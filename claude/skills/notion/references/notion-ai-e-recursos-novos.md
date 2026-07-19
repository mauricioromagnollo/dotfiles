# Notion AI e Recursos Recentes

**Estado deste documento:** julho de 2026. O Notion mudou mais entre janeiro e julho de 2026 do que nos dois anos anteriores. Se você tem conhecimento anterior a 2026, boa parte dele sobre AI e sobre pricing está **errada** hoje.

Este arquivo separa explicitamente o que foi confirmado na documentação oficial do que não deu para verificar.

---

## 1. As mudanças de 2026 que quebram conhecimento antigo

| O que você provavelmente "sabe" | O que é verdade em julho de 2026 |
|---|---|
| Notion AI é add-on de ~$8–10/membro comprável em cima de qualquer plano | **Falso.** AI é parte do **Business e Enterprise**. Free e Plus só recebem "complimentary responses" limitadas |
| Notion AI é cobrado por assento, uso ilimitado | **Falso.** Existe um sistema de **Notion credits** para Custom Agents, com pool no nível do workspace |
| Notion Mail é o novo app de e-mail da empresa | **Falso.** **Encerra em 22 de setembro de 2026** |
| Notion AI é um assistente de escrita inline | **Incompleto.** Existem **Custom Agents** autônomos com trigger e schedule, e **External Agents** (Claude, Cursor) orquestrados dentro do Notion |
| Não dá para rodar código no Notion | **Falso.** **Notion Workers** é um runtime hospedado, desde maio de 2026 |
| Webhooks do Notion são só de saída | **Falso.** **Webhook triggers** de entrada existem em beta desde maio de 2026 |
| O Notion não funciona offline | **Falso.** Offline mode existe desde agosto de 2025, em todos os planos |

---

## 2. Notion AI: o que é, hoje

### Plano necessário

Texto literal da doc oficial em [What is Notion AI?](https://www.notion.com/help/notion-ai-faqs):

> "Notion AI is only available on Business and Enterprise Plans. Users on the Free and Plus Plans get a limited number of complimentary AI responses so they can try Notion AI features out."

Note a nuance: não é que Free e Plus não tenham acesso nenhum. Qualquer um pode **experimentar** o Notion AI; o que exige upgrade para Business ou Enterprise é o **uso contínuo**, depois que as respostas de cortesia acabam. O caminho mais barato para AI de verdade é **Business, $20/membro/mês** no anual. Ver [Notion AI complimentary responses](https://www.notion.com/help/complimentary-ai-responses) para o detalhe das respostas de cortesia.

**Enterprise** adiciona **zero data retention** com os provedores de LLM — o argumento que destrava aprovação jurídica em empresa regulada.

### Onde a AI aparece

| Superfície | O que faz |
|---|---|
| **Inline no editor** | `Espaço` numa linha vazia ou seleção + `Ask AI`. Escrever, reescrever, resumir, traduzir, mudar tom, continuar |
| **AI blocks** | Blocos que vivem na página e se atualizam conforme o conteúdo muda |
| **AI properties (autofill)** | Colunas de database preenchidas por AI |
| **Ask Notion (Q&A / Enterprise Search)** | Pergunta em linguagem natural sobre o workspace **e fontes conectadas** (Slack, Drive, Jira), com citação |
| **AI Meeting Notes** | Transcrição e sumarização de reunião |
| **Custom Agents** | Agentes autônomos com trigger, schedule e ferramentas |
| **External Agents** | Claude, Cursor e outros, orquestrados dentro do Notion |

### O que a AI do Notion faz bem

**Busca com contexto (Ask Notion).** É o recurso mais valioso, de longe. Um workspace com 3.000 páginas é praticamente sem busca útil na busca lexical; com Q&A você pergunta "qual é a política de reembolso de viagem?" e recebe a resposta **com link para a página fonte**. O AI Connector estende isso para Slack, Google Drive e Jira, o que resolve o problema real de "a informação está em algum lugar, em alguma ferramenta".

**Meeting notes.** Transcrição, resumo, extração de itens de ação. Desde **1º de julho de 2026** com **speaker labels** — identificação de quem falou baseada em microfones ativos — o que melhora bastante a atribuição de follow-ups. Também passou a aceitar **upload de áudio** gravado em outras plataformas.

**Resumo de conteúdo longo.** Resumir uma thread de 40 comentários ou um doc de 20 páginas é trabalho que ninguém quer fazer e a AI faz aceitavelmente.

**Tradução.** Boa o suficiente para comunicação interna.

**Reformatação.** "Transforme este texto corrido em tabela" funciona muito bem, porque a saída tem estrutura verificável.

### O que a AI do Notion faz mal

**Escrever conteúdo original de qualidade.** Sai genérico. Todo texto gerado tem a mesma cadência e o mesmo vocabulário. Leitores identificam. Para conteúdo que representa você ou a empresa, o tempo de editar excede o tempo de escrever.

**Raciocinar sobre dados numéricos do database.** Ela lê propriedades como texto. Para agregação e cálculo, rollups e fórmulas são certos e determinísticos; a AI é aproximada.

**Manter consistência entre execuções.** Rodar o mesmo AI autofill duas vezes gera saídas diferentes. Isso torna a AI inadequada para qualquer coisa que alimente relatório ou decisão auditável.

**Trabalhar sobre um workspace bagunçado.** Isto é o ponto mais importante deste documento: **a AI amplifica a arquitetura que você tem**. Se há três versões contraditórias da política de férias, o Ask Notion cita uma delas — possivelmente a errada — com confiança total. Limpar o workspace é pré-requisito de AI útil, não consequência.

### Quando vale usar, quando é ruído

| Situação | Veredito |
|---|---|
| "Onde está a doc sobre X?" | **Use.** É o melhor caso de uso |
| Resumir reunião de 1h | **Use.** Economia real de tempo |
| Traduzir comunicado interno | **Use** |
| Extrair itens de ação de notas | **Use**, mas revise |
| Escrever post de blog | **Não use** como saída final |
| Escrever spec técnica | **Não use.** O valor da spec está no raciocínio, não no texto |
| Preencher 500 linhas com resumo AI | **Cuidado.** Ver seção de custo |
| Categorizar tickets automaticamente | **Use** se erro de ~10% for aceitável |
| Calcular métricas | **Nunca.** Use fórmula |
| Decidir prioridade de roadmap | **Não.** Isso é julgamento, e ela não tem o contexto que você tem |

---

## 3. AI properties em databases (autofill)

Doc: [Notion AI for databases](https://www.notion.com/help/autofill) e a lição [AI Autofill property](https://www.notion.com/help/notion-academy/lesson/ai-autofill-property).

### Como criar

Adicione uma propriedade do tipo **Text** e selecione **Set up fill with AI**. Depois escolha entre resumo automático ou prompt próprio. Alternativamente: passe o mouse sobre a propriedade, clique no nome, `AI Autofill`.

### Os tipos

| Tipo | O que faz | Bom para |
|---|---|---|
| **AI Summary** | Resume o conteúdo da página e **atualiza conforme o conteúdo muda** | Notas de reunião, docs longos, tickets |
| **Custom Autofill** | Saída de texto a partir do seu prompt | Extração estruturada, classificação |
| **AI Keywords** | Categoriza e etiqueta itens automaticamente | Triagem inicial de base grande |
| **AI Translation** | Traduz conteúdo selecionado | Workspace multilíngue |

### Basic Autofill vs Custom Agent Autofill — a distinção que define o custo

Esta é a diferença mais importante e a que menos gente conhece:

| | Basic Autofill | Custom Agent Autofill |
|---|---|---|
| Para que serve | Preenchimentos simples: resumo, tagging, tradução | Trabalho complexo: busca na web ou no workspace, instruções multi-etapa |
| Custo | **Incluído no Business e Enterprise** | **Consome Notion credits** conforme o trabalho |
| Previsibilidade de custo | Total | Variável |

**Regra:** use Basic Autofill sempre que ele resolver. Custom Agent Autofill num database de milhares de linhas é uma forma eficiente de queimar credits sem perceber.

### Casos de uso que valem

**1. Triagem de inbox de suporte.**
```
Database: Support tickets
Propriedade "Categoria" (AI Keywords)
→ classifica em Bug / Feature request / Dúvida / Cobrança
```
Não precisa ser perfeito; precisa ser melhor que "sem categoria nenhuma". Um humano corrige os erros ao trabalhar o ticket.

**2. Resumo de notas de reunião.**
```
Database: Meetings
Propriedade "Resumo" (AI Summary)
→ view de tabela mostra o resumo sem abrir cada página
```
Este é o melhor uso do AI Summary, porque a propriedade **se atualiza** conforme as notas evoluem.

**3. Extração estruturada de candidatos.**
```
Database: Candidates
Propriedade "Anos de experiência" (Custom Autofill)
Prompt: "Leia o currículo anexo. Retorne apenas o número total de
anos de experiência profissional. Se não conseguir determinar,
retorne 'N/D'. Nenhum outro texto."
```
Prompts de autofill devem ser **restritivos e com fallback explícito**. Sem o "nenhum outro texto", você recebe parágrafos numa coluna que deveria ter um número.

**4. Tradução de base de conhecimento.**
```
Database: Help articles
Propriedade "Título (EN)" (AI Translation)
```

### Casos onde não vale

- **Qualquer coisa que precise ser exata.** Valor de contrato, data de vencimento, CNPJ. Extraia com código ou digite.
- **Databases muito grandes com Custom Agent Autofill.** Custo linear ao número de linhas.
- **Propriedade que alimenta automação.** Saída não-determinística disparando automação é fonte de comportamento errático.
- **Quando um select manual resolve.** Se são 4 categorias óbvias e 20 itens por semana, a AI é overhead.

### O custo real

Basic Autofill está incluído. Custom Agent Autofill puxa credits. Da doc de credits, os fatores de consumo são:

> "Custom Agents use credits based on the work needed to complete a run. In general, they will use more credits when they read more content, take more actions, or run more often."

Ou seja: quantidade lida, número de etapas, frequência e modelo escolhido.

**Aritmética que evita surpresa:** com estimativas de $0,03 a $0,30 por run (ver seção 4), um Custom Agent Autofill sobre 2.000 linhas custa entre **$60 e $600** numa única passada. Rode primeiro em 20 linhas, meça, extrapole.

---

## 4. Custom Agents e Notion credits

### O que são

Custom Agents chegaram em **beta gratuito em 24 de fevereiro de 2026** (Notion 3.3), em Business e Enterprise. São assistentes autônomos que rodam por trigger ou schedule, sem prompt manual.

Doc: [Notion 3.3 — Custom Agents](https://www.notion.com/releases/2026-02-24).

Capacidades declaradas:
- Responder perguntas repetitivas usando Notion, Slack, Mail, Calendar e conexões MCP
- Rotear e triar tarefas, capturando pedidos e direcionando a pessoas
- Gerar relatórios de status em agenda (standup diário, recap semanal, OKR mensal)
- Integrar com Slack, Figma, Linear, HubSpot, FigJam

### Linha do tempo de 2026

| Data | O que |
|---|---|
| Jan 2026 (3.2) | AI Notes no mobile, seletor de modelos renovado, people directory |
| 24 fev (3.3) | **Custom Agents** em beta gratuito, Business e Enterprise |
| 14 abr (3.4 pt.2) | Custom Agents mais fáceis de ajustar; **AI Autofill** trazendo agentes para dentro dos databases |
| 17 abr | Mail & Calendar unificados numa aba de settings |
| 4 mai | Home tab do mobile redesenhada |
| 5 mai | **Controles de admin para Custom Agents**: restrição de quem cria, limites de credits por agente e por workspace, dashboard de gasto, notificação e pausa automática |
| 6 mai | **Custom Agent Directory** — biblioteca do workspace para navegar, favoritar e criar agentes |
| 7 mai | **Plan Mode** — o agente pede esclarecimento e monta plano antes de mudanças grandes |
| 13 mai (3.5) | **Notion Developer Platform**: Workers, Database Sync, Custom Agent Tools, webhook triggers, CLI, Agent SDK, connections dashboard |
| 26 mai | Merge de células em simple tables |
| 1 jul (3.6) | **External Agents**, HTML blocks, speaker labels, arquivos Office, Outlook, 5 MCPs novos |
| 8 jul | **App iOS de Notion Agents** |
| 9 jul | **Shared Notion Workers** (`Can connect` / `Full access`) |
| 16 jul | Ferramentas de calendário para agentes |

Fonte: [What's New – Notion](https://www.notion.com/releases).

### O sistema de credits

Não existe uma data única de corte: a doc diz que os agentes seguem rodando até a **primeira data mensal de serviço do workspace em ou após 4 de maio de 2026** — é nesse ciclo de faturamento que eles passam a consumir credits. Ou seja, o dia exato varia conforme a data de faturamento de cada workspace. Doc: [Buy & track Notion credits for Custom Agents](https://www.notion.com/help/buy-and-track-notion-credits-for-custom-agents).

**O que se sabe com confirmação:**

- Custo: **$10 por 1.000 credits mensais**
- Credits **resetam mensalmente**. Se sobra saldo acumula para o mês seguinte ou não, **não foi confirmado em fonte oficial direta** — não planeje orçamento assumindo nenhum dos dois
- O pool é **do workspace**, compartilhado — qualquer Custom Agent puxa do mesmo saldo, não importa quem criou ou executou
- Admins são notificados em **80% e 100%** do uso
- É possível comprar credits no meio do ciclo, mas alterações valem no próximo período de faturamento
- Ao esgotar credits em Business/Enterprise, os **outros recursos de AI continuam funcionando** (AI Meeting Notes, Notion Agent) até um **fair use limit**
- Enterprise multi-workspace pode alocar limites por workspace — ver [Allocate credits to each workspace](https://www.notion.com/help/allocate-credits-to-each-workspace)

**Estimativas de custo por execução, da doc oficial:**

| Tipo de agente | Custo por run |
|---|---|
| Q&A | ~$0,03 – $0,11 |
| Roteamento de tarefas | ~$0,05 – $0,15 |
| Atualização de status | ~$0,08 – $0,18 |
| Triagem de e-mail | ~$0,04 – $0,10 |
| Briefing diário | ~$0,10 – $0,30 |

**Aritmética que você precisa fazer antes de ligar qualquer agente:**

```
Agente de briefing diário, 1 run/dia, 22 dias úteis
  22 × $0,20 (média)  = $4,40/mês        → trivial

Agente de Q&A no Slack, 50 perguntas/dia
  50 × 22 × $0,07     = $77/mês          → precisa de justificativa

Agente de triagem em database movimentado, 300 runs/dia
  300 × 30 × $0,07    = $630/mês         → provavelmente uma automação nativa resolve
```

**O padrão que se repete:** agentes com trigger de evento em databases movimentados são o que estoura orçamento. Agentes agendados são baratos e previsíveis.

**Não confirmado:** quantos credits vêm incluídos no Business e no Enterprise por assento. A doc de credits que consultei não traz o número, e o valor pode variar por contrato. **Confirme na tela de billing do workspace antes de dimensionar.**

### Controles de admin (desde 5 de maio de 2026)

Recursos que existem e que você **deve** ligar antes de liberar agentes ao time:

- Restringir quem pode criar agentes
- Limite de credits **por agente** e **do workspace**
- Dashboard de uso com gasto por agente
- Notificação e **pausa automática** ao estourar
- Monitoramento entre múltiplos workspaces
- **Audit log de atividade de Custom Agents** (Enterprise, desde jul/2026)

Sem esses controles, um agente mal configurado com trigger em database ativo consome o pool do workspace inteiro em dias.

### External Agents (desde 1º de julho de 2026)

Notion 3.6 abriu o Notion como **camada de orquestração para agentes de terceiros**. Os dois primeiros são **Claude** e **Cursor**.

O que muda na prática: você atribui tarefas a eles a partir de um board compartilhado com o time, menciona com `@` como se fossem colegas, e acompanha a execução. O Notion vira o lugar onde trabalho humano e trabalho de agente coexistem no mesmo quadro.

Complementos: **External Agents API** (alpha) para trazer Claude, Codex, Decagon ou agentes próprios; **Agent SDK** (alpha) para embutir agentes do Notion em ferramentas externas (CRM, Teams, Discord, dashboards).

### Modelos disponíveis

Notion 3.6 cita suporte a **Opus 4.8, Grok 4.3 e o open-weight GLM 5.2**, com o argumento de escolher entre raciocínio de fronteira, velocidade e custo.

**Consequência de custo:** modelo mais avançado consome mais credits. Se o agente faz classificação simples, escolher o modelo mais forte é desperdício direto.

---

## 5. Notion Forms

Doc: [Forms](https://www.notion.com/help/forms).

### Como funciona

Formulários são **conectados a databases**. Da doc:

> "Forms are connected to databases, so each question in your form is connected to a property in your database."

Cada resposta vira uma **linha** do database. As respostas aparecem numa view de tabela chamada **Responses**.

Essa é a diferença fundamental para Typeform e Google Forms: no Notion, a resposta já nasce como **item de trabalho**, dentro do sistema onde você vai processá-la. Não há exportação, não há sincronização, não há Zapier no meio.

### Campos e configuração

Tipos suportados acompanham os tipos de propriedade do database: texto, múltipla escolha, data, select, pessoa, arquivo, número. Você configura exibição das opções (lista ou dropdown), resposta longa, e obrigatoriedade.

### Lógica condicional

**Exclusiva de Business e Enterprise.** Da doc: permite "customize what questions are shown to respondents based on their responses".

No Plus você tem forms customizados sem marca do Notion, mas sem ramificação.

### Compartilhamento

- Só membros do workspace (com link)
- Público na web
- Toggle de respostas anônimas
- Controle do nível de acesso do respondente às submissões

### Limitações que importam

**Não dá para criar ou customizar form no mobile.** Só web e desktop. Responder funciona em qualquer lugar.

**Sem pagamento.** Nada de Stripe.

**Sem cálculo no formulário.** Não dá para somar campos e mostrar total ao respondente.

**Sem salvar parcialmente.** Formulário longo perdido é formulário perdido.

**Personalização visual limitada.** Você ajusta cor e cover, não o layout.

**Analytics básico.** Sem funil de abandono, sem tempo por campo.

### Quando usar o Notion Forms e quando não

| Situação | Ferramenta |
|---|---|
| Pedido interno (TI, férias, compras) que vira task | **Notion Forms** |
| Candidatura a vaga que alimenta pipeline | **Notion Forms** |
| Inscrição em evento interno | **Notion Forms** |
| Coleta de feedback do time | **Notion Forms** |
| Pesquisa pública de marca com identidade visual forte | **Typeform** |
| Formulário com pagamento | **Typeform / Tally / Stripe** |
| Pesquisa acadêmica com validação complexa | **Google Forms / Qualtrics** |
| Volume muito alto (milhares/dia) | **Ferramenta dedicada** — o database vira lento |

**A regra:** se a resposta precisa virar trabalho dentro do Notion, use Notion Forms mesmo que ele seja mais feio. A ausência de integração vale mais que a estética.

---

## 6. Notion Sites

Docs: [Publish a Notion Site](https://www.notion.com/help/public-pages-and-web-publishing), [Notion Sites availability & pricing](https://www.notion.com/help/notion-sites-availability-and-pricing), [Connect a custom domain](https://www.notion.com/help/connect-a-custom-domain-with-notion-sites), [Edit & customize your Notion Sites](https://www.notion.com/help/edit-and-customize-your-notion-sites).

### O que dá para fazer

| Recurso | Free | Pago |
|---|---|---|
| Publicar sites (quantidade) | **Ilimitado** | Ilimitado |
| Domínios `notion.site` | 1 | **Até 5** |
| Indexação por buscadores | Sim | Sim |
| Customização de homepage | Não | Sim |
| Personalização (tema, aparência) | Não | Sim |
| Google Analytics | Não | **Sim** |
| Domínios customizados | Não | **Até 25**, via add-on |
| Título e descrição para SEO | Sim | Sim |

**Add-on de domínio customizado:** $10/mês (mensal) ou **$8/mês** (anual). **Cada domínio exige um add-on separado.** O ciclo de faturamento tem que casar com o da assinatura Notion; entradas no meio do ciclo são pro-rateadas.

O Notion **não vende domínios**. Você traz o seu, registrado em outro lugar.

### SEO: o que dá e o que não dá

**Dá:**
- Ligar/desligar indexação
- Customizar título e descrição da página (usado em preview de compartilhamento e em SERP)
- Google Analytics (plano pago)

**Não dá:**
- Controle sobre estrutura de URL além do slug básico
- Sitemap customizado
- Tags Open Graph por página com controle fino
- Dados estruturados / schema.org
- Controle de redirects (301)
- Otimização de imagem (formato, lazy loading, srcset)
- Controle de Core Web Vitals

### Quando NÃO usar o Notion como site

Esta seção é a que mais importa, porque o Notion Sites é bom o suficiente para você se enganar.

**Não use quando SEO é o canal de aquisição.** O Notion não te dá as alavancas: sem schema, sem controle de performance, sem redirects. Se tráfego orgânico é a estratégia, use um framework de verdade.

**Não use quando performance importa comercialmente.** Páginas do Notion carregam mais lentamente que um site estático. Em landing page de conversão paga, isso é dinheiro.

**Não use quando a marca precisa ser distinta.** Site do Notion parece site do Notion. Um olho treinado identifica em dois segundos.

**Não use para e-commerce, área logada, ou qualquer coisa transacional.** Não existe.

**Não use quando você precisa de A/B testing.**

**Use quando:**
- Documentação pública / changelog / help center
- Página de vaga, careers page
- Wiki público de comunidade ou projeto open source
- Portfólio pessoal
- Landing page temporária de evento
- Qualquer coisa onde a **velocidade de atualização** vale mais que a apresentação — e o Notion ganha muito nesse quesito: você edita e está no ar

**O teste decisivo:** se você atualizaria essa página mais de uma vez por semana, o Notion é ótimo. Se você a construiria uma vez e não tocaria mais, use outra coisa.

---

## 7. Notion Charts

Doc: [Charts](https://www.notion.com/help/charts).

### Tipos disponíveis

Cinco: **vertical bar, horizontal bar, line, donut, number**.

### Como criar

Duas formas: `/chart` numa página, ou `+` ao lado do nome do database para criar uma view de chart.

### Plano

- **Free: um chart por workspace.** Você pode deletar e criar outro, mas não ter dois.
- **Pago: ilimitado.**

### Limites técnicos confirmados

- Máximo **200 grupos e 50 subgrupos**
- **Não dá para editar dados a partir da view de chart.** "Use or create another view to edit your data"
- Sem edição a partir de drilldown e sem ações em lote lá
- **Não visualiza:** rollups, buttons, unique IDs, propriedades de arquivo/mídia, e certas fórmulas complexas
- Fórmulas complexas podem deixar o carregamento lento

### Veredito

Charts do Notion são para **acompanhamento operacional**, não para análise. Cinco tipos, sem eixo secundário, sem combinação de tipos, sem escala logarítmica, sem anotação.

**Bom para:** contagem de tasks por status no dashboard do time, tendência de tickets por semana, distribuição de conteúdo por autor.

**Ruim para:** qualquer coisa que alguém apresente a um board.

**A limitação que mais frustra:** rollups não podem ser plotados. Como métricas úteis costumam ser rollups ("total de horas do projeto"), a solução é materializar o rollup numa propriedade de número via database automation, e plotar essa propriedade.

---

## 8. Notion Calendar

App separado e **gratuito**.

- Conecta calendários **Google e Apple**
- Exibe e gerencia **databases do Notion** com propriedade de data
- Campo **Add AI meeting notes** direto no evento, gerando a página de notas no Notion
- Configurações: exibir fins de semana, dia inicial da semana, idioma, formato de hora

Docs: [Notion Calendar](https://www.notion.com/help/category/notion-calendar), [Manage your calendars & events](https://www.notion.com/help/manage-your-calendars-and-events), [Use Notion Calendar with Notion](https://www.notion.com/help/use-notion-calendar-with-notion).

**Novidades de 2026:**
- **17 de abril:** Mail e Calendar reunidos numa aba de settings; conexões sincronizam entre Notion, Notion Mail e Notion Calendar
- **16 de julho:** agentes ganharam ferramentas de calendário — exibir e gerenciar agenda, entrar em calls, enviar convites, encontrar horários livres, tudo por chat. Desktop disponível, mobile anunciado como "em breve"

**Veredito honesto:** o Notion Calendar é um bom cliente de calendário. A razão para usá-lo em vez do Google Calendar é a ligação com databases e o botão de meeting notes. Se você não usa nenhum dos dois, não há motivo para trocar.

---

## 9. Notion Mail — está sendo descontinuado

**O Notion Mail encerra em 22 de setembro de 2026**, em web, mobile e desktop.

Confirmado em: [Notion Mail inbox is going away: what to do next](https://www.notion.com/help/notion-mail-inbox-is-going-away-what-to-do-next).

**Motivo declarado:** com os agentes ficando mais capazes, mais da metade dos usuários gerenciava e-mail **sem nunca abrir a caixa de entrada**.

**Seus e-mails estão seguros.** O Notion Mail sempre sincronizou bidirecionalmente com o Gmail — todo e-mail recebido ou enviado também existe lá. O histórico permanece.

**Exporte até 21 de setembro de 2026:**
- Rascunhos
- E-mails agendados
- Snippets
- Instruções de auto-label

Exportação disponível desde 25 de junho de 2026, via app ou web.

**Prazo mais curto para HIPAA:** organizações sob conformidade HIPAA precisam sair do Notion Mail até **30 de junho de 2026** — bem antes do encerramento geral.

**O que sobrevive:** os **Gmail AI Connectors**, que permitem buscar e redigir e-mails dentro do Notion AI, e os **mail blocks** dentro de páginas do Notion. Ambos são independentes do app Notion Mail e continuam funcionando.

**O que fazer:** não construa nada novo sobre o Notion Mail. Se há workflows dependendo dele, migre para o Gmail AI Connector ou para a ação `Send mail via Gmail` em botões e automações.

---

## 10. Layouts e customização de páginas de database

O Notion evoluiu a customização da **página individual** de um item de database — como as propriedades são dispostas quando você abre uma linha.

O que se pode ajustar, em linhas gerais: quais propriedades aparecem no topo versus escondidas, agrupamento e ordem de propriedades, e a apresentação geral da página do item.

**Marcado como não totalmente confirmado:** tentei acessar a página de help específica sobre database layouts e recebi 404 na URL que testei, o que sugere que a doc foi reorganizada em 2026. Os detalhes exatos de opções e requisitos de plano de layouts **não foram verificados**. Confirme em [Database properties](https://www.notion.com/help/database-properties) e no Help Center antes de afirmar especificidades.

Mudança de edição confirmada em 2026: **26 de maio de 2026** trouxe **merge de células em simple tables** — dá para juntar células para criar cabeçalhos que abrangem colunas ou agrupar linhas.

Novidade relevante de layout em 3.6 (1º de julho): **interactive HTML blocks**. Agentes do Notion criam componentes interativos embutidos no documento — calculadoras de ROI, quizzes de time, organogramas — editáveis pelo time sem ferramenta externa.

---

## 11. Marketplace e templates

O [Notion Marketplace](https://www.notion.com/templates) hospeda templates gratuitos e pagos, oficiais e de criadores.

**Como avaliar um template antes de adotar:**

| Sinal | Leitura |
|---|---|
| Mais de 6 databases | Você não vai manter isso |
| Fórmulas com mais de 10 linhas | Impossível de depurar quando quebrar |
| Requer plano superior ao seu | Vai quebrar em partes silenciosamente |
| Muitos rollups aninhados | Lento e frágil |
| Screenshots com 40 propriedades | Otimizado para vender, não para usar |

**Regra prática:** o melhor uso de template é como **referência de estrutura**, não como sistema pronto. Abra, veja como modelaram as relations, feche, construa o seu com metade do tamanho.

O único caso em que adotar direto compensa é um template pequeno e específico (um único database de CRM, um tracker de hábitos). Sistemas de vida completos com 15 databases interligados são abandonados em semanas.

Existe também um **Custom Agent Directory** desde 6 de maio de 2026 — biblioteca do workspace para navegar, favoritar e criar agentes — e uma "hall of fame" de Custom Agents com exemplos prontos, lançada com o 3.5.

---

## 12. Notion offline

Docs: [Use pages offline](https://www.notion.com/help/use-pages-offline), [Working offline in Notion](https://www.notion.com/help/guides/working-offline-in-notion-everything-you-need-to-know).

O offline mode chegou em **agosto de 2025** (Notion 2.53) e é frequentemente desconhecido por quem carrega a impressão de que "o Notion não funciona sem internet".

**Como funciona:**

- Disponível em **desktop e mobile**. **Não funciona no navegador.**
- **Todos os membros, em todos os planos**, podem usar páginas offline
- Para marcar manualmente: abra a página → menu `•••` → toggle `Available offline`. Uma barra de progresso mostra o download
- Downloads são **por dispositivo**. Baixar no celular não disponibiliza no laptop
- **Em planos pagos**, o Notion baixa automaticamente páginas visitadas recentemente e favoritadas
- Offline você pode **ver, editar e criar** páginas. As mudanças salvam localmente e sincronizam quando a conexão volta

**O que não funciona offline:** busca no workspace inteiro, AI, automações, conteúdo não baixado previamente, e qualquer integração.

**Recomendação prática:** antes de viagem ou voo, marque manualmente as páginas que vai precisar. Não confie no download automático — ele cobre recentes e favoritos, não o que você vai precisar amanhã.

---

## 13. Os apps do Notion

| App | Nota |
|---|---|
| **Desktop** (macOS, Windows) | A melhor experiência. Atalhos, offline, múltiplas janelas. Use este |
| **Web** | Idêntico ao desktop menos offline. Bom para máquina emprestada |
| **Mobile** (iOS, Android) | Bom para consumo e captura rápida. Ruim para edição estruturada. **Não cria nem customiza forms.** Home tab redesenhada em 4 mai/2026 com acesso de um swipe a home, chats, meetings e inbox |
| **Notion Agents (iOS)** | App novo, lançado **8 de julho de 2026**. Agentes rodando no celular, para preparar tarefas e capturar ideias fora do escritório |
| **Web Clipper** (extensão) | Salva páginas web em um database. Vale ligar se você tem database de leitura |
| **Notion Calendar** | App separado, gratuito, desktop e mobile |
| **Notion Mail** | **Encerra 22/09/2026** |
| **Notion CLI** | Desde maio/2026, via npm. Suporte a Windows adicionado em jul/2026. Autenticar, ler e modificar conteúdo, buildar e deployar Workers |

---

## 14. O que não consegui confirmar

Registro explícito, para você não repetir como fato:

1. **Quantidade de Notion credits incluída por assento no Business e no Enterprise.** A doc de credits detalha preço ($10 por 1.000) e mecânica de pool, mas não achei o número base incluído. Pode variar por contrato Enterprise. **Confirme na tela de billing.**
2. **O valor exato do "fair use limit"** que se aplica quando os credits acabam em Business/Enterprise. A doc menciona o conceito sem quantificar.
3. **Detalhes de database layouts** — a URL de help que testei retornou 404, sugerindo reorganização da doc em 2026. Opções específicas e requisitos de plano não verificados.
4. **Estado de GA vs beta** de Database Sync, Custom Agent Tools, webhook triggers e Agent SDK em julho de 2026. Foram anunciados como beta/alpha em maio; podem ter avançado.
5. **Preço final dos Notion Workers** após 11 de agosto de 2026, quando saem do beta gratuito e passam a cobrar por credits.
6. **Se External Agents consomem credits do Notion**, e em qual proporção, versus consumirem a assinatura do provedor externo (Claude, Cursor).
7. **Limites de bloco no plano Free** para workspaces colaborativos — o número circula em fontes de terceiros mas não localizei confirmação oficial atual.

Quando qualquer um desses importar para uma decisão, verifique em [notion.com/help](https://www.notion.com/help) e em [notion.com/releases](https://www.notion.com/releases) antes de comprometer orçamento.

---

## 15. Resumo executivo

**Se você tem que lembrar de cinco coisas:**

1. **Notion AI é Business+ ($20/membro/mês).** O modelo de add-on acabou. Free e Plus só têm respostas de cortesia.
2. **Custom Agents custam por execução, via credits ($10 / 1.000).** Ligue os controles de admin antes de liberar ao time. Agente com trigger em database movimentado é o que estoura orçamento.
3. **Notion Mail morre em 22 de setembro de 2026.** Exporte rascunhos, agendados, snippets e auto-labels até 21/09. Seus e-mails estão no Gmail e ficam.
4. **O Notion virou plataforma de desenvolvimento em 2026** — Workers, CLI, webhook triggers de entrada, External Agents (Claude, Cursor). Se seu time escreve código, isso substitui parte do que você paga a Zapier/Make hoje.
5. **AI amplifica a arquitetura que você tem.** Workspace bagunçado com AI ligada produz respostas erradas com confiança total. Arrume a casa antes de comprar Business.

---

## Fontes

- [What is Notion AI?](https://www.notion.com/help/notion-ai-faqs)
- [Notion AI complimentary responses](https://www.notion.com/help/complimentary-ai-responses)
- [Notion AI for databases (autofill)](https://www.notion.com/help/autofill)
- [AI Autofill property — Notion Academy](https://www.notion.com/help/notion-academy/lesson/ai-autofill-property)
- [Buy & track Notion credits for Custom Agents](https://www.notion.com/help/buy-and-track-notion-credits-for-custom-agents)
- [Allocate credits to each workspace](https://www.notion.com/help/allocate-credits-to-each-workspace)
- [Understand pricing for Workers (beta)](https://www.notion.com/help/understand-pricing-for-workers)
- [MCP connections for Custom Agents](https://www.notion.com/help/mcp-connections-for-custom-agents)
- [Notion AI Connectors](https://www.notion.com/help/notion-ai-connectors)
- [Forms](https://www.notion.com/help/forms)
- [Publish a Notion Site](https://www.notion.com/help/public-pages-and-web-publishing)
- [Notion Sites availability & pricing](https://www.notion.com/help/notion-sites-availability-and-pricing)
- [Connect a custom domain with Notion Sites](https://www.notion.com/help/connect-a-custom-domain-with-notion-sites)
- [Edit & customize your Notion Sites](https://www.notion.com/help/edit-and-customize-your-notion-sites)
- [Charts](https://www.notion.com/help/charts)
- [Notion Calendar](https://www.notion.com/help/category/notion-calendar)
- [Manage your calendars & events](https://www.notion.com/help/manage-your-calendars-and-events)
- [Manage your Mail & Calendar settings](https://www.notion.com/help/manage-email-and-calendar-settings)
- [Notion Mail inbox is going away: what to do next](https://www.notion.com/help/notion-mail-inbox-is-going-away-what-to-do-next)
- [Use pages offline](https://www.notion.com/help/use-pages-offline)
- [Working offline in Notion](https://www.notion.com/help/guides/working-offline-in-notion-everything-you-need-to-know)
- [Notion for mobile](https://www.notion.com/help/notion-for-mobile)
- [Notion 3.3 — Custom Agents](https://www.notion.com/releases/2026-02-24)
- [Notion 3.5 — Notion Developer Platform](https://www.notion.com/releases/2026-05-13)
- [Notion 3.6 — External Agents, HTML blocks, and more](https://www.notion.com/releases/2026-07-01)
- [What's New – Notion](https://www.notion.com/releases)
- [Notion Pricing](https://www.notion.com/pricing)
