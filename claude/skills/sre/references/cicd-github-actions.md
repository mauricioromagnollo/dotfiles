# CI/CD com GitHub Actions

Um pipeline de GitHub Actions é código que roda com privilégios sobre o seu repositório e, quase sempre, sobre a sua nuvem. Trate-o como superfície de ataque e como centro de custo, não como script auxiliar. A tese central deste documento: **a maior parte dos incidentes de Actions não vem de "o build quebrou", mas de permissões amplas demais, actions não fixadas e `pull_request_target` mal usado**. Otimize primeiro para o menor privilégio possível e para builds determinísticos; velocidade e elegância vêm depois. Fonte de verdade: https://docs.github.com/en/actions.

---

## Modelo mental: workflow → job → step → action

- **Workflow**: arquivo YAML em `.github/workflows/`. Disparado por eventos.
- **Job**: unidade de execução em um runner. Jobs rodam em paralelo por padrão; `needs:` cria dependência (DAG).
- **Step**: comando dentro de um job. Ou `run:` (shell) ou `uses:` (uma action).
- **Action**: unidade reutilizável referenciada por `uses:` (repo público, local ou Docker).

Regras que mudam decisão de revisão:
- Cada job roda em uma VM limpa e isolada; estado só passa entre jobs via `needs` + `outputs` ou `artifacts`.
- O `GITHUB_TOKEN` é recriado por job e expira ao fim dele.
- Variáveis de step não sobrevivem entre jobs.

### Eventos/triggers

| Trigger | Quando dispara | Cuidado |
|---|---|---|
| `push` | push em branch/tag | Use `paths:`/`branches:` para não rodar à toa |
| `pull_request` | PR aberto/atualizado | Roda com token **read-only** e **sem segredos** em PR de fork — seguro |
| `pull_request_target` | igual, mas no contexto do **base** | Roda com token de escrita e segredos; **risco alto** (ver abaixo) |
| `workflow_dispatch` | disparo manual (UI/API) | Permite `inputs:`; bom para deploy manual gated |
| `schedule` | cron | Roda sempre no default branch; sujeito a atraso e desabilitação por inatividade |
| `workflow_call` | chamado por outro workflow | Base de reusable workflows |

**Ao revisar**: confirme que o trigger é o mínimo necessário e que branches/paths estão restritos. Um workflow de deploy disparado em todo `push` para qualquer branch é red flag.

---

## Segurança (a parte que mais importa)

### `pull_request` vs `pull_request_target`

`pull_request` executa o workflow **no contexto do PR** (código do fork), com `GITHUB_TOKEN` somente leitura e **sem** acesso a segredos do repo. Seguro para lint/test de contribuições externas.

`pull_request_target` executa **no contexto do branch base**, com token de **escrita** e **acesso a segredos** — mas o `github.event` ainda descreve o PR não confiável. O anti-padrão fatal:

```yaml
# PERIGOSO: nunca faça checkout do código do PR em pull_request_target
on: pull_request_target
jobs:
  build:
    steps:
      - uses: actions/checkout@<sha>
        with:
          ref: ${{ github.event.pull_request.head.sha }}  # código do fork
      - run: npm install && npm test  # executa código não confiável COM segredos
```

Isso entrega segredos e token de escrita a qualquer um que abra um PR. Se precisar de `pull_request_target` (ex.: rotular PR, comentar), **não faça checkout do código do fork** e não rode nada que ele controle. Prefira o padrão de dois workflows: um `pull_request` (sem segredos) faz o build/gera artifact; um `workflow_run` privilegiado consome o artifact.

**Ao revisar**: qualquer `pull_request_target` que faça checkout de `head.sha`/`head.ref` e execute build/test é bloqueio imediato.

### `GITHUB_TOKEN` e `permissions:` mínimas

O token default pode vir com escopos amplos. Defina o piso no topo e refine por job:

```yaml
permissions:
  contents: read          # default seguro para todo o workflow
jobs:
  release:
    permissions:
      contents: write       # só este job pode escrever tags/releases
      id-token: write       # OIDC, só onde precisa
```

`permissions: write-all` (ou a ausência de bloco combinada com default permissivo da org) é o erro mais comum. Aplique least privilege **por job**, não por workflow.

**Ao revisar**: exija um bloco `permissions:` explícito. O default do workflow deve ser `contents: read`; escrita aparece só nos jobs que a exigem.

### Pin de actions por SHA completo

Tags (`@v4`) e branches (`@main`) são **mutáveis**: quem controla a action pode reescrever a tag e injetar código malicioso no seu pipeline (ataque de supply chain, como no caso `tj-actions/changed-files`). Fixe pelo SHA de commit completo:

```yaml
# Frágil: tag pode ser movida
- uses: actions/checkout@v4
# Correto: SHA imutável, com comentário indicando a versão
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

Vale para toda action de terceiros. Actions oficiais da `actions/` são mais confiáveis, mas o SHA continua sendo a defesa correta.

**Ao revisar**: qualquer `uses:` de terceiro por tag/branch mutável é red flag. Peça SHA + comentário de versão.

### Segredos e OIDC (sem chave estática)

- Segredos via `secrets.*` nunca são impressos por padrão, mas **não os ecoe** e não os passe para actions não confiáveis.
- Para nuvem, **prefira OIDC** a chave de longa duração. O runner obtém um token curto e assume uma role via trust policy — nada de `AWS_SECRET_ACCESS_KEY` guardado no repo:

```yaml
permissions:
  id-token: write
  contents: read
steps:
  - uses: aws-actions/configure-aws-credentials@<sha>
    with:
      role-to-assume: arn:aws:iam::123456789012:role/gh-deploy
      aws-region: us-east-1
```

A trust policy da role deve restringir `sub` ao repo e ref específicos (ex.: `repo:org/repo:ref:refs/heads/main`), senão qualquer branch/fork pode assumir a role.

**Ao revisar**: chave estática de cloud em `secrets` quando OIDC está disponível é red flag. Verifique também a condição `sub` da trust policy.

### Script injection via `${{ github.event.* }}`

Campos controlados pelo autor do evento (título de PR, nome de branch, corpo de issue) interpolados direto em `run:` permitem execução de comando arbitrário:

```yaml
# VULNERÁVEL: título do PR é injetado no shell
- run: echo "PR: ${{ github.event.pull_request.title }}"
# SEGURO: passe por env; o shell trata como dado, não como código
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR: $TITLE"
```

A regra: **nunca interpole expressão `${{ }}` com dado não confiável dentro de `run:`**. Passe por `env:` e referencie a variável.

**Ao revisar**: procure `${{ github.event.* }}`, `${{ github.head_ref }}` etc. dentro de blocos `run:`. Exija a ponte por `env`.

### Environments com proteção

Para produção, use `environment:` com required reviewers, wait timer e restrição de branch. Segredos podem ser escopados por environment, e o job fica pausado até aprovação humana:

```yaml
jobs:
  deploy-prod:
    environment:
      name: production
      url: https://app.exemplo.com
    steps: [...]
```

**Ao revisar**: deploy de produção sem `environment` protegido (required reviewers/branch policy) é red flag.

---

## Confiabilidade e estrutura

### DAG de jobs, concorrência, timeout

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true   # cancela run obsoleto do mesmo branch/PR
jobs:
  test:
    timeout-minutes: 15       # evita runner pendurado consumindo minutos
  deploy:
    needs: test               # só roda se test passou
    if: github.ref == 'refs/heads/main'
```

- `concurrency` com `cancel-in-progress` evita gastar runner em commits já superados; **não** use `cancel-in-progress: true` em jobs de deploy, onde cancelar no meio pode deixar estado inconsistente — ali prefira serializar sem cancelar.
- `timeout-minutes` em todo job: sem isso, um passo travado roda até o teto de 6h.
- `if:` controla execução condicional; `continue-on-error: true` deixa o job falhar sem quebrar o workflow (útil para steps informativos, perigoso se esconder falha real).

### Matrix builds

```yaml
strategy:
  fail-fast: false            # não aborta as outras versões no primeiro erro
  matrix:
    node: [20, 22, 24]
    os: [ubuntu-latest, macos-latest]
```

Matrix multiplica combinações — 3 versões × 2 SOs = 6 jobs. Ótimo para cobertura, caro se explodir. Use `include`/`exclude` para podar combinações irrelevantes.

### Reusable workflows vs composite actions

| | Reusable workflow | Composite action |
|---|---|---|
| Referência | `uses: org/repo/.github/workflows/x.yml@sha` no nível de **job** | `uses:` no nível de **step** |
| Granularidade | Orquestra jobs inteiros | Empacota uma sequência de steps |
| Segredos | Recebe via `secrets:` (ou `inherit`) | Recebe via `inputs` |
| Quando usar | Padronizar pipelines (build+test+deploy) entre repos | Empacotar steps repetidos dentro de um job |

Regra prática: precisa de vários jobs, `needs`, environments? Reusable workflow. Só quer não repetir 5 steps de setup? Composite action.

### Cache e artifacts

- `actions/cache` (ou o cache embutido de `setup-node`/`setup-python`) reduz tempo e custo reinstalando dependências. Use chave estável baseada no lockfile: `key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}`.
- **Artifacts** passam arquivos entre jobs e ficam retidos para download; ajuste `retention-days` para não acumular custo de storage.
- Cache é otimização, não fonte de verdade: build deve funcionar com cache frio.

**Ao revisar**: jobs sem `timeout-minutes`, ausência de `concurrency` em workflows disparados por push/PR frequente, e matrix sem poda são pontos de atenção.

---

## Custo

| Alavanca | Efeito |
|---|---|
| Runner hosted vs self-hosted | Hosted cobra por minuto (multiplicador maior em macOS/Windows); self-hosted troca custo de minuto por custo de manutenção/segurança |
| Explosão de matrix | Cada célula é um runner cobrado; podar combinações corta gasto linearmente |
| Cache | Menos tempo de build = menos minutos cobrados |
| `paths:` / `paths-ignore:` | Não dispara pipeline em mudança de docs/README |
| `concurrency` + `cancel-in-progress` | Não paga por runs obsoletos |

```yaml
on:
  push:
    paths-ignore: ['**.md', 'docs/**']
```

Runners macOS/Windows têm multiplicador de minutos alto — evite matrix cheia nesses SOs quando Linux cobre o caso.

**Ao revisar**: pipeline pesado disparando em toda mudança (inclusive docs), matrix macOS/Windows sem necessidade, e ausência de cache em builds longos são desperdício direto.

### Self-hosted runners e segurança

Self-hosted é atraente para hardware específico ou rede privada, mas **nunca use self-hosted em repositório público com PRs de fork**: um PR malicioso executa código na sua máquina/rede persistente. Se precisar, use runners efêmeros (destruídos por job) e isolados de rede.

**Ao revisar**: self-hosted runner referenciado em workflow acionado por `pull_request` em repo público é red flag crítico.

---

## Deploy

- **Gate por environment**: produção atrás de required reviewers; staging automático.
- **Promoção entre ambientes**: mesmo artifact validado em staging é promovido a prod (não rebuild) — garante que o que testou é o que subiu.
- **Canary/blue-green**: orquestre via jobs com `needs` + health check; o job de "promote" só roda se o de "verify canary" passar. Falha aciona rollback (job com `if: failure()`).
- **Releases fixadas**: publique release/tag imutável e faça deploy referenciando a tag/SHA, não `latest`.

```yaml
deploy-canary:
  environment: production
verify-canary:
  needs: deploy-canary
promote:
  needs: verify-canary
  if: success()
```

**Ao revisar**: rebuild na promoção (em vez de reusar o artifact testado), deploy de `latest` sem tag fixa, e canary sem step de verificação/rollback são fragilidades.

---

## Manutenção

- **Dependabot para actions**: mantém os SHAs fixados atualizados via PR, resolvendo o atrito de pinning por SHA.

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule: { interval: "weekly" }
```

- **Versionar workflows**: mudanças em `.github/workflows/` passam por PR e review como qualquer código.
- **`act`** roda workflows localmente para iterar sem consumir minutos nem poluir histórico — bom para debug, não substitui execução real (diferenças de ambiente e de contexto de eventos/segredos).

**Ao revisar**: ausência de Dependabot para actions torna o pinning por SHA insustentável na prática (ninguém atualiza manualmente).

---

## Sinais de alerta na revisão

| Sinal | Por que é problema | Correção |
|---|---|---|
| `permissions: write-all` ou sem bloco `permissions` | Token com escopo amplo demais | Default `contents: read`, escrita só por job |
| `uses: org/action@v4` (tag/branch) | Supply chain: tag é mutável | Fixar por SHA completo + comentário |
| `pull_request_target` com checkout de código de fork | Segredos + escrita expostos a código não confiável | Não fazer checkout do fork; padrão em dois workflows |
| `${{ github.event.* }}` dentro de `run:` | Script injection | Passar por `env:` e referenciar variável |
| Segredo em `run: echo $SECRET` | Vazamento em log | Nunca ecoar; usar mascaramento nativo |
| Chave AWS/Azure estática em `secrets` | Credencial de longa duração roubável | OIDC + `configure-aws-credentials` + trust policy restrita |
| Sem `concurrency` | Runs obsoletos consomem runner | `concurrency` + `cancel-in-progress` (exceto deploy) |
| Sem `timeout-minutes` | Job travado roda até 6h | `timeout-minutes` em todo job |
| Deploy de prod sem `environment` protegido | Sem aprovação humana/branch policy | `environment` com required reviewers |
| Self-hosted em repo público com PR de fork | Execução de código não confiável na sua infra | Runner efêmero isolado ou hosted |
| Matrix macOS/Windows cheia sem necessidade | Custo de minutos multiplicado | Podar com `include`/`exclude`; Linux quando basta |
| Rebuild na promoção de ambiente | Sobe artifact diferente do testado | Promover o mesmo artifact validado |

Referência oficial completa: https://docs.github.com/en/actions — em especial "Security hardening for GitHub Actions" e "Automatic token authentication".
