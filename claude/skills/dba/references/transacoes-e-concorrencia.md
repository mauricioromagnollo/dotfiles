# Transações e Concorrência

Abra esta referência quando precisar decidir: que nível de isolamento usar num fluxo, se um `SELECT ... FOR UPDATE` é necessário, por que dois requests simultâneos corromperam um saldo, se um erro `40001` deve virar retry ou 500, ou quando alguém propuser "resolver com lock" algo que o banco já resolve. Ela cobre a teoria (Elmasri, cap. 21–23) e a tradução dela para o PostgreSQL real que o projeto usa via Prisma.

---

## 1. Transação: o que é e por que existe

Uma transação é um programa em execução que forma **uma unidade lógica de processamento de banco de dados** — uma ou mais operações de acesso (insert, delete, update, select) tratadas como indivisíveis (Elmasri, cap. 21.1.2).

O modelo teórico reduz tudo a duas operações sobre itens de dados nomeados:

- `read_item(X)`: localiza o bloco de disco de X, copia para um buffer da cache do SGBD, copia para a variável do programa.
- `write_item(X)`: localiza o bloco, traz para o buffer, escreve o valor no buffer e — **em algum momento posterior** — grava o buffer no disco.

Esse "em algum momento posterior" é a origem de metade dos problemas de recuperação: o commit lógico e a gravação física não coincidem.

Termos que reaparecem: **read set** / **write set** (itens que a transação lê / grava) e **granularidade** (o tamanho do item de dados — campo, registro, bloco, arquivo, banco inteiro; a teoria é independente dela, o desempenho não é — §7).

**Por que existe**: sem transação, duas coisas quebram — a execução concorrente intercalada produz estados inconsistentes (§3), e falhas no meio da execução deixam efeitos parciais (§9).

O gerenciador de recuperação rastreia `BEGIN_TRANSACTION`, `READ`/`WRITE`, `END_TRANSACTION`, `COMMIT_TRANSACTION` e `ROLLBACK`/`ABORT` (cap. 21.2.1).

### Estados

```
                    ┌──────────────────────────────────┐
  begin_transaction │                                  │
        ──────────► ATIVA ──end_transaction──► PARCIALMENTE ──commit──► CONFIRMADA
                      │                         CONFIRMADA                  │
                   abort/                            │                      │
                   erro │                         abort │                   │
                      ▼                              ▼                      ▼
                    FALHA ──────────────────────► TERMINADA ◄───────────────┘
```

**Ativa**: executa READ/WRITE. **Parcialmente confirmada**: terminou as operações, mas o sistema ainda precisa garantir que uma falha não impeça o registro permanente das mudanças (tipicamente: gravar o log); controle de concorrência otimista também valida aqui. **Ponto de confirmação**: todas as operações executaram com sucesso **e** o efeito de todas está registrado no log em disco — só então grava-se `[commit, T]`. Depois: **confirmada** / **falha** / **terminada** (sai do sistema; entradas nas tabelas do sistema são removidas).

**Nota prática:** no Postgres o `[commit, T]` é o registro de commit no WAL. `synchronous_commit = off` faz o commit retornar antes do WAL chegar ao disco — negocia durabilidade por latência. Para lançamentos financeiros, mantenha `on`.

---

## 2. ACID — o que cada letra garante e o que NÃO garante

(Elmasri, cap. 21.3)

| Letra | Garante | **NÃO** garante | Quem impõe |
|---|---|---|---|
| **A**tomicidade | Ou toda a transação é aplicada, ou nenhuma parte dela | Que o resultado esteja *correto*; que não haja interferência de outras transações | Subsistema de **recuperação** |
| **C**onsistência | Que uma transação executada **isoladamente, do início ao fim**, leve o banco de um estado consistente a outro | Nada sob concorrência. E o próprio "consistente" é definição sua: constraints do schema + invariantes de negócio | **Você** (o programador) + constraints do SGBD |
| **I**solamento | Que a transação *pareça* executar sozinha | Isolamento total, na prática: é um dial com níveis (§5) | Subsistema de **controle de concorrência** |
| **D**urabilidade | Que mudanças de transação confirmada persistam apesar de falhas | Sobrevivência a falha catastrófica sem backup/replicação (§9.7) | Subsistema de **recuperação** |

Os três pontos que mais geram erro de projeto:

1. **O "C" é o mais fraco do acrônimo.** Elmasri é explícito: a preservação da consistência "geralmente é considerada uma responsabilidade dos programadores que escrevem os programas de banco de dados ou do módulo de SGBD que impõe restrições de integridade" (cap. 21.3). O banco não sabe que `saldo >= 0`. Se essa invariante importa, ela é uma `CHECK`, uma constraint ou um lock — não um efeito colateral do `BEGIN`.
2. **Atomicidade não é isolamento.** Uma transação atômica pode perder uma atualização (§3.1). `prisma.$transaction([...])` te dá A e D; I depende do nível e dos locks.
3. **O "I" é parcial por padrão.** Elmasri já cataloga níveis de isolamento 0–3 (nível 0: não sobrescreve leituras sujas de níveis maiores; 1: sem lost update; 2: sem lost update nem dirty read; 3, "isolamento verdadeiro": nível 2 + leituras repetitivas) e a SQL padroniza quatro (§5). O default do Postgres não é serializável.

---

## 3. As anomalias de concorrência

Cenário base do projeto: `bank_accounts.initial_balance` mais a soma de `transactions.amount` daquela conta. Onde escrevo `saldo` abaixo, leia "a linha de conta e seus lançamentos".

### 3.1 Lost update (atualização perdida)

Duas transações leem o mesmo item, ambas calculam a partir do valor lido, ambas escrevem. A segunda escrita sobrescreve a primeira: a atualização de T₁ **é perdida** (Elmasri, cap. 21.1.3).

```
T1 (transfere 5 de X p/ Y)        T2 (deposita 4 em X)      X (inicial 80)
────────────────────────────      ──────────────────────    ─────────────
read_item(X)          -> 80                                       80
X := X - 5            (=75)
                                  read_item(X)     -> 80          80
                                  X := X + 4       (=84)
write_item(X)                                                     75
                                  write_item(X)                   84  ← errado
read_item(Y); Y := Y+5; write_item(Y)
```

Resultado correto seria 79; ficou 84. A subtração de T₁ desapareceu.

```sql
-- O padrão quebrado (read-modify-write no app), rodando em T1 e T2:
BEGIN;
SELECT initial_balance FROM bank_accounts WHERE id = $1;       -- app lê 80
UPDATE bank_accounts SET initial_balance = 75 WHERE id = $1;   -- valor literal!
COMMIT;

-- Correções, em ordem de preferência:
-- (a) deixe o banco calcular — atômico, sem read-modify-write
UPDATE bank_accounts SET initial_balance = initial_balance - 5 WHERE id = $1;
-- (b) se precisa ler, decidir e depois escrever: pegue o lock na leitura
SELECT initial_balance FROM bank_accounts WHERE id = $1 FOR UPDATE;
-- (c) optimistic locking: 0 linhas afetadas => alguém passou na frente => retry
UPDATE bank_accounts SET initial_balance = 75, version = version + 1
 WHERE id = $1 AND version = $2;
```

**Nota prática:** `prisma.bankAccount.update({ data: { initialBalance: { decrement: 5 } } })` gera a forma (a) e é seguro contra lost update mesmo em Read Committed. `update({ data: { initialBalance: valorCalculadoNoNode } })` é a forma quebrada.

### 3.2 Dirty read (leitura suja / atualização temporária)

T₂ lê um valor que T₁ escreveu e **ainda não confirmou**; T₁ aborta; T₂ trabalhou com um valor que nunca existiu (Elmasri, cap. 21.1.3).

```
T1                                T2                        X (inicial 80)
─────────────────────             ──────────────────        ─────────────
read_item(X)          -> 80
X := X - 5
write_item(X)                                                     75
                                  read_item(X)   -> 75    ← dado sujo
                                  X := X + 4     (=79)
                                  write_item(X)                   79
read_item(Y)
*** T1 FALHA -> rollback: X volta a 80 ***                        80 ?!
```

**Nota prática: o PostgreSQL nunca permite dirty read.** Nem no nível `READ UNCOMMITTED` — ele é aceito na sintaxe e silenciosamente tratado como `READ COMMITTED`. O MVCC do Postgres nem tem como expor uma versão não confirmada: cada tupla carrega o xmin/xmax da transação que a criou/removeu, e a visibilidade é decidida pelo snapshot. Não gaste tempo defendendo contra dirty read no Postgres.

### 3.3 Non-repeatable read (leitura não repetitiva)

T lê o mesmo item duas vezes; outra transação o alterou (e confirmou) entre as leituras; T vê valores diferentes para a mesma linha (Elmasri, cap. 21.1.3 e 21.6).

```
T1 (relatório do usuário)          T2 (edita lançamento)
──────────────────────────         ──────────────────────
BEGIN;
SELECT amount FROM transactions
  WHERE id = 'tx-1';   -> 100.00
                                   BEGIN;
                                   UPDATE transactions
                                     SET amount = 250.00 WHERE id='tx-1';
                                   COMMIT;
SELECT amount FROM transactions
  WHERE id = 'tx-1';   -> 250.00   ← mesma linha, valor diferente
COMMIT;
```

**Critério:** só importa se a transação lê a mesma linha duas vezes e assume estabilidade. Se cada leitura alimenta um cálculo independente, tolerável. Se o segundo `SELECT` valida uma decisão tomada no primeiro, é bug — use `REPEATABLE READ` ou `FOR UPDATE` na primeira leitura.

### 3.4 Phantom (fantasma)

T lê um **conjunto** de linhas por um predicado; outra transação **insere** (ou atualiza para dentro do predicado) uma linha que satisfaz a mesma condição; T repete a leitura e vê uma linha que "apareceu do nada" (Elmasri, cap. 21.6 e 22.7.1).

O ponto sutil (cap. 22.7.1): **as duas transações conflitam logicamente, mas não há item de dados em comum entre elas** — T pode ter bloqueado todas as linhas com `bank_account_id = A` *antes* de a outra inserir a nova. O protocolo de lock em registros não enxerga o conflito.

```
T1 (soma gastos do mês da conta A)   T2 (insere lançamento na conta A, mesmo mês)
──────────────────────────────────   ────────────────────────────────────────────
BEGIN;
SELECT sum(amount) FROM transactions
 WHERE bank_account_id='A'
   AND date >= '2026-07-01';  -> 900
                                     BEGIN;
                                     INSERT INTO transactions (..., bank_account_id,
                                       amount, date) VALUES (...,'A', 300, '2026-07-10');
                                     COMMIT;
SELECT sum(amount) FROM transactions
 WHERE bank_account_id='A'
   AND date >= '2026-07-01';  -> 1200  ← fantasma
COMMIT;
```

Soluções (cap. 22.7.1): **index locking** — bloquear a *entrada de índice* do predicado antes de acessar os registros (T₁ pega read lock na entrada `bank_account_id='A'`, T₂ precisa de write lock na mesma entrada ⟹ conflito detectado); ou **predicate locking** — bloquear tudo que satisfaz um predicado arbitrário, que Elmasri diz ter "provado ser difícil de implementar de modo eficiente". Ninguém faz na forma geral.

**Nota prática:** o Postgres em `REPEATABLE READ` já não sofre phantom em *leituras* (o snapshot é fixo no início da transação — mais forte que o padrão SQL exige). Mas snapshot isolation não impede o conflito de *escrita* baseado num predicado lido (write skew, §3.6). Para isso, `SERIALIZABLE` (SSI), que implementa predicate locking de forma prática via *SIREAD locks* sobre páginas/índices — a solução que Elmasri dizia ser difícil de implementar com eficiência, resolvida com detecção em vez de bloqueio.

### 3.5 Unrepeatable analysis / resumo incorreto (incorrect summary)

Uma transação calcula uma função de agregação sobre vários itens enquanto outra os atualiza. A agregação pega alguns valores antes da atualização e outros depois — o total fica defasado (Elmasri, cap. 21.1.3).

```
T3 (soma todas as contas)          T1 (transfere 5 de X para Y)
─────────────────────────          ────────────────────────────
sum := 0
read_item(A); sum += A
                                   read_item(X); X := X - 5
                                   write_item(X)          ← X já debitado
read_item(X); sum += X             ← lê X DEPOIS do débito
read_item(Y); sum += Y             ← lê Y ANTES do crédito
                                   read_item(Y); Y := Y + 5
                                   write_item(Y)
```

O total fica **5 a menos**: o dinheiro em trânsito não está em lugar nenhum. É a anomalia mais perigosa em finanças porque não corrompe nenhuma linha — só o relatório. Não há erro nem lock em conflito; o resultado simplesmente mente.

**Nota prática:** em Postgres, `REPEATABLE READ` mata essa classe inteira de graça: o snapshot congelado no início vê ou nenhum dos dois writes, ou ambos. É o argumento decisivo para rodar **todo relatório/fechamento em REPEATABLE READ**, e é barato — leitores nunca bloqueiam.

### 3.6 Write skew (não está no Elmasri; complemento)

**Nota prática:** duas transações leem conjuntos sobrepostos, cada uma decide com base no que leu, e escrevem em linhas *diferentes*. Nenhum lost update, nenhum phantom em leitura — e a invariante quebra mesmo assim.

```
T1                                        T2
BEGIN ISOLATION LEVEL REPEATABLE READ;    BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT sum(amount) FROM transactions      SELECT sum(amount) FROM transactions
  WHERE bank_account_id='A';  -> 100        WHERE bank_account_id='A';  -> 100
-- "saldo 100 >= 80, posso sacar 80"      -- "saldo 100 >= 80, posso sacar 80"
INSERT ... amount = -80;                  INSERT ... amount = -80;
COMMIT;  -- ok                            COMMIT;  -- ok em REPEATABLE READ!
                                          -- saldo final: -60
```

Snapshot isolation **não** detecta isso. Só `SERIALIZABLE` (SSI) ou um lock explícito na linha da conta (`SELECT ... FROM bank_accounts WHERE id='A' FOR UPDATE` como ponto de serialização) resolvem. Ver §12.

---

## 4. Escalonamentos (schedules)

Um **schedule** S de n transações é uma ordenação das operações delas; as operações podem ser intercaladas, mas a ordem interna de cada transação é preservada (Elmasri, cap. 21.4.1). Notação: `r₁(X)`, `w₂(X)`, `c₁`, `a₂`.

**Conflito**: duas operações conflitam se (1) são de transações diferentes, (2) acessam o mesmo item, e (3) pelo menos uma é `write`. Logo: read-write e write-write conflitam; read-read não; operações em itens distintos não; operações da mesma transação não.

### 4.1 Serializabilidade de conflito

Dois schedules são **equivalentes em conflito** se a ordem de quaisquer duas operações em conflito é a mesma nos dois. Um schedule é **serializável de conflito** se é equivalente em conflito a algum schedule serial — isto é, se dá para reordenar as operações **não** conflitantes até obter um schedule serial (cap. 21.5.1). Serial = correto por definição, já que cada transação isolada preserva consistência.

Serial é correto mas inaceitável na prática (zero concorrência, CPU ociosa em E/S, transação longa trava todas). Serializável entrega a corretude do serial com intercalação.

### 4.2 Teste do grafo de precedência (Algoritmo 21.1)

1. Um nó por transação de S.
2. `w_j(X)` antes de `r_k(X)` ⟹ aresta `Tⱼ → Tₖ`.
3. `r_j(X)` antes de `w_k(X)` ⟹ aresta `Tⱼ → Tₖ`.
4. `w_j(X)` antes de `w_k(X)` ⟹ aresta `Tⱼ → Tₖ`.
5. **S é serializável de conflito ⟺ o grafo não tem ciclo.**

Sem ciclo, a ordenação topológica dá o(s) schedule(s) serial(is) equivalente(s).

```
Schedule C: r1(X) r2(X) w1(X) r1(Y) w2(X) w1(Y)   Schedule D: r1(X) w1(X) r2(X) w2(X) r1(Y) w1(Y)
  r1(X)…w2(X) => T1→T2 ;  r2(X)…w1(X) => T2→T1     w1(X)…r2(X) => T1→T2 ; w1(X)…w2(X) => T1→T2
  T1 ⇄ T2  CICLO -> NÃO serializável                T1 → T2  sem ciclo -> serializável
           (é o lost update de §3.1)                         (equivale ao serial T1;T2)
```

**Por que isso importa, se o SGBD não roda esse algoritmo?** Porque nenhum sistema real testa serializabilidade a posteriori — seria preciso desfazer o schedule quando o teste falha, o que é impraticável (cap. 21.5.3). O grafo existe para *provar protocolos*: 2PL, TO e SSI garantem por construção que o grafo é acíclico. Entender o grafo é entender por que 2PL funciona.

### 4.3 Serializabilidade de visão

Menos restritiva. S e S' são **equivalentes de visão** se (cap. 21.5.4): (1) as mesmas transações e operações participam de ambos; (2) toda `r_i(X)` lê o valor gravado pela mesma `w_j(X)` (ou o valor inicial) nos dois; (3) a última `w_k(Y)` de cada item Y é da mesma transação nos dois. S é **serializável de visão** se é equivalente de visão a um schedule serial.

Todo schedule serializável de conflito é serializável de visão; a recíproca é falsa. A diferença só aparece com **blind writes** (gravação em X não precedida por leitura de X na mesma transação):

```
Sg: r1(X); w2(X); w1(X); w3(X); c1; c2; c3;
    ↑ w2 e w3 são blind writes
    Serializável de visão (equivale a T1;T2;T3), mas NÃO de conflito.
```

Sob a **suposição de gravação restrita** (sem blind writes), as duas definições coincidem. Testar serializabilidade de visão é NP-difícil — por isso "serializável" sem qualificação significa **de conflito**. Valor prático: quase nenhum; saiba que existe para não confundir os termos.

### 4.4 Recuperabilidade

Ortogonal à serializabilidade. Trata de: quando uma transação confirma, ela nunca deve precisar ser desfeita (cap. 21.4.2).

**Recoverable (recuperável)**: nenhuma transação T confirma até que todas as transações que gravaram itens lidos por T tenham confirmado.
```
Sc: r1(X); w1(X); r2(X); w2(X); c2; a1;   ← NÃO recuperável.
    T2 leu X de T1 e confirmou ANTES de T1. T1 aborta => T2 deveria ser
    desfeita depois de confirmada. Durabilidade violada. Proibido.
Sd: r1(X); w1(X); r2(X); w2(X); c1; c2;   ← recuperável (c2 adiado até depois de c1).
```
**Cascadeless (sem cascata)**: toda transação lê apenas itens gravados por transações **já confirmadas**. Impede que o abort de T force o abort de S que leu de T, que force o abort de R que leu de S...

**Strict (estrito)**: nenhuma transação lê **nem grava** X até que a última transação que gravou X tenha confirmado ou abortado. Por que o "nem grava" importa:
```
Sf: w1(X, 5); w2(X, 8); a1;        (X valia 9)
    Sf é cascadeless (ninguém LEU sujo), mas não é estrito.
    O rollback de T1 restaura a BFIM 9 -> apaga o 8 de T2. Resultado errado.
```
Schedules estritos permitem a recuperação mais simples possível: desfazer = restaurar a before image. Ponto. **Hierarquia:** `estrito ⊂ cascadeless ⊂ recuperável`.

---

## 5. Níveis de isolamento — padrão SQL vs. PostgreSQL real

O padrão SQL (Elmasri, cap. 21.6) define `SET TRANSACTION ISOLATION LEVEL {READ UNCOMMITTED | READ COMMITTED | REPEATABLE READ | SERIALIZABLE}` e caracteriza cada nível pelas anomalias que **permite**. Note que "SERIALIZABLE" do padrão significa "não permite dirty read, non-repeatable read nem phantom" — **não é idêntico** à serializabilidade de conflito da §4.1 (o próprio Elmasri alerta para isso).

### Tabela obrigatória

| Nível | Dirty read | Non-repeatable read | Phantom | Lost update | Write skew |
|---|---|---|---|---|---|
| **PADRÃO SQL** | | | | | |
| READ UNCOMMITTED | **Sim** | Sim | Sim | (não definido) | (não definido) |
| READ COMMITTED | Não | Sim | Sim | (não definido) | (não definido) |
| REPEATABLE READ | Não | Não | **Sim** | (não definido) | (não definido) |
| SERIALIZABLE | Não | Não | Não | Não | Não |
| **POSTGRESQL REAL** | | | | | |
| READ UNCOMMITTED | **Não** (vira RC) | Sim | Sim | Sim | Sim |
| READ COMMITTED *(default)* | **Não** | Sim | Sim | Sim¹ | Sim |
| REPEATABLE READ | Não | Não | **Não**² | Não³ | **Sim** |
| SERIALIZABLE | Não | Não | Não | Não | **Não** |

¹ Lost update no sentido read-modify-write **na aplicação**. Um `UPDATE ... SET x = x - 5` único é atômico mesmo em RC (o segundo UPDATE bloqueia, e ao ser liberado **relê a linha** e reaplica o predicado — comportamento específico do RC do Postgres).
² Mais forte que o padrão: o snapshot é tirado na primeira query da transação e não muda.
³ Em RR, a segunda escrita na mesma linha aborta com `40001` em vez de perder a atualização (*first-updater-wins*).

**Os três desvios que importam:**
1. **Postgres não tem dirty read em nenhum nível.** `READ UNCOMMITTED` é aceito e silenciosamente promovido a `READ COMMITTED`. Código ou revisão que se preocupe com dirty read no Postgres está resolvendo problema inexistente.
2. **`REPEATABLE READ` no Postgres é snapshot isolation**, estritamente mais forte que o RR do padrão: elimina phantom em leituras. O que ele **não** elimina é write skew.
3. **`SERIALIZABLE` no Postgres é SSI** (Serializable Snapshot Isolation): snapshot isolation + detecção de padrões de dependência perigosos. Não usa locks de leitura bloqueantes — leitores continuam não bloqueando. O preço é abort com `40001` e a obrigação de retry (§10).

### Critério de decisão

| Situação | Nível |
|---|---|
| CRUD comum, uma linha, escrita via `increment`/`decrement` | Read Committed (default) — não mexa |
| Relatório, fechamento de mês, export, qualquer agregação multi-linha | **Repeatable Read** (mata §3.5, custo ~zero) |
| Ler-decidir-escrever em linhas diferentes com invariante entre elas (write skew) | **Serializable** + retry, ou RC + `FOR UPDATE` no ponto de serialização |
| Job de fila / worker consumindo pendências | Read Committed + `FOR UPDATE SKIP LOCKED` |

Regra: **suba o isolamento antes de inventar lock manual; use lock explícito quando o ponto de serialização for óbvio e único.**

---

## 6. Two-phase locking (2PL)

Um **lock** é uma variável associada a um item que descreve seu status (cap. 22.1.1).

**Binário**: dois estados (0/1), `lock_item(X)` / `unlock_item(X)`, exclusão mútua. Simples demais — impede duas leituras concorrentes, que não conflitam. Não é usado na prática.

**Compartilhado/exclusivo (leitura/gravação)**: `read_lock(X)` (shared), `write_lock(X)` (exclusive), `unlock(X)`. Estados: read-locked, write-locked, unlocked. A tabela de lock guarda `<item, LOCK, num_leituras, transações>`. **Conversão**: upgrade read→write (só se T for a única leitora), downgrade write→read.

| Detém ↓ / Pede → | Read | Write |
|---|---|---|
| **Read** | Sim | Não |
| **Write** | Não | Não |

**Locks sozinhos não garantem serializabilidade** (cap. 22.1.1, Fig. 22.3): se T₁ solta Y cedo demais e depois pega X, um schedule não serializável passa. Daí o protocolo.

### O protocolo

Uma transação segue **2PL** se **todas as operações de lock precedem o primeiro unlock** (cap. 22.1.2): na **fase de expansão** adquire locks e não libera nenhum (upgrades aqui); na **fase de encolhimento** libera e não adquire nenhum (downgrades aqui).

**Teorema**: se toda transação de um schedule segue 2PL, o schedule é serializável — sem precisar testar o grafo.

**Preço**: X fica travado até que tudo que T precisa esteja travado, mesmo que T já tenha terminado de usar X. E o 2PL **não permite todos** os schedules serializáveis — alguns corretos são proibidos. É o custo de garantir sem testar.

### As quatro variações

| Variação | Regra | Deadlock? | Schedules | Uso |
|---|---|---|---|---|
| **Básico** | Locks antes do primeiro unlock | Sim | Serializáveis | Base teórica |
| **Conservador (estático)** | Pré-declara read set + write set e trava **tudo antes de começar**; se algum falta, não trava nada e espera | **Não** (livre de deadlock) | Serializáveis | Impraticável — raramente se conhece o read/write set antes |
| **Estrito** | Não libera locks **exclusivos** até commit/abort | Sim | **Estritos** | O mais popular na prática |
| **Rigoroso** | Não libera **nenhum** lock (S ou X) até commit/abort | Sim | **Estritos** | Mais simples de implementar que o estrito |

Contraste conservador × rigoroso (cap. 22.1.2): o conservador trava tudo antes de começar — quando a transação inicia ela **já está encolhendo**; o rigoroso não solta nada até terminar — ela **está expandindo até o fim**.

**Nota prática:** o Postgres não usa 2PL para leitura (é MVCC), mas usa **2PL rigoroso para escrita**: todo lock de linha (`FOR UPDATE`, `UPDATE`, `DELETE`) e de tabela é mantido até o fim da transação. Por isso `COMMIT` cedo é a principal ferramenta de contenção: a duração da transação **é** a duração dos locks. Ver `pg_locks` (§13).

---

## 7. Deadlock, starvation e granularidade

### 7.1 Deadlock

Cada transação de um conjunto espera por um item travado por outra do conjunto (cap. 22.1.3). Ninguém libera; ninguém prossegue.

```
T1'                          T2'
read_lock(Y)
read_item(Y)
                             read_lock(X)
                             read_item(X)
write_lock(X)  ← espera T2'
                             write_lock(Y)  ← espera T1'
```

**Detecção — wait-for graph**: um nó por transação ativa; aresta `T_i → T_j` quando T_i espera item travado por T_j. **Deadlock ⟺ ciclo** (aqui, `T1' ⇄ T2'`). A aresta some quando o lock é liberado. Detectado o ciclo, escolhe-se uma **vítima**: o algoritmo deve evitar transações longas com muitas atualizações e preferir as mais novas / com menos mudanças.

**Prevenção via timestamp.** `TS(T)` é único e crescente; transação mais antiga tem TS menor. T tenta travar X, travado por T' com lock conflitante:
- **wait-die**: se `TS(T) < TS(T')` (T mais antiga) → T espera. Senão → **aborta T** (T morre) e reinicia com o **mesmo timestamp**.
- **wound-wait**: se `TS(T) < TS(T')` (T mais antiga) → **aborta T'** (T fere T'), reinicia com mesmo timestamp. Senão → T espera.

Em wait-die, transações só esperam pelas mais **novas**; em wound-wait, só pelas mais **antigas**. Nos dois casos não se forma ciclo ⟹ livre de deadlock. Ambos abortam a mais nova. Reiniciar com o timestamp original é o que evita starvation.

**Sem timestamp:** *no waiting* (falhou o lock → aborta já) e *cautious waiting* (T espera só se T' **não** estiver bloqueada; senão aborta T) — este último é livre de deadlock porque os tempos de bloqueio formam ordenação total. **Timeout**: espera > limite → aborta, exista deadlock ou não; overhead baixíssimo, é o que se usa.

**Elmasri é explícito** (nota de rodapé, cap. 22.1.3): os protocolos de prevenção "geralmente não são usados na prática, ou por causa de suposições não realistas ou por causa de seu possível overhead. A detecção de deadlock e timeouts são mais práticos."

### 7.2 Starvation (inanição)

Uma transação nunca progride enquanto outras seguem normalmente — esquema de espera injusto, ou seleção de vítima que escolhe sempre a mesma. Soluções: fila FIFO; prioridade que **cresce com o tempo de espera**; prioridade maior para quem já foi abortada várias vezes.

### 7.3 Granularidade e intention locks

Trade-off puro (cap. 22.5.1). **Item grande** (bloco, arquivo): menos locks, menos overhead, **menos concorrência** — travar o bloco trava registros que ninguém queria. **Item pequeno** (registro, campo): mais concorrência, **mais locks ativos**, mais overhead no gerenciador, mais memória na tabela de lock. Resposta: **depende da transação** — poucos registros → granularidade de registro; arquivo inteiro → granularidade de arquivo.

**Multiple Granularity Locking (MGL)** permite travar em qualquer nível da hierarquia `db → arquivo → página → registro`. O problema: se T₂ tem S em um registro e T₁ pede X no arquivo, verificar todos os descendentes seria proibitivo. Daí os **intention locks** — a transação sinaliza, no caminho da raiz até o alvo, que tipo de lock vai pedir abaixo: **IS** (vou pedir shared em algum descendente), **IX** (vou pedir exclusive em algum descendente) e **SIX** (shared neste nó **e** exclusive em algum descendente).

| | IS | IX | S | SIX | X |
|---|---|---|---|---|---|
| **IS** | Sim | Sim | Sim | Sim | Não |
| **IX** | Sim | Sim | Não | Não | Não |
| **S** | Sim | Não | Sim | Não | Não |
| **SIX** | Sim | Não | Não | Não | Não |
| **X** | Não | Não | Não | Não | Não |

Regras do MGL: (1) respeitar a matriz; (2) travar a raiz primeiro; (3) N em S/IS exige pai em IS ou IX; (4) N em X/IX/SIX exige pai em IX ou SIX; (5) não travar após ter destravado (impõe 2PL); (6) só destravar N se nenhum filho estiver travado por T. Ideal para mistura de transações curtas (poucos registros) e longas (arquivos inteiros).

**Nota prática:** o Postgres implementa exatamente isso. Locks de tabela `ROW SHARE`/`ROW EXCLUSIVE` são os intention locks de `SELECT FOR UPDATE`/`UPDATE`; `ACCESS EXCLUSIVE` (DDL) é o X da raiz. É por isso que um `ALTER TABLE` fica na fila atrás de qualquer transação aberta que tocou a tabela — e, pior, **bloqueia todo mundo atrás dele** na mesma fila. Migrations do Prisma em produção: sempre com `lock_timeout`.

---

## 8. Os outros protocolos

### 8.1 Ordenação por timestamp (TO)

Sem locks ⟹ **sem deadlock** (cap. 22.2). Cada item guarda `read_TS(X)` e `write_TS(X)`. O schedule serial equivalente é **exatamente** a ordem dos timestamps (diferente do 2PL, onde é a ordem em que os locks foram adquiridos).

**TO básico:** `write_item(X)` por T — se `read_TS(X) > TS(T)` ou `write_TS(X) > TS(T)` → **aborta T** (alguém mais novo já leu ou gravou X); senão executa e `write_TS(X) := TS(T)`. `read_item(X)` por T — se `write_TS(X) > TS(T)` → **aborta T**; senão executa e `read_TS(X) := max(TS(T), read_TS(X))`.

Garante serializabilidade de conflito, mas **não** recuperabilidade — rollback em cascata é possível. Deadlock não ocorre; **reinício cíclico (starvation) ocorre**.

**TO estrita**: adia a operação de T até que a transação que gravou X confirme/aborte. Garante estrito + serializável, sem deadlock (T só espera por T' se `TS(T) > TS(T')`).

**Regra de Thomas**: se `write_TS(X) > TS(T)`, **ignore o write** de T (está obsoleto) em vez de abortar; continue. Rejeita menos writes, mas **não garante serializabilidade de conflito** (garante de visão).

### 8.2 Otimista / validação

Nenhuma verificação durante a execução (cap. 22.4). Três fases: **leitura** (lê valores confirmados; atualizações vão só para **cópias locais** no workspace da transação), **validação** (aplicar as atualizações violaria serializabilidade?) e **escrita** (validou ⟹ aplica; senão descarta e reinicia).

Validação de T contra cada T' confirmada ou em validação — basta **uma** das condições, testadas nesta ordem (custo crescente):
1. T' completa a fase de escrita antes de T iniciar a leitura.
2. T' completa a escrita antes de T iniciar a escrita, **e** `read_set(T) ∩ write_set(T') = ∅`.
3. `read_set(T) ∩ write_set(T') = ∅` **e** `write_set(T) ∩ write_set(T') = ∅` **e** T' completa a leitura antes de T.

**Critério**: ótimo com pouca interferência (quase tudo valida); péssimo com muita (trabalho executado até o fim e descartado). É exatamente o trade-off do `SERIALIZABLE` (SSI) e do optimistic locking com coluna `version`.

### 8.3 MVCC (multiversion)

Mantém versões antigas do item (cap. 22.3). Ideia central: **leituras que seriam rejeitadas passam a ser aceitas lendo uma versão mais antiga**, preservando a serializabilidade.

**MVCC por timestamp** (cap. 22.3.1): cada versão `Xᵢ` tem `read_TS(Xᵢ)` e `write_TS(Xᵢ)`.
- `read_item(X)` por T: escolhe a versão i com o maior `write_TS(Xᵢ) ≤ TS(T)`. **Sempre tem sucesso.**
- `write_item(X)` por T: seja i a versão com maior `write_TS(Xᵢ) ≤ TS(T)`. Se `read_TS(Xᵢ) > TS(T)` → aborta T. Senão cria nova versão.

**2PL multiversão com certification locks** (cap. 22.3.2): três modos — leitura, gravação, **certificação**. Duas versões por item: a confirmada X e a X' criada quando T pega write lock. Outras transações leem X enquanto T escreve X'. No commit, T precisa de **certification lock** em tudo que travou para escrita; certificação é incompatível com leitura. Ao obtê-la, X := X' e libera.

| | Leitura | Gravação | Certificação |
|---|---|---|---|
| **Leitura** | Sim | **Sim** | Não |
| **Gravação** | Sim | Não | Não |
| **Certificação** | Não | Não | Não |

Note o "Sim" em (Leitura, Gravação): **leitura e escrita simultâneas**, impossível no 2PL padrão. Preço: a transação pode esperar no commit até que todos os leitores saiam. Evita rollback em cascata (só se lê versão confirmada).

**Custo geral do MVCC**: armazenamento para as versões. Elmasri relativiza: versões antigas podem já ser mantidas para recuperação ou histórico.

**Nota prática — MVCC no PostgreSQL.** É o coração do Postgres, e a frase que resume tudo é: **leitores nunca bloqueiam escritores; escritores nunca bloqueiam leitores.** Um `UPDATE` não altera a tupla — cria uma **nova versão** e marca a antiga como morta (`xmax`). Consequências em produção:

- **Bloat**: tuplas mortas ocupam espaço e são varridas em seq scans. Tabela com muito UPDATE/DELETE incha — `transactions` sob reprocessamento de Open Finance é candidata natural.
- **VACUUM**: recupera espaço das tuplas mortas para reúso; `VACUUM FULL` devolve ao SO mas pega `ACCESS EXCLUSIVE` (trava tudo — nunca em pico). Autovacuum resolve o caso normal; monitore `pg_stat_user_tables.n_dead_tup`.
- **Long-running transactions são o inimigo #1.** Uma transação aberta há horas (um `BEGIN` esquecido num worker, um cursor não fechado) segura um snapshot antigo ⟹ o VACUUM **não pode** remover nenhuma tupla morta mais nova que ela ⟹ bloat cresce no banco **inteiro**, não só na tabela dela. Sintoma: `pg_stat_activity` com `state='idle in transaction'` e `xact_start` antigo. Defesa: `idle_in_transaction_session_timeout` e `statement_timeout`.
- **Transaction ID wraparound**: o XID é de 32 bits. Se o VACUUM não conseguir "congelar" tuplas antigas a tempo, o Postgres entra em modo de emergência e, no limite, **recusa novas escritas**. Monitore `age(datfrozenxid)`. Causa raiz quase sempre: autovacuum bloqueado por transação longa ou por locks.

---

## 9. Recuperação

### 9.1 Log e WAL

O **log do sistema** é um arquivo sequencial append-only em disco, imune a tudo exceto falha de disco/catástrofe (cap. 21.2.2). Registros:

```
[start_transaction, T]                        [commit, T]      [abort, T]
[write_item, T, X, valor_antigo, valor_novo]  -- BFIM (before image) e AFIM (after image)
[read_item, T, X]  -- só se rollback em cascata for possível; protocolos práticos dispensam
[checkpoint, lista de transações ativas]
```

Entradas ficam no **buffer de log** e vão para disco em lote. Antes do commit, o que ainda não foi gravado **deve** ser: **force write do buffer de log antes do commit**.

**Caching**: a cache do SGBD mantém páginas em buffers, cada um com **dirty bit** (modificado?) e **pin bit** (pode ir para o disco?). Ao esvaziar: **atualização no local** (in-place, sobrescreve — o que se usa) ou **sombreamento** (grava em outro lugar).

**Write-Ahead Logging (WAL)** — só necessário com atualização no local (cap. 23.1.3). Para um algoritmo UNDO/REDO: (1) a BFIM de um item **não pode** ser sobrescrita pela AFIM no disco até que todos os registros de log **tipo UNDO** daquela transação tenham sido gravados à força no disco; (2) o commit **não pode** completar até que todos os registros **tipo REDO e UNDO** daquela transação estejam no disco. Regra 1 preserva o UNDO; regra 2 preserva o REDO.

**steal/no-steal e force/no-force** (cap. 23.1.3):
- **no-steal**: página suja não vai ao disco antes do commit ⟹ **UNDO nunca necessário**. **steal**: pode ir (o buffer manager precisa do frame) ⟹ UNDO necessário.
- **force**: todas as páginas vão ao disco no commit ⟹ **REDO nunca necessário**. **no-force**: podem ficar no buffer ⟹ REDO necessário.

**Sistemas reais usam steal/no-force.** Steal evita exigir buffer gigante; no-force evita reescrever a mesma página várias vezes (economia grande de E/S numa página quente). O preço é precisar dos dois, UNDO e REDO.

### 9.2 Checkpoint

`[checkpoint, lista de ativas]` gravado periodicamente (a cada m minutos ou t commits). Transações com `[commit, T]` **antes** do checkpoint não precisam de REDO. Passos (cap. 23.1.4): (1) suspende transações; (2) força todos os buffers modificados ao disco; (3) grava `[checkpoint]` e força o log; (4) retoma.

O passo 1 é o problema. **Fuzzy checkpoint**: grava `[begin_checkpoint]`, retoma imediatamente, e grava `[end_checkpoint, ...]` quando o passo 2 terminar. Um arquivo especial aponta para o **checkpoint válido anterior** até o novo completar.

### 9.3 Deferred update vs. immediate update

| | **Deferred update** | **Immediate update** |
|---|---|---|
| Quando escreve no disco | **Só após o commit** | Pode escrever antes do commit |
| Algoritmo | **NO-UNDO/REDO** | **UNDO/REDO** (geral) ou **UNDO/NO-REDO** (com force) |
| Buffer | no-steal | steal |
| UNDO | Nunca | Sim |
| Viabilidade | Só transações curtas que mudam poucos itens — senão estoura o buffer | **É o que se usa** |

`RDU_M` (deferred, NO-UNDO/REDO com checkpoint): duas listas — confirmadas desde o último checkpoint e ativas. **REDO** de todos os writes das confirmadas, na ordem do log. As ativas são ignoradas (nunca tocaram o disco). `RIU_M` (immediate, UNDO/REDO com checkpoint): mesmas duas listas; **UNDO** dos writes das ativas na **ordem reversa** do log; depois **REDO** dos writes das confirmadas na ordem do log. Otimização dos dois: varra do fim do log e refaça só a **última** atualização de cada item, mantendo uma lista de itens já refeitos.

**Idempotência**: UNDO, REDO e o processo de recuperação inteiro devem ser idempotentes. Se o sistema falhar *durante* a recuperação, a próxima tentativa pode reexecutar operações já executadas — o resultado tem que ser o mesmo.

### 9.4 Rollback e rollback em cascata

Reverter T = restaurar as BFIMs dos itens que T gravou, via entradas UNDO. Se T é revertida, qualquer S que leu um item gravado por T também deve ser revertida, e qualquer R que leu de S... (cap. 23.1.5). Ocorre quando o protocolo garante schedules recuperáveis mas **não** estritos/cascadeless. **Elmasri**: "quase todos os mecanismos de recuperação são projetados de modo que o rollback em cascata nunca seja necessário" — daí não ser preciso registrar `read_item` no log (sua única função era determinar cascata).

### 9.5 Shadow paging

Diretório de n entradas apontando para as n páginas do banco (cap. 23.4). Ao iniciar, o **diretório atual** é copiado para o **diretório de sombra**, salvo em disco. Todo `write_item` cria **nova cópia** da página num bloco não usado e aponta o diretório atual para ela; o de sombra continua apontando para a página antiga e **nunca é modificado**. Recuperação de falha: descarte o diretório atual, restaure o de sombra — pronto. Commit: descarte o diretório de sombra anterior. Classificação: **NO-UNDO/NO-REDO**; dispensa log em ambiente monousuário.

**Por que ninguém usa**: páginas mudam de lugar no disco (destrói localidade), overhead de gravar diretórios grandes a cada commit, coleta de lixo das páginas antigas, e a migração entre diretórios precisa ser atômica. Em multiusuário, log e checkpoint voltam de qualquer forma.

### 9.6 ARIES

O algoritmo de recuperação real (usado nos produtos relacionais da IBM). **steal/no-force**, três conceitos (cap. 23.5): **write-ahead logging**; **repeating history durante o REDO** (reconstrói o estado exato do momento da falha — inclusive o das transações não confirmadas — e **só depois** desfaz as ativas); e **logging durante o UNDO** (compensation log records, que impedem o ARIES de repetir undos já concluídos se houver falha durante a recuperação).

Estruturas: **LSN** (Log Sequence Number, monotônico, é o endereço do registro no log; cada página de dados guarda o LSN da última mudança nela), **Tabela de Transações** (id, status, LSN mais recente) e **Tabela de Páginas Sujas** (id da página, LSN da atualização **mais antiga** nela). Ambas são anexadas ao log no checkpoint (fuzzy — a cache não precisa ir ao disco).

1. **Análise**: do `begin_checkpoint` até o fim do log. Reconstrói as duas tabelas. Identifica páginas sujas, transações ativas (o `undo_set`) e o ponto de início do REDO.
2. **REDO**: começa no **menor LSN da Tabela de Páginas Sujas** — antes disso, tudo já está no disco. Varre para frente até o fim, pulando o que já foi aplicado (página fora da Tabela de Páginas Sujas ⟹ já está no disco; LSN da tabela maior que o do registro ⟹ já aplicada; senão compara com o LSN gravado na própria página). **Ao fim, o banco está exatamente como no momento da falha.**
3. **UNDO**: varre para trás desfazendo as transações do `undo_set`, seguindo a cadeia de `prev_LSN` de cada uma, gravando um CLR por ação desfeita.

**Nota prática:** o WAL do Postgres é ARIES-like. LSN é conceito de primeira classe (`pg_current_wal_lsn()`) e é a moeda da replicação: o primário envia WAL, a réplica aplica, e o *replication lag* é a diferença de LSN. Ler de réplica = ler de um passado (`pg_last_wal_replay_lsn()`). Nunca leia saldo de réplica logo após escrever no primário sem checar lag.

### 9.7 Falha catastrófica e backup

As técnicas acima assumem que **o log sobreviveu**. Para falha de disco/desastre (cap. 23.7): backup periódico do banco **e** do log para mídia offline, em local fisicamente separado. **O log é copiado com mais frequência que o banco** — é muito menor. Recuperação: recarrega o último backup e **refaz** as transações confirmadas registradas nas cópias do log.

**Two-phase commit** (cap. 23.6), para transação multibanco: **Fase 1** — coordenador manda *prepare to commit*; cada participante força log e informações de recuperação ao disco e responde OK / não-OK (timeout conta como não-OK). **Fase 2** — todos OK ⟹ manda commit; qualquer não-OK ⟹ manda rollback. Efeito: ou todos confirmam, ou nenhum.

**Nota prática:** Postgres = base backup + WAL archiving = PITR. Réplicas via streaming replication (WAL contínuo). Um backup lógico (`pg_dump`) **não** é substituto: não dá PITR. E `PREPARE TRANSACTION` (2PC do Postgres) só com `max_prepared_transactions > 0` — e uma transação preparada e esquecida trava o VACUUM indefinidamente (§8.3). Evite.

---

## 10. Nota prática: erros de serialização e retry

Em `REPEATABLE READ` e `SERIALIZABLE`, o Postgres **aborta** transações em vez de bloquear:

- `40001` (`serialization_failure`): "could not serialize access due to concurrent update" (RR) ou "due to read/write dependencies among transactions" (SSI).
- `40P01` (`deadlock_detected`): o Postgres detectou ciclo no wait-for graph (§7.1) e escolheu uma vítima.

**Ambos são esperados, não são bugs.** Usar isolamento alto **sem** retry é pior que não usar: você troca corrupção silenciosa por 500 intermitente.

```ts
async function withRetry<T>(fn: () => Promise<T>, tentativas = 3): Promise<T> {
  for (let i = 0; ; i++) {
    try {
      return await fn();
    } catch (e: any) {
      const code = e?.code === 'P2034' ? '40001' : e?.meta?.code;
      const retriavel = code === '40001' || code === '40P01' || e?.code === 'P2034';
      if (!retriavel || i >= tentativas - 1) throw e;
      await new Promise(r => setTimeout(r, 2 ** i * 50 + Math.random() * 50)); // backoff + jitter
    }
  }
}

await withRetry(() =>
  prisma.$transaction(async (tx) => { /* ... */ },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable })
);
```

Regras do retry:
- **A transação inteira** é reexecutada, do `BEGIN`. Não dá para "continuar de onde parou" — o snapshot morreu.
- **A closure precisa ser pura em relação ao mundo externo.** Nada de enviar e-mail, cobrar cartão ou publicar evento dentro dela: o retry duplica. Efeitos externos vão para outbox, commitada na mesma transação.
- **Backoff exponencial com jitter** (sem jitter, as transações em conflito colidem de novo em sincronia) e **limite de tentativas** (retry infinito sob contenção alta é uma tempestade de retry).
- Prisma mapeia `40001` para `P2034` ("Transaction failed due to a write conflict or a deadlock"). Trate os dois códigos.

---

## 11. Nota prática: locks explícitos no PostgreSQL

```sql
-- Lock exclusivo de linha; outras transações que pedirem FOR UPDATE/UPDATE nessa linha esperam.
SELECT * FROM bank_accounts WHERE id = $1 FOR UPDATE;

-- Mesmo lock, mas não bloqueia FKs que referenciam esta linha. Preferível quando você só
-- vai atualizar colunas comuns e há tabelas filhas apontando para cá (transactions -> bank_accounts).
SELECT * FROM bank_accounts WHERE id = $1 FOR NO KEY UPDATE;

-- Só garante que a linha não some / não muda a chave. Para "esta FK precisa continuar válida".
SELECT * FROM bank_accounts WHERE id = $1 FOR SHARE;

-- Fila de trabalho: pega as N primeiras livres, ignora as travadas por outros workers.
SELECT * FROM transactions
 WHERE status = 'PENDING'
 ORDER BY date
 LIMIT 10
 FOR UPDATE SKIP LOCKED;

-- Não quero esperar: falha imediatamente (55P03 lock_not_available).
SELECT * FROM bank_accounts WHERE id = $1 FOR UPDATE NOWAIT;
```

| Ferramenta | Use quando | Cuidado |
|---|---|---|
| `FOR UPDATE` | Ler-decidir-escrever a **mesma** linha | Serializa tudo naquela linha; ponto quente |
| `FOR NO KEY UPDATE` | Idem, mas há FKs apontando para a linha | É o lock que o próprio `UPDATE` de coluna não-chave pega |
| `SKIP LOCKED` | Filas, workers concorrentes | **Não** use em relatório: pula linhas silenciosamente |
| `NOWAIT` | Prefere falhar rápido a enfileirar | Precisa de tratamento de `55P03` |
| Advisory lock | Exclusão mútua sobre um conceito **sem linha** | Não é liberado por rollback no modo session; escolha bem o modo |

**Advisory locks** — o mutex do Postgres, sem relação com dados. Bom para garantir que só um worker sincronize a conta X por vez, ou serializar um job sem tabela de controle:
```sql
-- Escopo de transação: liberado automaticamente no COMMIT/ROLLBACK. É o que você quer.
SELECT pg_advisory_xact_lock(hashtext('sync-open-finance:' || $1));

-- Escopo de sessão: sobrevive ao rollback; PRECISA de unlock explícito. Com pool de conexões,
-- vaza o lock para o próximo usuário da conexão. Evite.
SELECT pg_advisory_lock($1);  -- perigoso com PgBouncer/pool
```

**Ordem de aquisição de locks previne deadlock.** Elmasri (cap. 22.1.3) cita ordenar os itens do banco como protocolo de prevenção e observa que é impraticável **no geral**. Mas numa transferência entre duas contas é totalmente praticável — e obrigatório:
```sql
-- SEMPRE nesta ordem, em todo o código:
SELECT * FROM bank_accounts WHERE id IN ($origem, $destino) ORDER BY id FOR UPDATE;
```
Sem o `ORDER BY id`, a transferência A→B e a B→A concorrentes formam o ciclo do §7.1.

### Lendo um deadlock no log

```
ERROR:  deadlock detected
DETAIL:  Process 4821 waits for ShareLock on transaction 90210; blocked by process 4833.
         Process 4833 waits for ShareLock on transaction 90205; blocked by process 4821.
         Process 4821: UPDATE bank_accounts SET ... WHERE id = 'conta-B';
         Process 4833: UPDATE bank_accounts SET ... WHERE id = 'conta-A';
HINT:  See server log for query text.
CONTEXT:  while updating tuple (0,12) in relation "bank_accounts"
```
Leitura: é literalmente o **wait-for graph** do §7.1 impresso. O `DETAIL` dá o ciclo completo; as queries dão os dois lados. Aqui: 4821 já tem A e quer B; 4833 já tem B e quer A ⟹ ordem de aquisição inconsistente ⟹ aplique o `ORDER BY id`. Ative `log_lock_waits = on` e `deadlock_timeout` (default 1s) para ver esperas longas antes de virarem deadlock.

### Inspeção ao vivo

```sql
-- Quem está bloqueando quem: pg_blocking_pids() é o wait-for graph (§7.1) materializado.
SELECT pid, state, wait_event_type, wait_event, pg_blocking_pids(pid) AS bloqueado_por,
       now() - xact_start AS duracao_xact, left(query, 80) AS query
  FROM pg_stat_activity WHERE state <> 'idle' ORDER BY xact_start;

-- Locks pendentes (granted = false é quem está na fila):
SELECT l.pid, l.locktype, l.mode, l.granted, c.relname
  FROM pg_locks l LEFT JOIN pg_class c ON c.oid = l.relation WHERE NOT l.granted;

-- Transações zumbis (as que impedem o VACUUM, §8.3):
SELECT pid, now() - xact_start AS idade, left(query, 60) FROM pg_stat_activity
 WHERE state = 'idle in transaction' AND now() - xact_start > interval '1 minute';
```

---

## 12. Nota prática: o padrão do saldo correto sob concorrência

O caso clássico (Elmasri usa reservas aéreas, mas a nota de rodapé do cap. 21.1.3 diz explicitamente que "um exemplo semelhante, mais utilizado, considera um banco de dados bancário, com uma transação realizando uma transferência de fundos da conta X para a conta Y e outra transação realizando um depósito na conta X").

No schema do projeto, o saldo é **derivado**: `bank_accounts.initial_balance + SUM(transactions.amount)` daquela conta. Isso muda a natureza do problema — não há uma linha "saldo" para travar, então o lost update (§3.1) não aparece, mas o **write skew** (§3.6) aparece em cheio: dois saques concorrentes leem o mesmo saldo, cada um insere seu próprio lançamento, e a invariante "saldo ≥ 0" quebra sem que nenhuma linha tenha sido sobrescrita.

**Se não há invariante sobre o saldo** (só registrar lançamentos): nada a fazer. `INSERT` em `transactions` é seguro em Read Committed. Não invente lock.

**Se há invariante** ("não permitir saldo negativo"), três opções:

**Opção A — lock explícito na conta como ponto de serialização (recomendada).** Trave a linha da conta em `bank_accounts` mesmo sem alterá-la: ela vira o ponto de serialização de todos os lançamentos daquela conta. É o `read_lock`→`write_lock` do 2PL aplicado a mão, com a granularidade certa (§7.3): trava **uma conta**, não a tabela.

```ts
await prisma.$transaction(async (tx) => {
  // 1. Ponto de serialização. Qualquer outra transação nesta conta espera aqui.
  await tx.$queryRaw`SELECT id FROM bank_accounts WHERE id = ${contaId} FOR NO KEY UPDATE`;

  // 2. Agora a leitura é estável: ninguém mais insere lançamento nesta conta até nosso commit.
  const [{ saldo }] = await tx.$queryRaw<{ saldo: Prisma.Decimal }[]>`
    SELECT b.initial_balance + COALESCE(SUM(t.amount), 0) AS saldo
      FROM bank_accounts b
      LEFT JOIN transactions t ON t.bank_account_id = b.id
     WHERE b.id = ${contaId}
     GROUP BY b.initial_balance`;

  // 3. Decide.
  if (saldo.lessThan(valor)) throw new SaldoInsuficienteError(contaId, saldo);

  // 4. Escreve.
  await tx.transaction.create({ data: { bankAccountId: contaId, amount: valor.negated(), /* ... */ } });
});
```
- Funciona em **Read Committed** (o default). Não precisa de retry por `40001`.
- `FOR NO KEY UPDATE` e não `FOR UPDATE`: `transactions` tem FK para `bank_accounts`, e `FOR UPDATE` bloqueia inserts de filhos por outras transações desnecessariamente.
- Precisa de deadlock prevention se a transação toca duas contas (transferência): **`ORDER BY id`**, sempre (§11).
- Custo: todos os lançamentos daquela conta serializam. Para finanças pessoais, irrelevante — a contenção por conta é ~1.

**Opção B — SERIALIZABLE + retry.**

```ts
await withRetry(() => prisma.$transaction(async (tx) => {
  const saldo = await somarSaldo(tx, contaId);
  if (saldo.lessThan(valor)) throw new SaldoInsuficienteError(contaId, saldo);
  await tx.transaction.create({ data: { /* ... */ } });
}, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable }));
```
Sem lock, sem ordem de aquisição, sem deadlock: o SSI detecta o write skew e aborta um dos lados com `40001`. **Obrigatório**: retry (§10) e closure sem efeitos externos. Custo: aborts sob contenção, com a transação inteira reexecutando.

**Opção C — saldo materializado em coluna.**

```sql
UPDATE bank_accounts SET current_balance = current_balance - $2
 WHERE id = $1 AND current_balance >= $2;   -- 0 linhas => saldo insuficiente
```
Atômico, um round-trip, sem lock explícito, seguro em Read Committed (o `UPDATE` pega o lock e relê a linha ao ser liberado). Mas denormaliza: o saldo pode divergir da soma dos lançamentos se alguma escrita escapar do caminho. Só adote com o `UPDATE` de saldo e o `INSERT` do lançamento **na mesma transação, sempre**, e um job de reconciliação.

### Critério de decisão

| | Isolamento | Retry | Deadlock | Quando |
|---|---|---|---|---|
| **A** — `FOR NO KEY UPDATE` na conta | Read Committed | Não | Sim (ordene por id) | **Default.** Ponto de serialização óbvio, invariante por conta |
| **B** — `SERIALIZABLE` | Serializable | **Sim** | Não | Invariante espalhada por várias linhas/tabelas, sem ponto de serialização claro |
| **C** — saldo materializado | Read Committed | Não | Sim (ordene por id) | Saldo lido com altíssima frequência; aceita reconciliação |

E, para qualquer relatório/fechamento que agregue lançamentos: **`REPEATABLE READ`**, pelo §3.5. Custo zero, elimina o resumo incorreto.

**A regra que resume tudo**: a transação deve ser **curta** (locks duram até o commit — §6), **sem I/O externo** (retry duplica e a transação aberta trava o VACUUM — §8.3), e o `BEGIN` deve começar **depois** de toda validação que não precisa do banco.
