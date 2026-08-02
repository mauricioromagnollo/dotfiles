# Criptografia aplicada, gestão de segredos e proteção de dado sensível

Cobre falhas criptográficas (A04:2025 — *Cryptographic Failures*, ex-A02:2021), logging de
segurança (A09:2025 — *Security Logging & Alerting Failures*) e privacidade/LGPD. Abra este
arquivo quando encontrar: código que cifra/decifra dados, geração de token ou ID, comparação de
segredo, configuração de TLS, segredo em repositório/Dockerfile/CI, dado pessoal em log, ou
qualquer chamada a `crypto.*`. Hash de senha e JWT são de
`references/autenticacao-e-sessao.md` — aqui fica só a primitiva.

## Índice

- [A regra que evita 90% dos erros](#a-regra-que-evita-90-dos-erros)
- [Aleatoriedade](#aleatoriedade)
- [Criptografia simétrica: AEAD ou nada](#criptografia-simétrica-aead-ou-nada)
- [Assimétrico, assinatura e hash](#assimétrico-assinatura-e-hash)
- [KDF: derivação de chave](#kdf-derivação-de-chave)
- [TLS na prática](#tls-na-prática)
- [Gestão de segredos](#gestão-de-segredos)
- [Dado sensível em repouso e em trânsito na aplicação](#dado-sensível-em-repouso-e-em-trânsito-na-aplicação)
- [Logging e monitoramento de segurança (A09)](#logging-e-monitoramento-de-segurança-a09)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

## A regra que evita 90% dos erros

**Não monte protocolo criptográfico. Use a construção de mais alto nível disponível.** A ordem de
preferência, da Latacora ([Cryptographic Right Answers, edição pós-quântica de
2024](https://www.latacora.com/blog/post-quantum-cryptographic-right-answers/)):

1. **KMS gerenciado** (AWS KMS, GCP KMS, Vault Transit): a chave nunca sai do serviço, rotação e
   auditoria vêm de graça, e a API só expõe operações seguras (`Encrypt`/`Decrypt` com AAD via
   `EncryptionContext`).
2. **Biblioteca de alto nível**: libsodium (`crypto_secretbox`, `crypto_box`, `sealed box`),
   [`@noble/ciphers`](https://github.com/paulmillr/noble-ciphers)/`@noble/curves` em JS, `age`
   para arquivos, Tink. Elas escolhem algoritmo, geram nonce e prendem tudo junto — não dá para
   errar a montagem.
3. **Primitiva crua** (Node `crypto`, Web Crypto, `javax.crypto`): só quando as anteriores não
   servem, e aí este arquivo existe para revisar cada decisão que a API empurrou para você.

Quem monta na mão erra sempre nos mesmos pontos: reuso de nonce, cifra sem autenticação, chave
derivada de senha sem KDF, comparação de MAC com `===`, IV fixo "para o teste passar", e
versionamento inexistente (impossível rotacionar chave depois). Cada um desses tem seção abaixo.

Armadilhas de API específicas da stack Node:

- **`crypto.createCipher()` (sem `iv`)**: derivava a chave da "senha" com `EVP_BytesToKey`
  (MD5, sem salt) e IV determinístico — mesma senha + mesma mensagem = mesmo ciphertext.
  Deprecada como DEP0106 e **removida no Node 22**. Se aparecer em código legado, é achado, não
  estilo antigo.
- **AES-GCM em streaming**: `decipher.update()` devolve plaintext **antes** de
  `decipher.final()` verificar a tag. Se o código faz `res.write(decipher.update(chunk))` num
  stream, ele entrega dado não autenticado ao consumidor; a verificação só falha no fim. Buffere
  até `final()` ou use construção de streaming de verdade (libsodium `secretstream`).
- **`chacha20-poly1305` no Node exige `authTagLength: 16`** explícito no `createCipheriv`;
  esquecer gera erro só em runtime.
- **Web Crypto (`crypto.subtle`)** é *low-level*: `AES-GCM` aceita qualquer `iv` que você passar,
  inclusive um fixo. A API não protege contra reuso de nonce — você protege.
- **`crypto.publicEncrypt` default é OAEP** (bom), mas aceita
  `padding: crypto.constants.RSA_PKCS1_PADDING` — que desde o Node 18.19/20.11 (OpenSSL com
  proteção implícita a Bleichenbacher) ainda assim não deve ser usado em código novo.

## Aleatoriedade

### CSPRNG vs PRNG

PRNG comum é **previsível a partir das saídas**: `Math.random()` do V8 é xorshift128+, e o estado
inteiro se recupera observando ~5 saídas consecutivas (há solvers públicos com Z3);
`java.util.Random` tem semente de 48 bits, recuperável de duas saídas; `random` do Python é
Mersenne Twister, estado completo em 624 saídas; `rand()` do C e `math/rand` do Go idem.
**Qualquer valor que dá acesso a algo** — token de sessão, reset de senha, API key, código de
verificação, nonce, salt de convite — precisa de CSPRNG.

| Linguagem | ❌ previsível | ✅ CSPRNG |
|---|---|---|
| Node/JS | `Math.random()` | `crypto.randomBytes(n)`, `crypto.randomUUID()`, `crypto.getRandomValues()`, `crypto.randomInt(min, max)` |
| Python | `random.*` | módulo `secrets` (`secrets.token_urlsafe(32)`) |
| Go | `math/rand`, `math/rand/v2` | `crypto/rand` |
| Java | `java.util.Random`, `ThreadLocalRandom` | `java.security.SecureRandom` |
| PHP | `rand()`, `mt_rand()` | `random_bytes()`, `random_int()` |

```ts
// ❌ vulnerável — token de reset previsível (aparece em bug bounty com frequência real)
const token = Math.random().toString(36).slice(2)

// ✅ correto — 32 bytes = 256 bits, base64url sem padding
const token = crypto.randomBytes(32).toString('base64url')
```

### UUID não é token

| Versão | O que garante | O que vaza |
|---|---|---|
| v1 | unicidade temporal | timestamp de 60 bits + MAC address (ou 48 bits aleatórios) — enumerável |
| v4 | 122 bits de entropia (se o gerador for CSPRNG — `crypto.randomUUID()` é; libs antigas nem sempre) | nada, mas o formato anuncia "sou um UUID" |
| v7 ([RFC 9562](https://www.rfc-editor.org/rfc/rfc9562), 2024) | ordenável por tempo (ótimo para PK de banco) | timestamp de 48 bits; só 74 bits aleatórios |

Regra: **UUID identifica, não autoriza**. v7 como chave primária, ótimo; v7 como token de reset,
achado (o timestamp reduz o espaço de busca e 74 bits está abaixo do piso). Se um UUID v4 gerado
por `crypto.randomUUID()` é usado como token, não é vulnerável por entropia (122 bits > 128 é
falso, mas 122 é aceitável) — porém sinalize se a mesma coluna serve de ID público em URL.

### Quanta entropia e como codificar

Piso para token bearer: **128 bits** (OWASP pede ≥ 64 de sessão, mas 128 é o consenso; use 256
quando não custa nada). Codificação:

- `base64url` (RFC 4648 §5): 22 chars para 128 bits, seguro em URL, o default sensato.
- `base32` (Crockford): quando humano digita — sem `0/O`, `1/l/I` ambíguos, case-insensitive.
- hex: 32 chars para 128 bits, verboso mas inofensivo.
- **Nunca trunque** o hash/token depois de gerar ("pega os 8 primeiros chars") — isso reduz a
  entropia para o tamanho truncado.

## Criptografia simétrica: AEAD ou nada

### Por que AEAD

Cifra sem autenticação (AES-CBC puro, AES-CTR puro) permite que o atacante **modifique o
ciphertext** sem conhecer a chave — em CTR, flipar um bit do ciphertext flipa o mesmo bit do
plaintext (maleabilidade total); em CBC, manipular um bloco embaralha um e flipa bits do
seguinte. AEAD (*Authenticated Encryption with Associated Data*) resolve porque a tag cobre
ciphertext + AAD e a decifração **falha atomicamente** antes de entregar qualquer byte. Montar
"encrypt-then-MAC" na mão até funciona (é a ordem correta; MAC-then-encrypt é o que quebrou TLS
com Lucky13), mas exige acertar a ordem, cobrir o IV no MAC, usar chaves distintas para cifra e
MAC, e comparar em tempo constante — quatro chances de errar que a AEAD elimina.

Escolhas: **AES-256-GCM** (aceleração de hardware AES-NI, o default em serviço), 
**ChaCha20-Poly1305** (constante-time em software puro, melhor em mobile/embarcado sem AES-NI),
**XChaCha20-Poly1305** (nonce de 24 bytes — ver abaixo; libsodium/`@noble`, não está no Node core).

### Os clássicos que ainda aparecem

- **ECB**: blocos iguais viram ciphertext igual — a imagem do pinguim do Linux cifrada em ECB
  ainda mostra o pinguim. `grep -rn "aes.*ecb\|AES/ECB"` nunca tem justificativa em dado real.
- **CBC sem MAC → padding oracle**: o servidor que responde diferente para "padding inválido" vs
  "padding válido mas conteúdo errado" vira um oráculo que decifra byte a byte (~128 requests por
  byte). O mecanismo: o atacante manipula o último byte do bloco anterior até o padding validar,
  o que revela `plaintext ⊕ ciphertext_manipulado`. **Erro genérico não resolve sozinho**: a
  diferença de *timing* entre falhar no unpad e falhar na validação posterior reconstrói o
  oráculo (foi exatamente o Lucky13). A única correção estrutural é autenticar antes de decifrar
  — ou seja, AEAD.
- **CTR/GCM com nonce reutilizado**: em CTR, dois ciphertexts com o mesmo nonce dão
  `c1 ⊕ c2 = p1 ⊕ p2` — crib-dragging recupera ambos os plaintexts. **Em GCM é catastrófico de
  verdade**: além disso, duas mensagens com o mesmo nonce permitem recuperar a chave de
  autenticação GHASH (ataque "forbidden" de Joux), e a partir daí o atacante **forja tags para
  qualquer ciphertext** sob aquela chave. Um único reuso quebra a integridade de tudo.

### Nonce em GCM: os números que importam

GCM usa nonce de 96 bits. Duas estratégias válidas:

1. **Contador/determinístico** — garante unicidade, mas exige estado persistente e coordenado
   (perigoso com múltiplas réplicas do serviço usando a mesma chave).
2. **Aleatório** — sem estado, mas o aniversário morde: NIST SP 800-38D limita a **2³²
   mensagens por chave** com nonce aleatório de 96 bits (mantém probabilidade de colisão ≤ 2⁻³²).
   Um serviço que cifra milhões de registros por dia com uma chave fixa estoura isso em anos, não
   décadas. Limite adicional: ~64 GiB por mensagem.

**XChaCha20-Poly1305 existe para isso**: nonce de 192 bits torna colisão aleatória
desprezível — gere 24 bytes aleatórios por mensagem e esqueça contadores. Alternativa em AES:
AES-GCM-SIV (RFC 8452), que degrada graciosamente em reuso de nonce (só vaza igualdade de
mensagens), mas tem pouco suporte fora de BoringSSL/Tink.

```ts
// ✅ AES-256-GCM correto em Node — nonce aleatório por mensagem, prepend ao ciphertext
import { randomBytes, createCipheriv, createDecipheriv } from 'node:crypto'

function encrypt(key: Buffer, plaintext: Buffer, aad: Buffer) {
  const iv = randomBytes(12)                       // NUNCA fixo, NUNCA derivado do dado
  const cipher = createCipheriv('aes-256-gcm', key, iv)
  cipher.setAAD(aad)
  const ct = Buffer.concat([cipher.update(plaintext), cipher.final()])
  return Buffer.concat([iv, ct, cipher.getAuthTag()])   // formato: iv || ct || tag
}

function decrypt(key: Buffer, blob: Buffer, aad: Buffer) {
  const iv = blob.subarray(0, 12)
  const tag = blob.subarray(blob.length - 16)
  const ct = blob.subarray(12, blob.length - 16)
  const d = createDecipheriv('aes-256-gcm', key, iv)
  d.setAAD(aad)
  d.setAuthTag(tag)
  return Buffer.concat([d.update(ct), d.final()])  // final() lança se a tag não bate
}
```

### AAD: para que serve de verdade

AAD é dado **autenticado mas não cifrado** — a tag cobre ele, então a decifração falha se ele
mudar. O uso real é **amarrar o ciphertext ao contexto**: sem AAD, um atacante com acesso de
escrita ao banco (ou um IDOR de escrita) pode **trocar ciphertexts entre linhas** — mover o
`encrypted_ssn` do usuário A para a linha do usuário B, e o sistema decifra feliz (confused
deputy sobre a própria cifra). Com `aad = tenantId || rowId || columnName`, o ciphertext só
decifra no lugar onde nasceu. No AWS KMS isso é o `EncryptionContext` — mesma função, e ainda
aparece nos logs do CloudTrail.

### Envelope encryption e rotação

Cifrar cada registro chamando o KMS direto não escala (latência + custo por chamada) e cifrar
tudo com uma chave local única não rotaciona. O padrão que resolve os dois é **envelope
encryption**, o mesmo que AWS Encryption SDK, Tink e o Vault Transit implementam:

1. **KEK** (*key encryption key*) vive no KMS/cofre e nunca sai de lá.
2. Para cifrar, peça uma **DEK** (*data encryption key*) — `GenerateDataKey` devolve a DEK em
   claro (use e descarte da memória) e a DEK cifrada pela KEK (armazene junto do ciphertext).
3. Para decifrar, mande a DEK cifrada ao KMS (`Decrypt`), receba a DEK, decifre o dado.

O que isso compra: o KMS só processa chaves de 32 bytes (rápido, barato), cada registro/lote
pode ter DEK própria (blast radius de um vazamento de DEK = um registro), e **rotacionar a KEK
não exige re-cifrar dado nenhum** — só as DEKs cifradas, e mesmo isso pode ser preguiçoso.

Regras de rotação que valem revisão:

- Todo blob cifrado carrega **id e versão da chave** no cabeçalho (`v1:kms-key-arn:...`);
  ciphertext sem versionamento é dívida impagável — impossível saber com qual chave decifrar
  depois da rotação.
- Rotação em duas fases: nova versão cifra tudo que nasce agora; um job re-cifra o legado em
  background; a versão velha só decifra até o re-encrypt terminar, depois é destruída.
- Rotação **de emergência** (chave comprometida) é outro fluxo: a versão velha é revogada
  imediatamente e o que ela cifrou é tratado como exposto — por isso DEK por registro/tenant
  importa.

## Assimétrico, assinatura e hash

### Escolhas de 2026

| Uso | Default sensato | Aceitável | Evitar |
|---|---|---|---|
| Assinatura | **Ed25519** | ECDSA P-256 (com nonce determinístico RFC 6979), RSA-PSS ≥ 3072 | RSA PKCS#1 v1.5 em código novo, DSA, ECDSA com nonce aleatório caseiro |
| Cifra assimétrica | não cifre com RSA direto — use KEM/híbrido (libsodium `sealed box`, HPKE RFC 9180) | RSA-OAEP (SHA-256) para interoperar | **RSA PKCS#1 v1.5** (Bleichenbacher/ROBOT — oráculo de padding de 1998 redescoberto em 2017 em Facebook, PayPal, F5) |
| Hash | SHA-256 / SHA-512 | BLAKE3 (rápido, sem length extension), SHA-3 | MD5, SHA-1 para qualquer fim de segurança |
| MAC | HMAC-SHA-256 | KMAC, BLAKE3 keyed | hash(secret ‖ msg) na mão |

RSA: mínimo 2048 bits hoje, 3072 para vida longa (NIST SP 800-57 equipara 3072 a 128 bits de
segurança). Mas a resposta moderna é não escolher RSA: chave menor, operação mais rápida e menos
formas de errar em Ed25519.

### Ataques de assinatura que aparecem em revisão

- **Confusão de algoritmo**: o verificador aceita o algoritmo declarado pelo *atacante* (o caso
  clássico é JWT `alg: RS256 → HS256`, usando a chave pública como segredo HMAC — detalhes em
  `references/autenticacao-e-sessao.md`). A correção é sempre a mesma: o verificador fixa o
  algoritmo esperado, nunca lê do dado.
- **Reuso/viés de nonce em ECDSA**: nonce repetido em duas assinaturas recupera a chave privada
  com álgebra de ensino médio — foi assim que a chave da PlayStation 3 vazou. Viés de poucos bits
  também quebra (lattice attacks, Minerva/TPM-Fail). Use implementação com RFC 6979
  (determinístico) ou Ed25519, que é determinístico por construção.
- **Maleabilidade**: para cada assinatura ECDSA `(r, s)`, `(r, n−s)` também é válida. Irrelevante
  para "esse JWT é válido?", crítico quando a assinatura em si é um identificador
  (deduplicação, consenso, id de transação — Bitcoin normalizou para low-s por isso).
- **Curva não validada**: aceitar um ponto público sem verificar que está na curva permite
  *invalid curve attacks* que extraem a chave privada em ECDH estático (CVE-2017-3238 em JOSE
  libs). Bibliotecas modernas validam; código que importa ponto "cru" com aritmética própria, não.
- **Verificação com comparação vazada**: verificar assinatura/MAC com `===` ou `memcmp` vaza por
  timing o prefixo correto byte a byte. Assinaturas assimétricas verificadas via API da lib
  (`crypto.verify`) estão OK; o problema é MAC/token comparado na mão — ver abaixo.

### Length extension e por que HMAC existe

SHA-256/SHA-512 são Merkle–Damgård: dado `H(secret ‖ msg)`, o atacante calcula
`H(secret ‖ msg ‖ padding ‖ sufixo)` **sem saber o segredo** — se sua "assinatura" de URL é
`sha256(secret + url)`, ele estende a URL assinada. HMAC existe exatamente para fechar isso
(duas passadas com chaves derivadas). SHA-512/256, SHA-3 e BLAKE3 não sofrem length extension,
mas a resposta em revisão continua "use HMAC", não "troque o hash".

MD5/SHA-1: colisões práticas (SHA-1: SHAttered 2017, chosen-prefix 2020) matam qualquer uso onde
colisão importa — assinatura, certificado, deduplicação com consequência de segurança. Aparecem
**legitimamente** como checksum não-criptográfico (etag, chave de cache, detecção de corrupção) —
ver [Falsos positivos](#falsos-positivos-comuns).

### Comparação em tempo constante

```ts
// ❌ vulnerável — === retorna no primeiro byte diferente; timing vaza o prefixo
if (req.headers['x-webhook-signature'] === expectedHmac) { ... }

// ✅ correto
import { timingSafeEqual, createHmac } from 'node:crypto'
const a = Buffer.from(received, 'hex')
const b = createHmac('sha256', secret).update(body).digest()
if (a.length === b.length && timingSafeEqual(a, b)) { ... }
```

Detalhes que erram: `timingSafeEqual` **lança** se os buffers têm tamanhos diferentes (cheque o
tamanho antes — o tamanho não é segredo); comparar strings hex com ele exige decodificar antes.
Equivalentes: `hmac.Equal`/`subtle.ConstantTimeCompare` (Go), `secrets.compare_digest` (Python),
`hash_equals` (PHP), `MessageDigest.isEqual` (Java). Contexto onde importa: verificação de
webhook (Stripe, GitHub), token de API contra banco, MAC caseiro. Onde **não** importa: comparar
hash de senha já processado por bcrypt/argon2 (a lib já compara certo) — veja
`references/autenticacao-e-sessao.md`.

## KDF: derivação de chave

Dois problemas diferentes, duas ferramentas:

1. **Material de baixa entropia (senha humana)** → KDF de memória cara: Argon2id/scrypt. É o
   território de hash de senha — parâmetros e escolhas em `references/autenticacao-e-sessao.md`.
   O único ponto daqui: se você precisa de uma **chave de cifra** a partir de uma senha (ex.:
   cifrar um export com senha do usuário), use Argon2id com salt aleatório armazenado junto, e
   nunca `sha256(password)`.
2. **Material já uniforme (chave mestra, saída de ECDH, segredo do KMS)** → **HKDF**
   (RFC 5869): barato, e o parâmetro `info` é o recurso subutilizado — deriva chaves
   independentes por propósito e por contexto:

```ts
import { hkdfSync } from 'node:crypto'
// chaves independentes por tenant e por finalidade, a partir de UMA chave mestra no cofre
const keyEnc = hkdfSync('sha256', masterKey, salt, `tenant:${tenantId}:field-encryption:v1`, 32)
const keyMac = hkdfSync('sha256', masterKey, salt, `tenant:${tenantId}:blind-index:v1`, 32)
```

Isso dá: isolamento entre tenants (vazou a derivada de um, os outros seguem), separação
cifra/MAC sem gerenciar N segredos, e versionamento (`:v1`) que viabiliza rotação. Erro comum
inverso: usar Argon2/bcrypt para derivar de material já uniforme (desperdício) ou HKDF para
senha (inseguro — HKDF não é caro).

## TLS na prática

### Versões e suites

- **TLS 1.0/1.1: proibidos** (RFC 8996, 2021). SSLv3 nem se fala (POODLE).
- **TLS 1.2**: mínimo aceitável, só com ECDHE + AEAD (`ECDHE-*-AES128-GCM`,
  `ECDHE-*-CHACHA20-POLY1305`). Sem CBC, sem RSA key exchange (sem PFS e alvo de ROBOT), sem
  renegociação insegura.
- **TLS 1.3**: preferido — removeu tudo isso por construção (só AEAD, só (EC)DHE, handshake
  cifrado). Cuidado pontual: 0-RTT permite replay; não aceite early data em endpoint mutável.
- **PFS**: com ECDHE, capturar tráfego hoje e roubar a chave do certificado amanhã não decifra o
  passado. É o motivo de RSA key exchange estar morto.

Config de servidor: gere pelo
[Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) (perfil *intermediate*),
valide com [SSL Labs](https://www.ssllabs.com/ssltest/) ou `testssl.sh`.

### Certificado

- **SAN é o que vale** — browsers ignoram o CN desde ~2017 (Chrome 58).
- **Wildcard** (`*.example.com`): uma chave comprometida em qualquer host cobre todos os
  subdomínios; um subdomain takeover ganha um cert "válido" de brinde. Com ACME/Let's Encrypt
  emitindo cert por host de graça, wildcard só se justifica por multidão de subdomínios dinâmicos.
- **Certificate Transparency**: todo cert público vai para logs CT (obrigatório desde 2018).
  Útil dos dois lados: monitore emissões para seus domínios (crt.sh, Cert Spotter) — é assim que
  se detecta emissão indevida; e lembre que **hostname interno em cert público vaza topologia**.

### Validação no cliente — o erro nº 1 em código de integração

Desligar a validação transforma TLS em criptografia com o MITM. Os padrões, todos em produção
com frequência deprimente:

| Stack | Padrão a caçar |
|---|---|
| Node `https`/`tls` | `rejectUnauthorized: false` |
| Node (global) | `NODE_TLS_REJECT_UNAUTHORIZED=0` (env — cheque Dockerfile e CI também) |
| Go | `tls.Config{InsecureSkipVerify: true}` |
| Python requests | `verify=False` (e `urllib3.disable_warnings` escondendo o aviso) |
| Java | `TrustManager` que não lança / `HostnameVerifier` que retorna `true` |
| curl | `-k` / `--insecure` em script |

A desculpa é sempre "certificado self-signed no ambiente X". A correção certa é **confiar na CA
específica**, não desligar tudo: `ca: fs.readFileSync('internal-ca.pem')` no Node,
`REQUESTS_CA_BUNDLE` no Python, `RootCAs` no Go. Igualmente grave e mais sutil: validar o cert
mas não o hostname (`checkServerIdentity: () => undefined`).

**Pinning**: fixar a chave pública esperada além da cadeia. Vale para mobile contra MITM com CA
instalada e para conexões máquina-a-máquina de alto valor; o custo é operacional — cert
rotacionado sem atualizar o pin = outage (o motivo de HPKP ter sido removido dos browsers).
Sempre com pin de backup e prazo. Detalhes mobile em `references/mobile.md`.

**mTLS**: cliente também apresenta cert — o padrão para serviço-a-serviço interno (service mesh
faz por você: Istio/Linkerd). Um endpoint interno sem auth de aplicação **atrás de mTLS com
autorização por identidade do cert** não é achado — mas confirme que o mTLS existe mesmo, não só
no diagrama.

**HSTS e downgrade**: `Strict-Transport-Security` com preload fecha o primeiro-acesso-em-HTTP —
mecânica e interação com cookies em `references/xss-e-navegador.md`.

**Terminação no load balancer**: TLS morre no ALB/nginx e o trecho LB → aplicação vai em claro.
Dentro de uma VPC bem segmentada é risco aceito comum; vira achado quando o trecho em claro
cruza rede compartilhada, quando compliance exige (PCI-DSS 4.0 pede cifra em redes abertas e
recomenda interna), ou quando headers de identidade (`X-Forwarded-*`, header de auth interna)
viajam nesse trecho e qualquer pod na rede pode forjá-los — cruze com
`references/ssrf-e-camada-http.md`.

### Pós-quântica: onde estamos (2026)

- **Padrões prontos**: FIPS 203 (**ML-KEM**, ex-Kyber), FIPS 204 (**ML-DSA**, ex-Dilithium),
  FIPS 205 (**SLH-DSA**, ex-SPHINCS+), publicados em agosto/2024.
- **Key exchange híbrido já é o default real**: **X25519MLKEM768** habilitado por padrão no
  Chrome (131+) e Firefox (132+; QUIC no 135), suportado por Cloudflare/Google/Akamai na borda,
  nativo no **OpenSSL 3.5** (abril/2025), e chegando aos SDKs da AWS. Híbrido = ECDH clássico +
  ML-KEM concatenados; quebrar exige quebrar os dois. Se seu servidor está atrás de CDN moderna,
  você provavelmente já fala PQC sem saber; se termina TLS você mesmo, atualizar para OpenSSL
  3.5+ e habilitar o grupo é o passo de 2026.
- **Assinatura**: certificados ML-DSA ainda em transição (cadeias híbridas em piloto) — para
  assinatura de aplicação, Ed25519 segue sendo a resposta; planeje migração, não a execute às
  cegas.
- **Cronograma NIST** (IR 8547 draft): RSA/ECC clássicos *deprecated* ~2030, *disallowed* ~2035.
- **"Harvest now, decrypt later"** é o motivo de agir antes do computador quântico existir:
  tráfego capturado hoje pode ser decifrado quando ele existir. Importa para **dado de vida
  longa** — saúde, dado genético, segredo industrial, comunicação diplomática. Se seu dado
  precisa de sigilo por 10+ anos, o key exchange híbrido em trânsito e a cifra em repouso com
  AES-256 (já considerado quantum-resistente com margem) são o mínimo hoje.

## Gestão de segredos

A parte com mais incidentes reais: o GitGuardian reporta consistentemente **milhões de segredos
novos vazados por ano só em repositórios públicos do GitHub** (12,8 M em 2023, ~23,8 M em 2024).
Uber 2022 (credencial em script no share interno), Codecov 2021 (segredo exfiltrado do bash
uploader), Toyota, Mercedes — o padrão de entrada é sempre um segredo largado onde não devia.

### Onde segredo vaza

- **Git — e o histórico**: `git rm .env && git commit` **não remove nada**; o blob continua
  alcançável no histórico e em qualquer fork/clone. Bots varrem commits públicos em segundos —
  o tempo entre push de uma AWS key e o primeiro uso malicioso é medido em **minutos**.
- **`.env` commitado** (esqueceu o `.gitignore`) e `.env.example` que virou `.env` com valores
  reais.
- **Dockerfile**: `ENV API_KEY=...` e `ARG` ficam gravados nos metadados da imagem
  (`docker history --no-trunc` mostra; build args idem). `COPY .env .` grava o arquivo numa
  camada — deletar em camada posterior não apaga a anterior. O certo:
  `RUN --mount=type=secret,id=npmrc` (BuildKit) para build, injeção em runtime para execução.
- **Frontend bundle**: **tudo que chega ao browser é público, sem exceção**. `NEXT_PUBLIC_*` e
  `REACT_APP_*`/`VITE_*` existem justamente para inlinar a variável no bundle — colocar
  `NEXT_PUBLIC_STRIPE_SECRET_KEY` não é vazamento sutil, é publicação. O prefixo é o contrato:
  sem ele o Next.js não expõe; com ele, assuma que está no HTML de qualquer um. Segredo de
  verdade fica em route handler/server component e o browser recebe só o resultado.
- **Source map publicado**: `.map` em produção expõe o código-fonte original — inclusive o
  segredo que "estava só no código do servidor" se o bundling vazou para o client.
- **Logs e crash reporters**: `console.log(req)` sheader `Authorization` incluso; Sentry/Datadog
  capturando env vars no contexto do erro; `/proc/<pid>/environ` legível por quem tem exec no
  container.
- **CI**: segredo ecoado em log (mascaramento do GitHub Actions falha se o valor for
  transformado — base64, substring), artefato de build com `.env` dentro, `set -x` em script.
- **O resto**: backup de banco sem cifra, screenshot em issue/doc, mensagem de erro com
  connection string, PR de fork com acesso a secrets (pull_request_target — veja
  `references/supply-chain-e-cicd.md`), app mobile (strings no binário — `references/mobile.md`).

### O que fazer

1. **Cofre**: HashiCorp Vault/OpenBao, AWS Secrets Manager, GCP Secret Manager, Doppler,
   1Password (dev/CLI). O que o cofre dá que env var não dá: auditoria de acesso, rotação
   gerenciada, versionamento, revogação central, ACL por identidade.
2. **Injeção em runtime**, não em build: o segredo entra no processo na subida (sidecar do
   Vault, `secrets` do ECS/K8s via CSI driver, `op run --`), nunca na imagem.
3. **Workload identity — a evolução que elimina o problema na raiz**: em vez de um segredo
   estático que pode vazar, a carga de trabalho **prova quem é** e recebe **credencial de curta
   duração**:
   - CI: **OIDC federation** — GitHub Actions/GitLab emite um token OIDC assinado dizendo "sou o
     workflow X do repo Y na branch Z"; a AWS/GCP/Azure troca por credencial de 1h via
     `AssumeRoleWithWebIdentity`. Zero `AWS_SECRET_ACCESS_KEY` no repo. **Condicione o trust ao
     repo E à branch/ambiente** (`sub` claim) — trust policy com `repo:org/*` é um achado.
   - Runtime: IAM Roles (EC2/ECS), **IRSA** no EKS, Workload Identity no GKE, Managed Identity
     no Azure.
   - Não há o que vazar: a credencial expira em minutos/horas e a identidade não é exportável.
4. **GitOps**: segredo cifrado no repo com **sops + age** (ou KMS) ou **SealedSecrets**
   (cifrado para a chave pública do controller no cluster). O repo carrega ciphertext; só o
   destino decifra. Nunca `Secret` do K8s em YAML plano no git — base64 não é cifra.
5. **Higiene**: rotação periódica (automática via cofre onde der), escopo mínimo por credencial
   (uma key por serviço, não "a key da empresa"), e **prefixo identificável em token próprio** —
   `ghp_` (GitHub), `sk_live_` (Stripe), `xoxb-` (Slack) existem para que scanners reconheçam o
   formato; se você emite API keys, adote um (`myapp_live_<random>`) e registre no GitHub Secret
   Scanning Partner Program se for SaaS.

### Resposta a vazamento — a ordem importa

1. **Revogar/rotacionar imediatamente** a credencial exposta. Isso é o incidente; o resto é
   limpeza.
2. **Investigar uso**: CloudTrail/audit logs desde o primeiro commit exposto (não desde a
   descoberta). Assuma comprometimento se o repo era público — bots chegam em minutos.
3. **Caçar persistência**: chaves novas criadas, roles alteradas, recursos desconhecidos.
4. **Só então limpar o histórico**: `git filter-repo` ou BFG, force-push, contatar o GitHub para
   invalidar caches de fork/PR. **Reescrever histórico sem revogar é teatro**: o segredo já foi
   clonado, indexado e testado; a reescrita só melhora a estética do repo.

**Detecção contínua**: `gitleaks` (pre-commit + CI), `trufflehog` (varre histórico e valida se a
credencial está viva), **GitHub secret scanning + push protection** (bloqueia o push que contém
padrão conhecido — ligue na organização; é gratuito para repos públicos e o recurso com melhor
custo-benefício da lista). Configuração e comparação em `references/ferramentas.md`.

## Dado sensível em repouso e em trânsito na aplicação

### Classificação primeiro

Sem classificação, "cifrar dado sensível" não tem denominador. Mínimo viável: **credencial**
(senha, token, chave), **dado financeiro** (PAN/cartão → PCI-DSS), **dado de saúde**
(→ HIPAA/LGPD art. 11 "dado sensível"), **PII** (CPF, RG, e-mail, endereço, e — LGPD art. 5º —
qualquer dado de pessoa identificável), **dado sensível LGPD** (origem racial, religião, saúde,
biometria, vida sexual, político-sindical — regime mais restrito). Cada classe define: pode
logar? cifra em nível de campo? retenção? quem acessa?

### O que cada camada de cifra realmente protege

| Camada | Protege contra | NÃO protege contra |
|---|---|---|
| Disco/volume (LUKS, EBS encryption) | roubo físico do disco, descarte incorreto | qualquer coisa com o sistema ligado |
| TDE (banco) | cópia dos arquivos de dados/backup frio | **SQL injection, credencial de app vazada, DBA curioso** — a query vê plaintext |
| Nível de campo (aplicação cifra antes do INSERT) | dump do banco, SQLi de leitura, backup vazado, DBA | comprometimento do app server (que tem a chave), lógica de autorização quebrada |

TDE marcado como "dados cifrados ✓" no questionário de compliance enquanto o endpoint tem IDOR é
o teatro clássico. Cifra de campo com chave no KMS + AAD amarrando ao registro (seção AEAD) é o
que muda o resultado de um dump.

### Busca sobre dado cifrado

Cifra AEAD com nonce aleatório é não-determinística — `WHERE encrypted_cpf = ?` não funciona.
Soluções e seus custos:

- **Blind index**: coluna extra com `HMAC(chave_de_indice, normalizar(valor))` — busca por
  igualdade exata funciona. **Vaza igualdade e frequência**: dá para ver quantas linhas têm o
  mesmo valor e correlacionar entre tabelas se a chave for a mesma (use HKDF por coluna). Para
  valores de espaço pequeno (CPF tem 11 dígitos com DV — ~10⁹ válidos), um atacante com a chave
  do índice enumera tudo; sem a chave, o vazamento é só estatístico.
- **Tokenização**: troca o valor por um token opaco e guarda o mapeamento num cofre isolado
  (padrão PCI para PAN — tira o banco inteiro do escopo).
- Busca parcial/`LIKE` sobre cifrado: não existe solução boa em app comum — repense se a coluna
  precisa mesmo ser cifrada ou se o requisito de busca está certo.

### LGPD no que afeta decisão técnica

Lei 13.709/2018 ([texto](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm)):

- **Base legal (art. 7º)**: todo tratamento precisa de uma — consentimento, obrigação legal,
  execução de contrato, legítimo interesse etc. Efeito técnico: cada coleta de campo novo no
  formulário precisa de justificativa; "pode ser útil depois" não é base legal.
- **Direitos do titular (art. 18)**: acesso, correção, portabilidade e **eliminação**. Efeito
  técnico: você precisa conseguir **apagar de verdade** — inclusive de backups (ou documentar
  expiração do backup como término), logs e réplicas analíticas. Soft delete não cumpre
  eliminação. *Crypto-shredding* (cifrar por titular e destruir a chave) é a implementação
  prática quando apagar fisicamente é inviável.
- **Incidente (art. 48)**: comunicação à **ANPD** e ao titular quando houver risco relevante —
  a Resolução CD/ANPD nº 15/2024 fixa **3 dias úteis** a partir do conhecimento. Efeito técnico:
  os logs da seção A09 são o que permite dizer *o que* vazou e *de quem* dentro do prazo.
- **Transferência internacional (art. 33)**: replicar o banco para região fora do país exige
  mecanismo válido (cláusulas contratuais padrão da ANPD, países adequados). Efeito técnico:
  escolha de região de nuvem e de vendor de analytics é decisão de compliance.
- Mapeamento rápido: GDPR ≈ LGPD com prazos diferentes (72 h para notificação); **PCI-DSS**
  adiciona regras duras sobre PAN (nunca armazenar CVV, PAN mascarado exibindo no máximo
  BIN+4); **HIPAA** exige audit trail de acesso a registro de saúde por usuário.

### Mascaramento em resposta de API e retenção

O vazamento mais barato de encontrar em revisão não envolve cifra nenhuma: o endpoint devolve o
objeto do banco inteiro. `return user` com o model do Prisma serializa `passwordHash`,
`mfaSecret`, `resetToken`, CPF completo — e o front "só não mostra". Regras:

- **Serialização por allowlist**, nunca por blocklist: um schema de resposta (Zod,
  `@fastify/type-provider-typebox` com `response` schema — o Fastify **remove** campos fora do
  schema de resposta, um dos poucos frameworks em que o schema é filtro de saída de verdade)
  declara o que sai; campo novo no model não vaza por padrão.
- Mascare o que precisa aparecer parcialmente: PAN como `**** **** **** 1234` (PCI permite
  BIN+4 no máximo), CPF como `***.***.***-12`, e-mail como `m***@gmail.com` em contexto de
  enumeração. O mascaramento acontece no servidor — dado mascarado "no CSS" está no payload.
- GraphQL torna isso pior (o cliente escolhe campos; introspection revela os sensíveis) — veja
  `references/api-e-graphql.md`.

**Retenção e exclusão**: defina TTL por classe de dado no design, não no incidente — job de
expurgo agendado, particionamento por data para `DROP PARTITION` barato, e o caminho de
eliminação do titular (LGPD art. 18) testado de ponta a ponta, incluindo réplicas de analytics e
índices de busca (Elasticsearch é o esquecido clássico). Dado que você não guarda é dado que não
vaza — minimização é o controle de segurança com melhor ROI da lista.

### Dado sensível em log

**Nunca logar**: senha (nem errada — "senha inválida: hunter2" já aconteceu no Twitter e GitHub,
que em 2018 tiveram que resetar senhas por logá-las em plaintext internamente), token/API key,
header `Authorization` e `Cookie`, PAN completo, CPF completo (mascare: `***.***.***-12`),
respostas de OAuth com `access_token`, corpo de request de login.

O stack é Node/Fastify — `pino` tem redaction nativa e o Fastify usa pino por padrão:

```ts
// ✅ redaction real no pino (config do Fastify: logger: { redact: ... })
const logger = pino({
  redact: {
    paths: [
      'req.headers.authorization', 'req.headers.cookie',
      '*.password', '*.senha', '*.token', '*.accessToken', '*.refreshToken',
      '*.cpf', '*.cardNumber', 'res.headers["set-cookie"]',
    ],
    censor: '[REDACTED]',
  },
})
```

Limites que precisam ser ditos em revisão: o `redact` só cobre os *paths* listados — um
`logger.info(err)` ou `console.log(req)` **passa por fora**; objetos de erro carregam o request
inteiro em `err.config` (axios) ou `err.response`, e é assim que token vaza para o Sentry.
Regra: logue campos escolhidos (`{ userId, route }`), nunca o objeto inteiro; configure
`beforeSend` no Sentry para scrubbing; e trate log como dado sensível em si (acesso restrito,
retenção definida).

## Logging e monitoramento de segurança (A09)

A09:2025 (*Security Logging & Alerting Failures* — o rename de 2025 enfatiza **alerta**, porque
log que ninguém olha só serve para a perícia post-mortem). O tempo médio de detecção de breach
segue em meses; o que o encurta é exatamente esta seção.

**Eventos que precisam de log** (OWASP Logging Cheat Sheet):

| Evento | Por quê |
|---|---|
| Login: sucesso, falha, bloqueio | brute force, credential stuffing, spray |
| Logout e invalidação de sessão | linha do tempo de incidente |
| Mudança de privilégio/role, criação de admin | escalação é o objetivo do atacante |
| **Falha de autorização** (403 em recurso alheio) | IDOR sendo enumerado aparece aqui antes do breach |
| Acesso a dado sensível (quem leu o registro de quem) | LGPD/HIPAA e detecção de abuso interno |
| Mudança de configuração, feature flag, chave de API criada/revogada | persistência do atacante |
| Falha de validação de entrada repetida, erro 500 em massa | probing |
| Operações do KMS/cofre (decrypt, acesso a segredo) | uso anômalo de chave = comprometimento |

**Formato e correlação**: JSON estruturado, um evento por linha, com `timestamp` (UTC, NTP
sincronizado — sem isso a linha do tempo do incidente não fecha), `requestId`/`traceId`
propagado entre serviços, `userId`, `sourceIp`, `outcome`. O evento de segurança precisa ser
distinguível (`event: "authz.denied"`) para alertar sem regex frágil sobre mensagem.

**Integridade**: o primeiro gesto do atacante com root é editar o log. Envie para fora do host
em near-real-time (CloudWatch, Loki, SIEM), armazenamento append-only/WORM (S3 Object Lock para
o que é evidência), e IAM que nem o admin da aplicação consegue deletar.

**Alerta acionável vs ruído**: alerte sobre padrões, não eventos unitários — N falhas de login
por conta/IP em janela, primeiro login de país novo, criação de admin fora de horário, spike de
403, `decrypt` do KMS de origem inédita. Cada alerta precisa de dono e runbook; alerta que
dispara diariamente sem ação é pior que nenhum (treina a equipe a ignorar).

**Retenção**: defina por classe — evento de segurança 1 ano+ (PCI-DSS: 12 meses, 3 disponíveis),
log de aplicação com PII o mínimo (LGPD: minimização vale para log também).

**O log como vetor**: entrada do usuário no log sem escape permite log injection (forjar linhas,
quebrar parsing, CRLF) e já foi RCE via biblioteca de logging — Log4Shell (CVE-2021-44228,
`${jndi:ldap://...}` num header logado). Sanitização de newline e o caso Log4j em
`references/injecao.md`.

## Sinais em revisão de código

Padrões de busca (ajuste extensões ao repo):

| Achado provável | Padrão |
|---|---|
| Segredo hardcoded | `grep -rnE "(api[_-]?key\|secret\|password\|token)\s*[:=]\s*['\"][A-Za-z0-9+/_-]{16,}"` — e rode `gitleaks detect` no histórico, não só no HEAD |
| Chave de provedor pelo prefixo | `grep -rnE "AKIA[0-9A-Z]{16}\|ghp_[A-Za-z0-9]{36}\|sk_live_\|xox[bap]-\|AIza[0-9A-Za-z_-]{35}"` |
| IV/nonce fixo | `grep -rn "createCipheriv" -A3` e olhe o 3º argumento: `Buffer.alloc(12)`, `Buffer.from("0000..."`, constante do módulo = achado |
| Cifra sem autenticação | `grep -rnE "aes-[0-9]+-(cbc\|ctr\|ecb)"` — CBC/CTR sem HMAC visível por perto, ECB sempre |
| API removida/perigosa | `grep -rn "crypto.createCipher(\|createDecipher("` (sem `iv` — legado pré-Node 22) |
| TLS desligado | `grep -rnE "rejectUnauthorized:\s*false\|InsecureSkipVerify:\s*true\|verify\s*=\s*False\|NODE_TLS_REJECT_UNAUTHORIZED"` (inclua Dockerfile, docker-compose, CI YAML) |
| Aleatoriedade fraca em segurança | `grep -rn "Math.random" --include="*.ts"` e avalie o contexto: token/senha/código/id de sessão = achado |
| Comparação de segredo com `===` | `grep -rnE "(signature\|token\|hmac\|digest\|secret).{0,20}(===\|==\|!==)"` |
| Hash morto em contexto vivo | `grep -rnE "md5\|sha1"` e avalie: assinatura/senha/integridade = achado |
| Segredo no frontend | `grep -rn "NEXT_PUBLIC_\|REACT_APP_\|VITE_"` e pergunte de cada um: "isso pode ser público?" |
| Dockerfile vazando | `grep -rnE "^(ENV\|ARG).*(KEY\|SECRET\|TOKEN\|PASSWORD)" Dockerfile*` |
| Log vazando | `grep -rnE "console\.log\(req\|logger\.(info\|debug)\(.*req\.headers\|logger\..*password"` |

Semgrep cobre a maioria com os rulesets `p/secrets`, `p/nodejs-crypto` e `p/security-audit`;
`gitleaks` + push protection do GitHub para segredos — configuração em
`references/ferramentas.md`.

## Falsos positivos comuns

Marque como **não-achado** (e economize a confiança do usuário):

- **`Math.random()` fora de contexto de segurança**: jitter de retry/backoff, id de elemento de
  UI, amostragem de telemetria, animação, seed de teste. O critério é único: o valor dá acesso a
  algo ou é imprevisível-por-contrato? Não → não é achado.
- **MD5/SHA-1 não-criptográfico**: chave de cache, etag, sharding/particionamento, dedupe sem
  consequência de segurança, checksum de corrupção acidental. Sinalize só se colisão ou pré-imagem
  beneficiar um atacante. (Ainda vale sugerir SHA-256/xxhash em código novo — como estilo, não
  como vulnerabilidade.)
- **Chave pública commitada**: cert `.pem`/`.crt`, chave pública SSH/age/JWKS no repo são
  públicos por definição. Scanner que aponta `-----BEGIN PUBLIC KEY-----` ou
  `-----BEGIN CERTIFICATE-----` está errando; só `PRIVATE KEY` importa.
- **`NEXT_PUBLIC_*` com valor de fato público**: URL da API, chave *publishable* do Stripe
  (`pk_live_` é desenhada para o browser), site key de reCAPTCHA/Turnstile, DSN do Sentry,
  API key do Google Maps **com restrição de referrer**. O achado é segredo com o prefixo, não o
  prefixo.
- **Segredo de exemplo/teste**: `password123` em fixture, `sk_test_` do Stripe (modo teste),
  chaves em `testdata/` claramente sintéticas, o RSA key de exemplo da RFC 7515 em teste de JWT.
  Confirme que não é real (trufflehog valida contra a API) antes de alarmar.
- **TDE/EBS encryption "faltando" camada de campo**: cifra em repouso de infraestrutura sem
  cifra de campo não é vulnerabilidade por si — é decisão de risco. Vire achado apenas se
  requisito (PCI, dado de saúde, promessa contratual) exigir mais.
- **`http://` interno atrás de mTLS/service mesh** ou terminação TLS no LB dentro de VPC
  segmentada: risco aceito comum, não achado automático — pergunte pelo desenho antes.
- **Comparação `===` de hash de senha**: se o código compara com `bcrypt.compare`/
  `argon2.verify`, a lib já é constante no tempo. O `===` problemático é sobre MAC/token cru.
- **UUID v4 de `crypto.randomUUID()` como token**: 122 bits de CSPRNG — abaixo do ideal
  estético, acima do limiar de exploração. Não reporte como "entropia insuficiente".

## Fontes

- OWASP Top 10:2025 — <https://owasp.org/Top10/2025/> (A04 Cryptographic Failures, A09 Security
  Logging & Alerting Failures)
- OWASP Cheat Sheets: [Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html),
  [Key Management](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html),
  [Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html),
  [TLS](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html),
  [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html),
  [Logging Vocabulary](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Vocabulary_Cheat_Sheet.html)
- Latacora — [Cryptographic Right Answers: Post-Quantum Edition (2024)](https://www.latacora.com/blog/post-quantum-cryptographic-right-answers/)
- NIST: [SP 800-57 Part 1 Rev. 5](https://csrc.nist.gov/pubs/sp/800/57/pt1/r5/final) (key
  management), [SP 800-131A Rev. 2](https://csrc.nist.gov/pubs/sp/800/131/a/r2/final)
  (transições de algoritmo), [SP 800-38D](https://csrc.nist.gov/pubs/sp/800/38/d/final) (GCM e
  limites de nonce), [FIPS 203/204/205](https://csrc.nist.gov/projects/post-quantum-cryptography)
  (ML-KEM/ML-DSA/SLH-DSA), [IR 8547](https://csrc.nist.gov/pubs/ir/8547/ipd) (transição PQC)
- RFCs: [5869 (HKDF)](https://www.rfc-editor.org/rfc/rfc5869),
  [6979 (ECDSA determinístico)](https://www.rfc-editor.org/rfc/rfc6979),
  [8452 (AES-GCM-SIV)](https://www.rfc-editor.org/rfc/rfc8452),
  [8996 (deprecação TLS 1.0/1.1)](https://www.rfc-editor.org/rfc/rfc8996),
  [9180 (HPKE)](https://www.rfc-editor.org/rfc/rfc9180),
  [9562 (UUID v7)](https://www.rfc-editor.org/rfc/rfc9562)
- Node.js — [docs do módulo `crypto`](https://nodejs.org/api/crypto.html) (DEP0106,
  `timingSafeEqual`, `hkdfSync`); [libsodium docs](https://doc.libsodium.org/)
  (`secretbox`, `secretstream`, XChaCha20)
- TLS híbrido PQC: [draft-ietf-tls-ecdhe-mlkem](https://datatracker.ietf.org/doc/draft-ietf-tls-ecdhe-mlkem/)
  (X25519MLKEM768); [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/)
- Segredos: [gitleaks](https://github.com/gitleaks/gitleaks),
  [trufflehog](https://github.com/trufflesecurity/trufflehog),
  [GitHub secret scanning / push protection](https://docs.github.com/en/code-security/secret-scanning),
  [GitHub OIDC para cloud](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- LGPD — [Lei 13.709/2018](https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/l13709.htm);
  [Resolução CD/ANPD nº 15/2024](https://www.gov.br/anpd/pt-br) (comunicação de incidente)
- pino — [redaction](https://getpino.io/#/docs/redaction)
- Padding oracle: [PortSwigger — CBC byte flipping / padding oracle](https://portswigger.net/web-security)
- GCM nonce reuse (Joux, "forbidden attack"): resumo prático em
  <https://soatok.blog/2020/05/13/why-aes-gcm-sucks/>
