# Concorrência em Go — referência

> Arquivo de referência DESTILADO: regras, armadilhas e snippets curtos, não a
> documentação inteira.

Fontes: https://go.dev/doc/effective_go#concurrency · https://go.dev/blog/pipelines
Livro de referência: "Concurrency in Go" (Katherine Cox-Buday).

## Regra de ouro
Nunca inicie uma goroutine sem saber como e quando ela termina. Vazamento de
goroutine (goroutine leak) é o bug mais comum de Go em produção.

## context é o mecanismo de cancelamento
- `context.Context` é sempre o primeiro parâmetro: `func Do(ctx context.Context, ...)`.
- Nunca guarde `Context` dentro de struct; passe por parâmetro.
- Respeite `ctx.Done()` em qualquer operação bloqueante ou loop longo.
- Use `context.WithTimeout`/`WithCancel` e sempre chame o `cancel` (com `defer`).

## Channels vs Mutex
- Channel: para orquestrar fluxo, transferir posse de dados, sinalizar eventos.
- `sync.Mutex`: para proteger estado compartilhado simples. Não force um channel
  onde um mutex é mais claro.
- Feche o channel apenas no lado que envia, e apenas uma vez. Ler de channel fechado
  devolve o zero value com `ok == false`.

## Padrões úteis
- **errgroup** (`golang.org/x/sync/errgroup`) para paralelizar tarefas e coletar o
  primeiro erro, com cancelamento automático via context.
- **Worker pool**: N goroutines consumindo de um channel de jobs; feche o channel de
  jobs para encerrar os workers.
- **Pipeline**: estágios ligados por channels, cada estágio respeitando `ctx.Done()`.
- Use `sync.WaitGroup` para esperar um conjunto de goroutines: `wg.Add` antes de
  iniciar, `defer wg.Done()` dentro, `wg.Wait()` no fim.

## Armadilhas clássicas
- **Variável de loop capturada em goroutine** (relevante em Go < 1.22): passe como
  argumento — `go func(v T){ ... }(v)`.
- **WaitGroup**: `Add` deve vir antes de lançar a goroutine, nunca dentro dela.
- Enviar em channel sem receptor / sem buffer bloqueia para sempre (deadlock).
- Esquecer de chamar `cancel()` de um context com timeout vaza recursos.

## Sempre valide com o race detector
`go test -race ./...` e `go run -race`. Se há estado compartilhado entre goroutines
e o `-race` está limpo, você tem uma boa evidência de correção.
