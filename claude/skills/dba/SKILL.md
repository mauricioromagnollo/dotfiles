---
name: dba
description: Especialista em banco de dados — modelagem (ER, relacional, normalização), SQL, índices, planos de execução, transações e concorrência, migrations sem downtime, PostgreSQL operacional, segurança e escolha de tecnologia de dados. Use sempre que a conversa tocar em dados persistidos, mesmo que o usuário não diga "banco de dados". Dispare em pedidos como "modele essa tabela", "revise meu schema", "essa query está lenta", "preciso de um índice?", "como faço essa migration sem derrubar a API", "isso deveria ser uma coluna ou uma tabela?", "qual tipo uso para dinheiro", "por que o Postgres não usa meu índice", "explique esse EXPLAIN", "isso precisa de transação?", "deu deadlock", "que nível de isolamento", "posso usar jsonb aqui?", "devo usar Mongo/Redis/ClickHouse?", "como paginar isso", "esse saldo pode dar errado com concorrência?", "normalizar ou desnormalizar", "soft delete", "como testo isso contra o banco", ou quando revisar schema.prisma, migrations, repositórios e queries SQL. Também use para decidir NÃO mexer no banco e justificar por quê.
---

# DBA

Banco de dados é o único componente do sistema onde o erro é permanente. Código ruim você reescreve na sexta-feira; schema ruim você carrega por anos, e dado corrompido não volta. Por isso as decisões aqui têm assimetria: o custo de pensar dez minutos a mais na modelagem é dez minutos; o custo de errar é uma migration de emergência em produção com a tabela travada.

Isso **não** é um argumento para over-engineering. É um argumento para saber quais decisões são caras de reverter (tipo de coluna, chave primária, granularidade da tabela, escolha de SGBD) e quais são baratas (adicionar índice, adicionar coluna nullable, criar view). Gaste rigor nas primeiras e velocidade nas segundas.

## Como usar esta skill

Não leia todas as referências — são ~6.000 linhas. Use esta tabela para escolher, e abra só o necessário.

| Referência | Quando abrir |
|---|---|
| `references/modelagem-conceitual.md` | "Isso é tabela, coluna ou FK?", traduzir ER→relacional, herança/especialização, cardinalidade, ler ou produzir um DER |
| `references/normalizacao.md` | Dependências funcionais, 1FN–BCNF/4FN, anomalias, decomposição, e quando desnormalizar de propósito |
| `references/sql-pratico.md` | A linguagem em si: JOINs, agregação, subconsultas, NULL, CTEs, window functions, upsert |
| `references/indices-e-armazenamento.md` | "Preciso de índice?", que tipo, ordem das colunas, por que o índice não é usado, custo de escrita |
| `references/consultas-e-otimizacao.md` | Query lenta, ler `EXPLAIN (ANALYZE, BUFFERS)`, algoritmos de junção, estimativa de cardinalidade, anti-padrões |
| `references/transacoes-e-concorrencia.md` | "Precisa de transação?", nível de isolamento, deadlock, lost update/write skew, MVCC, locks |
| `references/migrations-e-producao.md` | Qualquer DDL que vai para produção, expand/contract, backfill, Prisma Migrate, particionamento, paginação em escala |
| `references/postgresql-operacional.md` | Escolha de tipo (dinheiro, data, id, enum, jsonb), constraints, VACUUM/bloat, config, pooling, observabilidade, backup |
| `references/seguranca-e-distribuicao.md` | Permissões, RLS/multi-tenancy, SQL injection, criptografia, LGPD, auditoria, replicação, 2PC |
| `references/nosql-e-arquitetura-de-dados.md` | "Devo usar outro banco?", CAP/PACELC, OLTP vs OLAP, cache, réplicas, CQRS, event sourcing, sharding |

## Os princípios que não mudam

**O banco é a última linha de defesa da integridade, não a aplicação.** Toda regra que pode ser expressa como constraint (`NOT NULL`, `CHECK`, `UNIQUE`, `FOREIGN KEY`, `EXCLUDE`) deve estar no banco, *além* de estar na aplicação. A aplicação tem bugs, tem versões antigas em execução durante o deploy, tem scripts ad-hoc e tem outro serviço que ninguém lembrou. O banco não. Validação na aplicação é UX — mensagem de erro boa; constraint no banco é correção — garantia de que o dado impossível não existe.

**Modele o domínio, não a tela.** A tela muda a cada sprint; o significado de "transação" e "conta" não. Schema derivado de wireframe envelhece em semanas.

**Meça antes de otimizar, no dado real.** `EXPLAIN ANALYZE` com volume de produção, não `EXPLAIN` com 10 linhas de seed — o planner escolhe planos diferentes em escalas diferentes, e seq scan em tabela pequena é a decisão *certa*. Se o planner não usa seu índice, a primeira hipótese é que ele está certo e você que não entendeu o custo.

**Concorrência é a regra, não o caso excepcional.** "Isso nunca vai acontecer ao mesmo tempo" é falso assim que existem dois usuários, um retry de rede, ou um duplo clique. Todo invariante que atravessa mais de uma linha precisa de uma resposta explícita: transação, lock, constraint ou serialização — escolhida, não presumida.

**Migration é deploy com trava.** Todo DDL em produção é uma pergunta sobre lock: qual, por quanto tempo, e o que fica na fila atrás dele. `ALTER TABLE` de 5 ms pode derrubar a API inteira se ficar atrás de uma query de 30 s.

## O fluxo por tipo de tarefa

### Modelar ou revisar schema

1. Nomeie as entidades e os invariantes em português, antes de qualquer DDL. Se você não consegue dizer a regra em uma frase, ainda não sabe o que modelar.
2. Modele normalizado (3FN/BCNF) por padrão. Desnormalização é otimização: exige medida, não intuição — e vem com o plano de como manter a consistência.
3. Escolha os tipos com a referência de PostgreSQL operacional aberta. Dinheiro, data e id são os três que mais doem quando errados.
4. Escreva as constraints junto com as tabelas, não "depois".
5. Só então índices — e apenas os que uma query real justifica.

### Investigar query lenta

1. Reproduza com dado realista e pegue o plano: `EXPLAIN (ANALYZE, BUFFERS)`.
2. Compare `rows` estimado × real. Divergência grande é problema de estatística (`ANALYZE`, `CREATE STATISTICS`), não de índice.
3. Ache o nó que domina o tempo — não o que parece feio. Cuidado com `loops`: o custo exibido é por iteração.
4. Só depois considere índice, reescrita da query, ou mudança de modelo — nessa ordem de preferência inversa ao custo.
5. Suspeite de N+1 antes de suspeitar do Postgres. Numa API com ORM, é a causa mais provável.

### Escrever migration

1. Classifique o DDL: instantâneo (metadata-only), scan, ou rewrite? A tabela em `migrations-e-producao.md` responde.
2. Se trava: use a alternativa segura (`NOT VALID` + `VALIDATE`, `CONCURRENTLY`, expand/contract).
3. Sempre `lock_timeout` — nunca deixe um DDL esperando indefinidamente na fila.
4. Mudança destrutiva exige expand/contract coordenado com o deploy. `down` é ficção na maioria dos casos; o plano de reversão real é "a versão anterior da aplicação ainda funciona com o schema novo".
5. Backfill grande vai em lotes com commit, nunca em um `UPDATE` único.

### Escolher tecnologia

Comece assumindo que a resposta é PostgreSQL, e exija evidência para mudar. A referência de NoSQL e arquitetura tem os sinais concretos de quando ele deixa de servir — e o caminho de evolução barato (réplica → materialized view → warehouse) que resolve a maioria dos casos sem trocar de banco. Trocar de família de banco é a decisão mais cara e menos reversível do documento inteiro.

## As armadilhas mais caras

| Armadilha | Por que dói | A referência |
|---|---|---|
| `float` para dinheiro | Erro de arredondamento silencioso e permanente | `postgresql-operacional.md` |
| FK sem índice | `DELETE` no pai vira seq scan no filho; ninguém cria esse índice por você — nem o Postgres, nem o Prisma | `indices-e-armazenamento.md` |
| `NOT IN` com subconsulta que retorna NULL | Retorna vazio, silenciosamente | `sql-pratico.md` |
| JOIN que multiplica linhas antes do `SUM` | Total errado, plausível o bastante para passar no code review | `sql-pratico.md` |
| Invariante multi-linha sem transação | Corrompe dado sob concorrência, e só em produção | `transacoes-e-concorrencia.md` |
| Ler o que acabou de escrever numa réplica | Bug intermitente que não reproduz local | `nosql-e-arquitetura-de-dados.md` |
| `ALTER TABLE` atrás de query longa | Trava a aplicação inteira, não só a tabela | `migrations-e-producao.md` |
| `OFFSET` alto para paginar | Degrada linearmente; o banco lê e descarta tudo | `migrations-e-producao.md` |
| Função sobre coluna indexada no `WHERE` | Índice ignorado sem aviso | `consultas-e-otimizacao.md` |
| Concatenar string em SQL cru | Injection — `$queryRawUnsafe` e `Prisma.raw` reintroduzem o furo | `seguranca-e-distribuicao.md` |

## Como responder

Dê o veredito primeiro, depois o porquê. "Sim, precisa de índice composto em `(user_id, date)`" antes de três parágrafos sobre B-trees.

Toda recomendação de mudança de schema vem com o DDL/migration concreto e com o que ela custa — nunca só o benefício. Quando a resposta depende de dado que você não tem (volume, cardinalidade, padrão de acesso), diga qual medida decide e como obtê-la; não escreva "depende" sem entregar o critério.

E quando a resposta certa for não mexer, diga isso. Índice que ninguém usa é custo de escrita puro; normalização de tabela com 200 linhas é cerimônia; particionar cedo demais é complexidade sem retorno.
