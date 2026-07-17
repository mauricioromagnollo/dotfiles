# NoSQL e Arquitetura de Dados

Abra esta referência quando a pergunta for **"qual banco?"** ou **"como escalo isso?"** — não quando for "como modelo esta tabela?". Ela cobre escolha de tecnologia, teoria de consistência distribuída, modelagem NoSQL, a divisão OLTP/OLAP e padrões de dados distribuídos. Normalização, PostgreSQL operacional, migrations e índices são cobertos por outras referências.

A postura desta referência é **cética**. A maior parte das decisões de "precisamos de NoSQL / precisamos de sharding / precisamos de um data warehouse" é tomada por hype, por currículo, ou por um benchmark que não se parece com a sua carga. O antídoto é medir antes de migrar e saber qual preço cada família cobra.

---

## 0. A resposta padrão é PostgreSQL

Comece por aqui, sempre. Um PostgreSQL bem tunado em uma máquina única aguenta muito mais do que a intuição sugere:

- Vertical scaling + connection pooling (PgBouncer) resolvem a maioria das cargas **abaixo de ~500 GB**; abaixo de ~100 GB uma única instância cobre da fundação até Series A sem drama.
- Tuning bem feito costuma render **2–5x** antes de qualquer mudança arquitetural.
- Postgres hoje não é "só relacional": é JSONB (documento), pgvector (vetorial), TimescaleDB (série temporal), PostGIS (geoespacial), full-text search embutido, LISTEN/NOTIFY, logical replication (CDC), particionamento declarativo.

**Calibração para este projeto (finanças pessoais, Postgres + Prisma + Fastify + TypeScript):** você está a ordens de magnitude de qualquer limite que justifique trocar de família. Um app de finanças pessoais com dezenas de milhares de usuários e milhões de transactions é um dataset de poucos GB. As tabelas abaixo existem para você **reconhecer quando parar de aplicá-las**, não para justificar uma migração.

O ônus da prova é de quem quer sair do Postgres. A pergunta certa nunca é "o Mongo escala melhor?" — é **"qual limite concreto do Postgres eu bati, com qual número medido?"**. Se não há número, não há decisão; há hype.

### Quando "use PostgreSQL" deixa de ser a resposta certa

Sinais concretos, todos mensuráveis:

| Sinal | Limite aproximado | Para onde olhar |
|---|---|---|
| Volume de escrita excede o que um nó aguenta, mesmo com hardware topo | > dezenas de milhares de writes/s sustentados | Cassandra, sharding, NewSQL |
| Dataset quente não cabe em RAM de uma máquina grande e o I/O domina | > ~1–2 TB quente | Sharding, Citus, NewSQL |
| Query analítica varre centenas de milhões de linhas e o OLTP sofre junto | scans regulares > 10⁸ linhas | ClickHouse, BigQuery, warehouse |
| Requisito de escrita multi-região com baixa latência local | RTT entre regiões no caminho crítico | Spanner, CockroachDB, Yugabyte |
| Requisito de disponibilidade que sobrevive à perda de uma região inteira, sem failover manual | | Cassandra, DynamoDB, NewSQL |
| Busca full-text com relevância, facetas, fuzzy em escala | Postgres FTS já não dá conta da relevância | Elasticsearch/OpenSearch |
| Travessia de grafo com 4+ hops ou algoritmos (PageRank, comunidades) | recursive CTE fica impraticável | Neo4j |

Nenhum desses sinais é "o time acha que Postgres não escala".

---

## 1. Teoria que decide

### CAP: por que a leitura popular está errada

A leitura popular ("escolha 2 de 3: Consistency, Availability, Partition tolerance") é **errada e inútil**. Os problemas, seguindo a crítica formal de Martin Kleppmann (2015):

1. **Você não escolhe P.** Partições de rede acontecem; não são uma opção de design. Sobra escolher entre C e A *durante a partição* — que é raro.
2. **As definições são estritas e contra-intuitivas.** "Availability" no CAP significa: *toda requisição recebida por um nó não-falho deve retornar uma resposta não-erro*. Isso **ignora latência completamente** — um sistema que responde em 10 minutos é "available" pelo CAP, e inútil na prática. Não tem nada a ver com o uptime que você mede em SLO.
3. **O teorema foi provado para um modelo específico**: um único registrador read-write, com um único tipo de falha (partição total de rede). Não diz nada sobre transações multi-objeto, nem sobre nós lentos, GC pauses, relógios dessincronizados ou falhas parciais — que causam muito mais incidentes reais que partições limpas.
4. **A classificação binária não fecha.** Um banco com replicação single-leader não é CAP-available (se o cliente é particionado do leader, não escreve). Kleppmann mostra que sistemas podem ser **"apenas P"** — nem CP nem AP. O "dois de três" permite escolher um de três, ou nenhum.

> **Regra prática:** se alguém em um design doc justifica uma escolha de banco com "é AP, então é mais disponível", peça o número. CAP não sustenta essa inferência.

### PACELC: o modelo que serve

PACELC (Daniel Abadi) corrige a lacuna central: **CAP só descreve o comportamento durante a partição — o modo raro.** No modo normal, sem partição nenhuma, replicação ainda impõe um trade-off inescapável.

> **If Partition: A ou C — Else: L (latency) ou C (consistency)**

O eixo **ELC** é o que governa o seu p99 todo santo dia. Se você quer que uma leitura reflita a escrita mais recente em um sistema replicado, alguém paga um round-trip. Não existe consistência forte de graça em rede.

Classificações úteis (segundo a formulação PACELC):

- **PC/EC** — consistência acima de tudo, nos dois modos: Spanner, CockroachDB, VoltDB, Postgres com replicação síncrona.
- **PA/EL** — disponibilidade e latência acima de tudo: Cassandra, Dynamo/DynamoDB (com leituras eventualmente consistentes), Riak.
- **PA/EC** — cede em partição, mas prioriza consistência no dia a dia: MongoDB fica aqui, na leitura mais comum.
- **PC/EL** — cede latência em partição, mas prioriza latência normal: raro, ex. PNUTS.

O que importa: **os dois eixos são sintonizáveis por query na maioria dos bancos modernos.** No DynamoDB você escolhe leitura eventual (barata, rápida) ou strongly consistent (2x o custo, mais latência) por chamada. No Cassandra você escolhe o quórum. No Mongo, read/write concern. A decisão não é "que banco?", é "que garantia esta query precisa?".

### Os dois eixos de consistência (o erro conceitual mais caro)

Existem **duas hierarquias diferentes** que o vocabulário da indústria mistura, e a confusão custa dinheiro. Jepsen separa assim:

**Eixo 1 — Isolamento transacional (mundo dos RDBMS, transações multi-objeto):**
Serializable → Snapshot Isolation / Repeatable Read → Monotonic Atomic View → Cursor Stability → Read Committed → Read Uncommitted

**Eixo 2 — Consistência distribuída (mundo dos sistemas distribuídos, operação single-object):**
Linearizable → Sequential → Causal → PRAM / Writes Follow Reads → Monotonic Reads / Monotonic Writes

Eles são **famílias disjuntas**. Unificadas apenas no topo por **strict serializability** = serializability (eixo 1) + linearizability (eixo 2).

As definições que importam:

- **Linearizabilidade** — garantia de *recência* sobre um objeto. Toda leitura vê a escrita mais recente commitada; o sistema se comporta como se houvesse uma única cópia. Diz respeito a **tempo real**, não a transações.
- **Serializabilidade** — garantia de *isolamento* sobre transações. O resultado concorrente equivale a *alguma* ordem serial. Note: **não diz qual ordem.** Um banco serializável pode legalmente executar sua transação "no passado" e devolver dados velhos — serializabilidade sozinha não impede isso.
- **Snapshot isolation** — cada transação lê de um snapshot consistente. Mais barata que serializable, e permite **write skew**: duas transações leem o mesmo estado, escrevem objetos diferentes, e juntas violam um invariante que cada uma preservaria sozinha. É o default do Oracle e o `REPEATABLE READ` do Postgres. Clássico em finanças: duas retiradas concorrentes checam "saldo total ≥ 0" no mesmo snapshot e ambas passam.

> **Para este projeto:** aplicações financeiras têm invariantes multi-linha (saldo = soma de transactions, transferência entre contas). Write skew é uma ameaça real e silenciosa. `SERIALIZABLE` no Postgres (SSI) resolve — ao custo de retries em erro de serialização, que o app **precisa** tratar. Prisma não faz esse retry por você; o `isolationLevel` em `$transaction` configura o nível, mas o loop de retry é seu.

### Disponibilidade dos modelos (Jepsen)

Isto é um teorema, não uma opinião — e desmonta boa parte do marketing:

- **Totalmente disponíveis** (sobrevivem a qualquer partição, em rede assíncrona): monotonic reads, monotonic writes, read your writes, writes follow reads, **causal consistency**.
- **Sticky available** (disponíveis desde que o cliente fique no mesmo nó): read your writes e alguns modelos vizinhos.
- **Não podem ser totalmente disponíveis**: linearizability, sequential, strict serializable, serializable, **snapshot isolation, repeatable read, cursor stability e read committed**.

O detalhe que surpreende: **read committed — o default do Postgres — já é forte o suficiente para ser impossível de manter totalmente disponível sob partição.** "Consistência forte vs. eventual" não é um botão binário; é uma escada com degraus bem definidos, e a maior parte do que você usa já está bem acima do chão.

**Causal consistency é o ponto ótimo pouco explorado**: é o modelo mais forte que ainda é totalmente disponível. Se você precisa de disponibilidade sob partição, é o teto teórico — e cobre a maior parte da intuição do usuário ("eu vejo o que eu escrevi, e vejo as coisas na ordem em que aconteceram").

### O que Jepsen ensinou

Jepsen (Kyle Kingsbury / Aphyr) testa bancos sob falha e compara com o que o marketing promete. As lições transferíveis:

1. **Promessa não é garantia.** Muitos bancos que anunciam "strong consistency" e "ACID" não entregam sob teste. O MongoDB 4.2.6 anunciava "full ACID transactions" e "among the strongest data consistency guarantees of any database available today". Jepsen encontrou, **nos níveis mais fortes de read/write concern**, violações de snapshot isolation: read skew, fluxo cíclico de informação, escritas duplicadas e transações lendo suas próprias escritas futuras — **~10% das transações exibiram anomalias em operação normal, sem falha injetada**. (MongoDB identificou um bug no retry de transações e corrigiu na 4.2.8.)
2. **Defaults são inseguros e silenciosos.** No mesmo relatório: transações do MongoDB ignoravam as configurações de segurança definidas no nível do database/collection e revertiam para `readConcern: local` / `w: 1` — leituras não commitadas e perda de dados. Em versões anteriores, a causal consistency só funcionava com read **e** write concern `majority`, e a documentação não mencionava isso.
3. **A composição das garantias é contra-intuitiva.** `readConcern: snapshot` não dava snapshot isolation sem `writeConcern: majority` — mesmo em transações só de leitura.
4. **O valor está no relatório, não no selo.** Jepsen identifica não só *se* houve falha, mas *os passos que a causaram*. Ler o relatório do banco que você está avaliando vale mais que qualquer benchmark de vendor.

> **Como usar isto na decisão:** antes de adotar um banco distribuído, procure `jepsen.io/analyses/<banco>`. Se não existe análise, isso é um dado. Se existe, leia a seção "Discussion" — e cheque se os problemas foram corrigidos e em qual versão. Verifique também qual **default** o seu driver/ORM usa: a insegurança quase sempre mora ali.

### Quóruns

`R + W > N` garante que o conjunto de leitura e o de escrita se sobrepõem em ao menos um nó — logo a leitura vê a última escrita. Com N=3: W=2, R=2 é o balanço padrão; W=3,R=1 favorece leitura; W=1,R=3 favorece escrita.

O que a fórmula **não** te dá, e é onde as pessoas se enganam:

- Quórum de leitura/escrita **não** é linearizabilidade. Sem read-repair síncrono e sem cuidado com escritas concorrentes, dá para violar recência.
- Escritas concorrentes precisam de resolução de conflito: last-write-wins (**descarta dados silenciosamente**, e depende de relógios), vector clocks, ou CRDTs.
- Uma escrita que falha o quórum pode ter sido persistida em alguns nós. Não há rollback. O cliente vê erro; o dado pode estar lá.
- Sloppy quorum + hinted handoff (Dynamo, Cassandra) aumentam disponibilidade e **quebram** a garantia `R+W>N`.

---

## 2. Famílias de banco e o critério de escolha

| Família | Modelo de dados | Brilha em | Cobra o preço de | Sinal concreto de que você precisa |
|---|---|---|---|---|
| **Relacional** (Postgres, MySQL) | Tabelas, linhas, schema fixo, joins, ACID | Invariantes, queries ad-hoc, flexibilidade de acesso, transações multi-objeto | Escala de escrita limitada a um nó; joins ficam caros em escala extrema | É o default. Não precisa de sinal — precisa de sinal para **sair** |
| **Documento** (MongoDB) | Documentos BSON/JSON aninhados, schema flexível | Agregados que se leem e escrevem inteiros; schema heterogêneo/evolutivo | Sem joins baratos; invariantes cross-document são responsabilidade sua; defaults historicamente inseguros | Seu agregado é naturalmente uma árvore, sempre lida inteira, e nunca consultada de outro ângulo |
| **Chave-valor / cache** (Redis) | Chave → valor (string, hash, list, set, sorted set, stream) | Latência sub-ms, contadores, rate limiting, filas, locks, leaderboards, pub/sub | Durabilidade fraca; sem query por valor; dataset limitado a RAM | Latência de p99 de leitura dominada por dados quentes e repetidos |
| **Chave-valor gerenciado** (DynamoDB) | Partition key + sort key, itens | Escala horizontal previsível, latência estável, ops zero | Só as queries que você modelou; sem ad-hoc; lock-in; modelagem irreversível | Escala/ops que justificam abrir mão de query flexível, e access patterns *estáveis e conhecidos* |
| **Colunar / analítico** (ClickHouse, BigQuery, Redshift) | Colunas comprimidas, orientado a scan | Agregação sobre 10⁸–10¹² linhas em ms/s | Ruim em point update/delete e transações; não é OLTP | Query analítica varre a tabela inteira e degrada o OLTP junto |
| **Família de colunas** (Cassandra, ScyllaDB) | Partition key + clustering columns, wide rows | Escrita massiva, multi-região ativo-ativo, disponibilidade extrema | Uma tabela por query; sem join; tombstones; modelagem rígida | Escrita sustentada acima de um nó **e** requisito de sobreviver à perda de uma região |
| **Grafo** (Neo4j) | Nós + arestas, index-free adjacency | Travessia profunda (6+ hops), shortest path, PageRank, detecção de comunidade | Mais um sistema; escala horizontal difícil; ecossistema menor | Shortest path/algoritmos de grafo são a **feature principal**, não um detalhe |
| **Série temporal** (TimescaleDB, InfluxDB) | Métricas append-only indexadas por tempo | Ingestão contínua, retenção, downsampling, compressão temporal | Modelo especializado; menos flexível fora do eixo tempo | Ingestão append-only alta + queries sempre por janela de tempo + necessidade de retenção automática |
| **Busca** (Elasticsearch, OpenSearch) | Índice invertido, documentos | Full-text com relevância, fuzzy, facetas, autocomplete | **Não é source of truth**: ACID só por documento, sem transações, risco real de perda | Postgres FTS não entrega a relevância/facetas que o produto exige |
| **Vetorial** (pgvector, Pinecone, Qdrant) | Embeddings + ANN index (HNSW/IVFFlat) | Busca por similaridade semântica, RAG | Índice aproximado (recall < 100%); memória; custo | Busca semântica é requisito — e só saia do pgvector acima de dezenas de milhões de vetores |
| **NewSQL / distribuído** (CockroachDB, Yugabyte, Spanner, Vitess) | SQL relacional sobre consenso (Raft/Paxos) | SQL + ACID + escala horizontal + multi-região | Latência por consenso; custo; incompatibilidades sutis com Postgres; **ruim em OLAP** | Você bateu o teto de um nó **e** não pode abrir mão de SQL/ACID |

### Notas por família (o que o marketing omite)

**Documento (MongoDB).** O princípio real é *"data that's accessed together should be stored together"* — modelagem dirigida por access pattern, não por normalização. Limites duros que decidem o design: **documento máximo de 16 MiB**, 100 níveis de aninhamento, 64 índices por collection, transações com lifetime default de 60s. O padrão anti-escala clássico: array que cresce sem limite dentro de um documento (comentários, eventos, line items) — bate no teto de 16 MiB ou destrói a performance de update muito antes. Se o array cresce sem fim, é referência, não embedding. E: leia o relatório Jepsen da sua versão, cheque seus read/write concerns explicitamente.

**Redis.** Não é database of record. RDB (snapshot periódico) perde tudo desde o último snapshot em um crash. AOF com `appendfsync everysec` limita a perda a ~1s. A própria Redis diz que, para segurança comparável à do Postgres, use **os dois** — e ainda assim, se o dado só existe no Redis, você aceitou perder segundos de escrita. Use para o que ele é excelente: cache, rate limiting, locks, filas, contadores, sorted sets, streams.

**DynamoDB.** Os números que governam o design: **cada partição entrega no máximo 3.000 RCU/s e 1.000 WCU/s.** Um RCU = uma leitura strongly consistent (ou duas eventualmente consistentes) de item até 4 KB; um WCU = uma escrita de item até 1 KB. Adaptive capacity está ligado por default, é gratuito, é instantâneo desde 2019 e realoca throughput de partições frias para quentes — mas **não levanta o teto físico por partição**. Nenhuma capacidade no nível da tabela conserta uma hot partition; só o design da chave conserta. CloudWatch Contributor Insights mostra as chaves mais acessadas e mais throttled — é como se transforma "uma partição está quente" em "esta chave é o problema".

**ClickHouse.** É explicitamente OLAP: *"column-oriented DBMS for online analytical processing"*. A doc mostra 100 milhões de linhas processadas em ~92 ms lendo só as colunas necessárias. Contrasta com OLTP, que "lê e escreve poucas linhas por query". Não use para update/delete pontual, transações, ou escrita de linha única em alta frequência — insira em lotes.

**Cassandra.** Modelagem query-first levada ao extremo: **uma tabela por query**, denormalização obrigatória (todo dado da query tem que estar em uma tabela), o que traz write amplification e custo de storage. Partition key precisa de alta cardinalidade ou você cria hot spots. Tombstones: delete escreve um marcador que só some após compaction **e** `gc_grace_seconds` (default 10 dias) — cargas delete-heavy degradam a leitura porque o banco lê e descarta tombstones para achar dado vivo. Cassandra é para quem tem um problema de escrita e disponibilidade que Postgres não resolve. É uma minoria absoluta dos casos.

**Neo4j.** A diferença é arquitetural: index-free adjacency significa que cada nó guarda ponteiros para os vizinhos — travessia é pointer hop O(1), independente do tamanho total. No Postgres, cada hop é um join. Os números medidos são instrutivos e cortam para os dois lados: em **reachability de vizinhança, Postgres ganha ~4x**; em **shortest path, Neo4j ganha ~85–135x**. Até ~10K nós / 50K arestas, recursive CTE no Postgres é rápido, simples e já está lá. Neo4j entra quando algoritmos de grafo (PageRank, comunidades, weighted shortest path) são o produto.

**Elasticsearch.** Não é ACID: atomicidade só por documento, não por transação. Um bulk que decrementa um contador e incrementa outro pode ter metade aplicada. Sem backend, você tem risco real de perda. É índice derivado do source of truth, populado por CDC ou reindex. Se você perder o cluster inteiro, deve conseguir reconstruí-lo do Postgres — se não consegue, você o transformou em database de record sem querer.

**Vetorial.** pgvector é o default para quem já está no Postgres, confortavelmente até ~5M vetores com centenas de QPS, e razoável até ~10–50M. A vantagem decisiva não é performance: é que **filtro + similaridade viram uma única query SQL** (filtre por user_id, tipo, intervalo de datas, então ranqueie por similaridade). Pinecone entra em centenas de milhões a bilhões de vetores com ops zero. Comece com pgvector.

**NewSQL.** CockroachDB entrega `SERIALIZABLE` por default via Raft + MVCC, fala protocolo/dialeto Postgres, e cita ~2ms para leitura de linha única e ~4ms para escrita — em multi-região, o RTT entre regiões afeta diretamente a performance. A doc é honesta sobre o limite: **"CockroachDB is not yet suitable for heavy analytics / OLAP"** e "alguns recursos [do Postgres] podem exigir esforço manual para portar". Não é um drop-in do Postgres, e não substitui um warehouse.

---

## 3. Modelagem NoSQL: o inverso da relacional

A inversão em uma frase:

> **Relacional:** modele os *dados* (uma verdade, normalizada), e as queries se viram depois — o planner acha um caminho.
> **NoSQL:** modele as *queries* (elas são o requisito), e os dados se organizam para servi-las — não há planner para te salvar.

Consequências:

**Agregado é a unidade.** Você desenha unidades que são lidas e escritas juntas, e faz a fronteira do agregado coincidir com a fronteira da transação. Dentro do agregado: atomicidade. Fora: eventual consistency e trabalho seu.

**Desnormalização é o padrão, não a exceção.** Se a query precisa do nome do usuário junto da transaction, o nome vai junto — duplicado. O preço: toda atualização de nome precisa varrer e atualizar cópias, você fica responsável pela consistência, e o storage cresce. Você trocou *integridade garantida pelo banco* por *latência de leitura*. Essa troca só compensa se a leitura for o gargalo real.

**Single-table design (DynamoDB).** Todas as entidades em uma tabela, com PK/SK genéricos, formando *item collections* — itens de tipos diferentes compartilhando a mesma partition key, recuperáveis em **uma** Query. Existe porque o DynamoDB removeu joins deliberadamente (não escalam em alta velocidade), e sem joins você precisaria de requisições em cascata. Single-table troca essa cascata por uma query.

O preço, na palavra do próprio Alex DeBrie:
- **Curva de aprendizado íngreme** — a estrutura contradiz tudo que você aprendeu em relacional.
- **Inflexibilidade de access pattern** — uma query nova pode exigir ETL caro para reestruturar dados.
- **Analytics vira sofrimento** — o design "twisted pretzel" com nomes de chave genéricos torna exportar e reportar difícil.

Quando **não** usar single-table:
- **Produto em estágio inicial**: agilidade vale mais que performance, e access patterns ainda mudam. Cada pivot torna sua estrutura de chave errada.
- **Sem expertise no time**: exige disciplina contínua; sem alguém que entenda de verdade, gente adiciona entidades sem entender a estrutura e ninguém consegue revisar mudança de schema.
- **Requisitos de reporting relevantes**: DynamoDB é genuinamente ruim em query ad-hoc e agregação; single-table piora.
- **Caso simples**: 4 entidades e 5 access patterns não pedem um schema elegante — pedem 4 tabelas que qualquer engenheiro entende em 5 minutos.

**Partition key e hot partition.** A partition key define distribuição. Escolha errada = uma partição recebe tráfego desproporcional e você bate em 3.000 RCU/1.000 WCU **mesmo com capacidade de tabela sobrando**. Antipadrões: chave de baixa cardinalidade (`status`, `tenant_id` com um tenant gigante), chave temporal sequencial (todo tráfego de hoje na partição de hoje). Mitigações: alta cardinalidade por design; **write sharding** (sufixo `#0..#N` na chave, espalhando escrita — ao custo de precisar de N queries paralelas na leitura); time bucketing; cache; buffering.

**Por que é uma aposta de difícil reversão.** No Postgres, uma query nova é um `CREATE INDEX` — minutos, reversível, e o dado não muda de forma. No DynamoDB/Cassandra, uma query nova que a sua chave não serve pede um GSI (nem sempre resolve), uma tabela nova, ou **um backfill/ETL de toda a base**. Você escolheu as queries antes de ter certeza de quais seriam. Em um produto que ainda descobre o que é, essa é a aposta errada — e é por isso que a maior parte dos casos deveria ficar em relacional.

> **Para este projeto:** finanças pessoais tem access patterns que **mudam** (todo relatório novo é um ângulo novo sobre os mesmos dados: por categoria, por mês, por conta, por tag, por comerciante). Isso é o oposto do perfil que single-table serve. Postgres + índices é a arquitetura certa, e não por acaso.

---

## 4. OLTP vs OLAP

### Por que linha vs. coluna muda tudo

**Row store:** os campos de uma linha ficam contíguos. Buscar/alterar um registro inteiro é uma leitura. Ótimo para "pegue a transaction 123" e para escrever/commitar rápido. É o que OLTP precisa: point queries de baixa latência, muitos usuários concorrentes, commits rápidos.

**Column store:** os valores de uma coluna ficam contíguos. `SUM(amount) WHERE date BETWEEN ...` lê **só** as colunas `amount` e `date` — o resto do disco nem é tocado. Três efeitos que se compõem:

1. **Menos I/O** — só as colunas da query são lidas.
2. **Compressão muito melhor** — valores do mesmo tipo e domínio, adjacentes, comprimem em ordens de magnitude melhores que linhas heterogêneas. Menos bytes = menos I/O.
3. **Vetorização** — a CPU aplica a mesma operação a muitos valores da coluna de uma vez (SIMD).

O custo simétrico: o column store é ruim em OLTP. Montar e desmontar linhas para operações que tocam poucas colunas vira gargalo. Update/delete pontual é caro ou não suportado.

**A regra:** OLTP lê e escreve poucas linhas por query; OLAP processa bilhões. São cargas antagônicas. Um sistema otimizado para uma é ruim na outra — e é por isso que a divisão existe, não por moda.

### Quando o Postgres deixa de servir para analytics

Não é volume absoluto; é a combinação:
- Queries analíticas fazem seq scan de dezenas/centenas de milhões de linhas **regularmente**.
- Elas competem por buffer cache e I/O com o OLTP, e o p99 transacional degrada.
- Dashboards levam dezenas de segundos e índice nenhum resolve (agregação sobre a tabela inteira é o requisito, não um acidente).

Antes de concluir isso, esgote: índices corretos, `BRIN` em colunas temporais, particionamento por range de data, materialized views, `work_mem` adequado.

### O caminho de evolução (siga na ordem; a maioria para no degrau 2)

1. **Índice + materialized view.** Custo ~zero. Refresh agendado. Resolve dashboard de finanças pessoais quase sempre.
2. **Read replica.** Isola a carga analítica do OLTP. Uma linha de infra. Aceite lag.
3. **Extensão colunar no próprio Postgres.** TimescaleDB (compressão colunar + continuous aggregates), Citus, DuckDB lendo Parquet. Ainda um sistema, ainda SQL.
4. **Warehouse de verdade** (ClickHouse, BigQuery, Redshift/Snowflake), carregado por ETL batch (dbt + cron).
5. **CDC / streaming** (Debezium → Kafka → warehouse). Near-real-time. Só quando "dados de ontem" comprovadamente não bastam — este degrau é caro em operação.

> **Para este projeto:** o degrau 1 cobre. Um app de finanças pessoais tem, por usuário, milhares de transactions — não bilhões. Materialized view refreshada de hora em hora, ou agregação em tabela mantida por trigger/job, resolve todo dashboard. Se alguém propuser Kafka + ClickHouse aqui, o custo é real e o benefício é zero.

### Warehouse vs. data lake vs. lakehouse

- **Data warehouse** — dado estruturado, schema-on-write, modelado e limpo antes de entrar. Query rápida, governança boa, ingestão rígida.
- **Data lake** — arquivos brutos (Parquet, JSON) em object storage, schema-on-read. Barato e flexível; sem disciplina vira *data swamp* — dado que ninguém sabe o que é nem confia.
- **Lakehouse** — arquivos abertos em object storage + camada de metadados transacional (Delta Lake, Iceberg, Hudi) que traz ACID, time travel e schema evolution. Tenta juntar o custo do lake com a confiabilidade do warehouse.

Nada disso é relevante abaixo de terabytes. Um "data lake" com 10 GB é uma pasta com arquivos e uma reunião mensal sobre governança.

### Star schema e dimensional modeling (Kimball) — o essencial

Criado por Ralph Kimball nos anos 90 e ainda o padrão para analytics, porque modela dados do jeito que o negócio pensa.

- **Fact table** — os eventos/medidas: numérica, alta cardinalidade, cresce sem parar. Colunas: chaves estrangeiras para dimensões + medidas aditivas. Ex: `fact_transaction(date_key, account_key, category_key, amount)`.
- **Dimension table** — o contexto descritivo: quem, o quê, quando, onde. Baixa cardinalidade, larga, **desnormalizada de propósito**. Ex: `dim_category(category_key, name, group, type)`.
- **Star schema** — a fact no centro, dimensões ao redor. Snowflake schema normaliza as dimensões — geralmente não vale: mais joins, sem ganho relevante.
- **Grain** — a decisão mais importante: o que **uma linha** da fact representa. Declare antes de qualquer coisa. Errar o grain invalida o modelo inteiro.
- **Slowly Changing Dimensions** — o que fazer quando o atributo muda. Tipo 1: sobrescreve (perde histórico). Tipo 2: nova linha versionada (preserva histórico — o mais usado). Em finanças, se uma categoria é renomeada, você quer relatórios antigos com o nome antigo ou o novo? Essa é a pergunta que SCD responde.

A desnormalização controlada aqui é **escolha deliberada de design**: menos joins, query mais rápida, schema navegável por analista. Arquiteturas modernas costumam misturar — camada core normalizada ou lakehouse, com marts dimensionais e modelos semânticos por cima.

---

## 5. Padrões de dados distribuídos

### Sharding — o último recurso

Sharding particiona dados por uma shard key entre nós independentes. O que você perde, tudo de uma vez:

- **Joins cross-shard** — ou impossíveis, ou lentos, ou reimplementados na aplicação.
- **Transações cross-shard** — precisam de 2PC ou saga.
- **Constraints globais** — `UNIQUE` em email exige coordenação ou uma tabela de lookup separada.
- **Rebalanceamento** — mudar a shard key é um projeto, não um deploy.
- **Auto-increment global**, agregações globais, `ORDER BY` global: tudo vira problema.

Esgote, nesta ordem: tuning de query e índices → vertical scaling → connection pooling (PgBouncer) → read replicas → particionamento **dentro** de um nó → arquivar dado frio → só então sharding (ou NewSQL, que faz isso por você ao custo de latência de consenso). Sharding quando connection pooling bastaria é complexidade pura. Case a estratégia com o gargalo **medido**.

Sinais de que você realmente saiu do vertical: contagem de conexões passando de 200 com tail latency crescendo (→ pooling), VACUUM não acompanhando com dead tuples > 5% semana a semana (→ particionamento/arquitetura), tempo de resposta subindo 20%+ mês a mês apesar do tuning.

### Read replicas e lag — o bug clássico

O bug: usuário salva uma transaction, o app redireciona para a lista, a leitura vai para a replica que ainda não aplicou o WAL, e a transaction **não está lá**. O usuário salva de novo. Agora você tem duas.

Isso não é bug de replica — é ausência de **read-your-writes**. Soluções, da mais simples à mais cara:

1. **Sticky to primary** — depois de um write, leia do primary por um TTL (1–3s, > lag típico). Marque com uma hot key no Redis (`user:{id}:recent_write`). Cru, confiável, barato de entregar. **É o que 95% dos apps deveriam fazer.**
2. **Roteamento lag-aware** — meça o lag da replica e só roteie para as que estão abaixo de um limiar.
3. **Fencing por LSN/GTID** — o cliente guarda o LSN do seu write; a leitura espera a replica aplicar até aquele LSN. Correto e mais caro de implementar.
4. **Replicação síncrona** — lag zero, mas todo write paga um round-trip e uma replica lenta deixa todos os writes lentos.
5. **Roteamento seletivo** — replica só para dados que o usuário não acabou de escrever (feeds, relatórios, listagens públicas).

> **Para este projeto:** replica de leitura só se justifica quando a carga analítica atrapalhar o OLTP. Antes disso, é um sistema a mais e uma classe de bug a mais, de graça.

### Cache-aside e invalidação

O padrão: leitura → busca no cache → miss → busca no banco → popula o cache. Escrita → **invalida** a chave.

O que vale saber:

- **Invalide, não atualize.** No write, faça `DEL`, não `SET`. `SET` cria race condition: duas escritas concorrentes podem gravar no cache na ordem inversa da que gravaram no banco, e o cache fica permanentemente errado. `DEL` faz o próximo leitor repopular do banco.
- **Write-through reintroduz o dual-write problem** — escrever no banco e no cache separadamente permite que um suceda e o outro falhe.
- **A janela de inconsistência é inescapável** — existe um intervalo entre o commit no banco e a invalidação. Cache-aside básico resolve a metade fácil; a metade difícil é invalidação, stampede e dado velho.
- **Stampede/thundering herd** — a chave expira, mil requisições vão ao banco juntas. Mitigue com TTL + refresh probabilístico antecipado, ou lock de repopulação.
- **Invalidação em cascata** — um write que afeta várias chaves pede invalidação por tag, ou **chaves versionadas**: em vez de deletar, incremente uma versão (`user:{id}:v{n}:balance`) e todas as leituras futuras vão para um namespace novo.
- **TTL curto é a melhor invalidação.** Se 30s de dado velho é aceitável, use TTL de 30s e pule a complexidade inteira.

### CQRS

Separar o modelo de escrita do modelo de leitura. Útil quando os dois têm formas genuinamente diferentes (escrita normalizada com invariantes; leitura desnormalizada para dashboard). Custa: dois modelos, sincronização, eventual consistency visível ao usuário.

**Não** precisa de event sourcing. Uma materialized view já é CQRS. Comece por ela.

### Event sourcing

Armazene os *eventos* como fonte da verdade; o estado atual é uma projeção. Auditoria perfeita, time travel, capacidade de reconstruir qualquer leitura.

O consenso honesto sobre quando **não** usar: domínio ou regras de negócio simples, onde um CRUD e acesso direto a dados bastam. O overhead de complexidade é substancial e a curva de aprendizado do time atrasa o desenvolvimento inicial.

Os custos que aparecem depois:
- **Versionamento de eventos te morde se você não planejar do dia 1.** Adicionar um campo pode quebrar o rebuild de projeções, exigindo estratégias de versionamento e funções de upcasting.
- **Manutenção de projeção** — cold start de rebuild de projeções grandes é doloroso.
- **Eventual consistency** entre write e read model vira problema de UX.

Vale em domínios com regras complexas, requisito de auditoria, ou padrões de query em evolução — **sistemas financeiros são o caso natural**.

> **Para este projeto:** o domínio é financeiro, o que é o caso de uso canônico — mas "finanças pessoais" é CRUD sobre transactions, não um ledger de banco com regulação. O ganho de auditoria você obtém com uma tabela de append-only history e triggers, a 5% do custo. Um ledger imutável (`INSERT`-only, correção por lançamento de estorno, nunca `UPDATE`/`DELETE`) captura o essencial do event sourcing sem a máquina toda. Se um dia o requisito de auditoria endurecer, você já está com a forma certa.

### Outbox pattern

Resolve o **dual-write problem**: você precisa atualizar o banco *e* publicar uma mensagem atomicamente, e não pode. Ou o banco commita e o publish falha (evento perdido), ou o publish vai e o banco falha (evento fantasma), ou o processo morre no meio (estado parcial).

A solução: escreva o evento em uma tabela `outbox` **na mesma transação local** do dado. Se a transação commita, o evento está lá; se aborta, nada acontece. Um processo separado — Debezium fazendo CDC no log, ou um poller — lê a outbox e publica. Entrega garantida sem 2PC.

CDC via log tem vantagens sobre polling: é leve (não executa query no banco), não tem lógica de polling para manter, e o log **preserva a ordem exata em que as transações commitaram**. Eventos chegam ao Kafka em milissegundos após o commit.

Note que é **at-least-once**: o consumidor tem que ser idempotente.

> **Para este projeto:** vale conhecer no dia em que existir um webhook ou um job externo que precisa disparar após uma transaction. A versão sem Kafka — tabela `outbox` + um worker que faz poll e marca como processado — é honesta, resolve o problema, e cabe em Fastify + Prisma. Não precisa de Debezium para isso.

### Saga e transações distribuídas

**2PC** é ACID, mas: exige locks entre serviços, cria ponto único de falha no coordenator, derruba a disponibilidade ao nível do participante mais fraco, e não escala. NoSQL geralmente nem suporta.

**Saga** decompõe a transação distribuída em transações locais, cada uma com uma **compensação**. Se o passo 3 falha, execute as compensações de 2 e 1 na ordem inversa.

O que exige rigor:
- Compensações precisam ser **idempotentes e retryable** — sem isso, você depende de intervenção manual.
- **Não há rollback, há compensação.** Estados intermediários são visíveis. Se você reservou saldo e depois compensou, alguém pode ter visto o saldo reservado.
- Compensar nem sempre é possível (email enviado não volta). Ordene os passos para que os irreversíveis fiquem por último.
- Orquestração (um coordenador explícito) é mais fácil de depurar; coreografia (cada serviço reage a eventos) acopla menos e vira um pesadelo de rastreamento acima de 4–5 passos.

> **Para este projeto:** monólito com um Postgres = `BEGIN`/`COMMIT` cobre tudo. Saga é o preço de ter distribuído o que não precisava ser distribuído. A melhor saga é a transação local que você não fragmentou.

### Idempotência

O fundamento de todo o resto. Rede não te dá exactly-once; te dá at-least-once, e você constrói o efeito exactly-once com idempotência.

- **Idempotency key** fornecida pelo cliente, com `UNIQUE` no banco. Retry com a mesma chave devolve o resultado original em vez de duplicar.
- Um `UNIQUE constraint` **é** um mecanismo de idempotência — e o mais barato que existe.
- Consumidores de eventos: guarde `processed_event_id` e ignore repetidos.
- Prefira operações naturalmente idempotentes (`SET status = 'paid'`) a não-idempotentes (`balance = balance - 100`).

> **Para este projeto:** um `POST /transactions` que o usuário dá double-click, ou que o mobile faz retry em rede ruim, cria transactions duplicadas — e num app de finanças, saldo errado é *o* bug que destrói a confiança. Idempotency key + `UNIQUE` é barato e você deveria ter agora, independentemente de qualquer coisa nesta referência.

---

## 6. Polyglot persistence: maturidade ou dívida?

**Maturidade** quando: cada banco resolve um problema **medido** que o principal não resolve; existe um source of truth **único e inequívoco**; os demais são **derivados e reconstrutíveis** a partir dele; o time tem capacidade operacional para cada um.

**Dívida** quando: foi escolhido por currículo, hype ou um benchmark que não parece com a sua carga; não há source of truth claro e dois sistemas discordam sem árbitro; o time não sabe operar um deles (backup, monitoring, patch, upgrade, DR drill); a sincronização é feita por dual write na aplicação.

Os custos que ninguém coloca no design doc:

- **TCO** — cada banco tem licenciamento, hosting, manutenção, e exige **expertise mantida** no time.
- **Dívida operacional composta** — cada novo banco pede estratégia de backup, pipeline de monitoring, patches de segurança, caminho de upgrade e *drills* de disaster recovery. Time diluído não mantém esse rigor, e a dívida acumula juros compostos.
- **Fault tolerance vira a do elo mais fraco** — se uma query global precisa de todos os bancos no ar, a disponibilidade da aplicação é o produto das disponibilidades. Três sistemas com 99,9% não dão 99,9%.
- **Ripple effect** — uma mudança de requisito atravessa todos os sistemas de uma vez.

**A regra da derivação:** todo banco secundário deve ser reconstruível a partir do primário por um comando que você já rodou. Elasticsearch reconstruível por reindex do Postgres é derivado saudável. Elasticsearch com dado que só existe lá é um database de record acidental, sem ACID, e um incidente esperando data.

**A heurística de custo:** cada banco novo custa, no mínimo, um on-call que sabe operá-lo, um runbook, um backup testado e um DR drill. Se você não vai pagar isso, não adicione o banco. "Vamos só usar pra uma coisinha" é como toda dívida operacional começa.

> **Para este projeto:** o segundo sistema legítimo, se e quando a carga pedir, é **Redis para cache e rate limiting** — problema real, escopo pequeno, dado descartável por definição, risco baixo. O terceiro (search, warehouse, fila dedicada) exige um número que ainda não existe. Postgres já é multi-modelo: JSONB, pgvector, full-text, particionamento, LISTEN/NOTIFY. Use o Postgres que você já opera antes de comprar um sistema que você não opera.

---

## Checklist de decisão

Antes de aprovar qualquer "precisamos do banco X":

1. **Qual número medido** mostra que o Postgres não serve? (Sem número: rejeite.)
2. **Você esgotou** índice, query tuning, vertical scaling, pooling, materialized view, particionamento, replica?
3. **Qual garantia** essa query precisa de verdade — linearizável, serializável, snapshot, causal, eventual? (Provavelmente mais fraca do que você supõe.)
4. **Qual o preço** que a família cobra, e você aceita conscientemente? (Volte à tabela.)
5. **Os access patterns são estáveis?** Se não, não escolha uma tecnologia que exige congelá-los.
6. **É reversível?** Quanto custa voltar em 6 meses? (NoSQL query-first: caro. Cache: grátis.)
7. **Existe relatório Jepsen** para essa versão? O que ele diz? Quais são os **defaults** do seu driver?
8. **Quem opera** isso às 3h da manhã, e existe runbook, backup testado e DR drill?
9. **Qual é o source of truth**, e o novo sistema é reconstruível a partir dele?

Se as respostas forem "acho que", "o pessoal falou que", ou "está no roadmap deles" — a decisão é: **fique no Postgres e volte quando tiver o número.**

---

## Fontes

- Martin Kleppmann, "Please stop calling databases CP or AP" — https://martin.kleppmann.com/2015/05/11/please-stop-calling-databases-cp-or-ap.html
- Martin Kleppmann, "A Critique of the CAP Theorem" — https://martin.kleppmann.com/2015/09/17/critique-of-the-cap-theorem.html
- Jepsen, Consistency Models — https://jepsen.io/consistency/models
- Jepsen, MongoDB 4.2.6 — https://jepsen.io/analyses/mongodb-4.2.6
- PACELC design principle (Wikipedia / Abadi) — https://en.wikipedia.org/wiki/PACELC_design_principle
- Marc Brooker, "CAP and PACELC: Thinking More Clearly About Consistency" — https://brooker.co.za/blog/2014/07/16/pacelc.html
- AWS, "Best practices for designing and using partition keys effectively in DynamoDB" — https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/bp-partition-key-design.html
- AWS Database Blog, "Scaling DynamoDB: partitions, hot keys, and split for heat" (Partes 2 e 3) — https://aws.amazon.com/blogs/database/part-3-scaling-dynamodb-how-partitions-hot-keys-and-split-for-heat-impact-performance/
- Alex DeBrie, "The What, Why, and When of Single-Table Design with DynamoDB" — https://www.alexdebrie.com/posts/dynamodb-single-table/
- AWS Database Blog, "Single-table vs. multi-table design in Amazon DynamoDB" — https://aws.amazon.com/blogs/database/single-table-vs-multi-table-design-in-amazon-dynamodb/
- MongoDB, Data Modeling — https://www.mongodb.com/docs/manual/data-modeling/
- MongoDB, Limits and Thresholds — https://www.mongodb.com/docs/manual/reference/limits/
- ClickHouse, "What is ClickHouse?" — https://clickhouse.com/docs/en/intro
- Apache Cassandra, Data Modeling — https://cassandra.apache.org/doc/latest/cassandra/developing/data-modeling/intro.html
- DataStax, "Best practices for data modeling in Cassandra-based databases" — https://docs.datastax.com/en/cql/hcd/data-modeling/best-practices.html
- Redis, Persistence — https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/
- Redis, "Three Ways to Maintain Cache Consistency" — https://redis.io/blog/three-ways-to-maintain-cache-consistency/
- Redis, Cache-Aside Pattern — https://redis.antirez.com/fundamental/cache-aside.html
- CockroachDB, Frequently Asked Questions — https://www.cockroachlabs.com/docs/stable/frequently-asked-questions
- Kimball Group, "Star Schema OLAP Cube" — https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/star-schema-olap-cube/
- Microsoft Learn, "Understand star schema and the importance for Power BI" — https://learn.microsoft.com/en-us/power-bi/guidance/star-schema
- Microsoft Learn, CQRS Pattern — https://learn.microsoft.com/en-us/azure/architecture/patterns/cqrs
- Microsoft Learn, Saga Design Pattern — https://learn.microsoft.com/en-us/azure/architecture/patterns/saga
- Thorben Janssen, "Implementing the Outbox Pattern with CDC and Debezium" — https://thorben-janssen.com/outbox-pattern-with-cdc-and-debezium/
- Bonsai, "Why Elasticsearch should not be your Primary Data Store" — https://bonsai.io/blog/why-elasticsearch-should-not-be-your-primary-data-store/
- BigData Boutique, "Using Elasticsearch or OpenSearch as Your Primary Datastore" — https://bigdataboutique.com/blog/using-elasticsearch-or-opensearch-as-your-primary-datastore-1e5178
- Tiger Data, "pgvector vs. Pinecone: Vector Database Comparison" — https://www.tigerdata.com/blog/pgvector-vs-pinecone
- VeloDB, "7 Ways to Scale PostgreSQL in 2026 (When Each One Breaks)" — https://www.velodb.io/glossary/ways-to-scale-postgresql
- Pedro Alonso, "When Does a Knowledge Graph Beat Vector Search — and When Do You Actually Need Neo4j?" — https://www.pedroalonso.net/blog/graphrag-vs-vector-postgres/
- Ashraf Mageed, "Lessons from the Trenches: CQRS, Event Sourcing, and the Cost of Tooling Constraints" — https://www.ashrafmageed.com/cqrs-eventsourcing-and-the-cost-of-tooling-constraints/
- "Polyglot Persistence — Usage and Challenges" (Barman & Joshi) — https://urfjournals.org/open-access/polyglot-persistence-usage-and-challenges.pdf
- TeamStation, "The Polyglot Persistence Fallacy: Stack Dilution Risks" — https://articles.teamstation.dev/the-polyglot-persistence-fallacy-stack-dilution-risks-in-distributed-architectures/
