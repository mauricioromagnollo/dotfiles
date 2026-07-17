# Testes em Go — referência

> Arquivo de referência DESTILADO: regras, armadilhas e snippets curtos, não a
> documentação inteira.

Fontes: https://pkg.go.dev/testing · https://go.dev/blog/subtests · https://go.dev/doc/fuzz · https://go.dev/blog/examples
Livros: "Learn Go with Tests" (Chris James) · "The Go Programming Language" (Donovan & Kernighan, cap. 11) · "Learning Go" 2ª ed (Jon Bodner).

## Convenções
- Arquivos terminam em `_test.go`, no mesmo pacote (acesso a internos) ou em `pkg_test` (testa só a API pública — preferível para o contrato).
- Testes: `func TestXxx(t *testing.T)`. Rode tudo com `go test ./...`; verboso com `-v`; um teste com `-run TestNome/subteste`.
- Sem framework de assert: a stdlib basta. Mantenha mensagens no formato `got %v, want %v`.

## Table-driven tests com subtests
```go
func TestAbs(t *testing.T) {
    tests := map[string]struct{ in, want int }{
        "positivo": {2, 2},
        "negativo": {-3, 3},
    }
    for name, tt := range tests {
        tt := tt // pré-Go 1.22: evita captura compartilhada no loop
        t.Run(name, func(t *testing.T) {
            t.Parallel()
            if got := Abs(tt.in); got != tt.want {
                t.Errorf("Abs(%d) = %d, want %d", tt.in, got, tt.want)
            }
        })
    }
}
```
- `t.Run` isola cada caso, dá nome próprio no output e permite `-run` seletivo.
- Go 1.22+ não precisa mais do `tt := tt`; abaixo disso é obrigatório.
- `t.Parallel()` roda subtests em paralelo — só use com casos independentes.

## Helpers e ciclo de vida
- `t.Helper()`: marca a função como auxiliar; falhas apontam para a linha que chamou, não para dentro do helper.
- `t.Cleanup(fn)`: registra teardown que roda ao fim do teste (melhor que `defer` espalhado); executa em LIFO.
- `t.Fatal`/`t.Fatalf`: para o teste imediatamente (use quando continuar não faz sentido — ex.: setup falhou). `t.Error`/`t.Errorf`: registra e segue (bom para verificar vários campos de uma vez).
- `t.Fatal` chama `runtime.Goexit` — nunca o chame de outra goroutine; só da goroutine do teste.

## Testar erros
```go
_, err := Parse("x")
if !errors.Is(err, ErrInvalid) {          // sentinela na cadeia (%w)
    t.Fatalf("erro = %v, want ErrInvalid", err)
}
var perr *ParseError
if !errors.As(err, &perr) {                // extrai tipo concreto
    t.Fatalf("esperava *ParseError, got %T", err)
}
```
- Nunca compare `err.Error()` por string: é frágil e não vê erros embrulhados.

## Benchmarks
```go
func BenchmarkFib(b *testing.B) {
    b.ReportAllocs()
    for i := 0; i < b.N; i++ {
        result = Fib(20) // atribui a var de pacote: evita dead-code elimination
    }
}
```
- Rode com `go test -bench=. -benchmem`. Use `b.ResetTimer()` após setup caro.
- Guarde o resultado numa variável exportada/pacote para o compilador não otimizar a chamada.

## Examples executáveis (viram doc + teste)
```go
func ExampleAbs() {
    fmt.Println(Abs(-2))
    // Output: 2
}
```
- O comentário `// Output:` é verificado por `go test`. Sem ele, o example compila mas não roda. Use `// Unordered output:` para saída sem ordem garantida.

## Fuzzing
```go
func FuzzReverse(f *testing.F) {
    f.Add("hello")                 // seeds do corpus
    f.Fuzz(func(t *testing.T, s string) {
        if Reverse(Reverse(s)) != s {
            t.Errorf("round-trip falhou para %q", s)
        }
    })
}
```
- Rode com `go test -fuzz=FuzzReverse`. Falhas viram seeds em `testdata/fuzz/`.

## Mocks/fakes e HTTP
- Defina interfaces pequenas **no consumidor**, não no produtor; injete um fake que implemente só o que o código usa. Prefira fakes simples a frameworks de mock.
- HTTP: use `net/http/httptest` — `httptest.NewServer` (cliente) e `httptest.NewRecorder` + `http.HandlerFunc` (handler).

## Coverage
- `go test -cover` mostra o percentual. `go test -coverprofile=c.out && go tool cover -html=c.out` abre o relatório visual. Cobertura alta não prova ausência de bugs.

## Armadilhas
- Testes que dependem de ordem de execução ou de estado global compartilhado — cada teste deve ser independente e repetível.
- `t.Parallel()` com mapa/variável compartilhada sem sincronização: race. Rode sempre `go test -race`.
- Asserções frágeis: comparar structs inteiras com campos voláteis (timestamps, IDs aleatórios). Use `google/go-cmp` com `cmpopts.IgnoreFields`/`Equal`, não `reflect.DeepEqual` cru para tipos complexos.
- Esquecer `// Output:` no example, ou `t.Helper()` no helper (erros apontam para o lugar errado).
