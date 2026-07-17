# Segurança e Distribuição de Banco de Dados

Abra esta referência quando precisar decidir **quem pode ver o quê** num banco relacional (permissões, multi-tenancy, PII, auditoria), quando estiver avaliando **defesa contra SQL injection**, quando for escolher **criptografia e gestão de chaves**, ou quando a discussão envolver **fragmentar, replicar ou distribuir** dados por mais de um nó (incluindo 2PC, réplicas de leitura e sharding). Base teórica: Elmasri & Navathe, capítulos 24 (segurança) e 25 (bancos de dados distribuídos). Tudo marcado como "Nota prática:" é complemento fora do livro, voltado a PostgreSQL + Prisma.

---

## 1. O modelo mental: quatro medidas de controle

O livro organiza segurança de banco em quatro medidas de controle, e vale usar essa taxonomia como checklist de cobertura (Elmasri, cap. 24.1.2):

| Medida | Contra o quê | Ferramenta típica no PostgreSQL |
|---|---|---|
| Controle de acesso | Acesso não autorizado ao sistema/objeto | `GRANT`/`REVOKE`, roles, RLS |
| Controle de inferência | Deduzir dado individual a partir de agregados | limite de cardinalidade, ruído, particionamento |
| Controle de fluxo | Informação vazar de nível alto para baixo | classificação/rótulos, canais secretos |
| Criptografia | Dados interceptados ou roubados fisicamente | TLS, TDE/LUKS, `pgcrypto` |

As três propriedades ameaçadas são **integridade** (modificação imprópria), **disponibilidade** e **confidencialidade** (Elmasri, cap. 24.1.1). Repare que disponibilidade está na lista: derrubar o banco é falha de segurança, não só de infra.

**Critério de decisão:** a maioria dos projetos precisa de controle de acesso + criptografia bem feitos e ignora inferência e fluxo. Correto para um app de finanças pessoais **exceto** se você expuser endpoints agregados sobre a base inteira (§6).

**Segurança vs. precisão** (Elmasri, cap. 24.1.5): **segurança** é expor só o não sensível e rejeitar qualquer consulta que toque campo sensível; **precisão** é proteger exatamente o subconjunto sensível e expor o máximo do resto. O ideal — segurança perfeita com precisão máxima — não existe; ganhar precisão custa risco. Toda decisão de "libera essa coluna pro suporte?" é uma escolha nesse eixo.

**Segurança vs. privacidade** (Elmasri, cap. 24.1.6): segurança é a tecnologia que garante que o dado está protegido; privacidade é a capacidade do indivíduo de controlar os termos sob os quais sua informação é adquirida e usada. Segurança é pré-requisito necessário — e insuficiente — para privacidade.

---

## 2. Controle de acesso discricionário (DAC)

O modelo padrão de SGBD relacional: privilégios concedidos e revogados, num **modelo de matriz de acesso** onde linhas são sujeitos (usuários, contas, programas) e colunas são objetos (relações, colunas, visões, operações) (Elmasri, cap. 24.2.1).

Dois níveis:
- **Nível de conta:** `CREATE SCHEMA`, `CREATE TABLE`, `CREATE VIEW`, `ALTER`, `DROP` — capacidades da conta, independentes de qualquer tabela. Não padronizados na SQL2; ficam a cargo do implementador.
- **Nível de relação:** `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `REFERENCES` sobre tabelas e visões. `INSERT` e `UPDATE` podem ser restritos a **colunas específicas**; `SELECT` e `DELETE` não (para restringir colunas em leitura, o mecanismo é a visão).

Toda relação tem uma **conta proprietária** — normalmente quem a criou — que recebe todos os privilégios automaticamente, incluindo a `GRANT OPTION` (Elmasri, cap. 24.2.1).

```sql
CREATE SCHEMA financeiro AUTHORIZATION owner_app;

GRANT SELECT, INSERT ON financeiro.transacoes TO servico_importacao;
GRANT UPDATE (categoria_id, descricao) ON financeiro.transacoes TO servico_categorizacao;
-- servico_categorizacao NÃO pode mexer em valor_centavos nem em conta_id.
```

O `UPDATE` por coluna é a peça mais subutilizada do DAC. Um serviço de categorização automática precisa reescrever `categoria_id` e nada mais — dar-lhe `UPDATE` na tabela inteira é regalar a capacidade de reescrever valores monetários.

### Propagação e revogação em cascata

Se A concede a B **com** `GRANT OPTION` (`GRANT SELECT ON t TO analista WITH GRANT OPTION`), B pode repassar — e privilégios se propagam sem o conhecimento do proprietário. A regra que morde: quando A revoga de B um privilégio que B propagou, **o sistema revoga automaticamente tudo que B propagou com base nele** (Elmasri, cap. 24.2.4). O SGBD precisa rastrear a origem de cada concessão.

Sutileza: um usuário pode receber o mesmo privilégio de **duas fontes**. Se A2 e A3 concederam `UPDATE` a A4 e A2 revoga, A4 **continua** com o privilégio via A3; só perde quando A3 também revogar. Ou seja, `REVOKE` não é garantia de remoção — você precisa conhecer todos os caminhos de concessão.

**Nota prática:** no PostgreSQL, `REVOKE ... CASCADE` é obrigatório se houver dependentes. Audite caminhos com `information_schema.role_table_grants` (colunas `grantee`, `grantor`, `is_grantable`).

**Critério de decisão sobre `GRANT OPTION`:** não use. Em sistema gerenciado por migrations, a concessão deve ser declarativa e centralizada no código de migração; `GRANT OPTION` cria concessões que existem só no estado do banco, invisíveis no repositório, e cuja revogação cascateia. O livro descreve limites de **propagação horizontal** (quantas contas B pode conceder) e **vertical** (profundidade da cadeia) que resolveriam isso, mas nota que **não estão implementados em SQL nem na maioria dos SGBDs** (Elmasri, cap. 24.2.6).

### Visões como mecanismo de segurança

O mecanismo de visões é, por si só, um mecanismo de autorização discricionário (Elmasri, cap. 24.2.2). Se A quer que B veja só algumas colunas ou linhas de R, cria uma visão sobre R e concede `SELECT` só nela. Para criar a visão, a conta precisa de `SELECT` em todas as relações envolvidas.

```sql
-- Analista vê agregados por categoria, nunca a transação individual nem o usuário.
CREATE VIEW financeiro.gastos_por_categoria AS
SELECT c.nome AS categoria, date_trunc('month', t.ocorrida_em) AS mes,
       sum(t.valor_centavos) AS total_centavos, count(*) AS qtd
FROM financeiro.transacoes t
JOIN financeiro.categorias c ON c.id = t.categoria_id
GROUP BY 1, 2;

REVOKE ALL ON financeiro.transacoes FROM analista;
GRANT SELECT ON financeiro.gastos_por_categoria TO analista;
```

**Trade-off:** visões são o mecanismo certo para **restringir colunas em leitura** (já que `SELECT` não é column-specific) e para **encapsular regras de projeção**. São o mecanismo errado para multi-tenancy por usuário — você precisaria de uma visão por tenant, ou de uma parametrizada por `current_user`, que é RLS mal-feito. Para linha-a-linha, use RLS (§4). Cuidado: visões nem sempre são atualizáveis, e é por isso que `UPDATE`/`INSERT` ganharam a opção de especificar colunas da tabela base (Elmasri, cap. 24.2.5).

---

## 3. Controle de acesso obrigatório (MAC) e Bell-LaPadula

DAC é **tudo-ou-nada**: o usuário tem ou não tem o privilégio. Quando a política exige classificar dados e usuários em níveis, entra o MAC (Elmasri, cap. 24.3). Classes típicas: `TS > S > C > U`, possivelmente num reticulado. O modelo **Bell-LaPadula** classifica cada sujeito S e objeto O e impõe duas restrições:

1. **Propriedade de segurança simples** (*no read up*): S só lê O se `classe(S) ≥ classe(O)`.
2. **Propriedade estrela** (*no write down*): S só grava em O se `classe(S) ≤ classe(O)`.

A segunda é a contra-intuitiva e a mais importante: impede que um usuário TS copie um objeto TS e o regrave como objeto U, visível a todos — ou seja, impede o **fluxo de informação de nível alto para baixo**.

No modelo relacional multinível, cada atributo A ganha um atributo de classificação C, e a tupla ganha um `TC` (classificação da tupla) = o maior dos C dentro dela. Duas consequências (Elmasri, cap. 24.3):

- **Filtragem:** um usuário de nível C vendo tupla com atributos S recebe `NULL` naqueles atributos.
- **Poli-instanciação:** quando um usuário de nível baixo atualiza atributo cujo valor real está classificado acima dele, o sistema **não pode rejeitar** — rejeitar revelaria a existência do valor (um canal secreto). Cria-se uma segunda tupla com a mesma chave aparente no nível baixo: a mesma chave passa a ter uma versão por nível de autorização.

### DAC vs. MAC — o critério

| | DAC | MAC |
|---|---|---|
| Flexibilidade | Alta, serve a muitos domínios | Baixa, exige classificação estrita |
| Vulnerabilidade | Cavalo de Troia: não controla o que acontece **depois** do acesso autorizado | Impede fluxo ilegal por construção |
| Onde se aplica | Praticamente tudo comercial | Militar, governo, inteligência |

Conclusão direta do livro: **a maioria dos SGBDs comerciais oferece apenas DAC**, e na prática as políticas discricionárias são preferidas por equilibrarem melhor segurança e aplicabilidade (Elmasri, cap. 24.3, 24.3.1).

**Nota prática:** não implemente Bell-LaPadula num app de finanças pessoais. O valor de estudá-lo é o *no write down* — o argumento formal de por que um processo que leu dado sensível não deve poder escrever num destino menos protegido. Aplicação real: o worker que lê `transacoes` **não** deve ter `INSERT` em tabela de log público nem em cache exposto. É a propriedade estrela em roupagem de arquitetura.

### RBAC — papéis

RBAC (Elmasri, cap. 24.3.2) associa privilégios a **papéis organizacionais**, não a usuários; usuários recebem papéis (`CREATE ROLE`/`DESTROY ROLE`, com os mesmos `GRANT`/`REVOKE`). Conceitos que importam:

- **Hierarquia de papéis:** ordem parcial (reflexiva, transitiva, antissimétrica); sênior herda júnior. Implementada papel-a-papel: `GRANT ROLE tempo_integral TO funcionario_tipo1`.
- **Separação de tarefas / exclusão mútua:** impede que um usuário sozinho faça trabalho que exige duas pessoas (anti-conluio). **Estática** (os dois papéis não podem ser atribuídos ao mesmo usuário) ou **dinâmica** (atribuídos, mas não ativados na mesma sessão).
- **Sessões:** o usuário ativa um subconjunto dos papéis que possui; cada sessão mapeia para um único sujeito.

O livro é explícito: RBAC inclui as capacidades de DAC e MAC e é o modelo desejável para aplicações Web.

**Nota prática — PostgreSQL: roles vs. users.** **Não existe distinção real**: `CREATE USER` é açúcar para `CREATE ROLE ... WITH LOGIN`, e há um catálogo único (`pg_roles`). A convenção que funciona: **role de grupo** (`NOLOGIN`) carrega os privilégios — é o "papel" do RBAC; **role de login** (`LOGIN`) é a identidade que conecta e só herda.

```sql
CREATE ROLE app_leitura NOLOGIN;
CREATE ROLE app_escrita NOLOGIN;

GRANT USAGE ON SCHEMA financeiro TO app_leitura;
GRANT SELECT ON ALL TABLES IN SCHEMA financeiro TO app_leitura;
GRANT app_leitura TO app_escrita;              -- hierarquia: escrita herda leitura
GRANT INSERT, UPDATE, DELETE ON financeiro.transacoes TO app_escrita;

CREATE ROLE api_prod LOGIN PASSWORD '...' IN ROLE app_escrita;  -- identidade, só herda

-- GRANT ... ON ALL TABLES é snapshot: NÃO pega tabelas futuras.
ALTER DEFAULT PRIVILEGES IN SCHEMA financeiro GRANT SELECT ON TABLES TO app_leitura;
```

Exclusão mútua dinâmica no PostgreSQL: `SET ROLE` troca o papel ativo, e roles `NOINHERIT` só ganham o privilégio via `SET ROLE` explícito — é o mais próximo da "ativação de papel por sessão" do RBAC.

### O princípio do menor privilégio para a aplicação

**Nota prática — o ponto mais importante desta referência.** O usuário que a aplicação usa em runtime **não deve ser owner das tabelas e jamais superuser**. Justificativa direta do livro: o proprietário recebe **todos** os privilégios sobre a relação automaticamente (Elmasri, cap. 24.2.1) — se a app é owner, `GRANT`/`REVOKE` são teatro e a app pode `DROP TABLE`. Pior: **o owner burla RLS por padrão** (§4).

```sql
CREATE ROLE owner_app NOLOGIN;                 -- dono do schema; só migrations
CREATE ROLE migrator LOGIN PASSWORD '...' IN ROLE owner_app;
CREATE ROLE api_prod LOGIN PASSWORD '...' IN ROLE app_escrita;  -- runtime, sem DDL

ALTER SCHEMA financeiro OWNER TO owner_app;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;    -- endureça o default
REVOKE ALL ON DATABASE financas FROM PUBLIC;
```

Duas URLs: `MIGRATION_DATABASE_URL` (migrator, só no deploy — usada pelo `prisma migrate deploy`) e `DATABASE_URL` (api_prod, runtime — usada pelo `PrismaClient`). Ganho: uma injection bem-sucedida não consegue `DROP TABLE` nem ler outros schemas; o blast radius fica confinado ao que `app_escrita` pode fazer.

---

## 4. Segurança em nível de linha (row-level / label-based)

O livro descreve **controle de acesso em nível de linha**: cada linha recebe um **rótulo** com sua sensibilidade (numa coluna extra acrescentada pela política); o usuário recebe um rótulo de sessão; a política é avaliada automaticamente a cada consulta e determina quais linhas retornam. Linha sem rótulo explícito herda o rótulo de sessão do usuário (Elmasri, cap. 24.3.3).

Duas afirmações do livro que são critério de decisão:

1. **Os requisitos de rótulo são aplicados *em cima* dos requisitos do DAC.** O usuário passa primeiro no DAC (autorizado à operação no schema) e **depois** no rótulo. RLS não substitui `GRANT`; empilha sobre ele.
2. **"Na maioria das aplicações, somente algumas das tabelas precisam de segurança baseada em rótulo. Para a maioria das tabelas da aplicação, a proteção fornecida pelo DAC é suficiente."** (Elmasri, cap. 24.3.3)

A implementação de referência é a do Oracle (VPD + Label Security): a função de política retorna um **predicado (uma cláusula `WHERE`)** anexado ao comando SQL do usuário, de forma transparente à aplicação; a ordem de avaliação é DAC → predicado VPD → checagem de rótulo por linha (Elmasri, cap. 24.10.1-2). Guarde o mecanismo — **é literalmente o que o RLS do PostgreSQL faz**.

**Nota prática — RLS no PostgreSQL para multi-tenancy por usuário.** É o caso de uso canônico num app de finanças pessoais: cada usuário só enxerga suas contas e transações.

```sql
ALTER TABLE financeiro.transacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE financeiro.transacoes FORCE ROW LEVEL SECURITY;  -- aplica até ao owner

CREATE POLICY tenant_isolation ON financeiro.transacoes
  USING (usuario_id = current_setting('app.usuario_id', true)::uuid)
  WITH CHECK (usuario_id = current_setting('app.usuario_id', true)::uuid);
```

`USING` filtra o que é **lido** (e o alvo de `UPDATE`/`DELETE`). `WITH CHECK` valida o que é **escrito** — sem ele, o usuário insere linhas com `usuario_id` alheio que depois nem consegue ver. É o *no write down* da propriedade estrela em miniatura.

Três armadilhas que derrubam RLS na prática:

1. **`FORCE ROW LEVEL SECURITY` é obrigatório se a app conectar como owner.** Sem ele, o owner **ignora** todas as políticas silenciosamente. É o argumento operacional que fecha o §3: a app não ser owner não é higiene abstrata — é o que impede o RLS de virar decoração.
2. **`BYPASSRLS` e superuser ignoram políticas.** Confira com `SELECT rolname, rolsuper, rolbypassrls FROM pg_roles;`
3. **O `current_setting` precisa ser setado na mesma transação/conexão** — pooling vaza contexto entre requisições se você errar isso.

Com Prisma, o padrão seguro é uma transação interativa que seta o contexto:

```ts
export function comTenant<T>(usuarioId: string, fn: (tx: Prisma.TransactionClient) => Promise<T>) {
  return prisma.$transaction(async (tx) => {
    // set_config com is_local = true: escopo da transação, some no COMMIT/ROLLBACK.
    await tx.$executeRaw`SELECT set_config('app.usuario_id', ${usuarioId}::text, true)`;
    return fn(tx);
  });
}
```

`is_local = true` é o detalhe que impede vazamento entre requisições no pool: o setting morre com a transação.

**Quando RLS é a ferramenta certa:**

| Situação | Use RLS? |
|---|---|
| Multi-tenancy por usuário em base compartilhada | **Sim.** Defesa em profundidade contra um `where` esquecido no ORM. |
| Só um app confiável no banco, com testes bons | Talvez. Ainda pega o bug humano; custa latência e debug. |
| Múltiplos consumidores (API, BI, jobs, notebooks) | **Sim, sem discussão.** Só o banco impõe a regra a todos. |
| Isolamento entre empresas com regulação forte | Considere banco/schema separado: RLS é política, schema é fronteira. |
| Restringir **colunas** (esconder CPF do suporte) | **Não.** Visão + `GRANT` por coluna. |

**Trade-off honesto:** RLS anexa predicado a **toda** consulta, inclusive as que o planejador otimizaria melhor sem ele, e políticas com subquery degradam planos seriamente. Mitigue mantendo o predicado sobre coluna indexada da própria tabela (`usuario_id`), nunca com `EXISTS` em outra tabela no caminho quente. E rode `EXPLAIN` sob o role da aplicação, não como superuser — o plano é diferente.

---

## 5. SQL injection

Uma das ameaças mais comuns a um sistema de banco de dados (Elmasri, cap. 24.4). O livro contextualiza junto de outros ataques: **escalada de privilégio não autorizada** (usuário não autorizado explora vulnerabilidade), **abuso de privilégio** (usuário legítimo usa seu privilégio para o que não deve — o admin que altera notas), **negação de serviço** e **autenticação fraca**.

### Os três métodos descritos (Elmasri, cap. 24.4.1)

**1. Manipulação de SQL** — o mais comum. Altera um comando existente, tipicamente acrescentando condições ao `WHERE` ou expandindo com `UNION`/`INTERSECT`/`MINUS`. O exemplo clássico é o login: o pretendido `... WHERE nomeusuario='jaque' AND senha='senhajaque'` vira `... WHERE nomeusuario='jaque' AND (senha='x' OR 'x'='x')`, e quem sabe um login válido entra sem a senha.

**2. Injeção de código** — acrescenta comandos SQL *adicionais* à instrução existente, explorando processamento de dados inválidos, para alterar o curso de execução.

**3. Injeção de chamada de função** — insere função do banco ou chamada de SO numa instrução vulnerável. O exemplo do livro usa `TRANSLATE` no Oracle com `UTL_HTTP.REQUEST` concatenado, fazendo o servidor de banco emitir requisição HTTP ao atacante e exfiltrar dados. O livro nota que **consultas construídas dinamicamente em tempo de execução são o alvo** e que até instruções triviais podem ser vulneráveis.

**Riscos** (Elmasri, cap. 24.4.2): fingerprinting do banco (descobrir o SGBD para usar ataques específicos), negação de serviço, **contornar autenticação**, **identificar parâmetros injetáveis** (facilitado por páginas de erro excessivamente descritivas), executar comandos remotos e escalada de privilégio.

### Defesas (Elmasri, cap. 24.4.3)

O livro lista três, e a hierarquia entre elas é o ponto.

**1. Variáveis de ligação (bind variables / comandos parametrizados) — a defesa correta.** Explícito no livro: "Em vez de embutir a entrada do usuário na instrução, ela deverá ser vinculada a um parâmetro." Protege contra injeção **e melhora o desempenho** (plano reaproveitado). Por que é categoricamente diferente das outras: o parâmetro nunca é texto de comando — o SQL é parseado **antes** do valor chegar, então o valor não pode virar sintaxe. Não há string a escapar porque não há concatenação.

**2. Filtragem/validação de entrada — a defesa errada.** A técnica é trocar aspa simples por duas aspas via `Replace`. O livro a descarta na mesma frase em que a descreve: "como pode haver um grande número de caracteres de escape, essa técnica **não é confiável**."

O argumento vale internalizar, porque reaparece toda vez que alguém propõe um "sanitizador": você tenta enumerar o conjunto de entradas maliciosas (blacklist), e esse conjunto é aberto — muda com encoding, versão do SGBD, charset, função aplicada depois. Bind parameters não enumeram nada; mudam a categoria do dado de "código" para "valor". Sanitizar é apostar que você pensou em tudo; parametrizar torna a pergunta irrelevante.

**3. Segurança de função:** restringir funções padrão e customizadas do banco, exploráveis na injeção de chamada de função.

**Nota prática — Node/TypeScript com Prisma.** A defesa real, na ordem:

```ts
// SEGURO — query tipada. Prisma sempre parametriza. Padrão absoluto.
await prisma.transacao.findMany({ where: { usuarioId, valorCentavos: { gt: minimo } } });

// SEGURO — $queryRaw como TEMPLATE TAG: o ${} vira placeholder $1, não concatenação.
const linhas = await prisma.$queryRaw<Linha[]>`
  SELECT categoria_id, sum(valor_centavos) AS total FROM financeiro.transacoes
  WHERE usuario_id = ${usuarioId}::uuid AND ocorrida_em >= ${inicio}
  GROUP BY categoria_id`;

// FURO — $queryRawUnsafe com concatenação. É exatamente o ataque do livro.
await prisma.$queryRawUnsafe(`SELECT * FROM transacoes WHERE usuario_id = '${usuarioId}'`);

// FURO SUTIL — template tag "correta" com string montada antes. O tipo mente.
const filtro = `usuario_id = '${input}'`;
await prisma.$queryRaw`SELECT * FROM transacoes WHERE ${Prisma.raw(filtro)}`;
```

Três regras:

1. **A distinção não é `$queryRaw` vs. query tipada — é template tag vs. concatenação.** `` prisma.$queryRaw`...${x}...` `` é seguro porque a template tag entrega os valores separados do texto: Prisma emite `$1` e passa o valor no protocolo. `$queryRawUnsafe(str)` recebe string já montada e não tem como distinguir dado de código. O nome `Unsafe` é literal.
2. **`Prisma.raw()` e `Prisma.sql` reintroduzem o furo** com input do usuário. Use `Prisma.raw` só com literais do seu código (nome de tabela, direção de `ORDER BY`); para identificadores dinâmicos, valide contra **allowlist** fechada, nunca blacklist:

```ts
const COLUNAS_ORDENAVEIS = { data: 'ocorrida_em', valor: 'valor_centavos' } as const;
const coluna = COLUNAS_ORDENAVEIS[entrada as keyof typeof COLUNAS_ORDENAVEIS];
if (!coluna) throw new Error('coluna inválida');  // agora é literal do seu código
```

Isso é necessário porque **identificadores não podem ser bind parameters** — nenhum banco aceita `ORDER BY $1`. Allowlist é a única saída, e funciona por ser fechada por construção (o inverso do sanitizador).
3. **Defesa em profundidade fecha a conta.** Menor privilégio (§3) limita o que uma injeção alcança; RLS (§4) limita quais linhas retorna. Se `api_prod` não tem DDL nem `BYPASSRLS`, os riscos de "executar comandos remotos" e "escalada de privilégio" (Elmasri, cap. 24.4.2) esbarram no §3 e no §4.

Sobre **fingerprinting e páginas de erro descritivas** (Elmasri, cap. 24.4.2): não vaze erro do banco ao cliente. Prisma vaza — `P2002` traz nome de constraint, erros de `$queryRaw` trazem a mensagem do PostgreSQL. Mapeie para erros de domínio na borda e logue o original.

---

## 6. Bancos de dados estatísticos e controle de inferência

Cenário: usuários obtêm **estatísticas sobre populações** (`COUNT`, `SUM`, `MIN`, `MAX`, `AVG`, `STDDEV`) mas não dados individuais. Uma **população** é o conjunto de tuplas que satisfaz uma condição de seleção (Elmasri, cap. 24.5).

O ataque não precisa de nenhuma falha de acesso. Você quer a renda de Jane Silva, e sabe que ela tem Ph.D. e mora em Santo André: rode `C1: SELECT COUNT(*) FROM PESSOA WHERE escolaridade='Ph.D.' AND sexo='F' AND cidade='Santo Andre'`; se der 1, rode `C2: SELECT AVG(renda) FROM PESSOA WHERE <mesma condição>` — a média de uma pessoa é a renda dela. E mesmo que `C1` retorne 2 ou 3, `MAX`/`MIN`/`AVG` cercam o intervalo. Todas as consultas são legítimas; a violação emerge da **combinação**.

Contramedidas (Elmasri, cap. 24.5): **limite mínimo de cardinalidade** (rejeitar consulta cuja população esteja abaixo de um limiar); **proibir sequências** de consultas que referenciam repetidamente a mesma população; **ruído deliberado** nos resultados; **particionamento** (registros em grupos de tamanho mínimo; consultas referenciam grupos inteiros, nunca subconjuntos). O livro liga isso ao fator "garantia de autenticidade": **o sistema pode rastrear consultas anteriores** para garantir que uma combinação não revele o confidencial (Elmasri, cap. 24.1.5).

**Nota prática:** relevante assim que o app expuser benchmark ("você gasta 20% mais que a média da sua faixa"). Com poucos usuários por segmento, o agregado **é** o dado individual. Critério mínimo: só publique agregado com `COUNT(*) >= k` (k-anonimato, k tipicamente 5-20). E cuidado com filtros compostos que fatiam a população até k=1: o segmento é o produto da granularidade dos filtros, então limite os filtros, não só o k.

```sql
CREATE VIEW financeiro.benchmark_categoria AS
SELECT categoria_id, faixa_renda,
       avg(total_centavos) AS media_centavos,
       count(*) AS n
FROM financeiro.gastos_mensais_por_usuario
GROUP BY categoria_id, faixa_renda
HAVING count(*) >= 20;  -- o HAVING é o controle de inferência
```

---

## 7. Controle de fluxo e canais secretos

**Controle de fluxo** regula a distribuição de informação entre objetos acessíveis: um fluxo de X para Y ocorre quando um programa lê X e grava em Y, e só é permitido se a classe do receptor for **pelo menos tão privilegiada** quanto a do emissor (Elmasri, cap. 24.6). Distingue-se **fluxo explícito** (`Y := f(X)`) de **implícito** (`if f(X) then Y := ...` — Y vaza informação sobre X sem receber X).

Um **canal secreto** viola a política, tipicamente transferindo de classificação alta para baixa. Duas categorias (cap. 24.6.1): **de armazenamento** (informação transmitida acessando informação de sistema de outra forma inacessível) e **de temporização** (transmitida pela **temporização** de eventos ou processos).

O exemplo do livro é distribuído: dois nós, um secreto (S) e um não-classificado (U), precisam concordar para confirmar uma transação, e a propriedade estrela proíbe S de passar informação a U — mas se a transação roda repetidamente e S varia *como* ou *quando* confirma de forma combinada, S transmite bits a U sem nunca gravar nada. Bloqueio previne canais de armazenamento; o controle de multiprogramação do SO previne os de temporização. Conclusão pragmática do livro: **"em geral, os canais secretos não são um grande problema nas implementações de banco de dados robustas e bem implementadas"**.

Recomendação acionável e barata: **impedir que programadores acessem os dados confidenciais que o programa processará em produção**. "Um programador de um banco não tem necessidade de acessar os nomes ou saldos nas contas dos clientes." Dados reais durante teste podem ser justificáveis; depois do uso regular, não.

**Nota prática:** este é o argumento canônico contra restaurar dump de produção em dev. Use dados sintéticos ou dump mascarado (§8). E o canal de temporização não é folclore: se seu login responde mais rápido para e-mail inexistente que para senha errada, você construiu um canal de temporização que enumera usuários. Comparação em tempo constante, resposta uniforme.

---

## 8. Criptografia, dados em repouso e em trânsito, chaves

Definições (Elmasri, cap. 24.7): **texto limpo**, **texto cifrado**, **criptografia** (limpo → cifrado), **descriptografia**. É a medida de controle para quando as anteriores foram contornadas: dado interceptado ou disco roubado não é legível.

**Simétrica** (Elmasri, cap. 24.7.2): mesma chave cifra e decifra. Rápida, adequada ao uso rotineiro sobre dados sensíveis no banco. **Desvantagem principal: a necessidade de compartilhar a chave.** Robustez depende do tamanho da chave — DES (chave efetiva 56 bits) foi superado pelo **AES** (bloco 128 bits, chaves de 128/192/256) porque seu espaço de chaves ficou pequeno (Elmasri, cap. 24.7.1).

**Assimétrica / chave pública** (Elmasri, cap. 24.7.3): duas chaves relacionadas; a pública trafega em canal inseguro, a privada nunca é transmitida; o que uma cifra só a outra decifra. Resolve a distribuição de chave da simétrica. RSA baseia-se na dificuldade de fatorar o produto de dois primos grandes.

**Assinaturas digitais** (Elmasri, cap. 24.7.4): precisam ser **diferentes a cada uso** — assinatura constante é copiável — logo são função **da mensagem** + **rótulo de tempo** + **número secreto do assinante**. O verificador não precisa saber segredo algum; chave pública é a melhor forma de obter isso.

**Certificados digitais** (Elmasri, cap. 24.7.5): ligam chave pública à identidade de quem detém a privada, numa declaração assinada por uma **autoridade certificadora (CA)**. Contêm DN do proprietário, chave pública, emissão, validade, identificador do emissor e assinatura da CA. Permitem **autenticação de terceiros** em vez de cada participante autenticar cada usuário.

**Nota prática — decisões concretas no PostgreSQL:**

| Camada | Ferramenta | Quando |
|---|---|---|
| **Trânsito** | TLS `sslmode=verify-full` | **Sempre.** `require` cifra mas não valida o servidor — não protege contra MITM; só `verify-full` valida o hostname contra o certificado (§24.7.5 aplicado). |
| **Repouso (volume)** | LUKS / EBS encryption / TDE | Padrão, custo ~zero. Protege contra roubo físico e descarte de disco. **Não** protege contra injection nem DBA curioso — o banco decifra transparentemente. |
| **Repouso (coluna)** | `pgcrypto` | Só no punhado de colunas que exigem proteção **contra quem tem acesso ao banco**. |
| **Senhas** | `crypt()` + `gen_salt('bf')`, ou argon2 na app | Nunca criptografia reversível. |

O trade-off da cifra em coluna é severo e subestimado: **coluna cifrada não é indexável para range nem busca, e destrói seletividade**. Não cifre `valor_centavos` — você perde `WHERE valor > X`, `SUM()` e todo índice útil. Cifre o token do provedor de open banking, o refresh token, o número completo do cartão.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Senha: hash, não criptografia. Não existe "decifrar senha".
INSERT INTO usuarios (email, senha_hash) VALUES ($1, crypt($2, gen_salt('bf', 12)));
SELECT id FROM usuarios WHERE email = $1 AND senha_hash = crypt($2, senha_hash);

-- Segredo de integração: cifra simétrica. $3 = chave, vinda da app, NUNCA do banco.
INSERT INTO integracoes (usuario_id, token_cifrado) VALUES ($1, pgp_sym_encrypt($2, $3));
```

**Gestão de chaves — onde quase todo mundo erra.** A chave do `pgp_sym_encrypt` não pode viver no banco, senão você cifrou o cofre e deixou a chave dentro. Nem como literal na query, porque **entra no log de statements e no `pg_stat_statements`**. Regras: (1) chave num KMS (AWS KMS, Vault), não em env var em texto plano quando houver alternativa; (2) **envelope encryption** — o KMS guarda a chave-mestra, ela cifra as DEKs, as DEKs cifram as linhas, e rotacionar a mestra não reescreve a tabela; (3) versione a chave por linha (`chave_versao`) **antes** de precisar, ou a rotação vira migração de tabela inteira; (4) chave sempre por parâmetro, nunca interpolada.

**Mascaramento de PII (nota prática):** para ambientes não-produtivos e roles de suporte, o mecanismo é o do §2 — visão + `GRANT`, agora com transformação:

```sql
CREATE VIEW financeiro.usuarios_suporte AS
SELECT id,
       regexp_replace(email, '(.).*(@.*)', '\1***\2') AS email,
       '***.***.***-' || right(cpf, 2) AS cpf,
       criado_em
FROM financeiro.usuarios;

REVOKE ALL ON financeiro.usuarios FROM suporte;
GRANT SELECT ON financeiro.usuarios_suporte TO suporte;
```

Isto é o §24.1.5 operacionalizado: sacrifica precisão (o suporte não vê o CPF inteiro) para ganhar segurança, e o dado exposto é o mínimo que ainda permite o trabalho.

---

## 9. Privacidade, LGPD e retenção

O livro trata privacidade como distinta e maior que segurança (Elmasri, cap. 24.1.6, 24.8). Princípio básico citado: **as pessoas devem ser informadas sobre a coleta, avisadas com antecedência sobre o uso e ter oportunidade razoável de aprovar tal uso**. Técnicas de preservação (cap. 24.8): **evitar warehouses centrais imensos** como repositório único de informação vital (violar um único repositório expõe tudo); **modificar/perturbar dados intencionalmente**, remover informação de identidade, injetar ruído — mas **atenção à qualidade dos dados resultantes**, sendo preciso **estimar os erros introduzidos**; mineração distribuída em vez de centralizada.

**Nota prática — LGPD e o conflito real.** O atrito num app financeiro é **direito ao esquecimento (art. 18) vs. imutabilidade do log contábil e da trilha de auditoria (§10)**. Você não pode simplesmente `DELETE` a transação: ela sustenta saldo, conciliação e a própria trilha. O padrão que resolve é **anonimização em vez de exclusão — preservar o fato, destruir o vínculo**:

```sql
BEGIN;
  UPDATE financeiro.usuarios
     SET email = 'anon+' || id || '@invalido.local', nome = 'Usuário removido',
         cpf = NULL, telefone = NULL, anonimizado_em = now()
   WHERE id = $1;
  UPDATE financeiro.transacoes
     SET descricao = NULL, contraparte = NULL   -- texto livre carrega PII
   WHERE usuario_id = $1;
COMMIT;
```

As transações continuam existindo com valores e datas — o fato contábil é preservado — mas não são mais atribuíveis a uma pessoa natural. Atende ao direito de eliminação sem violar a obrigação de guarda. É exatamente a técnica de "remover informações de identidade dos dados" do §24.8 — e o alerta do livro sobre qualidade dos dados se aplica: meça o impacto nos seus agregados antes de anonimizar em massa.

Decorrências:
- **Descrição em texto livre é o vazamento estrutural.** "PIX para Maria — aluguel" é PII de terceiro numa coluna que ninguém classificou como PII. É o fator 5 de sensibilidade do livro: dado não confidencial por si, que se torna na presença de outro (Elmasri, cap. 24.1.5).
- **Retenção:** defina prazo por tabela e execute. Dado que não existe não vaza — a medida mais barata que existe. Um `pg_cron` purgando logs além do prazo legal vale mais que muita criptografia.
- **Backups são cópias sem RLS.** Um dump ignora políticas. Cifre backups, controle o acesso e inclua-os na retenção — senão um restore desfaz o "esquecimento".
- **`anonimizado_em` é flag operacional**, não campo de negócio: use-a para excluir esses registros de benchmarks (§6) e reprocessamentos.

---

## 10. Auditoria e trilha de auditoria

O sistema precisa registrar **todas as operações aplicadas por certo usuário em cada sessão de login** — a sequência de interações do login ao logoff. Quando o usuário loga, o SGBD associa a conta ao computador/dispositivo de origem, e todas as operações daquele dispositivo são atribuídas a essa conta até o logoff (Elmasri, cap. 24.1.4).

O mecanismo proposto é reaproveitar o **log do sistema** (o mesmo dos caps. 21 e 23, usado para recuperação), estendendo as entradas com o número da conta e o ID do dispositivo que aplicou cada operação. Uma **auditoria** revisa o log para examinar acessos e operações num período; achada operação ilegal, o DBA determina a conta usada. **Um log de banco usado principalmente para fins de segurança é chamado de trilha de auditoria** (Elmasri, cap. 24.1.4). O livro enfatiza registrar **as operações de atualização**, para que, se o banco for adulterado, se saiba quem mexeu — e nota que auditorias importam especialmente em bancos sensíveis atualizados por muitas transações e usuários (o exemplo dado é o de bancos e seus caixas).

**Nota prática:**

- O WAL do PostgreSQL **não é** trilha de auditoria — existe para recuperação e é reciclado. Não responde "quem alterou este saldo em março".
- **`pgaudit`** é o caminho padrão para auditoria de sessão/objeto. Configure por role, não globalmente, ou o volume mata a performance.
- Para auditoria de **negócio** (quem mudou o quê, valor antigo e novo), use tabela própria alimentada por trigger, append-only:

```sql
CREATE TABLE financeiro.auditoria (
  id bigserial PRIMARY KEY,
  tabela text NOT NULL, registro_id uuid NOT NULL, operacao text NOT NULL,
  ator text NOT NULL DEFAULT current_setting('app.usuario_id', true),
  db_role text NOT NULL DEFAULT current_user,        -- §24.1.4: conta + origem
  origem_ip inet DEFAULT inet_client_addr(),
  valor_antigo jsonb, valor_novo jsonb,
  ocorrida_em timestamptz NOT NULL DEFAULT now()
);

-- Append-only: nem a app pode reescrever a história.
REVOKE UPDATE, DELETE ON financeiro.auditoria FROM app_escrita, api_prod;
GRANT INSERT, SELECT ON financeiro.auditoria TO app_escrita;
```

O `REVOKE UPDATE, DELETE` é o ponto: uma trilha que o atacante reescreve depois de comprometer a app não é trilha. É o argumento do livro sobre **abuso de privilégio** (cap. 24.4) — o ataque vem de um usuário privilegiado, então a trilha precisa ser protegida *contra* o privilégio da aplicação. Trigger `SECURITY DEFINER` grava sem dar `INSERT` direto.

- Registre `db_role` **e** `app.usuario_id`: com pooling todas as conexões usam o mesmo role, e sem o contexto da app você audita "api_prod" mil vezes sem aprender nada. É o §24.1.4 (conta + dispositivo de origem) adaptado ao connection pool.
- **Conflito com o §9:** a trilha guarda `valor_antigo`/`valor_novo` em JSONB, logo guarda PII de quem pediu esquecimento. Resolva por retenção (purgue após o prazo legal) ou anonimize os campos de PII dentro do JSONB — no design, não no incidente.

---

## 11. Bancos de dados distribuídos: conceitos e transparência

**BDD** = coleção de múltiplos bancos **logicamente inter-relacionados**, distribuídos por uma rede; **SGBDD** = software que o gerencia **tornando a distribuição transparente ao usuário** (Elmasri, cap. 25.1).

Condições mínimas para ser chamado distribuído (cap. 25.1.1): nós conectados por rede; **inter-relação lógica** entre os bancos; **ausência de restrição de homogeneidade** (os nós não precisam ser idênticos em dados, hardware ou software). A segunda é o que distingue BDD de "muitos arquivos na Web" — o livro nota que a proliferação de dados em milhões de sites Web **não se qualifica** como BDD.

### Tipos de transparência (Elmasri, cap. 25.1.2)

- **Da organização dos dados** (= distribuição, = rede): subdivide-se em **transparência de local** (o comando independe de onde estão os dados e de onde foi emitido) e **transparência de nomes** (objeto nomeado é acessado sem ambiguidade, sem dizer onde está).
- **De replicação:** o usuário desconhece a existência de cópias.
- **De fragmentação:** o usuário desconhece os fragmentos; a consulta global é transformada em várias consultas de fragmento.
- **De projeto e de execução:** não saber como o BDD foi projetado nem onde a transação executa.

**Trade-off explícito do livro:** transparência tem **custo de overhead**, e tensiona com **autonomia** — transparência total dá a visão de um sistema centralizado único; autonomia dá controle estrito sobre os bancos locais (Elmasri, cap. 25.1.5). Autonomia (cap. 25.1.3) aplica-se a **projeto** (modelo de dados, gerenciamento de transação), **comunicação** (quanto cada nó compartilha) e **execução**.

**Vantagens** (Elmasri, cap. 25.1.5): desenvolvimento flexível em sites geograficamente distribuídos; **maior confiabilidade e disponibilidade** (isolamento de falha ao site de origem — no centralizado uma falha derruba tudo para todos; no BDD parte dos dados fica inalcançável e o resto opera); **maior desempenho** (localização reduz disputa por CPU/IO e latência; bancos locais menores; paralelismo entre e dentro de consultas); expansão mais fácil.

**Funções adicionais exigidas** (Elmasri, cap. 25.1.6), cada uma sendo complexidade nova: rastrear a distribuição (catálogo estendido), consulta distribuída, transação distribuída, dados replicados, recuperação distribuída, segurança e catálogo distribuído.

**O aviso mais importante do capítulo, e ele é histórico:** apesar de vários protótipos de SGBDD nos anos 1980, **"um SGBDD abrangente em escala completa nunca surgiu como um produto comercialmente viável"**. Os principais fornecedores redirecionaram esforços para **cliente-servidor** e para tecnologias de acesso a fontes heterogêneas (Elmasri, cap. 25, introdução). Leia isso como: distribuição transparente completa é mais difícil do que parece, e a indústria desistiu dela em favor de arquiteturas onde a distribuição é explícita.

---

## 12. Fragmentação, replicação e alocação

Projeto de BDD = decidir as **unidades lógicas** a distribuir, e depois onde colocá-las (Elmasri, cap. 25.4).

### Horizontal

Subconjunto das **tuplas**, definido por condição sobre um ou mais atributos: `σ_C(R)`. Fragmentos cujas condições `C1..Cn` cobrem todas as tuplas (toda tupla satisfaz `C1 OR ... OR Cn`) formam uma **fragmentação horizontal completa**; se além disso nenhuma tupla satisfaz `Ci AND Cj` para `i≠j`, é **disjunta**. Reconstrução: **UNIÃO**.

### Horizontal derivada

Particiona uma relação **primária** e propaga o mesmo particionamento às **secundárias** via chave estrangeira, mantendo dados relacionados juntos (Elmasri, cap. 25.4.1). É o conceito operacionalmente mais valioso do capítulo: no exemplo, `DEPARTAMENTO` é fragmentado por `Dnumero` e `FUNCIONARIO`/`PROJETO`/`LOCALIZACAO_DEP` derivam por suas FKs. Objetivo: **que a junção aconteça localmente**.

**Nota prática:** é a regra de ouro do sharding. Fragmente `usuarios` por `id` e derive `contas`, `transacoes`, `categorias` por `usuario_id`. Se fragmentar `transacoes` por data e `contas` por usuário, toda junção vira cross-shard — você pagou o custo da distribuição sem receber o benefício.

### Vertical

Subconjunto das **colunas**: `π_L(R)`. O livro dá o contra-exemplo antes do exemplo: fragmentar `FUNCIONARIO` em {Nome, Data_nasc, Endereço, Sexo} e {Cpf, Salario, Cpf_supervisor, Dnr} **não funciona** — sem atributo comum, não dá para remontar as tuplas. **É obrigatório incluir a chave primária (ou candidata) em cada fragmento vertical.** Completa: `L1 ∪ ... ∪ Ln = ATTRS(R)` e `Li ∩ Lj = CHAVE(R)` para `i≠j`. Reconstrução: **UNIÃO EXTERNA**.

### Mista

`π_L(σ_C(R))`. Com `C = TRUE, L ≠ ATTRS(R)` → vertical; `C ≠ TRUE, L = ATTRS(R)` → horizontal; ambos diferentes → misto; a relação inteira é `C = TRUE, L = ATTRS(R)` (Elmasri, cap. 25.4.1). Um **esquema de fragmentação** garante que o banco é reconstruível dos fragmentos; um **esquema de alocação** mapeia fragmentos a sites (em mais de um site = replicado).

O livro é honesto sobre a dificuldade: relações M:N (como `TRABALHA_EM`) **não têm atributo que indique diretamente o fragmento** — a tupla liga um funcionário de um departamento a um projeto de outro. Fragmentar por qualquer lado deixa junções remotas, e a saída do exemplo é replicar os fragmentos-ponte nos dois sites (Elmasri, cap. 25.4.3). **Toda tabela de junção M:N é um problema de sharding.**

### Replicação e alocação (Elmasri, cap. 25.4.2)

| Estratégia | Ganho | Custo |
|---|---|---|
| **Totalmente replicado** | Disponibilidade máxima (opera com 1 site vivo); leitura sempre local | **Atualização aplicada em cada cópia**; concorrência e recuperação muito mais caros |
| **Sem replicação** (alocação não redundante) | Atualização barata | Falha de site = dados inacessíveis |
| **Replicação parcial** | Meio-termo ajustável | Complexidade de decidir o quê |

Critérios explícitos do livro: alta disponibilidade + maioria das transações **só de recuperação** → totalmente replicado; transações que acessam certas partes **submetidas principalmente a um site** → aloque aqueles fragmentos só ali; **muitas atualizações → limite a replicação**. Veredito: a alocação ótima **é um problema de otimização bastante complexo**.

**Nota prática:** este quadro explica réplicas de leitura no PostgreSQL. Réplica streaming = replicação total assíncrona: leitura escala, escrita não (todo write vai ao primário e é reaplicado em todas). O custo do livro reaparece como **replication lag**: um `SELECT` na réplica logo após um `INSERT` no primário pode não ver a linha — é a "consistência das cópias" que o SGBDD deveria garantir e que a replicação assíncrona não garante. Regra: leituras de relatório vão à réplica; leituras num fluxo read-your-writes (o extrato logo após registrar a transação) vão ao primário. Com Prisma é a extension `readReplicas` — decida por query, não globalmente.

---

## 13. Processamento de consulta distribuída

Estágios (Elmasri, cap. 25.5.1): **mapeamento** (traduz para álgebra sobre relações **globais**, sem considerar distribuição/replicação — idêntico ao centralizado); **localização** (mapeia a consulta global em consultas sobre **fragmentos individuais**); **otimização global** (estratégia de menor custo, sendo o custo total uma combinação ponderada de CPU, E/S e comunicação).

### Custo de transferência domina

O exemplo do livro merece ser reproduzido porque o resultado é contra-intuitivo (Elmasri, cap. 25.5.2). `FUNCIONARIO` no site 1 (10.000 × 100 B = 1.000.000 B), `DEPARTAMENTO` no site 2 (100 × 35 = 3.500 B), resultado pedido no site 3 (10.000 × 40 = 400.000 B).

| Estratégia | Bytes transferidos |
|---|---|
| Mandar as duas relações ao site 3 e juntar lá | 1.003.500 |
| Mandar FUNCIONARIO ao site 2, juntar, enviar ao 3 | 1.400.000 |
| **Mandar DEPARTAMENTO ao site 1, juntar, enviar ao 3** | **403.500** |

A estratégia intuitiva ("junte onde o resultado é pedido") é a segunda pior; a vencedora move a relação **pequena** até a **grande**. É o princípio do broadcast join de qualquer engine distribuída moderna, e estava aqui em 1980. O livro observa que esses custos são irrelevantes numa LAN rápida mas significativos em outras redes — **o critério de otimização muda com a topologia**.

### Semijunção

Em vez de transferir a relação inteira, transfere-se **apenas a coluna de junção**; o site remoto junta e devolve só as tuplas que casam. No exemplo, `T1` executa no site 2, a **coluna projetada `Fcpf`** vai ao site 1, `T2` executa lá e o resultado volta (Elmasri, cap. 25.5.3-4).

**Nota prática:** é o que você faz à mão quando um ORM gera N+1 cross-service: em vez de puxar a tabela inteira do outro serviço, mande a lista de IDs e receba só o que casa. Semijunção é a formalização de `WHERE id = ANY($1)`.

---

## 14. Transações distribuídas: 2PC e 3PC

Os gerenciadores de transação global e local, mais concorrência e recuperação, garantem coletivamente as propriedades ACID (Elmasri, cap. 25.6). O site que originou a transação assume temporariamente o papel de **gerenciador de transação global**. Semântica: `READ` retorna cópia local se válida; `WRITE` garante visibilidade em **todos** os sites com réplica; `ABORT` garante que nenhum efeito sobreviva em site algum; `COMMIT` garante persistência em todos os bancos com cópia. **O término atômico é implementado com 2PC.**

### 2PC (Elmasri, cap. 23.6, referenciado em 25.6.1)

- **Fase 1 (voto/preparação):** quando todos os participantes sinalizam que sua parte terminou, o coordenador envia **prepare to commit**. Cada participante **força a gravação em disco** dos registros de log e da informação de recuperação local, e responde **ready to commit / OK**; se a gravação forçada falhar ou o commit local for impossível, responde **não OK**. **Sem resposta dentro do timeout, o coordenador assume não OK.**
- **Fase 2 (decisão):** todos OK mais voto OK do coordenador → sinal de confirmação a todos. Caso contrário, aborta.

A força do 2PC está na fase 1: o *force-write* antes do voto é o que permite ao participante honrar o commit mesmo se cair logo depois.

### Por que 2PC é insuficiente (Elmasri, cap. 25.6.2)

**"A maior desvantagem do 2PC é que ele é um protocolo de bloqueio."** Falha do coordenador **bloqueia todos os participantes**, que esperam sua recuperação segurando bloqueios sobre recursos compartilhados.

Pior é o cenário indeterminado: **coordenador e um participante que já confirmou falham juntos**. No 2PC um participante não sabe se os demais receberam o commit da fase 2 — cada um confirma independentemente disso. Na recuperação o resultado é **não-determinístico**: não dá para abortar (um participante já confirmou) nem para confirmar otimisticamente (o voto original do coordenador pode ter sido abortar).

### 3PC (Elmasri, cap. 25.6.2)

Divide a fase 2 em **preparar-para-confirmar** e **confirmar**. A primeira **comunica o resultado da votação a todos**: se todos votaram sim, o coordenador os instrui a entrar no estado *prepared-to-commit*; a segunda é idêntica à do 2PC.

Ganho: se o coordenador falhar durante a subfase confirmar, **outro participante leva a transação até o fim** — basta perguntar a um participante se recebeu o preparar-para-confirmar; se não recebeu, assume-se seguramente abortar. O estado é recuperável independentemente de quem falhou. E o **timeout** garante que a transação libera os bloqueios ao expirar, resolvendo o bloqueio indefinido.

**Nota prática — o critério de decisão.** Não use 2PC (nem 3PC) se houver alternativa: custa dois round-trips com force-write em cada nó, bloqueios durante toda a janela, e a indeterminação real. No PostgreSQL 2PC existe (`PREPARE TRANSACTION`/`COMMIT PREPARED`, via `max_prepared_transactions`), com armadilha famosa: **uma transação preparada e órfã segura bloqueios e trava o VACUUM indefinidamente**, porque o banco não pode assumir nada sobre ela. Monitore `pg_prepared_xacts` ou não habilite.

Alternativas por ordem de preferência num app de finanças:
1. **Não distribua a transação.** Débito e crédito de uma transferência interna cabem numa transação local — e devem ficar nela. É decisão de arquitetura, não de infra.
2. **Outbox transacional:** grave o evento na mesma transação local que muda o estado; um relay publica depois, at-least-once. Troca atomicidade distribuída por consistência eventual com idempotência.
3. **Saga com compensação:** fluxos longos cross-service. O livro já cita **transações de compensação** entre as restrições que um federado precisa reconciliar (Elmasri, cap. 25.2.1).
4. **2PC:** só quando atomicidade forte cruzando recursos é irredutível e os participantes são poucos, confiáveis e próximos.

---

## 15. Controle de concorrência distribuído

Problemas que não existem no centralizado (Elmasri, cap. 25.7): múltiplas cópias dos itens (manter consistência); falha de sites individuais (o BDD deve continuar operando; ao voltar, o site se atualiza antes de reingressar); **falha dos links de comunicação**, cujo caso extremo é o **particionamento da rede** (sites divididos em partições que só falam internamente); confirmação distribuída; **deadlock distribuído**.

### Métodos de cópia distinguida (Elmasri, cap. 25.7.1)

Designa-se uma cópia de cada item como **distinguida**; os bloqueios ficam associados a ela e todo lock/unlock vai ao site que a contém.

| Técnica | Trade-off |
|---|---|
| **Site primário** — um site coordena os bloqueios de **todos** os itens | Extensão simples do centralizado, mas gargalo, e **falha dele paralisa o sistema** |
| **Primário com backup** — info de bloqueio nos dois | Failover simples, mas **atrasa cada aquisição** (lock e concessão registrados nos dois antes de responder) |
| **Cópia primária** — distinguidas de **itens diferentes** em **sites diferentes** | Distribui a carga; falha afeta só quem acessa itens cuja primária está lá |

Detalhe: os bloqueios são acessados no site primário, mas **os itens podem ser acessados em qualquer site onde residem**. Com `read_lock` lê-se qualquer cópia; com `write_lock`, o SGBDD **precisa atualizar todas as cópias antes de liberar o bloqueio**.

**Eleição:** se o coordenador cai sem backup, **todas as transações em execução são abortadas e reiniciadas**. Sem primário nem backup roda-se eleição: um site Y que falha repetidamente ao contatar o coordenador propõe-se aos sites vivos e, com **maioria** de votos sim, declara-se coordenador — algoritmo complexo, que ainda precisa resolver dois sites se elegendo ao mesmo tempo.

**Votação** (cap. 25.7.2): sem cópia distinguida, o pedido vai a **todos** os sites com cópia; obtida a **maioria**, a transação detém o bloqueio e avisa todas. É o **único método verdadeiramente distribuído**, mas tem **tráfego de mensagens muito mais alto**, e o livro avisa: *"se o algoritmo levar em conta possíveis falhas do site durante o processo de votação, ele se torna extremamente complexo"*.

### Recuperação distribuída (Elmasri, cap. 25.7.3)

O problema fundamental é epistemológico: X envia mensagem a Y e não recebe resposta. Três explicações **indistinguíveis** sem informação adicional: a mensagem não chegou; Y está parado; Y respondeu e a resposta se perdeu.

**Nota prática:** esta é a formulação, no vocabulário de 1980, do problema que o teorema CAP formalizaria depois. **Esta edição (6ª) não cobre CAP nem NoSQL** — não há capítulo sobre isso (26-29 são modelos avançados, recuperação de informação, mineração e data warehousing); o mais perto é o §25.9. Se você precisa de CAP, não cite este livro: ele tem o problema, não o teorema. Mas repare que "não dá para distinguir nó morto de rede particionada" **é** a partição do CAP, e a escolha entre esperar (2PC bloqueante) e prosseguir (votação por maioria) é CP vs. AP.

---

## 16. Catálogo distribuído

Catálogos são bancos de dados com metadados sobre o BDD. Três esquemas (Elmasri, cap. 25.8):

| Esquema | Leitura | Escrita | Autonomia |
|---|---|---|---|
| **Centralizado** | Bloqueia no central, recebe, confirma, desbloqueia | Tudo passa pelo central → **gargalo em write-intensive** | Prejudicada |
| **Totalmente replicado** | Local e rápida | Broadcast a todos como transação com **2PC** → tráfego alto | Prejudicada |
| **Parcialmente replicado** | Local para dados locais; cache para remotos (**sem garantia de atualidade**) | Propagada imediatamente ao site de origem ("de nascimento") | Preservada |

No parcialmente replicado, cada site tem catálogo completo do que armazena e pode cachear entradas remotas; buscar cópias atualizadas pode ser **adiado até o acesso**; usuários criam **sinônimos** para objetos remotos (transparência de nomes, §11). Centralizado e totalmente replicado **restringem a autonomia do site**, por precisarem garantir visão global coerente.

**Nota prática:** é a razão de service discovery e schema registry serem eventualmente consistentes com cache local — e de `pg_catalog` ser por-banco, não compartilhado no cluster: catálogo global é gargalo de escrita.

---

## 17. Tipos e arquiteturas

### Classificação em três eixos (Elmasri, cap. 25.2)

Eixos **ortogonais**: distribuição, autonomia, heterogeneidade.

| Ponto | Sistema | Distribuição | Autonomia | Esquema global |
|---|---|---|---|---|
| A | Centralizado tradicional | Nenhuma | Completa | — |
| B | **BDD puro** | Total | **Zero** (todo acesso via um site do SGBDD) | Único esquema conceitual |
| C | **Federado (SBDF)** | Sim | Alta (cada servidor é SGBD autônomo, com seus usuários e DBA) | **Existe** visão global compartilhada |
| D | **Multibanco / peer-to-peer** | Sim | **Completa** | **Não há** — construído interativamente conforme a necessidade |

Nota de rodapé ácida do livro sobre o ponto D: *"o termo sistema de multibanco de dados não se aplica facilmente à maioria dos ambientes de TI empresariais. A noção de construir um esquema global como e quando houver necessidade não é muito viável na prática."*

### Problemas dos sistemas federados (Elmasri, cap. 25.2.1)

Fontes de heterogeneidade: **modelos de dados** (mesmo entre dois SGBDRs, a mesma informação pode ser nome de atributo num, nome de relação noutro e valor num terceiro); **restrições** (recursos variam; o esquema global precisa reconciliar conflitos); **linguagens de consulta** (versões de SQL, tipos, operadores).

**Heterogeneidade semântica** — "o maior obstáculo no projeto de esquemas globais": diferenças no **significado, interpretação e uso intencionado** dos mesmos dados. O exemplo do livro é financeiro: relações `CLIENTE`/`CONTA`, uma nos EUA e outra no Japão, com atributos totalmente distintos exigidos por práticas contábeis diferentes, mais flutuação de câmbio. Nomes idênticos, informação parcialmente comum e parcialmente incompatível.

O desafio central: **fazer os componentes interoperarem preservando sua autonomia** — de comunicação, de execução e de associação (quanto compartilhar). A arquitetura de cinco níveis do SBDF (cap. 25.3.3): **local** → **componente** (traduzido para modelo canônico) → **exportação** (subconjunto disponível à federação) → **federado** (integração dos de exportação) → **externos** (por grupo de usuários).

**Paralela vs. distribuída** (cap. 25.3.1): **memória compartilhada** (disco + memória) e **disco compartilhado** (disco, memória própria) dão origem a SGBDs **paralelos**, não distribuídos. **Nada compartilhado** (memória e disco próprios, rede rápida) *se parece* com BDD, mas o livro marca a diferença: lá há **simetria e homogeneidade de nós**; no distribuído, **heterogeneidade de hardware e SO por nó é muito comum**.

### Cliente-servidor de três camadas (Elmasri, cap. 25.3.4)

A arquitetura que venceu: **apresentação** (cliente/browser) → **aplicação** (lógica de negócio; formula consultas, faz verificações de segurança e identidade, conecta via ODBC/JDBC) → **servidor de banco de dados**.

O ponto que importa: o servidor de aplicação é quem **gera o plano de execução distribuído**, supervisiona a execução multi-site, garante a **consistência de cópias replicadas** com controle de concorrência distribuído e a **atomicidade de transações globais** com recuperação global. Quando o SGBDD não faz, **a camada de aplicação herda o problema**.

**Nota prática:** é literalmente a sua API Node. Ao adotar réplica de leitura, join cross-service ou outbox, você virou o "servidor de aplicação" do §25.3.4 — a distribuição não sumiu, migrou para o seu código, sem transparência. O livro nota secamente que **alguns SGBDDs não oferecem transparência de distribuição, exigindo que as aplicações conheçam os detalhes**. Prisma não oferece.

### Tendências (Elmasri, cap. 25.9)

**Computação em nuvem** (cap. 25.9.1): o livro identifica os gargalos que mataram o SGBDD tradicional na nuvem — **custos de desempenho associados a falhas parciais e sincronismo global** e falta de **particionamento dinâmico** — e descreve a solução, que é o embrião do NoSQL sem a palavra: os conjuntos de dados **servem naturalmente ao particionamento** (natureza de valor de hash); **as partições podem ser tratadas independentemente, eliminando a necessidade de confirmação coordenada** (dispensa o 2PC do §14); **desacople metadados dos dados reais**, usando banco tradicional com consistência estrita só para os metadados críticos (fração do total, não viram gargalo); **requisitos de consistência variam com a natureza do dado** (busca tolera garantias fracas, editor online concorrente — o exemplo é Google Docs — exige estritas); e a **semântica de objeto único** (acesso atômico a um objeto) permite suporte transacional menos rigoroso. Repito: 90% da justificativa do NoSQL, mas **o livro não formula CAP nem discute NoSQL nominalmente**.

**Peer-to-peer** (cap. 25.9.2): busca escalabilidade, resiliência a ataque e auto-organização; nós autônomos vinculados a poucos pares. Diferença estrutural: SBDF e multibanco exigem mapeamentos entre esquemas locais e globais; **SBDPs evitam o esquema global**, mapeando **pares de fontes** entre si, já que cada par modela dados relacionados de forma diferente e um esquema mediado central seria inviável.

---

## Checklist de decisão

**Segurança (PostgreSQL + Prisma):** (1) app **não é owner, não é superuser**, sem `BYPASSRLS`; duas URLs, migrator e runtime — sem isso, o resto é teatro. (2) Roles de grupo (`NOLOGIN`) carregam privilégio, roles de login herdam; `ALTER DEFAULT PRIVILEGES` para tabelas futuras. (3) RLS com `FORCE` + `USING` + `WITH CHECK` nas tabelas com dado de tenant; contexto via `set_config(..., true)` dentro de `$transaction`. (4) Zero `$queryRawUnsafe`; `$queryRaw` só como template tag; `Prisma.raw` só com literais do código; identificadores dinâmicos só por allowlist. (5) TLS `verify-full`; cifra de volume por padrão; `pgcrypto` só nas poucas colunas que precisam, com chave no KMS — nunca no banco, nunca no log. (6) Trilha append-only (`REVOKE UPDATE, DELETE` da app), com `db_role` **e** `app.usuario_id`. (7) PII: visões mascaradas para suporte e dev; anonimização (não `DELETE`) para o esquecimento; retenção executada; backups na política. (8) Agregados só com `HAVING count(*) >= k`.

**Distribuição — a pergunta de abertura é sempre a mesma:**

1. **Você precisa distribuir?** O livro registra que o SGBDD completo nunca virou produto viável e que a indústria foi para cliente-servidor (Elmasri, cap. 25). Um PostgreSQL vertical com réplicas de leitura resolve a esmagadora maioria dos apps de finanças pessoais. Distribua com problema medido, não previsto.
2. **Se replicar:** replicação total favorece leitura e pune escrita (cap. 25.4.2). Decida por query onde a leitura vai; réplica assíncrona quebra read-your-writes.
3. **Se fragmentar:** escolha a chave (`usuario_id`) e use **fragmentação derivada** para levar as tabelas relacionadas juntas — senão toda junção vira remota. Vertical exige a PK em cada fragmento; tabelas M:N são o caso difícil.
4. **Se precisar de atomicidade cross-nó:** tente não precisar; depois outbox; depois saga; 2PC por último, monitorando `pg_prepared_xacts`.
5. **Aceite que a distribuição migrou para a sua aplicação.** Sem transparência do SGBDD, o §25.3.4 diz quem herda o plano distribuído, a consistência de réplicas e a atomicidade global: você.
