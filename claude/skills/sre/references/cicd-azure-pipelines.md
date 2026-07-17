# CI/CD com Azure Pipelines (Azure DevOps)

Azure Pipelines executa builds e deploys a partir de YAML versionado no repositório, com um modelo de recursos protegidos (service connections, environments, variable groups) que exige aprovação explícita para ser consumido. A tese central desta referência: prefira **YAML pipelines** sobre Classic, autentique via **Workload Identity Federation (OIDC)** em vez de segredos de longa duração, e proteja produção com **Environments + approvals & checks**. O restante são trade-offs de custo (hosted vs self-hosted), confiabilidade (templates e estratégias de deploy) e governança (protected resources). Fonte de verdade: https://learn.microsoft.com/en-us/azure/devops/pipelines/

## Modelo mental: pipeline → stages → jobs → steps

Um pipeline é uma árvore. `stages` agrupam trabalho em fases (build, test, deploy) e podem ter dependências entre si; `jobs` dentro de um stage rodam cada um em um agent; `steps` (tasks ou scripts) rodam sequencialmente dentro de um job compartilhando o mesmo workspace. Jobs em stages diferentes NÃO compartilham filesystem — passe artefatos via `publish`/`download` ou pipeline caching.

```yaml
trigger:
  branches: { include: [main] }
  paths: { include: [src/**] }   # path filter: evita rodar tudo em todo commit
pr:
  branches: { include: [main] }

stages:
  - stage: build
    jobs:
      - job: compile
        steps:
          - script: npm ci && npm run build
```

`trigger:` dispara em push; `pr:` dispara em pull request (só funciona para Azure Repos; para GitHub o trigger de PR vem da branch policy/app). `resources:` declara dependências externas — outros `repositories`, `pipelines` (para consumir artefatos de outro pipeline com trigger em cascata), e `containers` (para container jobs e service containers).

```yaml
resources:
  repositories:
    - repository: templatesRepo
      type: git
      name: platform/pipeline-templates
      ref: refs/tags/v3        # pinado: sem isso, mudança silenciosa no template
  pipelines:
    - pipeline: upstream
      source: build-lib
      trigger: true            # dispara este pipeline quando o upstream publica
```

Acionável: se um pipeline roda em todo commit sem `paths:`, questione o custo antes de qualquer outra coisa; e todo `resources.repositories` deve ter `ref` fixo.

## YAML vs Classic

| Aspecto | YAML pipelines | Classic (UI) |
|---|---|---|
| Versionamento | No repo, revisável em PR | Fora do repo, sem diff real |
| Reuso | Templates, `extends`, parameters | Task groups (frágeis) |
| Recomendação MS | Preferido para novos | Legado, evitar |
| Release gates | Environments + checks | Classic Release (em manutenção) |

Classic Release ainda existe e alguns times legados dependem dele, mas a Microsoft não investe mais nele. Acionável: em revisão de pipeline novo em Classic, sinalize migração para YAML — sem isso não há code review real do pipeline.

## Agents: Microsoft-hosted vs self-hosted

Microsoft-hosted são VMs efêmeras e limpas a cada job (sem estado entre execuções), mantidas pela Microsoft. Self-hosted são máquinas suas em um pool, com estado, cache local e acesso à sua rede.

| Critério | Microsoft-hosted | Self-hosted |
|---|---|---|
| Manutenção | Zero | Sua (patch, imagem, escala) |
| Isolamento | Efêmero por job | Persistente (risco de contaminação) |
| Custo | Por minuto/parallel job | Máquina fixa + parallel job grátis |
| Acesso a rede privada | Não (sem VNet) | Sim |
| Superfície de ataque | Baixa | Alta se exposto |

Billing: paralelismo é cobrado por **parallel job**, não por minuto de máquina no self-hosted. Cada parallel job Microsoft-hosted tem limite de 60 minutos por job em repositório privado (público tem mais); self-hosted não tem limite de tempo. Um projeto sem parallel jobs comprados enfileira jobs (serializa), o que aumenta o tempo de fila — pode ser gargalo antes do tempo de build em si.

Um self-hosted agent com acesso a produção e a segredos, exposto na internet ou rodando código de PR de fork, é um vetor de comprometimento crítico: o código do PR roda na máquina que enxerga sua rede e seu cache. Acionável: só use self-hosted quando precisar de rede privada ou toolchain pesada; se usar, isole o pool, não rode PR de fork nele, use imagens efêmeras (scale set agents) quando possível e restrinja quais pipelines podem usá-lo (protected resources).

## Segurança: segredos, service connections e OIDC

Segredos nunca em texto claro no YAML. Use **variable groups** (Library) ou, melhor, **Azure Key Vault** ligado a um variable group, para que o segredo viva no Key Vault e nunca no Azure DevOps.

```yaml
variables:
  - group: prod-secrets      # variable group (idealmente backed por Key Vault)
steps:
  - script: echo "##vso[task.setvariable variable=token;issecret=true]$GENERATED"
```

Secret variables não são mascaradas se você as construir e imprimir por engano — marque com `issecret=true` quando gerar em runtime e nunca faça `echo $SECRET`. Secret variables também NÃO são expostas automaticamente como env var para scripts; mapeie explicitamente via `env:` no step, o que reduz vazamento acidental.

**Workload Identity Federation (OIDC)** é a boa prática atual para autenticar em Azure/AWS/GCP: a service connection troca um token OIDC de curta duração por credenciais, sem client secret nem chave de longa duração armazenada. Elimina rotação de segredo e reduz o raio de dano de um vazamento. Acionável: em revisão, uma service connection para nuvem com secret/certificado de longa duração deve virar Workload Identity Federation.

Service connections, environments, variable groups, agent pools e repos protegidos são **protected resources**: por padrão exigem que o pipeline seja autorizado (e podem ter checks — approval, branch control, "exclusive lock"). Um **pipeline decorator** injeta steps em TODOS os pipelines da organização; é poderoso para compliance e igualmente perigoso — um decorator malicioso ou mal escrito compromete tudo. Acionável: audite decorators como código privilegiado e restrinja quem os instala.

## Confiabilidade e estrutura: templates

Templates dão reuso e governança. `template:` inclui steps/jobs/stages de outro arquivo; `extends:` faz o pipeline herdar de um template que define a forma permitida — o padrão para *impor* políticas (só este template pode ser usado, e ele controla o que roda). Use `parameters` tipados para contrato explícito.

```yaml
# templates/build.yml
parameters:
  - name: nodeVersion
    type: string
    default: "24"
steps:
  - script: nvm use ${{ parameters.nodeVersion }} && npm ci

# azure-pipelines.yml
extends:
  template: templates/build.yml
  parameters: { nodeVersion: "24.16.0" }
```

`extends` com required templates (via branch policy ou org settings) é o mecanismo para *governança*: só pipelines que estendem o template aprovado podem tocar recursos protegidos. Acionável: template referenciado sem ref fixa (`@refs/tags/v1` ou repo pinado por commit) é um risco de supply chain — fixe a versão.

## Stages: dependsOn, condition, matrix

`dependsOn` define a ordem/fan-out entre stages e jobs; `condition:` controla execução (ex.: só faz deploy em `main`). `strategy: matrix` expande um job em várias combinações; `strategy: parallel` fatia por número de agents.

```yaml
- stage: deploy
  dependsOn: [test]
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
    - job: test
      strategy:
        matrix:
          node20: { NODE: "20" }
          node24: { NODE: "24" }
```

Cuidado: `condition:` customizada substitui o implícito `succeeded()` — se você escreve `condition: eq(...)` sem `and(succeeded(), ...)`, o stage roda mesmo após falha anterior. Acionável: toda `condition:` de deploy deve incluir `succeeded()` explicitamente.

## Deployment jobs, Environments e estratégias

Um `deployment` job (diferente de `job`) registra histórico no **Environment** e habilita estratégias:

| Estratégia | Comportamento | Quando usar |
|---|---|---|
| `runOnce` | Deploy simples, uma passada | Maioria dos casos |
| `rolling` | Atualiza N alvos por vez | VMs, reduzir blast radius |
| `canary` | Incrementa tráfego (`increments`), com `preDeploy`/`postDeploy` | Validação gradual em produção |

```yaml
- deployment: web
  environment: production   # protected resource: aqui moram approvals & checks
  strategy:
    canary:
      increments: [10, 50]
      deploy:
        steps: [ { script: ./deploy.sh } ]
```

O **Environment** guarda recursos (Kubernetes namespaces, VMs) e o histórico de deploys, e é onde você anexa **approvals & checks**:

| Check | O que faz |
|---|---|
| Approvals | Aprovação manual de pessoas/grupos antes do stage rodar |
| Invoke REST API | Gate automático: chama um endpoint e valida a resposta |
| Query Azure Monitor | Gate automático: bloqueia se há alerta ativo |
| Branch control | Só permite deploy a partir de branches autorizadas |
| Business hours | Segura o deploy fora de janela definida |
| Exclusive lock | Serializa deploys concorrentes no mesmo environment |

Checks ficam no recurso protegido, não no YAML — o autor do pipeline não consegue removê-los, o que é o ponto: governança separada de quem escreve o pipeline. Acionável: produção sem approval OU sem gate automático no Environment é o achado número um em qualquer revisão.

## Custo

| Alavanca | Efeito |
|---|---|
| `paths:` filter | Não roda em todo commit |
| `Cache@2` | Restaura deps (node_modules, ~/.m2) entre runs |
| Pipeline caching vs artifacts | Cache = otimização best-effort; artifact = entrega garantida entre stages |
| Self-hosted | Parallel jobs grátis, mas custo de máquina/manutenção |

```yaml
- task: Cache@2
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    path: $(Pipeline.Workspace)/.npm
```

Cache é best-effort: um cache miss não quebra o build, só o deixa mais lento — por isso não substitui artifacts para passar build output entre stages. Acionável: se o custo de minutos hosted é alto e o pipeline reinstala deps do zero toda vez, adicione `Cache@2` e path filters antes de considerar self-hosted.

## Azure Pipelines vs GitHub Actions

| Dimensão | Azure Pipelines | GitHub Actions |
|---|---|---|
| Governança de recursos | Forte (protected resources, checks, extends obrigatório) | Environments + rulesets, mais leve |
| Ecossistema de reuso | Tasks + templates | Marketplace enorme de actions |
| Approvals/gates ricos | Nativo e maduro | Environments + required reviewers |
| Onde brilha | Enterprise, compliance, multi-repo, deploy complexo | Repo no GitHub, OSS, velocidade de setup |
| OIDC para nuvem | Workload Identity Federation | OIDC nativo |

Honestamente: se o código já está no GitHub e o time quer velocidade e marketplace, Actions costuma vencer. Se há requisito forte de governança, aprovações multi-stage e integração com Azure DevOps Boards/Repos, Azure Pipelines vence. Acionável: não migre por moda; escolha pela superfície de governança que você precisa impor.

## Sinais de alerta na revisão

| Sinal | Por que é problema | Correção |
|---|---|---|
| Segredo em variável sem `issecret`/não secret | Vaza em log | Variable group + Key Vault; `issecret=true` |
| Service connection com secret de longa duração | Rotação e raio de dano | Workload Identity Federation (OIDC) |
| Service connection com escopo amplo (subscription inteira) | Excesso de privilégio | Escopar a resource group / role mínima |
| Produção sem approvals nem gates | Deploy sem controle | Approvals & checks no Environment |
| Self-hosted agent exposto / rodando PR de fork | Execução de código não confiável com acesso | Isolar pool, bloquear fork, restringir pipelines |
| Template referenciado sem versão fixa | Supply chain / mudança silenciosa | Pinar por tag ou commit |
| `condition:` de deploy sem `succeeded()` | Roda após falha | `and(succeeded(), ...)` |
| Sem `paths:` filter em monorepo | Custo e ruído | Path filters por componente |
| Pipeline decorator amplo sem auditoria | Injeta steps em toda a org | Tratar como código privilegiado |
| Classic Release para pipeline novo | Sem code review real | Migrar para YAML + Environments |

Acionável final: percorra esta tabela de cima para baixo em todo pipeline revisado; os três primeiros itens (segredo exposto, OIDC ausente, produção sem approval) bloqueiam merge.
