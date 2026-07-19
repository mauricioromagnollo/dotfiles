# Documentação Oficial do Notion — Índice Curado

Ponto de partida para aprofundar em qualquer assunto de Notion. Todos os links abaixo foram
verificados e respondem `200`.

## Como usar este índice

1. **Procure aqui primeiro.** Achar a página certa custa uma linha de tabela; achar via busca
   genérica custa várias rodadas e frequentemente devolve blog post de terceiro desatualizado.
2. **Leia a página com WebFetch sempre que a resposta exigir precisão.** Este índice diz *onde*
   está a informação, não *qual* é. Use WebFetch quando a pergunta envolver:
   - **limites numéricos** (tamanho de payload, rate limit, quantidade de blocos, preço por seat);
   - **nomes exatos de campos, parâmetros ou propriedades** — a API renomeia coisas entre versões
     (`archived` → `in_trash`, `after` → `position`, `transcription` → `meeting_notes`);
   - **comportamento de recurso novo ou em beta** — Custom Agents, Workers, Notion Mail,
     conectores de IA e views mudam rápido e conhecimento de treino envelhece mal aqui;
   - **passos de UI** que você vai ditar para alguém seguir.
3. **Responda de memória** só para conceito estável (o que é um bloco, o que é uma relation,
   como funciona um teamspace). Para o resto, vale a pena o fetch.
4. **Duas bases distintas:** `www.notion.com/help` é produto e UI (Help Center);
   `developers.notion.com` é API, SDK e MCP. Perguntas de automação quase sempre terminam na
   segunda; perguntas de "como faço isso no Notion" na primeira.
5. **Se um link deste índice devolver 404**, o slug mudou. Vá na página de categoria
   correspondente — as categorias são muito mais estáveis que os artigos — e ache o artigo lá.

---

## 1. Help Center — mapa de categorias

Estas URLs de categoria são as âncoras mais estáveis do Help Center. Quando um artigo específico
some, entre pela categoria.

| Categoria | Link | O que tem lá |
|---|---|---|
| Índice geral | <https://www.notion.com/help> | Porta de entrada; lista todas as categorias |
| Get started | <https://www.notion.com/help/category/new-to-notion> | Primeiros passos, conceitos básicos, primeira página |
| Sidebar & navegação | <https://www.notion.com/help/category/sidebar-navigation> | Estrutura da barra lateral, favoritos, busca, navegação da árvore |
| Workspace settings | <https://www.notion.com/help/category/meet-your-workspace> | Criar/sair de workspace, teamspaces, configurações gerais, HIPAA |
| Settings & preferences | <https://www.notion.com/help/category/account-settings-and-privacy> | Conta, notificações, idioma, aparência, privacidade pessoal |
| Pages & blocks | <https://www.notion.com/help/category/write-edit-and-customize> | Editor, tipos de bloco, formatação, colunas, synced blocks |
| Databases | <https://www.notion.com/help/category/databases> | Bancos de dados, propriedades, relations, rollups, fórmulas, templates |
| Database views | <https://www.notion.com/help/category/database-views> | Table, board, calendar, timeline, gallery, dashboards, filtros e sorts |
| Sharing & permissions | <https://www.notion.com/help/category/sharing-and-collaboration> | Compartilhamento, níveis de acesso, convidados, comentários |
| Notion Sites | <https://www.notion.com/help/category/notion-sites> | Publicar páginas na web, domínio próprio, SEO, customização |
| Import & export | <https://www.notion.com/help/category/import-export-and-integrate> | Importar de Confluence/Asana/Monday, exportar, backup |
| Connections | <https://www.notion.com/help/category/connections> | Integrações com apps de terceiros, conexões da API |
| Automations | <https://www.notion.com/help/category/automations> | Automações de database, buttons, webhook actions |
| Notion AI | <https://www.notion.com/help/category/notion-ai> | Escrita assistida, Q&A, busca com IA, uso e limites |
| Notion AI Connectors | <https://www.notion.com/help/category/notion-ai-connectors> | Conectar Slack, Drive, Jira e outros à busca de IA |
| Custom Agents | <https://www.notion.com/help/category/custom-agents> | Agentes customizados dentro do Notion, configuração e uso |
| External Agents | <https://www.notion.com/help/category/external-agents> | Agentes externos acessando o workspace |
| Privacy & security | <https://www.notion.com/help/category/security-and-privacy> | Práticas de segurança, privacidade, residência de dados, IPs |
| Notion AI security | <https://www.notion.com/help/category/notion-ai-security> | Como a IA trata os dados do workspace |
| Desktop, web & mobile | <https://www.notion.com/help/category/notion-apps> | Apps por plataforma, requisitos de sistema, widgets, Web Clipper |
| Notion Mail | <https://www.notion.com/help/category/notion-mail> | Cliente de e-mail do Notion |
| Notion Calendar | <https://www.notion.com/help/category/notion-calendar> | Calendário, integração com databases e Google Calendar |
| Marketplace & templates | <https://www.notion.com/help/category/template-gallery> | Galeria de templates, publicar e vender templates |
| Notion credits | <https://www.notion.com/help/category/notion-credits> | Créditos de IA/agentes: como funcionam e como comprar |
| Plans & billing | <https://www.notion.com/help/category/plans-billing-and-payment> | Planos, cobrança, trials, upgrade/downgrade |
| Troubleshoot | <https://www.notion.com/help/category/troubleshooting> | Problemas comuns, sync, performance, login |
| Developer tools | <https://www.notion.com/help/category/developer-platform> | Visão de produto sobre API, integrações e MCP |

---

## 2. Help Center — primeiros passos e editor

| Tópico | Link | O que tem lá |
|---|---|---|
| Crie sua primeira página | <https://www.notion.com/help/create-your-first-page> | Fluxo inicial: criar página, adicionar conteúdo, organizar |
| Escrita e edição | <https://www.notion.com/help/writing-and-editing-basics> | Comando `/`, tipos de bloco, arrastar, seleção múltipla, markdown inline |
| Personalizar e estilizar | <https://www.notion.com/help/customize-and-style-your-content> | Cores, ícones, capas, fontes, full width, callouts |
| Colunas, headings e divisores | <https://www.notion.com/help/columns-headings-and-dividers> | Layout em colunas, hierarquia de títulos, separadores |
| Synced blocks | <https://www.notion.com/help/synced-blocks> | Bloco espelhado entre páginas; como criar, desvincular, limitações |
| Atalhos de teclado | <https://www.notion.com/help/keyboard-shortcuts> | Lista completa por SO — markdown, seleção, navegação, blocos |

---

## 3. Help Center — databases

| Tópico | Link | O que tem lá |
|---|---|---|
| Intro a databases | <https://www.notion.com/help/intro-to-databases> | Conceito, database vs. página, inline vs. full page, primeiros passos |
| Propriedades | <https://www.notion.com/help/database-properties> | Todos os tipos de propriedade e o que cada um aceita |
| Relations & rollups | <https://www.notion.com/help/relations-and-rollups> | Ligar databases, relation de mão dupla, agregações de rollup |
| Intro a fórmulas | <https://www.notion.com/help/formulas> | Conceito, onde usar, exemplos práticos |
| Sintaxe e funções de fórmula | <https://www.notion.com/help/formula-syntax> | Referência completa de funções, operadores e tipos |
| Templates de database | <https://www.notion.com/help/database-templates> | Templates de item, template padrão, template por view |
| Sub-itens e dependências | <https://www.notion.com/help/tasks-and-dependencies> | Hierarquia de itens, dependências para timeline |
| Forms | <https://www.notion.com/help/forms> | Formulários que gravam em database: campos, lógica, compartilhamento |

---

## 4. Help Center — views e filtros

| Tópico | Link | O que tem lá |
|---|---|---|
| Views, filtros, sorts & grupos | <https://www.notion.com/help/views-filters-and-sorts> | Como criar views, filtrar, ordenar, agrupar, subgrupos |
| Table view | <https://www.notion.com/help/tables> | Tabela, colunas congeladas, agregações no rodapé |
| Board view | <https://www.notion.com/help/boards> | Kanban, agrupar por propriedade, drag & drop |
| Calendar view | <https://www.notion.com/help/calendars> | Visão de calendário por propriedade de data |
| Timeline view | <https://www.notion.com/help/timelines> | Gantt, dependências, zoom, barras por intervalo |
| Gallery view | <https://www.notion.com/help/galleries> | Cards com preview de capa ou conteúdo |
| Dashboards | <https://www.notion.com/help/dashboards> | Painéis com múltiplas views e métricas |
| Charts | <https://www.notion.com/help/charts> | Gráficos sobre dados de database |
| Qual view usar | <https://www.notion.com/help/guides/when-to-use-each-type-of-database-view> | Guia comparativo de quando cada tipo faz sentido |

---

## 5. Help Center — colaboração, workspace e teamspaces

| Tópico | Link | O que tem lá |
|---|---|---|
| Sharing & permissions | <https://www.notion.com/help/sharing-and-permissions> | Níveis de acesso, herança, link público, restrições |
| Membros, admins, guests e grupos | <https://www.notion.com/help/add-members-admins-guests-and-groups> | Papéis, convites, grupos de permissão, diferença guest vs. member |
| Teamspaces | <https://www.notion.com/help/browse-join-and-create-teamspaces> | Criar, entrar e sair; aberto/fechado/privado; owners |
| Workspaces | <https://www.notion.com/help/create-delete-and-switch-workspaces> | Criar, alternar e sair de workspaces |
| Configurações de workspace | <https://www.notion.com/help/workspace-settings> | Configurações gerais, identidade, domínio, exportação |
| Enterprise Search | <https://www.notion.com/help/enterprise-search> | Busca unificada sobre Notion e ferramentas conectadas |
| HIPAA | <https://www.notion.com/help/hipaa> | Configuração de workspace para conformidade HIPAA |
| Guia: wiki da empresa | <https://www.notion.com/help/guides/how-to-build-a-wiki-for-your-company> | Passo a passo de estruturar um wiki interno |

---

## 6. Help Center — automações e IA

| Tópico | Link | O que tem lá |
|---|---|---|
| Automações de database | <https://www.notion.com/help/database-automations> | Gatilhos, ações, quando dispara, limitações |
| Buttons | <https://www.notion.com/help/buttons> | Botão como bloco: ações encadeadas, confirmar, abrir página |
| Database buttons | <https://www.notion.com/help/database-buttons> | Propriedade de botão dentro de linhas |
| Webhook actions | <https://www.notion.com/help/webhook-actions> | Disparar HTTP a partir de automação; payload e headers |
| Notion AI — FAQ | <https://www.notion.com/help/notion-ai-faqs> | Perguntas frequentes: dados, limites, disponibilidade por plano |
| Notion AI (produto) | <https://www.notion.com/product/ai> | Página de produto: capacidades e posicionamento |

---

## 7. Help Center — sites, calendar, mail

| Tópico | Link | O que tem lá |
|---|---|---|
| Publicar uma página na web | <https://www.notion.com/help/public-pages-and-web-publishing> | Tornar página pública, indexação, permissões do link |
| Domínio customizado | <https://www.notion.com/help/connect-a-custom-domain-with-notion-sites> | Apontar domínio próprio, DNS, verificação |
| Notion Sites (produto) | <https://www.notion.com/product/sites> | Visão geral do produto de sites |
| Notion Calendar (produto) | <https://www.notion.com/product/calendar> | Visão geral; integração com Google Calendar e databases |
| Notion Mail (produto) | <https://www.notion.com/product/mail> | Visão geral do cliente de e-mail |

---

## 8. Help Center — importação, exportação e backup

| Tópico | Link | O que tem lá |
|---|---|---|
| Importar dados | <https://www.notion.com/help/import-data-into-notion> | Formatos suportados (Markdown, CSV, HTML, Evernote, Word) e limites |
| Exportar conteúdo | <https://www.notion.com/help/export-your-content> | Exportar página/workspace em Markdown, CSV, PDF, HTML |
| Backup | <https://www.notion.com/help/back-up-your-data> | Estratégias de backup e o que a exportação preserva |
| Importar do Confluence | <https://www.notion.com/help/import-from-confluence> | Migração de espaços e o que se perde no caminho |

---

## 9. Help Center — planos, billing e apps

| Tópico | Link | O que tem lá |
|---|---|---|
| Preços | <https://www.notion.com/pricing> | Planos atuais, preço por seat, o que cada plano inclui |
| Billing | <https://www.notion.com/help/billing> | Ciclo de cobrança, notas fiscais, métodos de pagamento |
| Mudar de plano | <https://www.notion.com/help/upgrade-or-downgrade-your-plan> | Upgrade, downgrade e proporcionalidade |
| Uso de blocos | <https://www.notion.com/help/understanding-block-usage> | O que conta como bloco no limite do plano gratuito |
| Notion para desktop | <https://www.notion.com/help/notion-for-desktop> | App desktop, atalhos, múltiplas janelas |
| Notion para mobile | <https://www.notion.com/help/notion-for-mobile> | App móvel, widgets, diferenças de recursos |
| Web Clipper | <https://www.notion.com/help/web-clipper> | Extensão para salvar páginas da web em databases |
| Requisitos de sistema | <https://www.notion.com/help/system-requirements-for-notion> | SOs e navegadores suportados, requisitos mínimos |

---

## 10. Help Center — segurança e privacidade

| Tópico | Link | O que tem lá |
|---|---|---|
| Práticas de segurança | <https://www.notion.com/help/security-and-privacy> | Criptografia, certificações, práticas de infraestrutura |
| Práticas de privacidade | <https://www.notion.com/help/privacy> | Tratamento de dados pessoais, GDPR |
| Residência de dados | <https://www.notion.com/help/data-residency> | Regiões disponíveis e como funciona |
| IPs e domínios | <https://www.notion.com/help/allowlist-ip> | Faixas para allowlist em firewall corporativo |
| Dados visíveis ao workspace owner | <https://www.notion.com/help/data-accessible-by-your-workspace-owner> | O que um admin consegue ver do conteúdo dos membros |
| Retenção de dados | <https://www.notion.com/help/guides/notions-data-retention-settings> | Configurações de retenção e restauração de conteúdo |

---

## 11. Help Center — plataforma de desenvolvedor (visão de produto)

| Tópico | Link | O que tem lá |
|---|---|---|
| Developer tools | <https://www.notion.com/help/category/developer-platform> | Panorama de API, integrações e MCP pela ótica do usuário |
| Criar integrações com a API | <https://www.notion.com/help/create-integrations-with-the-notion-api> | Passo a passo de criar integração pela UI |
| Gerenciar conexões da API | <https://www.notion.com/help/add-and-manage-connections-with-the-api> | **Como conectar a integração a uma página** — o passo que todo mundo esquece |

---

## 12. Developer Docs — fundamentos

| Tópico | Link | O que tem lá |
|---|---|---|
| Getting started | <https://developers.notion.com/docs/getting-started> | Primeiro request, conceitos, tour da plataforma |
| Overview (guia) | <https://developers.notion.com/guides/get-started/overview> | Visão geral da plataforma de desenvolvedor |
| Criar uma integração | <https://developers.notion.com/docs/create-a-notion-integration> | Tutorial completo do zero ao primeiro request |
| Introdução da referência | <https://developers.notion.com/reference/intro> | Convenções da API, base URL, formato de resposta |
| Autenticação | <https://developers.notion.com/reference/authentication> | Bearer token, headers obrigatórios |
| Authorization / OAuth | <https://developers.notion.com/docs/authorization> | Internal vs. public, fluxo OAuth, capabilities |
| Criar token OAuth | <https://developers.notion.com/reference/create-a-token> | `POST /v1/oauth/token`: params, Basic auth, refresh |
| **Versionamento** | <https://developers.notion.com/reference/versioning> | **Versão atual da API e o que mudou entre versões** |
| Limites de request | <https://developers.notion.com/reference/request-limits> | Rate limit, tamanho de payload, limites por tipo de propriedade |
| Status e códigos de erro | <https://developers.notion.com/reference/status-codes> | Tabela completa de erros e significado |
| Paginação | <https://developers.notion.com/reference/pagination> | `has_more`, `next_cursor`, `page_size` |
| Changelog | <https://developers.notion.com/page/changelog> | **Novidades e breaking changes por data — cheque aqui primeiro** |

---

## 13. Developer Docs — trabalhar com conteúdo

| Tópico | Link | O que tem lá |
|---|---|---|
| Conteúdo de página | <https://developers.notion.com/docs/working-with-page-content> | Árvore de blocos, `has_children`, travessia recursiva |
| Conteúdo de página (guia) | <https://developers.notion.com/guides/data-apis/working-with-page-content> | Versão em guia, com exemplos |
| Databases | <https://developers.notion.com/docs/working-with-databases> | Modelo database/data source, schema, criação |
| Databases (guia) | <https://developers.notion.com/guides/data-apis/working-with-databases> | Fluxos práticos de leitura e escrita |
| Arquivos e mídia | <https://developers.notion.com/guides/data-apis/working-with-files-and-media> | Upload, referência a arquivos, expiração de URL |
| Markdown | <https://developers.notion.com/guides/data-apis/working-with-markdown-content> | Notion-flavored markdown para ler/escrever sem montar blocos |
| Comentários | <https://developers.notion.com/docs/working-with-comments> | Modelo de discussão, criar e listar |
| Upgrade 2025-09-03 | <https://developers.notion.com/docs/upgrade-guide-2025-09-03> | Migração para o modelo database → data source |
| FAQ 2025-09-03 | <https://developers.notion.com/docs/upgrade-faqs-2025-09-03> | Dúvidas comuns da migração |

---

## 14. Developer Docs — objetos

| Objeto | Link | O que tem lá |
|---|---|---|
| Page | <https://developers.notion.com/reference/page> | Campos, parents possíveis, `in_trash`, ícone/capa |
| Block | <https://developers.notion.com/reference/block> | **Todos os tipos de bloco e quais são read-only/unsupported** |
| Database | <https://developers.notion.com/reference/database> | Container: título, ícone, `is_inline`, array `data_sources` |
| Data source | <https://developers.notion.com/reference/data-source> | Schema (`properties`), parent, título |
| User | <https://developers.notion.com/reference/user> | `person` vs. `bot`, campos de e-mail |
| Comment | <https://developers.notion.com/reference/comment-object> | Estrutura, `discussion_id`, anexos |
| Rich text | <https://developers.notion.com/reference/rich-text> | **Annotations, links, mentions, equation — leia antes de gerar texto** |
| Property (schema) | <https://developers.notion.com/reference/property-object> | Definição de cada tipo de propriedade no schema |
| Property values | <https://developers.notion.com/reference/page-property-values> | Formato do **valor** de cada tipo ao ler e escrever |
| Parent | <https://developers.notion.com/reference/parent-object> | Formas válidas de `parent` por objeto |
| File | <https://developers.notion.com/reference/file-object> | `file` vs. `external` vs. `file_upload`, expiração |
| Emoji | <https://developers.notion.com/reference/emoji-object> | Emoji e custom emoji em ícones |

---

## 15. Developer Docs — endpoints

| Endpoint | Link | O que tem lá |
|---|---|---|
| Criar page | <https://developers.notion.com/reference/post-page> | `POST /v1/pages`: parent, properties, children, markdown, template |
| Atualizar page | <https://developers.notion.com/reference/patch-page> | `PATCH /v1/pages/{id}`: propriedades, ícone, capa, `in_trash` |
| Ler page | <https://developers.notion.com/reference/retrieve-a-page> | `GET /v1/pages/{id}` |
| Ler uma propriedade | <https://developers.notion.com/reference/retrieve-a-page-property> | `property_item` paginado — necessário para relations/rollups grandes |
| Ler filhos de bloco | <https://developers.notion.com/reference/get-block-children> | `GET /v1/blocks/{id}/children` com paginação |
| Append de blocos | <https://developers.notion.com/reference/patch-block-children> | `PATCH .../children`: `children`, `position` |
| Ler bloco | <https://developers.notion.com/reference/retrieve-a-block> | `GET /v1/blocks/{id}` |
| Atualizar bloco | <https://developers.notion.com/reference/update-a-block> | `PATCH /v1/blocks/{id}` |
| Deletar bloco | <https://developers.notion.com/reference/delete-a-block> | `DELETE /v1/blocks/{id}` (vai para lixeira) |
| Criar database | <https://developers.notion.com/reference/create-a-database> | `POST /v1/databases` |
| Ler database | <https://developers.notion.com/reference/retrieve-a-database> | `GET /v1/databases/{id}` — **de onde sai o `data_source_id`** |
| Atualizar database | <https://developers.notion.com/reference/update-a-database> | Título, ícone, capa, mover |
| Criar data source | <https://developers.notion.com/reference/create-a-data-source> | `POST /v1/databases/{id}/data_sources` |
| Ler data source | <https://developers.notion.com/reference/retrieve-a-data-source> | Schema completo |
| Atualizar data source | <https://developers.notion.com/reference/update-a-data-source> | Alterar schema, nome, descrição |
| **Query data source** | <https://developers.notion.com/reference/query-a-data-source> | **Filtros, sorts, paginação, `filter_properties`, teto de 10.000** |
| Search | <https://developers.notion.com/reference/post-search> | `POST /v1/search`: só títulos; filtro `page`/`data_source` |
| Criar comentário | <https://developers.notion.com/reference/create-a-comment> | `POST /v1/comments`, `display_name`, anexos |
| Listar comentários | <https://developers.notion.com/reference/list-comments> | `GET /v1/comments?block_id=…` |
| Listar usuários | <https://developers.notion.com/reference/get-users> | `GET /v1/users` paginado |
| Ler usuário | <https://developers.notion.com/reference/get-user> | `GET /v1/users/{id}` |
| Bot token (self) | <https://developers.notion.com/reference/get-self> | `GET /v1/users/me` — o smoke test de token |
| File upload (objeto) | <https://developers.notion.com/reference/file-upload> | Estados: pending, uploaded, expired, failed |
| Criar file upload | <https://developers.notion.com/reference/create-a-file-upload> | Modos `single_part`, `multi_part`, `external_url` |
| Enviar file upload | <https://developers.notion.com/reference/send-a-file-upload> | Envio dos bytes em multipart |
| Completar file upload | <https://developers.notion.com/reference/complete-a-file-upload> | Finalização de upload multi-part |
| Listar file uploads | <https://developers.notion.com/reference/list-file-uploads> | Inventário de uploads da integração |
| Webhooks | <https://developers.notion.com/reference/webhooks> | Assinatura, verificação, configuração |
| Entrega de webhooks | <https://developers.notion.com/reference/webhooks-events-delivery> | Tipos de evento, retries, ordenação |
| Admin API | <https://developers.notion.com/reference/admin/intro> | Gestão de workspace em nível Enterprise |

---

## 16. Developer Docs — MCP

| Tópico | Link | O que tem lá |
|---|---|---|
| MCP — overview | <https://developers.notion.com/guides/mcp/overview> | O que é o Notion MCP e para que serve |
| MCP — docs | <https://developers.notion.com/docs/mcp> | Página de entrada do MCP na documentação |
| Começar com MCP | <https://developers.notion.com/guides/mcp/get-started-with-mcp> | **URL do servidor e setup para Claude Code, Claude Desktop, Cursor, VS Code** |
| Clientes MCP comuns | <https://developers.notion.com/guides/mcp/common-mcp-clients> | Instruções por cliente |
| Tools suportadas | <https://developers.notion.com/guides/mcp/mcp-supported-tools> | **Lista completa de tools e o que cada uma faz** |
| Construir cliente MCP | <https://developers.notion.com/guides/mcp/build-mcp-client> | Integrar o MCP em aplicação própria |
| Self-hosting do MCP | <https://developers.notion.com/guides/mcp/hosting-open-source-mcp> | Rodar o servidor open source localmente |
| Boas práticas de segurança | <https://developers.notion.com/guides/mcp/mcp-security-best-practices> | Riscos, escopo de acesso, prompt injection |

---

## 17. Ferramentas e SDKs

| Recurso | Link | O que tem lá |
|---|---|---|
| SDK JavaScript/TypeScript | <https://github.com/makenotion/notion-sdk-js> | `@notionhq/client`: tipos, helpers de paginação, retry, webhooks |
| MCP server (open source) | <https://github.com/makenotion/notion-mcp-server> | Código do servidor MCP para self-host |
| CLI — overview | <https://developers.notion.com/cli/get-started/overview> | O que a CLI oficial faz |
| CLI — instalação | <https://developers.notion.com/cli/get-started/installation> | Instalar e autenticar |
| Índice para LLMs | <https://developers.notion.com/llms.txt> | Lista canônica de URLs da doc — útil para descobrir páginas novas |

---

## 18. Recursos complementares

| Recurso | Link | O que tem lá |
|---|---|---|
| Template gallery | <https://www.notion.com/templates> | Templates oficiais e da comunidade; ponto de partida para estruturas |
| Guias por área | <https://www.notion.com/help/guides> | Guias por função: engenharia, produto, design, marketing, startup |
| Guias de engenharia | <https://www.notion.com/help/guides/category/engineering> | Roadmap, sprints, docs técnicos, incidentes |
| Guias de projeto | <https://www.notion.com/help/guides/category/project-management> | Projetos, tarefas, dependências, dashboards |
| Release notes | <https://www.notion.com/releases> | Novidades do produto por data |
| Blog | <https://www.notion.com/blog> | Anúncios, casos de uso, lançamentos |
| Status | <https://status.notion.so> | Incidentes e disponibilidade — cheque antes de debugar 5xx |
| Comunidade | <https://www.notion.com/community> | Fórum, embaixadores, eventos |

---

## 19. Onde olhar primeiro, por tipo de pergunta

| Pergunta | Comece por |
|---|---|
| "A API mudou? Qual a versão atual?" | <https://developers.notion.com/reference/versioning> e <https://developers.notion.com/page/changelog> |
| "Por que dá 404 se a página existe?" | <https://www.notion.com/help/add-and-manage-connections-with-the-api> |
| "Como filtro por essa propriedade?" | <https://developers.notion.com/reference/query-a-data-source> |
| "Qual o formato desse valor de propriedade?" | <https://developers.notion.com/reference/page-property-values> |
| "Consigo criar esse tipo de bloco?" | <https://developers.notion.com/reference/block> |
| "Quantos itens/blocos/KB posso mandar?" | <https://developers.notion.com/reference/request-limits> |
| "Como formato negrito/link/menção?" | <https://developers.notion.com/reference/rich-text> |
| "Que ferramentas o MCP tem?" | <https://developers.notion.com/guides/mcp/mcp-supported-tools> |
| "Como conecto o MCP no Claude Code?" | <https://developers.notion.com/guides/mcp/get-started-with-mcp> |
| "Como faço X na interface?" | Categoria correspondente na seção 1 |
| "Isso está disponível no meu plano?" | <https://www.notion.com/pricing> |
| "A API está fora do ar?" | <https://status.notion.so> |
