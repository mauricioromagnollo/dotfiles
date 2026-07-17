# Acessibilidade Digital (a11y) — Digest Acionável

Referência prática e condensada para quem constrói UI (web e mobile), baseada nas
fontes canônicas: W3C WAI / WCAG 2.2, MDN, WebAIM, The A11Y Project, Apple HIG e
Material Design. Foco em decisões concretas de implementação e revisão.

---

## 1. Os 4 princípios POUR do WCAG

O WCAG organiza todos os critérios sob 4 princípios. Se um deles falha, usuários
com deficiência ficam sem acesso ao conteúdo. Mnemônico: **POUR**.

- **P — Perceptível (Perceivable):** a informação e os componentes de UI precisam
  ser apresentados de formas que o usuário consiga perceber. Não pode existir
  conteúdo invisível a algum sentido sem alternativa.
  - Texto alternativo para imagens; legendas e transcrições para mídia.
  - Não depender só de cor para transmitir significado.
  - Contraste suficiente entre texto/ícones e fundo.
  - Conteúdo adaptável (ordem de leitura lógica, relações semânticas preservadas).

- **O — Operável (Operable):** todos os componentes de interface e a navegação
  precisam ser operáveis por qualquer forma de entrada.
  - Tudo acessível e acionável pelo teclado, sem armadilhas de foco.
  - Tempo suficiente para ler e interagir (evitar timeouts curtos).
  - Não causar convulsões (nada que pisque mais de 3 vezes por segundo).
  - Foco visível, ordem de foco lógica, alvos de toque com tamanho adequado.

- **U — Compreensível (Understandable):** a informação e a operação da interface
  precisam ser compreensíveis.
  - Linguagem clara; atributo `lang` correto.
  - Comportamento previsível (nada muda de contexto sem aviso).
  - Ajuda na entrada de dados: labels, instruções, mensagens de erro claras e
    sugestões de correção.

- **R — Robusto (Robust):** o conteúdo precisa ser robusto o bastante para ser
  interpretado por uma ampla variedade de agentes de usuário, incluindo
  tecnologias assistivas (leitores de tela).
  - HTML válido e semântico; nome, função (role) e valor (state) expostos
    corretamente a11y para cada componente customizado.
  - Mensagens de status anunciadas (`aria-live`) sem roubar o foco.

---

## 2. Níveis de conformidade A / AA / AAA — e por que mirar AA

O WCAG 2.2 tem 13 guidelines com critérios de sucesso testáveis, em três níveis:

- **A (mínimo):** barreiras mais críticas. Sem isso, grupos inteiros ficam
  totalmente bloqueados. É o piso, não a meta.
- **AA (recomendado / padrão de mercado):** satisfaz A + AA. É o alvo prático da
  maioria das leis e contratos (ex.: legislações de acessibilidade, exigências de
  setor público, políticas corporativas). Inclui contraste 4.5:1, redimensionamento
  de texto, foco visível, etc.
- **AAA (aprimorado):** o nível mais alto. Não é recomendado como exigência para
  sites inteiros porque nem sempre é possível satisfazer para todo tipo de conteúdo.

**Por que mirar AA:** é o equilíbrio entre impacto real para o usuário e viabilidade
técnica. É o nível referenciado por regulações e pela maioria dos requisitos de
conformidade ("WCAG 2 Level AA Conformance"). AAA é ótimo como aspiração pontual
(ex.: contraste 7:1 em texto crítico), mas não como baseline universal.

> Importante: mesmo conteúdo em AAA não é acessível para todas as combinações de
> deficiência (especialmente cognitivas). Conformidade é o começo, não o fim — teste
> com pessoas reais e tecnologias assistivas.

---

## 3. Critérios práticos de maior impacto

### 3.1 Contraste de cor

- **Texto normal:** mínimo **4.5:1** (WCAG 1.4.3, AA). Texto "normal" = menor que
  18pt regular ou 14pt bold.
- **Texto grande:** mínimo **3:1**. "Grande" = ≥ 18pt (≈24px) regular, ou ≥ 14pt
  (≈18.66px) bold.
- **Componentes de UI e gráficos (não-texto):** mínimo **3:1** (WCAG 1.4.11, AA).
  Vale para bordas de input, ícones informativos, estados de foco/hover, limites de
  botões, partes de gráficos necessárias para entender a informação.
- **AAA (aprimorado, 1.4.6):** **7:1** texto normal / **4.5:1** texto grande.
- Verifique também texto sobre imagens/vídeo e a cor de seleção customizada.
- Ferramentas: WebAIM Contrast Checker, DevTools do navegador, axe.

### 3.2 Tamanho de alvo de toque

- **WCAG 2.2 (2.5.8 Target Size Minimum, AA):** alvo precisa comportar um quadrado
  de **24×24 CSS px** (ou ter espaçamento equivalente entre alvos). Exceções:
  alvos inline em texto, ou quando há um equivalente alternativo.
- **WCAG 2.2 (2.5.5 Target Size Enhanced, AAA):** **44×44 CSS px**.
- **Apple HIG:** mínimo **44×44 pt** para qualquer controle tocável.
- **Material Design:** mínimo **48×48 dp** de área tocável.
- Regra prática: para produção mire ~44–48px de área tocável (mesmo que o visual do
  ícone seja menor, expanda a área de toque com padding/hit area).

### 3.3 Navegação por teclado e ordem de foco

- Tudo que é interativo deve ser alcançável e acionável **só com teclado**
  (Tab/Shift+Tab, Enter/Espaço, setas em widgets compostos).
- Sem **armadilhas de foco** (o usuário sempre consegue sair de um componente).
- **Ordem de foco** deve seguir a ordem visual/lógica de leitura. Não use `tabindex`
  positivo (> 0); use apenas `0` (inclui no fluxo natural) ou `-1` (focável só via
  script).
- Evite `autofocus`. Remova elementos focáveis invisíveis (menus fechados,
  navegação fora da tela) do fluxo de foco.
- Ofereça **skip link** ("pular para o conteúdo") para saltar navegação repetida.

### 3.4 Foco visível

- Todo elemento interativo precisa de estado `:focus` claramente visível
  (WCAG 2.4.7, AA). **Nunca** use `outline: none` sem substituir por indicador
  equivalente.
- Prefira `:focus-visible` para mostrar o anel de foco na navegação por teclado sem
  poluir o clique de mouse.
- WCAG 2.2 acrescenta: **2.4.11 Focus Not Obscured (AA)** — o elemento focado não
  pode ficar totalmente escondido por conteúdo do autor (ex.: header sticky, cookie
  banner cobrindo o foco). **2.4.13 Focus Appearance (AAA)** define contraste e área
  mínima do indicador.

### 3.5 Textos alternativos (alt)

- Toda `<img>` informativa precisa de `alt` descritivo e conciso.
- Imagem **decorativa:** `alt=""` (vazio) para o leitor de tela ignorar.
- Imagens complexas (gráficos, mapas): forneça descrição longa (texto adjacente,
  tabela de dados, `aria-describedby`).
- Se a imagem contém texto, replique esse texto no `alt`.
- Ícone-botão sem rótulo visível precisa de nome acessível (`aria-label` ou texto
  visualmente oculto).

### 3.6 Labels em formulários

- Todo campo precisa de `<label for="id">` associado ao `id` do input (ou o input
  envolvido pelo label). Placeholder **não** substitui label.
- Agrupe campos relacionados (rádios, checkboxes) com `<fieldset>` + `<legend>`.
- Use `autocomplete` apropriado (ex.: `autocomplete="email"`) — ajuda todos e
  atende WCAG 1.3.5.
- Não remova indicação de campos obrigatórios só por cor; use texto/`aria-required`.

### 3.7 Mensagens de erro acessíveis

- Identifique o erro em **texto** e indique **qual campo** e **como corrigir**
  (WCAG 3.3.1 / 3.3.3).
- Associe a mensagem ao campo com `aria-describedby`; marque o campo com
  `aria-invalid="true"`.
- Anuncie erros dinâmicos via região `aria-live` (ou mova o foco para o resumo de
  erros no topo do formulário).
- Não comunique estado (erro/sucesso/aviso) só por cor — use ícone + texto.
- WCAG 2.2 (3.3.7 Redundant Entry / 3.3.8 Accessible Authentication): não obrigue
  o usuário a reinserir dados já fornecidos nem a resolver puzzles cognitivos para
  autenticar.

### 3.8 Hierarquia de headings

- Um único `<h1>` por página/view, descrevendo o propósito principal.
- Níveis em ordem descendente **sem pular** (h1 → h2 → h3...). Não escolha nível por
  tamanho visual — escolha por estrutura, estilize com CSS.
- Headings são a principal forma de navegação de usuários de leitor de tela.

### 3.9 Landmarks (regiões)

- Use elementos semânticos: `<header>`, `<nav>`, `<main>` (um por página),
  `<aside>`, `<footer>`. Eles viram landmarks navegáveis por tecnologia assistiva.
- Se houver múltiplas regiões do mesmo tipo (ex.: duas `<nav>`), diferencie com
  `aria-label`.

### 3.10 ARIA — e a 1ª regra do ARIA

- **1ª regra do ARIA:** se existe um elemento/atributo HTML nativo com a semântica e
  o comportamento que você precisa, **use o nativo** em vez de recriar com ARIA.
  Nativos já trazem role, estado e acessibilidade de teclado de graça.
- Use ARIA só quando: o recurso não existe em HTML; restrições de design impedem o
  elemento nativo; ou o suporte nativo é insuficiente.
- **"No ARIA is better than bad ARIA."** Levantamento da WebAIM em >1 milhão de home
  pages: páginas com ARIA tiveram em média **41% mais erros detectados**. ARIA mal
  usado piora a acessibilidade.
- ARIA muda apenas semântica exposta — **não** adiciona comportamento (teclado,
  foco): isso é responsabilidade do seu JS/CSS.

### 3.11 Respeitar prefers-reduced-motion

- Ofereça alternativa para usuários sensíveis a movimento:
  ```css
  @media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
      scroll-behavior: auto !important;
    }
  }
  ```
- Evite parallax agressivo, auto-play e animações grandes de entrada.
- WCAG 2.2.2: conteúdo em movimento/auto-atualização precisa de pausar/parar/ocultar.

### 3.12 Não depender só de cor

- Cor não pode ser o **único** meio de transmitir informação (WCAG 1.4.1, A).
- Links dentro de texto: sublinhe ou dê outro sinal além da cor.
- Estados (erro, sucesso, selecionado) precisam de ícone, texto ou padrão além da
  cor. Teste em modo alto contraste e escala de cinza.

### 3.13 Tamanho de fonte e zoom

- Não desabilite o zoom (`user-scalable=no` ou `maximum-scale=1` são anti-padrão).
- **WCAG 1.4.4 (Resize Text, AA):** texto redimensionável até **200%** sem perda de
  conteúdo/função e sem scroll horizontal.
- **WCAG 1.4.10 (Reflow, AA):** conteúdo utilizável a **320 CSS px** de largura
  (equivalente a 400% de zoom) sem scroll em dois eixos.
- Use unidades relativas (`rem`/`em`) para fontes e espaçamentos, não `px` fixo em
  tudo. Base confortável ~16px.
- **WCAG 1.4.12 (Text Spacing, AA):** layout não pode quebrar quando o usuário ajusta
  altura de linha, espaçamento de letras/palavras/parágrafos.

---

## 4. Checklist rápido de a11y para revisão de UI

Estrutura e semântica
- [ ] `<html lang="...">` correto e `<title>` único por página.
- [ ] Um `<h1>`; headings em ordem lógica sem pular níveis.
- [ ] Landmarks: `<header>`, `<nav>`, `<main>` (um só), `<footer>`.
- [ ] HTML semântico e válido; `<button>` para ações, `<a href>` para navegação.

Teclado e foco
- [ ] Tudo operável só por teclado; sem armadilha de foco.
- [ ] Ordem de foco = ordem visual; sem `tabindex` positivo; sem `autofocus`.
- [ ] Foco sempre visível (`:focus-visible`); nunca `outline:none` sem substituto.
- [ ] Foco nunca fica escondido atrás de header/banner sticky.
- [ ] Skip link para o conteúdo principal.

Cor e contraste
- [ ] Texto ≥ 4.5:1 (grande ≥ 3:1); UI/ícones/bordas ≥ 3:1.
- [ ] Informação nunca depende só de cor.
- [ ] OK em alto contraste, cores invertidas e escala de cinza.

Alvos e mobile
- [ ] Alvos de toque ≥ 24px (WCAG) / mire 44–48px (Apple/Material).
- [ ] Sem scroll horizontal; reflow a 320px; suporta orientação retrato/paisagem.

Texto e zoom
- [ ] Legível a 200% de texto e 400% de zoom.
- [ ] Unidades relativas; layout não quebra com ajuste de text-spacing.

Imagens e mídia
- [ ] `alt` descritivo em imagens informativas; `alt=""` em decorativas.
- [ ] Legendas em vídeo, transcrição em áudio; sem autoplay.
- [ ] Nada pisca mais de 3x/segundo.

Formulários
- [ ] `<label>` associado a cada campo (placeholder não conta).
- [ ] `fieldset`/`legend` em grupos; `autocomplete` apropriado.
- [ ] Erros em texto, ligados por `aria-describedby`, `aria-invalid`, anunciados.
- [ ] Não força reinserção de dados nem puzzle cognitivo para autenticar.

ARIA e movimento
- [ ] Nativo primeiro; ARIA só quando necessário (1ª regra do ARIA).
- [ ] Nome/role/estado corretos em componentes customizados; `aria-live` em status.
- [ ] `prefers-reduced-motion` respeitado; movimento pode ser pausado.

Validação final
- [ ] Rodar axe / Lighthouse / WAVE.
- [ ] Testar com leitor de tela real (VoiceOver, NVDA) e só teclado.
- [ ] Ferramentas automáticas pegam ~30–40%; teste manual é indispensável.

---

## Fontes

- W3C WAI — WCAG 2.2 (Recommendation): https://www.w3.org/TR/WCAG22/
- W3C WAI — WCAG 2 Overview: https://www.w3.org/WAI/standards-guidelines/wcag/
- W3C WAI — What's New in WCAG 2.2: https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/
- W3C WAI — Understanding Conformance: https://www.w3.org/WAI/WCAG21/Understanding/conformance
- W3C WAI — WCAG 2 Level AA Conformance: https://www.w3.org/WAI/WCAG2AA-Conformance
- W3C WAI — Understanding 1.4.3 Contrast (Minimum): https://www.w3.org/WAI/WCAG21/Understanding/contrast-minimum.html
- W3C WAI — Understanding 2.5.8 Target Size (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- W3C WAI — Understanding 2.4.11 Focus Not Obscured (Minimum): https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- W3C — Using ARIA (1ª regra do ARIA): https://www.w3.org/TR/using-aria/
- MDN — ARIA: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA
- WebAIM — WCAG 2 Checklist: https://webaim.org/standards/wcag/wcag22
- WebAIM — WCAG 2.2 Overview and Feedback: https://webaim.org/blog/wcag-2-2-overview-and-feedback/
- The A11Y Project — Checklist: https://www.a11yproject.com/checklist/
- Apple — Human Interface Guidelines, Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Material Design — Accessibility / Touch targets: https://m3.material.io/foundations/designing/structure e https://m2.material.io/develop/web/supporting/touch-target
