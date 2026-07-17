# Terraform e OpenTofu — Infrastructure as Code

Infraestrutura como código não é "escrever o `apply` mais rápido"; é tratar infra como software: versionada, revisável, reproduzível e aplicada por um pipeline, não por uma mão humana no terminal. Terraform (e o fork OpenTofu) declaram o estado desejado e convergem a realidade até ele. O maior risco não é o `.tf` — é o **state** e as **operações destrutivas**. Revise com isso em mente. Fontes de verdade: [docs Terraform](https://developer.hashicorp.com/terraform/docs), [Registry](https://registry.terraform.io/), [docs OpenTofu](https://opentofu.org/docs/). Base conceitual: **Terraform: Up & Running** (Yevgeniy Brikman) e **Infrastructure as Code** (Kief Morris).

## Princípios de IaC (Kief Morris)

**Tese**: código de infra deve ser idempotente e convergente — aplicar duas vezes dá o mesmo resultado, e o sistema caminha do estado atual para o desejado sem passos manuais. Trate servidores como **gado, não bichos de estimação** (cattle, not pets): recriáveis, descartáveis, sem carinho manual. Prefira infra **imutável** (recria em vez de mutar no lugar) sobre **mutável** (aplica patches sobre o que existe) — imutável elimina drift de configuração e "funciona só naquele servidor".

| Princípio | O que significa na revisão |
|---|---|
| Idempotência | `apply` repetido converge para o mesmo estado, sem efeito colateral acumulado |
| Convergência | O tooling reconcilia real → desejado; não há "passo manual depois do apply" |
| Imutável > mutável | Recurso é substituído, não editado à mão; sem SSH corrigindo produção |
| Cattle, not pets | Nada tem nome sagrado nem correção manual; tudo é recriável pelo código |
| Tudo versionado | `.tf`, `.tfvars` de exemplo, lock file e pipeline vivem no Git |
| Pipeline aplica | Humano abre PR e revisa o plan; o runner roda o `apply`, não a pessoa |

**Quando NÃO seguir à risca**: laboratório descartável, spike de um dia, ou POC que morre amanhã podem rodar `apply` local. Deixe explícito que é throwaway — o perigo é o throwaway virar produção.

**Acionável**: se um recurso precisa de intervenção manual pós-`apply` para funcionar, isso é um bug de convergência — mova o passo para o código ou para um provisioner declarado, não para um runbook.

## State — o coração e o maior risco

O `terraform.tfstate` é o mapa entre a configuração e os recursos reais. É **crítico e sensível**: contém IDs, metadados e frequentemente **segredos em texto claro** (senhas de RDS, chaves geradas). Perder o state = perder o controle da infra; vazar o state = vazar segredos.

**Regra dura: nunca state local em produção.** Use backend remoto com locking e versionamento.

| Backend | Locking | Notas |
|---|---|---|
| S3 + DynamoDB | Lock na tabela DynamoDB | Padrão AWS; S3 versionado + criptografado (SSE) |
| S3 nativo (lockfile) | `use_lockfile = true` (TF 1.10+ / OpenTofu) | Dispensa DynamoDB em versões recentes |
| Terraform Cloud / HCP | Nativo | Lock, histórico, RBAC e execução remota |
| azurerm | Blob lease | Storage Account com versionamento e soft-delete |
| gcs | Nativo | Bucket com versioning |

```hcl
terraform {
  backend "s3" {
    bucket         = "empresa-tfstate-prod"
    key            = "network/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks"   # ou use_lockfile = true em versões recentes
    encrypt        = true
  }
}
```

**State locking** evita dois `apply` concorrentes corromperem o state. Sem lock, dois pipelines simultâneos = corrupção. **Versionamento do bucket** é o seu botão de desfazer quando um `apply` estraga o state.

**Isolamento de state**: um state gigante para tudo é um blast radius enorme e um lock que serializa o time inteiro. Separe por **ambiente** (dev/stage/prod) e por **componente** (rede, banco, app). Brikman recomenda diretórios separados com backends distintos — mais explícito e seguro que workspaces.

**`terraform state` é bisturi, não martelo**:
- `state mv` — renomeia/move recurso no state sem destruir/recriar (refactor de nomes).
- `state rm` — remove do state sem destruir o recurso real (desacoplar sem apagar).
- `import` — traz recurso existente para o state (adoção de infra criada à mão).

Todos operam sobre o recurso crítico. Faça backup do state antes, rode em janela sem concorrência e revise o `plan` seguinte com lupa.

**Drift**: divergência entre o real e o state (alguém mexeu no console). `terraform plan` detecta; trate a causa (feche o acesso manual), não só o sintoma.

**Acionável**: em qualquer revisão, confirme backend remoto + lock + versionamento + `encrypt`. State local, sem lock ou sem versionamento em ambiente compartilhado é bloqueio de merge.

## Workflow seguro

O ciclo canônico é **`fmt` → `validate` → `plan` → revisão humana do plan → `apply`**. Nunca pule o plan.

```bash
terraform fmt -check -recursive   # formatação canônica (falha no CI se torto)
terraform validate                # sintaxe e consistência interna
terraform plan -out=tfplan        # plano salvo
# ... humano revisa o plan ...
terraform apply tfplan            # aplica EXATAMENTE o que foi revisado
```

**Sempre `plan` antes de `apply`.** O `plan` salvo com `-out` e aplicado depois garante que o `apply` executa exatamente o que foi revisado — sem corrida entre revisão e aplicação. `apply` sem plan revisado (ou `-auto-approve` interativo em produção) é dirigir de olhos fechados.

**Leia o plan procurando sinais destrutivos**:

| Sinal no plan | Significado | Ação |
|---|---|---|
| `+ create` | Cria recurso | OK, confira se é o esperado |
| `~ update in-place` | Altera sem recriar | Baixo risco, mas leia o diff |
| `-/+ destroy and then create` | **Recria** o recurso | Perda de dados/downtime se for stateful |
| `# forces replacement` | Atributo força recriação | Investigue antes; pode derrubar banco |
| `- destroy` | Destrói | Confirme que é intencional |

**Operações a alertar sempre**:
- `terraform destroy` — apaga tudo do state. Nunca no fluxo normal automatizado sem guarda.
- `-replace=ADDR` (substitui o antigo `taint`) — força recriação de um recurso.
- `-target=ADDR` — aplica só parte do grafo. É **escape hatch** para emergência/recuperação; no fluxo normal esconde dependências e cria state parcial. Ver `-target` num pipeline recorrente é red flag.

**`lifecycle`** protege recursos:

```hcl
resource "aws_db_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy       = true             # bloqueia destroy acidental de recurso com dados
    create_before_destroy = true             # cria o novo antes de matar o velho (zero-downtime)
    ignore_changes        = [tags["last_scan"]]  # ignora drift em campo mutado por fora
  }
}
```

**Acionável**: todo recurso stateful (banco, bucket com dados, volume) deve ter `prevent_destroy = true`. A ausência disso em recurso com dados é achado de revisão.

## Módulos

**Tese**: módulos são a unidade de reuso e composição. Root module é o que você aplica; child modules são chamados por ele. Bons inputs têm `type` e `validation`; bons outputs expõem só o necessário.

```hcl
variable "instance_count" {
  type        = number
  description = "Número de instâncias na ASG"
  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 10
    error_message = "instance_count deve estar entre 1 e 10."
  }
}
```

**Versione o que você consome** — pin de `source` e `version`, nunca `latest`:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"   # trava major/minor; nunca sem version no Registry
}
```

**DRY vs acoplamento**: nem tudo merece módulo. Abstrair cedo demais gera módulos com dez `if` disfarçados de variável, acoplando ambientes que deveriam divergir. **Não crie módulo** para algo usado uma vez, ou cuja "generalização" é especulação. Regra prática: extraia módulo quando há **repetição real** (rule of three) e a interface é estável.

**Estrutura de repositório (Brikman)**: separe **`modules/`** (blocos reutilizáveis, sem backend) de **`live/`** (root modules que aplicam, um por ambiente/componente, cada um com seu backend). Ambientes são diretórios distintos, não branches.

```
live/
  prod/
    network/     -> chama modules/vpc, backend próprio
    database/    -> chama modules/rds, backend próprio
  stage/
    ...
modules/
  vpc/
  rds/
```

**Acionável**: módulo do Registry sem `version` pinado, ou child module que recebe 15 variáveis para "servir a todos os casos", são sinais de abstração ruim — reveja a fronteira.

## Providers e versões

Reproduzibilidade exige travar **três** coisas: versão do Terraform/OpenTofu, versões dos providers e o lock file.

```hcl
terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"   # pin; nunca implícito "última que existir"
    }
  }
}
```

O **`.terraform.lock.hcl`** trava as versões exatas e os hashes dos providers. **Commite-o sempre** — é o equivalente ao `package-lock.json`. Sem ele, dois runners podem baixar providers diferentes e produzir planos diferentes. Atualize deliberadamente com `terraform init -upgrade` e revise o diff do lock.

**Acionável**: `required_version`, `required_providers` com `version`, e `.terraform.lock.hcl` versionado são obrigatórios. Provider por `latest` implícito ou lock file no `.gitignore` são bloqueio de merge.

## Segurança

| Regra | Como |
|---|---|
| Segredo nunca em `.tf`/`.tfvars` versionado | Use secret manager (AWS Secrets Manager, Vault) via `data` source |
| Marque outputs sensíveis | `sensitive = true` evita vazar no log do plan |
| State criptografado | `encrypt = true` no backend; bucket com SSE/KMS |
| Scanning no CI | `tfsec`, `checkov` ou `trivy config` a cada PR |
| Least privilege no runner | Credencial do pipeline com o mínimo; OIDC > chave estática |

```hcl
variable "db_password" {
  type      = string
  sensitive = true   # não aparece em output nem no plan textual
}
```

Lembre: mesmo com `sensitive = true`, o valor **entra no state em texto claro**. Por isso o state criptografado e com acesso restrito é inegociável. O ideal é o recurso ler o segredo direto do secret manager em runtime, não passar pelo Terraform.

**Acionável**: rode `grep -rniE 'password|secret|token|key' *.tfvars` na revisão. Segredo literal em arquivo versionado é incidente — rotacione o segredo, não só remova a linha.

## Padrões de código

**`for_each` > `count`**: `count` indexa por posição — remover o item do meio de uma lista **reordena** e faz o Terraform destruir/recriar tudo depois dele. `for_each` indexa por chave estável, então adicionar/remover um item mexe só naquele.

```hcl
# Frágil: remover "b" recria "c"
resource "aws_iam_user" "u" {
  count = length(var.names)
  name  = var.names[count.index]
}

# Seguro: cada usuário tem endereço estável por chave
resource "aws_iam_user" "u" {
  for_each = toset(var.names)
  name     = each.value
}
```

Use `count` apenas para o caso booleano (criar 0 ou 1: `count = var.enabled ? 1 : 0`).

**`data` sources** leem o que existe (AMI mais recente, VPC padrão) sem gerenciar. **`depends_on`** é para dependências que o Terraform não infere sozinho — use com parcimônia; dependência implícita via referência é melhor. **`dynamic` blocks** geram blocos repetidos (regras de security group), mas em excesso viram código ilegível — se estiver aninhando `dynamic`, reconsidere.

**Workspaces vs diretórios**: workspaces mantêm múltiplos states no mesmo backend/código. Parecem convenientes para dev/stage/prod, mas é fácil aplicar no workspace errado, e o código é idêntico entre ambientes que normalmente precisam divergir. Brikman prefere **diretórios separados** para ambientes (isolamento explícito de backend e config). Workspaces servem melhor para efêmeros de curta vida (branch/feature).

**Acionável**: `count` sobre lista que pode ter item removido do meio é bug latente — troque por `for_each`. Ambientes de produção em workspaces do mesmo diretório merecem questionamento.

## OpenTofu

Após a HashiCorp mudar o Terraform da licença MPL para a **BSL** (Business Source License) em 2023, a comunidade criou o **OpenTofu**, fork open source sob a Linux Foundation, licença MPL 2.0. É **drop-in**: o binário `tofu` substitui `terraform`, lê os mesmos `.tf`, usa o mesmo Registry e os mesmos providers.

| Aspecto | Nota |
|---|---|
| Compatibilidade | Forkado do Terraform 1.5.x; comandos e HCL equivalentes |
| Divergência | OpenTofu tem features próprias (ex.: state encryption nativa, `for_each` em provider) e cadência própria; versões novas do Terraform não são espelhadas |
| Quando considerar | Preocupação com a BSL, preferência por governação de fundação, ou features específicas do OpenTofu |
| Migração | `terraform` → `tofu` costuma ser troca de binário; teste com `plan`, não migre produção às cegas |

**Acionável**: escolha um dos dois por projeto e trave a versão. Não misture `terraform` e `tofu` no mesmo state sem validar compatibilidade da versão — os formatos de state podem divergir conforme evoluem.

## CI/CD para Terraform

**Tese**: o humano revisa; o pipeline aplica. O padrão é **`plan` no PR** (postado como comentário para revisão) e **`apply` no merge** para a branch principal.

| Fluxo | Como |
|---|---|
| Plan em PR | CI roda `fmt -check`, `validate`, scanning e `plan`; posta o plano como comentário |
| Apply em merge | Merge na main dispara `apply` do plano aprovado, com credencial de menor privilégio |
| Ferramentas | Atlantis (comentário `atlantis apply`), Terraform Cloud/HCP (run + policy), ou pipeline próprio (GitHub Actions/Azure) |

Regras: rode `fmt`, `validate` e scanning como gate antes do `plan`; salve o plano (`-out`) e aplique o **mesmo** artefato no merge; use OIDC para credencial efêmera no runner em vez de chave de longa duração; exija aprovação humana para ambientes de produção.

**Acionável**: se o `plan` do PR e o `apply` do merge não usam o mesmo plano salvo, existe janela para o real divergir entre revisão e aplicação — feche essa janela com `-out` + artefato.

## Sinais de alerta na revisão

| Sinal | Por que é problema |
|---|---|
| State local (sem backend remoto) em ambiente compartilhado | Sem colaboração segura, sem lock, fácil de perder |
| Backend sem locking | Dois `apply` concorrentes corrompem o state |
| Bucket de state sem versionamento/criptografia | Sem desfazer; segredos do state expostos |
| Segredo em `.tf` ou `.tfvars` commitado | Vazamento; exige rotação, não só remoção |
| Provider ou módulo por `latest`/sem `version` | Plano não reproduzível; upgrade silencioso |
| `.terraform.lock.hcl` não commitado (ou no `.gitignore`) | Runners baixam versões diferentes |
| `-target` no fluxo normal | Esconde dependências; gera state parcial |
| `apply` sem `plan` revisado (`-auto-approve` em prod) | Aplica o que ninguém leu |
| `prevent_destroy` ausente em recurso com dados | `destroy`/replacement acidental apaga o banco |
| `# forces replacement` em recurso stateful ignorado no plan | Recriação = perda de dados/downtime |
| `count` sobre lista mutável no meio | Reordenação recria recursos em cascata |
| State monolítico (tudo num arquivo) | Blast radius enorme; lock serializa o time todo |
| Sem `fmt`/`validate`/scanning no CI | Erro e vulnerabilidade passam para o merge |
| Credencial estática de longa duração no runner | Superfície de ataque; prefira OIDC/least privilege |

Na dúvida entre bloquear o merge ou seguir: qualquer item envolvendo **state, segredo ou operação destrutiva** é bloqueio até correção; os demais são comentário forte no PR.
