# Boas práticas e armadilhas no Notion

Este arquivo é opinião fundamentada, não neutralidade. O Notion é excelente numa faixa estreita de problemas e medíocre fora dela, e a maior parte da frustração que as pessoas têm com a ferramenta vem de insistir fora dessa faixa — ou de construir sistemas grandes demais para o trabalho que realmente existe.

A regra que atravessa tudo aqui: **um sistema de organização só vale o que ele economiza em decisão**. Se ele custa mais atenção do que devolve, ele é dívida, não ativo — por mais bonito que esteja.

---

## 1. Performance: o que deixa o Notion lento

O Notion não é lento por acaso. Ele é lento por padrões específicos e previsíveis. Conhecer os padrões vale mais que qualquer dica genérica de "limpe seu workspace".

### O modelo mental

Uma página no Notion carrega blocos. Blocos de database disparam **consultas**. Cada consulta precisa avaliar filtros, sorts, groups, e — no caso de rollups e fórmulas — atravessar relations para buscar valores em outros data sources. Fórmula sobre rollup sobre relation significa: para renderizar uma linha, o Notion precisa resolver N linhas em outro lugar. Multiplique por 500 linhas visíveis e você entendeu por que a página engasga.

### Tabela de causas e correções

| Causa | Por que dói | O que fazer |
|---|---|---|
| **Rollups encadeados** (rollup que depende de fórmula que depende de rollup) | Cada nível multiplica o trabalho de resolução. O Notion nem permite rollup direto de rollup — justamente para evitar loops | Materialize o valor com automação (`Property edited` → *Edit property* gravando um `Number` real). O valor gravado não recalcula |
| **Muitas linked views numa página** | Cada view é uma consulta independente com filtros próprios | Teto prático de 5–7 views por página. Acima disso, mova para toggles (só carrega ao abrir) ou subpáginas |
| **Database com dezenas de milhares de linhas sem filtro** | View sem filtro tenta paginar tudo | Sempre filtre por recência ou status. Crie `Archived` (Checkbox) e filtre por padrão em todas as views |
| **Fórmulas sobre relations** | Percorre coleção a cada render | Prefira rollup nativo (Sum, Count, Latest date) — é mais barato que fórmula equivalente |
| **Imagens pesadas** (covers de 5 MB, gallery de 200 cards com foto) | Download real de bytes | Comprima antes de subir (imagem de cover não precisa passar de ~300 KB). Gallery: desligue preview de imagem quando o card não depende dela |
| **Página com milhares de blocos** | Uma nota de reunião recorrente "infinita", um journal em página única | Uma página por ocorrência. Quebre em subpáginas |
| **Sub-items com muitos níveis exibidos** | Aninhamento resolve hierarquia a cada nível | Use exibição *flattened* quando não precisa da árvore |
| **Charts sobre databases grandes** | Agregação em tempo real; limite de 200 grupos e 50 subgrupos ([Chart view](https://www.notion.com/help/charts)) | Agregue por semana/mês em vez de dia; filtre janela de tempo |
| **Dashboard view com muitos widgets** | Vários datasets carregados juntos; a própria doc alerta que dashboards ficam lentos se carregarem dados demais ([Dashboards](https://www.notion.com/help/dashboards)) | Máx. 12 widgets é o limite duro; o limite útil é bem menor. Foque cada widget no essencial |
| **Sincronização de muitos synced blocks** | Cada bloco sincronizado resolve a origem | Use com parcimônia; um ou dois por página |
| **Relations bidirecionais em databases grandes** | Toda escrita atualiza os dois lados | Use two-way só quando você realmente navega nos dois sentidos |

### Diagnóstico prático

**Antes de tudo, uma triagem de dez segundos:** abra outras páginas do mesmo workspace. Se elas abrem rápido, o problema é o conteúdo desta página — siga o protocolo abaixo. Se *tudo* está lento, o problema é cliente ou conta, não conteúdo: compare app desktop vs browser, desative extensões, limpe o cache, verifique a rede/região e o tamanho geral do workspace. Busca binária em blocos não conserta nenhuma dessas coisas.

Confirmado que é o conteúdo, teste nesta ordem — leva cinco minutos e quase sempre acha o culpado:

```
1. Duplique a página.
2. Na cópia, delete metade dos blocos. Recarregue.
   ├─ Ficou rápido?  → o problema está na metade deletada. Repita (busca binária).
   └─ Continua lento? → repita na metade restante.
3. Achou o bloco culpado. Pergunte, nesta ordem:
   ├─ É uma view sem filtro?           → filtre por status/recência
   ├─ Tem rollup/fórmula em cadeia?    → materialize com automação
   ├─ É gallery com imagem?            → troque por list/table
   └─ Tem group + subgroup?            → remova o subgroup e meça
4. Delete a cópia.
```

### O que **não** resolve performance

- Mudar de tema claro para escuro.
- Limpar o cache repetidamente (ajuda uma vez, não é solução).
- Espalhar o mesmo conteúdo em mais páginas — isso aumenta o total de consultas.
- Trocar `Select` por `Multi-select`. Irrelevante.

---

## 2. Quando o Notion é a ferramenta errada

Isto é o que mais falta nos conteúdos sobre Notion. A lista abaixo é honesta e cada linha tem uma alternativa concreta.

| Você quer | Por que o Notion falha | Use |
|---|---|---|
| **Planilha com cálculo pesado** — modelo financeiro, cenários, referência de célula, tabela dinâmica, milhares de linhas com fórmula em cadeia | O Notion não tem referência de célula (A1, `$B$3`), não tem tabela dinâmica, e fórmulas só enxergam a própria linha e o que vem por relation/rollup. Cálculo entre linhas exige gambiarra | Google Sheets ou Excel. Embede a planilha no Notion se quiser contexto em volta |
| **Banco de dados relacional de verdade** — integridade referencial, transações, joins arbitrários, milhões de registros, consulta ad-hoc | Sem constraint, sem join real, sem SQL. A "relation" é um ponteiro editável, não uma foreign key com garantia. Volume alto degrada | Postgres (Supabase, Neon), ou Airtable como meio-termo. Se você quer app leve com backend, considere Airtable/Baserow |
| **Projeto com dependências complexas** — caminho crítico, nivelamento de recursos, baseline, replanejamento automático | Dependências existem, mas o Notion não calcula caminho crítico nem faz nivelamento. O *date shifting* é assistência de arraste, não motor de agendamento ([Sub-items & dependencies](https://www.notion.com/help/tasks-and-dependencies)) | MS Project, Smartsheet, ou Linear/Jira para engenharia. Notion serve bem como camada de comunicação sobre a execução |
| **Documentação de código versionada** — precisa acompanhar branch, revisar em PR, ter diff, sofrer CI | Notion não tem branch, merge nem review de diff. Doc no Notion e código no Git desincronizam em semanas | Markdown no repositório, MkDocs/Docusaurus/Mintlify. No Notion fica o que **não** versiona: decisão de arquitetura, contexto, runbook de gente |
| **Formulário público de alto volume** — milhares de respostas, pagamento, validação forte, anti-spam, lógica pesada | Forms nativos servem e rodam em todos os planos, mas a doc admite que formulários de alto volume podem carregar devagar, e conditional logic é Business/Enterprise ([Forms](https://www.notion.com/help/forms)). Não há pagamento nem antispam robusto | Typeform, Tally, Fillout (muitos escrevem direto no Notion via integração). Notion vira o destino, não a porta |
| **App com lógica de negócio** — estados, permissão por regra, cálculo condicional, usuários externos em escala | Buttons e automações fazem ações lineares. Não há loop, condicional composta nem tratamento de erro. Automação de database não dispara outra automação de database | Retool, Softr sobre Airtable, ou um app de verdade. Notion como backend leve funciona via API, mas com limites |
| **Colaboração em tempo real em texto longo com controle editorial forte** | Comentário e histórico existem, mas não há track changes com aceitar/rejeitar por trecho | Google Docs para a fase de redação pesada; Notion para o documento publicado |
| **Base de mídia grande** — vídeo, arquivos grandes, DAM | Upload por arquivo é limitado no plano gratuito; Notion não é storage nem CDN | Drive, Dropbox, Frame.io. Linke no Notion |
| **Analytics de produto / BI** | Chart view é bonito e limitado (5 tipos: barra vertical, barra horizontal, linha, rosca, número) | Metabase, Looker Studio, Hex |

### A regra de bolso

O Notion é imbatível quando o problema é **texto estruturado que precisa de contexto em volta e é operado por pessoas**. Ele é fraco quando o problema é **cálculo, volume, integridade ou automação condicional**.

Se você se pegou escrevendo "eu só precisaria de um IF aninhado aqui e de um lookup entre linhas", você saiu da faixa. Saia da ferramenta também.

---

## 3. O vício de montar o sistema em vez de fazer o trabalho

Esta é a maior armadilha do Notion, e ela não é técnica.

Montar sistema dá a sensação exata de produtividade — decisão, progresso visível, resultado estético — sem nenhum dos custos do trabalho real, que é ambíguo, resistente e sem feedback imediato. O cérebro aprende rápido que mexer no dashboard é agradável e escrever a proposta não é. É procrastinação de altíssima qualidade estética.

### Sintomas

- Você redesenhou a home mais de duas vezes no último mês.
- Você tem mais de três templates baixados que nunca migrou.
- Você sabe quantas views tem no seu `Tasks` (a resposta certa é: você não deveria saber).
- Você está adicionando uma propriedade porque "vai ser útil depois", não porque uma decisão de hoje depende dela.
- Você já pensou "vou refazer tudo do zero, agora do jeito certo" mais de uma vez.
- Suas tarefas ficaram desatualizadas enquanto você melhorava o sistema de tarefas.

### As três perguntas de corte

Antes de qualquer mudança estrutural, responda por escrito:

1. **Qual decisão eu não consigo tomar hoje por falta disto?** Se não há decisão travada, não construa.
2. **Quantas vezes por semana eu vou olhar isto?** Menos de uma vez por semana, não vale uma view.
3. **O que eu deixo de fazer nas próximas duas horas?** Sempre há um custo de oportunidade e ele quase sempre é o trabalho real.

### Regras operacionais

- **Timebox de manutenção**: 30 minutos por semana, um horário fixo. Fora dele, ideias de melhoria viram tarefa em `Tasks` com `Context = @deep` e esperam. A maioria morre na fila, que é o resultado desejado.
- **Regra da terceira vez**: só automatize/estruture depois de fazer o mesmo processo manualmente três vezes. Nas duas primeiras você ainda não sabe qual é o processo.
- **Construa contra dor, não contra hipótese.** "Perdi um prazo porque não vi" é dor. "Seria bom rastrear energia por hora" é hipótese.
- **Comece feio.** Uma lista simples usada por três semanas ensina mais sobre o que você precisa do que qualquer planejamento. Estrutura elegante prematura é chute com boa tipografia.
- **Se está reconstruindo do zero, pare.** Reconstrução é quase sempre fuga. Corrija o ponto específico que dói.

### O teste dos 30 dias

Olhe o workspace e pergunte de cada database, view e propriedade: *isto mudou uma decisão minha nos últimos 30 dias?* O que responder não, sai. Você vai se surpreender com quanto sai — e com o quanto o resto melhora quando sai.

---

## 4. Princípios de design de sistema

Seis princípios. Eles não são independentes: violar um costuma forçar a violação dos outros.

### 4.1 Capturar em um lugar só

Se existem dois lugares para anotar uma tarefa, existem zero lugares confiáveis — porque você vai ter que checar os dois, e cedo ou tarde vai esquecer de um. Um único ponto de captura, com atrito mínimo (um botão, um campo, `Status = Inbox`), vale mais que dez campos de metadado bem pensados.

Corolário: **capturar e organizar são momentos diferentes.** Se o ato de capturar exige escolher projeto, contexto, prioridade e estimativa, você para de capturar. Capture cru; processe depois, em bloco.

### 4.2 Uma fonte de verdade por conceito

Um conceito = um data source canônico. Toda tarefa do workspace vive em `Tasks`, ponto. Action item de reunião é `Task`. Item de checklist de projeto é `Task`. Recado do chefe é `Task`.

O sintoma da violação: você mantém duas listas e passa a checar as duas "por garantia". A partir daí, nenhuma é confiável e você criou trabalho de reconciliação que nunca acaba.

### 4.3 View, não cópia

Precisa das mesmas tarefas em outro lugar? **Linked view**, nunca duplicação. Cópia começa igual e diverge no terceiro dia. Uma linked view é uma janela para o mesmo data source, com filtro próprio ([Using database views](https://www.notion.com/help/guides/using-database-views)).

O mesmo vale para texto: bloco de conteúdo que precisa aparecer em dois lugares é **synced block** ([Synced blocks](https://www.notion.com/help/synced-blocks)), não copiar e colar.

### 4.4 Nomear pelo uso, não pela estrutura

| Nome ruim | Nome bom | Por quê |
|---|---|---|
| `Tasks — filtered by status = next` | `Next actions` | O nome deve dizer *quando* você abre |
| `DB_Projects_v2` | `Projects` | Versionamento no nome é sinal de cópia não deletada |
| `Untitled` | qualquer coisa | Página sem título é página perdida na busca |
| `Misc` | (não crie) | Categoria "diversos" absorve tudo e informa nada |
| `Q3 stuff` | `2026-Q3 planning` | Data no nome sobrevive ao tempo |

Regra prática para views: se o nome não termina implicitamente em "…quando eu quero X", o nome está errado.

### 4.5 Arquivar em vez de deletar

Delete quebra relations, @-menções e links. Além disso, apaga o histórico que dá valor ao sistema no ano seguinte (deal perdido, projeto cancelado, pauta descartada — tudo isso é dado).

O padrão: propriedade `Archived` (**Checkbox**), mais um filtro `Archived is unchecked` em **todas** as views operacionais. Checkbox e não um valor `Archived` dentro do `Status` porque arquivar é ortogonal ao ciclo de vida — você arquiva tanto o que terminou quanto o que foi cancelado, e colapsar os dois no `Status` apaga qual dos dois foi. Conteúdo permanece pesquisável, relations continuam íntegras, e nada polui o dia a dia.

Delete de verdade só para: duplicata acidental, teste, e dado sensível que precisa sair. Lembre que a lixeira do Notion tem prazo de retenção e restauração é um processo, não um `Ctrl+Z` ([Duplicate, delete & restore](https://www.notion.com/help/duplicate-delete-and-restore-content)).

### 4.6 Manutenção faz parte do sistema

Sistema que exige zero manutenção não existe. Sistema que exige manutenção não agendada morre.

Coloque a manutenção **dentro** do sistema:

| Ritual | Frequência | Duração | O que faz |
|---|---|---|---|
| Processar inbox | Diário ou 3x/semana | 5–10 min | Zerar captura crua |
| Weekly review | Semanal, horário fixo | 30–45 min | Revisar projetos, definir next action de cada, olhar `Waiting on` |
| Revisão de views | Mensal | 15 min | Apagar view que você não abriu |
| Revisão de propriedades | Trimestral | 20 min | Apagar propriedade com >60% de células vazias |
| Verificação de wiki | Conforme prazo | — | Revalidar páginas com verificação expirada ([Verified pages](https://www.notion.com/help/wikis-and-verified-pages)) |
| Export de backup | Trimestral | 10 min | Ver seção 8 |

Se você não consegue sustentar esses rituais, seu sistema é grande demais. A resposta certa é encolher o sistema, não se culpar.

---

## 5. Over-engineering típico

Quatro padrões que aparecem em praticamente todo workspace que dá errado.

### 5.1 Relations demais

**O padrão**: `Tasks` se relaciona com `Projects`, `Areas`, `Goals`, `People`, `Meetings`, `Resources`, `Habits` e `Content`. Oito relations.

**Por que dói**: cada relation é um campo a preencher (ou uma decisão de deixar vazio, que gera culpa), um custo de render e uma chance de inconsistência. E na prática você usa duas.

**Correção**: relation só quando você **navega** ou **agrega** naquela direção. Se você nunca abriu um `Area` para ver suas tarefas, a relation `Task → Area` não deveria existir — derive por rollup ou não derive.

Teste: para cada relation, responda *"qual view ou rollup depende disto?"*. Sem resposta, delete.

### 5.2 Propriedades que ninguém preenche

**O padrão**: `Tasks` com `Energy`, `Estimate`, `Context`, `Priority`, `Focus type`, `Location`, `Mood needed`, `Difficulty`.

**Por que dói**: propriedade vazia é pior que ausente — ela suja views, quebra agrupamentos (aparece coluna "No value" no board) e cria a sensação de que o sistema está incompleto.

**Correção**: métrica objetiva. Ordene o database por uma propriedade e veja quantas células estão vazias. **Acima de 60% de vazios, a propriedade sai.** Sem debate, sem "mas eu ia começar a usar".

### 5.3 Doze views que ninguém abre

**O padrão**: `Tasks` com `All`, `Today`, `Tomorrow`, `This week`, `Next week`, `By project`, `By area`, `By context`, `By priority`, `Overdue`, `Someday`, `Archive`.

**Por que dói**: a barra de views vira scroll horizontal, você não acha a que quer, e cada view salva é um filtro a manter quando o schema muda.

**Correção**: uma view por **momento de uso**, não por dimensão de dado. A maioria das pessoas precisa de 3 a 5 views em `Tasks`: capturar, hoje, decidir o próximo, revisar. Agrupamento resolve o resto — você pode reagrupar uma view ao vivo em dois cliques.

Regra: se você não abriu a view em 30 dias, apague. Ela leva 20 segundos pra recriar.

### 5.4 Hierarquia de seis níveis

**O padrão**: `Work → Clients → ACME → 2026 → Q3 → Projeto Alfa → Reuniões → 12 de julho`.

**Por que dói**: ninguém navega seis níveis. Você usa busca. E quando usa busca, a hierarquia só serviu para você gastar tempo criando pastas.

**Correção**: **propriedade em vez de pasta.** Um database `Meetings` com `Client`, `Project` e `Date` faz tudo o que a árvore fazia, e ainda filtra, agrupa e ordena. Regra prática: **máximo de três níveis de página**. Abaixo disso, database.

### Tabela-resumo de amputação

| Sintoma | Corte |
|---|---|
| Relation nunca navegada | Delete a relation |
| Propriedade >60% vazia | Delete a propriedade |
| View não aberta em 30 dias | Delete a view |
| Nível de página nº 4 | Vire database com propriedade |
| Database com <10 linhas e sem crescimento | Vire propriedade `Select` em outro database |
| Fórmula que ninguém lê | Delete |
| Template nunca usado | Delete |

---

## 6. Colaboração

Workspace pessoal aguenta improviso. Workspace de time não. O que quebra colaboração não é falta de recurso — é falta de **convenção explícita e escrita**.

### 6.1 Convenções que precisam estar escritas

Crie uma página `How we use Notion` na wiki e mantenha-a curta (uma tela). Ela deve cobrir:

| Tema | Exemplo de convenção |
|---|---|
| Nomes | Reuniões: `YYYY-MM-DD · Assunto`. Projetos: verbo + objeto (`Migrar billing`) |
| Onde criar | "Toda tarefa nasce em `Tasks`. Nunca em checkbox dentro de doc" |
| Status | O que significa `In review` exatamente, e quem move para lá |
| Idioma | Um só. Misturar `Tarefas` e `Tasks` destrói busca |
| Datas | `Dates` sempre com início e fim em qualquer coisa que apareça em timeline |
| Comentar vs editar | Ver 6.4 |
| O que não vai pro Notion | Ex.: "senha nunca; use o gerenciador" |

Convenção não escrita é convenção que só existe na cabeça de quem montou o workspace — e que morre quando essa pessoa sai de férias.

### 6.2 Quem é dono do quê

Três camadas de propriedade, todas necessárias:

- **Owner de página/doc** — quem garante que está correto. Em wikis, é propriedade nativa e requisito para verificação ([Verified pages](https://www.notion.com/help/wikis-and-verified-pages)). Configure para **um** owner, não vários: dono compartilhado é dono nenhum.
- **Owner de projeto/deal/KR** — uma pessoa (`Person`), não o time.
- **Owner de sistema** — quem cuida do próprio database: schema, views, automações. Sem esse papel, o schema apodrece por acréscimo de todo mundo. Escreva o nome no topo do database.

Permissões: use teamspaces para separar domínios e restrinja onde precisa. O Notion suporta acesso em nível de página dentro de database, então dá pra manter uma fonte única de verdade e ainda esconder linhas sensíveis ([Sharing & permissions](https://www.notion.com/help/sharing-and-permissions)).

Cuidado com um efeito colateral pouco conhecido: **automações não agem sobre páginas cujo acesso está restrito** ([Database automations](https://www.notion.com/help/database-automations)). Se sua automação "não funciona para algumas linhas", suspeite de permissão antes de suspeitar do filtro.

### 6.3 Onboarding de novo membro

Um roteiro de 30 minutos, não um tour de duas horas:

```
1. (5 min)  Onde é a home do time. Fixe. Explique as 3 views que importam.
2. (5 min)  "Toda tarefa vive em Tasks." Mostre criar uma. Mostre "My tasks".
3. (5 min)  Wiki: como buscar. Diga explicitamente: "sem check azul,
            confirme antes de agir."
4. (5 min)  Convenções: leia junto a página How we use Notion.
5. (5 min)  Comentário vs edição. Onde pedir ajuda.
6. (5 min)  Tarefa real: peça para criar sua primeira página seguindo o template.
```

O que **não** fazer no onboarding: mostrar o workspace inteiro. A pessoa esquece 90% e fica com a impressão (correta) de que o sistema é grande demais.

Bom teste do seu workspace: se o onboarding exige mais de 30 minutos, o problema não é o onboarding.

### 6.4 Comentários vs edição direta

| Situação | Ação |
|---|---|
| Erro de digitação, link quebrado, formatação | **Edite direto.** Pedir permissão pra corrigir typo é burocracia |
| Discordância de conteúdo | **Comente.** Editar por cima apaga a decisão de alguém sem discussão |
| Página verificada / política | **Comente e marque o owner.** Nunca edite política alheia direto |
| Nota de reunião de outra pessoa | **Comente.** É o registro dela do que ela ouviu |
| Doc em `Draft` | **Edite** se te pediram; **comente** se não pediram |
| Sugerir reestruturação grande | **Comente na página + converse.** Reestruturação silenciosa gera ressentimento |

Convenção que funciona bem: **resolva seus próprios comentários**. Comentário resolvido por terceiro deixa quem levantou a questão sem saber se foi endereçada.

E uma regra de higiene: comentário não é canal de decisão. Decisão vai para a seção "Decisões" do doc, com data e nome. Comentário some da vista quando resolvido; decisão precisa sobreviver.

---

## 7. Acessibilidade e legibilidade

Costuma ser esquecido e custa barato consertar.

- **Contraste**: fundos coloridos de callout no tema escuro deixam texto cinza ilegível. Teste no tema oposto ao seu antes de padronizar uma cor.
- **Cor como único sinal**: `Status` colorido sem rótulo textual é inútil para quem tem daltonismo (~8% dos homens). Use cor **mais** texto ou emoji distinto.
- **Emoji como propriedade**: um `Select` com valores `🟢`, `🟡`, `🔴` e nada mais é ruim em leitor de tela e em busca. Prefira `🟢 On track`.
- **Texto alternativo em imagem**: o Notion permite legenda; use-a quando a imagem carrega informação.
- **Largura de linha**: páginas em *full width* com texto corrido de 200 caracteres por linha são cansativas. Deixe full width para databases; texto longo fica melhor na largura padrão.
- **Hierarquia real de headings**: use `Heading 1/2/3` de verdade, não texto em negrito grande. Headings alimentam o sumário, a navegação e leitores de tela.
- **Tabela larga**: table view com 20 colunas força scroll horizontal em qualquer tela. Esconda propriedades por view — cada view mostra só o que aquele momento exige.
- **Mobile**: se a página é usada no celular (captura, checklist), teste no celular. Colunas viram empilhamento e boards ficam ruins em tela estreita.
- **Nome descritivo de link**: "clique aqui" não ajuda ninguém. Escreva o destino.
- **Densidade**: quatro linhas de callout coloridos seguidos anulam o propósito do destaque. Destaque tudo é destaque nada.

---

## 8. Backup, export e estratégia de saída

### O que o vendor lock-in realmente significa aqui

O lock-in do Notion não é o texto — é a **estrutura**. Parágrafos e títulos exportam bem. O que não exporta é o que te fez escolher o Notion: relations entre databases, rollups, fórmulas, views com filtro, automações, botões, templates de database, permissões e histórico de versão.

### O que sobrevive ao export

Formatos disponíveis: **PDF**, **HTML**, **Markdown & CSV** ([Export your content](https://www.notion.com/help/export-your-content)).

| Item | Markdown & CSV | HTML | PDF |
|---|---|---|---|
| Texto e formatação | Sim | Sim | Sim |
| Estrutura de subpáginas | Sim (pastas) | Sim | Parcial |
| Databases | CSV (linhas e valores) | Sim | Visual |
| Valores de propriedade | Sim, como texto | Sim | Sim |
| **Relations** | Só o texto do título relacionado — sem o vínculo | Só o texto | Visual |
| **Rollups / fórmulas** | Valor calculado no momento, congelado | Idem | Idem |
| **Views, filtros, sorts** | Não | Não | Não |
| **Automações e botões** | Não | Não | Não |
| Comentários | Não | Sim (inclusive resolvidos) | Não |
| Arquivos e imagens | Sim, como assets | Sim | Embutidos |
| Histórico de versões | Não | Não | Não |
| Emoji customizado | — | — | Não aparece |
| View de formulário | Não exporta — exporte da table view | Idem | Idem |

Dois avisos operacionais: export em nível de workspace pode **excluir páginas privadas** às quais quem exporta não tem acesso; e não dá para exportar todas as views de uma vez — apenas a atual e a padrão.

### Rotina de backup que eu recomendo

```
Trimestral (10 minutos):
  1. Settings → export do workspace inteiro
     Formato: Markdown & CSV,  "Include subpages" ligado,
              "Create folders for subpages" ligado
  2. Segundo export em HTML  (preserva comentários)
  3. Guarde os dois num storage fora do Notion, com a data no nome
  4. Abra um arquivo aleatório e confira se está legível
     — export nunca testado é backup que não existe

Antes de qualquer mudança estrutural grande:
  export do database afetado + duplicação dele dentro do Notion

Continuidade (opcional, para dados críticos):
  script contra a API do Notion gravando JSON,
  incluindo relations por ID — é a única forma de preservar o grafo
```

O passo 4 é o que separa backup de teatro de backup.

### Estratégia de saída

Se você quer reduzir o risco desde o começo:

- **Mantenha o essencial em texto**, não em fórmula. Um `Status` escrito sobrevive a qualquer migração; um `Progress` calculado não.
- **Evite fórmula como fonte de informação.** Fórmula é conveniência de exibição. Se um número importa historicamente (valor fechado do deal, pontos concluídos no sprint), grave-o num campo `Number` real via automação.
- **Documentos que precisam durar décadas** (contrato, política legal) devem existir em PDF fora do Notion também.
- **Migração realista**: databases saem via CSV para Airtable/Sheets razoavelmente bem; docs saem para Markdown razoavelmente bem; o **sistema** não sai. Aceite que migrar significa remontar as views e as automações, e dimensione o sistema sabendo disso.

---

## 9. Como auditar um workspace ou página

Roteiro de revisão. Dá pra rodar inteiro em uma hora num workspace pessoal, ou em blocos num workspace de time.

### 9.1 Nível workspace

```
[ ] Existe uma home clara e fixada? Alguém novo saberia por onde começar?
[ ] Quantos databases existem?  > 10 num workspace pessoal é suspeito
[ ] Há mais de um database para o mesmo conceito?  (duas listas de tarefa,
    dois lugares de nota)  → consolide
[ ] Há databases com menos de 10 linhas e sem crescimento?  → vire Select
[ ] Há databases órfãos (nenhuma página aponta pra eles)?  → arquive
[ ] Há páginas "Untitled"?  → nomeie ou delete
[ ] Há cópias com sufixo "(1)", "v2", "old", "copy"?  → resolva; são
    fontes de verdade concorrentes
[ ] A hierarquia passa de 3 níveis em algum lugar?  → achate
[ ] Teamspaces refletem times reais ou são resquício de reorg?
[ ] Existe a página "How we use Notion"? Está atualizada?
[ ] Quando foi o último export de backup?
```

### 9.2 Nível database

```
[ ] Cada propriedade: qual view, filtro ou rollup depende dela?
    Nenhum → delete
[ ] Percentual de células vazias por propriedade.  > 60% → delete
[ ] Cada relation: você navega ou agrega nessa direção? Não → delete
[ ] Relations two-way desnecessárias → torne one-way
[ ] Fórmulas: alguém consegue explicar cada uma? Não → delete ou documente
    na descrição da propriedade
[ ] Rollups encadeados sobre fórmulas → materialize
[ ] Cada view: aberta nos últimos 30 dias? Não → delete
[ ] Toda view operacional filtra "Archived is unchecked"?
[ ] Filtros usam datas relativas (Today, past week) e não datas fixas?
[ ] Status tem grupos To-do / In progress / Complete corretos?
[ ] O database tem uma descrição explicando o que entra e o que não entra?
[ ] Existe template de database para o caso comum de criação?
[ ] Existe um owner nomeado do database?
```

### 9.3 Nível página

```
[ ] O título diz o que a página é, sem abrir?
[ ] A primeira tela responde por que a página existe?
[ ] Headings reais (H1/H2/H3), não negrito grande?
[ ] Menos de 7 blocos de database/linked view?
[ ] Imagens comprimidas? Cover leve?
[ ] Links quebrados ou apontando pra páginas deletadas?
[ ] Se é doc de conhecimento: tem owner e verificação?
[ ] Se é doc de projeto: tem relation para o projeto?
[ ] Conteúdo duplicado que deveria ser synced block?
[ ] Legível no tema claro e no escuro?
[ ] Legível no celular, se for usada no celular?
```

### 9.4 Auditoria de automação

```
[ ] Cada automação: ainda faz sentido? Alguém confere que ela roda?
[ ] Há automação que dispara notificação que todo mundo ignora?
    → notificação ignorada é pior que nenhuma; delete
[ ] Automação escrevendo em database que já não existe?
[ ] Há automação esperando disparar outra automação de database?
    Não funciona — o Notion não encadeia automações de database
[ ] Automações agindo sobre páginas com acesso restrito?
    Não vão agir. Reveja permissão
[ ] Há botão que ninguém clica? → delete
```

---

## 10. Sinais de que o sistema está morrendo

Diagnóstico com tratamento. Um sistema raramente morre de repente; ele avisa.

| Sinal | O que significa | O que fazer |
|---|---|---|
| **Você abre o Notion e não sabe pra onde ir** | Não há ponto de entrada, ou há vários concorrendo | Escolha uma home. Fixe. Delete as concorrentes. Nada de segundo dashboard |
| **Você faz a tarefa e esquece de marcar** | O sistema virou registro histórico, não operação. Ele deixou de estar no seu caminho | Reduza atrito: menos campos obrigatórios, botão de captura, view "Today" mais curta. Se a coisa acontece fora do Notion, aceite e pare de rastrear |
| **A view "Today" tem 40 itens** | Você está enfiando o backlog inteiro no hoje | Aperte o filtro (só `P1` e `P2`), e faça a revisão semanal de verdade. Hoje realista é 3 a 5 itens |
| **Ninguém do time atualiza status** | Ou não é usado para nada visível, ou custa demais | Faça o status ter consequência (é ele que alimenta o report, a reunião, o Slack). E remova campo obrigatório que ninguém preenche |
| **Você mantém uma segunda lista fora do Notion** | Papel, notas do celular, mensagem pra si mesmo. Sinal grave: o sistema perdeu para uma folha em branco | Investigue o atrito específico do momento de captura. Muitas vezes a resposta é aceitar o Notion Calendar ou o celular como porta de entrada e sincronizar depois |
| **Você tem medo de abrir o inbox** | Acúmulo virou dívida emocional | **Bankruptcy declarada**: arquive tudo em massa com uma data de corte. O que importava vai voltar sozinho. Recomece com o hábito, não com o backlog |
| **Toda semana tem uma "melhoria" no sistema** | Fuga de trabalho (seção 3) | Timebox de manutenção. Fila de ideias. Nada estrutural fora do horário |
| **A página demora a carregar** | Problema técnico da seção 1 | Busca binária de blocos. Quase sempre é linked view sem filtro ou rollup encadeado |
| **Você usa a busca pra tudo e nunca a navegação** | Ou sua estrutura não serve, ou — mais provável — a busca é ótima e você não precisava de estrutura | Isto pode ser saúde, não doença. Se a busca resolve, achate a hierarquia em vez de melhorá-la |
| **Duas pessoas dão respostas diferentes sobre o mesmo processo** | Duas fontes de verdade | Consolide. Uma vira canônica, a outra vira `Deprecated` com `Supersedes` apontando pra nova |
| **Ninguém confia na wiki** | Verificação expirada ou nunca implantada | Rode uma campanha de verificação com prazo. Página sem owner disposto a verificar deveria ser depreciada, não mantida |
| **Você duplicou um template novo "pra recomeçar"** | Fuga, com toda certeza | Não migre. Anote o que dói no sistema atual e conserte só isso |
| **O sistema está lindo e você não trabalha** | Estética virou o produto | Faça o teste dos 30 dias (seção 3). Ampute |

### O critério final

Um sistema de organização é infraestrutura, não produto. Ele deve ser **invisível quando funciona**. Se você pensa nele com frequência — para admirar ou para consertar — ele está atrapalhando.

O melhor workspace do Notion que existe é o que a pessoa nem lembra de ter montado, porque ela está ocupada fazendo o trabalho.

---

## Referências oficiais citadas

- [What is a database?](https://www.notion.com/help/what-is-a-database)
- [Data sources & linked databases](https://www.notion.com/help/data-sources-and-linked-databases)
- [Database properties](https://www.notion.com/help/database-properties)
- [Views, filters, sorts & groups](https://www.notion.com/help/views-filters-and-sorts)
- [Using database views (guia)](https://www.notion.com/help/guides/using-database-views)
- [Relations & rollups](https://www.notion.com/help/relations-and-rollups)
- [Formulas](https://www.notion.com/help/formulas)
- [Sub-items & dependencies](https://www.notion.com/help/tasks-and-dependencies)
- [Database automations](https://www.notion.com/help/database-automations)
- [Buttons](https://www.notion.com/help/buttons)
- [Chart view](https://www.notion.com/help/charts)
- [Dashboards view](https://www.notion.com/help/dashboards)
- [Timeline view](https://www.notion.com/help/timelines)
- [Forms](https://www.notion.com/help/forms)
- [Wikis & verified pages](https://www.notion.com/help/wikis-and-verified-pages)
- [Synced blocks](https://www.notion.com/help/synced-blocks)
- [Database templates](https://www.notion.com/help/database-templates)
- [Sharing & permissions](https://www.notion.com/help/sharing-and-permissions)
- [Duplicate, delete & restore content](https://www.notion.com/help/duplicate-delete-and-restore-content)
- [Export your content](https://www.notion.com/help/export-your-content)
- [Import data into Notion](https://www.notion.com/help/import-data-into-notion)
- [AI Meeting Notes](https://www.notion.com/help/ai-meeting-notes)
- [Notion Agent](https://www.notion.com/help/notion-agent)
- [Search](https://www.notion.com/help/search)
- [Keyboard shortcuts](https://www.notion.com/help/keyboard-shortcuts)
