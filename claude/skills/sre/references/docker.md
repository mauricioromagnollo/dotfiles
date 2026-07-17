# Docker e imagens de container

Uma imagem é um artefato imutável de build; um container é uma instância efêmera
dela. Quase todo problema de Docker em produção (imagem gigante, secret vazado,
cache que nunca acerta, container que não morre no deploy) nasce de tratar o
Dockerfile como script de instalação em vez de definição de artefato reproduzível.
Esta referência é para **revisar** Dockerfiles e decisões de imagem — não é
tutorial. A fonte de verdade é https://docs.docker.com/ e o raciocínio vem do
*Docker Deep Dive* (Nigel Poulton). Ao decidir, ancore no trade-off, não no hábito.

## Modelo mental: imagem, container, camadas, registry

Uma **imagem** é uma pilha de camadas read-only unidas por um union filesystem
(overlay2). Um **container** é essa pilha mais uma fina camada writable no topo —
tudo que o processo escreve vai para lá e some quando o container é removido (por
isso estado vai em volume, não no container). Cada instrução `RUN`, `COPY`, `ADD`
do Dockerfile cria **uma camada nova**; `ENV`, `WORKDIR`, `CMD` etc. só alteram
metadados. Camadas são cacheadas e compartilhadas entre imagens — é isso que faz
build incremental e pull rápido funcionarem.

No **registry**, uma imagem é endereçada por `nome:tag` (mutável, ex.: `app:1.4`)
ou por `nome@sha256:...` (**digest**, imutável — sempre os mesmos bytes). Tag é um
ponteiro que pode ser reescrito; digest é o conteúdo. Em produção e em base
images, prefira digest quando reprodutibilidade importa.

> Regra de revisão: se uma instrução muda com frequência, ela tem que ficar o mais
> **embaixo** possível no Dockerfile, para não invalidar o cache das camadas caras
> acima dela.

## Dockerfile bem feito: ordem, cache e instruções

A tese central: **ordene do menos volátil para o mais volátil**. Dependências
mudam raramente e são caras de instalar; código-fonte muda a cada commit. Copiar o
código antes de instalar deps quebra o cache de layers a cada build.

```dockerfile
# CERTO: manifesto de deps primeiro, instala, só então copia o resto
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

Se você fizesse `COPY . .` antes do `npm ci`, qualquer alteração em qualquer
arquivo invalidaria a camada do `npm ci` e reinstalaria tudo. Vale para todo
ecossistema (`go.mod`/`go.sum`, `pom.xml`, `requirements.txt`, `Gemfile.lock`).

Decisões de instrução que aparecem em revisão:

| Tema | Regra | Porquê |
|------|-------|--------|
| `COPY` vs `ADD` | Prefira `COPY` | `ADD` faz auto-extração de tar e download de URL — comportamento implícito e inseguro. Use `ADD` só para extrair tar local de propósito. |
| `RUN` encadeado | Junte com `&&` e limpe na mesma camada | `RUN apt-get update` numa camada e `install` em outra cacheia índice velho; `rm -rf /var/lib/apt/lists/*` em camada separada não reduz tamanho (a anterior já gravou os bytes). |
| Forma exec vs shell | Use `["exec","forma"]` | Forma shell roda sob `/bin/sh -c`, que vira PID 1 e **não repassa sinais** — o `SIGTERM` do deploy não chega no processo. |
| `CMD` vs `ENTRYPOINT` | `ENTRYPOINT` = o binário fixo; `CMD` = args default sobrescrevíveis | `ENTRYPOINT ["app"]` + `CMD ["--port=8080"]` deixa o container executável e configurável. |
| `ARG` vs `ENV` | `ARG` só existe no build; `ENV` persiste no runtime | Não use `ENV` para valor que só o build precisa — ele vaza para o container e para o histórico. |
| `WORKDIR` | Sempre defina; nunca `RUN cd` | `cd` não persiste entre camadas. |
| `EXPOSE` | Documenta a porta, não publica | Publicação é `-p` no run / Compose; `EXPOSE` é metadado. |
| `HEALTHCHECK` | Defina para apps de longa duração | Sem ele, orquestrador não sabe se o processo está vivo mas travado. |

Exemplo de encadeamento correto de `RUN` (Debian):

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*
```

Ação em revisão: procure `COPY . .` acima do install de deps, `RUN apt-get update`
isolado, `CMD` em forma shell e `ADD` onde `COPY` bastaria — são os quatro erros
mais comuns.

## `.dockerignore`: o build context

Antes de qualquer instrução, o Docker envia o **build context** (o diretório do
build) para o daemon. Sem `.dockerignore`, isso inclui `node_modules`, `.git`,
`.env`, dumps e artefatos — deixa o build lento, incha o context e arrisca copiar
segredo ou credencial para dentro da imagem via `COPY . .`.

```
node_modules
.git
.env
dist
*.log
Dockerfile
.dockerignore
```

Ação em revisão: todo repo com Dockerfile precisa de `.dockerignore`. A ausência
dele é sinal de alerta por si só (tamanho e vazamento).

## Multi-stage builds: o padrão mais importante

Tese: **compile num stage, rode em outro**. O stage `builder` tem toolchain,
headers, compiladores e cache de deps; a imagem final copia só o **artefato** e
descarta todo o resto. É o que mais reduz tamanho e superfície de ataque de uma vez
— a imagem de produção não carrega compilador nem gerenciador de pacotes.

```dockerfile
# ---- build ----
FROM golang:1.23 AS builder
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app ./cmd/server

# ---- runtime ----
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /app /app
USER nonroot
ENTRYPOINT ["/app"]
```

Para Node/interpretadas, o ganho vem de separar deps de dev/build das de runtime e
deixar para trás o toolchain nativo:

```dockerfile
FROM node:22-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build && npm prune --omit=dev

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/main.js"]
```

Quando NÃO aplicar: script interpretado trivial sem passo de build e sem deps
nativas ganha pouco — mas mesmo aí multi-stage separa dev deps de prod. Para
qualquer app **compilada** (Go, Rust, Java, .NET, C++), imagem final com toolchain
é sempre erro de revisão.

## Imagens base e tamanho

A base define tamanho, superfície de ataque e facilidade de debug. Não existe
escolha universal — existe trade-off explícito:

| Base | Tamanho | Trade-off | Quando |
|------|---------|-----------|--------|
| `full` (`node`, `python`, `debian`) | Grande | Tudo à mão, muito CVE e superfície | Só como stage builder |
| `-slim` (Debian slim) | Médio | glibc padrão, tem shell/apt, poucos extras | Default seguro para runtime interpretado |
| `alpine` | Pequeno | **musl libc** ≠ glibc: bugs sutis de DNS, timezone, e binários que esperam glibc; build de deps nativas mais lento | Imagem enxuta quando você validou compatibilidade |
| `distroless` | Mínimo | Sem shell, sem package manager, sem `sh` — mais seguro e difícil de debugar | Runtime de app compilada ou já buildada |
| `scratch` | Zero | Nada dentro; só binário estático | Go/Rust estático, CA certs à mão |

O ponto do Alpine: musl é menor mas não é 100% compatível com glibc. Já houve
problemas reais de resolução DNS e de performance com threads; deps compiladas de
Python/Node podem não ter wheel/binário para musl e caírem em build from source.
Não é proibido — é uma escolha que exige validação.

Fixe a base por **digest** para reprodutibilidade e para não ser surpreendido por
um `latest`/tag reescrito no registry:

```dockerfile
FROM node:22-slim@sha256:<digest>
```

Ação em revisão: `FROM ...:latest` em qualquer lugar é alerta. Base `full` no stage
de runtime idem. Alpine sem menção a ter validado compatibilidade merece pergunta.

## Segurança

Camadas são **imutáveis e persistem no histórico**. Um segredo escrito numa camada
continua lá mesmo que uma camada posterior o apague — `docker history` e o pull
recuperam. Daí as regras:

- **Nunca** `ARG`/`ENV`/`COPY` de segredo no Dockerfile. Use **BuildKit secrets**,
  que montam o segredo só durante aquele `RUN` e não vão para nenhuma camada:

```dockerfile
RUN --mount=type=secret,id=npmtoken \
    NPM_TOKEN=$(cat /run/secrets/npmtoken) npm ci
```
```bash
docker build --secret id=npmtoken,src=$HOME/.npmtoken .
```

- **Rode como não-root.** Crie um usuário e faça `USER` antes do `CMD`. Container
  root que escapa é root no host (sem user namespace remap). Distroless oferece a
  tag `:nonroot`.

```dockerfile
RUN useradd -r -u 10001 appuser
USER appuser
```

- **Read-only rootfs no runtime**: `--read-only` + `--tmpfs /tmp`. O processo não
  precisa escrever no filesystem da imagem; travar isso corta uma classe de
  ataque. Configure o mesmo via `readOnlyRootFilesystem` no k8s.
- **Escaneie a imagem** no CI e falhe o build em vulnerabilidade crítica:
  `docker scout cves`, `trivy image`, `grype`. Escaneie a imagem final, não só a
  base.
- **Minimize a superfície**: menos pacotes, menos camadas com ferramenta, sem
  shell onde não precisa. Multi-stage já esconde o toolchain de build.
- **Nunca `latest` em produção** — sem imutabilidade não há rollback confiável nem
  auditoria do que roda.

Ação em revisão: procure segredo em `ARG`/`ENV`, ausência de `USER` (roda root),
imagem sem scan no pipeline e rootfs gravável sem necessidade.

## Build com BuildKit

BuildKit é o backend de build padrão e habilita recursos que não existiam no build
clássico. Use-o (`DOCKER_BUILDKIT=1` ou `docker buildx`):

- **Cache mounts** — cache de deps persiste entre builds sem virar camada:

```dockerfile
RUN --mount=type=cache,target=/root/.npm npm ci
```

- **Build secrets** (`--mount=type=secret`) e **SSH** (`--mount=type=ssh`) para
  clonar repo privado sem embutir chave.
- **Multiplataforma** com `buildx` para publicar arm64 + amd64 numa manifest list:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t app:1.4 --push .
```

- **Cache de camadas no CI** — sem daemon persistente, exporte/importe cache de um
  registry para acelerar builds:

```bash
docker buildx build \
  --cache-to type=registry,ref=reg/app:cache,mode=max \
  --cache-from type=registry,ref=reg/app:cache -t app:1.4 --push .
```

Ação em revisão: build de app com deps pesadas sem cache mount e CI sem
`cache-from`/`cache-to` desperdiçam minutos de runner a cada execução.

## Runtime: PID 1, sinais, limites, logs

O processo do container é **PID 1**, e PID 1 tem responsabilidades especiais no
Linux: não recebe sinais default e é quem faz reaping de processos zumbis. Isso
gera dois problemas clássicos:

- **Sinais / graceful shutdown**: no deploy o orquestrador manda `SIGTERM` e espera
  o processo drenar conexões antes do `SIGKILL`. Se o `CMD` está em forma shell,
  quem é PID 1 é o `sh`, que não repassa o sinal — o app é morto à força. Use forma
  exec e trate `SIGTERM` no código (fechar servidor, terminar in-flight).
- **Zumbis**: se seu processo cria filhos e não faz reaping, eles viram zumbis. Rode
  com `--init` (ou `tini`) para ter um init mínimo como PID 1.

```bash
docker run --init --memory=512m --cpus=1.5 --read-only --tmpfs /tmp app:1.4
```

Outras regras de runtime:

| Tema | Regra |
|------|-------|
| Limites | Sempre `--memory`/`--cpus` (ou requests/limits no k8s). Sem limite, um container consome o host inteiro. |
| Logs | Escreva em **stdout/stderr** (12-factor). Não gerencie arquivo de log dentro do container — o runtime coleta o stream. |
| Estado | Dados em **volume** (gerenciado pelo Docker, portável) ou **bind mount** (path do host, ótimo em dev, acoplado ao host). Nunca na camada writable. |
| Rede | Bridge default isola; crie rede nomeada para containers se comunicarem por nome de serviço. Publique só as portas necessárias. |

Ação em revisão: `CMD` em forma shell numa app que precisa de shutdown limpo,
ausência de handler de `SIGTERM`, container sem limite de memória e app logando em
arquivo em vez de stdout.

## Tags: imutabilidade e build once, deploy many

Tese: **construa a imagem uma vez e promova o mesmo artefato** entre ambientes
(dev → staging → prod). Rebuildar por ambiente significa que o que você testou não
é o que sobe. A imagem é imutável; o que muda entre ambientes é configuração
(env/secret injetados no runtime), não o binário.

- Versione com **semver + digest**. A tag legível (`app:1.4.2`) é para humano; o
  **digest** é a garantia de que é exatamente aquele conteúdo.
- Trate tags de release como **imutáveis** — nunca reescreva `1.4.2` apontando para
  outro build. Precisou corrigir? Nova versão.
- `latest` e `main` são ponteiros móveis: úteis em dev, proibidos como referência
  de deploy em produção.

Ação em revisão: promoção via rebuild por ambiente, tag de release reescrita e
deploy referenciando `latest` quebram rastreabilidade e rollback.

## Sinais de alerta na revisão

| Sinal | Por que é problema | Correção |
|-------|--------------------|----------|
| `FROM ...:latest` | Sem imutabilidade, sem rollback confiável | Pin por versão + digest |
| Roda como root (sem `USER`) | Escape do container vira root no host | Criar usuário e `USER` antes do `CMD` |
| Secret via `ARG`/`ENV`/`COPY` | Persiste no histórico de camadas para sempre | BuildKit `--mount=type=secret` |
| App compilada sem multi-stage | Imagem final carrega toolchain e superfície enorme | Stage builder + runtime mínimo |
| Sem `.dockerignore` | Context inchado, risco de copiar `.env`/`.git` | Adicionar `.dockerignore` |
| `COPY . .` antes de instalar deps | Quebra cache de layers a cada commit | Copiar manifesto, instalar, depois `COPY . .` |
| Sem `HEALTHCHECK` (app longa duração) | Processo travado passa por saudável | Definir `HEALTHCHECK` |
| Imagem gigante com toolchain de build | Pull lento, superfície e custo altos | Multi-stage + base slim/distroless |
| `CMD` em forma shell | PID 1 vira `sh`, `SIGTERM` não chega — sem graceful shutdown | Forma exec `["..."]` + `--init` |
| Sem limite de CPU/memória | Um container derruba o host | `--memory`/`--cpus` ou requests/limits |
| `RUN apt-get update` isolado / sem limpeza | Índice velho em cache, camada não encolhe | Encadear `update && install && rm -rf` numa camada |
| App logando em arquivo | Runtime não coleta, disco enche | stdout/stderr |
| Imagem sem scan no CI | CVE conhecido chega em produção | `docker scout`/`trivy`/`grype` no pipeline |

Feche toda revisão de Docker pelo trade-off: **tamanho vs. debugabilidade**
(distroless é seguro mas você não tem shell para investigar) e **cache vs.
reprodutibilidade** (cache mount acelera, digest garante). Aponte qual dos dois o
contexto do time pede antes de recomendar a mudança.
