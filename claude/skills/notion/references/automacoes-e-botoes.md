# Automações e Botões no Notion

O Notion tem quatro camadas de automação que muita gente confunde entre si: **buttons** (disparo manual), **database automations** (disparo por evento), **repeating templates** (disparo por tempo) e **agents/integrações externas** (disparo por qualquer coisa). Escolher a camada errada é a causa mais comum de automação frágil.

Este documento cobre o que cada uma faz, receitas completas, e — o mais importante — o que **não** automatizar no Notion.

---

## 1. Buttons

Botão é a automação de **disparo manual**. Alguém clica, uma sequência de ações roda. Disponível em todos os planos, embora certas ações exijam plano pago.

Para criar, editar ou clicar num botão você precisa de `Full access` ou `Can edit` na página.

Doc: [Buttons](https://www.notion.com/help/buttons).

### Ações disponíveis

| Ação | O que faz | Plano |
|---|---|---|
| **Insert blocks** | Insere blocos (texto, to-do, toggle, callout, subpágina) logo abaixo do botão | Todos |
| **Add page to** | Cria uma nova página num database, com propriedades pré-preenchidas | Todos |
| **Edit pages in** | Edita propriedades de páginas existentes num database, com filtro | Todos |
| **Open page** | Abre uma página ou URL | Todos |
| **Show confirmation** | Exibe um diálogo de confirmação antes de prosseguir | Todos |
| **Send notification to** | Notifica até **20 membros** do workspace | Todos |
| **Send Slack notification** | Manda mensagem para um canal do Slack | **Pago** |
| **Send mail via Gmail** | Envia e-mail com assunto e corpo customizados | **Pago** |
| **Send webhook** | Dispara um HTTP POST para uma URL | **Pago** |
| **Define variables** | Cria variáveis reutilizáveis nas etapas seguintes | Todos |

`Define variables` é o recurso que transforma botão de brinquedo em ferramenta. Ele permite capturar o resultado de uma etapa (por exemplo, a página recém-criada) e referenciá-lo nas etapas seguintes.

### Onde botões podem viver

**1. Como bloco numa página.** O caso mais comum. Um botão no topo de um dashboard: "Nova tarefa", "Registrar despesa", "Abrir incidente".

**2. Como propriedade de database (Button property).** Cada linha ganha seu próprio botão, e as ações têm acesso ao contexto **daquela linha**. É o uso mais poderoso e o mais subutilizado.

```
Database "Tasks"
┌───────────────────┬──────────┬───────────────┐
│ Nome              │ Status   │ Ações         │
├───────────────────┼──────────┼───────────────┤
│ Revisar contrato  │ Doing    │ [✅ Concluir] │
│ Migrar billing    │ Todo     │ [✅ Concluir] │
└───────────────────┴──────────┴───────────────┘
```

O botão `Concluir` numa Button property faz, num clique: `Status = Done`, `Completed at = @Today`, `Completed by = @Person`. Sem abrir a página, sem três cliques em selects.

**3. Dentro de um template de database.** O botão nasce em toda página criada a partir daquele template.

### Encadear ações

As ações rodam **em sequência, na ordem que você define**. Isso importa, porque etapas posteriores podem referenciar o resultado das anteriores.

Ordem que funciona:
```
1. Show confirmation          ← sempre primeiro, se houver ação destrutiva
2. Define variables           ← capture o que vai usar depois
3. Add page to [database]     ← cria
4. Edit pages in [database]   ← ajusta relacionados
5. Send notification          ← avisa
6. Open page                  ← leva o usuário ao resultado
```

`Open page` no final é o detalhe de UX que faz diferença: sem ele, o usuário clica, algo acontece em algum lugar, e ele não vê nada. Com ele, o botão parece funcionar.

### Limitações reais dos botões

- **Fórmulas não funcionam em todo lugar.** Em `Insert blocks` e em `Open URL`, fórmulas não são suportadas. Funcionam em `Add page to` e `Edit pages in`.
- **Notificação limitada a 20 pessoas.**
- **Botão quebra silenciosamente.** Se o database alvo foi deletado, a propriedade renomeada ou a conexão de terceiros expirou, o botão para de funcionar sem aviso claro. É a causa número um de "meu botão parou".
- **Não roda sozinho.** Botão é sempre manual. Se você quer agendamento, é outra camada.

### Receita completa — botão de captura rápida

**Objetivo:** botão no dashboard que cria uma task no inbox com data de hoje e me atribui, e já abre a página para eu digitar.

```
Botão: "➕ Nova task"

Ação 1 — Add page to → database "Tasks"
  Nome        = (vazio, o usuário digita)
  Status      = Inbox
  Owner       = @Person (quem clicou)
  Created     = @Today
  Priority    = Medium

Ação 2 — Open page → a página criada na Ação 1
```

Duas ações. Substitui: abrir database, clicar New, preencher 4 propriedades. De ~8 interações para 1.

### Receita completa — botão de fechamento de tarefa com log

**Objetivo:** Button property em `Tasks` que marca como concluída, carimba data e responsável, e registra numa database de log.

```
Botão (propriedade): "✅ Concluir"

Ação 1 — Show confirmation
  Título: "Concluir esta tarefa?"
  Botão:  "Concluir"

Ação 2 — Edit pages in → "Tasks", filtro: esta página
  Status       = Done
  Completed at = @Now
  Completed by = @Person

Ação 3 — Add page to → database "Activity log"
  Nome   = "Concluída: " + [nome da página atual]
  Tipo   = Task completed
  Quando = @Now
  Quem   = @Person
  Ref    = [relation para a página atual]

Ação 4 — Send Slack notification → canal #time-updates
  "✅ {Person} concluiu {Nome da task}"
```

### Receita completa — botão de escalação de incidente

**Objetivo:** durante um incidente, um clique cria a página de incidente, notifica o on-call e abre o canal.

```
Botão: "🔥 Abrir incidente"

Ação 1 — Show confirmation
  "Isso vai notificar o on-call. Confirmar?"

Ação 2 — Add page to → "Incidents"
  Título    = "Incidente " + @Today
  Severity  = SEV2
  Status    = Investigating
  Started   = @Now
  Commander = @Person

Ação 3 — Send Slack notification → #incidents
  "🔥 Novo incidente aberto por {Person}. Sev: SEV2."

Ação 4 — Send notification to → grupo On-call

Ação 5 — Open page → a página criada
```

---

## 2. Database automations

Automação de database é o **disparo por evento**. Você define o gatilho e as ações rodam sozinhas.

Doc: [Database automations](https://www.notion.com/help/database-automations).

### Triggers

| Trigger | Quando dispara | Observação |
|---|---|---|
| **Page added** | Uma nova página entra no database | Inclui páginas criadas via form, API, botão |
| **Property edited** | Uma propriedade específica muda | Suporta condição (`is set to`, `starts with`, etc.) |
| **Every {frequency}** | Recorrente: diário, semanal, mensal | Data de início/fim e timezone configuráveis |

**Detalhe crítico da doc oficial**, sobre múltiplos triggers combinados:

> "If you have multiple `is edited` triggers that must **all** occur for your automation to take place, those triggers need to happen within a small window of about three seconds."

Ou seja: se você quer "quando Status = Done **E** Approved = true", ambas as mudanças precisam ocorrer em ~3 segundos. Na prática humana isso quase nunca acontece — a pessoa marca um, pensa, marca outro 20 segundos depois. **A automação não dispara.**

A solução é usar um trigger só, com condição sobre uma propriedade calculada (uma fórmula que retorna verdadeiro quando ambas as condições valem), e disparar na edição dessa fórmula.

### Actions

| Ação | O que faz | Plano |
|---|---|---|
| **Edit property** | Muda propriedades da página que disparou | Pago |
| **Add page to** | Cria página em qualquer database | Pago |
| **Edit pages in** | Edita páginas em outro database (com filtro) | Pago |
| **Send notification to** | Notifica membros do workspace | Pago |
| **Send mail via Gmail** | Envia e-mail | Pago |
| **Send Slack notification** | Posta no Slack | **Free também** |
| **Send webhook** | HTTP POST para URL externa | Pago |
| **Define variables** | Variáveis via mentions/fórmulas | Pago |

**Nota de plano:** automações de database são recurso de plano pago. A única exceção é `Send Slack notification`, disponível no Free.

### Restrições que a doc declara explicitamente

- **"Automations won't take action on any pages whose access is restricted."** Se a automação tenta editar uma página que o criador não pode acessar, ela simplesmente não age.
- **Automações não disparam outras automações.** Não há encadeamento automático. Isso previne loops infinitos — e limita workflows multi-etapa.
- **Trigger recorrente não combina com outros triggers.**
- **`Every {frequency}` funciona com todas as ações exceto `Edit property`.**
- **E-mails podem levar até dois minutos** para chegar.
- Quem cria precisa ter acesso completo ao database.
- Automações de Slack **só podem ser editadas por quem as criou**. Se essa pessoa sai da empresa, a automação vira caixa-preta.

### Receita completa — mover task para "Doing" quando alguém é atribuído

```
Database: Tasks

Trigger: Property edited → "Owner"
  Condição: Owner is not empty

Action 1: Edit property
  Status     = Doing
  Started at = @Now

Action 2: Send notification to
  → [Owner] (a pessoa recém-atribuída)
```

Simples e de alto valor: elimina o ritual "atribuí mas esqueci de mudar o status".

### Receita completa — arquivar tarefas concluídas há mais de 30 dias

```
Database: Tasks

Trigger: Every day, às 03:00, timezone America/Sao_Paulo

Action: Edit pages in → "Tasks"
  Filtro: Status is Done
     AND  Completed at is before "30 days ago"
  Definir: Archived = true
```

Isso mantém as views de trabalho limpas sem ninguém precisar lembrar. Note que `Edit property` não funciona com trigger recorrente — por isso usamos `Edit pages in`.

### Receita completa — pipeline de conteúdo com aprovação

```
Database: Content

Automação 1
  Trigger: Property edited → Status is "Ready for review"
  Action 1: Edit property → Reviewer = @Editor-chefe
  Action 2: Send Slack notification → #conteudo
            "📝 {Title} pronto para revisão. Autor: {Author}"

Automação 2
  Trigger: Property edited → Status is "Approved"
  Action 1: Edit property → Approved at = @Now
  Action 2: Add page to → "Publishing queue"
            Title    = {Title}
            Source   = [relation para esta página]
            Publish  = {Scheduled date}
  Action 3: Send notification to → @Social media manager
```

Note que estas são **duas automações separadas**, não uma encadeada — porque automação não dispara automação.

### Receita completa — sincronizar rollup para propriedade real

**Problema:** você não pode filtrar nem agrupar por rollup de forma eficiente em algumas views, e rollups não disparam automações.

```
Database: Projects

Trigger: Property edited → "Tasks" (relation)
Action:  Edit property
  Task count = {rollup count de Tasks}   ← copia para número real
```

Isso "materializa" o rollup numa propriedade concreta, que aí sim pode ser usada em filtros, automações e charts.

### Receita completa — webhook para sistema externo

```
Database: Deals

Trigger: Property edited → Stage is "Closed won"

Action: Send webhook
  URL: https://hooks.seu-servico.com/notion/deal-won
  Payload inclui: Deal name, Amount, Owner, Closed date
```

O `Send webhook` é a válvula de escape para tudo que o Notion não faz nativamente. Do outro lado pode estar um n8n, uma Lambda, um Worker.

---

## 3. Repeating database templates

A camada de **disparo por tempo** para criação de conteúdo estruturado.

Doc: [Automate work with repeating database templates](https://www.notion.com/help/guides/automate-work-repeating-database-templates).

Como funciona: você cria um template de database (dropdown ao lado de `New` → `+ New template`), depois `...` ao lado do template → `Repeat`.

**Frequências:** diário, semanal, mensal, anual, ou `Custom` — a cada 3 dias, terças e quintas, a cada 2 meses. Você define data de início e horário de criação.

### Repeating template vs automação recorrente

| | Repeating template | Automação `Every {frequency}` |
|---|---|---|
| Cria página com **conteúdo do corpo** | **Sim** | Não (só propriedades) |
| Cria página com propriedades | Sim | Sim |
| Boa para agenda de reunião, checklist, relatório | **Sim** | Não |
| Boa para editar páginas existentes em lote | Não | **Sim** |
| Boa para notificar / integrar | Não | **Sim** |

**Regra:** se a coisa recorrente precisa nascer com estrutura no corpo (agenda, checklist, seções de relatório), é **repeating template**. Se é uma manutenção sobre dados existentes, é **automação recorrente**.

### Limitação de aninhamento

Da doc oficial: você **não pode aninhar um template dentro de um template que recorre diariamente**. Só é possível aninhar template dentro de template com recorrência semanal, mensal ou anual.

### Exemplo — daily standup

```
Database: Meetings
Template: "Daily standup"
Repeat: todo dia útil, 08:00

Propriedades:
  Type = Standup
  Date = data da criação
  Attendees = grupo Engineering

Corpo do template:
  ## O que foi feito ontem
  ## O que será feito hoje
  ## Bloqueios
  - [ ]
  ## Ações
  (database inline de tasks, filtrada por esta reunião)
```

### Exemplo — relatório mensal

```
Database: Reports
Template: "Monthly business review"
Repeat: dia 1 de cada mês, 07:00

Corpo:
  ## Números do mês
  (linked view de Metrics, filtrada pelo mês anterior)
  ## O que funcionou
  ## O que não funcionou
  ## Prioridades do próximo mês
```

---

## 4. Webhooks

O Notion tem webhooks nos dois sentidos, e a direção de entrada é novidade de 2026.

### Webhooks de saída (outgoing)

Disponíveis como ação em **buttons** e em **database automations**. Enviam um HTTP POST com payload JSON contendo as propriedades da página.

Exigem plano pago.

**Uso típico:** disparar um fluxo no n8n/Make/Zapier, chamar sua própria API, atualizar um sistema externo.

**Armadilha:** o webhook do Notion não tem retry visível nem log de falha acessível. Se o endpoint estiver fora do ar, você não fica sabendo. Para fluxos críticos, o receptor deve confirmar de volta escrevendo no Notion (via API), para você ter evidência do sucesso.

### Webhook triggers de entrada (beta, desde Notion 3.5)

Lançados em **13 de maio de 2026** como parte do Notion Developer Platform. Invertem o fluxo: **um app externo dispara um workflow dentro do Notion**.

Exemplos citados na release: fechar uma task quando um pull request faz merge; criar documentos de onboarding quando uma proposta é assinada.

Rodam sobre **Notion Workers** — um runtime hospedado onde você deploya código sem gerenciar servidor. Gratuito durante o beta, com passagem para cobrança por credits a partir de **11 de agosto de 2026**.

Docs: [Notion 3.5 — Notion Developer Platform](https://www.notion.com/releases/2026-05-13), [Understand pricing for Workers (beta)](https://www.notion.com/help/understand-pricing-for-workers).

Complementos do mesmo lançamento:
- **Notion CLI** — autenticar, ler/modificar conteúdo, buildar e deployar Workers via linha de comando
- **Database Sync (beta)** — puxar dados de qualquer API para um database Notion (Zendesk, Salesforce, etc.)
- **Custom Agent Tools (beta)** — lógica determinística em código como ferramenta de agente, mais confiável e mais barata que raciocínio de LLM
- **Connections dashboard** — aba única em settings para conexões pessoais, do workspace, tokens de API e conexões internas

Em **9 de julho de 2026** os Workers ganharam compartilhamento com dois níveis: `Can connect` (usar) e `Full access` (editar e reaproveitar).

---

## 5. Integrações nativas

Doc central: [Notion Connections & Integrations](https://www.notion.com/connections).

### As três formas de integrar

**1. Connected properties** — propriedades de database que puxam dados de outra ferramenta. Arquivos do Google Drive, designs do Figma, tickets do Zendesk, pull requests do GitHub, tudo dentro da linha do database. Doc: [Connected properties](https://www.notion.com/help/connected-properties).

**2. Synced databases** — um database Notion espelhando dados externos. Status de projetos do Jira, PRs do GitHub, tasks do Asana, visíveis e filtráveis dentro do Notion. Doc: [Synced databases](https://www.notion.com/help/synced-databases).

**3. AI Connectors** — dão à AI acesso de leitura à ferramenta externa para responder perguntas com citação da fonte. Doc: [Notion AI Connectors](https://www.notion.com/help/notion-ai-connectors).

### Por ferramenta

| Ferramenta | O que dá para fazer |
|---|---|
| **Slack** | Notificação por automação e botão; preview de links; AI Connector busca em threads. Slack Enterprise Grid suportado desde jul/2026 |
| **GitHub** | Connected property com PRs e issues; synced database; preview de links |
| **Jira** | Synced database; AI Connector; preview de issues |
| **Google Drive** | Connected property com arquivos; AI Connector busca em documentos; embed |
| **Figma** | Connected property; embed interativo de frames e protótipos |
| **Zoom / Google Meet** | Link de reunião em eventos; AI Meeting Notes captura o áudio |
| **Gmail** | Ação `Send mail via Gmail` em botões e automações; AI Connector para buscar e redigir |
| **Outlook** | Mail e Calendar conectados desde Notion 3.6 (jul/2026); agentes gerenciam inbox e agenda |

### MCP connections para Custom Agents

Custom Agents leem e agem através de conexões MCP pré-configuradas — Linear, Ramp, Figma e outras — ou por MCP customizado para qualquer app. Doc: [MCP connections for Custom Agents](https://www.notion.com/help/mcp-connections-for-custom-agents).

Cinco conexões novas chegaram em julho de 2026 (Notion 3.6): **Mercury, Mixpanel, Miro, Box e ClickHouse**.

### O que as integrações nativas *não* fazem

Sincronização **bidirecional com escrita**. Quase tudo é leitura. Você vê o ticket do Jira no Notion, mas mudar o status no Notion não muda no Jira. Para escrita bidirecional você precisa de automação externa ou da API.

---

## 6. Automação externa: Zapier, Make, n8n

### Quando compensa sair do Notion

Use ferramenta externa quando pelo menos uma for verdadeira:

- Precisa de **encadeamento** (automação A dispara B) — o Notion proíbe nativamente
- Precisa de **lógica condicional complexa** (if/else aninhado, switch)
- Precisa de **escrita bidirecional** com outro sistema
- Precisa de **transformação de dados** (parsear, agregar, formatar)
- Precisa de **retry e tratamento de erro** com visibilidade
- O gatilho vive **fora do Notion** e não há webhook trigger que sirva

### Quando não compensa

- Ação simples dentro do Notion → automação nativa
- Notificação para Slack → nativo
- Criação de página recorrente → repeating template
- Qualquer coisa que a automação nativa faça em uma etapa

Cada automação externa é uma dependência a mais, uma conta a mais para pagar, e um lugar a mais para procurar quando algo quebra.

### Comparação

| | Zapier | Make | n8n |
|---|---|---|---|
| Curva de aprendizado | Baixa | Média | Alta |
| Modelo de preço | Por task, caro em volume | Por operação, mais barato | Self-hosted grátis; cloud pago |
| Lógica complexa | Limitada | Boa (visual, ramificações) | Excelente (código quando precisar) |
| Self-hosting | Não | Não | **Sim** |
| Suporte ao Notion | Sólido | Sólido | Sólido |
| Melhor para | Fluxos lineares simples | Fluxos ramificados de negócio | Times técnicos, volume alto, dados sensíveis |

**Recomendação:** se o time é técnico e o volume passa de algumas centenas de execuções por mês, **n8n self-hosted** paga a conta rapidamente. Se ninguém no time quer manter infraestrutura, **Make** tem o melhor equilíbrio. **Zapier** só se a simplicidade valer o preço.

**Alerta de custo:** o modelo por task do Zapier explode com triggers de polling em databases movimentados. Um database com 200 mudanças por dia consome ~6.000 tasks/mês só no gatilho.

**Nota de 2026:** com os webhook triggers de entrada e os Notion Workers, parte do que exigia ferramenta externa agora roda dentro do Notion. Se o seu time escreve código, avalie Workers antes de contratar mais um SaaS de automação.

---

## 7. Notion Calendar e Notion Mail

### Notion Calendar

Aplicativo separado, **gratuito**, que unifica calendários pessoais e de trabalho.

- Conecta calendários **Google e Apple**
- Exibe e gerencia **databases do Notion** que tenham propriedade de data
- Eventos oferecem o campo **Add AI meeting notes**, que gera a página de notas no Notion
- Configurações de visualização: fins de semana, dia inicial da semana, idioma, formato de hora

Docs: [Notion Calendar](https://www.notion.com/help/category/notion-calendar), [Use Notion Calendar with Notion](https://www.notion.com/help/use-notion-calendar-with-notion).

Em **17 de abril de 2026** as conexões de Mail e Calendar foram unificadas numa aba própria de settings, sincronizando entre Notion, Notion Mail e Notion Calendar. Doc: [Manage your Mail & Calendar settings](https://www.notion.com/help/manage-email-and-calendar-settings).

Em **16 de julho de 2026**, os agentes ganharam ferramentas de calendário: exibir e gerenciar agenda, entrar em calls, enviar convites e encontrar horários livres via chat. Desktop primeiro, mobile anunciado como "em breve".

### Notion Mail — está sendo descontinuado

**O Notion Mail encerra em 22 de setembro de 2026**, em web, mobile e desktop.

Isto é confirmado pela doc oficial: [Notion Mail inbox is going away: what to do next](https://www.notion.com/help/notion-mail-inbox-is-going-away-what-to-do-next).

Razão declarada pela empresa: com os agentes ficando mais capazes, mais da metade dos usuários do Notion Mail gerenciava e-mail **sem nunca abrir a caixa de entrada**.

**O que acontece com seus e-mails:** nada. O Notion Mail sempre sincronizou nos dois sentidos com o Gmail — todo e-mail recebido ou enviado também existe no Gmail. O histórico permanece lá.

**O que você precisa exportar até 21 de setembro de 2026:**
- Rascunhos
- E-mails agendados
- Snippets
- Instruções de auto-label

A exportação está disponível desde 25 de junho de 2026, no app e na web.

**Se sua organização está sob HIPAA, o prazo é outro:** a saída do Notion Mail precisa acontecer até **30 de junho de 2026**, bem antes do encerramento geral.

**O que continua funcionando:** os **Gmail AI Connectors**, que permitem buscar e redigir e-mails dentro do Notion AI, e os **mail blocks** dentro de páginas do Notion. Ambos são independentes do app Notion Mail.

**Implicação prática:** não construa nenhum workflow novo em cima do Notion Mail. Se você tem automações dependendo dele, migre para o Gmail AI Connector ou para a ação `Send mail via Gmail`.

---

## 8. Limites e armadilhas

### Loops de automação

O Notion previne loops porque **automação não dispara automação**. Mas o loop volta quando você mistura camadas:

```
Automação Notion → webhook → n8n → API do Notion escreve propriedade
                                          ↓
                              dispara a mesma automação Notion
                                          ↓
                                        loop
```

**Como evitar:**
1. Escreva numa propriedade **diferente** da que dispara o gatilho
2. Adicione uma propriedade de guarda (`Synced at`) e condicione a escrita externa a ela
3. Use filtro de condição estreito no trigger (`is set to X`, não `is edited`)

### Latência

| Mecanismo | Latência esperada |
|---|---|
| Button | Imediato |
| Database automation (edit property) | Segundos |
| Database automation (e-mail) | **Até 2 minutos** (declarado na doc) |
| Trigger recorrente | Próximo do horário, sem garantia de precisão |
| Webhook de saída | Segundos |
| Repeating template | No horário configurado |

Nada disso é tempo real garantido. **Não construa nada dependente de latência sub-segundo no Notion.**

### O que não dispara automação

Esta lista economiza horas de depuração:

- Mudança feita **pela própria automação** (não encadeia)
- Mudança em **rollup** (rollup é derivado, não editado)
- Mudança em **formula** (recalculada, não editada)
- Mudança de **conteúdo do corpo** da página (só propriedades disparam)
- Páginas com **acesso restrito** ao criador da automação
- **Múltiplos triggers `is edited`** que não ocorrem na janela de ~3 segundos

A armadilha do rollup e da fórmula é a mais dolorosa: "quando o total de tasks passar de 10, notifique" **não funciona** se o total for rollup. Você precisa materializar o rollup numa propriedade real primeiro (ver receita na seção 2).

### Custo de automações em massa

`Edit pages in` sobre um database grande é lento e pode falhar parcialmente. Numa base de 10.000 linhas, uma automação diária tocando todas as linhas é abuso da ferramenta.

**Mitigue:** filtre agressivamente. `Edit pages in Tasks where Status is Done AND Completed at is before 30 days ago` toca dezenas de linhas, não milhares.

### Automações órfãs

Automações de Slack **só podem ser editadas por quem as criou**. Quando essa pessoa sai da empresa, a automação continua rodando e ninguém consegue mexer.

**Prevenção:** mantenha uma página `Automations registry` documentando cada automação — o que faz, quem criou, qual database, qual canal. É chato e é o que salva você.

---

## 9. Tabela de decisão: quero automatizar X → use Y

| Quero... | Use | Por quê |
|---|---|---|
| Criar uma página com campos pré-preenchidos, sob demanda | **Button** (`Add page to`) | Manual e instantâneo |
| Fechar uma task em um clique, da própria linha | **Button property** | Contexto da linha, zero navegação |
| Mudar status quando alguém é atribuído | **Database automation** (`Property edited`) | Evento, não ação humana |
| Notificar o Slack quando um deal fecha | **Database automation** + Slack | Nativo, funciona no Free |
| Criar a agenda do standup toda manhã | **Repeating template** | Precisa de corpo estruturado |
| Arquivar tasks antigas toda noite | **Database automation** (`Every day` + `Edit pages in`) | Manutenção em lote |
| Enviar e-mail quando um formulário é preenchido | **Database automation** (`Page added` + Gmail) | Form cria página no database |
| Sincronizar um rollup para uma propriedade filtrável | **Database automation** (`Property edited` na relation) | Rollup não dispara nada |
| Chamar minha própria API | **Send webhook** (button ou automation) | Válvula de escape |
| Disparar algo no Notion a partir de um app externo | **Webhook trigger** (Workers, beta) | Único caminho nativo de entrada |
| Encadear: automação A dispara B | **n8n / Make / Zapier** | O Notion proíbe encadeamento |
| Escrever de volta no Jira/GitHub | **Automação externa ou API** | Integrações nativas são só leitura |
| Puxar dados de uma API para um database | **Database Sync** (beta) ou n8n | Sync é nativo, beta |
| Ver PRs do GitHub dentro da linha | **Connected property** | Nativo, zero código |
| Responder perguntas sobre docs do Drive | **AI Connector** | Busca com citação |
| Rotina complexa, condicional, 24/7 | **Custom Agent** | Consome credits — ver custo |
| Gerar ata de reunião | **AI Meeting Notes** | Nativo, com speaker labels desde jul/2026 |
| Lógica determinística barata dentro de um agente | **Custom Agent Tool** (Worker) | Mais confiável e mais barato que LLM |

---

## 10. Ordem de escolha (o algoritmo)

Quando alguém pedir "automatiza isso", percorra nesta ordem e pare no primeiro que resolve:

1. **Dá para fazer com um botão?** → Button. Mais barato, mais previsível, sem custo recorrente.
2. **É reação a uma mudança de propriedade?** → Database automation.
3. **É criação recorrente com estrutura?** → Repeating template.
4. **É manutenção recorrente em lote?** → Database automation com `Every {frequency}`.
5. **Precisa de dado externo, só leitura?** → Connected property / Synced database / AI Connector.
6. **Precisa de encadeamento, condicional complexo ou escrita externa?** → Webhook + n8n/Make.
7. **O gatilho é externo?** → Webhook trigger (Workers).
8. **Precisa de julgamento, não de regra?** → Custom Agent. **Último recurso** — é o único que custa por execução.

O erro mais comum é começar pelo passo 8. Agente para o que uma automação de duas etapas resolveria é caro, mais lento e não-determinístico.

---

## Fontes

- [Buttons](https://www.notion.com/help/buttons)
- [Database automations](https://www.notion.com/help/database-automations)
- [Database templates](https://www.notion.com/help/database-templates)
- [Automate work with repeating database templates](https://www.notion.com/help/guides/automate-work-repeating-database-templates)
- [Using database templates to help cement your team's process](https://www.notion.com/help/guides/using-database-templates-for-teams)
- [Notion Connections & Integrations](https://www.notion.com/connections)
- [Connected properties](https://www.notion.com/help/connected-properties)
- [Synced databases](https://www.notion.com/help/synced-databases)
- [Notion AI Connectors](https://www.notion.com/help/notion-ai-connectors)
- [Slack AI Connector](https://www.notion.com/help/notion-ai-connectors-for-slack)
- [MCP connections for Custom Agents](https://www.notion.com/help/mcp-connections-for-custom-agents)
- [Understand pricing for Workers (beta)](https://www.notion.com/help/understand-pricing-for-workers)
- [Notion Calendar](https://www.notion.com/help/category/notion-calendar)
- [Use Notion Calendar with Notion](https://www.notion.com/help/use-notion-calendar-with-notion)
- [Manage your Mail & Calendar settings](https://www.notion.com/help/manage-email-and-calendar-settings)
- [Notion Mail inbox is going away: what to do next](https://www.notion.com/help/notion-mail-inbox-is-going-away-what-to-do-next)
- [Notion 3.5 — Notion Developer Platform](https://www.notion.com/releases/2026-05-13)
- [Notion 3.6 — External Agents, HTML blocks, and more](https://www.notion.com/releases/2026-07-01)
