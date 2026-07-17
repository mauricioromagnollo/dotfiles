# Padrões de Interface (UI Patterns) — Catálogo acionável

> Síntese de soluções consagradas para problemas recorrentes de interface, destilada da
> literatura de referência (Jenifer Tidwell, *Designing Interfaces*; ui-patterns.com;
> *A Pattern Language* aplicado a UI; Material Design; Apple HIG). **Padrão não é meta:**
> só use um quando ele resolve um problema real da sua tela. O default é a solução mais
> simples e mais convencional que cumpre a tarefa (Lei de Jakob) — ver `leis-heuristicas.md`.

Cada padrão traz: **problema** que resolve · **quando usar** · **quando NÃO usar** · **boas práticas**.

---

## 1. Navegação

### Barra de navegação global (top nav)
- **Problema:** dar acesso persistente às seções principais e à identidade do produto.
- **Quando usar:** produtos com poucas seções de topo (≤ 7); sites de conteúdo/marketing.
- **Quando NÃO usar:** apps com dezenas de destinos → prefira sidebar; mobile → tab bar.
- **Boas práticas:** logo à esquerda linkando à home; marque a seção atual com **dois** sinais visuais (cor + peso); mantenha idêntica em todas as páginas.

### Menu lateral (sidebar / nav drawer)
- **Problema:** navegar entre muitos destinos hierárquicos em apps densos (dashboards, admin).
- **Quando usar:** SaaS/back-office com muitas áreas; navegação que precisa de agrupamento.
- **Quando NÃO usar:** sites de conteúdo simples; quando rouba largura preciosa no mobile.
- **Boas práticas:** permita colapsar (ícone + label → só ícone); agrupe com títulos; destaque o item ativo; no mobile vire drawer sob demanda.

### Tab bar inferior (mobile)
- **Problema:** alternar entre 3–5 seções de topo com o polegar.
- **Quando usar:** apps mobile com 3 a 5 destinos primários de igual importância.
- **Quando NÃO usar:** > 5 destinos (não caiba tudo; não use "Mais" como muleta para 8 itens); ações (ação não é destino → use FAB/botão).
- **Boas práticas:** ícone + rótulo curto; alvo ≥ 44px; item ativo destacado; fica na thumb zone.

### Menu hambúrguer
- **Problema:** esconder navegação secundária quando falta espaço.
- **Quando usar:** navegação **secundária** no mobile, ou primária quando não há alternativa.
- **Quando NÃO usar:** para esconder a navegação **principal** que caberia visível — "fora de vista, fora da mente" derruba a descoberta e o engajamento (Norman/NNG). Prefira tab bar.
- **Boas práticas:** se usar, sinalize claramente; considere expor os 2–3 itens mais usados fora do menu.

### Breadcrumbs (migalhas)
- **Problema:** mostrar onde o usuário está numa hierarquia e permitir subir níveis.
- **Quando usar:** hierarquias com ≥ 3 níveis (e-commerce, docs, arquivos).
- **Quando NÃO usar:** apps de nível único/plano; como substituto da navegação principal.
- **Boas práticas:** topo da página; separador claro (`/` ou `>`); item atual sem link, em negrito; fonte discreta (é acessório).

### Paginação vs. scroll infinito vs. "carregar mais"
- **Problema:** exibir listas longas sem despejar tudo de uma vez.
- **Paginação numerada:** quando o usuário precisa **encontrar/voltar** a um item, comparar, ou saber o tamanho do conjunto (resultados de busca, tabelas). Dá senso de lugar e é linkável.
- **"Carregar mais" (botão):** meio-termo; mantém o rodapé acessível e dá controle ao usuário.
- **Scroll infinito:** feeds de descoberta/exploração contínua (redes sociais). **Nunca** em páginas com rodapé importante nem quando o usuário precisa reencontrar itens — ele perde a posição e não alcança o footer.
- **Boas práticas:** preserve a posição ao voltar; mostre progresso/total quando fizer sentido.

---

## 2. Entrada de dados e formulários

> Regras transversais de formulário estão em `ui-moderno.md` (labels acima, 1 campo/linha,
> validação on-blur, input types no mobile). Aqui, os padrões de controle.

### Seleção: radio · checkbox · select · toggle
- **Radio:** 1 opção entre poucas (2–5), todas visíveis, mutuamente exclusivas.
- **Checkbox:** múltipla escolha independente, ou um único opt-in/aceite.
- **Select/dropdown:** 1 opção entre **muitas** (> 5–7) onde o espaço é escasso; ao custo de esconder as opções (um clique a mais). Evite para ≤ 5 (use radio).
- **Toggle (switch):** liga/desliga com **efeito imediato** (sem precisar de "Salvar"). Se depende de um submit, use checkbox. Rotule o que ele controla, não o estado.

### Autocomplete / combobox
- **Problema:** entrada num domínio grande e conhecido (cidade, produto, usuário).
- **Quando usar:** listas grandes onde digitar filtra melhor que rolar; busca com sugestões.
- **Boas práticas:** mostre resultados após 1–2 caracteres; navegável por teclado; tolere erros de digitação; deixe claro se aceita valor livre ou só da lista.

### Date/time picker
- **Problema:** capturar data válida sem erro de formato (restrição, à la Norman).
- **Quando usar:** qualquer entrada de data; especialmente datas futuras/agendamento.
- **Quando NÃO usar:** datas conhecidas de cor (nascimento) → campo de texto com máscara costuma ser mais rápido que navegar um calendário.
- **Boas práticas:** desabilite datas inválidas; aceite também digitação; deixe claro o formato.

### Stepper / entrada numérica
- **Quando usar:** ajuste de pequenas quantidades (1–2 dígitos, ex.: quantidade no carrinho).
- **Quando NÃO usar:** faixas grandes (use campo + teclado numérico no mobile).
- **Boas práticas:** botões −/+ com alvo ≥ 44px; permita digitar direto; respeite min/max.

### Wizard / formulário em etapas
- **Problema:** quebrar uma tarefa longa em passos curtos (simplificar a estrutura — Norman).
- **Quando usar:** fluxos longos, lineares, com dependência entre passos (onboarding, checkout).
- **Quando NÃO usar:** formulários curtos (fragmentar sem motivo adiciona cliques e frustração).
- **Boas práticas:** indicador de progresso ("passo 2 de 4"); permita voltar sem perder dados; valide por etapa; revele o próximo passo só quando o atual estiver válido.

### Edição inline
- **Problema:** editar um valor sem mudar de tela/modal.
- **Quando usar:** ajustes rápidos em listas/tabelas/configurações.
- **Boas práticas:** deixe claro que é editável (affordance ao hover/foco); confirme salvamento com feedback; ofereça cancelar; cuidado com salvar acidental.

---

## 3. Feedback e comunicação de estado

### Toast / snackbar
- **Problema:** confirmar uma ação ou avisar de algo **sem interromper** o fluxo.
- **Quando usar:** confirmações efêmeras ("Item salvo"), com opção de **Desfazer**.
- **Quando NÃO usar:** para erros críticos ou mensagens que o usuário precisa ler/agir (somem sozinhas). Não coloque ação **destrutiva** irreversível só num toast.
- **Boas práticas:** 4–6s; um por vez; posição consistente; inclua "Desfazer" quando aplicável (melhor que diálogo de confirmação — Norman).

### Validação inline
- **Problema:** apontar erro no campo certo, no momento certo.
- **Boas práticas:** valide ao sair do campo (on-blur), não a cada tecla; mensagem **abaixo do campo**, específica e com a **solução** ("Use ao menos 8 caracteres"), não "inválido"; nunca dependa só de cor (ícone + texto).

### Estados de carregamento
- **Skeleton:** quando você conhece o layout que vai chegar (listas, cards) — reduz a percepção de espera. Preferido para carregamento de conteúdo.
- **Spinner:** ações curtas e pontuais de duração desconhecida (< 1s não mostre nada; some the 300ms threshold, ver `ui-moderno.md`).
- **Barra de progresso:** operações longas com progresso mensurável (upload, importação).
- **UI otimista:** reflita a ação na hora e reconcilie depois (curtir, marcar) para parecer instantâneo.

### Estado vazio (empty state)
- **Problema:** a primeira impressão quando ainda não há dados — momento decisivo, não um erro.
- **Boas práticas:** explique o que aparece ali; ofereça a **ação principal** para preencher (CTA); diferencie "vazio na primeira vez" de "sua busca não retornou nada" (este último sugere refinar/limpar filtros).

### Estado de erro
- **Boas práticas:** diga **o que aconteceu**, **por que** e **como resolver**; linguagem humana, não código; ofereça caminho de recuperação (tentar de novo, contato); preserve o que o usuário já digitou.

### Confirmação vs. Desfazer
- **Prefira Desfazer.** Diálogos de confirmação são aprovados no automático e não protegem contra lapsos (Norman). Para ações reversíveis, execute + ofereça "Desfazer".
- **Confirmação** reserve para o que é **destrutivo e irreversível** (excluir conta). Aí exija fricção real: mostre o que será perdido, e para o irreparável peça digitar o nome do recurso.

### Tooltip
- **Quando usar:** dica complementar sobre um ícone/controle; **nunca** para informação essencial.
- **Quando NÃO usar:** conteúdo crítico (some, não é descoberto, não funciona em toque). No mobile não há hover.
- **Boas práticas:** curto; acionável por teclado e foco; não esconda o alvo.

---

## 4. Exibição de dados

### Card
- **Problema:** agrupar informação heterogênea de um item num contêiner escaneável.
- **Quando usar:** coleções de itens com imagem + texto + ação (produtos, posts, projetos).
- **Quando NÃO usar:** comparar muitos itens por atributos → tabela é melhor. Não transforme uma tabela densa em cards só por estética.
- **Boas práticas:** hierarquia interna clara; toda a área clicável quando levar a um destino; espaçamento consistente; não sobrecarregue de ações.

### Tabela de dados
- **Problema:** comparar muitos itens por vários atributos alinhados.
- **Quando usar:** dados densos e comparáveis (planilhas, relatórios, listas administrativas).
- **Boas práticas:** cabeçalho fixo ao rolar; alinhe números à direita; ordenação por coluna; zebra/linhas discretas; ações por linha reveladas no hover/foco; no mobile, transforme em cards ou permita scroll horizontal com a 1ª coluna fixa.

### Lista
- **Quando usar:** itens homogêneos, muitas vezes com uma ação principal por item.
- **Boas práticas:** linha inteira clicável; divisórias sutis; suporte a estados (não lido, selecionado); ações secundárias por swipe/hover.

### Accordion / disclosure (divulgação progressiva)
- **Problema:** mostrar só o essencial e revelar o detalhe sob demanda (reduz carga cognitiva).
- **Quando usar:** FAQs, configurações avançadas, conteúdo longo secundário.
- **Quando NÃO usar:** conteúdo que a maioria precisa ver (não esconda o principal); quando o usuário provavelmente quer tudo aberto (aí some the accordion e mostre).
- **Boas práticas:** indicador claro de expansível (chevron que gira); não aninhe demais; permita múltiplos abertos quando fizer sentido.

### Abas (tabs)
- **Problema:** dividir conteúdo de um mesmo objeto em visões paralelas, sem trocar de página.
- **Quando usar:** seções mutuamente exclusivas do mesmo item (Perfil / Atividade / Config).
- **Quando NÃO usar:** quando o usuário precisa **comparar** conteúdos de abas diferentes ao mesmo tempo; para navegação de topo do site (isso é nav, não tabs).
- **Boas práticas:** aba ativa claramente destacada e conectada ao painel; poucos itens; rótulos curtos.

---

## 5. Busca e filtragem

### Campo de busca
- **Boas práticas:** faça a busca **parecer** busca (caixa + ícone de lupa + placeholder claro); posição convencional (topo); mostre o termo buscado na página de resultados; trate o resultado vazio com sugestões.

### Filtros e facetas
- **Problema:** estreitar um grande conjunto de resultados por atributos.
- **Quando usar:** catálogos/listas grandes (e-commerce, busca de imóveis/vagas).
- **Boas práticas:** mostre os filtros aplicados como chips removíveis; atualize resultados na hora (ou com botão "Aplicar" claro no mobile); mostre contagem por opção; "Limpar filtros" sempre visível; no mobile use bottom sheet.

### Ordenação (sort)
- **Boas práticas:** separado dos filtros; deixe claro o critério atual; defaults sensatos ("Relevância").

---

## 6. Sobreposições (overlays)

### Modal / diálogo
- **Problema:** focar o usuário numa tarefa/decisão curta que **exige** interrupção.
- **Quando usar:** confirmação crítica; tarefa curta e autocontida que não vale uma página.
- **Quando NÃO usar:** fluxos longos ou com muitos campos (use página); conteúdo que o usuário quer comparar com o que está atrás; empilhar modal sobre modal.
- **Boas práticas:** foco preso dentro do modal (focus trap); fecha no Esc e no clique fora (se não destrutivo); botão de fechar visível; retorna o foco ao gatilho ao fechar; título claro e ação primária evidente.

### Drawer / painel lateral
- **Quando usar:** conteúdo/ações contextuais sem perder o contexto de trás (detalhes, filtros, carrinho).
- **Boas práticas:** desliza de um lado; overlay que fecha ao clicar fora; não use para fluxos longos.

### Popover / bottom sheet
- **Popover:** pequeno conteúdo ancorado a um gatilho (menu de ações, mini-form).
- **Bottom sheet (mobile):** ações/opções ancoradas na parte inferior, ao alcance do polegar.
- **Boas práticas:** posicione perto do gatilho; feche ao tocar fora; alvos grandes.

---

## 7. Onboarding e primeira experiência

- **Prefira o "empty state" que ensina fazendo** a tours/coach marks que ninguém lê.
- **Coach marks / tour:** use com muita parcimônia; sempre pulável; nunca bloqueie o uso. Um bom design não precisa de tour (Norman/Krug).
- **Divulgação progressiva no onboarding:** peça só o mínimo para o primeiro valor; adie o resto.
- **Defaults inteligentes e conteúdo de exemplo** reduzem o "medo da tela em branco".

---

## Como escolher (roteiro rápido)

1. **Nomeie a tarefa da tela** e o dado envolvido (ver SKILL.md).
2. **Procure a convenção** que o usuário já conhece para essa tarefa antes de inventar.
3. **Escolha o padrão mais simples** que cumpre a tarefa; não adicione um padrão "porque fica moderno".
4. **Desenhe todos os estados** do padrão (vazio, carregando, erro, cheio) — não só o feliz.
5. **Cheque contra as leis** (`leis-heuristicas.md`), a **acessibilidade** (`acessibilidade.md`) e o **visual** (`design-visual.md`, `ui-moderno.md`).
