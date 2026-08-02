# Autenticação e sessão

Tudo que responde à pergunta **"quem é este usuário?"** e como esse fato é mantido entre requisições:
armazenamento de senha, política de senha, ataques contra o login, MFA/passkeys, gestão de sessão,
JWT, OAuth 2.0/OIDC, SAML e os fluxos periféricos (reset, troca de e-mail, API key, magic link) onde
a maior parte dos bugs realmente mora.

Abra este arquivo ao revisar rota de login/logout, código que gera ou valida token, configuração de
cookie de sessão, integração de SSO, ou qualquer fluxo que emita credencial. **A pergunta "esse
usuário pode fazer isso?" não é deste arquivo** — é de `references/autorizacao-e-logica-de-negocio.md`
(IDOR, BOLA, escalonamento de privilégio, tenant isolation). Aqui provamos identidade; lá decidimos
permissão. A distinção importa na hora de classificar o achado: um endpoint que aceita token expirado
é falha de autenticação; um endpoint que aceita token válido do usuário errado é falha de autorização.

No OWASP Top 10:2025 (edição final publicada em janeiro de 2026) a categoria correspondente é
**A07:2025 – Authentication Failures** — renomeada a partir de "Identification and Authentication
Failures" da edição 2021. Veja `references/owasp-top10.md`.

## Índice

- [Armazenamento de senha](#armazenamento-de-senha)
- [Política de senha (NIST SP 800-63B-4)](#política-de-senha-nist-sp-800-63b-4)
- [Ataques contra o login e defesas que funcionam](#ataques-contra-o-login-e-defesas-que-funcionam)
- [User enumeration](#user-enumeration)
- [MFA e passkeys](#mfa-e-passkeys)
- [Sessão](#sessão)
- [Cookies](#cookies)
- [JWT](#jwt)
- [OAuth 2.0 e OIDC](#oauth-20-e-oidc)
- [SAML](#saml)
- [Fluxos periféricos: onde o bug mora](#fluxos-periféricos-onde-o-bug-mora)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

---

## Armazenamento de senha

### Por que hash lento e não SHA-256+salt

SHA-256 é rápido por projeto — útil para integridade, inútil para senha. Uma GPU moderna faz na ordem
de 10^10 SHA-256/s. O salt por usuário impede rainbow table e ataque em lote, mas não muda o custo de
atacar **uma** senha: contra um dump de 1 milhão de hashes o atacante não precisa quebrar todos, só os
5% com senha fraca. As funções de derivação (Argon2id, scrypt, bcrypt, PBKDF2) invertem essa economia:
cada tentativa custa dezenas de milissegundos de CPU e, nas memory-hard, dezenas de MiB de RAM.
Memória é o parâmetro que quebra GPU/ASIC — milhares de cores, nenhum com 19 MiB de RAM rápida.

### Parâmetros vigentes (OWASP Password Storage Cheat Sheet)

Os cinco conjuntos de Argon2id abaixo são **equivalentes em defesa**; a escolha é trade-off entre RAM
e CPU. Todos com `p=1` exceto onde indicado.

| Algoritmo | Configuração recomendada | Notas |
|---|---|---|
| **Argon2id** (1ª escolha) | `m=47104` (46 MiB), `t=1`, `p=1` — ou `m=19456` (19 MiB), `t=2`, `p=1` — ou `m=12288` (12 MiB), `t=3`, `p=1` — ou `m=9216` (9 MiB), `t=4`, `p=1` — ou `m=7168` (7 MiB), `t=5`, `p=1` | `m` em KiB. Use a variante **id** (híbrida), não `argon2d` (sem resistência a side-channel) nem `argon2i` (mais fraca contra TMTO) |
| **scrypt** (quando Argon2id não está disponível) | `N=2^17` (128 MiB), `r=8`, `p=1` — ou `N=2^16`, `r=8`, `p=2` — ou `N=2^15`, `r=8`, `p=3` — ou `N=2^14`, `r=8`, `p=5` — ou `N=2^13`, `r=8`, `p=10` | Está no `node:crypto` sem dependência nativa |
| **bcrypt** (sistemas legados) | work factor **mínimo 10** | Limite duro de **72 bytes** de entrada. Veja abaixo |
| **PBKDF2** (só quando exige FIPS-140) | HMAC-SHA256: **600.000** iterações; HMAC-SHA512: **220.000**; HMAC-SHA1: **1.400.000** (legado) | Não é memory-hard; é a opção mais fraca da lista |

Salt: mínimo 32 bits segundo o NIST SP 800-63B-4 §3.1.1; na prática use **16 bytes** de CSPRNG, único
por usuário, armazenado junto do hash (o formato PHC já faz isso).

### O limite de 72 bytes do bcrypt, o truncamento por NUL e o password shucking

bcrypt trunca silenciosamente a entrada em **72 bytes**. Duas senhas que compartilham os primeiros 72
bytes produzem o mesmo hash — e o usuário não é avisado. Isso já é ruim; a tentativa ingênua de
consertar é pior.

O padrão comum é pré-hashear com SHA-256/SHA-512 para "comprimir" a senha antes do bcrypt. Duas
armadilhas:

1. **Truncamento por byte NUL.** O digest binário bruto contém bytes `0x00` com alta probabilidade.
   Muitas implementações de bcrypt são wrappers de C e tratam `0x00` como fim de string — a senha
   efetiva encolhe para os poucos bytes antes do primeiro NUL. Symfony e WordPress resolvem
   codificando o pré-hash em **base64** (que nunca contém NUL) antes de passar ao bcrypt.
2. **Password shucking.** Se o pré-hash for um hash rápido sem chave (`sha256(password)`), e a mesma
   senha aparecer em outro vazamento como MD5/SHA-1 sem salt, o atacante quebra o hash barato daquele
   outro vazamento e testa o resultado diretamente contra o seu bcrypt — pulando o custo do bcrypt.
   A construção sancionada pelo OWASP é usar um pré-hash **com chave**:
   `bcrypt(base64(hmac-sha384(password, pepper)))`.

```ts
// ❌ pré-hash binário: NUL trunca, e é shuckable
const hash = await bcrypt.hash(createHash('sha256').update(password).digest(), 12)

// ❌ silenciosamente aceita só os 72 primeiros bytes de uma passphrase longa
const hash = await bcrypt.hash(password, 12)

// ✅ se você precisa manter bcrypt: HMAC com pepper + base64
const inner = createHmac('sha384', PEPPER).update(password, 'utf8').digest('base64')
const hash = await bcrypt.hash(inner, 12)

// ✅ melhor: Argon2id, sem limite de comprimento e sem pré-hash
```

### Pepper

O **pepper** é um segredo único da aplicação (não por usuário) misturado à senha antes ou depois do
hash. O que ele compra: se o atacante rouba **só o banco** (SQL injection, backup exposto, réplica mal
configurada), sem o pepper ele não consegue nem começar o cracking offline. O que ele **não** compra:
nada, se o atacante tem RCE no app — o pepper estará no processo.

Regras: o pepper **não** pode ser armazenado junto dos hashes (senão é decorativo). Vai em HSM, KMS,
vault ou variável de ambiente com origem em secret manager — veja
`references/criptografia-e-segredos.md`. O NIST SP 800-63B-4 recomenda esse mesmo padrão: "uma
iteração adicional de hashing com chave ou operação de cifra usando chave secreta" armazenada em HSM
ou TEE.

Implementação preferida: **HMAC com o pepper antes do KDF** (`argon2id(hmac_sha384(pw, pepper))`), ou
o campo `secret` nativo do Argon2 (é exatamente para isso). Rotacionar pepper exige versionar: guarde
`pepper_version` na linha do usuário e re-derive no próximo login bem-sucedido.

```ts
// Node ≥ 24.7.0: Argon2 nativo em node:crypto — sem dependência nativa para compilar
import { argon2, randomBytes, timingSafeEqual } from 'node:crypto'
import { promisify } from 'node:util'
const argon2Async = promisify(argon2)

const OPTS = { memory: 19456, passes: 2, parallelism: 1, tagLength: 32 } // m=19 MiB, t=2, p=1

async function hashPassword(password: string) {
  const nonce = randomBytes(16) // "nonce" é o nome do salt na API do Node
  const tag = await argon2Async('argon2id', {
    message: password, nonce, secret: PEPPER, ...OPTS,
  })
  return `$argon2id$v=19$m=${OPTS.memory},t=${OPTS.passes},p=${OPTS.parallelism}$` +
         `${nonce.toString('base64url')}$${tag.toString('base64url')}`
}
```

`crypto.argon2`/`crypto.argon2Sync` foram adicionados no **Node 24.7.0**; assinatura
`argon2(algorithm, parameters, callback)` com `algorithm` em `'argon2d' | 'argon2i' | 'argon2id'` e
`parameters` = `{ message, nonce, memory, passes, parallelism, tagLength, secret?, associatedData? }`.
Antes disso, use `argon2` (npm, binding nativo) ou `@node-rs/argon2` (Rust, sem node-gyp).
`crypto.scrypt` está disponível desde o Node 10 e é a alternativa sem dependência em runtimes antigos.

### Migração de hash legado sem forçar reset

**Passo 1 (imediato, sem interação do usuário):** envelope o hash legado —
`novo = argon2id(hash_legado_em_hex)`, gravando `algo = 'argon2id(sha256)'`. O SHA-256 puro deixa de
existir no banco no mesmo dia, sem esperar ninguém logar.

**Passo 2 (oportunístico, no próximo login):** você tem a senha em claro por um instante — recalcule
o hash puro e substitua.

```ts
// ✅ upgrade transparente no login
const rec = await db.user.findUnique({ where: { email } })
let ok = false

if (rec?.algo === 'argon2id(sha256)') {
  const legacy = createHash('sha256').update(password).digest('hex')
  ok = await verifyArgon2(rec.hash, legacy)
} else if (rec?.algo === 'argon2id') {
  ok = await verifyArgon2(rec.hash, password)
}

if (ok && rec.algo !== 'argon2id') {
  // rehash com o algoritmo atual, agora que temos a senha em claro
  await db.user.update({
    where: { id: rec.id },
    data: { hash: await hashPassword(password), algo: 'argon2id' },
  })
}
```

Guarde o identificador do algoritmo e os parâmetros **no próprio hash**, usando o formato PHC
(`$argon2id$v=19$m=19456,t=2,p=1$<salt>$<tag>`). Isso é o que permite aumentar o work factor depois
sem invalidar hashes antigos: leia os parâmetros do registro, verifique com eles, e se forem menores
que os atuais, re-hasheie. `bcrypt` já embute o cost (`$2b$12$...`).

### Comparação em tempo constante

`===` e `Buffer.compare` retornam no primeiro byte diferente — o tempo vaza quantos bytes bateram.
Explorável quando o atacante controla o valor comparado e pode medir com precisão (API key, token de
reset, código TOTP, assinatura de webhook). Para *senha* o ponto é menos crítico porque a comparação é
entre digests de tamanho fixo, mas use `timingSafeEqual` de qualquer forma.

```ts
// ❌ vaza posição do primeiro byte divergente
if (apiKeyFromHeader === storedKey) { /* ... */ }

// ✅ tempo constante — exige mesmo comprimento, senão lança
import { timingSafeEqual, createHash } from 'node:crypto'
const a = createHash('sha256').update(apiKeyFromHeader).digest()
const b = createHash('sha256').update(storedKey).digest()
if (timingSafeEqual(a, b)) { /* ... */ }
```

O hash antes da comparação resolve o requisito de comprimento igual de `timingSafeEqual` (que **lança
`RangeError`** se os buffers diferirem em tamanho — e esse throw em si vaza o comprimento).

Timing de login: mesmo com comparação constante, o caminho "usuário não existe" costuma retornar em
1 ms enquanto "usuário existe, senha errada" gasta 50 ms no Argon2. Isso é enumeração por timing —
veja a seção correspondente.

---

## Política de senha (NIST SP 800-63B-4)

A revisão vigente é a **SP 800-63B-4** (agosto de 2025), e a orientação inverteu boa parte do que se
ensinava até 2017. Ela usa o termo *memorized secret*.

| Regra | O que a SP 800-63B-4 diz |
|---|---|
| Comprimento mínimo | **15 caracteres** quando a senha é fator único; **8 caracteres** quando compõe MFA |
| Comprimento máximo | Verificadores **SHOULD** aceitar pelo menos **64 caracteres** |
| Regras de composição | **SHALL NOT** impor (nada de "1 maiúscula, 1 número, 1 símbolo") |
| Expiração periódica | **SHALL NOT** exigir troca periódica — só troca por evidência de comprometimento |
| Blocklist | **SHALL** comparar contra lista de senhas comuns/esperadas/comprometidas (corpus de vazamento, palavras de dicionário, contexto do serviço) |
| Dica de senha | **SHALL NOT** permitir que o usuário armazene hint acessível sem autenticação |
| Pergunta secreta (KBA) | **SHALL NOT** usar |
| Caracteres | ASCII e espaço **SHOULD** ser aceitos; Unicode **SHOULD** ser aceito, contando cada code point como 1 caractere |
| Colar senha | Deve ser permitido (gerenciadores de senha) |
| Rate limiting | **SHALL** limitar tentativas falhas |

O OWASP Authentication Cheat Sheet alinha: senha com menos de 8 caracteres é fraca mesmo com MFA;
menos de 15 é fraca sem MFA; aceite ao menos 64.

**Armadilha de implementação:** "máximo 64 caracteres" não pode virar truncamento silencioso. E se
você impõe máximo por causa de DoS (Argon2 de uma senha de 1 MB), o limite deve ser generoso (128 ou
256 bytes) e **rejeitar explicitamente**, nunca cortar.

### Checagem contra vazamento — k-anonymity do Have I Been Pwned

A API Pwned Passwords permite verificar sem enviar a senha nem o hash completo:

```
GET https://api.pwnedpasswords.com/range/{5 primeiros chars do SHA-1 em maiúsculo}
```

O servidor devolve ~800 sufixos de hash (os 35 caracteres restantes) com a contagem de ocorrências;
você procura o seu sufixo localmente. Não exige API key e não tem rate limit. Envie o header
`Add-Padding: true` para que a resposta sempre tenha entre 800 e 1000 registros — sem isso, o tamanho
da resposta vaza informação sobre o prefixo consultado a quem observa o tráfego. Registros de padding
vêm com contagem `0` e devem ser descartados. Há também `?mode=ntlm` (sufixos de 27 caracteres).

```ts
// ✅ k-anonymity: só os 5 primeiros caracteres do SHA-1 saem da sua rede
async function isPwned(password: string): Promise<number> {
  const sha1 = createHash('sha1').update(password, 'utf8').digest('hex').toUpperCase()
  const prefix = sha1.slice(0, 5)
  const suffix = sha1.slice(5)
  const res = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`, {
    headers: { 'Add-Padding': 'true' },
    signal: AbortSignal.timeout(2000),
  })
  const body = await res.text()
  for (const line of body.split('\n')) {
    const [hash, count] = line.trim().split(':')
    if (hash === suffix) return Number(count) // count 0 = padding
  }
  return 0
}
```

Aplique **no cadastro e na troca de senha**, não no login (no login você não deve bloquear alguém que
já está entrando; alerte e force a troca). Falha da API deve ser *fail-open* com log — indisponibilidade
da HIBP não pode derrubar seu cadastro.

Sim, o SHA-1 aqui é intencional e não é uma falha: ele é o formato do dataset público, não o
armazenamento da sua senha.

---

## Ataques contra o login e defesas que funcionam

### Os três ataques, que são diferentes

| Ataque | Mecânica | O que detecta |
|---|---|---|
| **Credential stuffing** | Pares `email:senha` de vazamentos de *outros* sites, testados em massa. Taxa de sucesso típica de 0,1–2% — o que ainda é milhares de contas em uma campanha grande. **É o ataque real número 1 contra login hoje.** | Muitos usuários distintos, poucas tentativas por usuário, muitos IPs |
| **Password spraying** | Uma senha provável (`Verao@2026`, `Empresa123`) contra milhares de contas, devagar o suficiente para não estourar o lockout por conta | Muitos usuários distintos, **1–3** tentativas por usuário, distribuído no tempo |
| **Brute force** | Muitas senhas contra **uma** conta | Um usuário, muitas tentativas |

A consequência prática: **rate limit por IP não detecta nenhum dos dois primeiros.** Uma botnet
residencial ou proxy rotativo dá ao atacante 100.000 IPs; ele faz 2 requisições por IP. E lockout por
conta não detecta spraying, porque o atacante fica abaixo do limite de propósito.

### Defesa em camadas

Nenhuma camada isolada resolve. O conjunto que funciona:

1. **Rate limit por conta** — contador amarrado ao identificador de usuário, não ao IP (recomendação
   explícita do OWASP Authentication Cheat Sheet). Pega brute force.
2. **Rate limit por IP / ASN / sub-rede** — pega o atacante amador e o script single-host.
3. **Rate limit global no endpoint de login** — a métrica que pega stuffing e spraying: um pico na
   taxa *agregada* de falhas de login, ou na razão falha/sucesso do serviço inteiro. Se normalmente
   10% dos logins falham e de repente 85% falham, é campanha em curso, independentemente da
   distribuição por IP.
4. **Backoff exponencial** por conta em vez de bloqueio duro: 0 s, 1 s, 2 s, 4 s, 8 s… O OWASP sugere
   duplicar o atraso a cada falha. Isso torna brute force inviável sem criar um botão de DoS.
5. **Detecção de anomalia / risk-based**: novo dispositivo, novo país, ASN de proxy/VPN conhecido,
   horário atípico → exija MFA ou passo extra em vez de negar.
6. **Bloquear senha vazada** no cadastro e na troca (seção anterior).
7. **MFA** — a Microsoft estima que teria bloqueado **99,9%** dos comprometimentos de conta.

### Bloqueio de conta e o DoS que ele cria

Lockout permanente após N falhas transforma o login em arma: eu bloqueio a conta do seu CEO enviando
5 senhas erradas. Além disso, **a mensagem de "conta bloqueada" é um oráculo de enumeração**, e o
atacante pode usar o próprio lockout para descobrir quais e-mails existem.

Prefira: backoff exponencial + CAPTCHA + MFA obrigatório na próxima tentativa, com desbloqueio
automático após uma janela (15–30 min). Se precisar de lockout duro, aplique-o de forma que a resposta
ao cliente seja **idêntica** à de senha errada, e notifique o dono da conta por e-mail.

### CAPTCHA e seus custos

Compra: encarece a automação. Custa: acessibilidade (leitor de tela, deficiência motora, daltonismo),
conversão, e um terceiro no caminho crítico do login (reCAPTCHA envia dados do usuário e é bloqueado
em algumas redes/países). Serviços de resolução custam centavos por milhar — o OWASP registra que
ferramentas os contornam "com taxa de sucesso razoável". Uso correto é **condicional**: só após N
falhas na conta ou quando o sinal de risco dispara, nunca no primeiro POST de todo mundo. Alternativas
com menos atrito: proof-of-work no cliente, Private Access Tokens / Privacy Pass.

### Fingerprint de dispositivo e de conexão

Fingerprint de **dispositivo** (User-Agent, resolução, fontes, canvas, plugins) é spoofável — camada,
não controle. Fingerprint de **conexão** — JA3/JA4 (TLS ClientHello) e fingerprint de frames HTTP/2 —
é mais difícil de forjar porque depende da stack TLS/HTTP real, não de valores que o cliente declara.
O Credential Stuffing Prevention Cheat Sheet é explícito: bloqueio por IP "não deve ser usado como
defesa única ou principal, pela facilidade de contorno".

**Notificação ao usuário** é barata e eficaz: e-mail em login de dispositivo desconhecido, em senha
correta com MFA falhado (sinal forte de que a senha vazou), em múltiplos pedidos de reset de IPs
diferentes. Exponha "dispositivos ativos" com botão de encerrar sessão.

---

## User enumeration

Descobrir quais e-mails/usernames existem não é vulnerabilidade crítica sozinha, mas é o **pré-requisito
de custo** do credential stuffing e do spraying: reduz a lista de alvos em ordens de magnitude e
transforma um ataque caro em barato. Em bug bounty costuma ser aceito como Low/Info isolado e escala
para Medium quando combinado com login sem rate limit.

Canais que vazam, e o conserto de cada um:

| Canal | Como vaza | Conserto |
|---|---|---|
| **Mensagem de erro do login** | "Usuário não encontrado" vs. "Senha incorreta" | Mensagem única: `Login failed; Invalid user ID or password.` |
| **Timing do login** | Usuário inexistente retorna em ~1 ms; existente gasta os ~50 ms do Argon2 | Sempre rode o KDF, mesmo sem usuário: verifique contra um **hash dummy** fixo pré-computado |
| **Código/estrutura HTTP** | `401` vs `403`, `Content-Length` diferindo por 1 byte, campo `error_code` distinto, presença de header | Resposta byte-idêntica nos dois casos |
| **Cadastro** | "Este e-mail já está em uso" | Aceite o cadastro, responda `A link to activate your account has been emailed to the address provided.` e envie e-mail diferente para quem já tem conta ("alguém tentou criar conta com seu e-mail; faça login ou recupere a senha") |
| **Reset de senha** | "E-mail não cadastrado" | `If that email address is in our database, we will send you an email to reset your password.` — e tempo de resposta constante (envie o e-mail em fila assíncrona, não inline) |
| **Resposta de MFA** | Senha certa + usuário sem MFA vai direto; usuário com MFA vai para tela de código. Se a senha estiver errada e você já revela "esta conta usa MFA", vazou | Só revele a etapa de MFA **após** senha correta |
| **Lockout** | "Conta temporariamente bloqueada" só aparece para conta existente | Mesma mensagem genérica |
| **Login social** | `/auth/google/callback` responde diferente se o e-mail já está vinculado | Redirecione igual nos dois casos |
| **Autocomplete / API de disponibilidade** | `GET /api/users/check?email=` no formulário de cadastro | Rate limit agressivo + CAPTCHA; ou aceite o vazamento conscientemente e documente |
| **GraphQL** | Erro de resolver distinto, ou introspection permitindo query de usuário | Veja `references/api-e-graphql.md` |

```ts
// ❌ três oráculos: mensagem, timing e status
const user = await db.user.findUnique({ where: { email } })
if (!user) return reply.code(404).send({ error: 'Usuário não encontrado' })
if (!(await verify(user.hash, password)))
  return reply.code(401).send({ error: 'Senha incorreta' })

// ✅ resposta e custo idênticos nos dois caminhos
const DUMMY_HASH = process.env.DUMMY_ARGON2_HASH! // hash de uma senha aleatória, fixo
const user = await db.user.findUnique({ where: { email } })
const ok = await verifyArgon2(user?.hash ?? DUMMY_HASH, password)
if (!user || !ok)
  return reply.code(401).send({ error: 'Login failed; Invalid user ID or password.' })
```

O `DUMMY_HASH` precisa ter os **mesmos parâmetros** do hash real, senão o timing continua diferente. E
cuidado com a migração de algoritmo: se metade dos usuários está em bcrypt cost 10 e metade em
Argon2id, o timing distingue os dois grupos (vaza "conta antiga"), o que raramente importa mas vale
saber.

**Quando não fechar:** em produto B2B onde o cadastro é por convite e o e-mail corporativo é público,
gastar semanas fechando enumeração enquanto o login não tem MFA é priorização errada. Diga isso na
revisão.

---

## MFA e passkeys

### Força relativa dos fatores

| Fator | Resiste a phishing? | Ataques específicos | Veredito |
|---|---|---|---|
| **SMS / voz** | Não | SS7 (interceptação na rede de sinalização), **SIM swap** (engenharia social na operadora), port-out fraud, malware Android lendo SMS | **Restricted** na SP 800-63B-4 §3.2.9. Ainda melhor que nada: ativar SMS para uma base que não tem MFA reduz stuffing em ordens de magnitude. Não use em app financeiro/PII |
| **E-mail** | Não | Comprometimento da caixa = comprometimento de tudo | Proibido como out-of-band pelo NIST |
| **TOTP** (RFC 6238) | Não — código é phishável em tempo real (AiTM: Evilginx, Modlishka) | Replay dentro da janela, seed exposto no QR/backup, brute force do código de 6 dígitos sem rate limit | Bom custo-benefício. Padrão mínimo aceitável hoje |
| **Push (approve/deny)** | Não | **MFA fatigue / prompt bombing** | Só com number matching |
| **Push com number matching** | Não (mas resiste a fatigue) | AiTM ainda funciona | Aceitável |
| **U2F/FIDO2 hardware (YubiKey)** | **Sim** | Perda física; custo | Excelente |
| **Passkey (WebAuthn)** | **Sim** | Sincronização na nuvem move o risco para a conta Apple/Google; recuperação vira o elo fraco | **O destino de todo mundo** |

Nota do OWASP MFA Cheat Sheet: exigir duas instâncias do **mesmo** fator (senha + PIN) **não é MFA**.
E pergunta secreta deixou de ser fator aceitável segundo o NIST.

### TOTP: o que revisar

- **Seed**: 160 bits de CSPRNG, base32. O QR contém o segredo em claro na URL
  (`otpauth://totp/App:user@x?secret=...`) — nunca logue essa URL, nunca a mande por e-mail, e sirva o
  QR com `Cache-Control: no-store`.
- **Janela**: aceitar ±1 step de 30 s (total 90 s) é o razoável. `window: 10` (±5 min) é bug.
- **Replay**: um código válido por 30 s pode ser reusado dentro da janela se você não marcar consumo.
  Guarde o último `counter` aceito por usuário e **rejeite qualquer counter ≤ o último**.
- **Rate limit**: 6 dígitos = 1.000.000 de combinações, mas com janela de ±1 são 3 códigos válidos por
  instante; sem rate limit, um atacante acerta em minutos. Limite a 5 tentativas por código/janela e
  invalide a sessão parcial de login depois disso.
- **Ativação**: exija um código válido antes de gravar o seed como ativo, senão o usuário se tranca
  fora.
- **Códigos de 8 dígitos** onde a usabilidade permitir (recomendação do OWASP MFA Cheat Sheet).

### Push e MFA fatigue

O atacante já tem a senha. Ele dispara 50 pushes às 3h da manhã; o usuário aprova para o telefone
parar de vibrar. Foi assim no comprometimento da Uber em 2022 (push spam + mensagem no WhatsApp se
passando pelo TI).

Defesa primária: **number matching** — a tela de login exibe 2 dígitos que o usuário precisa **digitar**
no app; não existe botão "aprovar". A Microsoft tornou obrigatório em todos os tenants do Entra ID a
partir de **8 de maio de 2023**, e a CISA publicou fact sheet recomendando a prática. Defesa secundária:
limitar quantos prompts uma conta pode receber por janela, mostrar contexto no prompt (app, IP,
geolocalização) e oferecer botão "não fui eu" que revoga sessões e força troca de senha.

### WebAuthn e passkeys

É para onde tudo vai, e é o único mecanismo da lista que resiste a phishing por construção. A
especificação vigente é **WebAuthn Level 3** (W3C Candidate Recommendation Snapshot de 26 de maio de
2026).

**Como funciona.** No registro, o RP (relying party — sua aplicação) gera um `challenge` aleatório e
manda junto de `rp.id`, `user.id` e critérios de autenticador. O navegador constrói um
`clientDataJSON` contendo `{type, challenge, origin, crossOrigin}` — **o `origin` é preenchido pelo
navegador, não pela página** — e o autenticador gera um par de chaves ligado ao `rpId`, assinando o
`authenticatorData` + hash do `clientDataJSON`. Na autenticação, o mesmo par assina um novo challenge.

**Por que isso é phishing-resistant de verdade.** Duas amarrações independentes:

1. O autenticador só oferece a credencial se o `rpId` da requisição casar com o domínio efetivo da
   página. Um `contoso-secure.com` não consegue pedir credencial de `contoso.com`.
2. O `origin` gravado no `clientDataJSON` é assinado. Mesmo que o autenticador fosse enganado, o
   servidor compara `clientData.origin` com o valor esperado e rejeita.

É por isso que um proxy AiTM (Evilginx) — que derrota TOTP e push trivialmente, porque só repassa o
código digitado — **não** derrota WebAuthn: o proxy tem outro domínio, e o `origin` assinado o entrega.

**Discoverable credential (antigo "resident key").** Quando a credencial é *client-side discoverable*,
o autenticador guarda o handle do usuário e consegue apresentá-la sem que o servidor informe a lista
de `allowCredentials` — é o que viabiliza login sem digitar o e-mail (usernameless) e o autofill de
passkey via **conditional mediation** (`mediation: 'conditional'` + `autocomplete="username webauthn"`).
Controlado por `authenticatorSelection.residentKey: 'required' | 'preferred' | 'discouraged'`
(`requireResidentKey` é o campo legado do L1).

**Sincronizada vs. vinculada ao dispositivo.** O L3 define duas flags no `authenticatorData`:
**BE (Backup Eligibility)** e **BS (Backup State)**. `BE=0` significa credencial *single-device* (ex.:
YubiKey) — se o dispositivo se perde, a credencial se perde. `BE=1` significa *multi-device* — a
passkey pode ser sincronizada (iCloud Keychain, Google Password Manager, 1Password), e `BS=1` indica
que está sincronizada agora. Consequência de segurança: com passkey sincronizada, **a segurança da sua
conta herda a segurança da conta Apple/Google do usuário**. Para requisitos regulatórios de posse
física (FIDO2 device-bound), exija `BE=0` e verifique attestation.

**Attestation.** `attestationType: 'none' | 'indirect' | 'direct' | 'enterprise'`. Formatos definidos:
`packed`, `tpm`, `android-key`, `android-safetynet`, `fido-u2f`, `apple`, `compound`, `none`. Para
consumidor, use `'none'`: attestation revela modelo de autenticador (privacidade) e complica o fluxo
sem ganho real. Para corporativo com política de hardware homologado, use `'direct'` e valide contra
a **FIDO Metadata Service (MDS)**.

**Signal methods** (novidade do L3): `signalCurrentUserDetails`, `signalAllAcceptedCredentials` e
`signalUnknownCredential` permitem que o RP diga ao gerenciador de senhas que uma credencial foi
revogada ou que o username mudou — evita a passkey órfã que fica aparecendo no autofill depois que o
usuário a removeu no seu site.

**Extensões úteis:** `prf` (deriva material simétrico a partir da credencial — base para criptografia
E2E ligada à passkey), `largeBlob` (armazena blob cifrado por credencial).

**Implementação em Node — SimpleWebAuthn v13:**

```ts
import {
  generateRegistrationOptions, verifyRegistrationResponse,
  generateAuthenticationOptions, verifyAuthenticationResponse,
} from '@simplewebauthn/server'

const rpID = 'exemplo.com'                 // domínio, sem esquema nem porta
const origin = 'https://exemplo.com'       // com esquema

// registro
const options = await generateRegistrationOptions({
  rpName: 'Exemplo', rpID,
  userID: new Uint8Array(userIdBytes),     // desde a v10 é Uint8Array, string lança
  userName: user.email,
  attestationType: 'none',
  excludeCredentials: existing.map(c => ({ id: c.id, transports: c.transports })),
  authenticatorSelection: { residentKey: 'preferred', userVerification: 'preferred' },
})
await saveChallenge(session.id, options.challenge) // server-side, uso único, TTL curto

const verification = await verifyRegistrationResponse({
  response: body,
  expectedChallenge: await popChallenge(session.id), // ❗ nunca aceite challenge vindo do cliente
  expectedOrigin: origin,
  expectedRPID: rpID,
})
// v13: a credencial verificada vive em registrationInfo.credential
const { id, publicKey, counter, transports } = verification.registrationInfo!.credential

// autenticação
const auth = await verifyAuthenticationResponse({
  response: body,
  expectedChallenge: await popChallenge(session.id),
  expectedOrigin: origin,
  expectedRPID: rpID,
  credential: { id: stored.id, publicKey: stored.publicKey, counter: stored.counter,
                transports: stored.transports },
  requireUserVerification: true,
})
// ❗ persista o novo contador, senão a proteção contra clonagem de chave de hardware não funciona
await db.credential.update({ where: { id: stored.id },
  data: { counter: auth.authenticationInfo.newCounter } })
```

Erros recorrentes em revisão de WebAuthn:

- `expectedChallenge` lido do corpo da requisição em vez do estado do servidor → assinatura de replay
  passa.
- Challenge sem TTL ou reutilizável → replay.
- `expectedOrigin` como array grande demais ou construído do header `Origin` da requisição → destrói a
  amarração de origem, que é *o* controle.
- `rpID` com esquema/porta (`https://exemplo.com:443`) → falha silenciosa ou aceita errado.
- Não atualizar `counter` → clone de autenticador não é detectado (só relevante para `BE=0`; passkeys
  sincronizadas costumam reportar `0`).
- `excludeCredentials` vazio no registro → usuário cria passkeys duplicadas no mesmo autenticador.
- Vincular a passkey ao usuário **antes** de `verifyRegistrationResponse` retornar `verified: true`.

**Mobile:** iOS usa Associated Domains (`apple-app-site-association` com `webcredentials:exemplo.com`)
e `ASAuthorizationPlatformPublicKeyCredentialProvider`; Android usa Digital Asset Links
(`/.well-known/assetlinks.json`) e Credential Manager. O `rpId` é o domínio, e o app só consegue usar
a credencial se o arquivo de associação estiver publicado no domínio — é o mesmo mecanismo de origin
binding. Veja `references/mobile.md`.

### Códigos de recuperação

Toda MFA precisa de saída de emergência, e ela é o novo caminho mais fraco. Regras:

- 8–10 códigos de ≥ 20 bits de entropia cada, gerados com CSPRNG, exibidos **uma vez**.
- **Armazenados com hash** (podem usar um KDF mais barato, já que têm alta entropia — não são
  adivinháveis; `sha256` com salt é aceitável aqui, ao contrário de senha).
- **Uso único**, com invalidação atômica (`UPDATE ... WHERE id = ? AND used_at IS NULL` e checar
  `rowCount`) — senão dá race condition.
- Regenerar todos ao usar um, ou pelo menos avisar quantos restam.
- Rate limit no consumo, igual ao TOTP.
- Consumir código de recuperação deve **notificar por e-mail** e, idealmente, exigir re-configuração
  do MFA.

Não faça: fluxo de "perdi meu MFA" que só pede o e-mail. Isso reduz MFA a "quem controla o e-mail
entra", ou seja, elimina o segundo fator. Se precisar existir, imponha atraso (24–72 h) com
notificação e possibilidade de cancelamento.

### Onde MFA é frequentemente esquecido

Estes são bugs de bug bounty clássicos — o MFA está na tela de login e em nenhum outro lugar:

- **Reset de senha**: fluxo de "esqueci a senha" que autentica só pelo token do e-mail e loga o
  usuário, pulando o MFA. Bypass completo.
- **Endpoint legado**: `/api/v1/login` antigo mantido para o app mobile antigo, sem a etapa de MFA.
- **API token / personal access token**: emitido por um usuário e usado depois sem MFA — correto,
  mas a **emissão** precisa de step-up.
- **Login social**: entrar por "Sign in with Google" pula o MFA local do seu app.
- **"Remember this device"**: cookie de confiança sem expiração, sem vínculo com a sessão, ou com
  valor previsível.
- **Step-up ausente em operação sensível**: trocar e-mail, trocar senha, desativar MFA, adicionar
  chave SSH/webhook, criar API key, transferir dinheiro, convidar admin, exportar dados. O OWASP MFA
  Cheat Sheet lista explicitamente: login, troca de senha/pergunta, troca de e-mail, desativação de
  MFA e elevação a sessão administrativa.

```ts
// ✅ step-up: exige reautenticação recente para operação sensível
const MAX_AGE_MS = 5 * 60_000
if (Date.now() - session.lastStrongAuthAt > MAX_AGE_MS) {
  return reply.code(401).send({ error: 'reauthentication_required', step: 'mfa' })
}
```

Grave `lastStrongAuthAt` na sessão **server-side**. Se estiver num JWT que o cliente devolve, o
atacante com o token simplesmente não atualiza o campo — e você acabou de fazer controle de segurança
com dado controlado pelo cliente.

---

## Sessão

### Session ID

| Propriedade | Requisito (OWASP Session Management Cheat Sheet) |
|---|---|
| Entropia | **≥ 64 bits**. Na prática: 128 bits (`randomBytes(16)`), ou 256 bits se barato |
| Geração | CSPRNG obrigatório — `crypto.randomBytes` / `crypto.randomUUID`, **nunca** `Math.random()`, `Date.now()`, contador ou hash de dados do usuário |
| Conteúdo | Opaco e sem significado. Nada de `base64(userId:role)`. Todo o estado fica no servidor |
| Nome do cookie | Evite defaults que dedam a stack (`PHPSESSID`, `JSESSIONID`, `connect.sid`); use algo genérico com prefixo `__Host-` |
| Transporte | Apenas cookie. Nunca em URL (vaza em log de proxy, histórico, `Referer`), nunca em campo oculto |

```ts
// ❌ previsível: Math.random não é CSPRNG e o timestamp é público
const sid = Math.random().toString(36).slice(2) + Date.now()

// ❌ o ID carrega significado — o atacante forja
const sid = Buffer.from(`${user.id}:${user.role}`).toString('base64')

// ✅ 128 bits de CSPRNG, opaco
import { randomBytes } from 'node:crypto'
const sid = randomBytes(32).toString('base64url')
```

Armazene o **hash** do session ID no banco/Redis (`sha256(sid)`), não o valor bruto: um dump de tabela
de sessões ou um log com o valor deixa de ser sequestro imediato. O OWASP recomenda logar apenas o
hash salgado do session ID.

### Session fixation

O atacante fixa um session ID conhecido no navegador da vítima (por link com o ID na URL, por
`Set-Cookie` a partir de um subdomínio que ele controla, ou por XSS), a vítima faz login, e o servidor
**reaproveita o mesmo ID** — que o atacante já tem. WSTG-SESS-03.

A regra é curta: **regenere o session ID em toda mudança de nível de privilégio.** Login, logout,
elevação a admin, saída de impersonation, conclusão de step-up, aceitação de convite. O OWASP é
explícito: "Renew the Session ID After Any Privilege Level Change".

```ts
// ❌ express-session sem regeneração: o ID pré-login continua válido
app.post('/login', async (req, res) => {
  const user = await authenticate(req.body)
  req.session.userId = user.id   // mesmo sid de antes
  res.redirect('/dashboard')
})

// ✅ regenera e só então grava a identidade
app.post('/login', async (req, res) => {
  const user = await authenticate(req.body)
  req.session.regenerate(err => {
    if (err) return res.status(500).end()
    req.session.userId = user.id
    req.session.lastStrongAuthAt = Date.now()
    req.session.save(() => res.redirect('/dashboard'))
  })
})
```

Complemento: **não aceite session ID que você não emitiu**. Se chega um cookie com ID inexistente no
store, emita um novo em vez de "adotar" o valor do cliente (é o *strict mode* do PHP;
`saveUninitialized: false` no `express-session` ajuda a não criar sessão para visitante anônimo).

### Timeout absoluto vs. inatividade

| Tipo | O que é | Valores sugeridos pelo OWASP |
|---|---|---|
| **Idle (inatividade)** | Expira após N minutos sem requisição | 2–5 min em aplicação de alto valor (banco); 15–30 min em aplicação de baixo risco |
| **Absoluto** | Expira N horas após a criação, independentemente de atividade | 4–8 h para aplicação de jornada de trabalho |
| **Renewal** | Regenera o ID periodicamente durante a sessão, mantendo o estado | Complementar aos dois |

Os dois são necessários: só idle permite sessão eterna de quem mantém uma aba com polling; só absoluto
deixa a sessão viva num computador compartilhado abandonado. **Ambos devem ser verificados no
servidor** — `Max-Age` do cookie é dica para o navegador, não controle: o atacante que roubou o cookie
o replica sem `Max-Age`.

### Logout que realmente invalida

```ts
// ❌ só apaga o cookie do navegador; o ID continua válido no Redis
res.clearCookie('__Host-sid')
res.redirect('/')

// ✅ destrói server-side primeiro
await sessionStore.destroy(sessionId)
res.clearCookie('__Host-sid', { path: '/', secure: true, httpOnly: true, sameSite: 'lax' })
res.setHeader('Clear-Site-Data', '"cache", "cookies", "storage"')
res.setHeader('Cache-Control', 'no-store')
```

`Clear-Site-Data` (suportado por Chrome e Firefox; Safari historicamente não implementa) limpa cache,
cookies e storage do site. Não substitui a destruição server-side.

Teste de revisão: pegue o cookie de sessão com o DevTools, faça logout, reenvie a requisição com o
cookie antigo via curl. Se responder 200, o logout é decorativo. É um achado comum e frequentemente
aceito como Medium.

### Invalidação em massa

Após **troca de senha**, **reset de senha**, **desativação de MFA**, **remoção de usuário da
organização** e **detecção de comprometimento**, todas as outras sessões do usuário devem morrer. Duas
implementações:

1. **Store com índice por usuário**: `SMEMBERS sessions:user:{id}` → `DEL` em cada uma. Preciso,
   permite "encerrar esta sessão" individual na UI.
2. **`session_version` (ou `token_version`) na linha do usuário**: incrementa a cada evento; o
   middleware compara a versão gravada na sessão/token com a do banco. Barato, funciona com JWT, mas
   custa uma leitura por requisição — o que já anula metade do argumento do JWT stateless.

Deixe o usuário ver as sessões ativas (dispositivo, IP, última atividade, localização aproximada) e
encerrá-las. Sobre sessão concorrente: permitir várias é o padrão razoável; restringir a uma só é
decisão de produto (comum em banco), e a implementação precisa decidir se a nova sessão derruba a
antiga ou é recusada.

---

## Cookies

| Atributo | Valor recomendado | O que quebra se você errar |
|---|---|---|
| `Secure` | sempre | Cookie trafega em HTTP; MITM em rede aberta rouba a sessão. Obrigatório para `SameSite=None` e para os prefixos |
| `HttpOnly` | sempre (cookie de sessão) | XSS lê `document.cookie` e exfiltra a sessão. Veja `references/xss-e-navegador.md` |
| `SameSite` | `Lax` (padrão prático) ou `Strict` | `None` sem defesa de CSRF = CSRF clássico |
| `Path` | `/` (exigido por `__Host-`) | `Path` restritivo não é fronteira de segurança — outro path do mesmo host lê via DOM |
| `Domain` | **omitir** | Com `Domain=exemplo.com`, o cookie vai para **todos** os subdomínios |
| `Max-Age`/`Expires` | omitir para sessão (cookie de sessão do navegador) | Cookie persistente sobrevive a fechar o navegador. `Max-Age` tem precedência sobre `Expires` |
| Prefixo | `__Host-` | Sem ele, um subdomínio pode sobrescrever seu cookie de sessão |
| `Partitioned` | conforme necessidade de embed cross-site (CHIPS) | Exige `Secure` |

### SameSite: o que cada valor custa

- **`Strict`** — o cookie nunca acompanha requisição iniciada por outro site, **incluindo navegação
  top-level**. Consequência de UX: o usuário clica num link do seu app vindo do Slack/e-mail e chega
  deslogado. Resolve-se com um "gateway" (`/enter?next=...` que faz redirect same-site) ou com dois
  cookies (um `Strict` para operações sensíveis, um `Lax` para "está logado").
- **`Lax`** — acompanha navegação top-level com método seguro (GET). Bloqueia POST cross-site, que é
  a forma clássica de CSRF. É o default de fato do Chrome desde 2020 (com a exceção "Lax+POST": cookie
  sem `SameSite` explícito acompanha POST cross-site nos **primeiros 2 minutos** após ser setado — não
  confie nisso, declare `SameSite` explicitamente).
- **`None`** — necessário para SSO em iframe, widget embutido, API consumida de outra origem. Exige
  `Secure` e **exige token anti-CSRF de verdade**.

`SameSite` sozinho **não é defesa completa de CSRF**: não protege contra requisição vinda de um
subdomínio do mesmo site (que é same-site), e a proteção some se você precisar de `None`. Veja
`references/xss-e-navegador.md` para a defesa de CSRF em si.

### Por que `Domain=.exemplo.com` é perigoso

Se você emite `Set-Cookie: sid=...; Domain=exemplo.com`, o cookie é enviado para `www.exemplo.com`,
`api.exemplo.com`, `blog.exemplo.com`, `status.exemplo.com` e para o `promo-2019.exemplo.com` apontado
para um Heroku que você desligou. Consequências:

1. **Vazamento**: XSS em qualquer subdomínio (incluindo aquele WordPress do marketing) lê o cookie se
   ele não for `HttpOnly`, e o envia para o servidor do atacante se for — porque o subdomínio pode
   fazer uma requisição a `exemplo.com` com o cookie anexado.
2. **Subdomain takeover**: um CNAME órfão apontando para bucket/serviço não reclamado permite ao
   atacante hospedar conteúdo em `antigo.exemplo.com`, ler o cookie e — pior — **setar** cookies para
   `exemplo.com` (cookie tossing / session fixation), porque a *same-origin policy* não vale para
   cookies: subdomínios podem escrever cookies do domínio pai. Veja
   `references/ssrf-e-camada-http.md`.

A defesa é o prefixo. `__Host-` **proíbe** o atributo `Domain`, exige `Secure` e exige `Path=/` — o que
significa que o cookie é host-only e **não pode ser sobrescrito por subdomínio**. É a única defesa real
contra cookie tossing.

```
Set-Cookie: __Host-sid=<128 bits base64url>; Secure; HttpOnly; SameSite=Lax; Path=/
```

`__Secure-` é mais fraco: só exige `Secure` e origem HTTPS; ainda permite `Domain`.

Nota MDN relevante: ponto inicial em `Domain` (`.exemplo.com`) é **ignorado** pelas especificações
atuais — `.exemplo.com` e `exemplo.com` têm o mesmo efeito, e ambos incluem subdomínios.

### Cookie de sessão vs. token no `localStorage`

A discussão honesta, porque a resposta "nunca use localStorage" é repetida sem o raciocínio:

| | Cookie `HttpOnly` | Token em `localStorage` |
|---|---|---|
| XSS lê a credencial? | **Não** diretamente | **Sim**, uma linha: `fetch(evil + localStorage.token)` |
| XSS consegue agir como o usuário? | Sim — faz requisições autenticadas de dentro da página | Sim, e ainda leva a credencial embora |
| CSRF? | **Sim**, precisa de defesa (`SameSite`, token anti-CSRF, checagem de `Origin`) | Não (o header `Authorization` não é anexado automaticamente) |
| Revogação | Server-side, trivial | Depende do desenho do token |
| Cross-domain (API em outro site) | Precisa `SameSite=None` + CORS com `credentials` | Simples |
| Mobile / não-navegador | Não se aplica | Natural |

O ponto que decide: **com XSS, o cookie `HttpOnly` limita o atacante a agir enquanto a página está
aberta; o `localStorage` entrega uma credencial portátil que ele usa de outra máquina por dias.** A
diferença entre "sessão comprometida" e "credencial roubada" é material — para resposta a incidente,
inclusive.

Portanto: **para aplicação web, cookie `HttpOnly` + `SameSite` + defesa de CSRF.** `localStorage` só
quando a arquitetura obriga (SPA consumindo API em domínio completamente diferente, sem possibilidade
de proxy same-origin). Padrão intermediário usado por muitos: refresh token em cookie `HttpOnly` com
`Path=/auth/refresh`, access token de vida curta em memória JavaScript (variável de módulo, nunca
`localStorage`) — sobrevive a navegação por refresh silencioso e não sobrevive a um XSS que só lê
storage. Não é imune, mas é estritamente melhor.

`sessionStorage` não é mais seguro que `localStorage` contra XSS; só tem escopo de aba.

---

## JWT

Fonte constante de erro. Trate cada JWT em revisão como suspeito até provar o contrário.

### O que é, e o que não é

`header.payload.signature`, cada parte em **base64url** (sem padding). Base64 **não é criptografia**:
qualquer pessoa com o token lê o payload. `jwt.io`, `echo <payload> | base64 -d`, um `atob()` no
console — tudo funciona.

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIiwicm9sZSI6ImFkbWluIn0.<sig>
                 ↓ base64 -d                        ↓ base64 -d
{"alg":"HS256","typ":"JWT"}          {"sub":"1","role":"admin"}
```

Consequência prática: **CPF, e-mail, telefone, endereço, plano, saldo, flag de feature interna, ID
interno de banco — nada disso deveria estar no payload** se o token trafega para o navegador ou fica
em log. E JWT fica em log: proxy reverso que loga `Authorization`, APM, Sentry, `console.log` de
debug, URL com `?token=`.

Um JWT **assinado** (JWS) garante integridade e autenticidade, não confidencialidade. Para
confidencialidade existe **JWE**, que quase ninguém usa.

Claims registradas na RFC 7519: `iss`, `sub`, `aud`, `exp`, `nbf`, `iat`, `jti`.

### Falhas clássicas

| Falha | Mecanismo | Sinal em revisão |
|---|---|---|
| **`alg: none`** | Header `{"alg":"none"}` com assinatura vazia. Biblioteca que aceita `none` valida nada. Variações de case (`nOnE`) driblam blocklist ingênua | Biblioteca antiga; `verify` sem `algorithms` |
| **Confusão RS256 → HS256** | Servidor chama `verify(token, key)` genérico. Atacante troca `alg` para `HS256` e assina com a **chave pública** (bytes exatos do PEM, incluindo `\n`) como segredo HMAC. O servidor faz HMAC com a mesma chave pública e valida | Chave pública exposta em `/.well-known/jwks.json`; `verify` sem allowlist de algoritmo |
| **`kid` injection** | `kid` é usado para localizar a chave. Se vira caminho de arquivo: `"kid":"../../../../dev/null"` → chave = string vazia → HMAC com `""`. Se vira query SQL: `"kid":"x' UNION SELECT 'chave-conhecida'--"`. Se vira comando: injeção de comando | `kid` concatenado em path, SQL ou shell |
| **`jku` / `x5u`** | Header aponta para a URL do JWK Set. Sem allowlist, o atacante hospeda o próprio JWKS e assina o token com a chave correspondente. Também é vetor de SSRF | `jku` lido do token sem allowlist |
| **`jwk` embutido** | O header carrega a chave pública inteira. Biblioteca que a usa para verificar aceita qualquer token autoassinado | Uso de `jwk` do header |
| **Segredo HMAC fraco** | `"secret"`, `"changeme"`, `JWT_SECRET` de exemplo do tutorial. Crackável **offline**, sem tocar no servidor: `hashcat -m 16500 jwt.txt wordlist.txt`, ou `jwt_tool <JWT> -C -d lista.txt` | Segredo hardcoded, curto, ou vindo de `.env` commitado |
| **`exp`/`nbf` não validados** | Token nunca expira na prática; sessão roubada vale para sempre | `decode()` em vez de `verify()` |
| **`iss` não validado** | Token emitido por outro tenant/IdP é aceito | Falta `issuer` nas opções |
| **`aud` não validado (audience confusion)** | Token emitido para o serviço A é aceito pelo serviço B que compartilha a chave. Em multi-tenant: token do tenant X aceito no tenant Y | Falta `audience` nas opções |
| **Cross-JWT confusion** | Token de um tipo (ex.: reset de senha, verificação de e-mail) aceito onde se espera outro (access token), porque só a assinatura é checada | Um único segredo e uma única função `verify` para todos os propósitos |

A RFC 8725 (**BCP 225**, fev/2020) codifica as defesas. As doze recomendações da Seção 3, pelos nomes
exatos: *Perform Algorithm Verification*; *Use Appropriate Algorithms*; *Validate All Cryptographic
Operations*; *Validate Cryptographic Inputs*; *Ensure Cryptographic Keys Have Sufficient Entropy*;
*Avoid Compression of Encryption Inputs*; *Use UTF-8*; *Validate Issuer and Subject*; *Use and Validate
Audience*; *Do Not Trust Received Claims*; *Use Explicit Typing*; *Use Mutually Exclusive Validation
Rules for Different Kinds of JWTs*.

Há um sucessor em andamento — `draft-ietf-oauth-rfc8725bis` (draft-07, julho/2026), ainda
**Internet-Draft, não RFC** — que acrescenta §3.13 *Limit Hash Iteration Count* (DoS via PBES2 com
`p2c` gigante), §3.14 *Check JWT Format Type* e §3.15 *Limit JWE Decompression Size* (zip bomb), e
renomeia §3.10 para *Carefully Evaluate Received Claims*.

### Validação correta

A regra central: **o algoritmo aceito vem da sua configuração, nunca do header do token.** O `alg` do
token é entrada do atacante.

```ts
// ❌ decode não verifica NADA — é só base64 decode
const claims = jwt.decode(token)
if (claims.role === 'admin') { /* ... */ }

// ❌ verify sem allowlist: jsonwebtoken infere os algoritmos pelo tipo da chave.
// Com secret string → ['HS256','HS384','HS512']; com chave RSA → ['RS256','RS384','RS512'].
// É exatamente o buraco da confusão de algoritmo em código que aceita ambos.
const claims = jwt.verify(token, key)

// ✅ jsonwebtoken ≥ 9: allowlist explícita + todas as claims
const claims = jwt.verify(token, publicKey, {
  algorithms: ['RS256'],       // ❗ único item, fixo
  issuer: 'https://auth.exemplo.com',
  audience: 'https://api.exemplo.com',
  clockTolerance: 5,           // segundos, para drift de relógio
  maxAge: '15m',
})
```

```ts
// ✅ jose (panva) — API que erra menos por padrão
import { jwtVerify, createRemoteJWKSet } from 'jose'

const JWKS = createRemoteJWKSet(new URL('https://auth.exemplo.com/.well-known/jwks.json'))

const { payload, protectedHeader } = await jwtVerify(token, JWKS, {
  algorithms: ['RS256'],
  issuer: 'https://auth.exemplo.com',
  audience: 'https://api.exemplo.com',
  typ: 'at+jwt',                        // typing explícito (RFC 8725 §3.11)
  requiredClaims: ['sub', 'jti'],
  clockTolerance: '5s',
  maxTokenAge: '15m',
})
```

Depois de verificar a assinatura, **ainda valide o conteúdo**: `sub` existe e mapeia para um usuário
ativo; o tenant do token bate com o tenant do recurso; `role` do token é confrontada com a fonte de
verdade quando a operação é sensível (papel embutido em token de 24 h significa que uma demissão leva
24 h para ter efeito).

### Bibliotecas Node

| Biblioteca | Versão atual | Defaults e armadilhas |
|---|---|---|
| **`jsonwebtoken`** (auth0) | 9.0.3 | `verify` **não exige** `algorithms` — infere pelo tipo da chave. `none` é um algoritmo suportado. CVEs de dez/2022 corrigidas na **9.0.0**: **CVE-2022-23540** (algoritmo padrão inseguro no `verify`), **CVE-2022-23541** (função de recuperação de chave insegura permitindo forjar RSA→HMAC), **CVE-2022-23539**. A **CVE-2022-23529** (dita RCE) foi depois **retratada/disputada** pela Unit 42 por pré-requisitos irrealistas — mas o endurecimento da 9.0.0 vale. **Nunca use < 9.0.0** |
| **`jose`** (panva) | 6.2.7 | Zero dependências. **Rejeita `alg:"none"` sempre**, independente de opção. `algorithms` também não é obrigatório (aceita os aplicáveis à chave) — passe mesmo assim. `createRemoteJWKSet` faz cache e rotação de JWKS com rate limit embutido. **GHSA-hhhv-q57g-882q / CVE-2024-28176**: DoS por JWE com `zip` DEFLATE (bomba de descompressão), corrigido em 2.0.7 / 4.15.5 / 5.2.3 |
| **`fast-jwt`** | 6.3.1 | Base do ecossistema Fastify. Configure `createVerifier({ algorithms: [...] })` |
| **`@fastify/jwt`** | 10.2.1 | Wrapper de `fast-jwt ^6`. Fixe com `verify: { allowedAlgorithms: ['RS256'] }` |
| **`jwks-rsa`** | 4.1.0 | v4 depende de `jose ^6`. Ative `cache: true`, `rateLimit: true` — senão cada token com `kid` desconhecido vira uma requisição ao IdP (amplificação de DoS) |

### O problema estrutural: revogação

Um JWS válido é válido até `exp`. Não existe "cancelar". Isso não é bug de implementação, é a natureza
de um token autocontido — e é a razão pela qual "JWT é stateless" quase sempre é meia verdade.

Estratégias reais, do mais leve ao mais correto:

1. **TTL curto + refresh token.** Access token de 5–15 min, refresh de dias em cookie `HttpOnly`. A
   janela de exposição vira o TTL. É o padrão de fato. Não resolve revogação imediata — só a limita.
2. **Denylist por `jti`.** Guarde os `jti` revogados em Redis com TTL igual ao `exp` restante. Custa
   uma leitura por requisição, mas a lista é pequena (só tokens revogados antes de expirar).
3. **`token_version` no usuário.** O token carrega `ver: 3`; a cada logout global/troca de senha o
   contador incrementa e todos os tokens antigos morrem. Uma leitura por requisição (cacheável), mas
   granularidade de usuário, não de sessão.
4. **Sessão server-side com o JWT como cache.** O token carrega `sid`, o servidor valida a assinatura
   (barato) e checa `sid` no store (uma leitura). Se você chegou aqui, admita: você tem sessão
   server-side com passos a mais.

**Não** faça: TTL de 30 dias "porque o usuário reclama de deslogar". Isso é um token de sequestro
permanente com validade de um mês.

### Refresh token: rotação e detecção de reuso

O RFC 9700 §2.2.2 é normativo: *"Refresh tokens for public clients MUST be sender-constrained or use
refresh token rotation as described in Section 4.14."*

Rotação: cada uso do refresh token emite um **novo** refresh token e invalida o anterior. O ganho real
vem da **detecção de reuso** (§4.14): se um refresh token **já invalidado** for apresentado, isso só
pode significar que alguém tem uma cópia — ou o atacante roubou e usou antes da vítima, ou o
contrário. A resposta prescrita é **revogar toda a família de tokens daquele grant**.

```ts
// ✅ rotação com detecção de reuso
const rec = await db.refreshToken.findUnique({ where: { hash: sha256(presented) } })

if (!rec) return reply.code(401).send({ error: 'invalid_grant' })

if (rec.usedAt) {
  // reuso: a família inteira está comprometida
  await db.refreshToken.updateMany({
    where: { familyId: rec.familyId, revokedAt: null },
    data: { revokedAt: new Date() },
  })
  await alertUser(rec.userId, 'possible_token_theft')
  return reply.code(401).send({ error: 'invalid_grant' })
}

// marca como usado atomicamente e emite o próximo da família
const { count } = await db.refreshToken.updateMany({
  where: { id: rec.id, usedAt: null },
  data: { usedAt: new Date() },
})
if (count === 0) return reply.code(401).send({ error: 'invalid_grant' }) // corrida perdida
```

Armazenamento do refresh token: **hash no banco** (é uma credencial de longa duração — trate como
senha de alta entropia; `sha256` basta), cookie `HttpOnly; Secure; SameSite=Lax; Path=/auth/refresh`
no navegador, Keychain/Keystore no mobile (veja `references/mobile.md`). Nunca em `localStorage`.

Uma alternativa a rotação é **sender-constraining**: mTLS (RFC 8705) ou DPoP (RFC 9449), tratados na
seção de OAuth.

### Quando NÃO usar JWT

A resposta honesta, porque JWT virou default sem análise: **para sessão de aplicação web monolítica (ou
de qualquer app com um único backend), cookie de sessão server-side é quase sempre a escolha melhor.**

Argumento:

- O ganho anunciado do JWT é evitar a leitura de sessão. Mas você vai precisar dessa leitura de
  qualquer forma — para revogar, para checar `token_version`, para invalidar em massa, para dados de
  usuário atualizados. E `GET` num Redis local custa < 1 ms; num app que já faz 5 queries no Postgres
  por requisição, isso não é o gargalo.
- O custo do JWT é uma superfície de ataque inteira (esta seção) que o cookie opaco simplesmente não
  tem: não há `alg`, não há `kid`, não há confusão de audiência, não há segredo HMAC crackável.
- O payload do JWT é público e cresce; um cookie de 4 KB com claims vai em toda requisição, inclusive
  para assets.
- JWT joga o estado de autenticação no cliente — logout, ban e mudança de papel deixam de ser
  imediatos.

JWT faz sentido quando: (a) o token cruza **fronteiras de confiança** — de um IdP para múltiplos
serviços que não compartilham banco de sessão; (b) **federação** (é o formato do OIDC ID token e do
access token JWT); (c) autenticação **machine-to-machine** de vida curta; (d) o receptor precisa
validar sem chamar o emissor.

### PASETO e JWE

**PASETO** (Platform-Agnostic Security Tokens) elimina a agilidade criptográfica que causa metade dos
bugs: **não existe header `alg`**. A versão fixa a suíte inteira e o "purpose" é explícito no prefixo
do token.

- `v4.local.<...>` — simétrico: **XChaCha20** para cifrar + **BLAKE2b com chave** para o tag de
  autenticação, com derivação de subchaves por domínio (`paseto-encryption-key`,
  `paseto-auth-key-for-aead`).
- `v4.public.<...>` — assinatura **Ed25519**; payload assinado e **não** cifrado, com footer opcional
  autenticado.
- `v3.*` — variantes com primitivas NIST (AES-256-CTR + HMAC-SHA384; ECDSA P-384) para quem precisa
  de compliance.

Consequência: `alg: none` e confusão RS256/HS256 são **impossíveis por construção**. Timestamps são
ISO-8601 (`"exp":"2026-01-01T00:00:00Z"`) em vez de epoch. Custo: ecossistema muito menor e nenhum IdP
comercial fala PASETO.

**JWE** cifra o payload (`header.encrypted_key.iv.ciphertext.tag` — cinco partes, não três). Dois
pontos que a RFC 8725 §2.3 marca:

- **Ordem de composição**: o correto é **assinar e depois cifrar** (JWS aninhado dentro do JWE).
  Cifrar-e-depois-assinar permite que um atacante remova a assinatura externa e reassine o mesmo
  ciphertext — a assinatura não fica ligada ao plaintext — além de expor a identidade do signatário.
- **Invalid Curve Attack (2017, Antonio Sanso/Adobe)**: implementações de `ECDH-ES` em **go-jose,
  node-jose, jose2go, Nimbus JOSE+JWT e jose4j** não verificavam se o ponto público recebido estava na
  curva. Enviando pontos inválidos e observando o resultado da decifragem, era possível **recuperar a
  chave privada estática do receptor**. Lição de revisão: qualquer código que faça ECDH com chave
  fornecida pelo par precisa validar o ponto.
- Descompressão (`zip: "DEF"`) é vetor de DoS — foi a CVE-2024-28176 do `jose`, e virou a nova §3.15
  do rfc8725bis.

Detecção rápida em revisão:

```bash
grep -rn "jwt.decode\|jsonwebtoken" --include=*.ts --include=*.js .
grep -rn "verify(.*)" --include=*.ts . | grep -v "algorithms"
grep -rn "algorithms\s*:\s*\[" --include=*.ts .        # confira se tem mais de um item
grep -rn "jku\|x5u\|\"kid\"\|header.kid" --include=*.ts .
grep -rn "JWT_SECRET\|jwtSecret" --include=*.ts --include=*.env* .   # segredo curto/hardcoded?
grep -rn "ignoreExpiration\|ignoreNotBefore" --include=*.ts .
```

---

## OAuth 2.0 e OIDC

### OAuth não é autenticação

O erro conceitual mais caro da área. **OAuth 2.0 (RFC 6749) é um protocolo de delegação de
autorização**: ele responde "este cliente pode acessar aquele recurso em nome de alguém". O access
token é um *bearer token* opaco para o cliente — ele diz o que pode ser feito, **não quem é o
usuário**. **OpenID Connect** é a camada de identidade construída sobre OAuth, e o que carrega
identidade é o **ID token** (um JWT com `iss`, `sub`, `aud`, `exp`, `iat`, `nonce`).

O bug que decorre disso: "login com Facebook" implementado como *"o cliente me mandou um access token;
eu chamo `/me` com ele; o e-mail que voltar é o usuário"*. Isso é autenticação por posse de bearer
token — e um access token pode ter sido emitido para **outro aplicativo**. Um app malicioso qualquer
consegue um token do mesmo IdP para a mesma vítima e o replay no seu endpoint. É o **token
substitution attack**, e por isso o OIDC existe. Se o seu código tem `POST /auth/social` recebendo
`access_token` do cliente, marque como falha.

Correções: use o **Authorization Code flow** (o cliente devolve um `code`, você o troca por tokens no
back-channel, autenticando-se ao IdP), valide o **ID token** com as regras abaixo, ou — se precisar
aceitar token do cliente — chame o endpoint de introspection/tokeninfo do provedor e **verifique que
`aud`/`client_id` é o seu**.

### Fluxos

| Fluxo | Uso hoje |
|---|---|
| **Authorization Code + PKCE** | **O padrão para tudo** — SPA, mobile, e também cliente confidencial no servidor. O RFC 9700 e o OAuth 2.1 exigem PKCE em todos os clientes que usam o code flow, não só nos públicos |
| **Client Credentials** | Máquina-a-máquina, sem usuário. Sem `redirect_uri`, sem PKCE |
| **Device Authorization Grant** (RFC 8628) | TV, CLI, dispositivo sem teclado/navegador |
| **Refresh Token** | Renovação. Para cliente público, **MUST** ser sender-constrained ou rotacionado (RFC 9700 §2.2.2) |
| **Implicit** (`response_type=token`) | **Morto.** Devolvia o access token no fragmento da URL — vaza em `Referer`, histórico, log de browser extension, e não tem como amarrar ao cliente. Omitido do OAuth 2.1 |
| **Resource Owner Password Credentials (ROPC)** | **Morto.** O cliente coleta a senha do usuário, o que destrói a premissa do OAuth, impede MFA e federação. Omitido do OAuth 2.1 |

O **OAuth 2.1** (`draft-ietf-oauth-v2-1`, ainda Internet-Draft) consolida RFC 6749 + 6750 + 7636 +
RFC 9700 e formaliza: PKCE obrigatório no code flow; **comparação exata de string** para
`redirect_uri`; remoção de Implicit e ROPC; proibição de bearer token em query string; refresh token
de cliente público sender-constrained ou de uso único.

### PKCE (RFC 7636)

Resolve a interceptação do authorization code em cliente público (app mobile que registra um custom
scheme que outro app pode sequestrar; SPA em navegador compartilhado). O cliente gera um
`code_verifier` aleatório (43–128 caracteres do conjunto unreserved) e envia
`code_challenge = BASE64URL(SHA256(code_verifier))` com `code_challenge_method=S256` na autorização;
na troca do code, envia o `code_verifier`. Quem interceptou só o code não tem o verifier.

`code_challenge_method=plain` **não deve ser usado** — o desafio é o próprio verifier, então
interceptar a requisição de autorização basta. Do lado do servidor de autorização, revise: o AS
**rejeita** a troca quando o `code_challenge` foi registrado e o `code_verifier` não veio? Se aceitar,
o PKCE é decorativo (downgrade attack).

PKCE protege o **code**; ele não substitui o `state` para CSRF de login em todos os cenários, embora
o RFC 9700 aceite PKCE como defesa de CSRF quando implementado corretamente. Na dúvida, use os dois.

### Ataques

| Ataque | Mecanismo | Defesa |
|---|---|---|
| **`state` ausente/não validado → CSRF de login** | O atacante inicia o fluxo com a própria conta do IdP, captura o `code` e induz a vítima a visitar `/callback?code=<code do atacante>`. A vítima fica logada **na conta do atacante** — e tudo que ela fizer (salvar cartão, subir documento) vai para a conta que o atacante controla | `state` com ≥ 128 bits de CSPRNG, ligado à sessão do browser (cookie ou store server-side), **verificado e consumido** no callback |
| **`redirect_uri` validado por prefixo/wildcard** | `https://app.com/cb` registrado, mas a validação aceita `https://app.com/cb.evil.com`, `https://app.com/cb/../../open-redirect?to=evil`, `https://app.com.evil.com/cb`, ou `https://evil.com` porque o registro tem `*`. O `code` vai para o atacante | **Comparação exata de string** com a lista registrada. Nada de prefixo, subdomínio curinga, path traversal ou `startsWith` |
| **Open redirect encadeado** | O `redirect_uri` é legítimo, mas aquela rota tem um open redirect que repassa a query string (com o `code`) para fora | Auditar open redirects no domínio registrado. Veja `references/ssrf-e-camada-http.md` |
| **Code injection / replay** | O atacante injeta um `code` obtido em outro contexto no callback da vítima (ou reusa um code) | Code de **uso único** e TTL curto (≤ 60 s, RFC 6749 recomenda 10 min no máximo); PKCE amarra o code ao cliente que o iniciou; revogar todos os tokens do grant se um code for reapresentado |
| **Mix-up attack** | Cliente que fala com múltiplos IdPs recebe o callback e não sabe **qual** AS o emitiu; o atacante faz o cliente enviar o code (e o segredo do cliente) para o AS errado, que ele controla | **RFC 9207**: o AS devolve o parâmetro `iss` na resposta de autorização e o cliente o valida. Alternativamente, `redirect_uri` distinto por IdP |
| **Token substitution** | Access token de outro cliente aceito como prova de identidade (ver acima) | ID token + validação de `aud` |
| **`nonce` ausente (OIDC)** | Replay de ID token: um ID token válido capturado é reapresentado numa nova sessão | `nonce` aleatório na autorização, gravado server-side, comparado com o claim `nonce` do ID token |
| **Escopo excessivo / consentimento enganoso** | App pede `scope` amplo; a tela de consentimento é ignorada pelo usuário | Escopo mínimo; incremental authorization |
| **Device code phishing** | O atacante inicia um Device Grant, obtém o `user_code`, e envia à vítima "confirme este código para acessar o RH". A vítima autentica no domínio **legítimo** do IdP e autoriza o dispositivo **do atacante** — a URL é verdadeira, o MFA é feito, e não há nada visualmente errado | Restringir o Device Grant a clientes que realmente precisam; mostrar na tela de confirmação o **nome e a localização** do dispositivo; `user_code` de vida curta; alertar o usuário; exigir que o código seja **digitado**, não pré-preenchido por link (`verification_uri_complete` é conveniente e perigoso) |

### Validação de ID token (OIDC)

Checklist, na ordem:

1. **Assinatura** conferida contra a chave do JWKS do issuer, com o `alg` vindo da sua allowlist
   (normalmente `RS256`), não do header do token.
2. **`iss`** exatamente igual ao issuer esperado (string exata, incluindo/excluindo barra final).
3. **`aud`** contém o seu `client_id`. Se houver múltiplas audiences, **`azp`** deve ser o seu
   `client_id`.
4. **`exp`** no futuro, **`iat`** razoável (tolerância de segundos, não horas).
5. **`nonce`** igual ao que você gerou e guardou.
6. **`at_hash`** / **`c_hash`**, quando presentes, batem com o access token / code recebidos — é o que
   amarra o ID token ao resto da resposta.
7. **`sub`** é o identificador estável do usuário no IdP. **Use `sub`, nunca `email`, como chave de
   vínculo** — e-mail muda de dono, `sub` não.

Descoberta e rotação de chaves: leia `https://issuer/.well-known/openid-configuration` para obter
`jwks_uri`, `issuer`, `authorization_endpoint`, `token_endpoint`. Cacheie o JWKS com TTL e refaça a
busca quando aparecer um `kid` desconhecido — **com rate limit**, senão um atacante enviando tokens
com `kid` aleatório faz seu serviço martelar o IdP (DoS por amplificação; é o que `jwks-rsa`
resolve com `cache: true, rateLimit: true`). E **nunca** aceite `jku`/`jwk` do token para escolher a
chave: a origem das chaves é a configuração, não o token.

### Login social e pre-account-takeover por e-mail não verificado

Bug muito comum e muito lucrativo em bug bounty. A cadeia:

1. O atacante cadastra `vitima@empresa.com` no seu app via login social num IdP que **não verifica**
   o e-mail (ou via um provedor onde ele mesmo controla o domínio configurado), ou simplesmente cria
   a conta local sem confirmar o e-mail.
2. Depois, a vítima real chega e faz "Sign in with Google" com `vitima@empresa.com`. Seu app
   **vincula** o login social à conta existente porque o e-mail bate.
3. Os dois agora têm acesso à mesma conta. O atacante mantinha uma sessão viva ou uma senha local, e
   passa a ver tudo que a vítima fizer.

O erro raiz é sempre o mesmo: **fazer merge de contas por e-mail sem checar `email_verified`, e sem
provar que quem chegou primeiro controlava o endereço.** O claim `email_verified` do OIDC é um
booleano no ID token — e um IdP mal configurado (ou um Azure AD/Okta com domínio não verificado) pode
mandar `true` sem que isso signifique nada; para provedores que você não controla, trate `sub` como a
identidade e o e-mail apenas como atributo.

Regras de implementação:

- **Nunca** vincule automaticamente um login social a uma conta local existente. Peça a senha da conta
  local (ou um passo de verificação por e-mail) antes de vincular.
- Se aceitar merge por e-mail, exija `email_verified === true` **e** que a conta local também já
  tenha o e-mail verificado.
- Conta criada mas nunca verificada não deve ter sessão de longa duração nem poder receber convites,
  e deve ser derrubada quando o dono real do e-mail se cadastra.
- Verificação de e-mail deve **invalidar sessões pré-existentes** daquela conta.

A pesquisa que sistematizou isso é *"Pre-hijacked accounts: An Empirical Study of Security Failures in
User Account Creation on the Web"* (Sudhodanan & Paverd, USENIX Security 2022), que nomeia as cinco
variantes: **Classic-Federated Merge**, **Unexpired Session**, **Trojan Identifier**, **Unexpired
Email Change** e **Non-Verifying IdP**. Vale ler a lista como checklist de revisão de qualquer fluxo
de cadastro.

### Máquina a máquina: mTLS, DPoP e sender-constrained tokens

O problema do bearer token é estar no nome: **quem o porta, usa**. Roubado de um log, de um proxy, de
um bucket, funciona. As duas soluções padronizadas amarram o token a uma chave que o cliente precisa
provar possuir:

- **mTLS (RFC 8705)** — o token é vinculado ao *thumbprint* do certificado cliente usado no TLS
  (`cnf.x5t#S256` no token). O resource server só aceita o token se a conexão TLS apresentar aquele
  certificado. Robusto, mas exige infraestrutura de PKI; é o padrão em Open Banking/FAPI.
- **DPoP (RFC 9449)** — o cliente gera um par de chaves, e cada requisição leva um header `DPoP` com
  um JWT curto assinado por ela, contendo o método HTTP (`htm`), a URI (`htu`), um `jti` e o timestamp
  (`iat`); o access token carrega `cnf.jkt` = thumbprint da chave pública. Um token roubado sem a
  chave privada não serve. Funciona sem PKI e é o caminho prático para SPA/mobile.

O RFC 9700 §2.2.1 é claro: servidores de autorização e de recursos **SHOULD** usar mecanismos de
sender-constraining (mTLS ou DPoP) "para prevenir o uso indevido de access tokens roubados e
vazados".

Para M2M sem usuário, o padrão é **Client Credentials** com autenticação do cliente por
`private_key_jwt` ou mTLS — **não** por `client_secret` em variável de ambiente compartilhada entre
serviços. Veja `references/criptografia-e-segredos.md` e `references/supply-chain-e-cicd.md`.

### OAuth em app nativo (RFC 8252)

- **Nunca** use WebView embutida para o login: o app hospedeiro lê a senha digitada, os cookies e o
  DOM — a premissa de delegação do OAuth desaparece. Use `SFSafariViewController`/`ASWebAuthenticationSession`
  (iOS) e Custom Tabs (Android), que rodam fora do processo do app.
- Redirect por **loopback** (`http://127.0.0.1:<porta aleatória>/cb`) ou **custom scheme** com nome
  reverso do domínio (`com.exemplo.app:/oauth`). Custom scheme pode ser sequestrado por outro app que
  registre o mesmo scheme — por isso **PKCE é obrigatório** aqui; sem ele, o sequestro do scheme
  entrega o code.
- Preferir **App Links (Android) / Universal Links (iOS)**, que são verificados pelo domínio e não
  sequestráveis.
- **Não existe segredo de cliente** em app nativo: o binário é público. Cliente nativo é *público* por
  definição — se você achou um `client_secret` no APK/IPA, é achado, e a correção é trocar para
  cliente público + PKCE, não ofuscar. Veja `references/mobile.md`.

---

## SAML

Ainda é o que sustenta SSO corporativo. O que um revisor precisa saber pelos nomes certos:

- **XML Signature Wrapping (XSW).** A assinatura XML cobre um *elemento específico* identificado por
  `Reference URI="#id"`. O atacante mantém o elemento assinado original (que valida) e injeta uma
  cópia modificada em outro ponto da árvore; se a biblioteca **valida a assinatura de um nó e depois
  processa outro** — porque a lógica de negócio faz `getElementsByTagName('Assertion')[0]` em vez de
  usar o nó que foi de fato verificado —, a assertion falsa é aceita. Existem ~8 variantes catalogadas
  de XSW. Defesa: use a biblioteca do IdP/SP em versão atual, valide o schema, e garanta que os dados
  consumidos venham **do mesmo nó** cuja assinatura foi verificada.
- **Assinatura na Response vs. na Assertion.** Um SP pode aceitar `<Response>` assinada, `<Assertion>`
  assinada, ou ambas. Se ele aceita "pelo menos uma assinatura válida em algum lugar", o XSW fica
  trivial. Configure **explicitamente** o que precisa estar assinado — e recuse assertion não
  assinada, sempre.
- **Comment truncation no `NameID`.** Descoberto pela Duo Labs (fev/2018). O canonicalizador XML
  ignora comentários ao calcular o digest, mas o parser da aplicação lê o texto por partes: com
  `<NameID>admin@empresa.com<!---->.evil.com</NameID>`, a assinatura continua válida (o comentário é
  removido na canonicalização) enquanto uma API como `getTextContent()` ingênua devolve só o primeiro
  nó de texto — `admin@empresa.com`. Afetou OneLogin `python-saml`/`ruby-saml`, Shibboleth e OmniAuth
  (CVE-2017-11427, CVE-2017-11428, CVE-2017-11429, CVE-2017-11430).
- **`RelayState`.** Parâmetro opaco que o SP usa para lembrar para onde voltar. É controlado pelo
  atacante: se virar `Location:` sem validação, é open redirect; se for usado como chave de estado sem
  binding com a sessão, permite CSRF de login. Trate como o `state` do OAuth: valide contra allowlist
  ou guarde server-side.
- **Replay e `InResponseTo`.** Guarde o `ID` da `AuthnRequest` e exija que a `Response` traga o
  `InResponseTo` correspondente; rejeite `Response` já consumida (cache do `ID` até `NotOnOrAfter`);
  valide `NotBefore`/`NotOnOrAfter`, `Destination` (deve ser a sua ACS URL) e `Audience`.
- **XXE e billion laughs.** SAML é XML vindo do exterior. Desabilite entidades externas e DTD no
  parser. Veja `references/injecao.md`.
- **IdP-initiated SSO** é intrinsecamente mais fraco (não há `AuthnRequest`, logo não há
  `InResponseTo` nem estado do SP). Prefira SP-initiated.

---

## Fluxos periféricos: onde o bug mora

O login costuma ser a parte mais revisada do sistema. Os fluxos ao redor dele quase nunca são — e
todos terminam em "usuário autenticado". É onde estão os achados de bug bounty com pagamento alto.

### Recuperação de senha

| Requisito | Detalhe |
|---|---|
| Entropia do token | ≥ 128 bits de CSPRNG (`randomBytes(32).toString('base64url')`). Nada de UUIDv1 (contém timestamp e MAC), `Math.random`, hash do e-mail+timestamp, ou sequencial |
| Armazenamento | **Hash** no banco (`sha256`). Um dump da tabela não pode virar takeover em massa |
| Expiração | 15–60 min. TTL longo transforma e-mail antigo vazado em chave |
| Uso único | Invalidar na primeira troca bem-sucedida, atomicamente |
| Invalidação de outros tokens | Pedir um novo reset deve invalidar os anteriores |
| Sessões | Encerrar todas as outras sessões após o reset (o OWASP permite perguntar ao usuário, mas o padrão seguro é invalidar) |
| Login automático | **Não** logar o usuário automaticamente — senão o token de e-mail vira autenticação e o MFA é pulado |
| MFA | Exigir o segundo fator antes de concluir o reset, se a conta tiver MFA |
| Resposta | Genérica e com **tempo constante**: `If that email address is in our database, we will send you an email to reset your password.` Envie o e-mail em fila assíncrona |
| Rate limit | Por conta e por IP — senão o endpoint vira ferramenta de spam/harassment com o seu domínio como remetente |

**Host header poisoning no link de reset.** Se o link é construído com o header `Host` (ou
`X-Forwarded-Host`) da requisição, o atacante dispara o reset da vítima com
`Host: attacker.com` e o e-mail legítimo, vindo do seu domínio, chega com
`https://attacker.com/reset?token=...`. A vítima clica e entrega o token. É o "password reset
poisoning" da PortSwigger. Muitos frameworks e proxies (Next.js atrás de CDN, Rails, Django com
`ALLOWED_HOSTS` mal configurado) tornam isso trivial.

```ts
// ❌ o atacante controla o Host
const link = `https://${req.headers.host}/reset?token=${token}`

// ❌ pior: X-Forwarded-Host é injetável mesmo quando o Host é validado pelo LB
const link = `https://${req.headers['x-forwarded-host'] ?? req.headers.host}/reset?token=${token}`

// ✅ origem fixa vinda de configuração
const link = `${process.env.PUBLIC_BASE_URL}/reset?token=${token}`
```

Veja `references/ssrf-e-camada-http.md` para host header injection, cache poisoning e a validação de
`Host` na borda.

**Vazamento por `Referer`.** Se a página `/reset?token=...` carrega qualquer recurso de terceiro
(Google Fonts, Analytics, Intercom, pixel de marketing), o header `Referer` leva a URL **com o token**
para esse terceiro, que a guarda em log. Correções, em ordem de robustez:

1. Sirva a página de reset com `Referrer-Policy: no-referrer`.
2. Melhor: **não coloque o token na URL de uma página que renderiza terceiros** — a página lê o token,
   faz `history.replaceState` para remover da URL, e envia por POST.
3. Melhor ainda: link para uma página sem recursos externos.

O mesmo raciocínio vale para link de verificação de e-mail, magic link e link de convite.

### Verificação de e-mail

O e-mail verificado é a raiz de confiança de quase tudo (reset, login social, recuperação de MFA).
Regras: token de uso único com entropia alta; a verificação deve marcar `email_verified` **do endereço
específico** que foi verificado, não do usuário em geral; e reenviar verificação precisa de rate limit.

Bug comum: `POST /verify` que aceita `{ userId, token }` e marca verificado sem conferir que o token
pertence àquele usuário — IDOR clássico (assunto de
`references/autorizacao-e-logica-de-negocio.md`, mas a consequência aqui é de identidade).

### Troca de e-mail

O fluxo mais subestimado, porque troca a raiz de confiança da conta. Checklist:

1. **Exige senha atual ou step-up MFA?** Se não, um XSS ou uma sessão emprestada vira takeover
   permanente.
2. **Verifica o e-mail NOVO antes de trocar?** O padrão correto é *pending change*: grava
   `pending_email` + token, só efetiva quando o novo endereço confirma. Trocar imediatamente permite
   sequestrar a conta apontando para um endereço que o atacante não controla — e ainda deixa a vítima
   sem recuperação.
3. **Notifica o e-mail ANTIGO?** Com link de "não fui eu" que reverte e bloqueia a conta. Isso é o
   que dá à vítima a chance de reagir.
4. **Invalida sessões e tokens de reset pendentes?**
5. **Colisão**: se o novo e-mail já pertence a outra conta, a resposta não pode enumerar. E não pode
   fundir contas silenciosamente.

### Convite para organização

- O token de convite carrega **papel e organização**; se ele for editável pelo cliente (JWT sem
  verificação de assinatura, ou parâmetro `role` no POST de aceite), qualquer convidado vira admin.
- Convite deve ser **vinculado ao endereço de e-mail** convidado. Se qualquer pessoa com o link entra,
  o link vazado no Slack de outra empresa é acesso.
- Expiração (7–14 dias) e revogação pelo admin.
- Aceitar convite muda o nível de privilégio → **regenere a sessão**.
- Convite para e-mail que ainda não tem conta: o fluxo de cadastro precisa validar que quem completa
  o cadastro controla aquele e-mail, senão é a variante "unexpired session" de pre-hijacking.

### Impersonation / "login as user" por admin

Recurso legítimo de suporte, e um backdoor se malfeito:

- Só para papel específico, com autorização checada no servidor a cada requisição (não uma vez no
  início).
- **Sessão nova**, com marcador `impersonatedBy: <adminId>` — e não a substituição do `userId` dentro
  da sessão do admin.
- Auditoria imutável: quem, quem foi impersonado, quando, e idealmente por quê (ticket).
- **Read-only por padrão**; escrita exige aprovação ou é bloqueada para operações destrutivas
  (trocar senha, trocar e-mail, transferir dinheiro, deletar conta).
- TTL curto e banner visível na UI.
- Sair da impersonation → regenerar sessão de novo.
- Nunca implemente como `?userId=123` lido de query string em uma rota de admin.

### API keys

| Aspecto | Prática |
|---|---|
| Geração | ≥ 128 bits de CSPRNG |
| Formato | **Prefixo identificável** — `sk_live_`, `sk_test_`, `ghp_`, `myapp_pat_`. Permite que o secret scanning do GitHub/GitLab e o seu próprio grep encontrem a chave vazada, e que o suporte saiba o tipo sem ver o valor |
| Checksum | Um sufixo de checksum (o GitHub usa CRC32 em base62) reduz falso positivo do scanner e permite rejeitar chave malformada sem consultar o banco |
| Armazenamento | **Hash** no banco. Como a entropia é alta, `sha256` é suficiente (não é senha adivinhável). Guarde também os últimos 4 caracteres em claro, para a UI |
| Busca | Não faça `SELECT * FROM keys` e compare uma a uma. Guarde um `lookup_id` público (parte não secreta da chave) indexado, ou indexe o próprio `sha256` |
| Exibição | Uma vez, na criação. Nunca recuperável |
| Escopo | Permissões mínimas por chave, não "acesso total à conta". Restrição opcional por IP |
| Rotação | Suporte a duas chaves ativas simultaneamente, para rotação sem downtime, com `last_used_at` para saber quando a antiga morreu |
| Expiração | Padrão com validade (90–365 dias) e aviso por e-mail antes |
| Transporte | Header `Authorization: Bearer` — **nunca** query string (vaza em log de acesso, `Referer` e histórico) |
| Revogação | Imediata, e com log de auditoria |

### Magic link

É um token de reset que loga. Herda todas as regras da recuperação de senha, mais:

- TTL **curto** (5–15 min) e uso único.
- Vinculado ao dispositivo/navegador que pediu (grave um nonce em cookie no momento do pedido e exija
  o par). Isso impede que o link encaminhado por engano — ou lido por um scanner de link do
  antivírus/Outlook Safe Links, que **faz GET no link e o consome** — logue outra pessoa. Use POST na
  confirmação por causa exatamente do pré-fetch de scanner.
- Rate limit por e-mail e por IP.
- Segurança da conta = segurança da caixa de e-mail. Combine com MFA para contas de valor.

### "Lembrar de mim"

- É uma credencial de longa duração: token separado, de alta entropia, com **hash** no banco, uma
  linha por dispositivo, com rotação a cada uso (mesma mecânica do refresh token, com detecção de
  reuso).
- Nunca `remember=base64(userId:hash_da_senha)` — padrão histórico do PHP/Rails antigo, e o motivo do
  WSTG-ATHN-05 ("Testing for Vulnerable Remember Password").
- Sessão restaurada por "lembrar de mim" deve ser **de privilégio reduzido**: operações sensíveis
  exigem senha/MFA de novo (é o que a Amazon e o GitHub fazem).
- Invalidar todos os tokens de "lembrar" na troca de senha.

---

## Sinais em revisão de código

### Node / TypeScript (Fastify, Next.js, Express)

| Procurar | Por que importa |
|---|---|
| `jwt.decode(` | Não verifica assinatura. Se o resultado alimenta decisão de auth, é bypass |
| `jwt.verify(token, key)` sem `algorithms` | Confusão de algoritmo |
| `ignoreExpiration: true`, `ignoreNotBefore: true` | Token eterno |
| `Math.random()`, `Date.now()`, `uuid v1` em geração de token/sid | Previsível |
| `createHash('sha256').update(password)` sem KDF | Hash de senha rápido |
| `===` comparando token/API key/HMAC | Timing |
| `req.session.userId = ...` sem `regenerate()` antes | Session fixation |
| `res.clearCookie` sem `store.destroy` | Logout falso |
| `secure: false`, `httpOnly: false`, `sameSite: 'none'` em cookie de sessão | Flags |
| `domain: '.exemplo.com'` em cookie de sessão | Escopo excessivo, cookie tossing |
| `req.headers.host` / `x-forwarded-host` compondo URL de e-mail | Reset poisoning |
| `localStorage.setItem('token'` / `accessToken` | XSS rouba credencial portátil |
| `saveUninitialized: true` (`express-session`) | Cria sessão para anônimo; facilita fixation e enche o store |
| Rota `/api/auth/*` sem plugin de rate limit | Stuffing |
| `verifyRegistrationResponse({ expectedChallenge: body.challenge })` | Challenge do cliente = replay |
| `middleware.ts` do Next.js como **única** proteção de rota | Middleware não roda em toda rota (matcher, rotas de API chamadas server-side, RSC). Autorize também no handler/Server Action |
| `getServerSession()` ausente em Server Action | Server Action é um endpoint HTTP público; precisa de checagem de sessão própria |

### Go

| Procurar | Por que importa |
|---|---|
| `jwt.Parse` sem checar `token.Method.(*jwt.SigningMethodHMAC)` na `Keyfunc` | Confusão de algoritmo — o buraco clássico do `golang-jwt` |
| `jwt.ParseUnverified` | Sem verificação |
| `math/rand` em vez de `crypto/rand` | Previsível |
| `==` em `[]byte` de MAC/token; falta de `hmac.Equal` / `subtle.ConstantTimeCompare` | Timing |
| `sha256.Sum256([]byte(password))` | Sem KDF (`golang.org/x/crypto/argon2`, `bcrypt`, `scrypt`) |
| `http.SetCookie` sem `Secure`, `HttpOnly`, `SameSite` | Flags (o zero value de `SameSite` é `SameSiteDefaultMode`) |
| `gorilla/sessions` sem `session.Options.MaxAge` ou sem regenerar ID | Fixation/timeout |

### Python

| Procurar | Por que importa |
|---|---|
| `jwt.decode(token, options={"verify_signature": False})` | Sem verificação |
| `jwt.decode(..., algorithms=...)` ausente | PyJWT ≥ 2.0 exige `algorithms`, mas código legado pode ter wrapper permissivo |
| `random.` / `uuid.uuid1()` para token | Previsível — use `secrets.token_urlsafe(32)` |
| `hashlib.sha256(password)` | Sem KDF — use `argon2-cffi` ou `passlib` com `argon2` |
| `==` em token; falta de `hmac.compare_digest` | Timing |
| Django: `SESSION_COOKIE_SECURE=False`, `SESSION_COOKIE_HTTPONLY=False`, `SESSION_COOKIE_SAMESITE=None`, `ALLOWED_HOSTS=['*']` | Flags e host header |
| Django: falta de `update_session_auth_hash` após troca de senha | Sessões antigas sobrevivem |
| Flask: `session` (cookie assinado) usado como sessão server-side, com `SECRET_KEY` fraco/hardcoded | O payload é legível e forjável se a chave vazar; `flask-unsign` automatiza |

---

## Falsos positivos comuns

- **`Math.random()` fora de contexto de segurança.** Chave de lista em React, jitter de retry, ID de
  animação, embaralhar cards de UI. Só é bug quando o valor é credencial, token, session ID, salt,
  nonce ou código de verificação.
- **JWT sem `alg` na allowlist quando a biblioteca é `jose`.** `jose` rejeita `alg:"none"`
  incondicionalmente e restringe aos algoritmos aplicáveis à chave fornecida. Ainda vale passar
  `algorithms`, mas isso é *hardening*, não vulnerabilidade — não abra como Medium.
- **`jwt.decode()` em código de teste, script de debug ou para ler `kid`/`iss` antes de escolher a
  chave.** Ler o header antes de verificar é o fluxo normal do JWKS. O bug é usar o resultado de
  `decode` para **decidir autorização**.
- **Ausência de `HttpOnly` num cookie que não é credencial**: preferência de tema, locale, flag de
  banner de cookie, ID de A/B test. `HttpOnly` neles às vezes até quebra a aplicação.
- **`SameSite=None` num cookie que existe para uso cross-site legítimo** (widget embutido, SSO em
  iframe). É a configuração correta; o achado real seria a ausência de defesa de CSRF, não a flag.
- **Sessão sem timeout absoluto em ferramenta interna atrás de VPN/mTLS/SSO corporativo com política
  de sessão própria no IdP.** O controle existe, só não está nesse código.
- **`bcrypt` com cost 10.** É o mínimo recomendado pelo OWASP, não uma falha. Cost 12 é melhor; 10 não
  é achado por si só. Já `bcrypt` com cost **4** é.
- **Ausência de MFA num serviço interno M2M.** MFA é controle para humanos. Para máquina, o controle é
  mTLS/OIDC client credentials com rotação — cobrado por `references/supply-chain-e-cicd.md`.
- **Token de vida longa que é, na verdade, API key com escopo e revogação.** Um PAT de 90 dias com
  escopo mínimo, hash no banco e revogação funcionando não é "JWT eterno".
- **User enumeration no cadastro de um produto onde a lista de usuários é pública por design**
  (rede social com perfil público, marketplace com vendedor visível). Fechar o oráculo de cadastro
  enquanto `/u/{username}` responde 200/404 não muda nada.
- **`localStorage` guardando token em app mobile híbrido com WebView isolada e sem conteúdo de
  terceiro.** O modelo de ameaça de XSS muda; avalie antes de reportar como o mesmo bug do browser.
- **Falta de regeneração de session ID em framework que já regenera por padrão** — Rails
  (`reset_session` em `sign_in` do Devise), Laravel (`$request->session()->regenerate()` no
  `AuthenticatedSessionController` gerado), ASP.NET Core Identity. Confirme antes de abrir.

---

## Fontes

**OWASP**
- [Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html)
- [Multifactor Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html)
- [Credential Stuffing Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Credential_Stuffing_Prevention_Cheat_Sheet.html)
- [Forgot Password Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html)
- [JSON Web Token for Java Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html)
- [OWASP Top 10:2025 — A07 Authentication Failures](https://owasp.org/Top10/2025/)
- [ASVS 5.0.0](https://github.com/OWASP/ASVS) — V6 Authentication, V7 Session Management
- [WSTG](https://owasp.org/www-project-web-security-testing-guide/latest/) — WSTG-ATHN-01..11, WSTG-SESS-01..11

**NIST**
- [SP 800-63B-4, *Digital Identity Guidelines: Authentication and Authenticator Management*](https://pages.nist.gov/800-63-4/sp800-63b.html) (ago/2025)

**RFCs e specs**
- [RFC 6749](https://www.rfc-editor.org/rfc/rfc6749) OAuth 2.0 · [RFC 6750](https://www.rfc-editor.org/rfc/rfc6750) Bearer Token
- [RFC 7519](https://www.rfc-editor.org/rfc/rfc7519) JWT · [RFC 8725](https://www.rfc-editor.org/rfc/rfc8725) JWT BCP (BCP 225) · [draft-ietf-oauth-rfc8725bis-07](https://www.ietf.org/archive/id/draft-ietf-oauth-rfc8725bis-07.html)
- [RFC 7636](https://www.rfc-editor.org/rfc/rfc7636) PKCE · [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252) OAuth for Native Apps
- [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html) OAuth 2.0 Security BCP (jan/2025)
- [RFC 9207](https://www.rfc-editor.org/rfc/rfc9207) Authorization Server Issuer Identification
- [RFC 8705](https://www.rfc-editor.org/rfc/rfc8705) mTLS · [RFC 9449](https://www.rfc-editor.org/rfc/rfc9449) DPoP
- [RFC 8628](https://www.rfc-editor.org/rfc/rfc8628) Device Authorization Grant · [RFC 7009](https://www.rfc-editor.org/rfc/rfc7009) Token Revocation
- [OpenID Connect Core 1.0](https://openid.net/specs/openid-connect-core-1_0.html)
- [WebAuthn Level 3 (W3C CR, mai/2026)](https://www.w3.org/TR/webauthn-3/)
- [PASETO spec](https://github.com/paseto-standard/paseto-spec)

**PortSwigger Web Security Academy**
- [Authentication vulnerabilities](https://portswigger.net/web-security/authentication)
- [JWT attacks](https://portswigger.net/web-security/jwt) · [Algorithm confusion](https://portswigger.net/web-security/jwt/algorithm-confusion)
- [OAuth 2.0 authentication vulnerabilities](https://portswigger.net/web-security/oauth)
- [SAML](https://portswigger.net/web-security/saml)

**Outros**
- [MDN — Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie)
- [Have I Been Pwned — Pwned Passwords API](https://haveibeenpwned.com/API/v3#PwnedPasswords)
- [SimpleWebAuthn](https://simplewebauthn.dev/docs/packages/server)
- [Unit 42 — jsonwebtoken CVE-2022-23529 (retratada)](https://unit42.paloaltonetworks.com/jsonwebtoken-vulnerability-cve-2022-23529/)
- [Auth0 — Critical vulnerability in JSON Web Encryption (invalid curve)](https://auth0.com/blog/critical-vulnerability-in-json-web-encryption/)
- [CISA — Implementing Number Matching in MFA Applications](https://www.cisa.gov/sites/default/files/publications/fact-sheet-implement-number-matching-in-mfa-applications-508c.pdf)
- [Node.js `crypto` — `argon2`, `scrypt`, `timingSafeEqual`](https://nodejs.org/api/crypto.html)
