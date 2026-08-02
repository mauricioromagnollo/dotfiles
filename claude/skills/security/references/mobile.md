# Segurança de aplicações mobile

Cobre o que é **específico de plataforma** em Android e iOS — nativo e cross-platform (React Native,
Flutter, Capacitor/Cordova). Abra este arquivo ao revisar um `AndroidManifest.xml`, um `Info.plist`,
código Kotlin/Swift/Objective-C, o lado nativo de um app React Native, ao decidir onde guardar um
token no dispositivo, ao avaliar pinning/attestation/anti-root, ou ao planejar o teste de um app.

O que **não** está aqui: tudo que é falha do servidor. A API que o app consome se revisa com
`references/api-e-graphql.md`, `references/autorizacao-e-logica-de-negocio.md`,
`references/autenticacao-e-sessao.md` e `references/injecao.md`. Isso não é uma divisão burocrática —
é a tese central da próxima seção.

## Índice

- [A premissa que muda tudo](#a-premissa-que-muda-tudo)
- [Padrões: Mobile Top 10, MASVS, MASTG](#padrões-mobile-top-10-masvs-mastg)
- [Armazenamento local](#armazenamento-local)
- [Comunicação de rede](#comunicação-de-rede)
- [Certificate pinning: quando vale](#certificate-pinning-quando-vale)
- [Superfície de plataforma: Android](#superfície-de-plataforma-android)
- [Superfície de plataforma: iOS](#superfície-de-plataforma-ios)
- [Cross-platform](#cross-platform)
- [Autenticação em mobile](#autenticação-em-mobile)
- [Attestation e device binding](#attestation-e-device-binding)
- [Resiliência (MASVS-RESILIENCE) com honestidade](#resiliência-masvs-resilience-com-honestidade)
- [Testar um app na prática](#testar-um-app-na-prática)
- [Sinais em revisão de código](#sinais-em-revisão-de-código)
- [Falsos positivos comuns](#falsos-positivos-comuns)
- [Fontes](#fontes)

---

## A premissa que muda tudo

O binário está na mão do atacante. Ele instala o app num dispositivo que ele controla — rooteado,
com bootloader destravado, com Frida injetado no processo, com o tráfego passando por um proxy que
ele configurou. Nada que roda dentro do processo do app é confiável para o servidor.

As três consequências que você precisa repetir em toda revisão:

1. **Todo segredo embarcado é público.** Uma chave de API no `BuildConfig`, no `Info.plist`, num
   `.env` empacotado pelo Metro, numa string ofuscada por R8, num `.so` nativo com XOR — tudo isso é
   recuperável. O custo varia de `strings app.apk | grep -i key` a uma tarde de Ghidra. Não existe
   "segredo do cliente"; existe segredo que dura mais ou menos tempo. Se o segredo dá acesso a algo
   que vale dinheiro, ele precisa ficar no servidor, com o app pedindo ao servidor que faça a
   chamada por ele.
2. **Toda validação local é sugestão.** Checagem de saldo, limite de transferência, "usuário é
   premium", "o CPF é válido", "o cupom expirou", `if (isJailbroken) exit()` — tudo isso vira um
   `NOP` num patch de bytecode ou um `Interceptor.attach` no Frida. Validação client-side é UX. A
   decisão precisa ser tomada no servidor, de novo, com os mesmos dados.
3. **Todo endpoint que o app chama é um endpoint público.** Ele será chamado com `curl`, fora de
   ordem, com o `userId` do vizinho, sem passar pela tela que "garantia" o pré-requisito. Isso é
   IDOR e broken business logic — veja `references/autorizacao-e-logica-de-negocio.md`.

**A segurança de um produto mobile é ~80% a segurança da API.** O erro conceitual mais caro nessa
área é uma equipe gastar três sprints em anti-root e ofuscação enquanto o endpoint
`GET /api/v1/accounts/{id}/statement` não checa se `{id}` pertence ao token. Em bug bounty de apps,
a esmagadora maioria dos achados de alta severidade é: IDOR na API, autenticação quebrada na API,
token com escopo excessivo, endpoint de admin acessível. Os achados client-side puros (dado em
`SharedPreferences`, `ContentProvider` exportado, deep link mal validado) existem e importam, mas
raramente pagam o bounty maior — exceto quando encadeados com algo da API.

O que **é** genuinamente client-side e merece o seu tempo, em ordem de retorno:

- Dado sensível persistido sem cifra no dispositivo (roubo físico, backup, malware, forense).
- Superfície de IPC exposta: componentes exportados, deep links, `ContentProvider`, WebView com
  ponte nativa. É aqui que mora "app malicioso instalado no mesmo dispositivo lê/escreve dado do
  seu app".
- Fluxo de autenticação mal montado (WebView de login, redirect roubado, refresh token eterno em
  texto claro).
- Vazamento por canais laterais: log, clipboard, screenshot em background, crash reporter.

---

## Padrões: Mobile Top 10, MASVS, MASTG

### OWASP Mobile Top 10 (edição 2024, vigente em agosto de 2026)

A lista foi reescrita em 2024 e continua sendo a edição corrente — não houve edição 2025/2026.
Códigos exatos:

| Código | Categoria | O que costuma cair aqui na prática |
|---|---|---|
| **M1** | Improper Credential Usage | Credencial hardcoded no binário; token com escopo eterno; senha em `SharedPreferences` |
| **M2** | Inadequate Supply Chain Security | SDK de terceiro exfiltrando dado; dependência comprometida; pipeline de build sem assinatura — veja `references/supply-chain-e-cicd.md` |
| **M3** | Insecure Authentication/Authorization | Autorização decidida no cliente; biometria só com `evaluatePolicy`; IDOR na API |
| **M4** | Insufficient Input/Output Validation | Deep link não validado; SQL injection local; path traversal em `ContentProvider` |
| **M5** | Insecure Communication | Cleartext HTTP; ATS desligado; validação de certificado desativada |
| **M6** | Inadequate Privacy Controls | PII em log/analytics; permissão excessiva; identificador persistente |
| **M7** | Insufficient Binary Protections | Sem ofuscação/anti-tamper onde o modelo de ameaça exige |
| **M8** | Security Misconfiguration | `debuggable`, `allowBackup`, componente exportado sem querer |
| **M9** | Insecure Data Storage | Keychain/Keystore não usados; cache de WebView; snapshot |
| **M10** | Insufficient Cryptography | ECB, IV fixo, chave derivada de string constante — veja `references/criptografia-e-segredos.md` |

Repare que M7 (binary protections) é **uma** de dez categorias e M1/M3/M9 dominam achados reais. Use
o Top 10 como taxonomia para comunicar severidade, não como plano de trabalho.

### MASVS v2.1.0 — os grupos de controle

O MASVS foi refatorado na v2.0.0 (abril de 2023) e a versão corrente é a **v2.1.0**, com 8 grupos e
24 controles. A mudança estrutural mais importante: **os níveis L1/L2/R foram removidos do MASVS** e
viraram *testing profiles* no MASTG. Se você ler "MASVS L2" numa RFP, o interlocutor está falando de
`MAS-L2`, um perfil de teste — não de um nível do MASVS atual.

| Grupo | Escopo |
|---|---|
| **MASVS-STORAGE** | Onde e como o dado sensível é persistido; o que vaza para log, backup, cache |
| **MASVS-CRYPTO** | Algoritmos, gestão de chave, uso do keystore de hardware |
| **MASVS-AUTH** | Autenticação e autorização, incluindo autenticação local (biometria) |
| **MASVS-NETWORK** | TLS, validação de certificado, pinning |
| **MASVS-PLATFORM** | IPC, WebView, deep link, permissões, telas sensíveis |
| **MASVS-CODE** | Dependências, validação de input, tratamento de erro, build seguro |
| **MASVS-RESILIENCE** | Anti-tamper, anti-debug, ofuscação, detecção de ambiente |
| **MASVS-PRIVACY** | Minimização de dado, transparência, preferências do usuário (novo na v2.1.0) |

### MASTG e os perfis de teste

O **MASTG** (Mobile Application Security Testing Guide, v2.0 desde junho de 2026) é o guia de teste.
Ele é modular e endereçável — cada peça tem um ID estável, o que torna prático citar num relatório e
automatizar:

- **MASTG-TEST-xxxx** — o procedimento de teste em si, mapeado a um controle MASVS e a uma fraqueza
  MASWE. Ex.: testes de armazenamento no Android sob MASVS-STORAGE-1.
- **MASTG-TECH-xxxx** — técnica de apoio (ex.: `MASTG-TECH-0109` "Intercepting Flutter HTTPS Traffic"
  no Android, `MASTG-TECH-0110` o equivalente iOS).
- **MASTG-TOOL-xxxx** — a ferramenta (Frida, objection, apktool…).
- **MASTG-KNOW** / **MASTG-BEST** / **MASTG-DEMO** — conhecimento de plataforma, boa prática e
  demonstração executável com código.

Os perfis definem o que está em escopo:

- **MAS-L1** — baseline. Todo app deveria passar. Use como padrão em qualquer revisão.
- **MAS-L2** — defesa em profundidade para app que trata dado sensível: financeiro, saúde,
  identidade, comunicação privada. Exemplo concreto da diferença: em MASVS-STORAGE-1, guardar dado
  em armazenamento interno sem cifra é aceitável em L1 (o sandbox já protege num dispositivo íntegro);
  em L2 exige-se cifra com chave no Keystore/Secure Enclave, porque o modelo de ameaça inclui
  dispositivo rooteado/perdido.
- **MAS-R** — resiliência. **Só é justificado quando o próprio binário é o alvo**: o adversário lucra
  modificando o app (cheat em jogo, fraude em escala, contorno de DRM/licenciamento, clonagem de app
  bancário, bot farm). Não aplique R por reflexo: em app cujo valor está no servidor, R adiciona
  custo de build, quebras em dispositivos legítimos e falsos positivos de suporte, sem mover a agulha.
  R nunca é alternativa a L1/L2 — é adicional.

Regra prática de escopo: **L1 sempre; L2 se o app trata dinheiro, saúde ou identidade; R só se
existe incentivo econômico direto para adulterar o binário.**

---

## Armazenamento local

A pergunta de revisão é sempre a mesma: *se eu tirar esse dispositivo do bolso do usuário e fizer
dump do sandbox do app, o que eu leio?* No Android com root ou com backup habilitado, e no iOS com
jailbreak ou backup não cifrado, o sandbox não protege nada.

**Nunca vai sem cifra em**: `SharedPreferences`, `NSUserDefaults`, `localStorage`/`sessionStorage` de
WebView, `AsyncStorage` do React Native, SQLite/Room/Core Data comum, arquivo em
`getExternalFilesDir()`, JSON no diretório de documentos.

**O que conta como "dado sensível"**: refresh token, senha, PIN, resposta de pergunta secreta, chave
de API do usuário, PII (CPF, endereço, dado de saúde), número completo de cartão, saldo/extrato,
histórico de mensagens, geolocalização precisa, cookie de sessão.

### Android

**Keystore** é o único lugar onde uma chave pode existir sem ser extraível. A chave é gerada dentro
do TEE (ou do **StrongBox**, um elemento seguro discreto, API 28+) e o app só recebe um *handle*: você
manda dado para cifrar, não recebe a chave.

```kotlin
// ✅ chave AES-GCM em hardware, exigindo biometria forte a cada uso
val spec = KeyGenParameterSpec.Builder("refresh_token_key",
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
    .setUserAuthenticationRequired(true)
    // API 30+: 0s de validade = exige auth por operação (CryptoObject obrigatório)
    .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
    // se o usuário cadastrar uma nova digital, a chave é destruída
    .setInvalidatedByBiometricEnrollment(true)
    .setUnlockedDeviceRequired(true)   // API 28+: só usa com a tela desbloqueada
    .setIsStrongBoxBacked(true)        // API 28+: lança StrongBoxUnavailableException, trate
    .build()
KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
    .apply { init(spec) }.generateKey()
```

Detalhes que decidem se isso funciona:

- `setUserAuthenticationRequired(true)` **sem** usar `BiometricPrompt.CryptoObject` não faz nada de
  útil: o app chama `authenticate()`, ignora o resultado e usa a chave. O vínculo real acontece
  quando você passa o `Cipher` inicializado dentro do `CryptoObject` — o `Cipher` só fica autorizado
  se o kernel/TEE viu a autenticação.
- `setInvalidatedByBiometricEnrollment(true)` é o que impede o cenário "atacante com o dispositivo
  desbloqueado cadastra a própria digital e lê o token". É o padrão para chaves de biometria, mas
  confirme explicitamente — bibliotecas wrapper às vezes desligam para reduzir suporte.
- `setIsStrongBoxBacked(true)` falha em dispositivos sem StrongBox; o fallback deve ser TEE, não
  "chave em software".
- **Key attestation**: `KeyStore.getCertificateChain(alias)` devolve uma cadeia com a extensão de
  attestation (OID `1.3.6.1.4.1.11129.2.1.17`) assinada pela raiz do Google, provando ao seu servidor
  que a chave nasceu em hardware. Isso é a base séria de *device binding* (veja adiante).

**EncryptedSharedPreferences / Jetpack Security — atenção, mudou.** A biblioteca
`androidx.security:security-crypto` (`EncryptedSharedPreferences`, `EncryptedFile`) foi **depreciada**
por volta do `1.1.0-alpha07` e não é mais o caminho recomendado. Os motivos foram práticos: I/O
síncrono na main thread (violações de StrictMode) e exceções de *keyset corruption* em OEMs
específicos, que geravam crash em massa sem correção viável no app. Recomendação atual: **Jetpack
DataStore para persistência + Tink para a cifra + Android Keystore para a chave**, ou cifra própria
com AES-GCM e chave no Keystore. Existe um fork comunitário (`ed-george/encrypted-shared-preferences`)
para quem precisa de sobrevida, sem suporte do Google. Numa revisão, `EncryptedSharedPreferences` **não
é um achado de segurança** — é dívida técnica com risco de crash; sinalize como tal, não como
vulnerabilidade.

**Backup.** `android:allowBackup="true"` é o padrão histórico e deixa o conteúdo do sandbox sair do
dispositivo. A partir da API 31 o controle correto é `android:dataExtractionRules`, que separa
**backup em nuvem** de **transferência device-to-device** — importa porque D2D copia dado mesmo com o
backup em nuvem desativado (`android:fullBackupContent` cobre API < 31).

```xml
<!-- res/xml/data_extraction_rules.xml, referenciado em <application android:dataExtractionRules=…> -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="sharedpref" path="auth.xml"/>
        <exclude domain="database" path="messages.db"/>
    </cloud-backup>
    <device-transfer>
        <exclude domain="sharedpref" path="auth.xml"/>
    </device-transfer>
</data-extraction-rules>
```

**Armazenamento externo e scoped storage.** Desde a API 29/30, o app tem acesso amplo apenas ao
próprio `getExternalFilesDir()`; `MANAGE_EXTERNAL_STORAGE` exige justificativa na Play Console. Ainda
assim, o que está lá é lido por quem tem o caminho (`MediaStore`, backup, cabo): PDF de fatura, foto
de documento e export de dado nunca ficam lá em texto claro.

**Log.** `Log.d(TAG, "token=$accessToken")` sobrevive em release, é lido por `adb logcat` e por
ferramenta de diagnóstico do OEM. R8 **não** remove log automaticamente — só com a regra:

```proguard
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
```

**Clipboard.** `ClipboardManager.setPrimaryClip` com senha/OTP é legível por qualquer app em foco.
Desde o Android 12 o sistema mostra um toast quando um app lê o clipboard, e desde o Android 13 você
pode marcar o conteúdo como sensível:

```kotlin
val clip = ClipData.newPlainText("otp", code).apply {
    description.extras = PersistableBundle().apply {
        putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)  // API 33+
    }
}
```

**Telas sensíveis.** `WindowManager.LayoutParams.FLAG_SECURE` bloqueia screenshot, gravação de tela e
a miniatura do multitarefas. Aplique em tela de login, de senha, de token e de dado de cartão.

### iOS

**Keychain** é o cofre. O parâmetro que mais erra é a classe de acessibilidade:

| Constante `kSecAttrAccessible…` | Legível quando | Sai do dispositivo? |
|---|---|---|
| `WhenUnlocked` | tela desbloqueada | **sim** — vai em backup e iCloud Keychain |
| `AfterFirstUnlock` | após o primeiro desbloqueio pós-boot | **sim** |
| `WhenPasscodeSetThisDeviceOnly` | desbloqueado, só se há passcode | não; some se o passcode for removido |
| `WhenUnlockedThisDeviceOnly` | tela desbloqueada | **não** |
| `AfterFirstUnlockThisDeviceOnly` | após o primeiro desbloqueio | **não** |
| `Always` / `AlwaysThisDeviceOnly` | sempre | depreciados desde iOS 12 — não use |

A diferença que importa: **sem o sufixo `ThisDeviceOnly`, o item é incluído em backup e migra para um
dispositivo novo**. Um refresh token com `kSecAttrAccessibleWhenUnlocked` restaurado num iPhone
comprado com o backup de outra pessoa continua valendo. Para credencial, o default deve ser
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Use `AfterFirstUnlockThisDeviceOnly` apenas quando o
app precisa do dado em background (push processing, sync) — o preço é que o dado fica acessível a um
ataque que rode com o dispositivo ligado e bloqueado.

**Vínculo com biometria** — o correto, e a razão pela qual `evaluatePolicy` sozinho não serve:

```swift
// ✅ o sistema só devolve o item se a biometria atual autenticar
var error: Unmanaged<CFError>?
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .biometryCurrentSet,     // invalida se o conjunto de biometrias mudar
    &error)!

let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "refresh_token",
    kSecValueData as String: token.data(using: .utf8)!,
    kSecAttrAccessControl as String: access
]
SecItemAdd(query as CFDictionary, nil)
```

Flags de `SecAccessControlCreateFlags`: `.userPresence` (biometria ou passcode), `.biometryAny`,
`.biometryCurrentSet`, `.devicePasscode`, `.applicationPassword` (uma senha do app entra na derivação
da chave), `.privateKeyUsage` (para chave do Secure Enclave), combináveis com `.or`/`.and`.

**Data Protection** para arquivos: `NSFileProtectionComplete` (ilegível com o dispositivo bloqueado),
`CompleteUnlessOpen`, `CompleteUntilFirstUserAuthentication` (o **default**), `None`. O default
significa que, num dispositivo ligado e bloqueado, os arquivos do app já estão decifráveis. Para
banco de dados de mensagens ou documentos, suba para `Complete`:

```swift
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.complete], ofItemAtPath: dbPath)
```

**Secure Enclave**: chave EC P-256 gerada com `kSecAttrTokenIDSecureEnclave` nunca sai do chip; serve
para assinar (device binding, App Attest) e para envelopar chaves simétricas — não para cifra
simétrica direta.

**`NSUserDefaults`** é um plist em texto claro em `Library/Preferences/`. Vai para o backup. Serve
para preferência de tema, não para token. Erro clássico: guardar `isPremium` ou `hasCompletedKYC`
ali — além de vazar, é editável no dispositivo.

**Snapshot ao ir para background.** O iOS fotografa a tela para a animação do app switcher e grava a
imagem em `Library/Caches/Snapshots/`. Tela de extrato ou de cartão vaza inteira. Mitigação:

```swift
func sceneWillResignActive(_ scene: UIScene) {
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    blur.frame = window!.bounds; blur.tag = 9999
    window?.addSubview(blur)
}
func sceneDidBecomeActive(_ scene: UIScene) {
    window?.viewWithTag(9999)?.removeFromSuperview()
}
```
Em SwiftUI, `.privacySensitive()` + `redacted(reason: .privacy)` cobre o caso comum.

**Pasteboard universal.** `UIPasteboard.general` sincroniza entre dispositivos do mesmo Apple ID via
Handoff. Copiar um OTP ou uma senha manda o valor para o Mac do usuário — e para qualquer app aberto
lá. Para conteúdo sensível:

```swift
UIPasteboard.general.setItems(
    [[UTType.plainText.identifier: code]],
    options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(60)])
```

### Caches que ninguém lembra de olhar

| Onde | O que costuma vazar | Como checar |
|---|---|---|
| Cache do WebView | resposta JSON com PII, cookie, HTML de página autenticada | Android: `app_webview/`; iOS: `Library/Caches/WebKit/` |
| `URLCache` / OkHttp cache | corpo de resposta autenticada em disco | procurar `Cache-Control` ausente no servidor |
| Cache de imagem (Glide, Coil, SDWebImage, Kingfisher) | foto de documento, comprovante, avatar privado | diretório de cache do app |
| SQLite/Realm de terceiro (analytics, chat SDK) | evento com PII, mensagem | `find . -name '*.db' -o -name '*.realm'` no dump |
| Crash reporter (Crashlytics, Sentry) | valor de variável em breadcrumb, URL com token no path | revisar `beforeSend`/scrubbing |
| WAL/journal do SQLite | linha "apagada" ainda legível | `.db-wal`, `.db-shm` |
| Autofill / keyboard cache | texto digitado em campo não marcado como senha | `isSecureTextEntry` / `inputType="textPassword"` |

Regra: se o servidor manda `Cache-Control: no-store` nas respostas autenticadas, metade desses
problemas some sozinha.

---

## Comunicação de rede

TLS em tudo, sem exceção "só para o endpoint de configuração". Um único `http://` no app é o ponto
onde um atacante em Wi-Fi hostil injeta resposta.

### Android — Network Security Config

Desde a API 28 (Android 9), **cleartext é bloqueado por padrão**; antes disso era permitido. E desde
a **API 24 (Android 7)** o app **não confia mais em CA instalada pelo usuário** por padrão — essa é
exatamente a razão de você precisar de configuração extra para interceptar tráfego em teste.

```xml
<!-- res/xml/network_security_config.xml -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors><certificates src="system"/></trust-anchors>
    </base-config>

    <!-- ✅ CA de debug só entra em build debuggable; o Play rejeita release debuggable -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user"/>
            <certificates src="@raw/burp_ca"/>
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

```xml
<!-- AndroidManifest.xml -->
<application android:networkSecurityConfig="@xml/network_security_config"
             android:usesCleartextTraffic="false">
```

Sinais de problema numa revisão:

- `<certificates src="user"/>` dentro de `<base-config>` ou `<domain-config>` (fora de
  `debug-overrides`) — o app aceita qualquer CA que o usuário instalar, em produção.
- `cleartextTrafficPermitted="true"` em qualquer domínio que não seja `localhost`/rede de teste.
- `android:usesCleartextTraffic="true"` no manifest.
- Um `TrustManager` custom que aceita tudo — o padrão mais perigoso e ainda comum em código copiado
  de Stack Overflow:

```java
// ❌ desliga toda a validação de certificado; MITM trivial
new X509TrustManager() {
    public void checkServerTrusted(X509Certificate[] c, String a) {}
    public void checkClientTrusted(X509Certificate[] c, String a) {}
    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
}
// ❌ e o gêmeo
HttpsURLConnection.setDefaultHostnameVerifier((h, s) -> true);
```

`grep -rn "checkServerTrusted\|ALLOW_ALL_HOSTNAME_VERIFIER\|setHostnameVerifier\|TrustAllCerts"`. O
Google Play bloqueia publicação de apps com `TrustManager` inseguro detectado, mas o bloqueio é
baseado em padrões conhecidos e contornável — não confie nele como controle.

### iOS — App Transport Security

ATS é ligado por padrão desde o iOS 9 e exige HTTPS com **TLS 1.2+**, cifras com forward secrecy e
certificado com SHA-256/RSA-2048 ou ECC-256.

```xml
<!-- ❌ o achado mais comum em Info.plist -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key><true/>
</dict>
```

Chaves relevantes: `NSAllowsArbitraryLoads` (desliga ATS globalmente),
`NSAllowsArbitraryLoadsInWebContent` (exceção só para WebView — muito menos ruim, e a exceção
legítima mais comum), `NSAllowsLocalNetworking` (rede local, aceitável),
`NSExceptionDomains` com `NSExceptionAllowsInsecureHTTPLoads`, `NSExceptionMinimumTLSVersion`,
`NSExceptionRequiresForwardSecrecy`, `NSIncludesSubdomains`.

O padrão real que você vai encontrar: alguém ligou `NSAllowsArbitraryLoads` em 2018 para um endpoint
de sandbox e nunca removeu. A correção quase sempre é trocar por uma `NSExceptionDomains` do domínio
específico, ou por `NSAllowsArbitraryLoadsInWebContent` se o problema era conteúdo de terceiro no
WebView. Note que quando `NSAllowsArbitraryLoads` é `true`, as chaves
`NSAllowsArbitraryLoadsInWebContent`/`InMedia` passam a *reativar* ATS nesses contextos.

---

## Certificate pinning: quando vale

Pinning amarra a conexão a uma chave pública específica, e não a "qualquer CA confiável". Ele protege
contra: CA comprometida ou coagida, MITM corporativo com CA instalada no dispositivo, e — o caso
prático mais frequente — **usuário que instalou um proxy para inspecionar/modificar o tráfego do
próprio app** (fraude, cheat, script de automação).

Como fazer:

```xml
<!-- Android, declarativo -->
<domain-config>
    <domain includeSubdomains="true">api.exemplo.com.br</domain>
    <pin-set expiration="2027-06-01">
        <pin digest="SHA-256">7HIpactkIAq2Y49orFOOQKurWxmmSFZhBCoQYcRhJ3Y=</pin>
        <pin digest="SHA-256">fwza0LRMXouZHRC8Ei+4PyuldPDcf3UKgO/04cDM1oE=</pin> <!-- backup -->
    </pin-set>
</domain-config>
```

```kotlin
// Android, OkHttp
val pinner = CertificatePinner.Builder()
    .add("api.exemplo.com.br", "sha256/7HIpactkIAq2Y49orFOOQKurWxmmSFZhBCoQYcRhJ3Y=")
    .add("api.exemplo.com.br", "sha256/fwza0LRMXouZHRC8Ei+4PyuldPDcf3UKgO/04cDM1oE=")
    .build()
OkHttpClient.Builder().certificatePinner(pinner).build()
```

No iOS: `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` comparando o SPKI hash da
cadeia, ou TrustKit. **Nunca** implemente comparando o certificado inteiro (`SecCertificateCopyData`
== bytes esperados): quebra a cada renovação. Pine o **SPKI** (hash da chave pública), que sobrevive à
renovação se você mantiver a chave.

Custo operacional — a parte que times subestimam:

- Um pin errado ou expirado **briga o app inteiro** para todos os usuários instalados, e a correção
  exige release + review + adoção. Não há rollback do lado do servidor.
- Exige **pin de backup** (a chave da próxima rotação, gerada com antecedência e guardada offline) e
  um processo de rotação documentado. Sem backup pin, um incidente na CA vira incidente no app.
- `expiration` no `pin-set` do Android é uma faca de dois gumes: evita brick de usuários que não
  atualizam, mas significa que depois da data o pinning simplesmente não existe mais.
- Quebra proxy corporativo legítimo e ferramenta de suporte interna.

Honestamente: **para a maioria dos apps, pinning não vale.** Se o valor está no servidor e o servidor
autoriza corretamente, um MITM com CA do usuário não dá ao atacante nada que ele já não tenha (é o
tráfego dele). Pinning vale quando: app financeiro/pagamento, app de saúde, app com incentivo de
fraude (cupom, pontos, jogo com economia), ou requisito regulatório/contratual. Nesses casos, faça
com pin de backup, monitoramento de falha de pinning no telemetry e um kill switch de servidor.

E lembre: **pinning não impede engenharia reversa.** Frida com `objection` desliga em segundos num
dispositivo controlado. O que pinning faz é elevar o custo do atacante casual e bloquear ataque em
escala via CA — não parar um pesquisador.

---

## Superfície de plataforma: Android

### Componentes exportados

Desde a **API 31 (Android 12)**, todo `activity`/`service`/`receiver` com `intent-filter` **precisa**
declarar `android:exported` — o build falha se não declarar. Isso matou o bug "exportado por acidente"
e criou outro: dev com pressa escreve `android:exported="true"` para o build passar. Desde a **API 34
(Android 14)**, `registerReceiver` para broadcasts não-sistema exige `RECEIVER_EXPORTED` ou
`RECEIVER_NOT_EXPORTED` explícito.

```xml
<!-- ❌ activity interna acessível por qualquer app instalado -->
<activity android:name=".TransferActivity" android:exported="true">
    <intent-filter><action android:name="com.exemplo.TRANSFER"/></intent-filter>
</activity>

<!-- ✅ se precisa mesmo ser exportado, proteja com permissão de assinatura -->
<permission android:name="com.exemplo.permission.INTERNAL"
            android:protectionLevel="signature"/>
<activity android:name=".TransferActivity" android:exported="true"
          android:permission="com.exemplo.permission.INTERNAL"/>
```

Checagem no APK: `apktool d app.apk && grep -n 'exported="true"' AndroidManifest.xml`. Para cada
componente exportado, pergunte: o que acontece se um app sem permissão nenhuma mandar essa Intent com
extras arbitrários?

### Intent implícita e intent redirection

Enviar dado sensível numa Intent implícita entrega o dado a quem registrar o filtro:

```kotlin
// ❌ qualquer app que declare esse action recebe o token
startActivity(Intent("com.exemplo.SYNC").putExtra("token", accessToken))

// ✅ explícita: só o componente nomeado recebe
startActivity(Intent(this, SyncActivity::class.java).putExtra("token", accessToken))
```

**Intent redirection** é a variante grave: o app recebe uma Intent de fora, extrai uma Intent aninhada
dos extras e a executa com os próprios privilégios. O atacante usa isso para abrir componentes não
exportados do seu app ou para conseguir `grantUriPermission` sobre arquivos internos.

```kotlin
// ❌ proxy confuso — executa Intent controlada pelo atacante no contexto do app
val next = intent.getParcelableExtra<Intent>("forward")
startActivity(next)

// ✅ valide destino antes de repassar
val next = intent.getParcelableExtra<Intent>("forward") ?: return
val ok = next.resolveActivity(packageManager)?.packageName == packageName
        && next.component?.className in ALLOWED_TARGETS
if (ok) startActivity(next)
```

O **Android 16 (API 36)** passou a bloquear por padrão boa parte dos casos de intent redirection no
lançamento de componentes; existe um opt-out, `Intent.removeLaunchSecurityProtection()`, cuja
presença no código é por si só um sinal de revisão. Isso não isenta a validação: o app precisa rodar
em versões anteriores.

### PendingIntent mutável

Um `PendingIntent` executa com a identidade do seu app. Se ele for **mutável** e a Intent base estiver
vazia (sem componente/ação), quem recebe o objeto pode preencher os campos e fazer o seu app executar
uma ação arbitrária — inclusive acessar `ContentProvider` interno.

```kotlin
// ❌ base "em branco" + mutável = o receptor decide o destino
PendingIntent.getActivity(ctx, 0, Intent(), PendingIntent.FLAG_UPDATE_CURRENT)

// ✅ imutável, com componente explícito
PendingIntent.getActivity(ctx, 0,
    Intent(ctx, DetailActivity::class.java).putExtra("id", id),
    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
```

Apps que **targetam a API 31+** são obrigados a passar `FLAG_IMMUTABLE` ou `FLAG_MUTABLE`; omitir
lança `IllegalArgumentException`. `FLAG_MUTABLE` é legítimo em poucos casos (inline reply de
notificação, bubbles) — sempre com componente explícito na Intent base.
`grep -rn "FLAG_MUTABLE"` e revise cada ocorrência.

### Deep links e App Links

`scheme://` custom (`meuapp://reset-password?token=…`) **não é verificado**: qualquer app pode
declarar o mesmo scheme. Se o seu fluxo de OAuth ou de reset de senha entrega um segredo por custom
scheme, esse segredo é roubável. **App Links** resolvem: `android:autoVerify="true"` + `https://` +
`https://seudominio/.well-known/assetlinks.json` com o package e o SHA-256 do certificado de
assinatura — o sistema verifica na instalação e só o seu app abre aquele link.

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="app.exemplo.com.br"/>
</intent-filter>
```

Se a verificação falhar (arquivo ausente, fingerprint errado, redirect no `.well-known`), a partir do
Android 12 os links **não** abrem no app — caem no navegador, e o usuário tem de habilitar à mão em
Configurações. Diagnóstico: `adb shell pm get-app-links <package>` e
`adb shell pm verify-app-links --re-verify <package>`.

Verificado ou não: **todo parâmetro de deep link é input não confiável.** Allowlist de host, e nunca
deixe um deep link executar ação com efeito colateral sem confirmação — um
`meuapp://transfer?to=X&amount=Y` que executa direto é CSRF mobile.

### ContentProvider

```xml
<!-- ❌ leitura e escrita para qualquer app -->
<provider android:name=".DataProvider" android:authorities="com.exemplo.data"
          android:exported="true"/>
```

Se o provider precisa ser exportado, use `android:readPermission`/`writePermission` com
`protectionLevel="signature"`, ou `android:grantUriPermissions="true"` com `<path-permission>`
restrito e `FLAG_GRANT_READ_URI_PERMISSION` por Intent.

Path traversal em `openFile` é o bug clássico de `FileProvider` mal usado:

```kotlin
// ❌ ../../ escapa do diretório e serve shared_prefs/auth.xml
override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
    val f = File(context.filesDir, "public/" + uri.lastPathSegment)
    return ParcelFileDescriptor.open(f, MODE_READ_ONLY)
}

// ✅ canonicalize e confine
val base = File(context.filesDir, "public").canonicalFile
val f = File(base, uri.lastPathSegment ?: "").canonicalFile
require(f.path.startsWith(base.path + File.separator))
```

Injeção SQL em provider é real também: `query()` que concatena `selection` recebido do chamador. Veja
`references/injecao.md`.

### WebView

O WebView é onde o Android se parece mais com a web — e onde XSS deixa de ser XSS e vira acesso
nativo. Configuração perigosa:

```kotlin
// ❌ combinação que transforma XSS em leitura do sandbox
webView.settings.apply {
    javaScriptEnabled = true
    allowFileAccess = true
    allowFileAccessFromFileURLs = true
    allowUniversalAccessFromFileURLs = true   // file:// lê qualquer origem, inclusive https
}
webView.addJavascriptInterface(NativeBridge(), "Android")
webView.loadUrl(intent.getStringExtra("url")!!)   // URL vinda de fora
```

Fatos que decidem a severidade:

- `addJavascriptInterface` **antes da API 17** expunha todos os métodos públicos do objeto, incluindo
  `getClass()` — reflexão até `Runtime.getRuntime().exec()`, ou seja, RCE (CVE-2012-6636). Da API 17
  em diante só métodos anotados com `@JavascriptInterface` são expostos, mas o método exposto continua
  sendo código nativo chamado por JS. Se o método faz `readFile(path)`, `getToken()` ou
  `openDeepLink(url)`, um XSS na página é game over.
- `setAllowUniversalAccessFromFileURLs(true)` permite que uma página `file://` faça XHR para
  `https://api.exemplo.com` **com os cookies** e leia a resposta. Combinado com download de HTML
  arbitrário para o sandbox, é exfiltração completa. Default é `false` desde a API 16 — se está
  `true`, alguém ligou de propósito.
- `setAllowFileAccess` tem default `true` até a API 29 e `false` a partir da 30. Para carregar assets
  locais, use `WebViewAssetLoader` (serve arquivos sob `https://appassets.androidplatform.net/`) em
  vez de `file://`.
- `shouldOverrideUrlLoading` sem allowlist deixa o WebView navegar para qualquer domínio, herdando
  a ponte JS. Sempre valide host:

```kotlin
override fun shouldOverrideUrlLoading(v: WebView, req: WebResourceRequest): Boolean {
    val host = req.url.host ?: return true
    return if (host == "app.exemplo.com.br" || host.endsWith(".exemplo.com.br")) false
           else { startActivity(Intent(Intent.ACTION_VIEW, req.url)); true }  // abre no browser
}
```

- **Carregar URL vinda de Intent** (`loadUrl(intent.getStringExtra("url"))`) num WebView exportado é
  o bug de WebView mais reportado em bug bounty Android. Vira "qualquer app abre qualquer página no
  contexto do seu WebView, com a sua ponte JS e a sua sessão".
- `setSafeBrowsingEnabled(true)` é o default desde a API 26; não desligue.
- Cookies: `CookieManager` do WebView é separado do `OkHttp`; sessão compartilhada entre WebView e
  nativo é uma decisão de risco, não um detalhe.

Cross-link: as defesas de conteúdo (CSP, sanitização, `srcdoc`, `postMessage` com verificação de
origem) estão em `references/xss-e-navegador.md`.

### `debuggable`, overlay e permissões

- `android:debuggable="true"` em release permite `run-as`/`jdb` em qualquer dispositivo e leitura
  completa do sandbox. O Play rejeita, mas APK distribuído fora da loja não passa por isso.
  `grep -n 'debuggable' AndroidManifest.xml`.
- **Tapjacking**: uma janela `TYPE_APPLICATION_OVERLAY` de outro app sobre a sua tela captura toques
  ou engana o usuário. Defesa: `android:filterTouchesWhenObscured="true"` na view sensível (ou
  `View.setFilterTouchesWhenObscured(true)`), e checar `MotionEvent.FLAG_WINDOW_IS_OBSCURED`. A partir
  do Android 12 o sistema já bloqueia toques em diálogos do sistema sobrepostos; para o seu app é sua
  responsabilidade. O Play Integrity expõe `appAccessRiskVerdict` com `KNOWN_OVERLAYS`/`UNKNOWN_OVERLAYS`
  para detectar o cenário no servidor.
- **Permissões**: revise `uses-permission` contra o que o app realmente faz. `READ_SMS` "para ler o
  OTP" é sinal de que o app deveria usar SMS Retriever API (que entrega só a mensagem do seu hash) em
  vez de ler a caixa inteira. `QUERY_ALL_PACKAGES` exige justificativa na Play Console e costuma ser
  usado por SDK de antifraude — saiba qual.
- **Componentes de terceiros no manifest**: SDKs de analytics/ads injetam activities, providers e
  receivers via manifest merger. Depois do build, leia o `AndroidManifest.xml` **do APK final**, não o
  do módulo `app`. É lá que aparece o provider exportado que você não escreveu. Veja
  `references/supply-chain-e-cicd.md`.

---

## Superfície de plataforma: iOS

### URL schemes vs Universal Links

`CFBundleURLSchemes` com `meuapp://` tem exatamente o mesmo problema do Android: **não há
verificação de propriedade**. Qualquer app pode registrar `meuapp://`; no iOS, quando dois apps
registram o mesmo scheme, o comportamento de qual ganha é indefinido — historicamente foi o instalado
primeiro. Um segredo entregue por custom scheme (código de autorização OAuth, magic link) é roubável
por um app instalado no dispositivo.

**Universal Links** são a forma verificada: `https://app.exemplo.com.br/...` + um
`apple-app-site-association` (AASA) servido em `https://app.exemplo.com.br/.well-known/apple-app-site-association`,
com `Content-Type: application/json`, **sem redirect** e **sem extensão `.json`** no caminho, mais o
entitlement `com.apple.developer.associated-domains` = `applinks:app.exemplo.com.br`.

Falhas comuns no AASA: servido atrás de CDN que responde 302; `appID` com o Team ID errado; app
instalado antes de o arquivo existir (o iOS cacheia — teste com reinstalação).

`LSApplicationQueriesSchemes` no `Info.plist` lista os schemes que o app pode consultar com
`canOpenURL`. É um vazamento de privacidade menor (revela quais apps você procura) e um sinal útil na
revisão: uma lista longa costuma indicar SDK de fingerprinting.

Em qualquer caso, `application(_:open:options:)` e `scene(_:continue:)` recebem input não confiável.
Valide host, path e parâmetros; nunca execute ação com efeito colateral direto.

### WebView

`UIWebView` está morto: a Apple parou de aceitar apps novos com ele em abril de 2020 e atualizações
em dezembro de 2020. Se aparecer numa base legada, é achado — ele roda JS no processo do app com um
motor sem sandbox por processo. Use `WKWebView`.

Pontos de revisão do `WKWebView`:

- `WKScriptMessageHandler` é a ponte JS↔nativo. `userContentController.add(self, name: "native")`
  expõe `window.webkit.messageHandlers.native.postMessage(x)` a **qualquer** página carregada. Valide
  o `message.frameInfo.securityOrigin` antes de agir, e nunca exponha um handler genérico do tipo
  `{ "action": "...", "args": [...] }`.
- `WKWebpagePreferences.allowsContentJavaScript` / `configuration.preferences.javaScriptEnabled`
  (depreciado): desligue JS se a WebView só renderiza HTML estático.
- `webView.configuration.websiteDataStore = .nonPersistent()` para conteúdo autenticado — evita cache
  e cookie em disco.
- `decidePolicyFor navigationAction`: allowlist de host, igual ao Android.
- `loadHTMLString(_:baseURL:)` com `baseURL` apontando para um domínio seu dá à string HTML a origem
  daquele domínio. Se a string vem de servidor, é XSS com origem privilegiada.

### App Groups, Keychain sharing e extensões

`com.apple.security.application-groups` cria um contêiner compartilhado entre o app e suas extensões
(widget, share extension, Notification Service). O que entra ali é legível por **todos** os targets do
grupo — e, se você publicar mais de um app no mesmo grupo, por todos eles. `keychain-access-groups`
faz o mesmo para o Keychain. Revise: o widget precisa mesmo do refresh token, ou bastaria um token de
leitura de escopo reduzido?

Extensões rodam em processos separados com entitlements próprios; uma Notification Service Extension
que desencripta payload precisa da chave — e portanto precisa da chave num lugar acessível **com o
dispositivo bloqueado** (`AfterFirstUnlockThisDeviceOnly`), o que é um trade-off consciente, não um
detalhe.

### Teclado de terceiros, pasteboard, entitlements

- Teclado de terceiro (`RequestsOpenAccess`) vê tudo que o usuário digita, exceto campos com
  `isSecureTextEntry = true`. Marque campos de senha/PIN/cartão. Para bloquear teclados customizados
  no app inteiro, implemente `application(_:shouldAllowExtensionPointIdentifier:)` retornando `false`
  para `.keyboard`.
- `textContentType` correto (`.oneTimeCode`, `.password`) melhora UX e evita autofill errado.
- Revise o arquivo `.entitlements`: `get-task-allow` deve ser `false` em release (se `true`, o app
  aceita debugger — equivalente ao `debuggable` do Android);
  `com.apple.developer.associated-domains` deve listar só os domínios seus.

### Biometria: por que `evaluatePolicy` sozinho não vale

```swift
// ❌ decisão booleana dentro do processo do app — hookável em 3 linhas de Frida
context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                       localizedReason: "Entrar") { success, _ in
    if success { self.unlockWithToken(self.storedToken) }   // token já estava em memória
}
```

O atacante com o dispositivo em mãos (jailbroken, ou com o app repackageado) intercepta o callback e
força `success = true`. O token estava acessível o tempo todo — a biometria só decorou a tela.

```swift
// ✅ a biometria é pré-requisito criptográfico: sem ela o Keychain não devolve o item
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrAccount as String: "refresh_token",
    kSecReturnData as String: true,
    kSecUseOperationPrompt as String: "Autentique para entrar"
]
var out: CFTypeRef?
let status = SecItemCopyMatching(query as CFDictionary, &out)
// item gravado com SecAccessControl(.biometryCurrentSet): o SO exige a biometria aqui
```

Regra equivalente no Android: `BiometricPrompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))`
com uma chave criada com `setUserAuthenticationRequired(true)`. Sem `CryptoObject`, é o mesmo teatro.

E, em ambos: autenticação **local** só desbloqueia um segredo local. Ela nunca substitui autenticação
no servidor. O servidor precisa continuar validando o token que o app apresenta.

---

## Cross-platform

### React Native

**O bundle JS é o app.** Num APK, `unzip -l app.apk | grep bundle` mostra
`assets/index.android.bundle`; no iOS, `main.jsbundle` dentro do `.app`.

- **Sem Hermes**: JavaScript minificado em texto claro. `strings` já resolve; um prettier deixa
  legível. Toda constante, todo endpoint, toda flag de feature, toda chave.
- **Com Hermes** (default desde o React Native 0.70): bytecode HBC. Não é proteção — é atrito. A
  tabela de strings continua extraível (`strings index.android.bundle | grep -i 'api\|key\|secret'`),
  e existem disassembler/decompiler: `hermes-dec` (P1 Security: `hbc-file-parser`, `hbc-disassembler`,
  `hbc-decompiler`) e `hbctool` (suporta até HBC v85, defasado frente às versões atuais). Conclusão
  prática: Hermes muda o esforço de 5 minutos para uma hora. Não muda a conclusão de que segredo em
  bundle é público.

Pontos de revisão específicos:

```ts
// ❌ AsyncStorage não é cifrado — é um SQLite (RKStorage) no Android e um arquivo no iOS
await AsyncStorage.setItem('refreshToken', token)

// ✅ Keychain/Keystore com biometria
import * as Keychain from 'react-native-keychain'
await Keychain.setGenericPassword('user', refreshToken, {
  service: 'com.exemplo.auth',
  accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_CURRENT_SET,
  securityLevel: Keychain.SECURITY_LEVEL.SECURE_HARDWARE,
  storage: Keychain.STORAGE_TYPE.RSA,
})
```

No Expo, o equivalente é `expo-secure-store` com
`{ keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY, requireAuthentication: true }`.

### Transaction signing: quando guardar o token direito ainda não basta

Vincular a chave à biometria resolve *"quem destranca o cofre"*. Não resolve *"o servidor tem
como saber que esta transferência específica foi autorizada por esta pessoa neste aparelho"* — e
essa é a pergunta que importa quando há dinheiro. Um token no header prova sessão, não intenção:
qualquer código rodando no app (ou o atacante que capturou o token) reusa o mesmo header para
qualquer valor e qualquer destinatário.

O padrão que fecha isso é **assinar a transação, não a sessão**:

1. O app pede ao servidor um **desafio** vinculado à operação: `{ nonce, valor, destinatário, exp }`.
2. O app manda assinar com uma chave privada que **só existe em hardware** (Secure Enclave no iOS,
   StrongBox/TEE no Android) e que foi criada exigindo autenticação do usuário
   (`kSecAccessControlBiometryCurrentSet`, `setUserAuthenticationRequired(true)` +
   `setInvalidatedByBiometricEnrollment(true)`). O prompt biométrico é o que libera **o uso da
   chave** — não um `boolean` que o app decide acatar.
3. O servidor valida a assinatura contra a chave pública registrada no *enrollment* do dispositivo,
   confere que o desafio é o que ele emitiu, que não expirou e que não foi usado antes.

A propriedade que isso dá e que nenhuma checagem local dá: **o servidor rejeita a operação mesmo
que o app inteiro esteja comprometido**, porque a assinatura sobre aqueles valores não pode ser
produzida sem o gesto do usuário no hardware. É também o que transforma um "aprovei" em prova
oponível depois (não repúdio), o que costuma ser exigência regulatória em pagamento.

Vale a pena para operação sensível — transferência acima de um limite, cadastro de beneficiário,
troca de chave Pix, alteração de limite. Não vale para abrir a tela de saldo: o custo de UX é real
e gastar o gesto biométrico em tudo treina o usuário a aprovar sem ler.

Quando a operação vier do cliente sem esse vínculo, a checagem de limite **precisa** existir no
servidor de qualquer forma — veja `references/autorizacao-e-logica-de-negocio.md` para o lado da
API, incluindo por que "o app não deixa passar de R$ 5.000" nunca é um controle.

- **Access token em memória, refresh token no cofre.** O access token de vida curta não precisa
  tocar disco; guarde num módulo/estado e recarregue via refresh no cold start.
- **`__DEV__` e código de debug**: `if (__DEV__)` é eliminado no bundle de release pelo Metro, mas
  `console.log` **não** é removido por padrão — adicione `transform-remove-console` ao
  `babel.config.js` para produção. Reactotron, Flipper e devtools não podem entrar em release.
- **Variáveis de ambiente**: `react-native-config`, `react-native-dotenv` e `process.env.X` inlinado
  pelo Metro colocam o valor **dentro do bundle**. `EXPO_PUBLIC_*` é público por definição. Não existe
  "env secreta no cliente".
- **Deep links no JS**: `Linking.getInitialURL()` e `Linking.addEventListener('url', …)`, ou a config
  `linking` do React Navigation. Os parâmetros vêm de fora do app — trate como query string hostil,
  com validação de host e de esquema, antes de navegar ou de disparar mutação.
- **A ponte nativa**: `NativeModules` / TurboModules expõem métodos nativos ao JS. Se você escreveu um
  módulo nativo que recebe um path, uma URL ou um SQL do JS, ele é um sink. Revise igual a
  `addJavascriptInterface`.
- **Over-the-air update** é a superfície mais subestimada do React Native: quem controla o canal de
  update controla o código do app. O CodePush hospedado pela Microsoft foi **descontinuado junto com o
  App Center em 31 de março de 2025**; sobraram o `microsoft/code-push-server` self-hosted e o
  **EAS Update** da Expo. Um servidor de update self-hosted **sem assinatura** significa que
  comprometer aquele servidor (ou o bucket S3 atrás dele) injeta JS arbitrário em todos os
  dispositivos. Use assinatura fim a fim: no EAS Update, `codeSigningCertificate` (X.509 PEM com EKU
  de code signing) + `codeSigningMetadata` com `alg: "rsa-v1_5-sha256"`; a chave privada assina
  localmente e o cliente verifica antes de aplicar o update. Sem code signing, o canal de OTA é uma
  backdoor com SLA.

### Flutter

- O código Dart é compilado **AOT para código de máquina** dentro de `libapp.so` (Android) /
  `App.framework` (iOS), com um formato de snapshot próprio. Não há bytecode legível como no RN, e
  jadx não ajuda. A engenharia reversa passa por Ghidra/IDA com scripts de parsing de snapshot, ou
  pelo **reFlutter**, que recompila o engine com hooks e reempacota o app.
- **`flutter_secure_storage`** é o wrapper correto (Keystore/Keychain). Cheque as opções: no Android,
  `EncryptedSharedPreferences` era o backend padrão (ver a nota de depreciação acima); no iOS,
  `IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device)` — o default nem sempre é
  `ThisDeviceOnly`.
- **Interceptação de tráfego**: o Dart usa a própria stack de sockets e **ignora o proxy configurado
  no sistema** — `Socket.connect()` direto, sem consultar as configurações de proxy do Android/iOS.
  Consequência prática em teste: seu Burp fica vazio e você conclui erradamente que "não há tráfego".
  As saídas são (a) redirecionar no kernel com `iptables`/`pf`, (b) `HttpOverrides.global` numa build
  de teste, (c) reFlutter, (d) Frida hookando `ssl_verify_peer_cert` no BoringSSL embutido no
  `libflutter.so`. Os procedimentos estão em `MASTG-TECH-0109` (Android) e `MASTG-TECH-0110` (iOS).
- Flutter também não usa o Network Security Config nem o ATS para o tráfego do engine — a política de
  cleartext e as trust anchors do sistema não se aplicam da forma esperada. Verifique no código Dart
  (`badCertificateCallback` retornando `true` é o equivalente de `TrustAllCerts`).

### Capacitor / Cordova / Ionic

Aqui a fronteira entre web e nativo praticamente não existe: a UI inteira é um WebView com **plugins
nativos expostos ao JavaScript**. Portanto:

**XSS num app híbrido não é "roubo de sessão" — é acesso ao dispositivo.** Um `innerHTML` com dado do
servidor, num app com os plugins de Filesystem, Camera, Contacts e Geolocation instalados, dá ao
atacante leitura do sistema de arquivos, câmera e contatos. É a diferença de severidade que justifica
tratar XSS em híbrido como crítico por padrão. Mecânica e defesas de XSS: `references/xss-e-navegador.md`.

Revisão de configuração:

```ts
// capacitor.config.ts
const config: CapacitorConfig = {
  server: {
    androidScheme: 'https',         // ✅ evita origem file://
    // ❌ cleartext: true            — permite http no WebView
    // ❌ url: 'http://192.168.0.10:3000'  — dev server esquecido em release
    allowNavigation: ['api.exemplo.com.br'],  // ✅ allowlist estreita; nunca ['*']
  },
  android: { allowMixedContent: false },
}
```

No Cordova, os equivalentes ficam no `config.xml`: `<allow-navigation href="...">` (para onde a
WebView pode navegar), `<allow-intent>` (o que pode ser aberto por outro app) e `<access origin>` do
whitelist plugin — `<allow-navigation href="*"/>` é achado imediato. Some a isso: `cordova-plugin-*`
abandonados são um problema de supply chain (`references/supply-chain-e-cicd.md`), e uma CSP
`<meta http-equiv="Content-Security-Policy">` estrita no `index.html` é a mitigação de maior retorno
nesse stack.

---

## Autenticação em mobile

### Onde guardar o quê

| Item | Onde | Por quê |
|---|---|---|
| Access token (curto, ≤15 min) | memória do processo | não precisa persistir; morre com o app |
| Refresh token | Keychain `WhenUnlockedThisDeviceOnly` + `.biometryCurrentSet` / Keystore com `CryptoObject` | é a credencial de longa vida — o alvo real |
| Chave de device binding | Secure Enclave / Keystore (não exportável) | prova de posse do dispositivo |
| Senha do usuário | **em lugar nenhum** | o app não precisa dela depois do login |
| "Lembrar de mim" | um refresh token, não a senha | revogável no servidor |

O refresh token precisa ser **rotacionado a cada uso com detecção de reuso** — se um token já
consumido reaparece, revogue a família inteira. Isso é lógica de servidor; veja
`references/autenticacao-e-sessao.md`.

### OAuth em app nativo: o desenho correto

App móvel é **cliente público** — não guarda `client_secret` (voltamos à premissa: qualquer segredo
embarcado é público). O padrão é RFC 8252 ("OAuth 2.0 for Native Apps") + **Authorization Code com
PKCE** (RFC 7636), obrigatório no OAuth 2.1.

- **iOS**: `ASWebAuthenticationSession` — abre um Safari fora do processo do app, compartilhando (ou
  não, com `prefersEphemeralWebBrowserSession = true`) os cookies do Safari. O app **não** vê o que é
  digitado.
- **Android**: **Custom Tabs** (`androidx.browser`), idealmente via AppAuth-Android.
- **React Native**: `expo-auth-session` ou `react-native-app-auth` — ambos usam os componentes acima.

**Por que WebView embutido para login é antipadrão**, concretamente:

1. O app hospedeiro pode ler o DOM, injetar JS e capturar usuário e senha — o usuário não tem como
   distinguir um app honesto de um phishing, porque não há barra de endereço confiável.
2. Não compartilha a sessão do navegador: quebra SSO e força login repetido.
3. Não tem acesso a passkeys/WebAuthn nem ao gerenciador de senhas do sistema.
4. Google, Microsoft e vários IdPs **bloqueiam ativamente** login por WebView embutido
   (`disallowed_useragent`) — então além de inseguro, quebra em produção.

### Roubo do código de autorização no redirect

Com `redirect_uri = meuapp://callback`, um app malicioso que registre `meuapp://` pode receber o
`code`. Duas correções, ambas necessárias:

1. **PKCE**: o `code` sozinho não vale nada sem o `code_verifier`, que nunca saiu do app legítimo.
   Use `code_challenge_method=S256` — `plain` não protege.
2. **App Links / Universal Links** como `redirect_uri` (`https://app.exemplo.com.br/callback`): o
   sistema verifica a propriedade do domínio, então nenhum outro app recebe o redirect.

Adicione o parâmetro `state` com valor aleatório e verifique na volta (CSRF do fluxo OAuth), e no
servidor exija `redirect_uri` exata por allowlist — redirect aberto no IdP anula tudo (veja
`references/ssrf-e-camada-http.md` para a mecânica de open redirect).

---

## Attestation e device binding

O objetivo é o servidor conseguir dizer: *esta requisição veio do meu app genuíno, não modificado,
rodando num dispositivo/SO íntegro*. Isso não é possível de dentro do app (a premissa!) — precisa de
uma raiz de confiança fora dele: o SO e o fabricante.

### Android: Play Integrity API

Substituiu o SafetyNet Attestation, que foi **totalmente desligado em 31 de janeiro de 2025** (o
onboarding de novos apps já havia encerrado em janeiro de 2023). Código que ainda chama SafetyNet
recebe erro — é achado de manutenção, não só de segurança.

O app pede um token; o servidor o desencripta/verifica (via API do Google, ou localmente com as chaves
da Play Console) e lê os veredictos:

| Campo | Valores | Leitura |
|---|---|---|
| `appIntegrity.appRecognitionVerdict` | `PLAY_RECOGNIZED`, `UNRECOGNIZED_VERSION`, `UNEVALUATED` | binário e certificado batem com o publicado na Play — pega repackaging |
| `deviceIntegrity.deviceRecognitionVerdict` | array: `MEETS_DEVICE_INTEGRITY`; opcionalmente `MEETS_BASIC_INTEGRITY`, `MEETS_STRONG_INTEGRITY`, `MEETS_VIRTUAL_INTEGRITY`; **vazio** = comprometido | array vazio é o sinal de root/emulador |
| `accountDetails.appLicensingVerdict` | `LICENSED`, `UNLICENSED`, `UNEVALUATED` | pega instalação pirata/sideload |
| `environmentDetails.appAccessRiskVerdict.appsDetected` | `KNOWN_CAPTURING`, `UNKNOWN_CAPTURING`, `KNOWN_CONTROLLING`, `UNKNOWN_CONTROLLING`, `KNOWN_OVERLAYS`, `UNKNOWN_OVERLAYS`, `KNOWN_INSTALLED`… | apps de captura de tela/acessibilidade/overlay ativos — sinal de fraude remota |
| `environmentDetails.playProtectVerdict` | `NO_ISSUES`, `NO_DATA`, `POSSIBLE_RISK`, `MEDIUM_RISK`, `HIGH_RISK`, `UNEVALUATED` | opt-in |

Dois modos de requisição: **standard** (baixa latência, resposta com cache do lado do Google, usa
`requestHash` que você fornece — o recomendado para chamadas frequentes) e **classic** (mais caro e
lento, usa `nonce`, sem `appAccessRisk`; reserve para ações raras e de alto valor). `appAccessRisk`
exige biblioteca 1.4.0+ e opt-in.

### iOS: App Attest e DeviceCheck

**App Attest** (iOS 14+): o app gera um par de chaves no **Secure Enclave**
(`DCAppAttestService.generateKey`), pede uma atestação (`attestKey:clientDataHash:`) que a Apple
assina, e o servidor valida a cadeia contra a raiz da Apple, conferindo o `appID` (`teamID.bundleID`),
o `counter` e o `receipt`. Depois disso, cada requisição sensível leva uma **assertion**
(`generateAssertion`) assinada por aquela chave, com um hash do corpo da requisição — o servidor
verifica assinatura e contador monotônico.

**DeviceCheck** é outra coisa: dois bits de estado por dispositivo, persistentes entre reinstalações.
Serve para "este dispositivo já usou o teste grátis", não para integridade.

### O que attestation prova (e o que não prova)

Prova, com verificação **no servidor**:

- que o binário é o que você publicou (assinatura/versão);
- que o SO e o dispositivo não estão obviamente comprometidos, segundo o fabricante;
- que a requisição está ligada a uma chave de hardware daquele dispositivo (device binding), se você
  amarrar o token/assertion à sessão.

Não prova, e é onde times se enganam:

- que o **usuário** é legítimo — attestation não é autenticação nem antifraude. Engenharia social,
  conta comprada, mula financeira e fraude com o dono do dispositivo colaborando passam com
  `MEETS_STRONG_INTEGRITY`.
- que a requisição veio do app **naquele momento** — se você não amarrar o token a um nonce/requestHash
  e a uma sessão, ele é replayável e "emprestável" (o atacante roda o app real num dispositivo limpo só
  para gerar tokens e usa em outro lugar).
- nada, se o veredicto for avaliado **dentro do app**. `if (!integrityOk) return;` no cliente é um
  `NOP`. O token tem de ir para o servidor e a decisão tem de acontecer lá.

Impacto operacional real: um percentual não trivial de usuários legítimos falha (dispositivo sem
Google Play, ROM de fabricante, Play Services desatualizado, dispositivo antigo, emulador de QA).
Bloquear duro por veredicto gera ticket de suporte em volume. O uso maduro é **sinal de risco
ponderado**: `deviceRecognitionVerdict` vazio + valor alto da transação → step-up authentication, não
bloqueio cego.

---

## Resiliência (MASVS-RESILIENCE) com honestidade

Tudo nesta seção é **atrito, não controle**. A pergunta certa não é "isso pode ser contornado?" (pode,
sempre), e sim "isso aumenta o custo do ataque acima do valor que o atacante extrai?".

| Técnica | O que faz | Como cai |
|---|---|---|
| Detecção de root/jailbreak | procura `su`, Magisk, `/Applications/Cydia.app`, montagem `rw` de `/system`, pacotes conhecidos | Magisk DenyList/Zygisk, Shamiko, hook do `File.exists` — minutos |
| Detecção de emulador | `Build.FINGERPRINT` com `generic`, ausência de sensores, `ro.kernel.qemu` | patch das props; emuladores "anti-detecção" comerciais |
| Anti-debug | `ptrace(PTRACE_TRACEME)`, `TracerPid` em `/proc/self/status`, `isDebuggerConnected`, `sysctl` P_TRACED no iOS | patch do binário; hook antes da checagem |
| Anti-hooking (Frida/objection) | procura porta 27042, string `frida-agent`, `/proc/self/maps`, thread `gum-js-loop` | `frida --no-pause` com script de evasão; gadget renomeado |
| Ofuscação (R8/ProGuard) | renomeia classes/métodos/campos, remove código morto | não é cifra: strings continuam legíveis, chamadas de framework mantêm nome, `-keep` expõe a superfície |
| Verificação de assinatura | compara o SHA-256 do certificado de assinatura em runtime | patch do comparador; resign com a mesma lógica |
| Detecção de repackaging | package name, instalador (`getInstallerPackageName`), checksum do DEX | tudo dentro do processo, tudo hookável |

Sobre **R8/ProGuard** especificamente, porque a expectativa costuma estar errada: ele faz *name
mangling* e *shrinking*. Ele **não** cifra strings, **não** achata fluxo de controle, **não** esconde
a estrutura do app e **não** protege o bundle JS de um app React Native. `-keep` em modelos de dados,
em classes de reflexão e em SDKs devolve nomes legíveis exatamente nos pontos mais interessantes.
Ligar `minifyEnabled true` é bom (reduz tamanho, remove código morto, dificulta leitura casual) — não é
uma medida de segurança na qual apoiar uma decisão.

Como fazer o pouco que funciona valer mais:

- **Nunca decida no cliente.** Detectou root? Mande o sinal para o servidor, junto com o token de
  attestation, e deixe o servidor decidir (step-up, limite de transação, monitoramento). Um
  `System.exit()` local é um `NOP` de uma instrução.
- **Múltiplas checagens, em lugares diferentes, com efeito tardio.** Uma checagem única num método
  chamado `isRooted()` é encontrada com `grep`. Isso vale contra fraude em escala (o script kiddie
  desiste), não contra um adversário dedicado.
- **Aceite o teto.** Contra um atacante com o dispositivo, tempo e Frida, MASVS-R não vence. Ele
  compra tempo e quebra automação em massa. Se o seu modelo de ameaça exige mais que isso, o problema
  é de arquitetura: mova a lógica valiosa para o servidor.

---

## Testar um app na prática

Tudo abaixo pressupõe **o seu próprio app, ou um alvo com autorização escrita**. Engenharia reversa e
interceptação de app de terceiro sem autorização violam ToS e, dependendo da jurisdição, a lei.

### Obter o binário

```bash
# Android — do próprio dispositivo, app que você instalou
adb shell pm list packages | grep exemplo
adb shell pm path com.exemplo.app          # pode devolver várias (split APKs / AAB)
adb pull /data/app/~~abc==/com.exemplo.app-1/base.apk
# split APKs: junte tudo antes de analisar (apkeditor / apktool sobre o conjunto)

# iOS — build de desenvolvimento, ou frida-ios-dump num dispositivo com jailbreak seu
unzip App.ipa -d ipa && ls ipa/Payload/App.app
```

### Inspeção estática

```bash
# visão geral automatizada (Android e iOS)
docker run -it --rm -p 8000:8000 opensecurity/mobile-security-framework-mobsf

# Android
apktool d base.apk -o out/                 # manifest e resources legíveis
jadx-gui base.apk                          # DEX -> Java aproximado
grep -nE 'exported="true"|debuggable|usesCleartextTraffic|allowBackup' out/AndroidManifest.xml
strings -n 8 out/classes.dex | grep -iE 'api[_-]?key|secret|password|bearer|AKIA|-----BEGIN'
unzip -l base.apk | grep -E 'bundle|\.so$'  # React Native / libs nativas

# iOS
plutil -p ipa/Payload/App.app/Info.plist | grep -iE 'ATS|Arbitrary|URLSchemes|Queries'
otool -l ipa/Payload/App.app/App | grep -A4 LC_ENCRYPTION_INFO   # binário cifrado?
class-dump -H ipa/Payload/App.app/App -o headers/                # Objective-C
nm -gU ipa/Payload/App.app/App | head                            # símbolos exportados
codesign -d --entitlements :- ipa/Payload/App.app                # entitlements
```

Para lógica nativa (`libapp.so` do Flutter, `.so` com criptografia própria), **Ghidra** ou IDA.

### Interceptar tráfego

1. Suba `mitmproxy`/Burp, configure o proxy no Wi-Fi do dispositivo e instale a CA.
2. **Android 7+ não confia em CA de usuário.** Opções, em ordem de preferência para teste:
   - Build de debug do app com `<debug-overrides><trust-anchors><certificates src="user"/>` —
     limpo e não exige root.
   - Emulador com imagem *Google APIs* (não Play Store) e a CA instalada no store do sistema. Note que
     a partir do **Android 14** o store de CAs do sistema é atualizável e vive em
     `/apex/com.android.conscrypt/cacerts` — o procedimento antigo de remontar `/system/etc/security/cacerts`
     não basta; use um módulo Magisk mantido ou o procedimento do MASTG.
3. **Pinning ativo** (o tráfego some, ou o app dá erro de rede): em teste autorizado,
   `objection -g com.exemplo.app explore` → `android sslpinning disable` (ou `ios sslpinning disable`),
   que hooka os pontos conhecidos de verificação. Alternativa: um script Frida que substitui
   `checkServerTrusted` / `SSL_CTX_set_custom_verify`.
4. **Flutter**: o tráfego não passa pelo proxy do sistema (o Dart abre socket direto). Redirecione com
   `iptables -t nat -A OUTPUT -p tcp --dport 443 -j DNAT --to-destination <ip-proxy>:8080`, ou use
   reFlutter, ou hook do `ssl_verify_peer_cert` no `libflutter.so`. Procedimentos:
   `MASTG-TECH-0109` (Android), `MASTG-TECH-0110` (iOS).
5. Tráfego que não é HTTP (gRPC sobre TLS, WebSocket, MQTT, socket bruto) precisa de proxy TCP
   genérico + Frida, não de Burp.

### Instrumentação dinâmica

```bash
frida-ps -Ua                                        # processos no dispositivo
objection -g com.exemplo.app explore
  android keystore list                             # chaves e se exigem auth
  android hooking list class_methods com.exemplo.auth.TokenStore
  android intent launch_activity com.exemplo.app/.TransferActivity   # testa exportado
  ios keychain dump
  ios nsuserdefaults get
  memory search --string "eyJhbGciOi"               # JWT vivo em memória
```

### Inspeção de armazenamento no dispositivo

```bash
# Android (dispositivo com root ou app debuggable)
adb shell run-as com.exemplo.app ls -laR /data/data/com.exemplo.app
adb shell run-as com.exemplo.app cat shared_prefs/*.xml
adb pull /data/data/com.exemplo.app/databases/app.db && sqlite3 app.db .dump

# procure em tudo que foi extraído
grep -rniE 'token|refresh|passw|cpf|jwt|eyJ' extraido/
```

No iOS, o caminho equivalente é o contêiner do app (`/var/mobile/Containers/Data/Application/<UUID>/`)
num dispositivo com jailbreak seu, ou um backup local sem cifra analisado com `iOSbackup`/`ideviceinfo`.

### No CI

```yaml
# GitHub Actions — análise estática de mobile no pipeline
- name: mobsfscan
  run: |
    pip install mobsfscan
    mobsfscan --sarif -o mobsfscan.sarif ./android ./ios || true
- name: semgrep (regras mobile)
  run: semgrep --config p/mobsf --config p/kotlin --config p/react-native --sarif -o semgrep.sarif .
- name: MobSF em modo API
  run: |
    curl -F "file=@app-release.apk" -H "Authorization: $MOBSF_KEY" \
         http://mobsf:8000/api/v1/upload
```

`mobsfscan` é o motor estático do MobSF em CLI (rápido, bom para PR); o MobSF completo, com upload do
APK/IPA gerado, é melhor como job noturno. Some a isso `gitleaks` no repositório (segredo commitado é
a origem mais comum de segredo embarcado) e SCA das dependências nativas e npm. Detalhes de
ferramental e integração: `references/ferramentas.md` e `references/supply-chain-e-cicd.md`.

---

## Sinais em revisão de código

### `AndroidManifest.xml`

| Procurar | Por que importa |
|---|---|
| `android:exported="true"` sem `android:permission` | IPC aberta a qualquer app |
| `android:debuggable="true"` | dump completo do sandbox via `run-as` |
| `android:allowBackup="true"` sem `dataExtractionRules` | dado sai do dispositivo |
| `android:usesCleartextTraffic="true"` | HTTP em produção |
| ausência de `android:networkSecurityConfig` | sem controle explícito de trust anchors |
| `<provider>` exportado, sem `grantUriPermissions` restrito | leitura/escrita do sandbox |
| `<data android:scheme="meuapp">` sem par `https` + `autoVerify` | deep link sequestrável |
| `QUERY_ALL_PACKAGES`, `READ_SMS`, `SYSTEM_ALERT_WINDOW` | permissão excessiva / risco de overlay |
| componentes que você não escreveu (manifest merger) | superfície vinda de SDK |

### `Info.plist` / `.entitlements`

| Procurar | Por que importa |
|---|---|
| `NSAllowsArbitraryLoads: true` | ATS desligado globalmente |
| `NSExceptionAllowsInsecureHTTPLoads` em domínio de produção | HTTP autorizado |
| `CFBundleURLSchemes` usado como `redirect_uri` de OAuth | código de autorização roubável |
| ausência de `com.apple.developer.associated-domains` com Universal Link em uso | AASA não configurado |
| `get-task-allow: true` em release | app aceita debugger |
| `UIFileSharingEnabled` / `LSSupportsOpeningDocumentsInPlace` | arquivos do app expostos via Finder/Arquivos |
| `NSCameraUsageDescription`… genéricos demais | sinal de permissão sem propósito claro |

### Kotlin / Java

```bash
grep -rnE 'checkServerTrusted|ALLOW_ALL_HOSTNAME|setHostnameVerifier|TrustAll' app/src/
grep -rnE 'addJavascriptInterface|setAllowUniversalAccessFromFileURLs|setAllowFileAccess\(true' app/src/
grep -rnE 'FLAG_MUTABLE|getParcelableExtra.*Intent' app/src/
grep -rnE 'Log\.(d|v|i)\(.*(token|password|secret)' app/src/
grep -rn  'MODE_WORLD_READABLE\|MODE_WORLD_WRITEABLE' app/src/     # depreciado, lança exceção desde API 24
grep -rnE 'SecretKeySpec\(|"AES/ECB|IvParameterSpec\(ByteArray\(' app/src/
```

### Swift / Objective-C

```bash
grep -rnE 'evaluatePolicy|LAContext' Sources/            # biometria sem vínculo de Keychain?
grep -rnE 'UserDefaults.standard.set\(.*(token|password)' Sources/
grep -rnE 'kSecAttrAccessible(Always|AfterFirstUnlock)\b' Sources/   # sem ThisDeviceOnly
grep -rn  'UIWebView' Sources/
grep -rnE 'loadHTMLString|allowsContentJavaScript|WKScriptMessageHandler' Sources/
grep -rn  'urlSession(_:didReceive:' Sources/            # pinning custom ou bypass de validação?
```

### TypeScript (React Native)

```bash
grep -rnE "AsyncStorage.setItem\(.*(token|secret|password)" src/
grep -rnE "process\.env\.[A-Z_]*(KEY|SECRET|TOKEN)" src/
grep -rn  "console\.log" src/ | wc -l                    # e checar transform-remove-console
grep -rnE "Linking.(getInitialURL|addEventListener)" src/  # validação do deep link
grep -rn  "dangerouslySetInnerHTML\|WebView" src/
grep -rnE "codePush|expo-updates" package.json           # canal OTA assinado?
```

---

## Falsos positivos comuns

- **Dado não sensível em `SharedPreferences`/`NSUserDefaults`.** Tema, idioma, "já viu o onboarding",
  contador de uso. Não é achado. Cheque *o que* está guardado antes de escrever o relatório.
- **`EncryptedSharedPreferences` no código.** Está depreciado, mas o dado *está* cifrado. É dívida
  técnica com risco de crash (keyset corruption, StrictMode), não vulnerabilidade.
- **Chave pública embarcada** (para pinning, para verificar assinatura de update, para cifrar payload
  destinado ao servidor). É pública por design. Só vira achado se for **privada**.
- **Certificado de teste / `debug-overrides` / `TrustAllCerts` dentro de `src/debug`.** Confirme o
  source set e o build type antes de reportar. `debug-overrides` só tem efeito em build `debuggable`.
- **Ausência de certificate pinning.** Não é vulnerabilidade por si. É uma decisão de defesa em
  profundidade; reporte como recomendação condicionada ao perfil do app (MAS-L2), com o custo
  operacional explícito.
- **Ausência de detecção de root/anti-debug/ofuscação.** Só é achado se o perfil for **MAS-R**. Num
  app cujo valor está no servidor, apontar isso como "vulnerabilidade" desperdiça o tempo do time.
- **`Math.random()` / `Random()` fora de contexto de segurança** (animação, jitter de retry,
  amostragem de telemetria). Só é achado quando gera token, ID de sessão, OTP ou nonce — aí exige
  `SecureRandom` / `SecRandomCopyBytes` / `crypto.getRandomValues`.
- **Componente exportado protegido por permissão de assinatura** (`protectionLevel="signature"`) ou
  cuja única ação é abrir uma tela sem parâmetro. Exportado ≠ vulnerável; a pergunta é o que a Intent
  consegue causar.
- **Endpoint HTTP para `localhost`/`10.0.2.2`** no Network Security Config (emulador, dev server). Não
  é cleartext em produção — só verifique que não está no `base-config` do release.
- **JWT no bundle JS que é um token público de leitura** (chave anônima de Supabase, token público de
  CMS). Só é achado se o token conceder mais do que a RLS/regras do backend permitem — e aí o achado
  é no backend, não no app.
- **App que pede permissão de câmera/localização e realmente usa.** Permissão excessiva se mede pela
  função, não pela lista.
- **WebView carregando apenas URL constante do próprio domínio, sem `addJavascriptInterface`.** Baixo
  risco; o achado real aparece quando a URL vem de Intent/deep link ou quando há ponte JS.

---

## Fontes

- OWASP Mobile Top 10 (2024): https://owasp.org/www-project-mobile-top-10/
- OWASP MASVS v2.1.0: https://mas.owasp.org/MASVS/ — releases: https://github.com/OWASP/masvs/releases
- OWASP MASTG (v2.0): https://mas.owasp.org/MASTG/ — checklists: https://mas.owasp.org/checklists/
- MASTG-TECH-0109 (interceptar Flutter, Android): https://mas.owasp.org/MASTG/techniques/android/MASTG-TECH-0109/
- MASTG-TECH-0110 (interceptar Flutter, iOS): https://mas.owasp.org/MASTG/techniques/ios/MASTG-TECH-0110/
- Android — Network Security Config: https://developer.android.com/privacy-and-security/security-config
- Android — App security best practices: https://developer.android.com/privacy-and-security/security-best-practices
- Android — Intent redirection: https://developer.android.com/privacy-and-security/risks/intent-redirection
- Android — Keystore e `KeyGenParameterSpec`: https://developer.android.com/privacy-and-security/keystore
- Android — Data backup / `dataExtractionRules`: https://developer.android.com/identity/data/autobackup
- Android — App Links e `assetlinks.json`: https://developer.android.com/training/app-links/verify-android-applinks
- Android — mudanças de comportamento da API 36: https://developer.android.com/about/versions/16/behavior-changes-16
- Play Integrity API — veredictos: https://developer.android.com/google/play/integrity/verdicts
- Descontinuação do SafetyNet Attestation (31/01/2025): https://groups.google.com/g/safetynet-api-clients/c/ac_AmiRCn0U
- Depreciação de `androidx.security:security-crypto`: https://developer.android.com/jetpack/androidx/releases/security
- Apple — App Transport Security: https://developer.apple.com/documentation/security/preventing-insecure-network-connections
- Apple — Keychain e access control: https://developer.apple.com/documentation/security/keychain-services
- Apple — App Attest / DeviceCheck: https://developer.apple.com/documentation/devicecheck
- Apple — Universal Links / AASA: https://developer.apple.com/documentation/xcode/supporting-associated-domains
- Apple — `ASWebAuthenticationSession`: https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
- RFC 8252 — OAuth 2.0 for Native Apps: https://datatracker.ietf.org/doc/html/rfc8252
- RFC 7636 — PKCE: https://datatracker.ietf.org/doc/html/rfc7636
- Expo — code signing do EAS Update: https://docs.expo.dev/eas-update/code-signing/
- Retirement do Visual Studio App Center / CodePush: https://learn.microsoft.com/en-us/appcenter/retirement
- `microsoft/code-push-server` (self-hosted): https://github.com/microsoft/code-push-server
- hermes-dec (disassembler/decompiler de Hermes): https://github.com/P1sec/hermes-dec
- reFlutter: https://github.com/Impact-I/reFlutter
- MobSF: https://github.com/MobSF/Mobile-Security-Framework-MobSF — `mobsfscan`: https://github.com/MobSF/mobsfscan
- Frida: https://frida.re — objection: https://github.com/sensepost/objection
