# Design Visual de Interfaces — Digest Acionável

Fonte: "Como aprender Design de Interfaces — O Guia Definitivo", Gabriel Silvestri (67 páginas, pt-br).
Foco: fundamentos de **design visual de UI**. O livro é introdutório/prático (nível iniciante).

> Nota de escopo: o autor NÃO nomeia as leis de Gestalt explicitamente (proximidade, semelhança,
> continuidade, fechamento, figura-fundo). Ele trabalha os efeitos equivalentes sob outros nomes
> — "espaço", "agrupamento", "consistência", "hierarquia visual", "affordances/signifiers".
> Abaixo os fundamentos são organizados pelos temas pedidos; onde o livro não cobre algo, está marcado
> como **[fora do livro — padrão de mercado]** para manter o digest acionável sem inventar autoria.

---

## 1. Princípios base do autor (6 princípios de UI)

O autor estrutura tudo em 6 princípios fundamentais. Ordem de prioridade e aplicação:

1. **Espaço** (whitespace / espaço negativo)
2. **Grids e alinhamento**
3. **Consistência**
4. **Hierarquia visual**
5. **Usabilidade** (affordances, signifiers, eficiência, tolerância a erro)
6. **Design visual** (cores, tipografia, componentes)

Regra mestra: a parte visual bonita (cor, tipo, efeitos) é a **ÚLTIMA** coisa a resolver.
Primeiro estrutura (espaço → grid → hierarquia), depois pele (cor → tipo → detalhes).
Aplicar os 6 princípios em cada elemento visual é o que faz diferença. "Simplicidade é o último grau
de sofisticação."

---

## 2. Espaçamento / Whitespace (o princípio mais importante)

- Interface com boa legibilidade, usabilidade e elegância **tem MUITO espaço**. Espaço em branco
  não é desperdício — é o que faz a interface ser boa.
- Espaço gera **Ordem, Organização e Ênfase**.
- Dois níveis, sempre pensar nos dois:
  - **Espaço micro**: espaço interno dos elementos (padding dentro de card, botão, entre número e label).
  - **Espaço macro**: espaço entre grupos de elementos (entre seções, blocos, cards).
- Aumentar espaço ao redor de um elemento = aumentar sua ênfase/importância (ligação direta com hierarquia).
- **[fora do livro — padrão de mercado]** Trabalhe espaçamento em escala base 8 (4, 8, 12, 16, 24, 32, 48, 64px)
  para consistência; agrupar por proximidade (menos espaço = pertence junto; mais espaço = grupos distintos)
  é a lei de Gestalt da proximidade aplicada.

### Agrupamento (proxy de Gestalt: proximidade + semelhança)
- Listado como alavanca de hierarquia: agrupar elementos relacionados cria blocos que o olho lê como unidade.
- Elementos com mesma cor/tamanho/forma são lidos como "do mesmo tipo" (semelhança) — usar para padronizar
  botões, tags, ícones de uma mesma categoria.

---

## 3. Grids e Alinhamento

- Grid = "esqueleto" da interface; define regra de organização e alinhamento.
- Grids de UI digital **não têm linhas horizontais (rows)** — não há controle exato de altura/largura da tela
  (responsividade). Foque em **colunas + alinhamento**, não em cálculos complexos de row.
- O essencial para iniciante: **alinhamento**. Alinhe tudo a uma estrutura simples.

### Estrutura de 3 linhas (mobile e desktop, simples)
- 3 linhas-guia: uma no canto esquerdo com margem de **30px**, uma no centro, uma no canto direito com **30px**.
- Serve para alinhar rapidamente todos os elementos sem cálculo. Baixo esforço, resultado consistente.

### Estrutura de 12 colunas (desktop)
- Frame **1260 x 2500**.
- Grid: **12 colunas**, **width 70**, **gutter 30**, alinhado ao **centro**, offset 0.
- Padrão que devs front-end já conhecem (facilita handoff).

### Tamanhos de tela de referência
- Web: resolução mais usada 1366x768; autor trabalha em **1600x900**. Não há "certo/errado".
- Mobile: **375x667** (iPhone 8) como base.
- O dev torna responsivo/adaptável na implementação — ajustes finos saem daí.

**[fora do livro — padrão de mercado]** Alinhamento óptico > matemático em ícones; nunca deixe elementos
"quase alinhados" (o pior estado). Continuidade de Gestalt: olhos seguem linhas/bordas alinhadas.

---

## 4. Consistência

Interface inconsistente parece feita às pressas e mal revisada. Padronize via:

- **A) Espaço e escala de tamanhos**: NÃO usar tamanhos aleatórios. Definir uma hierarquia de escala
  e reutilizar os mesmos valores em toda a interface.
- **B) Cores**: NÃO usar cores "parecidas" aleatoriamente. Usar **uma paleta selecionada e funcional**
  (mesmo botão sempre com a mesma cor/estilo/raio/sombra).
- **C) Tipografia**: NÃO escolher tamanho de fonte no olho a cada texto. **Definir e documentar uma
  escala tipográfica** e definir famílias de fonte fixas.

Regra prática: se um elemento se repete (botão, card, título), ele deve ter **sempre** os mesmos
atributos. Documente tokens (tamanhos, cores, espaços).

---

## 5. Hierarquia Visual

Hierarquia = deixar claro o que é mais importante. É aplicada como a consistência (padrões deliberados),
manipulando 5 alavancas:

1. **Tipografia (peso)** — bold/regular/light, tamanho.
2. **Cores (contraste)** — mais contraste = mais destaque.
3. **Escala de tamanhos** — maior = mais importante.
4. **Espaço** — mais espaço ao redor = mais ênfase.
5. **Agrupamento** — blocos relacionados juntos.

Exemplo do livro (popup bom vs ruim): título maior e em peso forte, CTA em cor de contraste (laranja),
texto secundário menor e apagado. O olho vai para o mais contrastante/maior/mais espaçado.

Aplicação em componentes (ênfase): ação principal (ex.: "Entrar") = botão destacado; ação secundária
(ex.: "Esqueci a senha") = só texto pequeno perto do form.

**[fora do livro — figura-fundo]** Use contraste de brilho/cor para separar figura (conteúdo/CTA) do fundo;
sombra e elevação (cards) criam camadas de profundidade que reforçam hierarquia.

---

## 6. Cor (modelo HSB — núcleo do capítulo de cores)

Regra do autor: **esqueça RGB e HEX na criação; trabalhe em HSB.** HSB é o jeito mais versátil de gerar
variações e paletas.

### HSB
- **H (Hue / Matiz)**: qual cor. Posição na roda de cores em graus. **0° vermelho, 120° verde, 240° azul**.
- **S (Saturation / Saturação)**: quão vívida. 0–100. 100% = intensa/vibrante; 0% = cinza (sem cor).
- **B (Brightness / Brilho)**: quão clara. 0% = preto; 100% = brilho máximo da cor.

### Categorias de cor numa boa interface
- **Cor primária**: identidade visual (Facebook=azul, Netflix=vermelho, Nubank=roxo).
  Precisa de **5 a 10 variações** claras/escuras da primária.
- **Cores de acentuação** (destacar/comunicar), 4 tipos:
  - **Contraste**: botões importantes, labels, destaques.
  - **Perigo**: variações de **vermelho** (deletar, ação destrutiva).
  - **Alerta**: variações de **amarelo** (atenção, avisos).
  - **Positivo/sucesso**: variações de **verde** (confirmação, valores subindo).
  → semântica de cor: vermelho=erro/destrutivo, amarelo=atenção, verde=sucesso.
- **Tons de cinza**: quase todo elemento (textos, forms, controles) é cinza.
  Precisa de **6 a 10 tons** diferentes.
  **Nunca use preto 100%** — quase nunca fica harmonioso; use sempre cinzas/acinzentados.

### Método para gerar a paleta (o "pulo do gato")
1. Escolha a cor primária base — teste-a aplicada como se fosse um botão. Prefira um **meio-termo**
   (nem muito clara nem muito escura).
2. **Variações ESCURAS**: **+ saturação, − brilho**. Copie a base, aumente S, diminua B; repita até
   escuro o suficiente.
3. **Variações CLARAS**: **− saturação, + brilho**. Copie a base, diminua S, aumente B; repita.
4. Repita o mesmo processo para as cores de acentuação e estados.
5. **Cinzas**: a base não importa muito — pegue um cinza quase preto e vá **variando só o brilho**
   até ter uma boa escala de tons.

Aviso: geradores de paleta aleatórios (5 cores random) produzem interfaces feias/estranhas. Uma
interface real precisa de **muito mais que 5 cores** — daí a necessidade das variações sistemáticas.

**[fora do livro — contraste/acessibilidade]** Garanta contraste WCAG: texto normal ≥ 4.5:1,
texto grande ≥ 3:1 contra o fundo; não comunique estado só por cor (adicione ícone/label).

---

## 7. Tipografia (3 pilares)

Pilares: **1) Escala de tamanhos, 2) Boas fontes, 3) Legibilidade.**

### Escala tipográfica (pronta, recomendada pelo autor)
Use uma escala pronta em vez de reinventar. Escala do autor (px):
**12, 14, 16, 18, 20, 24, 30, 36, 48, 60, 72**
- Boa diferença entre passos → versátil. Ex.: 12px legendas/detalhes, 18px botões, 48px títulos.
- Máximo **2 fontes por interface** (há quem use 1). Definir fonte para títulos/subtítulos/botões/legendas
  primeiro, depois a fonte de corpo; então testar tamanhos, pesos e variações.

### Boas fontes
- Buscar em **Google Fonts** e **TypeWolf** (também Typekit).
- Na dúvida, use **Sans Serif** — melhor legibilidade em tela: **Roboto, Helvetica, Open Sans**.
- Listas do autor:
  - **Títulos/subtítulos**: Roboto, Proxima Nova, Freight Sans, Montserrat, Harmonia Sans.
  - **Corpo de texto**: Source Serif Pro, Source Sans, Open Sans, Merriweather, Franklin Gothic.
  - **Dashboards/aplicações**: Inter UI, Roboto, Source Sans, Lato, Open Sans.
- Critérios para escolher a fonte: **estilo/humor da marca**, disponibilidade da fonte no sistema, legibilidade.

### Legibilidade (2 alavancas principais)
- **Largura do parágrafo (medida de linha)**: **45 a no máximo 75 caracteres por linha.**
  Linhas longas demais cansam e o leitor se perde.
- **Altura de linha (entrelinha)**: entrelinha curta demais faz reler a mesma linha. Dê **espaço maior
  entre linhas**, sobretudo em textos longos.
  **[fora do livro — padrão de mercado]** line-height ~1.4–1.6x o tamanho da fonte para corpo de texto.

---

## 8. Usabilidade e affordances (visual a serviço da função)

- **Affordance**: pista visual de como algo funciona — "empurrãozinho" que mostra o que dá pra fazer.
  Principais pistas: **sombra e cor**. Escala do menos ao mais evidente (ex.: link "SAIBA MAIS"):
  texto puro → texto colorido → sublinhado → contornado (outline) → botão preenchido sólido.
  Quanto mais pistas (cor + sombra + contêiner), mais "clicável/usável" parece.
- **Estados de botão**: normal = **box shadow** (elevado); pressionado = **inner shadow** (afundado).
- **Signifiers**: elementos que dão significado explícito (labels, mensagens de erro, ícones em botões,
  toggle verde=ligado/branco=desligado). Ex.: toggle laranja preenchendo = alarme ativo.
- **Efetividade**: linguagem simples, sem jargão; menos complexidade = mais gente consegue usar.
- **Eficiência**: menos passos/etapas para o objetivo.
- **Tolerância a erros**: sempre ofereça desfazer (CTRL+Z / "cancelar envio" do Gmail, "desfazer" do Dropbox).
- **Facilidade de aprendizado**: siga **convenções** já conhecidas — o usuário reaproveita hábitos.

### Componentes (catálogo prático)
Botões de ação, checkboxes (várias marcações), rádios (só 1 por vez), menus (navegação), formulários,
seletores (lista de opções pré-definidas), dropdowns (cada opção = ação), cards (agrupar/organizar info).

3 características ao criar componentes: **Legibilidade, Ênfase, Usabilidade.**
- **Legibilidade**: tamanho/cor/fonte podem passar impressão de habilitado vs desabilitado; se perde
  legibilidade, perde função.
- **Ênfase**: manipular destaque para hierarquizar (principal destacado, secundário discreto).
- **Usabilidade**: ação clara (ícone/texto) + tamanho clicável. Nomeie o botão pela consequência real
  ("Confirmar compra"/"Realizar pagamento", não "Finalizar").

### Tamanhos concretos de componente
- **Botões (responsivo)**: altura **~50px**, largura mínima **~100px** (referência Apple/Google).
- **[fora do livro — padrão de mercado]** alvo de toque mínimo ~44x44px (Apple) / 48dp (Google).

---

## 9. Processo de criação de interface (do briefing ao handoff)

Não há passo-a-passo definitivo; média do fluxo do autor (12 passos + 1 opcional):

1. **Briefing e documentação** — reunir e documentar necessidades/requisitos.
2. **Definir objetivos** — o que a interface precisa resolver.
3. **Análise de concorrentes** — o que é bom/ruim, como se diferenciar.
4. **Coleta de referências / moodboard** — Pinterest, Dribbble, Behance (montado no Figma).
   Alimentar o cérebro; **não copiar**, analisar elementos e criar algo novo.
5. **Esboço inicial no papel** — rabiscos a lápis destravam criatividade.
6. **Arquitetura da informação e flow** — seções, páginas, fluxo do usuário.
7. **Wireframe** — definir tela + grid; **versão CRUA** em tons de cinza focando estrutura e hierarquia
   (timer de 10–20 min, soluções rápidas); depois refinar (~2h telas simples, dias para complexas).
   - **Opcional: teste de usabilidade** com ~3 pessoas para achar principais problemas.
8. **Tipografia** — só agora entra o visual: escolher fontes (títulos primeiro, depois corpo), testar
   tamanhos/pesos.
9. **Paleta de cores** — usar a existente da marca ou criar do zero (método HSB da seção 6).
10. **Detalhes finais** — adornos, sombras, luzes, efeitos; deixar "pixel perfect".
11. **Revisão** — deixar a interface "descansar" ≥1 dia, depois revisar erros/inconsistências.
12. **Protótipo interativo** — InVision/Zeplin para handoff (dev inspeciona cada elemento).

Insight-chave do processo: **estrutura em cinza primeiro (espaço/grid/hierarquia), estética por último
(tipo → cor → efeitos).** Isso evita bloqueio criativo de "pensar em tudo ao mesmo tempo".

---

## 10. Erros a evitar (resumo)

1. Começar pela parte bonita (cor/tipo/efeitos) antes da estrutura.
2. Só aprender software (Figma/Sketch/XD) — ferramenta não substitui princípios.
3. Não coletar/analisar referências antes de criar (≥15 min) → bloqueio criativo.
4. Confundir UX (pesquisa, usabilidade, estratégia) com UI (design visual: tipografia, cores, layout,
   design system).

---

## Cheat-sheet de valores concretos

| Item | Valor |
|---|---|
| Escala tipográfica | 12,14,16,18,20,24,30,36,48,60,72 px |
| Fontes por interface | máx 2 |
| Medida de linha | 45–75 caracteres |
| Margem 3 linhas-guia | 30px lados |
| Grid desktop | frame 1260×2500, 12 col, width 70, gutter 30, centro |
| Tela desktop base | 1600×900 (1366×768 mais comum) |
| Tela mobile base | 375×667 (iPhone 8) |
| Botão | altura ~50px, largura mín ~100px |
| Variações da cor primária | 5–10 |
| Tons de cinza | 6–10 (nunca preto 100%) |
| Cor escura | +saturação / −brilho |
| Cor clara | −saturação / +brilho |
| Hue refs | 0° vermelho, 120° verde, 240° azul |
| Semântica | vermelho=perigo, amarelo=alerta, verde=sucesso |
| Estados botão | normal=box shadow, pressionado=inner shadow |
