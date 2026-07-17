---
name: golang
description: >
  Escrita, revisão e refatoração de código Go idiomático: design de pacotes e APIs,
  tratamento de erros, concorrência (goroutines, channels, context, sync), testes,
  módulos e performance. USE ESTA SKILL sempre que aparecer Go, Golang, arquivo .go,
  go.mod/go.sum, package, goroutine, channel, context, interface, struct, slice,
  map, generics, `go test`, `go build`, `go run`, race condition, gofmt, go vet,
  golangci-lint, ou qualquer pedido para escrever/revisar/otimizar/testar código em
  Go — MESMO que o usuário não diga "idiomático" ou "best practices". Na dúvida entre
  esta skill e uma resposta genérica de programação, prefira esta skill.
---

# Go (Golang)

Esta skill faz o Claude escrever Go como a comunidade escreve: simples, legível e
idiomático. A filosofia do Go é "clear is better than clever" — prefira a solução
óbvia à esperta. O objetivo não é só compilar; é produzir código que outra pessoa
leia em seis meses sem esforço.

## Filosofia (aplicar sempre)

- **Simplicidade acima de tudo.** Menos abstração, menos "mágica". Se há uma forma
  óbvia, é ela. Evite frameworks e generics quando o problema não pede.
- **Erros são valores.** Trate erro explicitamente, na hora. Nunca use `panic` para
  fluxo de erro normal — `panic` é para bugs irrecuperáveis (invariantes violadas).
- **Composição, não herança.** Interfaces pequenas; embedding quando fizer sentido.
- **"Accept interfaces, return structs".** Funções recebem interfaces (flexível) e
  devolvem tipos concretos (previsível). Defina a interface no consumidor, não no
  produtor.
- **Zero value útil.** Projete tipos cujo valor zero já seja usável (ex.: `sync.Mutex`,
  `bytes.Buffer`) antes de exigir construtores.
- **A concorrência não é paralelismo.** Só adicione goroutines quando resolvem um
  problema real. "Don't communicate by sharing memory; share memory by communicating."

## Gates de ferramenta (não negociáveis)

Todo código Go entregue deve passar por, e assumir, este pipeline:

- **`gofmt` / `goimports`** — formatação é automática e não se discute. Todo código
  sai formatado.
- **`go vet`** — pega erros comuns (ex.: `Printf` com verbo errado, locks copiados).
- **`golangci-lint`** — linter agregado; assuma que ele roda no CI.
- **`go test -race ./...`** — SEMPRE proponha o race detector em código concorrente.

## Idiomas essenciais (aplicar inline)

**Tratamento de erro**
- Envolva com contexto usando `%w`: `fmt.Errorf("reading config: %w", err)`.
- Verifique com `errors.Is` (sentinelas) e `errors.As` (tipos), nunca comparando strings.
- Strings de erro em minúscula, sem pontuação final: `"connection refused"`, não
  `"Connection refused."` — elas aparecem no meio de outras mensagens.
- Não descarte erro com `_` sem um comentário justificando.

**Nomes e API**
- Nomes curtos no escopo curto (`i`, `r`, `buf`); descritivos no escopo amplo.
- Sem stutter: em `package user`, o tipo é `user.Service`, não `user.UserService`.
- Todo símbolo exportado tem doc comment começando pelo nome: `// Client faz ...`.

**Estruturas de dados**
- Prefira slices a arrays; cuidado com o compartilhamento de backing array em `append`.
- `context.Context` é o primeiro parâmetro (`ctx context.Context`), nunca em struct.
- `defer` para liberar recursos (`f.Close()`), ciente do custo em loops quentes.

## Guardrails de concorrência

- Nunca inicie uma goroutine sem saber **como e quando ela termina**. Vazamento de
  goroutine é o bug clássico de Go.
- Propague cancelamento com `context`; respeite `ctx.Done()`.
- Channels para orquestração/fluxo; `sync.Mutex` para proteger estado compartilhado.
  Não use channel onde um mutex é mais simples.
- Feche um channel apenas do lado que envia, e apenas uma vez.
- Rode com `-race` antes de confiar em qualquer código concorrente.

## Roteamento das referências

Leia APENAS o arquivo relevante em `references/` conforme o pedido:

| Se o pedido envolve...                                   | Leia |
|----------------------------------------------------------|------|
| Goroutines, channels, context, sync, race conditions     | `references/concurrency.md` |
| `go test`, table-driven, benchmarks, mocks, fuzzing      | `references/testing.md` |
| Estrutura de projeto, módulos, layout de pacotes         | `references/project-structure.md` |
| Erros sutis, alocação, performance, pitfalls comuns      | `references/common-mistakes.md` |

## Formato de saída

- Entregue **código completo e compilável**, formatado com `gofmt`, com imports.
- Trate todos os erros explicitamente — nada de `_ = err` silencioso.
- Doc comments em todo símbolo exportado.
- Para código não trivial, inclua um teste (table-driven) ou um exemplo executável.
- Explique brevemente as decisões não óbvias (concorrência, escolha de tipo, trade-off
  de performance) — antes ou depois do bloco, não misturado no código.

## Documentações oficiais (fonte de verdade)

- Docs gerais — https://go.dev/doc/
- Effective Go — https://go.dev/doc/effective_go
- Go Code Review Comments — https://go.dev/wiki/CodeReviewComments
- Google Go Style Guide — https://google.github.io/styleguide/go/
- Biblioteca padrão / pacotes — https://pkg.go.dev/std
- Especificação da linguagem — https://go.dev/ref/spec
- Tour of Go — https://go.dev/tour/
- Go Blog — https://go.dev/blog/
