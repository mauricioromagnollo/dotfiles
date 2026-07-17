# Modelagem conceitual e lógica (ER → relacional)

Abra esta referência quando precisar **decidir a forma de um schema**: se um conceito vira tabela, coluna ou FK; como traduzir 1:1 / 1:n / n:n; como implementar herança em PostgreSQL; se a cardinalidade mínima permite `NOT NULL`; ou quando for necessário ler/produzir um DER ou reconstruir o modelo conceitual a partir de um banco existente. Base: Carlos A. Heuser, *Projeto de Banco de Dados*. Exemplos em PostgreSQL, domínio de finanças pessoais.

O projeto tem duas etapas: **modelagem conceitual** (o que o BD guarda, independente de SGBD — modelo ER) e **projeto lógico** (como isso vira tabelas). Nunca antecipe FK, tipos ou desnormalização para o modelo conceitual: são decisões da segunda etapa (Heuser, cap. 1 e 3).

---

## 1. Vocabulário ER — o que cada construção significa

| Construção | Definição operacional | Onde aparece no relacional |
|---|---|---|
| **Entidade** | conjunto de objetos sobre os quais se quer guardar informação | tabela |
| **Ocorrência de entidade** | um objeto individual | linha |
| **Relacionamento** | conjunto de associações entre entidades | FK ou tabela própria |
| **Atributo** | dado associado a cada ocorrência de entidade *ou de relacionamento* | coluna |
| **Identificador** | conjunto mínimo de atributos e/ou relacionamentos que distingue uma ocorrência | chave primária |
| **Papel** | função de uma entidade dentro do relacionamento | nome da coluna FK |
| **Generalização/especialização** | subconjuntos de uma entidade genérica com propriedades próprias | ver §5 |
| **Entidade associativa** | relacionamento tratado também como entidade, para poder ser relacionado | tabela do n:n referenciada por outras |

Regras estruturais (Heuser, cap. 2 e 3.3.1): atributo não tem atributo, não participa de relacionamento e não é especializado. Violar isso é **erro sintático**. Cada objeto da realidade aparece **uma única vez** no modelo — ter a entidade `CATEGORIA` e, além disso, um atributo `categoria` em `TRANSACAO` é erro semântico.

### Cardinalidade

Duas cardinalidades, sempre anotadas como par `(mín, máx)` do lado **oposto** da entidade a que se referem, na notação Chen:

- **Máxima**: só interessam `1` e `n`. Classifica relacionamentos binários em 1:1, 1:n, n:n.
- **Mínima**: só interessam `0` (participação opcional) e `1` (obrigatória).

A cardinalidade mínima é a decisão mais cara do modelo porque **exige conhecer as transações**, não só a semântica (Heuser, cap. 2.2.6). Critério: pergunte *"no instante imediatamente após o INSERT desta ocorrência, a outra ponta já existe?"*. Se a conta é criada numa transação e só depois recebe transações, `CONTA` tem cardinalidade mínima 0 em `LANCAMENTO` — mesmo que "conta sem lançamento" pareça inútil no domínio. Por isso Heuser recomenda deixar as mínimas para o último passo da modelagem (cap. 3.5.2.1).

Consequência direta no DDL: cardinalidade mínima 1 na ponta que recebe a FK ⇒ `NOT NULL`; mínima 0 ⇒ coluna anulável.

### Relacionamento binário vs. n-ário

O que define o grau é o **número de ocorrências de entidade em cada ocorrência do relacionamento**, não o número de retângulos. Auto-relacionamento (`CASAMENTO` entre duas `PESSOA`) é **binário**.

Em relacionamento ternário, cardinalidade se refere a **pares**: em `DISTRIBUICAO(PRODUTO, CIDADE, DISTRIBUIDOR)`, o `1` junto a `DISTRIBUIDOR` significa "cada par (produto, cidade) tem no máximo um distribuidor" (Heuser, cap. 2.2.5). Essa restrição **não é expressável** com três relacionamentos binários — é a única razão real para manter um ternário no modelo.

### Auto-relacionamento e papéis

Papéis são obrigatórios quando a mesma entidade aparece duas vezes (marido/esposa, supervisor/supervisionado). Entre entidades diferentes são óbvios e omitidos.

Limite conhecido (Heuser, cap. 3.1.2): o DER **não expressa restrições recursivas**. Uma hierarquia de supervisão sem ciclos, ou "produto não pode estar em sua própria composição" com profundidade ilimitada, não cabe no diagrama — documente fora dele e implemente com `CHECK`/trigger/consulta recursiva.

### Identificadores

Duas propriedades obrigatórias:

1. **Mínimo** — retirar qualquer componente destrói a identificação. `(codigo, nome)` não é identificador se `codigo` basta.
2. **Único por entidade** — se `codigo` e `CPF` ambos identificam, escolha **um**. O outro vira chave alternativa (`UNIQUE`).

**Identificador externo / relacionamento identificador**: quando a entidade só é identificada junto com a entidade relacionada. `DEPENDENTE` é identificado por `EMPREGADO` + `numero_sequencia`. Alguns autores chamam isso de **entidade fraca**; Heuser desaconselha o termo (cap. 2.3.1): pelo critério, `EMPRESA` e `FILIAL` seriam "fracas" e, no entanto, são centrais no modelo. Use "entidade com relacionamento identificador" e decida pela estrutura, não pelo rótulo.

**Identificador de relacionamento**: por padrão uma ocorrência de relacionamento é identificada pelas entidades que associa — logo, no máximo um par (engenheiro, projeto). Se pode haver vários (várias consultas entre o mesmo médico e paciente; várias transferências entre as mesmas duas contas), é preciso um **atributo identificador do relacionamento** (`data_hora`).

---

## 2. Heurísticas de modelagem que valem decisão

**Atributo ou entidade?** (Heuser, cap. 3.2.1) — dois critérios, ambos decisivos:
- O objeto tem propriedades próprias, se relaciona, ou é especializado? → **entidade**. Atributo não sustenta nada disso.
- O conjunto de valores muda em runtime (existe transação que cria/apaga valores)? → **entidade**. Domínio fixo pela vida do sistema → atributo (ou `enum`).

Em finanças: `moeda` com lista fixa → atributo/enum. `categoria` que o usuário cria e edita → entidade `category` com FK.

**Atributo ou especialização?** (cap. 3.2.2) — só especialize se as classes têm **propriedades particulares** (atributos, relacionamentos). Sexo do empregado, sem propriedades próprias, é atributo. Motorista/engenheiro, cada um com atributos e relacionamentos próprios, é especialização.

**Atributo opcional é um cheiro** (cap. 3.2.3.1): vários atributos opcionais numa entidade geralmente escondem uma especialização, e o modelo com opcionais não diz **quais combinações são válidas** (posso ter data de validade da CNH sem número da CNH?). Sempre que aparecer opcional, teste se especialização não é mais fiel.

**Atributo multi-valorado é sempre transformável** (cap. 3.2.3.2): não tem implementação direta em SQL/2, e frequentemente esconde entidade+relacionamento. Vire entidade relacionada. (Exceção deliberada em §7.)

**Modelo mínimo — sem redundâncias** (cap. 3.3.3):
- *Relacionamento redundante*: derivável de outros. `MAQUINA—FABRICA` é redundante se existem `MAQUINA—DEPARTAMENTO` e `DEPARTAMENTO—FABRICA`.
- *Atributo redundante*: derivável por busca ou cálculo. `numero_de_empregados` (contagem), `codigo_do_departamento` dentro de `EMPREGADO` (isso é FK, detalhe de implementação — **não vai ao modelo conceitual**, cap. 3.3.3 nota 5).

Critério: o DER não distingue derivado de armazenado, então derivado no DER vira redundância não controlada no banco. Redundância por performance é decisão do **projeto lógico** (§7), com o custo assumido.

**Aspecto temporal** (cap. 3.3.4) — o padrão mais recorrente e mais esquecido:

| Requisito | Efeito no modelo |
|---|---|
| guardar histórico de um atributo | atributo vira entidade (`SALARIO(data, valor)`) |
| guardar histórico de um relacionamento 1:1 ou 1:n | vira **n:n**, e normalmente ganha atributo identificador (`data`) |
| histórico de um n:n | o atributo `data` passa a ser **identificador** do relacionamento |
| histórico de 1:n | atributos da entidade podem **migrar para o relacionamento** (ex.: `n_documento_lotacao`) |

Em finanças: `CONTA —1:n— SALDO_ATUAL` é errado se o requisito é extrato; `CONTA —n:n— ...` com data identificadora é a forma histórica. Planeje também **descarte/arquivamento** desde a modelagem: se dados antigos saem do banco, planeje o retorno em cascata (as ocorrências relacionadas precisam voltar juntas) ou guarde só agregados.

**Entidade isolada / sem atributos** (cap. 3.3.5): não é erro, mas é raro — investigue. A entidade que modela a própria organização (`UNIVERSIDADE`, `LOCADORA`) costuma ficar isolada legitimamente: como há uma única ocorrência, não faz sentido relacionar `ALUNO` a ela.

**Estratégias de construção** (cap. 3.5), escolhidas pela fonte de informação:
- Fonte = descrições de dados existentes (arquivos, documentos) → **bottom-up**: parte de atributos, agrega em entidades. É a engenharia reversa.
- Fonte = conhecimento de pessoas → **top-down** (entidades genéricas → atributos → relacionamentos → cardinalidades mínimas por último → validação) ou **inside-out** (parte da entidade central e vai adicionando periferia).

---

## 3. Modelo relacional — o mínimo que muda decisão

- **Tabela**: conjunto **não ordenado** de linhas; campos **atômicos e mono-valorados**. Ordem não é informação (Heuser, cap. 4.1.1). Se a ordem importa (classificação, sequência de apresentação), ela precisa virar **coluna explícita**.
- **Chave primária**: coluna(s) com valores únicos, **mínima**, sempre `NOT NULL`.
- **Chave alternativa**: outra combinação única não escolhida como PK.
- **Chave estrangeira**: coluna(s) cujos valores aparecem necessariamente na PK referenciada. Pode referenciar a **própria tabela** ("estrangeira" não implica outra tabela).
- **Domínio** + **vazio (NULL)**: `NULL` ≠ zero. Heuser insiste na distinção (cap. 4.1.3).

**Por que PK e não chave alternativa?** Considerada isoladamente, não há diferença — ambas são unicidade. A diferença é que **a PK é a coluna que as FKs referenciam** (cap. 4.1.2.3). Critério de escolha: prefira a chave **curta e estável**; nomes e atributos grandes geram índices ineficientes (cap. 7, sol. ex. 3.6). Na prática moderna: chave sintética (`uuid`/`bigint identity`), com o identificador natural como `UNIQUE`.

Restrições garantidas pelo SGBD: **domínio**, **vazio** (`NOT NULL`), **chave** (`UNIQUE`), **referencial** (`FOREIGN KEY`). Tudo além disso é **restrição semântica** — vai para `CHECK`, trigger ou aplicação, e deve ser documentada fora do DER.

Integridade referencial é checada em três momentos: INSERT na tabela da FK, UPDATE da FK, DELETE da linha referenciada.

---

## 4. Tradução ER → relacional: as três formas e a tabela de decisão

Os princípios que geram as regras (Heuser, cap. 5.2) — use-os para arbitrar casos fora da tabela:

1. **Evitar junções** — dados de uma consulta na mesma linha.
2. **Diminuir o número de chaves primárias** — cada PK custa um índice; duas tabelas com a mesma PK e relação 1-para-1 duplicam armazenamento e processamento.
3. **Evitar campos opcionais** — sobretudo quando a obrigatoriedade de um campo depende do valor de outro, controle que o SGBD não faz.

Três formas de traduzir um relacionamento:

- **Tabela própria** — colunas = identificadores das entidades + atributos do relacionamento; PK = identificadores das entidades; cada bloco é FK.
- **Adição de colunas** — insere na tabela da entidade de **cardinalidade máxima 1** as colunas do identificador da outra (FK) + atributos do relacionamento.
- **Fusão de tabelas** — só para 1:1; tudo numa tabela só.

**Tabela de decisão (Heuser, tab. 5.1)** — ✔ preferida, ○ aceitável, ✕ não usar:

| Relacionamento | Tabela própria | Adição de colunas | Fusão |
|---|:--:|:--:|:--:|
| 1:1 `(0,1)–(0,1)` | ○ | ✔ | ✕ |
| 1:1 `(0,1)–(1,1)` | ✕ | ○ | ✔ |
| 1:1 `(1,1)–(1,1)` | ✕ | ○ | ✔ |
| 1:n `(0,1)–(0,n)` | ○ | ✔ | ✕ |
| 1:n `(0,1)–(1,n)` | ○ | ✔ | ✕ |
| 1:n `(1,1)–(0,n)` | ✕ | ✔ | ✕ |
| 1:n `(1,1)–(1,n)` | ✕ | ✔ | ✕ |
| n:n (qualquer mínima) | ✔ | ✕ | ✕ |

### 4.1 Entidade → tabela

Cada entidade vira tabela; cada atributo, coluna; atributos identificadores, PK.

Nomes (cap. 5.2.1.1): colunas curtas, sem espaço, **sem repetir o nome da tabela** (`account.name`, não `account.account_name`) — **exceto a PK**, que aparecerá como FK em outras tabelas e por isso deve ser qualificada (`account_id`). Abreviaturas consistentes em todo o banco.

```sql
CREATE TABLE account (
  account_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text        NOT NULL,
  kind        text        NOT NULL,          -- domínio fixo → atributo, não entidade
  opened_at   date        NOT NULL
);
```

### 4.2 Relacionamento identificador (identificador externo)

Regra: para cada identificador externo, crie coluna(s) na tabela — e elas **entram na PK** (cap. 5.2.1.2). A composição pode encadear vários níveis: `Dependente(CodGrup, NoEmpresa, NoEmpreg, NoSeq)`.

```sql
-- INSTALLMENT (parcela) é identificada pela transação + número da parcela
CREATE TABLE installment (
  transaction_id bigint  NOT NULL REFERENCES transaction (transaction_id),
  seq            integer NOT NULL,
  due_date       date    NOT NULL,
  amount_cents   bigint  NOT NULL,
  PRIMARY KEY (transaction_id, seq)          -- FK dentro da PK
);
```
*Trade-off:* PK composta propaga-se para tabelas filhas (chaves cada vez mais largas). Alternativa prática: PK sintética + `UNIQUE (transaction_id, seq)` — preserva a semântica do identificador e mantém as FKs estreitas. **Nota prática:** com Prisma, `@@id([transactionId, seq])` vs. `@@unique`; a segunda evita chaves compostas em relações aninhadas.

### 4.3 Relacionamento 1:n → adição de colunas (sempre preferida)

FK vai na tabela do lado `1`. Mínima 1 daquele lado ⇒ `NOT NULL`.

```sql
-- CATEGORY (0,n) —— (1,1) TRANSACTION : toda transação tem exatamente uma categoria
CREATE TABLE category (
  category_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text   NOT NULL UNIQUE
);

CREATE TABLE transaction (
  transaction_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id     bigint NOT NULL REFERENCES account (account_id),
  category_id    bigint NOT NULL REFERENCES category (category_id),  -- (1,1) → NOT NULL
  occurred_at    timestamptz NOT NULL,
  amount_cents   bigint NOT NULL
);
```

Quando o lado `1` é **opcional** `(0,1)`, a tabela própria vira alternativa legítima (cap. 5.2.3.2). Exemplo do livro: `VENDA (0,1) —— (0,n) FINANCEIRA`, com atributos `n_parcelas` e `taxa_juros` no relacionamento.

```sql
-- Preferida: colunas em transaction, opcionais em bloco
ALTER TABLE transaction
  ADD COLUMN financier_id     bigint REFERENCES financier (financier_id),
  ADD COLUMN installments     integer,
  ADD COLUMN interest_rate    numeric(6,4),
  ADD CONSTRAINT financing_all_or_nothing CHECK (
    num_nonnulls(financier_id, installments, interest_rate) IN (0, 3)
  );
```
*Trade-off (cap. 5.2.3.2):* a adição de colunas evita junção e evita a segunda PK; o preço é o **bloco de colunas opcionais que só é válido tudo-preenchido ou tudo-vazio** — controle que o SGBD clássico não faz. Em PostgreSQL esse argumento **enfraquece**: `CHECK` com `num_nonnulls` devolve o controle ao SGBD. **Critério:** com o `CHECK` acima, fique na adição de colunas. Use tabela própria só se o bloco opcional for grande, raramente preenchido e raramente lido junto.

### 4.4 Relacionamento 1:1

- **Ambos obrigatórios `(1,1)–(1,1)`** → **fusão**. As duas outras alternativas produziriam duas tabelas com a mesma PK e relação 1-para-1 — violam os princípios 1 e 2 diretamente.
- **Um obrigatório, outro opcional** → **fusão** também é a preferida; alternativa: colunas na tabela do lado `(0,1)`.
- **Ambos opcionais `(0,1)–(0,1)`** → **adição de colunas** (qualquer lado, escolha arbitrária); tabela própria é a segunda opção, e a PK é uma das FKs (a outra vira chave alternativa).

```sql
-- (1,1)–(1,1): CONFERENCIA —— COMISSAO ORGANIZADORA  → fusão
-- Em finanças: CARD (1,1) —— (1,1) CARD_SETTINGS  → uma tabela só
CREATE TABLE card (
  card_id        bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id     bigint NOT NULL REFERENCES account (account_id),
  last4          char(4) NOT NULL,
  closing_day    smallint NOT NULL,   -- veio de card_settings
  due_day        smallint NOT NULL    -- veio de card_settings
);
```
*Critério para quebrar a regra da fusão (cap. 7, sol. ex. 5.1):* se os dois blocos de atributos são alterados por **transações diferentes e concorrentes**, a fusão serializa os UPDATEs (o SGBD trava a linha). Aí duas tabelas ganham. É a única justificativa forte contra a fusão.

### 4.5 Relacionamento n:n → sempre tabela própria

Não há alternativa: adição de colunas exigiria coluna multi-valorada, o que o modelo relacional não tem (cap. 5.2.3.3). Independe das mínimas.

```sql
-- TRANSACTION (0,n) —— (0,n) TAG, com atributo do relacionamento
CREATE TABLE transaction_tag (
  transaction_id bigint NOT NULL REFERENCES transaction (transaction_id),
  tag_id         bigint NOT NULL REFERENCES tag (tag_id),
  weight_pct     numeric(5,2),                 -- atributo do relacionamento
  PRIMARY KEY (transaction_id, tag_id)         -- identificado pelas entidades
);
```

Se pode haver **mais de uma ocorrência entre o mesmo par**, o relacionamento precisa de atributo identificador, que **entra na PK**:

```sql
-- TRANSFER: várias transferências entre as mesmas duas contas
CREATE TABLE transfer (
  from_account_id bigint      NOT NULL REFERENCES account (account_id),
  to_account_id   bigint      NOT NULL REFERENCES account (account_id),
  occurred_at     timestamptz NOT NULL,        -- atributo identificador
  amount_cents    bigint      NOT NULL,
  PRIMARY KEY (from_account_id, to_account_id, occurred_at),
  CHECK (from_account_id <> to_account_id)     -- restrição semântica, fora do DER
);
```

### 4.6 Relacionamento de grau > 2

Não há regra própria (cap. 5.2.3.4). Procedimento: **transforme em entidade** ligada por um relacionamento binário `(1,1)` a cada entidade original, depois aplique as regras binárias. Resultado: tabela com as três FKs na PK.

```sql
Distribuicao (CodProd, CodDistr, CodCid, Nome)   -- as três colunas são PK e FK
```

### 4.7 Entidade associativa

Um relacionamento redefinido como entidade, para poder ser relacionado a outras (`CONSULTA` precisa se ligar a `MEDICAMENTO`). No relacional **não muda nada**: a tabela do n:n existe e é referenciada normalmente. Entidade associativa e "n:n transformado em entidade" geram **o mesmo banco** — são modelos equivalentes (cap. 3.1.3), e discutir qual usar é perda de tempo.

**Transformação n:n → entidade** (procedimento, cap. 3.1.3): (1) o relacionamento vira entidade; (2) ligada às entidades originais; (3) identificada por essas entidades + os atributos identificadores originais; (4) cardinalidade da nova entidade nos novos relacionamentos é sempre `(1,1)`; (5) as cardinalidades originais são transcritas. É por isso que notações que não têm n:n (Engenharia de Informações) não perdem poder de expressão.

---

## 5. Generalização/especialização

Semântica em Heuser (cap. 2.4): herança de atributos, relacionamentos, identificador e demais especializações. Classificação em dois eixos:

| Eixo | Valores | Símbolo | Efeito |
|---|---|---|---|
| Cobertura | **total** / **parcial** | `t` / `p` | total: toda ocorrência genérica está em alguma especialização |
| Exclusividade | **exclusiva** / não exclusiva | — | exclusiva: a ocorrência aparece em no máximo uma folha |

Regra prática: na **parcial**, a entidade genérica costuma ganhar um atributo `tipo`. Na **total** ele é dispensável — a presença na tabela filha já identifica.

**Especialização não exclusiva é proibida no livro** e a razão é técnica, não estilística (cap. 2.4): as especializadas **não podem herdar o identificador do genérico** — uma pessoa pode ser professor duas vezes. Modele com **relacionamentos** entre `PESSOA` e as entidades de papel. Regra derivada: *papéis acumuláveis → relacionamento; subtipos disjuntos com atributos próprios → especialização.*

Herança múltipla e múltiplos níveis são admitidos.

### 5.1 As três alternativas de tradução

**(a) Tabela única para toda a hierarquia** (cap. 5.2.4.1) — PK do genérico; coluna `tipo` se não existir; uma coluna por atributo do genérico; uma coluna **opcional** por atributo de cada especializada; FKs das especializadas também opcionais. Uma especializada sem atributos e sem FKs próprios (ex.: `SECRETARIA`) **não gera coluna nenhuma**.

```sql
CREATE TABLE party (
  party_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind      text   NOT NULL CHECK (kind IN ('individual','company')),
  name      text   NOT NULL,
  cpf       text,          -- só individual
  birth_date date,         -- só individual
  cnpj      text,          -- só company
  legal_name text,         -- só company
  CHECK (kind <> 'individual' OR (cpf IS NOT NULL AND cnpj IS NULL)),
  CHECK (kind <> 'company'    OR (cnpj IS NOT NULL AND cpf IS NULL))
);
```

**(b) Uma tabela por entidade** (cap. 5.2.4.2) — genérico e cada especializada viram tabela, **todas com a mesma PK**; a PK da especializada é também **FK para o genérico** (porque a toda ocorrência especializada corresponde uma genérica).

```sql
CREATE TABLE party (
  party_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind     text NOT NULL,
  name     text NOT NULL
);
CREATE TABLE individual (
  party_id   bigint PRIMARY KEY REFERENCES party (party_id),  -- PK = FK
  cpf        text NOT NULL UNIQUE,
  birth_date date NOT NULL
);
CREATE TABLE company (
  party_id   bigint PRIMARY KEY REFERENCES party (party_id),
  cnpj       text NOT NULL UNIQUE,
  legal_name text NOT NULL
);
```

**(c) Uma tabela por folha, com os atributos herdados** (cap. 5.2.4.3.1) — cada folha carrega também os atributos do genérico. Se a especialização é **parcial**, existe ainda uma tabela para os "demais" (`EmpOutros`); se **total**, ela desaparece.

```sql
CREATE TABLE individual (party_id bigint PRIMARY KEY, name text NOT NULL, cpf text NOT NULL, ...);
CREATE TABLE company    (party_id bigint PRIMARY KEY, name text NOT NULL, cnpj text NOT NULL, ...);
-- não existe tabela party
```

### 5.2 Trade-offs — e o critério de decisão

| | (a) tabela única | (b) tabela por entidade | (c) tabela por folha |
|---|---|---|---|
| Junções para ler genérico+especializado | nenhuma | 1 junção | nenhuma |
| PK armazenada | 1 vez | 2 vezes (índice duplicado) | 1 vez |
| Colunas opcionais | **todas** as das especializadas | só as opcionais de fato | nenhuma |
| Quem controla a opcionalidade | aplicação (via `tipo`) | SGBD | — |
| FK apontando para "o conjunto todo" | possível | possível | **impossível** |
| Unicidade da PK no conjunto | SGBD | SGBD | **aplicação**, varrendo todas as folhas |

**Decisão (Heuser, cap. 5.2.4.3 e 5.2.4.3.1):**

- **(c) está descartada na prática.** As vantagens de eficiência são sobrepujadas por dois defeitos funcionais: a aplicação passa a garantir unicidade da PK varrendo todas as folhas, e **não existe tabela onde referenciar o conjunto todo** — nenhuma FK pode apontar para "qualquer party". Só considere se nada referencia o genérico e a especialização é total.
- Entre **(a)** e **(b)**: escolha **(a)** quando as especializadas têm poucos atributos, o `tipo` é lido em quase toda consulta, e a hierarquia é estável. Escolha **(b)** quando as especializadas têm muitos atributos próprios, o genérico é consultado sozinho com frequência, ou você quer o SGBD garantindo obrigatoriedade dos campos do subtipo. **Nota prática:** o argumento de Heuser contra (a) — "o controle das opcionais passa para a aplicação" — é parcialmente neutralizado em PostgreSQL por `CHECK` condicional, como no exemplo acima. Com isso, (a) fica mais atraente do que o livro sugere. Contra (a), sobra o custo real de tabelas largas e esparsas. **Nota prática (Prisma):** o ORM não modela herança; (a) vira um model com campos opcionais + enum; (b) vira models separados com relação 1:1 obrigatória — mais verboso, mais tipado.

---

## 6. Engenharia reversa: relacional → ER

Útil quando o banco não tem modelo conceitual: legado, schema que evoluiu sem documentação, migração de plataforma. Quatro passos (Heuser, cap. 5.3).

**Passo 1 — classificar cada tabela pela composição da PK:**

| Regra | Condição da PK | Construção ER |
|---|---|---|
| 1 | PK composta por **mais de uma FK** | **relacionamento n:n** entre as entidades referenciadas |
| 2 | PK é **toda ela** uma FK | **entidade especializada** da tabela referenciada |
| 3 | demais casos | **entidade** |

Cuidado com a regra 3: `Sala(CodPr, CodSl)` com só `CodPr` sendo FK **não** cai na regra 1 (uma FK só) nem na 2 (a PK não é toda FK) — é entidade, com relacionamento identificador.

**Passo 2 — relacionamentos 1:n / 1:1:** toda FK que **não** caiu nas regras 1 ou 2 é um relacionamento 1:n ou 1:1. O schema **não diz qual** — é preciso verificar os conteúdos possíveis do banco (ou constatar um `UNIQUE` sobre a FK, que força 1:1).

**Passo 3 — atributos:** cada coluna **não-FK** vira atributo. Colunas FK são relacionamentos, já tratadas.

**Passo 4 — identificadores:** coluna da PK que não é FK → **atributo identificador**; coluna da PK que é FK → **identificador externo** (relacionamento identificador).

**Cardinalidades deriváveis do schema** (cap. 7, sol. ex. 5.4) — a cadeia de inferência:
- FK ⇒ máxima 1 daquele lado (colunas são mono-valoradas).
- FK **dentro da PK** ⇒ é `NOT NULL` ⇒ **mínima 1**.
- FK fora da PK e anulável ⇒ mínima 0; `NOT NULL` ⇒ mínima 1.
- A cardinalidade da **outra direção** (quantas linhas filhas por pai) **não é derivável** do schema. Só o domínio responde.

**Limites — o que a engenharia reversa não conserta** (cap. 6.8 e cap. 7, sol. ex. 6.10):
- Não detecta **relacionamentos redundantes** (aparecem porque a PK os carregou).
- Reproduz anomalias do legado: dois relacionamentos separados para "autor principal" e "autores" onde caberia um só com atributo `principal`.
- Chave primária omitida no documento vira atributo espúrio (`assunto_principal` como texto em vez de FK para `TEMA`).
- Sempre termine com **verificação do modelo ER obtido**, aplicando §2.

Contexto (cap. 6): quando a fonte não é um banco relacional mas arquivos/documentos, o processo é ÑN → 1FN → 2FN → 3FN (→ 4FN) por arquivo, depois **integração de modelos** (funde tabelas com a mesma PK; elimina tabela que só tem PK contida em outra — mas só se os valores forem realmente os mesmos), e **então** as regras acima. Detalhes em referência de normalização.

---

## 7. Refinamento do modelo relacional (desnormalizações deliberadas)

Só depois de o modelo pelas regras não atender performance (cap. 5.2.5). Todas são **piores** para desenvolvimento; assuma o custo conscientemente.

**Relacionamentos mutuamente exclusivos** (5.2.5.1): entidade que participa de exatamente um de dois relacionamentos. Regra normal gera duas FKs opcionais. Alternativa: uma coluna só + coluna `tipo`.

```sql
-- Venda é para pessoa física OU jurídica
Venda(No, data, CIC/CGC, TipoCompr)
```
*Custo:* a coluna deixa de ser FK — o SGBD não valida nada, porque ela referencia duas tabelas alternadamente. **Critério:** na dúvida, não faça; prefira as duas FKs opcionais com `CHECK (num_nonnulls(a_id, b_id) = 1)`, que preserva integridade referencial.

**Simular atributo multi-valorado** (5.2.5.2): `Cliente(CodCli, Nome, NumTel1, NumTel2)` em vez de tabela `Telefone`. Condições de contorno explícitas no livro: (i) raríssimo ter mais que N valores e truncar é aceitável; (ii) **nenhuma consulta usa o valor como critério de busca**. Ganho: sem junção, sem PK extra. Custo: busca por telefone tem de varrer todas as colunas. **Nota prática:** em PostgreSQL, `text[]` ou `jsonb` cobre o mesmo caso com índice GIN — o critério (ii) deixa de ser bloqueante, mas o dado continua sem FK e sem tipo forte. Só faça se ele nunca se relacionar com nada.

**Atributo redundante/derivado** (5.2.5.3): `VOO.numero_de_reservas` é contagem — fora do modelo conceitual. No projeto lógico, se for lido com muita frequência ou servir de critério de busca, materialize. **Critério:** materialize quando o custo de recomputar × frequência de leitura supera o custo de manter sincronia; e então garanta a sincronia com trigger/transação, transformando redundância não controlada em **controlada**. Em finanças, `account.balance_cents` é o caso canônico.

---

## 8. Notações — ler qualquer diagrama

| Conceito | **Chen** (Heuser) | **Engenharia de Informações / James Martin** (≈ crow's foot, ferramentas CASE, Oracle, Barker) | **MERISE** |
|---|---|---|---|
| Entidade | retângulo | retângulo | retângulo |
| Relacionamento | **losango** | **apenas uma linha** | **elipse** |
| Atributo | elipse ligada (na prática, texto à parte) | só em entidades | texto |
| Cardinalidade | `(mín,máx)` textual, **do lado oposto** | gráfica: símbolo **mais próximo** do retângulo = máxima; **mais distante** = mínima | `mín,máx` junto à entidade |
| Generalização | triângulo com `t`/`p` | **aninhamento** de retângulos (subtipo dentro do supertipo) | — |
| Nome do relacionamento | um nome | **verbo nas duas direções** ("tem lotado" / "está lotado em") | um nome |

Diferenças que mudam o modelo, não só o desenho:
- **Engenharia de Informações só admite relacionamentos binários** (uma linha liga dois retângulos) e **atributos só em entidades**. Consequência: o que seria n:n com atributos em Chen tende a virar **entidade** ali; ternários viram entidade + três binários. Como as duas formas são equivalentes (§4.7), não há perda.
- **MERISE muda a semântica da cardinalidade**: Chen usa **semântica associativa** ("a uma ocorrência de A estão associadas quantas de B"); MERISE usa **semântica participativa** ("quantas vezes uma ocorrência de A participa do relacionamento"). Por isso a anotação troca de lado. Ler MERISE com olhos de Chen inverte o modelo.

Ler o par `(0,n)` / `(1,1)` num diagrama Chen: a anotação está **junto ao símbolo da entidade oposta** àquela a que se refere. Essa convenção é a fonte nº 1 de erro de leitura.

**Nota prática:** o crow's foot moderno (dbdiagram, DBeaver, Prisma ERD) é a família Engenharia de Informações: pé-de-galinha = máxima n; traço = máxima 1; círculo = mínima 0; traço adicional = mínima 1. Símbolo **mais próximo da entidade é a máxima**.

Padronização (cap. 3.4): escolha **uma** notação e treine todos os envolvidos — inclusive usuários. Um DER é um modelo **formal e não ambíguo**; a aparência gráfica intuitiva dá a falsa impressão de ser compreensível sem treino, e o resultado clássico é usuário aprovando um modelo que não entendeu (cap. 3.1.1).
