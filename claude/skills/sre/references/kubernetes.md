# Kubernetes: Objetos, Workloads, Deploy Seguro e Segurança

Abra esta referência quando precisar **decidir** ou **revisar** algo em Kubernetes: qual workload usar, se o manifest está seguro para produção, se as probes estão certas, se o RBAC vaza permissão, se o deploy vai derrubar o serviço. Não é um tutorial de `kubectl` — é um conjunto de vereditos com o trade-off explícito e o "quando NÃO aplicar". Kubernetes é uma máquina de reconciliação: você declara o estado desejado, ele converge. A pergunta em toda revisão é *o que acontece quando um nó morre, quando o Pod trava, ou quando o deploy dá errado às 3h da manhã?*

Fontes de verdade: **Kubernetes: Up & Running (Burns, Beda, Hightower)** para os fundamentos, **Kubernetes Patterns (Ibryam, Huß)** para os padrões de projeto, e a doc oficial https://kubernetes.io/docs/ para a semântica exata dos campos.

---

## 1. Modelo mental: declarativo e reconciliação

**Tese: você não dá ordens ao Kubernetes, você declara um estado desejado e ele reconcilia.** Todo objeto tem `spec` (o que você quer) e `status` (o que existe agora). Os *controllers* rodam um loop infinito: observam o `status`, comparam com o `spec`, agem para fechar a diferença. Isso é o coração da resiliência — mate um Pod de um Deployment e o ReplicaSet recria; ninguém precisa acordar.

O cluster se divide em dois planos:

| Plano | Componentes | Papel |
|---|---|---|
| **Control plane** | `api-server` (única porta de entrada, valida e persiste), `etcd` (banco chave-valor, fonte de verdade), `scheduler` (decide em qual nó o Pod roda), `controller-manager` (roda os loops de reconciliação) | Decide o estado desejado |
| **Nodes** | `kubelet` (garante que os Pods do nó estejam rodando), `kube-proxy` (regras de rede/Service), container runtime | Executa o estado |

Consequência prática para revisão: **prefira sempre o modelo declarativo (`kubectl apply -f`, GitOps) a comandos imperativos (`kubectl create`, `kubectl edit`).** Comando imperativo não deixa rastro e diverge do repositório. Se o estado real não está no Git, ele não existe.

**Acionável:** ao revisar, pergunte "onde está o YAML que descreve isto?". Se a resposta for "eu rodei um comando", o desenho está errado — o estado precisa ser versionado.

---

## 2. Workloads: qual usar

**Tese: Pod é a unidade mínima e efêmera — nunca rode um Pod solto em produção.** Pod sem controller não é recriado quando o nó cai. Escolha o controller pela natureza da carga.

| Workload | Quando usar | Não use quando |
|---|---|---|
| **Pod** (solto) | Nunca em produção; só debug pontual (`kubectl run --rm -it`) | Sempre que precisar sobreviver a falha |
| **ReplicaSet** | Quase nunca direto — é detalhe interno do Deployment | Você quer rollout/rollback |
| **Deployment** | Padrão para **stateless**: API, worker sem estado. Rolling update e rollback nativos | A app tem identidade/estado por réplica |
| **StatefulSet** | **Stateful**: banco, broker, quorum. Identidade estável (`pod-0`, `pod-1`), DNS previsível, **um PVC por réplica**, ordem de criação/término | A app é stateless (over-engineering) |
| **DaemonSet** | Um Pod **por nó**: agente de log, coleta de métricas, CNI | Carga que não precisa estar em todo nó |
| **Job** | Tarefa que roda até completar (batch, migration) e para | Processo de longa duração |
| **CronJob** | Job em agenda (backup, relatório) | Precisa de execução contínua |

StatefulSet resolve identidade e storage, mas custa complexidade: escala mais devagar (ordenado), e você é responsável pela replicação de dados *dentro* da app — o Kubernetes só garante o PVC, não sincroniza os dados. Para bancos gerenciados, prefira o serviço da cloud (RDS) a rodar StatefulSet.

**Acionável:** em qualquer manifest de produção, confirme que há um controller (`Deployment`/`StatefulSet`/`DaemonSet`). Pod nu no repositório é sinal de alerta.

---

## 3. Rede e exposição

**Tese: Pods são efêmeros e têm IP volátil — nunca fale com um Pod por IP, fale com um Service.** O Service é uma abstração estável (IP e DNS fixos) que faz load balancing sobre os Pods que casam com seu `selector`.

| Tipo de Service | Expõe para | Uso típico |
|---|---|---|
| **ClusterIP** (padrão) | Só dentro do cluster | Comunicação entre serviços internos |
| **NodePort** | Porta em todo nó | Raramente direto; base para outras camadas |
| **LoadBalancer** | LB da cloud (ELB, etc.) | Expor um serviço à internet, um LB por Service (caro) |

Para HTTP, **um LoadBalancer por serviço não escala em custo**. Use **Ingress** + **Ingress Controller** (nginx, Traefik): um único ponto de entrada roteia por host/path para vários Services. O Ingress é só a regra; o Controller é quem a executa — sem Controller instalado, o Ingress não faz nada.

**Gateway API** é o sucessor oficial do Ingress (mais expressivo, com papéis separados entre infra e app). Para clusters novos, avalie Gateway API; o Ingress continua suportado mas está em modo de manutenção.

**DNS interno:** todo Service ganha nome `service.namespace.svc.cluster.local`. Dentro do mesmo namespace, basta `service`.

**NetworkPolicy:** por padrão, **todo Pod fala com todo Pod** — rede aberta. Aplique **default-deny** e libere só o necessário (least privilege de rede). Sem NetworkPolicy, um Pod comprometido alcança o cluster inteiro.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-ingress }
spec:
  podSelector: {}          # todos os Pods do namespace
  policyTypes: [Ingress]   # nega toda entrada; libere com policies específicas
```

**Acionável:** confirme que o namespace tem um default-deny e que a NetworkPolicy exige um CNI que a suporte (Calico, Cilium) — sem isso, a policy é ignorada silenciosamente.

---

## 4. Configuração: ConfigMap e Secret

**Tese: configuração sai da imagem — ConfigMap para dados não sensíveis, Secret para sensíveis.** Mas cuidado com a maior armadilha de todas:

**⚠️ Secret NÃO é criptografado — é apenas base64.** Qualquer um com acesso ao objeto ou ao `etcd` lê o valor em texto claro. Base64 é codificação, não segurança. Para proteger de verdade:

- Habilite **encryption at rest** no `etcd` (`EncryptionConfiguration` no api-server).
- Use **External Secrets Operator**, **Sealed Secrets** ou um **KMS** (AWS/GCP/Vault) para nunca ter o segredo em texto no repositório.
- Restrinja acesso via RBAC (quem pode `get secrets` num namespace lê tudo).

Injeção — **env var vs volume mount**:

| Forma | Prós | Contras |
|---|---|---|
| **Env var** | Simples | Vaza fácil (logs de crash, `/proc`, ferramentas de debug); não atualiza sem restart |
| **Volume mount** | Atualiza sem restart (ConfigMap); menos exposto | App precisa reler o arquivo |

Para Secret, **volume mount é mais seguro que env var**.

**Acionável:** procure por Secret em texto no Git, valor sensível em ConfigMap, e confirme encryption at rest. Secret commitado é incidente — rotacione a credencial, não só remova o arquivo.

---

## 5. Saúde e rollout (Kubernetes Patterns)

**Tese: as três probes têm efeitos diferentes e trocá-las causa outage.** Este é o erro mais comum e mais caro em revisão.

| Probe | O que faz ao falhar | Use para |
|---|---|---|
| **liveness** | **Reinicia o container** | Detectar deadlock/travamento irrecuperável |
| **readiness** | **Tira do load balancer** (Endpoints), sem reiniciar | App viva mas não pronta (aquecendo, dependência fora) |
| **startup** | Segura liveness/readiness até a app subir | Apps de boot lento (evita liveness matar durante o start) |

**Erro clássico: `liveness == readiness`.** Se a liveness aponta para um endpoint que depende do banco, uma queda momentânea do banco faz o Kubernetes **reiniciar todos os Pods** — transformando uma degradação em outage total. Liveness deve checar só "o processo está vivo?"; readiness checa "consigo atender agora?".

**Rolling update** (padrão do Deployment): substitui Pods aos poucos.

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1          # quantos a mais posso criar durante o rollout
    maxUnavailable: 0    # 0 = nunca reduz capacidade (mais seguro, mais lento)
```

Deu errado? **`kubectl rollout undo deployment/x`** volta à revisão anterior — por isso versione com imagem por tag/digest, nunca `latest`.

**PodDisruptionBudget (PDB):** protege contra *disrupções voluntárias* (drain de nó, upgrade). Sem PDB, um `kubectl drain` pode derrubar todas as réplicas de uma vez.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 2        # nunca menos de 2 Pods durante manutenção
  selector: { matchLabels: { app: api } }
```

**Graceful shutdown:** ao receber `SIGTERM`, a app deve parar de aceitar tráfego e drenar conexões antes de morrer. Ajuste `terminationGracePeriodSeconds` e use `preStop` (ex.: `sleep 5`) para dar tempo do Service tirar o Pod do LB antes do processo cair.

**Acionável:** rejeite qualquer Deployment sem readiness probe, com liveness idêntica à readiness, ou serviço crítico sem PDB. Confirme que a app trata `SIGTERM`.

---

## 6. Recursos e scheduling

**Tese: sem `requests`/`limits`, você tem noisy neighbor e OOMKill imprevisível.** `requests` é o que o scheduler reserva (garante); `limits` é o teto (estoura → CPU throttling ou OOMKill na memória). A combinação define a **QoS class**, que decide **quem morre primeiro quando o nó fica sem memória**:

| QoS class | Condição | Risco de despejo |
|---|---|---|
| **Guaranteed** | requests == limits em todos os containers | Menor (morre por último) |
| **Burstable** | tem requests, mas != limits | Médio |
| **BestEffort** | sem requests nem limits | **Morre primeiro** |

Memória não é comprimível: passar do `limit` de memória = **OOMKill imediato**. CPU é comprimível: passar do `limit` = throttling (fica lento, não morre). Por isso muitos definem `limit` de CPU generoso (ou omitem) mas fixam `requests` de CPU e `requests == limits` de memória.

**Autoscaling:**

- **HPA** (Horizontal Pod Autoscaler): escala número de réplicas por métrica (CPU, memória, custom). Precisa de `requests` definido para calcular %.
- **VPA** (Vertical): ajusta requests/limits do Pod. Não combine com HPA na mesma métrica.
- **Cluster Autoscaler / Karpenter:** adiciona/remove nós quando Pods não cabem.

**Scheduling avançado:** `nodeAffinity` (atrai para nós com label), `taints/tolerations` (repele Pods de nós dedicados — só tolera quem deve), `topologySpreadConstraints` (espalha réplicas por zona/nó para sobreviver à queda de uma AZ).

**Acionável:** todo container precisa de `requests` (mínimo) e `limits` de memória. Sinalize qualquer Pod BestEffort em produção e HPA sem `requests`.

---

## 7. Segurança

**Tese: o padrão do Kubernetes é permissivo — segurança é opt-in e precisa ser exigida na revisão.**

**RBAC — least privilege.** `Role`/`RoleBinding` (namespace) e `ClusterRole`/`ClusterRoleBinding` (cluster). **Nunca conceda `cluster-admin`** a um workload ou pessoa "para funcionar rápido". Evite verbos amplos (`*`) e recursos amplos (`*`).

**ServiceAccount por workload.** Cada app com sua SA, com só as permissões que usa. Na AWS, use **IRSA** (IAM Roles for Service Accounts) ou **EKS Pod Identity** — mapeia a SA a um IAM role, eliminando chaves estáticas. Em GCP/Azure, **Workload Identity**.

**securityContext** — endureça o container:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 10001
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: ["ALL"] }
  seccompProfile: { type: RuntimeDefault }
```

**Pod Security Standards (PSS):** três níveis — `privileged`, `baseline`, `restricted`. Aplicados por namespace via label (`pod-security.kubernetes.io/enforce: restricted`). **Substituem as PodSecurityPolicies, que foram removidas** no 1.25. Alvo de produção: `restricted`.

**Isolamento:** use **namespaces** para separar times/ambientes, com **ResourceQuota** (teto de CPU/memória/objetos por namespace) e **LimitRange** (defaults por Pod). Isso impede um namespace de consumir o cluster.

**Acionável:** rejeite RBAC com `cluster-admin` ou `*`, Pod rodando como root, container sem `securityContext`, e namespace de produção sem PSS `restricted` e sem ResourceQuota.

---

## 8. Padrões (Kubernetes Patterns)

**Tese: composição de containers no Pod resolve problemas sem tocar na aplicação principal.** Um Pod pode ter vários containers que compartilham rede e volumes.

| Padrão | O que faz | Exemplo |
|---|---|---|
| **Init container** | Roda **antes** dos containers principais, até completar | Migration de banco, esperar dependência, preparar volume |
| **Sidecar** | Roda **junto**, estende a app | Coleta de logs, service mesh proxy, sync de config. Desde 1.29, sidecars nativos via init container com `restartPolicy: Always` |
| **Adapter** | Normaliza a saída da app para o mundo externo | Traduz métricas para formato do Prometheus |
| **Ambassador** | Proxy da app para o mundo externo | Simplifica acesso a um serviço remoto/sharding |

**Foundational patterns** (base de tudo): **Health Probe** (a app expõe seu estado — seção 5) e **Predictable Demands** (a app declara o que precisa via requests/limits — seção 6). Sem esses dois, os outros padrões não seguram.

**Operators e CRDs:** para automatizar operação de apps complexas (banco, mensageria), um **CRD** estende a API com um tipo novo e um **Operator** roda o loop de reconciliação daquele domínio. Padrão certo para "eu preciso que o Kubernetes gerencie X como gerencia Deployment".

**Acionável:** use init container para pré-condições (não `command` com `sleep`/`wait` no container principal); prefira sidecar a embutir responsabilidade de infra na app.

---

## 9. Helm, Kustomize e manifests puros

**Tese: escolha a ferramenta de empacotamento pelo grau de variação entre ambientes, não por moda.**

| Ferramenta | Quando | Trade-off |
|---|---|---|
| **Manifests puros** | Poucos objetos, um ambiente | Simples, mas duplica em cada ambiente |
| **Kustomize** | Mesma base com overlays por ambiente (dev/stg/prod), sem templating | Nativo no `kubectl`, sem linguagem nova; menos poderoso para lógica |
| **Helm** | Empacotar app para reuso/distribuição, muita parametrização, dependências | Templating (Go) e release management, mas templates viram sopa de `{{ }}` difícil de ler |

**Helm** — conceitos: **chart** (o pacote), **values** (parâmetros), **templating**, **release** (uma instalação com histórico). Use **`helm diff`** (plugin) antes de `helm upgrade` para ver o que muda — nunca aplique às cegas.

**Sempre fixe a versão do chart** (`--version`) e do app dentro dele. Chart de terceiro sem pin é o mesmo risco de `latest`: um `helm repo update` pode trazer uma versão que quebra tudo.

**Acionável:** para variação simples entre ambientes, prefira Kustomize a Helm (menos acidental complexidade). Se usar Helm, exija pin de versão e `helm diff` no pipeline.

---

## 10. Deploy seguro na prática

**Tese: rolling update básico não protege contra bug que passou no CI — reduza o blast radius com deploy progressivo.**

- **Canary:** manda uma fração do tráfego para a versão nova, mede métricas (erro, latência), promove se saudável ou reverte automaticamente. Ferramentas: **Argo Rollouts**, **Flagger**.
- **Blue-green:** sobe a versão nova completa em paralelo, troca o tráfego de uma vez (rollback instantâneo). Custa dobrar recursos durante a troca.

**GitOps como padrão de entrega.** O Git é a fonte de verdade; um agente (**ArgoCD**, **Flux**) reconcilia o cluster com o repositório continuamente. Ninguém roda `kubectl apply` na mão — você faz um PR, o merge é o deploy, e o drift é detectado e corrigido. Isso fecha o círculo do modelo declarativo da seção 1: estado desejado versionado, reconciliação automática, auditoria via histórico do Git.

**Acionável:** para serviço crítico, exija deploy progressivo com rollback automático por métrica. Prefira GitOps a `kubectl apply` manual no pipeline — o cluster deve espelhar o Git, não o contrário.

---

## Sinais de alerta na revisão

Escaneie o manifest/PR por estes — cada um é motivo para pedir mudança:

| Sinal | Por que é problema |
|---|---|
| **Pod solto** (sem Deployment/StatefulSet/DaemonSet) | Não é recriado se o nó cair |
| **Sem `requests`/`limits`** | QoS BestEffort, noisy neighbor, OOMKill; HPA não funciona |
| **Sem probes**, ou **`liveness == readiness`** | Sem readiness não drena LB; liveness acoplada a dependência causa outage em cascata |
| **Secret em texto no repositório** | Base64 não é criptografia; credencial vazada = incidente |
| **RBAC `cluster-admin` / `*`** | Viola least privilege; escalada de privilégio |
| **Roda como root** (sem `runAsNonRoot`) | Superfície de ataque; escape de container |
| **Imagem `:latest`** ou sem digest | Deploy não reproduzível; rollback impossível |
| **Serviço crítico sem PDB** | `drain`/upgrade derruba todas as réplicas |
| **Sem NetworkPolicy** (namespace aberto) | Pod comprometido alcança o cluster inteiro |
| **Sem PSS `restricted`** em produção | Pod privilegiado passa sem barreira |
| **`kubectl apply` manual** em vez de GitOps | Estado diverge do Git; sem auditoria |
| **Chart Helm sem pin de versão** | Upgrade não controlado quebra produção |

Regra final: em Kubernetes o padrão é sempre o mais permissivo e o menos resiliente. Segurança, isolamento de rede e limites de recurso são todos opt-in — se não estão no YAML, não existem. Revisar Kubernetes é, na prática, checar tudo o que *deveria* estar lá e não está.
