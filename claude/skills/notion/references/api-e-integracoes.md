# Notion API e Integrações

Referência prática da Notion API para quem vai automatizar: modelo de objetos, autenticação,
versionamento, endpoints com payloads reais, limites, e quando usar o Notion MCP em vez de bater
na API crua.

**Versão da API vigente:** `2026-03-11` (confirmada em <https://developers.notion.com/reference/versioning>).
A versão anterior amplamente usada é `2025-09-03`, que introduziu o modelo `database` → `data_source`.
Tudo antes disso (`2022-06-28` e anteriores) está fora de suporte no SDK oficial v5+.

**Base URL:** `https://api.notion.com/v1`

---

## 1. Modelo de objetos

A API expõe sete objetos de primeira classe. Entender como eles se aninham economiza 90% do
tempo de debug, porque quase todo erro `object_not_found` ou `validation_error` é confusão de
qual ID vai em qual campo.

| Objeto | `object` | O que é | Onde vive |
|---|---|---|---|
| `page` | `"page"` | Um documento. Tem propriedades (se filho de data source) e conteúdo (blocos) | Filho de `workspace`, `page_id`, `database_id` ou `data_source_id` |
| `block` | `"block"` | Uma unidade de conteúdo: parágrafo, heading, imagem, tabela, coluna | Filho de uma page ou de outro block |
| `database` | `"database"` | **Container** de uma ou mais data sources. Guarda `title`, `icon`, `cover`, `is_inline` | Filho de `page_id` ou `workspace` |
| `data_source` | `"data_source"` | A **tabela** de verdade: guarda o `properties` (schema) e é o alvo de query | Filho de um `database` |
| `user` | `"user"` | Pessoa ou bot. Tipos: `person` e `bot` | Workspace |
| `comment` | `"comment"` | Comentário em page ou block, agrupado por `discussion_id` | Filho de `page_id` ou `block_id` |
| `property_item` | `"property_item"` | O valor de **uma** propriedade de **uma** page, paginado | Filho de uma page |

### 1.1 A hierarquia real

```
workspace
└── page (ex.: "Engenharia")
    ├── block (paragraph, heading_1, callout, …)
    │   └── block (children aninhados: toggle, column, table_row)
    └── database  ← container, NÃO tem properties
        ├── data_source "Tarefas Q3"   ← tem properties (schema)
        │   └── page (um item da tabela) ← tem properties (valores)
        │       └── block (o corpo da page do item)
        └── data_source "Tarefas Q4"
```

Uma `page` tem duas faces que confundem quem começa:

- **`properties`** — só existe de verdade quando o parent é um `data_source`. Aí os valores
  seguem o schema daquela data source. Se o parent for outra page, só `title` existe.
- **conteúdo** — não está em `properties`. É a lista de blocos filhos, lida por
  `GET /v1/blocks/{page_id}/children`. **O `page_id` funciona como `block_id`**: toda page é
  também um bloco container.

### 1.2 O modelo database/data_source (a mudança de 2025)

Antes de `2025-09-03`, `database` e "tabela" eram a mesma coisa: o database tinha `properties`
e você fazia `POST /v1/databases/{id}/query`. Desde `2025-09-03`, um database é um **container**
que pode ter várias data sources (várias tabelas debaixo do mesmo objeto, com abas na UI).

| O que mudou | Antes (`2022-06-28`) | Agora (`2025-09-03`+) |
|---|---|---|
| Query de itens | `POST /v1/databases/{id}/query` | `POST /v1/data_sources/{id}/query` |
| Ler schema | `GET /v1/databases/{id}` retornava `properties` | `GET /v1/data_sources/{id}` retorna `properties` |
| Alterar schema | `PATCH /v1/databases/{id}` | `PATCH /v1/data_sources/{id}` |
| Parent ao criar page | `{"database_id": "…"}` | `{"data_source_id": "…"}` |
| Relation property | apontava `database_id` | requer `data_source_id` no request |
| Filtro do `/v1/search` | `"value": "database"` | `"value": "data_source"` |

**O que quebrou na prática:** código antigo que guardava um `database_id` no banco e usava
direto no query passou a receber `object_not_found` ou `validation_error`. **IDs de database e
de data source não são intercambiáveis** — mesmo formato UUID, namespaces diferentes.

O caminho de migração é sempre o mesmo: dado um `database_id`, chame
`GET /v1/databases/{database_id}` e leia o array `data_sources` da resposta:

```bash
curl -s "https://api.notion.com/v1/databases/842a0286-cef0-46a8-abba-eac4c8ca644e" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11"
```

```json
{
  "object": "database",
  "id": "842a0286-cef0-46a8-abba-eac4c8ca644e",
  "title": [{ "type": "text", "text": { "content": "Tarefas" }, "plain_text": "Tarefas" }],
  "is_inline": false,
  "in_trash": false,
  "data_sources": [
    { "id": "2f26ee68-df30-4251-aad4-8ddc420cba3d", "name": "Tarefas Q3" }
  ],
  "parent": { "type": "page_id", "page_id": "c1e5a2f0-0000-4000-8000-000000000000" }
}
```

Guarde o `data_source_id` — é ele que você usa em query, em `parent` ao criar pages, e em
relations. Guarde o `database_id` só para renomear o container, trocar ícone ou mover.

> **Regra prática:** se a operação é sobre *linhas e colunas*, é data source. Se é sobre a
> *caixa* que segura as tabelas (título, ícone, capa, posição na árvore), é database.

### 1.3 Objeto page

```json
{
  "object": "page",
  "id": "59833787-2cf9-4fdf-8782-e53db20768a5",
  "created_time": "2026-05-12T14:22:00.000Z",
  "last_edited_time": "2026-07-18T09:03:00.000Z",
  "created_by": { "object": "user", "id": "c3aa0ba1-…" },
  "last_edited_by": { "object": "user", "id": "c3aa0ba1-…" },
  "cover": { "type": "external", "external": { "url": "https://exemplo.com/capa.png" } },
  "icon": { "type": "emoji", "emoji": "🚀" },
  "parent": { "type": "data_source_id", "data_source_id": "2f26ee68-…" },
  "in_trash": false,
  "properties": {
    "Nome": { "id": "title", "type": "title", "title": [ /* rich text */ ] },
    "Status": { "id": "K%3EAd", "type": "status", "status": { "id": "…", "name": "Em andamento", "color": "blue" } },
    "Estimativa": { "id": "%40Xzn", "type": "number", "number": 8 }
  },
  "url": "https://www.notion.so/Corrigir-retry-do-worker-598337872cf94fdf8782e53db20768a5",
  "public_url": null
}
```

Atenção a `in_trash`: na versão `2026-03-11` ele **substituiu** `archived` em todos os endpoints.
Código que ainda envia `"archived": true` no body vai falhar na validação nessa versão.

### 1.4 Objeto data source

```json
{
  "object": "data_source",
  "id": "2f26ee68-df30-4251-aad4-8ddc420cba3d",
  "parent": { "type": "database_id", "database_id": "842a0286-…" },
  "title": [{ "type": "text", "text": { "content": "Tarefas Q3" }, "plain_text": "Tarefas Q3" }],
  "description": [],
  "icon": null,
  "in_trash": false,
  "created_time": "2026-01-15T10:30:00.000Z",
  "last_edited_time": "2026-07-10T18:41:00.000Z",
  "properties": {
    "Nome":       { "id": "title",  "name": "Nome",       "type": "title",  "title": {} },
    "Status":     { "id": "K%3EAd", "name": "Status",     "type": "status", "status": { "options": [ … ], "groups": [ … ] } },
    "Estimativa": { "id": "%40Xzn", "name": "Estimativa", "type": "number", "number": { "format": "number" } },
    "Responsável":{ "id": "n%3AoW", "name": "Responsável","type": "people", "people": {} }
  }
}
```

Repare que `properties` aqui descreve o **schema** (tipos e opções), enquanto em uma page o
mesmo `properties` carrega **valores**. Os `id` das propriedades são URL-encoded (`%3E`, `%40`)
e são estáveis mesmo se o usuário renomear a coluna — prefira gravar `id` a gravar `name` se a
sua integração precisa sobreviver a renomeações.

### 1.5 Objeto block

Todo bloco tem envelope comum + um objeto com o nome do próprio tipo:

```json
{
  "object": "block",
  "id": "c02fc1d3-db8b-45c5-a222-27595b15aea7",
  "parent": { "type": "page_id", "page_id": "59833787-…" },
  "type": "paragraph",
  "created_time": "2026-07-01T12:00:00.000Z",
  "last_edited_time": "2026-07-01T12:00:00.000Z",
  "has_children": false,
  "in_trash": false,
  "paragraph": {
    "rich_text": [{ "type": "text", "text": { "content": "Olá" }, "plain_text": "Olá" }],
    "color": "default"
  }
}
```

**Tipos criáveis/editáveis pela API** (confirmado em <https://developers.notion.com/reference/block>):
`bookmark`, `breadcrumb`, `bulleted_list_item`, `callout`, `code`, `column_list`/`column`,
`divider`, `embed`, `equation`, `file`, `heading_1`…`heading_4`, `image`, `numbered_list_item`,
`paragraph`, `pdf`, `quote`, `synced_block`, `table`/`table_row`, `table_of_contents`, `tab`,
`to_do`, `toggle`, `video`, `audio`.

**Somente leitura:** `link_preview`, `meeting_notes` (chamado `transcription` antes de
`2026-03-11`). Qualquer outro tipo volta como `{"type": "unsupported"}` com um campo
`block_type` dizendo o que era de verdade — é assim que `form` e `button` aparecem.

---

## 2. Autenticação

### 2.1 Internal integration token

Para automação interna de um único workspace. Você cria a integração em
<https://www.notion.so/my-integrations>, precisa ser workspace owner, e recebe um token estático
(`ntn_…`) usado em todas as chamadas.

```bash
curl -s https://api.notion.com/v1/users/me \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11"
```

Desde julho de 2026 os personal access tokens têm expiração configurável (7 dias a 1 ano) — se a
sua integração é de longa duração, escolha o prazo mais longo e monitore `401 unauthorized`.

**Use quando:** script de sincronização interno, cron, backend próprio, um workspace só.
**Não use quando:** você distribui o produto para outros workspaces — aí é OAuth.

### 2.2 Public integration (OAuth 2.0)

Fluxo authorization code padrão, para integrações instaláveis em qualquer workspace.

1. Redirecione o usuário para a URL de autorização da sua integração (ela é gerada no painel
   de integrações, com `client_id`, `redirect_uri`, `response_type=code`, `owner=user`).
2. O Notion devolve `?code=…&state=…` no seu `redirect_uri`.
3. Troque o code por token:

```bash
curl -s -X POST https://api.notion.com/v1/oauth/token \
  -H "Authorization: Basic $(printf '%s:%s' "$CLIENT_ID" "$CLIENT_SECRET" | base64)" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2026-03-11" \
  -d '{
        "grant_type": "authorization_code",
        "code": "e202e8c9-0990-40af-855f-ff8f872b1ec6",
        "redirect_uri": "https://exemplo.com/callback"
      }'
```

Resposta (campos principais):

```json
{
  "access_token": "ntn_…",
  "token_type": "bearer",
  "bot_id": "b3414d65-…",
  "workspace_id": "63b9d1a4-…",
  "workspace_name": "Acme",
  "workspace_icon": "https://…",
  "owner": { "type": "user", "user": { "object": "user", "id": "…" } },
  "duplicated_template_id": null
}
```

A autenticação do endpoint de token é **HTTP Basic** com `client_id:client_secret` em base64 —
não é bearer. Isso é a causa mais comum de `invalid_grant` em implementações caseiras.
Refresh de token usa o mesmo endpoint com `grant_type: "refresh_token"`.

### 2.3 Capabilities (os "escopos" do Notion)

A Notion não usa escopos OAuth granulares por request; ela usa **capabilities** configuradas na
integração. As principais:

| Capability | Efeito |
|---|---|
| Read content | `GET`/query em pages, blocks, data sources |
| Update content | `PATCH` em pages e blocks |
| Insert content | `POST /v1/pages`, `PATCH /v1/blocks/{id}/children` |
| Read comments | `GET /v1/comments` |
| Insert comments | `POST /v1/comments` |
| Read user information (com ou sem e-mail) | `/v1/users` |

**As duas de comentário vêm desligadas por padrão.** Se `POST /v1/comments` responde `403
restricted_resource` e o token está certo, é isso.

### 2.4 O passo que todo mundo esquece: conectar a integração à página

Token válido + capabilities corretas + página existente = **`404 object_not_found`**, porque a
API só enxerga o que foi explicitamente compartilhado com a integração.

Na página (ou no topo da árvore que você quer expor): menu `•••` → **Connections** /
**Add connections** → busque o nome da integração → confirme.

O acesso é **herdado para baixo**: conecte na página raiz do teamspace e todos os filhos ficam
visíveis. Não existe endpoint para se auto-conceder acesso — é sempre ação humana na UI.
Documentado em <https://www.notion.com/help/add-and-manage-connections-with-the-api>.

> Debug: se `GET /v1/users/me` funciona (token ok) mas `GET /v1/pages/{id}` dá 404, o problema é
> conexão, não credencial. `404` aqui significa "não existe **para você**", não "não existe".

---

## 3. Versionamento

Toda request exige o header `Notion-Version`. Omitir gera `400 missing_version`.

```
Notion-Version: 2026-03-11
```

Uma nova versão só nasce quando há mudança **incompatível**. Adições (endpoint novo, parâmetro
opcional, campo novo na resposta) entram em todas as versões ao mesmo tempo, sem bump.

**Mudanças incompatíveis de `2026-03-11`:**

| Antes | Depois | Onde |
|---|---|---|
| `"after": "<block_id>"` | `"position": { "type": "after_block", "after_block": { "id": "<block_id>" } }` | append de blocos |
| `archived` | `in_trash` | todos os endpoints |
| tipo de bloco `transcription` | `meeting_notes` | objeto block |

**Mudanças incompatíveis de `2025-09-03`:** o modelo database/data_source da seção 1.2.

Fixe a versão no código, nunca deixe implícita, e trate o upgrade como uma tarefa deliberada.
Uma boa prática é ler `Notion-Version` de variável de ambiente para poder testar a versão nova
em staging sem redeploy de código.

---

## 4. Endpoints principais

### 4.1 Criar page

`POST /v1/pages`

```bash
curl -s -X POST https://api.notion.com/v1/pages \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "type": "data_source_id", "data_source_id": "2f26ee68-df30-4251-aad4-8ddc420cba3d" },
    "icon": { "type": "emoji", "emoji": "🐛" },
    "properties": {
      "Nome":        { "title": [{ "text": { "content": "Corrigir retry do worker" } }] },
      "Status":      { "status": { "name": "Em andamento" } },
      "Estimativa":  { "number": 3 },
      "Tags":        { "multi_select": [{ "name": "backend" }, { "name": "urgente" }] },
      "Prazo":       { "date": { "start": "2026-07-25" } },
      "Responsável": { "people": [{ "object": "user", "id": "c3aa0ba1-…" }] }
    },
    "children": [
      { "type": "heading_2", "heading_2": { "rich_text": [{ "text": { "content": "Contexto" } }] } },
      { "type": "paragraph", "paragraph": { "rich_text": [{ "text": { "content": "O worker não respeita Retry-After." } }] } }
    ]
  }'
```

Formatos aceitos em `parent` (só um por request):
`{"data_source_id": "…"}`, `{"page_id": "…"}`, `{"database_id": "…"}`, `{"workspace": true}`
(este último só para public integrations).

Alternativas ao `children` na versão atual:

- **`markdown`**: string em Notion-flavored markdown, mutuamente exclusiva com `children`.
  Muito mais barato em tokens e em linhas de código para conteúdo longo. Com `allow_async: true`
  a resposta pode vir `202` com um objeto `async_task` a ser consultado depois.
- **`template`**: aplica um template (`{"type":"template_id","template_id":"…"}`, `"default"`
  ou `"none"`).

Limite: `children` aceita no máximo 100 blocos. Conteúdo maior exige append incremental (4.4).

### 4.2 Atualizar propriedades

`PATCH /v1/pages/{page_id}`

```bash
curl -s -X PATCH "https://api.notion.com/v1/pages/59833787-2cf9-4fdf-8782-e53db20768a5" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "properties": {
      "Status": { "status": { "name": "Concluído" } },
      "Tags":   { "multi_select": [{ "name": "backend" }] }
    }
  }'
```

Semântica importante:

- É **merge por propriedade**, não replace do objeto inteiro: propriedades não citadas ficam
  intactas.
- Mas é **replace dentro de cada propriedade**: mandar `multi_select` com um item apaga os
  outros. Para "adicionar uma tag" você precisa ler, concatenar e reenviar.
- Para limpar: `{"date": null}`, `{"multi_select": []}`, `{"rich_text": []}`.
- Este endpoint **não altera conteúdo** (blocos). Para isso, endpoints de block.
- Mandar para a lixeira: `{"in_trash": true}`.

Propriedades **não graváveis**: `formula`, `rollup`, `created_time`, `created_by`,
`last_edited_time`, `last_edited_by`, `unique_id`. Tentar escrever gera `validation_error`.

### 4.3 Ler blocos com paginação

`GET /v1/blocks/{block_id}/children?page_size=100&start_cursor=…`

```bash
curl -s "https://api.notion.com/v1/blocks/59833787-2cf9-4fdf-8782-e53db20768a5/children?page_size=100" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11"
```

```json
{
  "object": "list",
  "results": [ { "object": "block", "type": "heading_2", "has_children": false, … } ],
  "next_cursor": "aG9sYS0x…",
  "has_more": true,
  "type": "block",
  "block": {}
}
```

Duas paginações se acumulam aqui e é fácil errar:

1. **Horizontal** — `has_more`/`next_cursor` na lista de irmãos.
2. **Vertical** — `has_children: true` significa que existem filhos que **não** vieram na
   resposta. Toggles, colunas, listas aninhadas e `table` exigem nova chamada com o `id`
   daquele bloco. Ler uma página inteira é uma travessia recursiva em árvore, não uma lista.

```ts
async function lerArvore(notion: Client, blockId: string): Promise<BlockObjectResponse[]> {
  const blocos: BlockObjectResponse[] = []
  for await (const bloco of iteratePaginatedAPI(notion.blocks.children.list, {
    block_id: blockId,
  })) {
    const b = bloco as BlockObjectResponse
    blocos.push(b)
    if (b.has_children) {
      blocos.push(...(await lerArvore(notion, b.id)))
    }
  }
  return blocos
}
```

Se você só precisa do texto, considere pedir markdown (ver
<https://developers.notion.com/guides/data-apis/working-with-markdown-content>) em vez de
reconstruir a árvore à mão.

### 4.4 Append de blocos

`PATCH /v1/blocks/{block_id}/children`

```bash
curl -s -X PATCH "https://api.notion.com/v1/blocks/59833787-2cf9-4fdf-8782-e53db20768a5/children" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "children": [
      { "type": "callout", "callout": {
          "icon": { "type": "emoji", "emoji": "⚠️" },
          "color": "yellow_background",
          "rich_text": [{ "text": { "content": "Deploy congelado até sexta." } }]
      }},
      { "type": "toggle", "toggle": {
          "rich_text": [{ "text": { "content": "Detalhes" } }],
          "children": [
            { "type": "paragraph", "paragraph": { "rich_text": [{ "text": { "content": "Nested funciona até 2 níveis." } }] } }
          ]
      }}
    ],
    "position": { "type": "after_block", "after_block": { "id": "c02fc1d3-db8b-45c5-a222-27595b15aea7" } }
  }'
```

`position` (novo em `2026-03-11`, substitui `after`):

| Valor | Efeito |
|---|---|
| `{ "type": "end" }` | Anexa no fim (default) |
| `{ "type": "start" }` | Insere no começo |
| `{ "type": "after_block", "after_block": { "id": "…" } }` | Insere logo depois do bloco indicado |

Restrições: máximo 100 blocos por request, até **dois níveis** de aninhamento no mesmo payload,
e o endpoint **só cria** — não move blocos existentes. Reordenar conteúdo pela API significa
deletar e recriar, o que perde comentários e IDs.

### 4.5 Query de data source

`POST /v1/data_sources/{data_source_id}/query`

```bash
curl -s -X POST "https://api.notion.com/v1/data_sources/2f26ee68-df30-4251-aad4-8ddc420cba3d/query" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "and": [
        { "property": "Status", "status": { "does_not_equal": "Concluído" } },
        { "property": "Prazo",  "date":   { "on_or_before": "2026-07-31" } },
        { "or": [
            { "property": "Tags", "multi_select": { "contains": "backend" } },
            { "property": "Tags", "multi_select": { "contains": "infra" } }
        ]}
      ]
    },
    "sorts": [
      { "property": "Prazo", "direction": "ascending" },
      { "timestamp": "last_edited_time", "direction": "descending" }
    ],
    "page_size": 100
  }'
```

```json
{
  "object": "list",
  "results": [ { "object": "page", "id": "…", "properties": { … } } ],
  "next_cursor": null,
  "has_more": false,
  "type": "page_or_data_source",
  "request_status": { "type": "complete", "incomplete_reason": null }
}
```

Parâmetros do body: `filter`, `sorts`, `page_size` (máx. 100), `start_cursor`,
`is_archived` (default `false`), `result_type` (`"page"` ou `"data_source"`, este último só
para wikis). Query string: `filter_properties[]` para reduzir o payload a propriedades
específicas — vale muito a pena em data sources com dezenas de colunas.

Filtros seguem sempre `{ "property": "<nome ou id>", "<tipo>": { "<condição>": valor } }`.
O **tipo tem que bater com o tipo real da propriedade** — usar `select` numa coluna `status` é
`validation_error`, e é o erro mais comum aqui, porque `status` e `select` parecem iguais na UI.

Condições por tipo (resumo):

| Tipo | Condições típicas |
|---|---|
| `title`, `rich_text`, `url`, `email`, `phone_number` | `equals`, `does_not_equal`, `contains`, `does_not_contain`, `starts_with`, `ends_with`, `is_empty`, `is_not_empty` |
| `number` | `equals`, `greater_than`, `less_than`, `greater_than_or_equal_to`, `less_than_or_equal_to`, `is_empty` |
| `checkbox` | `equals`, `does_not_equal` |
| `select`, `status` | `equals`, `does_not_equal`, `is_empty`, `is_not_empty` |
| `multi_select` | `contains`, `does_not_contain`, `is_empty` |
| `date`, `created_time`, `last_edited_time` | `equals`, `before`, `after`, `on_or_before`, `on_or_after`, `past_week`, `next_month`, `is_empty` |
| `people`, `created_by`, `last_edited_by` | `contains`, `does_not_contain`, `is_empty` |
| `relation` | `contains`, `does_not_contain`, `is_empty` |
| `formula`, `rollup` | wrapper pelo tipo do resultado (`string`, `number`, `checkbox`, `date`) |

Combinadores `and`/`or` aninham até **dois níveis**. Filtro mais complexo do que isso precisa
ser feito em memória depois de puxar um conjunto maior.

O teto de **10.000 resultados** por query é real. Para data sources maiores, particione por
janela de tempo (`last_edited_time` entre X e Y) — o SDK tem `iterateAllDataSourceRows()`
exatamente para isso.

`request_status.type` pode vir `"incomplete"` quando o Notion aborta a varredura; nesse caso o
resultado é parcial e você precisa estreitar o filtro. Não trate `has_more: false` como
"terminou com sucesso" sem olhar esse campo.

### 4.6 Search

`POST /v1/search`

```bash
curl -s -X POST https://api.notion.com/v1/search \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "retrospectiva",
    "filter": { "property": "object", "value": "page" },
    "sort": { "direction": "descending", "timestamp": "last_edited_time" },
    "page_size": 50
  }'
```

O que o search **não** faz, e as pessoas esperam que faça:

- **Não busca no conteúdo dos blocos** — só em títulos de pages e data sources.
- **Não filtra por propriedade.** Para isso use query de data source.
- `filter.value` aceita `"page"` ou `"data_source"` (era `"database"` antes de `2025-09-03`).
- Só devolve o que está compartilhado com a integração.
- Databases linkados duplicados são excluídos dos resultados.
- Pode devolver resultado parcial com `request_status` indicando
  `query_result_limit_reached`.

**Use search quando:** você tem só o nome que o humano digitou e precisa descobrir o ID.
**Não use quando:** você já sabe a data source — query é mais rápido, exato e paginável.

### 4.7 Comments

```bash
# Criar comentário em uma page
curl -s -X POST https://api.notion.com/v1/comments \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{
    "parent": { "page_id": "59833787-2cf9-4fdf-8782-e53db20768a5" },
    "rich_text": [{ "text": { "content": "Build quebrou no CI: ver run #4821." } }],
    "display_name": { "type": "integration" }
  }'
```

Alvo: exatamente um entre `parent.page_id`, `parent.block_id` ou `discussion_id` (para responder
numa thread existente). Conteúdo: `rich_text` (máx. 100 itens) **ou** `markdown` (só formatação
inline). Opcionalmente `attachments` com até 3 `file_upload_id`.

Listagem: `GET /v1/comments?block_id=…` — ver <https://developers.notion.com/reference/list-comments>.

Limitação real: a API **não resolve** discussões. Marcar como resolvido continua sendo ação de UI.

### 4.8 File upload

Fluxo em três passos (<https://developers.notion.com/reference/create-a-file-upload>):

```bash
# 1. Criar o file upload
curl -s -X POST https://api.notion.com/v1/file_uploads \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{ "mode": "single_part", "filename": "relatorio.pdf", "content_type": "application/pdf" }'
# → { "id": "a3f1…", "status": "pending", "upload_url": "https://api.notion.com/v1/file_uploads/a3f1…/send", … }

# 2. Enviar os bytes (multipart/form-data, campo "file")
curl -s -X POST "https://api.notion.com/v1/file_uploads/a3f1…/send" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -F "file=@relatorio.pdf"
# → status: "uploaded"

# 3. Referenciar o upload em um bloco (ou icon/cover/property)
curl -s -X PATCH "https://api.notion.com/v1/blocks/$PAGE_ID/children" \
  -H "Authorization: Bearer $NOTION_TOKEN" \
  -H "Notion-Version: 2026-03-11" \
  -H "Content-Type: application/json" \
  -d '{ "children": [ { "type": "pdf", "pdf": { "type": "file_upload", "file_upload": { "id": "a3f1…" } } } ] }'
```

Modos:

| Modo | Quando | Observações |
|---|---|---|
| `single_part` | arquivos ≤ 20 MB | default |
| `multi_part` | > 20 MB | exige `number_of_parts` (máx. 10.000) e `filename`; finaliza com `POST /v1/file_uploads/{id}/complete` |
| `external_url` | arquivo já hospedado publicamente via HTTPS | o Notion baixa por você |

`status` percorre `pending` → `uploaded` → (`expired` / `failed`). Uploads `pending` têm
`expiry_time`. Desde julho de 2026 blocos HTML também podem ser criados via File Upload API.

---

## 5. Rich text — onde todo mundo erra

Rich text não é string. É um **array de segmentos**, cada um com sua própria formatação. Um
parágrafo com uma palavra em negrito no meio são três objetos, não um.

```json
[
  { "type": "text", "text": { "content": "O deploy " } },
  { "type": "text", "text": { "content": "falhou" }, "annotations": { "bold": true, "color": "red" } },
  { "type": "text", "text": { "content": " no ambiente de " } },
  { "type": "text", "text": { "content": "staging" }, "text_link_placeholder": null,
    "annotations": { "code": true } },
  { "type": "text", "text": { "content": "." } }
]
```

Estrutura de cada segmento:

| Campo | Escrita | Descrição |
|---|---|---|
| `type` | opcional | `"text"`, `"mention"` ou `"equation"` |
| `text` / `mention` / `equation` | sim | objeto específico do tipo |
| `annotations` | opcional | `bold`, `italic`, `strikethrough`, `underline`, `code` (booleans) + `color` |
| `plain_text` | **read-only** | texto sem formatação, gerado pela API |
| `href` | **read-only** | URL resolvida; para criar link use `text.link.url` |

Erros clássicos:

1. **Mandar `plain_text` ou `href` no request.** São de resposta. `href` na escrita é ignorado;
   o link real vai em `text.link`.
2. **Achar que existe HTML/markdown dentro de `content`.** `"**oi**"` renderiza literalmente
   `**oi**`. Formatação só via `annotations` (ou via o parâmetro `markdown` dos endpoints que
   o aceitam, que é outro caminho).
3. **Estourar 2000 caracteres em um único segmento.** O limite é por objeto de rich text, então
   textos longos precisam ser quebrados em vários segmentos — não é o total que trava, é o item.
4. **Omitir `annotations` esperando herdar do segmento anterior.** Cada segmento é independente;
   sem `annotations`, o default é tudo `false`/`"default"`.

Cores aceitas em `annotations.color`: `default`, `gray`, `brown`, `orange`, `yellow`, `green`,
`blue`, `purple`, `pink`, `red`, mais as variantes `*_background`.

### 5.1 Link

```json
{ "type": "text",
  "text": { "content": "abrir o runbook", "link": { "url": "https://exemplo.com/runbook" } } }
```

### 5.2 Mentions

```json
{ "type": "mention", "mention": { "type": "user", "user": { "object": "user", "id": "c3aa0ba1-…" } } }
{ "type": "mention", "mention": { "type": "page", "page": { "id": "59833787-…" } } }
{ "type": "mention", "mention": { "type": "date", "date": { "start": "2026-07-25", "end": null } } }
```

Subtipos de mention: `user`, `page`, `database`, `date`, `link_preview`, `template_mention`.
Mencionar um usuário **não** dispara notificação como quando um humano digita `@` na UI.

### 5.3 Equation

```json
{ "type": "equation", "equation": { "expression": "E = mc^2" } }
```

LaTeX, máximo 1000 caracteres na expressão.

---

## 6. Limites, paginação e erros

### 6.1 Rate limits

Média de **3 requests/segundo por integração**, com bursts tolerados acima disso. Existe também
um limite **por workspace**, compartilhado entre todas as conexões e escalado conforme o plano.
Estourar qualquer um dos dois retorna `429` com código `rate_limited` e header `Retry-After`
em segundos.

Respeite o `Retry-After` — ele é autoritativo. Backoff exponencial cego é pior porque ignora a
janela que o servidor informou.

### 6.2 Tamanhos máximos

| Limite | Valor |
|---|---|
| Payload total por request | 500 KB |
| Blocos por request | 1000 elementos (mas `children` em append/create: 100) |
| Conteúdo de um rich text | 2000 caracteres |
| Qualquer URL | 2000 caracteres |
| Expressão de equation | 1000 caracteres |
| Arrays de bloco | 100 elementos |
| E-mail | 200 caracteres |
| Telefone | 200 caracteres |
| Opções de `multi_select` por request | 100 |
| Relations por request | 100 pages |
| `people` por request | 100 usuários |
| `page_size` de paginação | 100 |
| Resultados por query de data source | 10.000 |
| Nome de arquivo em file upload | 900 bytes |

Os limites de propriedade valem **por request**, não como capacidade total: uma page pode ter
mais de 100 relations, você só não consegue setar mais de 100 de uma vez.

### 6.3 Paginação com cursor

Todo endpoint de lista responde:

```json
{ "object": "list", "results": [ … ], "has_more": true, "next_cursor": "aG9sYS0x…" }
```

Loop correto: enquanto `has_more`, repita passando `start_cursor: next_cursor`. Cursores são
opacos, de curta duração e **não** são offsets — não persista, não faça aritmética, não
paralelize. Uma página só sai depois que a anterior voltou.

Isso significa que iterar uma data source de 10.000 itens custa 100 requests sequenciais; a 3
req/s, ~33 segundos no melhor caso. Planeje jobs de sincronização com isso em mente.

### 6.4 Erros

| HTTP | `code` | Ação |
|---|---|---|
| 400 | `invalid_json` | body malformado |
| 400 | `invalid_request_url` | rota errada (típico: `/databases/{id}/query` em versão nova) |
| 400 | `invalid_request` | operação não suportada |
| 400 | `validation_error` | schema do body errado — leia `message`, ele é específico |
| 400 | `missing_version` | faltou `Notion-Version` |
| 400 | `invalid_grant` | credencial OAuth inválida/expirada/revogada |
| 401 | `unauthorized` | token inválido |
| 403 | `restricted_resource` | falta capability |
| 404 | `object_not_found` | não existe **ou** não foi compartilhado com a integração |
| 409 | `conflict_error` | colisão de escrita — **retry** |
| 429 | `rate_limited` | respeite `Retry-After` |
| 500 | `internal_server_error` | retry com backoff |
| 502 | `bad_gateway` | retry |
| 503 | `service_unavailable` / `database_connection_unavailable` | retry |
| 504 | `gateway_timeout` | retry |
| 529 | `service_overload` | retry com backoff longo |

Formato do erro:

```json
{ "object": "error", "status": 400, "code": "validation_error",
  "message": "body failed validation: body.properties.Status.status.name should be defined.",
  "request_id": "5cbe1f0d-…" }
```

Guarde `request_id` no seu log — é o que o suporte pede.

**Política de retry sensata:** retry em `409`, `429`, `5xx`. Nunca em `400`/`401`/`403`/`404`
(retry não conserta payload errado nem permissão faltando). Backoff exponencial com jitter,
teto de 5 tentativas, respeitando `Retry-After` quando presente.

---

## 7. SDK oficial (`@notionhq/client`)

```bash
npm install @notionhq/client
```

Requer Node 18+. TypeScript 5.9 se você usar os tipos.

```ts
import {
  Client,
  APIErrorCode,
  isNotionClientError,
  iteratePaginatedAPI,
} from "@notionhq/client"

const notion = new Client({
  auth: process.env.NOTION_TOKEN,
  notionVersion: "2026-03-11", // fixe explicitamente; o default do SDK pode ser mais antigo
  timeoutMs: 30_000,
})

type Tarefa = { id: string; nome: string; status: string | null }

export async function tarefasAbertas(dataSourceId: string): Promise<Tarefa[]> {
  const tarefas: Tarefa[] = []

  for await (const page of iteratePaginatedAPI(notion.dataSources.query, {
    data_source_id: dataSourceId,
    filter: { property: "Status", status: { does_not_equal: "Concluído" } },
    sorts: [{ property: "Prazo", direction: "ascending" }],
  })) {
    if (!("properties" in page)) continue // partial response

    const nomeProp = page.properties["Nome"]
    const statusProp = page.properties["Status"]

    tarefas.push({
      id: page.id,
      nome: nomeProp?.type === "title"
        ? nomeProp.title.map((t) => t.plain_text).join("")
        : "",
      status: statusProp?.type === "status" ? statusProp.status?.name ?? null : null,
    })
  }

  return tarefas
}

export async function concluir(pageId: string): Promise<void> {
  try {
    await notion.pages.update({
      page_id: pageId,
      properties: { Status: { status: { name: "Concluído" } } },
    })
  } catch (erro) {
    if (isNotionClientError(erro)) {
      switch (erro.code) {
        case APIErrorCode.ObjectNotFound:
          throw new Error(`Page ${pageId} não existe ou não está compartilhada com a integração.`)
        case APIErrorCode.RateLimited:
          throw new Error("Rate limit; reenfileirar respeitando Retry-After.")
        case APIErrorCode.ValidationError:
          throw new Error(`Payload inválido: ${erro.message}`)
        default:
          throw erro
      }
    }
    throw erro
  }
}
```

**Criar página com conteúdo** — o caso mais pedido. Mesmo payload do curl de 4.1, tipado:

```ts
export async function criarTarefa(dataSourceId: string, titulo: string) {
  return notion.pages.create({
    parent: { type: "data_source_id", data_source_id: dataSourceId },
    icon: { type: "emoji", emoji: "🐛" },
    properties: {
      Nome: { title: [{ text: { content: titulo } }] },
      Status: { status: { name: "Em andamento" } },
    },
    children: [
      { type: "heading_2", heading_2: { rich_text: [{ text: { content: "Contexto" } }] } },
      {
        type: "paragraph",
        paragraph: { rich_text: [{ text: { content: "O worker não respeita Retry-After." } }] },
      },
    ],
  })
}
```

Vale para o SDK o mesmo que vale para o REST: `children` no máximo 100 blocos, e `markdown` é
alternativa mutuamente exclusiva — mais barata para conteúdo longo (ver 4.1).

Helpers que valem conhecer:

| Helper | Uso |
|---|---|
| `iteratePaginatedAPI(fn, args)` | async iterator; consome sem carregar tudo em memória |
| `collectPaginatedAPI(fn, args)` | junta tudo num array; cuidado com listas grandes |
| `iterateAllDataSourceRows(...)` | contorna o teto de 10.000 particionando por janela de tempo |
| `isNotionClientError(e)` / `APIErrorCode` | narrowing type-safe de erro |
| `verifyWebhookSignature(...)` | valida HMAC-SHA256 de webhooks recebidos |

O construtor também aceita `logLevel` e `retry` (retry automático em rate limit e erro de
servidor). Ligue `retry` em vez de escrever a sua própria camada, a menos que precise de
comportamento específico de fila.

Além do SDK, existe uma CLI oficial (<https://developers.notion.com/cli/get-started/overview>),
útil para exploração manual e scripts de uso único.

---

## 8. Notion MCP

O Notion MCP é um servidor **hospedado pela Notion** que expõe o workspace a agentes de IA via
Model Context Protocol, com OAuth e instalação de um clique.

- **URL:** `https://mcp.notion.com/mcp`
- **Transport:** Streamable HTTP
- **Auth:** OAuth. A doc diz que os access tokens duram cerca de oito horas, mas que essa duração
  está sujeita a mudança — leia o campo `expires_in` da resposta em vez de hardcodar o prazo

### 8.1 Conectar

```bash
# Claude Code
claude mcp add --transport http notion https://mcp.notion.com/mcp
# depois rode /mcp e conclua o OAuth
```

**Claude Desktop:** Settings → Connectors → Add Connector → `https://mcp.notion.com/mcp` → OAuth.
(Remote MCP no Desktop é configurado por Connectors, **não** por `claude_desktop_config.json`;
exige plano Pro, Max, Team ou Enterprise.)

**Cursor** — Settings → MCP → novo servidor global:

```json
{ "mcpServers": { "notion": { "url": "https://mcp.notion.com/mcp" } } }
```

**VS Code (Copilot)** — `.vscode/mcp.json`:

```json
{ "servers": { "notion": { "type": "http", "url": "https://mcp.notion.com/mcp" } } }
```

Também existe um servidor open source para self-hosting
(<https://developers.notion.com/guides/mcp/hosting-open-source-mcp>).

### 8.2 Ferramentas expostas

| Tool | O que faz |
|---|---|
| `notion-search` | Busca no workspace e em ferramentas conectadas (Slack, Drive, Jira) |
| `notion-fetch` | Lê page/database/data source por URL ou ID; também identidade do workspace/usuário |
| `notion-create-pages` | Cria uma ou várias pages com propriedades e conteúdo |
| `notion-update-page` | Atualiza propriedades, conteúdo, ícone, capa |
| `notion-move-pages` | Move pages/databases para outro parent |
| `notion-duplicate-page` | Duplica page (assíncrono) |
| `notion-create-database` | Cria database com propriedades e views |
| `notion-update-data-source` | Altera schema, nome, descrição da data source |
| `notion-create-view` / `notion-update-view` | Cria e edita views (table, board, calendar, …) |
| `notion-query-data-sources` | Consulta data sources **com SQL** ou executa uma view existente |
| `notion-query-database-view` | Consulta usando filtros/sorts já salvos numa view |
| `notion-query-meeting-notes` | Filtra meeting notes do usuário atual |
| `notion-create-comment` / `notion-get-comments` | Comentários e discussões |
| `notion-get-teams` | Lista teamspaces |
| `notion-get-users` | Lista membros e convidados |
| `notion-get-async-task` | Consulta status de tarefa assíncrona de outra tool |
| `notion-create-attachment` / `notion-download-attachment` | Envia e baixa anexos |

No conjunto, o servidor cobre busca, leitura e escrita de páginas, query de data sources, criação e
edição de views, comentários e anexos. **Não decore a contagem de tools:** ela muda entre releases e
a lista publicada costuma ficar atrás do que o servidor em produção realmente expõe. Confira com
`/mcp` no seu cliente.

Note que o MCP faz coisas que a REST API **não** faz: criar e editar **views**, e consultar
data sources com **SQL**. `notion-fetch` com `self` retorna um mapa `current_tool_access`
indicando quais tools o plano do workspace libera.

### 8.3 MCP ou API crua?

| Situação | Escolha |
|---|---|
| Trabalho exploratório, conversacional, one-off ("resume esse doc", "cria essa página") | **MCP** |
| Precisa criar/editar views de database | **MCP** (a REST API não faz) |
| Consulta ad hoc em linguagem quase-SQL | **MCP** |
| Job em produção, cron, webhook handler | **API** |
| Precisa de idempotência, log estruturado, retry determinístico | **API** |
| Precisa fixar `Notion-Version` e ter contrato estável | **API** |
| Volume alto e previsível | **API** (controle explícito do rate limit) |
| Não quer gerenciar token nem tela de conexão por página | **MCP** (OAuth cobre o escopo autorizado) |

Regra curta: **MCP para o agente pensar, API para o sistema rodar.** O MCP é ótimo no loop
humano-agente e ruim como dependência de produção — as tools evoluem, o token expira em horas
e o comportamento é otimizado para consumo por LLM, não para contrato de máquina.

---

## 9. O que a API NÃO faz

Ser honesto sobre isso evita arquiteturas que não fecham.

**Blocos e conteúdo**

- Não cria `link_preview` nem `meeting_notes` (só lê).
- Não cria `button` nem `form` — voltam como `unsupported`.
- Não move blocos existentes; append só insere novos.
- Não controla largura de coluna, altura de bloco, nem qualquer detalhe de layout além da
  estrutura `column_list`/`column`.
- Não aplica formatação de página (full width, fonte pequena/serif).

**Databases e views**

- **Não cria nem edita views pela REST API.** Table, board, calendar, timeline, gallery,
  filtros salvos, agrupamentos e ordenações de view são invisíveis para a API. Os `sorts` e
  `filter` do query são do request, não da view. (O MCP cobre isso; a REST API não.)
- Não lê o que está configurado numa view.
- Não escreve em `formula` nem `rollup` — são derivados.
- Não cria nem edita automações/buttons de database.

**Permissões e administração**

- Não compartilha páginas nem gerencia permissões. Conectar integração é sempre manual.
- Não gerencia membros, grupos ou teamspaces (isso é Admin API, escopo Enterprise —
  <https://developers.notion.com/reference/admin/intro>).
- Não publica sites nem configura domínio.

**Outros**

- Search não vê o conteúdo dos blocos, só títulos.
- Não resolve comentários.
- Não dispara notificação de menção como a UI faz.
- Não tem transação: não existe "atualizar 5 pages atomicamente".

---

## 10. Sincronização e idempotência

Sem transação e sem upsert nativo, a robustez tem que vir do desenho.

**1. Guarde a chave externa dentro do Notion.** Crie uma propriedade `rich_text` (ex.:
`External ID`) com o ID do sistema de origem. Antes de criar, faça query filtrando por ela:

```json
{ "filter": { "property": "External ID", "rich_text": { "equals": "jira-PROJ-1421" } }, "page_size": 1 }
```

Zero resultados → `POST /v1/pages`. Um resultado → `PATCH /v1/pages/{id}`. Isso te dá upsert e
torna o job re-executável sem duplicar nada. Sem essa chave você vai duplicar registros na
primeira vez que o job falhar no meio.

**2. Use `last_edited_time` para sync incremental.** Guarde o timestamp da última execução e
filtre por `{"timestamp": "last_edited_time", "last_edited_time": {"on_or_after": "…"}}`. Muito
mais barato que varrer tudo. Cuidado: **qualquer** escrita sua atualiza esse campo, então grave
um marcador do que foi escrito pela integração se quiser evitar eco em sync bidirecional.

**3. Trate `409 conflict_error` como normal.** Notion é colaborativo; escritas concorrentes
colidem. `409` significa "tente de novo", não "deu errado".

**4. Sincronize em uma direção só, quando puder.** Sync bidirecional sem vetor de versão vira
loop de eco (A escreve em B, B nota mudança e escreve em A). Se precisar dos dois lados,
mantenha um hash do conteúdo por registro e só escreva quando o hash mudar de fato.

**5. Cache dos IDs.** `data_source_id` e IDs de propriedade não mudam. Resolva uma vez no boot,
guarde em memória ou config, e pare de gastar requests do seu orçamento de 3/s em lookup.

**6. Prefira `name` a `id` ao *escrever* select/status, e `id` ao *ler*.** Escrever por nome
cria a opção se ela não existir (em `multi_select`); ler por ID sobrevive a renomeação.

**7. Batch respeitando os limites.** 100 blocos por append, 100 itens por página de query,
500 KB por payload. Divida antes de bater no limite, não depois do `validation_error`.

**8. Webhooks em vez de polling.** Ver <https://developers.notion.com/reference/webhooks> e
`verifyWebhookSignature()` no SDK. Polling a 3 req/s desperdiça orçamento e ainda tem latência.

**9. Idempotência no seu lado também.** Se o job cai depois do `POST` mas antes do commit
local, você recria na próxima rodada. A busca por `External ID` do passo 1 é o que protege
contra isso — ela precisa vir antes de qualquer escrita, sempre.

---

## 11. Links de referência

O índice completo e navegável da documentação está em `documentacao-oficial.md`. Os links
abaixo são só os que você mais reabre enquanto escreve código de integração:

| Assunto | Link |
|---|---|
| Versão atual da API | <https://developers.notion.com/reference/versioning> |
| Changelog (breaking changes) | <https://developers.notion.com/page/changelog> |
| Migração database → data source | <https://developers.notion.com/docs/upgrade-guide-2025-09-03> |
| Query de data source (filtros e sorts) | <https://developers.notion.com/reference/query-a-data-source> |
| Formato dos valores de propriedade | <https://developers.notion.com/reference/page-property-values> |
| Tipos de bloco suportados | <https://developers.notion.com/reference/block> |
| Rich text | <https://developers.notion.com/reference/rich-text> |
| Limites e rate limits | <https://developers.notion.com/reference/request-limits> |
| Códigos de erro | <https://developers.notion.com/reference/status-codes> |
| Conectar integração a uma página | <https://www.notion.com/help/add-and-manage-connections-with-the-api> |
| SDK JavaScript | <https://github.com/makenotion/notion-sdk-js> |
| MCP — tools disponíveis | <https://developers.notion.com/guides/mcp/mcp-supported-tools> |
