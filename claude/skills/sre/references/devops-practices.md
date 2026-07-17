# Cultura DevOps, SLO e confiabilidade como prática

DevOps não é um time nem um cargo — é a decisão de otimizar o *sistema* de entrega
inteiro (dev + ops + segurança) em vez de otimizar cada silo. Este arquivo traz o
raciocínio para revisar cultura, definir confiabilidade em números (SLO/error
budget), medir entrega (DORA), controlar toil, operar on-call/incidentes e desenhar
times. A tese que costura tudo: **confiabilidade e velocidade são consequência de
fluxo, feedback e aprendizado — não de heroísmo.**

## Os Três Caminhos e a cultura que os sustenta

**Tese (Kim, *The DevOps Handbook*).** Todo ganho durável de entrega vem de três
princípios, nesta ordem: **Fluxo** (esquerda→direita: acelerar o trabalho de dev
para produção reduzindo batch size e work in progress), **Feedback** (direita→
esquerda: encurtar o loop entre falha e quem pode corrigi-la) e **Aprendizado
contínuo** (transformar cada incidente em melhoria do sistema, não em punição).

Lote pequeno é a alavanca central: reduz o custo do erro, o tempo até detectá-lo e
o tamanho do que precisa ser revertido. WIP alto esconde o problema — a fila cresce
antes de qualquer alerta disparar.

**Cultura Westrum** classifica organizações pelo fluxo de informação, e *Accelerate*
provou que cultura generativa prediz performance de entrega:

| Dimensão | Patológica (poder) | Burocrática (regra) | Generativa (performance) |
|---|---|---|---|
| Informação ruim | é escondida | é ignorada | é investigada |
| Mensageiro | é punido | é tolerado | é treinado/recompensado |
| Responsabilidade | terceirizada | compartimentada | assumida coletivamente |
| Falha | vira bode expiatório | vira "justiça" processual | vira aprendizado |

**Trade-off.** Cultura não se decreta; muda por incentivos e rituais (postmortem
blameless, error budget, ownership de ponta a ponta). Ferramenta sem mudança de
incentivo só acelera o caos existente.

**Quando NÃO aplicar dogmaticamente.** Em time minúsculo (1-3 devs) e produto
pré-PMF, o overhead de rituais formais pode custar mais que o problema que resolve —
o "sistema" ainda cabe na cabeça de uma pessoa. Formalize quando a coordenação, não
o código, virar o gargalo.

> Em revisão: ao ver "quem foi o culpado?" numa retro ou um mensageiro punido por
> reportar risco, pergunte se a cultura está tratando informação ruim como algo a
> esconder — é o sinal Westrum patológico e mata todo o resto.

## Métricas DORA: medir entrega sem enganar a si mesmo

**Tese (Forsgren/Humble/Kim, *Accelerate*).** Quatro métricas capturam performance
de entrega de software, e a descoberta empírica é que **velocidade e estabilidade
não são trade-off** — times de elite lideram nas quatro simultaneamente. Quem
"desacelera para ficar estável" normalmente piora as duas (lotes grandes, deploys
raros e arriscados).

| Métrica | O que mede | Eixo | Elite | Low |
|---|---|---|---|---|
| **Deployment Frequency** | com que frequência se entrega a produção | velocidade | on-demand (várias/dia) | < 1 por mês |
| **Lead Time for Changes** | commit → rodando em produção | velocidade | < 1 dia | > 1 mês |
| **Change Failure Rate** | % de deploys que causam falha/rollback | estabilidade | 0-15% | > 40% (faixas antigas) |
| **Time to Restore (MTTR)** | tempo para recuperar de falha em produção | estabilidade | < 1 hora | > 1 semana |

Como raciocinar com elas: as duas primeiras (throughput) e as duas últimas
(estabilidade) devem melhorar **juntas**. Deploy raro é sintoma, não segurança —
força lotes grandes, que elevam Change Failure Rate e Lead Time. Melhorar Deployment
Frequency (lotes menores) tipicamente derruba MTTR e CFR de tabela.

**Trade-off.** DORA mede o sistema de entrega, não valor de negócio nem qualidade
de código. Otimizar a métrica pelo número (deploys vazios para inflar frequência)
é Goodhart — a métrica vira alvo e deixa de medir. Use como termômetro de tendência
do time, jamais como meta individual ou comparação entre times de contextos
diferentes.

**Quando NÃO aplicar.** Batch/ETL de baixa cadência, firmware, sistemas
regulatórios com janela fixa de release: Lead Time e Deploy Frequency perdem
significado; foque em CFR e MTTR.

> Em revisão: ao ver alguém propor "deployar menos para ter mais estabilidade",
> pergunte pelos números — a evidência DORA diz o contrário; lote menor é o que
> compra estabilidade.

## SLI, SLO, SLA e error budget

**Tese (Google SRE).** Confiabilidade precisa de um alvo numérico explícito, senão
o alvo implícito vira 100% — o número errado, porque é caro e desnecessário. Defina
os três termos e nunca os confunda:

| Termo | O que é | Exemplo | Público |
|---|---|---|---|
| **SLI** | *indicador*: uma métrica de saúde, geralmente uma razão de eventos bons/total | % de requests com latência < 300ms | interno |
| **SLO** | *objetivo*: a meta que o SLI deve cumprir num período | 99,9% num mês | interno (o alvo real) |
| **SLA** | *acordo*: contrato com o cliente + consequência (multa/crédito) se romper | 99,5% ou reembolso | externo/legal |

Regra prática: o **SLO é mais rígido que o SLA** (folga para reagir antes de virar
problema contratual). O SLI mede; o SLO define o "bom o bastante"; o SLA é a
promessa comercial com dente.

**Error budget = 1 − SLO.** Um SLO de 99,9%/mês dá ~43,2 min de indisponibilidade
permitida. Esse orçamento é *permissão para arriscar*: enquanto sobra budget, o time
pode fazer releases, experimentos e migrações. A **política de error budget** amarra
isso a ação: quando o budget do período **esgota**, congela-se feature e o time
redireciona esforço para confiabilidade (bugs, hardening, testes) até voltar dentro
do SLO. Isso remove a briga "dev quer entregar × ops quer estabilidade" — o número
decide, não a hierarquia.

**Trade-off.** SLO alto demais gasta budget em engenharia cara de resiliência para
ganho que o usuário nem percebe; baixo demais queima confiança. Comece pelo que o
usuário sente e ajuste com dados, não pela vaidade dos "noves".

**Quando NÃO aplicar.** Serviço interno best-effort, PoC, ou dependência sem impacto
direto no usuário não precisam de SLO formal — a política de congelamento seria
teatro. SLO existe onde há usuário que sofre com a falha.

> Em revisão: ao ver "SLO de 100%" ou disponibilidade sem número, pare — 100% é o
> alvo errado (impossível e sem budget para arriscar). Pergunte "qual é o SLI, qual
> a meta, e o que acontece quando o budget acaba?".

## Toil, os Golden Signals e alerting

**Toil (definição precisa, SRE).** Trabalho que é **manual, repetitivo,
automatizável, sem valor duradouro e que escala linearmente** com o serviço.
Reiniciar um serviço na mão a cada alerta é toil; escrever o script que o faz sozinho
não é. Meta do SRE: manter toil **< 50%** do tempo do time, senão a equipe vira
suporte de operação e para de melhorar o sistema.

**Quatro Golden Signals** para monitorar qualquer serviço voltado a usuário — se só
puder medir quatro coisas, meça estas:

| Signal | Pergunta | Cuidado |
|---|---|---|
| **Latency** | quão rápido responde? | separe latência de sucesso da de erro; use percentis (p99), não média |
| **Traffic** | quanta demanda? | req/s, transações/s — baseline para o resto |
| **Errors** | taxa de falha? | inclua "sucesso mentiroso" (200 com conteúdo errado) |
| **Saturation** | quão cheio? (recurso mais restrito) | prever o esgotamento antes de bater 100% |

**Alerting: sintoma, não causa.** Alerte no que o usuário sente (SLO/Golden Signals:
"latência p99 > 1s", "error rate acima do budget"), não em cada causa possível
("CPU 90%"). CPU alta com SLO saudável não é incidente — é ruído que acorda gente à
toa. Causa vira dado de diagnóstico no dashboard; sintoma que fura SLO vira page.

**Trade-off.** Automatizar toil tem custo inicial; vale quando `custo de automatizar
< frequência × custo manual × horizonte`. Nem todo toil compensa eliminar hoje.

> Em revisão: ao ver um alerta que dispara em recurso/causa (CPU, disco, memória)
> em vez de sintoma de usuário, pergunte "isso afeta o SLO? se não, por que acorda
> alguém?". E ao ver toil crescente sem item de automação no backlog, sinalize a
> tendência de 50%.

## On-call saudável, incidentes e postmortem

**Tese.** On-call é sustentável só quando o alerting é bom (poucos, acionáveis),
a carga é humana e o aprendizado é institucionalizado. On-call que só apaga incêndio
e nunca corrige a causa é dívida operacional com juros.

**On-call saudável:** alertas acionáveis (todo page tem runbook e ação), rotação
que respeita descanso, tempo protegido para reduzir toil/melhorar alertas, e
compensação/reconhecimento. Fadiga de alerta (page ruidoso) é a causa raiz de
incidente perdido — o sinal real se afoga no ruído.

**Gestão de incidentes (roles):** separe papéis para não ter uma pessoa fazendo
tudo sob pressão.

| Papel | Responsabilidade |
|---|---|
| **Incident Commander (IC)** | coordena, decide, NÃO debuga; dono do incidente |
| **Ops/Tech Lead** | executa mitigação técnica |
| **Communications** | atualiza stakeholders/status page |
| **Scribe** | registra timeline e decisões para o postmortem |

Métricas do ciclo: **MTTD** (tempo até detectar) e **MTTR** (tempo até restaurar).
Mitigar > diagnosticar: restaurar o serviço (rollback, failover) vem antes de
entender a causa raiz. A causa raiz é trabalho do postmortem, com o sistema já de pé.

**Postmortem blameless.** Foca no *sistema* que permitiu a falha, não na pessoa que
apertou o botão. Premissa: pessoas competentes agem racionalmente com a informação
que tinham; se erraram, o sistema (ferramenta, alerta, doc, guardrail) as deixou
errar. Culpado gera ocultação (volta à cultura patológica); blameless gera dados.

**Trade-off.** Blameless não é ausência de responsabilidade — accountability é do
sistema e das ações de melhoria, com dono e prazo. Postmortem sem action item com
responsável é catarse, não engenharia.

**Quando NÃO aplicar postmortem completo.** Incidente trivial e recorrente-conhecido
pode virar só um item de backlog; reserve o postmortem formal para o que teve
impacto de usuário, foi novo, ou quase-desastre (near miss também merece).

> Em revisão: ao ver um postmortem que nomeia um culpado ("fulano derrubou"),
> reescreva para o sistema ("um deploy sem canary + ausência de rollback automático
> permitiram X"). E ao ver postmortem sem action items com dono/prazo, ele não
> fechou.

## Team Topologies: desenhar times como se desenha arquitetura

**Tese (Skelton/Pais).** A estrutura de times determina a arquitetura do sistema
(**Conway's Law**: o software espelha a comunicação da organização). Logo, para
obter a arquitetura desejada, projete os times para produzi-la (**inverse Conway
maneuver**). E a restrição de projeto de time é a **carga cognitiva**: um time só
entrega bem o que cabe na sua cabeça coletiva.

**Quatro tipos de time:**

| Tipo | Propósito | Exemplo |
|---|---|---|
| **Stream-aligned** | fluxo de valor de ponta a ponta para um segmento; é o time "padrão", os demais existem para servi-lo | squad de pagamentos |
| **Platform** | oferece serviços internos como produto (self-service) para reduzir carga dos stream-aligned | time de infra/paved road |
| **Enabling** | ajuda outros times a adquirir capacidade que lhes falta; temporário | especialistas em testes/segurança que capacitam |
| **Complicated-subsystem** | encapsula complexidade que exige especialista raro | motor de risco, codec de vídeo |

**Três modos de interação:**

| Modo | Quando | Duração |
|---|---|---|
| **Collaboration** | descoberta, problema novo/mal definido; alto aprendizado, alta fricção | curta, deliberada |
| **X-as-a-Service** | fronteira clara e estável; um consome o serviço do outro | duradoura (o modo-alvo da plataforma) |
| **Facilitating** | um time ajuda/desbloqueia outro (típico do enabling) | temporária |

Regra: interação é *modo*, não permanente. Collaboration prolongada entre dois times
é sinal de fronteira mal desenhada — vire para X-as-a-Service quando a interface
estabilizar.

**Trade-off.** Plataforma cedo demais (antes de existirem streams sofrendo) é
over-engineering — vira time gargalo procurando problema. Plataforma existe para
*diminuir* carga cognitiva de quem entrega; se ela vira fila de ticket, inverteu o
propósito e virou o gargalo que deveria eliminar.

**Quando NÃO aplicar.** Organização pequena não precisa dos quatro tipos — um único
stream-aligned resolve. Formalize platform/enabling quando a carga cognitiva de
infra começar a roubar tempo de produto de vários times.

> Em revisão: ao ver um time que todos precisam esperar para entregar (ticket para
> subir ambiente, DBA que aprova toda migration), você achou o gargalo — pergunte se
> aquilo deveria ser self-service (X-as-a-Service / paved road). E ao ver dois times
> em collaboration permanente, questione a fronteira.

## Continuous Delivery: o princípio cultural (o detalhe mora em outro arquivo)

**Tese (Humble/Farley).** Tudo que vai a produção passa pela **mesma esteira
automatizada**, e o pipeline é a **fonte única de verdade** sobre o que é
"pronto para produção". Deploy manual e ambiente de floco de neve são incompatíveis
com feedback rápido. O objetivo: tornar o release um evento **entediante** e
reversível, não um ritual de fim de semana.

Princípios acionáveis aqui (mecânica de pipeline fica em `cicd-github-actions.md` /
`cicd-azure-pipelines.md`): automatize tudo que se repete; construa o artefato uma
vez e promova o mesmo binário por ambiente; feedback rápido antes do lento (lint →
unit → integração → e2e); se o pipeline está vermelho, parar a linha é prioridade.

**Quando NÃO aplicar CD contínuo pleno.** Contexto regulatório com aprovação humana
obrigatória ou release atômico de hardware: mantenha *Continuous Delivery* (sempre
deployável) mesmo sem *Continuous Deployment* automático até produção. A esteira e a
reversibilidade continuam valendo; só o gatilho final é manual.

> Em revisão: ao ver um deploy que roda comandos manuais fora do pipeline, ou build
> diferente por ambiente, pergunte "onde está a fonte única de verdade?" — se o
> release depende de alguém lembrar de passos, não é CD.

## Sinais de alerta na revisão (resumo)

| Sinal | Por que é problema | O que perguntar/fazer |
|---|---|---|
| SLO de 100% (ou sem número) | impossível e sem error budget para arriscar | definir SLI, SLO realista e política de budget |
| Alerta em causa (CPU/disco), não em sintoma | acorda gente à toa, afoga o page real | alertar no que fura SLO / Golden Signals |
| Postmortem com culpado nomeado | gera ocultação, cultura patológica | reescrever focado no sistema; blameless |
| Postmortem sem action item com dono/prazo | catarse, não engenharia | atribuir dono e prazo a cada melhoria |
| Toil crescente sem item de automação | time vira suporte, para de melhorar | rastrear % de toil; meta < 50% |
| "Deployar menos para ser estável" | contraria a evidência DORA | lote menor melhora CFR e MTTR juntos |
| Time gargalo criando fila (ticket para tudo) | quebra fluxo, eleva Lead Time | virar para self-service / X-as-a-Service |
| Collaboration permanente entre dois times | fronteira mal desenhada | estabilizar interface e virar as-a-Service |
| Deploy com passos manuais fora do pipeline | sem fonte única de verdade, não reprodutível | automatizar na esteira; build uma vez |
| Alerta ruidoso / fadiga de on-call | incidente real se perde no ruído | reduzir a alertas acionáveis com runbook |
| Métrica DORA como meta individual | Goodhart: vira alvo, deixa de medir | usar como tendência do sistema, não do indivíduo |
