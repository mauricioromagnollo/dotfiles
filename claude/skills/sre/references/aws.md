# AWS — modo de pensar, serviços essenciais e revisão de arquitetura

A AWS não é um catálogo de serviços que você memoriza; é um conjunto de trade-offs que você **escolhe conscientemente**. O erro mais comum não é técnico, é de altitude: escolher um serviço antes de ter decidido o que se está otimizando (custo? operação? confiabilidade? velocidade de entrega?). Este arquivo trata o **Well-Architected Framework** como a lente central — a forma de perguntar antes de decidir — e depois desce para os serviços por categoria, sempre no formato tese → trade-off → quando NÃO aplicar. A regra que atravessa tudo: **na AWS quase nada tem uma única resposta certa; tem a resposta certa para a sua carga, seu orçamento e sua tolerância a falha.** Base: AWS Well-Architected Framework (https://aws.amazon.com/architecture/well-architected/), docs oficiais (https://docs.aws.amazon.com/) e a amplitude do syllabus Solutions Architect Associate (Stephane Maarek / Adrian Cantrill).

---

## Well-Architected Framework — os 6 pilares (o modo de pensar)

Well-Architected **não é uma receita**, é uma lista de perguntas. A AWS publica centenas de perguntas de revisão agrupadas em 6 pilares; o valor está em fazer as perguntas *antes* de construir e *de novo* em cada revisão. Ninguém "passa" no Well-Architected — você conhece seus riscos e decide quais aceitar. Use os pilares como checklist de conversa, não como certificado.

| Pilar | Pergunta central | Princípios de design (1-2) |
|---|---|---|
| **Operational Excellence** | "Como eu opero, observo e melhoro isso ao longo do tempo?" | Faça operações como código (IaC, runbooks versionados); antecipe falha e aprenda com cada incidente. |
| **Security** | "Quem pode fazer o quê, e como eu provo isso?" | Least privilege por padrão; rastreabilidade total (tudo auditável). Segurança em todas as camadas. |
| **Reliability** | "O que acontece quando (não se) isso falhar?" | Recupere-se automaticamente de falha; teste procedimentos de recuperação; escale horizontalmente. |
| **Performance Efficiency** | "Estou usando o recurso certo, no tamanho certo, agora?" | Use serviços gerenciados para descer de nível; experimente com frequência (o barato de testar é vantagem da nuvem). |
| **Cost Optimization** | "Estou pagando pelo valor que recebo?" | Meça e atribua custo (tags); adote modelo de consumo — pague pelo que usa, desligue o que não usa. |
| **Sustainability** | "Qual o impacto ambiental da minha carga?" | Maximize utilização (menos recurso ocioso = menos energia); escolha regiões e instâncias mais eficientes. |

**Tese:** os pilares frequentemente **conflitam** — mais confiabilidade (Multi-Region) custa mais; mais performance (instância maior) custa mais; mais segurança (isolamento por conta) custa operação. Well-Architected não resolve o conflito, ele **força você a nomeá-lo**.

**Quando NÃO aplicar como dogma:** para um protótipo descartável ou spike de 2 semanas, otimizar os 6 pilares é over-engineering. Aplique Security sempre (nunca vaze credencial nem exponha dado nem em POC), e adie o resto conscientemente.

**Acionável:** em toda decisão de arquitetura, escreva em uma linha qual pilar você está priorizando e qual está sacrificando. Se não consegue nomear o sacrifício, você não decidiu — você chutou.

---

## IAM e segurança (o pilar mais crítico — comece por aqui)

**Tese:** IAM é onde os maiores desastres da AWS acontecem, e quase sempre por excesso de permissão ou credencial de longa duração vazada. O modelo mental: **identidades** (quem) recebem **policies** (o que pode) para agir sobre **recursos**. Prefira sempre **roles** (credencial temporária, rotacionada automaticamente) a **access keys** estáticas (credencial que vaza em commit, log e print).

Conceitos que você precisa distinguir na revisão:

| Conceito | O que é | Quando usar |
|---|---|---|
| **Root user** | Dono da conta, poder total | **Nunca no dia a dia.** Ative MFA, guarde, use só para tarefas que exigem root (fechar conta, mudar billing). |
| **IAM User** | Identidade humana de longa duração | Cada vez menos — prefira SSO/Identity Center federado. |
| **IAM Role** | Identidade *assumível*, credencial temporária | Padrão para serviços (EC2, Lambda), cross-account, federação, CI/CD. |
| **Policy** | Documento JSON que concede/nega permissão | Anexada a user/role/recurso. Least privilege: comece negando, libere o mínimo. |
| **Permission Boundary** | Teto máximo de permissão de uma identidade | Delegar criação de roles sem permitir escalada de privilégio. |
| **SCP (Organizations)** | Guarda-corpo em nível de conta/OU | Proibir regiões, proibir desligar CloudTrail, mesmo para admins da conta. |

**Least privilege na prática:** `Action` e `Resource` específicos, nunca `"*"`. Use condições (`aws:SourceIp`, `aws:PrincipalTag`). `iam:PassRole` e `"*:*"` são os sinais de policy perigosa — permitem escalada. Compare:

```json
// ANTI-PADRÃO: acesso total a tudo — qualquer key vazada = conta inteira comprometida
{ "Effect": "Allow", "Action": "*", "Resource": "*" }

// LEAST PRIVILEGE: só ler objetos de um prefixo de um bucket
{
  "Effect": "Allow",
  "Action": ["s3:GetObject"],
  "Resource": "arn:aws:s3:::balancie-uploads/incoming/*",
  "Condition": { "IpAddress": { "aws:SourceIp": "203.0.113.0/24" } }
}
```

**Trust policy (quem pode assumir a role):** a *permission policy* diz o que a role pode fazer; a *trust policy* diz quem pode virar a role. Para CI/CD via OIDC (ex.: GitHub Actions), a trust policy fixa o provedor **e** o repositório/branch — sem isso, qualquer repo do GitHub poderia assumir sua role:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::111122223333:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike": { "token.actions.githubusercontent.com:sub": "repo:balancie/balancie-api:ref:refs/heads/main" }
  }
}
```

**Elimine access keys de longa duração:**
- **EC2/ECS/Lambda** → instance profile / task role (a própria plataforma injeta credencial temporária).
- **EKS** → **IRSA** (IAM Roles for Service Accounts) via OIDC do cluster; cada pod assume só a role que precisa.
- **CI/CD (GitHub Actions, GitLab)** → **OIDC federation**: o pipeline assume uma role via token de curta duração, zero secret guardado.
- **Fora da AWS (on-prem, outra nuvem)** → **IAM Roles Anywhere** (certificado X.509) em vez de key estática.

**Multi-account:** uma conta só é anti-padrão em produção séria. Separe por blast radius e billing — conta de prod, de dev, de segurança/log, de rede. Use **AWS Organizations** + **Control Tower** (landing zone pronta com guardrails, SCPs e log centralizado). O isolamento de conta é a fronteira de segurança mais forte da AWS.

**Segredos e criptografia:**
- Senhas, tokens, connection strings → **Secrets Manager** (rotação automática) ou **SSM Parameter Store** (SecureString, mais barato, sem rotação nativa). Nunca em env var em texto plano de imagem/repo.
- Criptografia → **KMS** gerencia as chaves (SSE-KMS em S3/EBS/RDS). Habilite encryption at rest por padrão; hoje é praticamente de graça.

**Auditoria e detecção (habilite desde o dia 1):** **CloudTrail** (log de toda chamada de API — sem isso você é cego em incidente), **GuardDuty** (detecção de ameaça gerenciada), **Security Hub** (agrega findings e checa contra padrões como CIS/Well-Architected). Ative CloudTrail *organization-wide* num bucket de conta de log isolada.

**Acionável na revisão:** procure por access key estática em uso, `Resource: "*"` + `Action: "*"`, root sem MFA, CloudTrail desligado e conta única. Cada um desses é um achado, não um detalhe.

---

## Compute — qual escolher

**Tese:** desça o nível de abstração até onde a operação deixa de te dar valor. Mais controle (EC2) = mais responsabilidade (patch, scaling, AMI). Serverless (Lambda) elimina operação, mas impõe limites e um modelo de execução diferente.

| Serviço | Modelo | Você opera | Escolha quando |
|---|---|---|---|
| **EC2** | IaaS, VM | SO, patch, scaling, AMI | Precisa de controle total, licença específica, GPU, workload legado ou de longa duração previsível. |
| **ECS + Fargate** | Container serverless | Só a task/imagem | Container sem querer gerenciar nós; time pequeno; quer simplicidade acima de portabilidade. |
| **ECS + EC2** | Container em nós seus | Nós + cluster | Precisa de tipo de instância específico, GPU, ou economia com Spot/Reserved nos nós. |
| **EKS** | Kubernetes gerenciado | Workloads, add-ons, upgrades | Já tem k8s, precisa de ecossistema CNCF, portabilidade multi-cloud, ou escala/complexidade que justifica k8s. |
| **Lambda** | FaaS, event-driven | Só o código | Carga esporádica/event-driven, glue entre serviços, spiky. Cobra por invocação + duração. |
| **App Runner** | PaaS de container | Nada além do container | Web app/API simples, quer deploy de container sem tocar em rede/scaling. |

**Trade-offs de custo:** Lambda é imbatível para carga intermitente (paga zero quando ocioso) e caro para carga alta e constante (aí EC2/Fargate reservado ganha). Fargate custa mais por vCPU que EC2, mas você não paga a operação dos nós — some o custo de engenheiro na conta.

**Limites do Lambda que decidem contra ele:** timeout máx 15 min, memória até ~10 GB, payload limitado, **cold start** (latência p99 sofre), sem estado local durável. Workload de processamento longo, latência baixíssima e constante, ou que precisa de conexão persistente/stateful → não é Lambda.

**Quando serverless NÃO vale:** carga alta e previsível 24/7 (o preço por unidade de trabalho fica maior que container reservado), dependência forte de bibliotecas nativas pesadas, ou necessidade de controle fino de rede/kernel. Serverless troca custo por operação — quando a operação já é barata e a carga é constante, a troca deixa de compensar.

**Acionável:** parta do serverless/gerenciado e só desça de nível quando um limite concreto (custo constante alto, timeout, controle de SO) te empurrar. Justifique cada nível a menos de abstração.

---

## Rede (VPC)

**Tese:** a VPC é onde o custo esconde e a segurança começa. As duas decisões que mais doem depois: **NAT Gateway** (caro e fácil de multiplicar sem querer) e **Security Groups frouxos**.

- **VPC / subnets:** subnet **pública** (rota para Internet Gateway) só para o que precisa ser alcançado da internet (ALB, NAT). Tudo mais (app, banco) em subnet **privada**. Espalhe subnets por múltiplas AZs desde o começo.
- **IGW vs NAT Gateway:** IGW dá internet bidirecional (para subnet pública). **NAT Gateway** dá saída para internet a partir de subnet privada — e **cobra por hora + por GB processado**. Um NAT por AZ vira dinheiro de verdade. Para tráfego a serviços AWS (S3, DynamoDB, ECR), use **VPC Endpoints** e evite o NAT inteiro.
- **Security Group (stateful) vs NACL (stateless):** SG é firewall de instância, permite (não nega), lembra a conexão de volta — é onde você trabalha 95% do tempo. NACL é de subnet, permite e nega, é stateless (precisa liberar ida e volta) — use só para bloqueio amplo (banir um IP). Regra correta vs anti-padrão em porta de banco:

  ```
  # CORRETO: Postgres só do SG da aplicação, porta específica
  Ingress: TCP 5432  source = sg-app-0a1b2c   (não um CIDR aberto)

  # ANTI-PADRÃO: banco exposto à internet inteira
  Ingress: TCP 5432  source = 0.0.0.0/0
  ```
  Referenciar o SG de origem (`sg-app-...`) em vez de um CIDR é melhor: acompanha o auto scaling sem editar regra.
- **Balanceadores:** **ALB** (L7, HTTP/HTTPS, roteamento por path/host, WAF), **NLB** (L4, TCP/UDP, latência mínima, IP fixo, altíssimo throughput), **API Gateway** (REST/HTTP/WebSocket gerenciado, throttling, auth, ótimo com Lambda — mas custa mais por requisição em escala alta).
- **Route 53** (DNS, health checks, roteamento por latência/geo/failover) e **CloudFront** (CDN/edge, cacheia estático e dinâmico, termina TLS na borda, reduz latência e egress).
- **PrivateLink / VPC Endpoints:** exponha/consuma serviço sem passar pela internet. **Gateway Endpoint** (S3, DynamoDB — de graça) e **Interface Endpoint** (demais serviços — cobra, mas evita NAT e egress).

**Acionável na revisão:** conte os NAT Gateways e pergunte se cada um é necessário; troque tráfego AWS-para-AWS por VPC Endpoints; garanta que banco está em subnet privada; procure SG de banco aberto para `0.0.0.0/0`.

---

## Armazenamento e dados

**Tese:** escolher o banco errado é a decisão mais cara de reverter na AWS. Relacional quando o modelo e as queries são ricos e você quer JOIN/transação; NoSQL (DynamoDB) quando o padrão de acesso é conhecido, previsível e a escala é o requisito.

| Serviço | Tipo | Escolha quando |
|---|---|---|
| **S3** | Object storage | Arquivo, backup, data lake, estático, log. Durabilidade 11 noves. Base de quase tudo. |
| **EBS** | Bloco (1 instância/AZ) | Disco de uma EC2 (root, banco self-managed). Preso a uma AZ. |
| **EFS** | NFS compartilhado | Vários hosts leem/escrevem o mesmo filesystem; escala elástica. Mais caro que EBS. |
| **RDS** | Relacional gerenciado | Postgres/MySQL/etc. padrão, quer gerenciado sem reescrever. Multi-AZ para HA. |
| **Aurora** | Relacional AWS | Compatível Postgres/MySQL, storage auto-escalável, réplicas rápidas, Serverless v2 para carga variável. Custa mais que RDS base. |
| **DynamoDB** | NoSQL key-value | Escala massiva previsível, latência de milissegundo constante, serverless. Exige modelar por access pattern. |
| **ElastiCache** | Cache (Redis/Memcached) | Reduzir latência/carga do banco, sessão, rate limit, fila leve. |

**S3 — pontos de revisão:** **Block Public Account** ligado por padrão (bucket público sem intenção é vazamento clássico); **versionamento** para proteger de sobrescrita/delete; **lifecycle** para descer classe automaticamente (Standard → IA → Glacier → Deep Archive) conforme o dado esfria; escolha da classe = trade-off custo de armazenamento vs custo/latência de recuperação (Glacier é barato para guardar, caro e lento para ler).

O **Block Public Access** é o cinto de segurança — os quatro flags ligados barram qualquer ACL/policy pública, mesmo que alguém erre a policy depois:

```json
// Block Public Access (nível do bucket ou da conta) — o default seguro
{ "BlockPublicAcls": true, "IgnorePublicAcls": true,
  "BlockPublicPolicy": true, "RestrictPublicBuckets": true }

// Bucket policy que EXIGE TLS — nega qualquer acesso não-criptografado em trânsito
{
  "Effect": "Deny", "Principal": "*", "Action": "s3:*",
  "Resource": ["arn:aws:s3:::balancie-uploads", "arn:aws:s3:::balancie-uploads/*"],
  "Condition": { "Bool": { "aws:SecureTransport": "false" } }
}
```
Só desligue o Block Public Access no bucket específico que precisa servir conteúdo público (site estático), e mesmo assim prefira CloudFront com OAC na frente.

**Backup, RTO e RPO:** decida antes de precisar. **RPO** = quanto dado você aceita perder (janela entre backups); **RTO** = quanto tempo você aceita ficar fora (velocidade de restore). Multi-AZ do RDS cobre falha de AZ, **não substitui backup** (não protege de `DROP TABLE` nem de bug). Use snapshots automáticos + point-in-time recovery + cópia cross-region para desastre. Teste o restore — backup não testado é esperança, não backup.

**Acionável:** para cada dado persistido, saiba a classe/serviço, se está criptografado, e o RPO/RTO alvo. Para S3, confirme Block Public Access e lifecycle. Se não sabe o RTO/RPO, esse é o primeiro achado.

---

## Confiabilidade (design para falha)

**Tese:** o princípio operante da AWS é "everything fails all the time" (Werner Vogels). Confiabilidade não é evitar falha, é **se recuperar automaticamente** dela. Projete assumindo que a instância, a AZ e eventualmente a região vão cair.

- **Multi-AZ** (mínimo para produção): réplica em outra zona da mesma região, failover automático. Cobre a falha mais comum (queda de AZ). Custo moderado. **Deveria ser default em prod.**
- **Multi-Region** (para o crítico): sobrevive à perda de uma região inteira. Complexo e caro (replicação de dado, roteamento, consistência). Justifique com requisito real de RTO/RPO ou soberania de dado — não faça por reflexo.
- **Auto Scaling + health checks:** escale horizontalmente por métrica (CPU, fila, requisições); o load balancer tira o nó doente do rotativo. Prefira muitos nós pequenos a um grande (falha de um dói menos).
- **Desacoplamento assíncrono:** **SQS** (fila, absorve pico, retry, DLQ), **SNS** (pub/sub fan-out), **EventBridge** (event bus com roteamento por regra). Um consumidor lento ou fora do ar não derruba o produtor.
- **Idempotência:** com retry e entrega "at-least-once" (SQS, EventBridge), a mesma mensagem chega duas vezes. Toda operação precisa ser segura para reexecutar (chave de idempotência, upsert). Sem isso, retry vira cobrança/efeito duplicado.

**Quando NÃO investir em Multi-Region:** a esmagadora maioria dos sistemas está bem servida por Multi-AZ + backup cross-region. Multi-Region ativo-ativo é caro em dinheiro e em complexidade de consistência; só entra quando o custo do downtime regional supera claramente esse preço.

**Acionável na revisão:** produção sem Multi-AZ é achado; acoplamento síncrono onde a carga é spiky pede fila; qualquer consumidor de fila/evento sem tratamento de idempotência é bug latente.

---

## Custo (Cost Optimization)

**Tese:** na nuvem o custo é resultado de decisão de arquitetura, não de negociação. As maiores economias vêm de três lugares: **modelo de compra certo**, **right-sizing** e **matar custo escondido** (egress e NAT).

**Modelos de compra de compute:**

| Modelo | Desconto | Compromisso | Use para |
|---|---|---|---|
| **On-Demand** | 0% (base) | Nenhum | Carga imprevisível, curta, dev. |
| **Savings Plans** | até ~72% | Gasto $/h por 1-3 anos | Carga base estável (flexível entre serviços). Preferível a Reserved hoje. |
| **Reserved Instances** | até ~72% | Instância específica 1-3 anos | Carga muito estável e conhecida (ex.: RDS). |
| **Spot** | até ~90% | Pode ser tomada com 2 min de aviso | Batch, CI, workers stateless tolerantes a interrupção. Nunca para stateful crítico. |

**Right-sizing:** a instância que você provisionou "por garantia" é quase sempre grande demais. Meça (CloudWatch, Compute Optimizer) e reduza. Ligue **auto scaling** para não pagar pico o tempo todo.

**Custo escondido (onde a fatura surpreende):**
- **Egress (saída de dados para a internet):** cobrado por GB; tráfego entre AZs também cobra. CloudFront e VPC Endpoints reduzem. Entrada é geralmente grátis; saída não.
- **NAT Gateway:** hora + GB processado; multiplicado por AZ. Um dos maiores "de onde veio isso?" da fatura. Mini-cálculo (ordem de grandeza, us-east-1 ~US$0,045/h + ~US$0,045/GB processado):

  ```
  1 NAT, 24/7:            0,045 × 730h        ≈ US$ 33/mês só de estar ligado
  3 NATs (1 por AZ):      33 × 3              ≈ US$ 99/mês antes de 1 byte trafegar
  + 1 TB/mês processado:  0,045 × 1000 GB     ≈ US$ 45/mês por NAT em tráfego
  Total 3 AZs c/ 1 TB cada:                   ≈ US$ 234/mês
  ```
  Boa parte desse tráfego é seu app falando com **S3, DynamoDB, ECR, Secrets Manager** — serviços AWS. Um **Gateway Endpoint** (S3/DynamoDB) é *de graça* e tira esse tráfego do NAT; **Interface Endpoints (PrivateLink)** cobram por hora mas costumam sair mais barato que o NAT + egress equivalente, além de manterem o tráfego fora da internet pública.
- **S3:** classe errada (Standard para dado frio), versões antigas acumulando, requisições. Lifecycle resolve.

**Governança de custo:** **tags de billing** obrigatórias (owner, ambiente, projeto) — sem tag você não sabe quem gasta o quê; **Cost Explorer** para analisar tendência; **Budgets** para alertar/agir ao estourar limite. E o mais simples e mais esquecido: **desligue o que não usa** (ambiente de dev à noite, recurso órfão de POC).

**Acionável:** exija tag de custo em todo recurso; revise a fatura por serviço mensalmente atrás de NAT e egress; mova carga estável de On-Demand para Savings Plan; agende desligamento de ambientes não-produtivos.

---

## Observabilidade

**Tese:** sem observabilidade você não tem SRE, tem adivinhação. Na AWS o alicerce é o **CloudWatch**, e o objetivo é enxergar os **Golden Signals** (latência, tráfego, erros, saturação) e sustentar seus **SLOs**.

- **CloudWatch Metrics:** métricas nativas de cada serviço + custom metrics da aplicação. É onde vivem latência, throughput, erro e saturação.
- **CloudWatch Logs:** logs centralizados; **Logs Insights** para consulta. Defina retenção (log infinito é custo infinito).
- **CloudWatch Alarms:** alarme em cima de métrica → notifica (SNS) ou aciona (auto scaling, runbook). Alarme deve refletir **sintoma que dói para o usuário** (SLO), não ruído de recurso.
- **X-Ray:** tracing distribuído — segue a requisição entre serviços, acha o gargalo real em arquitetura de microserviços/serverless.

**Mapeamento em SLO:** latência e erros do ALB/API Gateway alimentam o SLI de disponibilidade e latência; o alarme dispara no **error budget** queimando, não em "CPU a 80%". CPU alta pode ser saúde; erro ao usuário nunca é.

**Acionável:** para cada serviço em produção, tenha dashboard com os 4 Golden Signals, retenção de log definida, e ao menos um alarme ligado a SLO (não a métrica de recurso solta).

---

## IaC na AWS

**Tese:** infraestrutura na AWS é código versionado — clicar no console em produção é anti-padrão. A escolha da ferramenta é trade-off entre portabilidade, integração nativa e linguagem.

| Ferramenta | Força | Fraqueza / quando evitar |
|---|---|---|
| **Terraform / OpenTofu** | Multi-cloud, ecossistema enorme, HCL declarativo, estado explícito | Gerenciar/travar o state é operação sua; drift com mudança manual. Padrão de mercado. |
| **CloudFormation** | Nativo, sem state para gerenciar, integração e rollback nativos | Só AWS, YAML verboso, evolução mais lenta. Bom se você é 100% AWS e quer zero infra de tooling. |
| **CDK** | Código real (TS/Python), abstrai boilerplate, gera CloudFormation | Curva e "mágica" de abstração; ainda amarrado ao CFN por baixo. Bom para time de dev que quer tipos e loops. |

**Acionável:** escolha uma e proíba mudança manual em produção; guarde o state de forma remota e travada (Terraform); revise o `plan`/changeset antes de aplicar. Console é para ler, não para escrever.

---

## Sinais de alerta na revisão/decisão

| Sinal | Por que é problema | Direção |
|---|---|---|
| **Root user no dia a dia / sem MFA** | Comprometimento = perda total da conta | MFA no root, guardar; usar roles/Identity Center. |
| **Access key estática em serviço** | Vaza em commit/log; não rotaciona | IAM Role (instance profile, IRSA, OIDC no CI). |
| **Policy com `Action:"*"` / `Resource:"*"` / `iam:PassRole` amplo** | Escalada de privilégio, blast radius total | Least privilege: ação e recurso específicos. |
| **S3 público sem intenção** | Vazamento de dado clássico | Block Public Access; política explícita só onde precisa. |
| **`0.0.0.0/0` em SG de banco** | Banco exposto à internet | Restringir a SG/subnet da aplicação; banco em subnet privada. |
| **Sem Multi-AZ em produção** | Queda de uma AZ derruba tudo | Multi-AZ como default de prod. |
| **CloudTrail desligado** | Cego em incidente e auditoria | CloudTrail org-wide em conta de log isolada. |
| **Sem tags de custo** | Impossível saber quem gasta / cortar | Tag obrigatória (owner, ambiente, projeto). |
| **NAT Gateway desnecessário** | Custo por hora + GB, multiplicado por AZ | VPC Endpoints para tráfego AWS; contar/justificar cada NAT. |
| **Tudo numa conta só** | Blast radius e billing sem isolamento | Multi-account via Organizations/Control Tower. |
| **Serverless para carga alta e constante** | Custo por unidade maior que container reservado | Reavaliar EC2/Fargate reservado ou Savings Plan. |
| **Backup não testado / sem RTO-RPO definido** | Restore falha na hora do desastre | Definir e testar restore; snapshot cross-region. |
| **Alarme em CPU em vez de SLO** | Ruído; não reflete dor do usuário | Alarme em latência/erro (Golden Signals). |
| **Mudança manual no console de prod** | Drift, irreproduzível, sem revisão | IaC com plan revisado; console só leitura. |

**Fechamento:** se numa revisão de arquitetura AWS você só puder fazer três perguntas, faça estas — "isso usa credencial temporária em vez de key estática?", "sobrevive à queda de uma AZ?" e "eu sei quanto isso custa e quem paga?". Elas cobrem Security, Reliability e Cost — os três pilares onde os erros de AWS mais machucam.
