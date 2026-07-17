# Erros sutis, alocação e performance em Go — referência

> Destilado: cada armadilha traz o erro e a correção. Não é a documentação inteira.

Fontes: https://go.dev/doc/effective_go · https://go.dev/wiki/CodeReviewComments
Livros de referência: "100 Go Mistakes and How to Avoid Them" (Teiva Harsanyi) · "The Go Programming Language" (Donovan & Kernighan).

## Regra de ouro
Meça antes de otimizar (`go test -bench`, `pprof`). A maioria dos bugs de performance nasce de alocação escondida e de estruturas compartilhando memória sem você perceber.

## Slices e append
- Slices compartilham o **backing array**. `append` pode mutar o slice de origem se houver `cap` sobrando: `b := a[:2]; b = append(b, x)` sobrescreve `a[2]`.
- Proteja com **full slice expression** `s[low:high:max]` para limitar `cap` e forçar cópia no próximo append: `b := a[0:2:2]`.
- `len` = elementos usados; `cap` = tamanho do backing array. São coisas diferentes.
- Pré-aloque quando souber o tamanho: `make([]T, 0, n)` e depois `append`. Evita realocações e cópias em loop.
- Um slice pequeno tirado de um array grande **segura o array inteiro na memória**. Copie o que precisa: `out := make([]byte, n); copy(out, big[:n])`.

## Maps
- Valor zero de map é `nil`: ler funciona (retorna zero), **escrever panica**. Inicialize com `make(map[K]V)` ou literal.
- Acesso concorrente (leitura+escrita) **panica** ("concurrent map ...") — não é o race detector. Use `sync.Mutex` ou `sync.Map`.
- Iteração tem **ordem aleatória** por design. Nunca dependa da ordem; ordene as chaves se precisar.
- Não dá para pegar endereço de valor de map (`&m[k]` não compila). Para struct, releia, modifique e reatribua, ou guarde ponteiros: `map[K]*V`.

## Variável de loop (Go < 1.22)
- Em Go < 1.22 a variável do loop é **reutilizada**; capturada em closure/goroutine todas veem o último valor. Corrija com cópia local: `v := v`. Em Go >= 1.22 cada iteração tem sua própria variável.

## nil interface != nil
- Uma interface guarda (tipo, valor). Com tipo concreto não-nil e valor nil, a interface **não é `== nil`**.
- Clássico: retornar `*MyError` nil como `error` faz `err != nil` ser verdadeiro. Retorne `nil` explícito: `if bad { return err }; return nil`.

## defer
- Argumentos do `defer` são **avaliados na hora do `defer`**, não na execução: `defer fmt.Println(i)` captura o `i` atual.
- `defer` em loop **acumula** até o fim da função. Extraia o corpo para uma função ou feche manualmente dentro do loop.
- Não engula o erro de `Close` em writers: `defer func() { err = f.Close() }()` para não perder erro de flush.

## Erros
- Compare com `errors.Is(err, ErrX)` (sentinelas) e `errors.As(err, &target)` (tipos), não com `==`, pois erros vêm embrulhados.
- Embrulhe com `%w` para preservar a cadeia: `fmt.Errorf("read config: %w", err)`. Use `%v` quando NÃO quiser expor o erro interno.
- Cuidado com **shadowing**: `if x, err := f(); err != nil` cria um `err` novo no escopo do `if`; o `err` externo não muda.

## Ponteiro vs valor
- Escolha receiver por ponteiro se precisa mutar ou se a struct é grande. Seja **consistente** no tipo: não misture value e pointer receivers.
- Nunca copie um valor que contém `sync.Mutex`/`sync.WaitGroup` (copia o estado do lock). Por isso `go vet` reclama de "copies lock value". Use ponteiro.

## Strings
- `range` sobre string itera **runes** (pontos de código UTF-8), com índice em bytes; `len(s)` conta **bytes**, não caracteres.
- Indexar `s[i]` dá um **byte**, não um caractere. Para contar caracteres use `utf8.RuneCountInString`.
- Concatenar com `+=` em loop realoca a cada passo. Use `strings.Builder` (ou `bytes.Buffer`), idealmente com `b.Grow(n)`.

## Números
- `int`/`int64` fazem **overflow silencioso** (wrap-around), sem panic. Valide limites em somas/multiplicações que possam estourar.
- **Nunca** use `float64` para dinheiro — erro de arredondamento binário. Use inteiro em centavos ou um tipo decimal.
- Conversões estreitam sem aviso: `int32(bigInt)` e `float64` -> `int` **truncam/perdem precisão**. Converta com cuidado e cheque faixa.

## Goroutine leak
- Goroutine bloqueada em channel sem consumidor vaza para sempre. Use `context` para cancelar e garanta que todo `send`/`receive` tenha saída. Detalhes em `concurrency.md`.

## Performance e alocação
- Pré-aloque slices/maps com capacidade conhecida; corta realocação e GC.
- Colocar valor em `interface{}`/`any` pode causar **boxing** (alocação no heap). Evite em caminhos quentes.
- `sync.Pool` só compensa para objetos grandes e reusáveis sob alta frequência; mal usado piora e complica.
- **Escape analysis** decide stack vs heap. Veja com `go build -gcflags='-m'`: o que "escapes to heap" aloca; ponteiros retornados/capturados escapam.
- Meça sempre: `go test -bench=. -benchmem`, `pprof` (CPU/heap) e `-race` em testes. Sem profile, otimização é chute.
