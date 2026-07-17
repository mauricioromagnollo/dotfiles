# Estrutura de projeto, módulos e pacotes em Go — referência

> Destile o que importa (regras, armadilhas, snippets), não a documentação
> inteira.

Fontes: https://go.dev/doc/modules · https://go.dev/wiki/CodeReviewComments · https://go.dev/doc/modules/layout
Ressalva: https://github.com/golang-standards/project-layout **não é oficial** nem endossado pelo time do Go; use como catálogo, não como lei.
Livros: "Let's Go" e "Let's Go Further" (Alex Edwards) · "Learning Go" 2ª ed (Jon Bodner).

## Regra de ouro
O pacote é a **unidade de design**, não uma camada técnica. Nomeie pacotes pela
**função/domínio** (`store`, `mailer`, `data`, `validator`), nunca por camada
genérica (`utils`, `helpers`, `common`, `base`, `misc`).

## Módulos
- `go mod init <module-path>` — o path é a **URL do repo** (`github.com/user/proj`), pois define como outros importam.
- `go.mod` declara path, versão do Go e dependências diretas; `go.sum` fixa hashes de verificação (commite os dois).
- `go mod tidy` sincroniza `go.mod`/`go.sum` com os imports reais (adiciona faltantes, remove órfãos). Rode antes de commitar.
- Versionamento semântico: `v1.2.3`. A partir de `v2`, o major entra no path: `github.com/user/proj/v2`.
- `replace github.com/x/y => ../y` redireciona para fork/local (dev, patch temporário). Evite deixar `replace` local em release.

## Layout de pacotes
- `internal/` — só importável pelo próprio módulo (compilador força). Coloque aqui a lógica de aplicação.
- `cmd/<binário>/main.go` — um diretório por executável quando há múltiplos binários; `main` fino, só monta e chama `internal`.
- `pkg/` — convenção para código reexportável; **debatida**, muitos evitam (aninhamento sem ganho). Não use por hábito.
- Projeto simples de 1 binário não precisa de `cmd/` nem `internal/` — comece plano e extraia depois.

## Layout típico de API (Let's Go Further)
```
cmd/api/          main.go, handlers, routes, middleware (o binário)
internal/data/    modelos e acesso a dados (store/repository)
internal/validator/  validação reutilizável
internal/mailer/  envio de e-mail
go.mod  go.sum  Makefile
```

## Injeção de dependência (sem framework)
```go
type application struct {
    logger *slog.Logger
    users  data.UserModel
    mailer mailer.Mailer
}
func (app *application) handleX(w http.ResponseWriter, r *http.Request) { /* ... */ }
```
Struct `application`/`app` com as deps; métodos como handlers. Sem container de DI, sem mágica.

## Config e contexto
- Config via **flags/env**, não hardcode: `flag.StringVar`, `os.Getenv`. Falhe cedo se faltar valor obrigatório.
- Use `context.Context` para escopo de request (cancelamento, deadline, valores de request); passe como 1º parâmetro, nunca guarde em struct.

## Nomes e dependências
- Sem **stutter**: pacote `http` → `http.Server`, não `http.HTTPServer`. Pacote `user` → `user.Store`, não `user.UserStore`.
- Evite **dependência circular** — Go proíbe. Sinal de camadas mal desenhadas; extraia tipos compartilhados para um pacote menor.

## Armadilhas
- Pacote `models`/`types` gigante virando lixeira de tudo → quebre por domínio.
- Tentar importar `internal/` de fora do módulo → não compila (é o objetivo).
- Nomes genéricos (`utils`, `helpers`, `common`) escondem falta de design.
- Over-engineering de camadas; DDD/clean architecture/hexagonal **prematuros** em app pequeno. Comece simples.
- `pkg/` só por convenção, sem necessidade real.

## Comandos úteis
- `go build ./...` — compila tudo, detecta imports quebrados.
- `go vet ./...` — checagens estáticas além do compilador.
- `go test ./...` · `go mod tidy` · `go mod verify`.
