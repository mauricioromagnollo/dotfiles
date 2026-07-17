# UI/UX Moderno — Digest Acionável (2023–2026)

Referência prática para decisões de design de produto. Valores concretos (px, ms, razões)
prontos para virar tokens. Fontes ao final.

---

## 1. Design Systems e Design Tokens

**O que são.** Tokens são as decisões de design nomeadas (cor, espaço, tipo, raio, sombra,
motion) armazenadas como variáveis. Fonte única de verdade → consistência e troca de tema
sem refatorar componentes.

**Arquitetura em 3 camadas (use sempre):**
- **Global / primitivos:** valores crus. `--blue-600: #2563eb`, `--space-4: 16px`.
- **Semânticos / alias:** apontam para primitivos pelo papel. `--color-surface`,
  `--color-text-primary`, `--color-border`, `--color-danger`. Componentes consomem ESTA camada.
- **Component:** escopo por componente. `--button-bg → --color-primary`.
- Regra de ouro: nunca use primitivo direto no componente. Nomeie pelo papel (surface,
  text-primary, border), nunca pelo valor (white, gray-900). Assim dark mode/rebrand = trocar
  uma camada.

**Escala de espaçamento (base 4px, múltiplos de 4/8).** Nunca use valores arbitrários.
```
--space-0: 0     --space-1: 4px   --space-2: 8px   --space-3: 12px
--space-4: 16px  --space-5: 20px  --space-6: 24px  --space-8: 32px
--space-10: 40px --space-12: 48px --space-16: 64px --space-24: 96px
```
- Base 4px dá granularidade para UI densa; 8px para ritmo mais folgado. Padding interno de
  componentes tende a 8/12/16; gaps entre grupos 24/32/48.

**Escala tipográfica (razão modular ~1.2–1.25, use rem).** rem respeita o zoom/preferência
do usuário.
```
xs 12px  sm 14px  base 16px  lg 18px  xl 20px  2xl 24px
3xl 30px  4xl 36px  5xl 48px  6xl 60px
```
- Corpo de texto: 16px mínimo (14px só para metadados/labels). Line-height: 1.5–1.6 para
  corpo, 1.1–1.25 para títulos grandes. Comprimento de linha ideal: 50–75 caracteres (~65ch).
- Limite os pesos: 400 (corpo), 500/600 (ênfase/subtítulo), 700 (títulos). Evite <400.

**Tokens de cor semânticos mínimos:** `surface`, `surface-raised`, `text-primary`,
`text-secondary` (~70% de contraste do primary, não cinza claro), `text-muted`, `border`,
`primary`, `primary-hover`, `danger`, `warning`, `success`, `info`. Cada um com variantes
`-bg`, `-fg`, `-border` quando fizer sentido (ex.: alertas).

---

## 2. Refactoring UI (Wathan / Schoger)

**Hierarquia por peso e cor, não por tamanho.** Antes de aumentar a fonte, mude cor e peso.
Três "cores" de texto: primária (títulos/valores), secundária (corpo), terciária (metadados).
Diferencie por opacidade/tom, não só por font-size.

- **Texto secundário: aproxime da cor de fundo, não use cinza claro puro.** Em fundo colorido,
  escolha um tom da mesma família (mais claro/dessaturado), não cinza.
- **Cor com propósito.** Reserve a cor de destaque para ação/ênfase. Interface majoritariamente
  neutra; cor pontual guia o olho.
- **Sombras = profundidade real.** Sombra pequena e pouco borrada = elemento perto da
  superfície (botões, inputs). Sombra grande e borrada = elevado, foco (modais, popovers).
  Use uma escala de elevação (ex.: 5 níveis), não sombras aleatórias.
  ```
  sm:  0 1px 2px rgba(0,0,0,.05)
  md:  0 4px 6px -1px rgba(0,0,0,.1), 0 2px 4px -2px rgba(0,0,0,.1)
  lg:  0 10px 15px -3px rgba(0,0,0,.1)
  xl:  0 20px 25px -5px rgba(0,0,0,.1)
  ```
  Sombras realistas combinam duas: uma ambiente (grande, difusa) + uma direta (pequena, nítida).
- **Menos bordas.** Para separar elementos, prefira, nesta ordem: espaçamento → cor de fundo
  diferente → sombra. Borda é o último recurso; borda em tudo deixa a UI "ruidosa".
- **Espaçamento cria grupos (proximidade).** Aproxime o que é relacionado, afaste o que não é.
  Comece com espaçamento "grande demais" e reduza — designers iniciantes apertam demais.
- **Comece pelo layout em preto e branco.** Resolva hierarquia com espaço/tamanho/contraste
  antes de introduzir cor.
- **Estados vazios merecem design.** A tela vazia costuma ser a primeira impressão; trate-a
  como feature, não como afterthought (ver seção 4).
- **Dê personalidade com detalhes.** Ícones, ilustrações, estados de foco. Botão "supom" a
  ação principal; ações secundárias mais discretas (ghost/outline/link).

---

## 3. UX de Formulários (Baymard + NNG)

**Labels ACIMA do campo.** Sempre visíveis ao digitar, leitura vertical rápida, funcionam
com quebra de linha no mobile. Evite:
- **Labels inline (dentro do campo como placeholder):** somem ao digitar → perda de contexto;
  em teste de usabilidade Baymard causaram apagar o input inteiro só para reler o label. Nunca
  use placeholder como label.
- **Floating labels:** aceitáveis, mas exigem cuidado extra no estado de erro; label fica
  pequeno. Na dúvida, label estático acima.

**Um campo por linha.** Layout de coluna única é mais rápido de completar e menos propenso a
erro. Exceções permitidas quando os campos são logicamente ligados e curtos (CEP + número,
cidade + UF, validade MM/AA).

**Reduza campos ao mínimo.** Cada campo removido aumenta conversão. Não peça o que dá para
derivar (cidade/UF a partir do CEP). Marque o que é OPCIONAL, não o obrigatório, se a maioria
for obrigatória (ou vice-versa) — seja consistente e explícito.

**Validação inline correta:**
- Valide **on-blur** (ao sair do campo), não a cada tecla — validar enquanto digita gera erro
  prematuro (ex.: e-mail acusado antes de terminar).
- **Feedback positivo em tempo real** é ok (check verde ao acertar).
- **Mensagem de erro abaixo do campo**, junto ao campo — nunca só um banner no topo.
- Boa mensagem de erro tem 3 qualidades: **diz o que deu errado, por quê, e o que fazer.**
  Ex.: "Senha precisa de ao menos 8 caracteres" em vez de "Senha inválida".
- Preserve o input do usuário em erro (não limpe o campo).

**Tipos de input corretos (mobile abre o teclado certo):**
- `type="email"`, `type="tel"`, `type="number"` / `inputmode="numeric"`, `type="url"`.
- `inputmode="decimal"` para valores, `autocomplete` apropriado (`name`, `email`,
  `cc-number`, `one-time-code`), `enterkeyhint`.
- Toque mínimo 44–48px de altura no campo (ver seção 6).

**Outros:** agrupe campos relacionados (fieldset/legend), mostre requisitos de senha antes do
erro, botão de submit com estado de loading e desabilitado durante envio (evita duplo submit).

---

## 4. Estados de UI

Modele SEMPRE os estados para qualquer dado assíncrono: **loading, empty, error, success**
(mais idle/partial). Nunca renderize "nada" enquanto carrega nem exponha erro cru.

**Loading — skeleton vs spinner:**
- **Skeleton** quando você conhece a estrutura do conteúdo (listas, cards, perfil): mostra o
  layout, reduz o tempo percebido de espera.
- **Spinner** para ação/processamento sem estrutura definida (salvar, enviar) ou áreas pequenas.
- **Regra dos 300ms:** se a espera for < ~300ms, não mostre indicador — flash de spinner
  parece glitch. Responda a todo clique com feedback imediato (mesmo que só mudar estado do botão).
- Duração previsível → barra de progresso/etapas; indefinida → spinner/skeleton.
- **UI otimista:** para ações de baixo risco, atualize a interface na hora assumindo sucesso e
  reconcilie depois; sensação de instantâneo, sem loader. Reverta com feedback em caso de falha.

**Empty state:** eduque + oriente. Diga o que apareceria ali, por que está vazio, e um CTA
claro ("Criar primeiro projeto"). Diferencie "vazio de verdade" (nunca teve dado) de "zero
resultados" (filtro/busca) — no segundo, ofereça limpar filtro. Ilustração/ícone opcional.

**Error state:** mensagem específica e humana + ação de recuperação (Tentar de novo).
Nunca stack trace ou objeto de erro cru. Distinga erro de rede (retry) de erro de validação
(corrigir input) de erro de permissão.

**Success feedback:** confirme visivelmente (toast/inline/estado atualizado). Toast some sozinho
(4–6s) para info; confirmação persistente para ações destrutivas/importantes.

**Estados interativos — implemente TODOS:**
- `:hover` — feedback de affordance (desktop): leve mudança de bg/elevação.
- `:focus-visible` — anel de foco visível SEMPRE (acessibilidade/teclado). Nunca
  `outline: none` sem substituto. Anel ~2px com offset, cor de contraste.
- `:active` — resposta ao toque/clique (leve "afundar").
- `disabled` — reduzir opacidade (~0.5) + `cursor: not-allowed`; não depender só de cor;
  idealmente explicar por que está desabilitado.
- Estados de seleção/checado, loading no próprio botão, erro no campo.

---

## 5. Microinterações e Movimento

**Propósito primeiro.** Movimento comunica: causa→efeito, para onde algo vai, mudança de
estado, hierarquia de entrada. Decoração sem função distrai — use com moderação.

**Durações (tokens Material 3, bons defaults):**
```
short1  50ms   ripple/fade micro
short2  100ms  troca de estado de ícone, hover
short4  200ms  botão, toggle
medium1 250ms  expandir card
medium2 300ms  transição padrão de componente
long1   450ms  transição de página
long2   500ms  expandir full-screen
```
- Regra geral: hover/feedback pequeno 100–200ms; transições de componente 200–300ms;
  entradas/páginas 300–500ms. **Sair mais rápido que entrar.** Nada > ~500ms em UI comum.
- Distância maior / elemento maior → duração um pouco maior.

**Easing (cubic-bezier):**
```
standard              cubic-bezier(0.2, 0.0, 0, 1.0)   uso geral
emphasized            cubic-bezier(0.2, 0.0, 0, 1.0)   entradas expressivas (partida rápida, pouso suave)
emphasized-decelerate cubic-bezier(0.05, 0.7, 0.1, 1.0) elemento ENTRANDO na tela
emphasized-accelerate cubic-bezier(0.3, 0.0, 0.8, 0.15) elemento SAINDO da tela
```
- Entra desacelerando (decelerate), sai acelerando (accelerate). Evite `linear` (robótico),
  exceto spinners/progress contínuos. Micro-interações curtas (50–100ms) usam standard — em
  emphasized o "arranque lento" fica perceptível e parece lento.

**Acessibilidade (obrigatório):**
```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: .01ms !important;
    transition-duration: .01ms !important;
    scroll-behavior: auto !important;
  }
}
```
- Troque física/spring por fade simples de opacidade. Nunca dependa só de movimento para
  comunicar informação essencial.

---

## 6. Mobile

**Touch targets:** mínimo **44×44px (Apple HIG)** / **48×48dp (Material)**. Recomendado 48px.
- Ícone pode ser 24px visual com área tocável expandida a 48px via padding.
- **Espaço entre alvos ≥ 8px** (zona de exclusão ~7mm). Alvos pequenos aumentam mis-tap 60–80%.

**Thumb zone (polegar):**
- Ações primárias na metade/terço inferior da tela (zona natural do polegar), quadrante
  inferior-direito para destros.
- Evite cantos superiores para ações frequentes (exigem trocar a pegada).
- Nav principal no rodapé (bottom bar/tab bar) em vez do topo.

**Safe areas (obrigatório):**
```css
padding-bottom: env(safe-area-inset-bottom);
padding-top: env(safe-area-inset-top);
```
- Respeite notch, home indicator (iOS) e barra de gestos (Android). Não coloque tap targets
  colados nas bordas onde gestos do sistema disparam.

**Gestos:** zonas de swipe 44–48px de altura para carrosséis/listas. Sempre ofereça
alternativa visível (botão) — gesto oculto não é descobrível. Não sequestre gestos do sistema
(swipe-back).

**Mobile-first:** desenhe para a menor tela primeiro (prioriza conteúdo essencial), depois
progressive enhancement para telas maiores. Uma coluna no mobile; input types corretos (seção 3).

---

## 7. Responsividade e Breakpoints

**Breakpoints (defaults modernos, mobile-first, `min-width`):**
```
sm  640px   md  768px   lg 1024px   xl 1280px   2xl 1536px
```
- Breakpoints devem seguir o CONTEÚDO (onde o layout quebra), não dispositivos específicos.

**Container queries (baseline desde 2023, use quando possível):** componente responde ao
tamanho do PRÓPRIO container, não da viewport → componentes de verdade reutilizáveis.
```css
.card-wrap { container-type: inline-size; }
@container (min-width: 400px) { .card { display: grid; grid-template-columns: 1fr 2fr; } }
```

**Tipografia fluida com `clamp()`** (evita saltos entre breakpoints):
```css
font-size: clamp(1rem, 0.9rem + 0.5vw, 1.25rem); /* min, ideal, max */
```
- Também para espaçamento/padding de seção fluido. Prefira `vw`/`cqi` no termo ideal.

**Grid responsivo sem media query:**
```css
grid-template-columns: repeat(auto-fit, minmax(min(100%, 16rem), 1fr));
```

**Regras gerais:** largura máxima de leitura (~65ch / container 1120px neste projeto),
imagens `max-width: 100%`, nada de scroll horizontal no body (conteúdo largo scrolla no
próprio container com `overflow-x: auto`). Use unidades relativas (rem/%/fr), não px fixos em layout.

---

## 8. Dark Mode

**Nunca use preto puro (#000).** Contraste branco-em-preto puro cansa a vista e prejudica
dislexia/astigmatismo (vibração ótica, "sangramento" do texto).
- Fundo base: **#121212** (Material) ou #1A1A1A. Texto: branco-suave (#E0E0E0 / opacidade ~87%),
  não #FFF puro.

**Elevação por luminosidade, não por sombra.** Sombras quase não aparecem em fundo escuro.
Superfícies mais elevadas ficam **mais claras**. Material 3: overlay tonal (tinta da cor
primária) aumenta com a elevação.
```
surface base   #121212
+1 (card)      ~#1E1E1E
+2 (menu)      ~#242424
+3 (modal)     ~#2C2C2C
```

**Dessature as cores de destaque.** Cores vibrantes vibram opticamente no escuro. Reduza
saturação para ~70–80% e/ou clareie. Cores puras saturadas cansam.

**Reduza contraste (sem quebrar acessibilidade).** Alvo texto/fundo ~ contraste alto porém
não máximo. Continue respeitando WCAG (corpo ≥ 4.5:1, texto grande ≥ 3:1), mas prefira
#E0E0E0 sobre #121212 a #FFF sobre #000.

**Tokens semânticos resolvem tudo.** Dark mode = trocar a camada semântica; componentes não
mudam. Suporte via `prefers-color-scheme`, atributo/classe `[data-theme]`, ou `light-dark()`
no CSS. Teste componentes elevados nos DOIS temas. Ajuste imagens/ilustrações com fundo branco.

---

## Checklist rápido

- [ ] Tokens em 3 camadas; componentes só consomem semânticos.
- [ ] Espaço em múltiplos de 4/8; tipo em rem, escala ~1.2.
- [ ] Hierarquia por peso+cor antes de tamanho; texto secundário aproxima do fundo.
- [ ] Bordas por último: espaço → cor de fundo → sombra.
- [ ] Elevação em escala (5 níveis), não sombras aleatórias.
- [ ] Labels acima; 1 campo por linha; validação on-blur; erro abaixo do campo com solução.
- [ ] input types + autocomplete + inputmode no mobile.
- [ ] 4 estados (loading/empty/error/success) + regra dos 300ms + UI otimista onde couber.
- [ ] :focus-visible sempre; disabled com opacidade + motivo.
- [ ] Motion 100–300ms, easing decelerate/accelerate, prefers-reduced-motion.
- [ ] Touch ≥ 44/48px, gap ≥ 8px, ações no thumb zone, safe-area-inset.
- [ ] Container queries + clamp(); breakpoints seguem conteúdo.
- [ ] Dark: #121212 não #000, elevação por luminosidade, cores dessaturadas.

---

## Fontes

- Nielsen Norman Group — [Touch Target Size](https://www.nngroup.com/articles/touch-target-size/)
- Baymard Institute — [Form Design: 6 Best Practices](https://baymard.com/learn/form-design) ·
  [Mobile Forms: Never Use Inline Labels](https://baymard.com/blog/mobile-forms-avoid-inline-labels)
- Jakob Nielsen — [Required Fields in Forms](https://jakobnielsenphd.substack.com/p/required-fields)
- Material Design 3 — [Easing and Duration](https://m3.material.io/styles/motion/easing-and-duration) ·
  [Tokens & Specs](https://m3.material.io/styles/motion/easing-and-duration/tokens-specs) ·
  [Motion Overview](https://m3.material.io/styles/motion/overview/how-it-works)
- Refactoring UI (Wathan/Schoger) — [refactoringui.com](https://refactoringui.com/) ·
  [7 Practical Tips for Cheating at Design](https://medium.com/refactoring-ui/7-practical-tips-for-cheating-at-design-40c736799886) ·
  [Top 20 Key Points (notes)](https://medium.com/design-bootcamp/top-20-key-points-from-refactoring-ui-by-adam-wathan-steve-schoger-d81042ac9802)
- Design tokens — [What Are Design Tokens (UXPin)](https://www.uxpin.com/studio/blog/what-are-design-tokens/) ·
  [Design Token System (Contentful)](https://www.contentful.com/blog/design-token-system/) ·
  [Design Systems & Tokens (design.dev)](https://design.dev/guides/design-systems/)
- Tipografia com tokens — [Mastering Typography in Design Systems (UX Collective)](https://uxdesign.cc/mastering-typography-in-design-systems-with-semantic-tokens-and-responsive-scaling-6ccd598d9f21)
- Estados de UI — [Loading/Error/Empty States in React (LogRocket)](https://blog.logrocket.com/ui-design-best-practices-loading-error-empty-state-react/) ·
  [Skeleton vs Spinner (Onething)](https://www.onething.design/post/skeleton-screens-vs-loading-spinners) ·
  [When to Use Loaders & Empty States (UX Collective)](https://uxdesign.cc/when-to-use-loaders-empty-states-ebd23cecc7d6) ·
  [UX Patterns for Loading (Pencil & Paper)](https://www.pencilandpaper.io/articles/ux-pattern-analysis-loading-feedback)
- Mobile / thumb zone — [Tap Targets & Thumb Zones (72Technologies)](https://www.72technologies.com/blog/tap-targets-thumb-zones-mobile-ux) ·
  [Mastering the Thumb Zone (Parachute)](https://parachutedesign.ca/blog/thumb-zone-ux/)
- Responsividade — [Container Query Units & Fluid Typography (Modern CSS)](https://moderncss.dev/container-query-units-and-fluid-typography/) ·
  [Container Queries, Grids, Fluid Type (Morgan Feeney)](https://morganfeeney.com/guides/container-queries/container-queries-responsive-grids-fluid-typography)
- Dark mode — [Dark Mode UI Best Practices (Atmos)](https://atmos.style/blog/dark-mode-ui-best-practices) ·
  [12 Principles of Dark Mode (Uxcel)](https://uxcel.com/blog/12-principles-of-dark-mode-design-627) ·
  [Dark Mode UI (LogRocket)](https://blog.logrocket.com/ux-design/dark-mode-ui-design-best-practices-and-examples/)
