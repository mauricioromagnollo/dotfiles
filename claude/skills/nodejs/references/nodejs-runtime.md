# Node.js runtime (v24 LTS)

Comportamento do runtime que muda decisões numa API backend. Abra este arquivo ao decidir *onde* rodar algo (loop, worker, processo), ao investigar latência ou vazamento, ao mexer em resolução de módulos, ou antes de adicionar uma lib que o core já resolve. Contexto assumido: Node 24.16.0, TypeScript 5.8 com `module: node16`, execução via `tsx`, Fastify + Prisma + Vitest + pino.

## Event loop: o modelo mental que importa

O loop tem fases em ordem fixa: **timers** (`setTimeout`/`setInterval`) → **pending callbacks** → **poll** (I/O; onde o processo dorme esperando o kernel) → **check** (`setImmediate`) → **close callbacks**. Entre *cada* callback, Node drena duas filas de microtasks: primeiro `process.nextTick`, depois promises (`queueMicrotask`, `.then`).

As consequências práticas:

- `process.nextTick` roda **antes** de qualquer promise e antes de voltar ao loop. Recursão em `nextTick` trava o processo sem nunca ceder ao I/O — a fila é drenada até esvaziar. Em aplicação, prefira `queueMicrotask`; `nextTick` é ferramenta de autor de biblioteca.
- `setImmediate` roda na fase *check*, **depois** do I/O do ciclo atual. Para "processar isto depois de entregar a resposta" é a escolha certa — `setTimeout(fn, 0)` compete com a fase de timers e tem ordem não determinística fora de um callback de I/O (dentro de um, `setImmediate` vem sempre antes).

**O que bloqueia:** qualquer CPU síncrona — `JSON.parse`/`stringify` de payloads grandes, `bcrypt`/`pbkdf2Sync`, `zlib` síncrono, regex com backtracking, `fs.*Sync` fora do bootstrap. Bloquear o loop degrada **todas** as requisições em voo, não só a atual: é o modo de falha mais caro do Node. Para detectar (`node:perf_hooks`, estável):

```ts
import { monitorEventLoopDelay, performance } from 'node:perf_hooks';

const h = monitorEventLoopDelay({ resolution: 20 });
h.enable();

setInterval(() => {
  logger.info({ p99: h.percentile(99) / 1e6, elu: performance.eventLoopUtilization().utilization });
  h.reset();
}, 10_000).unref();
```


ELU perto de 1 indica CPU-bound (mova para worker); delay p99 alto com ELU baixo indica GC ou starvation por microtasks.

## Módulos em Node 24

`require()` de ESM é **estável em v24.15.0** (sem flag desde v22.12/v23.0), mas o módulo precisa ser **totalmente síncrono**: se ele ou qualquer dependência do grafo tiver top-level `await`, lança `ERR_REQUIRE_ASYNC_MODULE` — use `import()` dinâmico. O retorno é o *namespace object*, com default em `.default` e marcador `__esModule: true`. Isso importa quando uma dependência passa a publicar ESM: `const x = require('lib')` passa a receber `{ default: x }`.

Com `module: node16`, o formato de cada arquivo vem do `"type"` do `package.json` mais próximo, e **a extensão no specifier é obrigatória em ESM** — escreva `./foo.js` mesmo importando de `foo.ts`. `.mts` força ESM e `.cts` força CJS, independentemente do `"type"`. `tsx` tolera specifier sem extensão; `node` puro não — se o build for para `node dist/`, o `tsc` com `node16` diz a verdade.

Use **subpath imports** em vez de `../../../` — `{ "imports": { "#app/*": "./src/*.js" } }` no `package.json`. Funcionam em runtime sem `tsconfig.paths`, que o Node ignora (`paths` é só type-checking).

Prefixo `node:` **não é obrigatório**, mas use sempre: elimina ambiguidade com pacotes npm homônimos, é imune a shadowing e sinaliza builtin ao leitor e ao bundler.

Em ESM não existem `__dirname`/`__filename`: use `import.meta.dirname` e `import.meta.filename` (v21.2.0, **estáveis em v24.0.0**). `import.meta.main` (v24.2.0) substitui `require.main === module`, mas ainda está em desenvolvimento inicial (1.0).

## Async: contexto, cancelamento, agregação

**`AsyncLocalStorage`** (`node:async_hooks`) é **estável** e é a peça certa para request-scoped context — request id, tenant, usuário, trace. O store atravessa `await`, callbacks e timers sem passar parâmetro pela cadeia toda.

```ts
import { AsyncLocalStorage } from 'node:async_hooks';

export const ctx = new AsyncLocalStorage<{ requestId: string }>();

app.addHook('onRequest', (req, _reply, done) => {
  ctx.run({ requestId: req.id }, done);
});
```

Qualquer camada (repositório Prisma, logger) lê `ctx.getStore()?.requestId` sem acoplamento ao Fastify. Atenção: `run()` é estável, mas `enterWith()`, `exit()` e `disable()` seguem **experimentais (1)** em v24 — `enterWith` vaza contexto para o resto do tick e é fonte clássica de contexto cruzado entre requisições. Fique em `run()`. `bind(fn)` e `snapshot()` são estáveis desde v23.11 e retêm contexto ao entregar callbacks a pools/filas.

**`AbortSignal`** é o protocolo padrão de cancelamento, aceito por `fetch`, `setTimeout`, streams e `fs/promises`. Propague o sinal da requisição downstream em vez de deixar queries órfãs após o cliente desconectar — `AbortSignal.any([req.signal, AbortSignal.timeout(5_000)])` compõe cancelamento do cliente com deadline (que rejeita como `TimeoutError`). `signal.throwIfAborted()` no topo de laços longos evita trabalho descartado.

`Promise.withResolvers()` (v24) elimina o antipadrão de capturar `resolve`/`reject` de dentro do construtor. `AggregateError` chega de `Promise.any()` e de erros de DNS/conexão com múltiplos endereços — logue `err.errors`, não só `err.message`, senão a causa real some.

Use `Promise.allSettled` quando falhas parciais são aceitáveis: `Promise.all` não cancela nada — as demais promises seguem rodando e podem rejeitar depois, gerando `unhandledRejection`.

## Streams e backpressure

`highWaterMark` é **limiar, não limite**: `writable.write()` retorna `false` quando o buffer passou dele, mas ignorar o retorno não gera erro — o Node segue bufferizando em memória. É assim que exportações "funcionam em dev" e estouram heap em produção com cliente lento.

Nunca use `pipe()` em produção: ele **não propaga erro nem destrói a cadeia**, deixando o source aberto e listeners vazando quando o destino falha. Use `pipeline` de `node:stream/promises`:

```ts
import { pipeline } from 'node:stream/promises';

await pipeline(
  rowsAsyncIterable,
  async function* (src) { for await (const row of src) yield JSON.stringify(row) + '\n'; },
  reply.raw,
  { signal },
);
```

Async generators dentro de `pipeline` dão backpressure de graça — o `yield` só avança quando o destino consome; `for await` idem. `Readable.from(iterable)` transforma qualquer async iterable (um cursor paginado do Prisma) em stream.

Interop com Web Streams via `Readable.toWeb`/`fromWeb` é estável e conecta o corpo de um `fetch` a streams Node. **`stream.compose()` segue experimental (1)** em v24 — evite em produção.

Se o payload não tem tamanho conhecido e limitado, não faça `JSON.parse` do buffer inteiro: 50 MB bloqueiam o loop por segundos e o pico de heap é múltiplo do tamanho do texto.

## Erros

Encadeie causa em vez de concatenar mensagens: `Error.cause` preserva a stack original e o pino serializa.

```ts
class RepositoryError extends Error {
  name = 'RepositoryError';
}

try { await prisma.tx.create({ data }); }
catch (cause) { throw new RepositoryError('failed to persist transaction', { cause }); }
```

**`uncaughtException` e `unhandledRejection` não são recuperáveis.** Depois deles o processo tem estado indefinido: transações pela metade, locks presos, invariantes quebradas. O handler serve para **logar e sair**, não para continuar:

```ts
process.on('uncaughtException', (err) => {
  logger.fatal({ err }, 'uncaught');
  process.exit(1);
});
```

Em v24, promise rejeitada sem handler **derruba o processo** por padrão (`--unhandled-rejections=throw` é default desde v15) — não conte com o antigo warning. `--trace-uncaught` mostra a stack de onde o valor foi lançado (essencial quando dão `throw` em algo que não é `Error`); `--trace-warnings` faz o mesmo para warnings.

## Worker threads vs child_process vs cluster

- **`node:worker_threads`** (estável): CPU-bound no mesmo processo, memória compartilhável via `SharedArrayBuffer`, comunicação por structured clone. É a resposta para hashing, compressão e parsing pesado. `postMessageToThread` segue experimental (1).
- **`child_process`**: rodar *outro programa* (binário, script). Isolamento de crash ao custo de um processo inteiro. Não use para paralelizar JS — worker é mais barato.
- **`cluster`**: várias instâncias do mesmo servidor compartilhando porta. Em container geralmente é **redundante** — o orquestrador já escala réplicas, e 1 processo por container dá métricas, limite de memória e restart previsíveis. Use só sem orquestrador.

## APIs de v24 que dispensam dependência

| Necessidade | Nativo em v24 | Status |
|---|---|---|
| `.env` | `--env-file=.env`, `--env-file-if-exists` | **Estável em v24.10** (dispensa `dotenv`) |
| HTTP client | `fetch` global | Estável |
| Restart em dev | `node --watch` | Estável (dispensa `nodemon`) |
| Test runner | `node:test` + `mock.timers` | Estável desde v20 |
| CLI args | `util.parseArgs` | Estável |
| Deep clone | `structuredClone` | Estável |
| UUID | `crypto.randomUUID()` | Estável |
| Rodar script do package.json | `node --run` | Estável |
| Sandbox de permissões | `--permission`, `--allow-fs-read/write` | **Estável** desde v23.5 (`--allow-worker`/`--allow-wasi` seguem 1.1) |
| SQLite embutido | `node:sqlite` | **Experimental (1)** — não use em produção |

Type stripping é default desde v22.6 e `--no-strip-types` ficou estável em v24.12; `--experimental-transform-types` (enums, decorators, namespaces) ainda é **release candidate (1.2)**. É a rota de saída do `tsx` quando o código ficar restrito a sintaxe apagável.

## Observabilidade e shutdown

`node:diagnostics_channel` é **estável** e é como Fastify/undici expõem eventos internos sem custo quando ninguém escuta (`channel.hasSubscribers`). `tracingChannel` segue **experimental (1)**. Para perfil sob demanda sem instrumentar código: `node --cpu-prof --cpu-prof-dir=/tmp app.js` (estável desde v22.4) gera `.cpuprofile` para o DevTools; `--heap-prof` para alocação.

**Graceful shutdown** — o erro comum é `process.exit()` no handler, que **descarta I/O pendente**: `process.stdout` é assíncrono quando aponta para pipe (o caso em Docker), então logs do pino somem e conexões ficam penduradas. O correto é parar de aceitar, drenar, e deixar o processo morrer sozinho:

```ts
let shuttingDown = false;

for (const signal of ['SIGTERM', 'SIGINT'] as const) {
  process.on(signal, async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    const timer = setTimeout(() => process.exit(1), 10_000).unref();
    try {
      await app.close();          // para de aceitar, drena requests em voo
      await prisma.$disconnect();
      clearTimeout(timer);
    } catch (err) {
      logger.error({ err }, 'shutdown failed');
      process.exit(1);
    }
  });
}
```

O guard evita dupla execução (Kubernetes reenvia SIGTERM); o timer com `unref()` impede um socket travado de segurar o pod. Faça o health check falhar **antes** de `app.close()`, senão o load balancer continua roteando durante o drain.

## Armadilhas com consequência real

- **`__dirname` em ESM**: não existe; use `import.meta.dirname`. Caminho relativo a `process.cwd()` quebra quando o serviço roda de outro diretório.
- **Listener leak**: `MaxListenersExceededWarning` quase nunca é ruído — é `.on()` dentro de um handler por requisição. Use `{ once: true }`, `{ signal }` ou `events.once()`. `--trace-warnings` mostra o call site.
- **`process.exit` engolindo I/O**: prefira `process.exitCode = 1` e deixe o loop esvaziar.
- **`fetch` sem timeout**: não há timeout padrão. Uma dependência lenta vira exaustão de conexões. Sempre `AbortSignal.timeout()`.
- **Erro assíncrono fora do try**: `try { stream.on('data', () => { throw x }) }` não captura nada — o throw acontece noutro tick. Erro de EventEmitter só chega via evento `'error'`.
- **`--max-old-space-size` em container**: o V8 dimensiona o heap pela memória da *máquina*, não pelo cgroup; sem ajuste, o kernel OOM-killa antes do GC agir. Em v24 existe `--max-old-space-size-percentage`.
