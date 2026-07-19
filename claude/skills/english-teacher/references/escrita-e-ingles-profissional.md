# Escrita e inglês profissional

Este documento trata do inglês que o desenvolvedor brasileiro realmente usa: e-mail, Slack, code review, standup, documentação, entrevista. Não é gramática — é registro, tom e cultura. A tese central: o problema do brasileiro em inglês profissional raramente é vocabulário; é **calibragem de registro**. Ele escreve como se estivesse peticionando a um juiz quando deveria estar avisando um colega, e escreve como se estivesse pedindo desculpas quando deveria estar discordando.

---

## Parte I — Escrita

### 1. Registro: o erro fundacional

Registro é a variação da língua conforme a situação. Em português, o brasileiro instruído domina isso perfeitamente: ele não escreve "venho por meio desta" no WhatsApp. Em inglês, ele perde a régua e desliza para o topo da escala formal, porque o único inglês escrito que praticou foi o do vestibular, do TOEFL e do abstract acadêmico.

| Registro | Onde vive | Traço dominante | Exemplo |
|---|---|---|---|
| Acadêmico | papers, teses | voz passiva, nominalização, hedging denso | "It was observed that the implementation of the proposed method yielded a reduction in latency." |
| Corporativo/legal | contratos, HR, compliance | fórmulas fixas, arcaísmos | "Please be advised that the aforementioned policy shall take effect..." |
| Técnico (bom) | docs, RFC, PR, README | imperativo, direto, presente simples | "Set `timeout` to 30s. The client retries three times." |
| Casual profissional | Slack, e-mail interno, review | contrações, frases curtas, humor leve | "Quick heads-up: the deploy is pushed to Thursday." |
| Casual | DM, pós-reunião | gíria, fragmento, emoji | "lol yeah that PR is cursed" |

O inglês profissional moderno de tech vive quase inteiramente nas linhas 3 e 4. A linha 2 é onde o brasileiro se instala por default — e é justamente a que soa **mais estranha**, porque um americano só a usa quando está sendo passivo-agressivo ou quando um advogado escreveu por ele.

✗ "I would like to inform you that the deployment has been rescheduled to next Thursday."
✓ "Quick heads-up: we moved the deploy to Thursday."

✗ "I am writing to kindly request your assistance regarding the aforementioned issue."
✓ "Could you take a look at this when you get a chance?"

✗ "Please find attached the requested document."
✓ "Attached is the spec." / "I've attached the spec."

✗ "We would like to express our sincere gratitude for your valuable contribution."
✓ "Thanks a lot for jumping in on this — it helped."

**Veredito:** formalidade excessiva não é "erro seguro". Ela cria distância, sinaliza desconforto e — pior — faz você parecer júnior, porque quem manda no assunto escreve curto. A régua correta: escreva como você falaria se a pessoa estivesse na sua frente e você estivesse relaxado.

**Contrações são obrigatórias no registro profissional normal.** `I'm`, `we've`, `don't`, `it's`, `that's`. Evitá-las é o marcador número um de texto escrito por não-nativo ou por IA. Só evite em documento legal, ou quando quiser dar ênfase deliberada ("I did *not* approve that").

### 2. Princípios de clareza

A tradição anglófona tem uma doutrina de escrita clara com nomes fortes. Vale conhecer os três pilares:

- **Joseph M. Williams, _Style: Lessons in Clarity and Grace_** — o melhor livro sobre prosa em inglês já escrito. Princípio central: uma frase é clara quando o **sujeito gramatical é o ator da história** e o **verbo principal é a ação**. Quase todo texto ruim viola isso.
- **William Zinsser, _On Writing Well_** — não-ficção. Mantra: "clutter is the disease of American writing". Corte metade e corte de novo.
- **Strunk & White, _The Elements of Style_** — canônico, mas leia com ressalva. Vários "conselhos" (nunca use passiva, nunca comece com "however") são superstições que os próprios autores violam. Geoffrey Pullum destruiu boa parte do livro em "50 Years of Stupid Grammar Advice", e ele tem razão. Use como cultura geral, não como lei.
- **Plain English / Plain Language movement** — origem britânica (Plain English Campaign, 1979) e agora lei federal americana (Plain Writing Act, 2010). Frases curtas, palavras comuns, voz ativa, "you" para o leitor.
- **Bryan Garner, _Garner's Modern English Usage_** — a autoridade descritivo-prescritiva. Quando você não sabe se algo é aceitável, Garner responde com dados de frequência.

#### 2.1 Ator como sujeito, ação como verbo

✗ "The implementation of the caching layer by the team resulted in a reduction of response times."
✓ "The team implemented a caching layer, which cut response times."

A primeira frase tem quatro ações escondidas em substantivos (*implementation, caching, reduction, response*) e um verbo vazio (*resulted*). A segunda tem atores e verbos.

#### 2.2 Nominalizações: o vício número um

Nominalização é o verbo transformado em substantivo. Português adora — é a herança do estilo jurídico-cartorial. Inglês técnico odeia.

| ✗ Nominalização | ✓ Verbo |
|---|---|
| make a decision | decide |
| perform an analysis of | analyze |
| provide assistance to | help |
| conduct an investigation | investigate |
| is dependent on | depends on |
| has a requirement for | requires |
| effect a reduction in | reduce |
| carry out the migration | migrate |

Regra prática: se a frase tem `-tion`, `-ment`, `-ance`, `-ity` seguido de `of`, quase sempre dá para reescrever com o verbo.

#### 2.3 Voz ativa por padrão

Passiva não é proibida — é **escolha**. Use-a quando o ator é irrelevante, desconhecido, ou quando você quer deliberadamente não apontar dedo.

✓ Legítimo: "The record was deleted at 04:12." (não sabemos por quem — postmortem)
✓ Legítimo: "Requests are rate-limited to 100/min." (o ator é o sistema, óbvio)
✗ Covarde: "Mistakes were made." (clássico exemplo de passiva usada para fugir da responsabilidade)
✗ Confuso: "It was decided that the feature would be postponed." → ✓ "We decided to postpone the feature."

Em postmortem, a passiva é na verdade uma **ferramenta cultural**: cultura blameless prefere "the config was pushed without review" a "João pushed the config without review". Isso é intencional e correto.

#### 2.4 "Old before new"

Princípio de fluxo de informação: comece a frase com o que o leitor já sabe, termine com a informação nova. É o que costura parágrafos.

✗ "A new rate limiter was added. Redis is used by the rate limiter. Latency spikes are handled well by Redis."
✓ "We added a new rate limiter. The limiter uses Redis, which handles latency spikes well."

Cada frase pega o fim da anterior e usa como início. Isso é coesão de verdade — muito mais eficaz do que empilhar "Moreover".

#### 2.5 Comprimento de frase

Média-alvo em prosa técnica: 15 a 20 palavras. Varie: uma frase longa, uma curta. Se você passou de 35 palavras, quase certamente há duas frases ali. O brasileiro escreve frases longas em inglês porque escreve frases longas em português — e em português isso é estilisticamente aceitável. Em inglês, não é.

### 3. Coesão: linking devices por função

Cada conector carrega registro. Usar o formal onde caberia o neutro é o erro clássico brasileiro.

| Função | Casual/neutro | Neutro-formal | Formal (use com parcimônia) |
|---|---|---|---|
| Adição | and, also, plus, on top of that | in addition, as well as | moreover, furthermore |
| Contraste | but, though, still | however, on the other hand | nevertheless, nonetheless, conversely |
| Causa | because, since, so | as, due to, given that | consequently, therefore, thus, hence |
| Resultado | so, that's why | as a result, which means | accordingly, thereby |
| Concessão | even so, that said, sure, but | although, while, granted | notwithstanding, albeit |
| Exemplificação | like, say, for example | for instance, such as | namely, to illustrate |
| Sequência | first, then, next, after that | initially, subsequently | thereafter, henceforth |
| Reformulação | in other words, basically, I mean | that is, put differently | i.e., viz. |
| Conclusão | so, all in all, bottom line | overall, in short | in conclusion, to summarize |
| Ressalva | that said, but keep in mind | however, note that | it should be noted that |

**Alerta específico e importante:** o brasileiro superusa `Moreover`, `Furthermore`, `In addition`, `Therefore`, `Thus` e `In conclusion` porque foi treinado na redação dissertativa e no ensaio de proficiência, onde esses conectores valiam ponto. Em e-mail e documentação real de tech, eles soam empolados e datados. Um engenheiro americano escreve três parágrafos sem usar nenhum dos seis.

✗ "The API is slow. Moreover, the cache is not being used. Furthermore, the query is unindexed. In conclusion, we should refactor."
✓ "The API is slow: the cache isn't being used and the query is unindexed. Worth refactoring."

Note também: `though` no fim da frase é extremamente comum e natural em fala e Slack — "It works. Slow, though." Brasileiros nunca usam. Deveriam.

E: **começar frase com `But`, `And`, `So` é correto** e comum em inglês profissional. A proibição é mito escolar. Garner documenta isso à exaustão.

### 4. Estrutura de parágrafo

Um parágrafo em inglês técnico tem uma anatomia previsível e o leitor **conta** com ela:

1. **Topic sentence** — a primeira frase declara o ponto. Não é introdução, é tese.
2. **Desenvolvimento** — evidência, exemplo, detalhe, número.
3. **Transição ou consequência** — o que isso significa, ou a ponte para o próximo parágrafo.

O brasileiro tende ao padrão inverso — contexto, contexto, contexto, e a conclusão no fim (padrão de alta contextualização, ver Erin Meyer adiante). Em inglês corporativo isso lê como "essa pessoa não sabe aonde quer chegar". A regra é **BLUF: Bottom Line Up Front**. Ponto primeiro, justificativa depois.

✗ "As you know, we've been working on the migration for a few sprints. There were several issues with the legacy schema, and the team spent time investigating. After discussion with the DBAs, and considering the risks, we believe it may be necessary to postpone the release."
✓ "We need to postpone the release by one sprint. The legacy schema has two blocking issues the DBAs flagged; details below."

### 5. Pontuação que o brasileiro erra

**Vírgula de Oxford (serial comma).** Antes de `and` no último item de lista. Chicago Manual e a maioria dos style guides americanos exigem; jornalismo (AP) omite. **Adote sempre** — resolve ambiguidade real.
- Ambíguo: "I'd like to thank my parents, Ayn Rand and God."
- Claro: "I'd like to thank my parents, Ayn Rand, and God."

**Comma splice.** Duas orações independentes ligadas só por vírgula. Em português é tolerado; em inglês é erro visível.
- ✗ "The test failed, I'll look into it."
- ✓ "The test failed. I'll look into it." / "The test failed, so I'll look into it." / "The test failed; I'll look into it."

**Ponto e vírgula.** Duas funções apenas: (a) unir duas orações independentes muito relacionadas; (b) separar itens de lista que já contêm vírgulas. Se você não tem certeza, use ponto. Ponto e vírgula mal usado é marcador de não-nativo.

**Conectivos que exigem ponto e vírgula ou ponto.** `however`, `therefore`, `moreover` são advérbios, não conjunções.
- ✗ "The build passed, however the deploy failed."
- ✓ "The build passed; however, the deploy failed."
- ✓ "The build passed. However, the deploy failed."
- ✓ "The build passed, but the deploy failed."

**Apóstrofo.** O campeão de erros.

| ✗ | ✓ | Regra |
|---|---|---|
| Its broken | It's broken | `it's` = it is/has; `its` = possessivo |
| changed it's policy | changed its policy | possessivo de `it` NUNCA tem apóstrofo |
| API's are slow / In the 90's | APIs are slow / In the 90s | plural não leva apóstrofo |
| Your right | You're right | `you're` = you are |
| Whose ready? | Who's ready? | `who's` = who is |
| — | James's code | Chicago prefere `James's` a `James'` |

**Hífen.** Adjetivo composto **antes** do substantivo leva hífen; depois, não.
- ✓ "a well-known issue" / "the issue is well known"
- ✓ "a third-party library" / "we use a third party" (aqui é substantivo)
- ✓ "read-only access", "up-to-date docs", "the docs are up to date"
- ✗ "a real time system" → ✓ "a real-time system"
- Advérbio em `-ly` **não** leva hífen: ✗ "a highly-available cluster" → ✓ "a highly available cluster"

**Travessão (em dash, —).** Interrupção enfática. Em inglês americano, sem espaços: `the deploy—which nobody reviewed—broke prod`. Britânico usa en dash com espaços: `the deploy – which nobody reviewed – broke prod`. Escolha um e seja consistente. Não abuse: mais de um par por parágrafo cansa.

**Aspas e pontuação.** Americano coloca vírgula e ponto **dentro** das aspas, mesmo quando ilógico. Britânico, fora.
- US: `He called it a "hotfix," which it wasn't.`
- UK: `He called it a "hotfix", which it wasn't.`
- Exceção universal em contexto técnico: nunca coloque pontuação dentro de aspas que delimitam um valor literal. `Set the flag to "true".`

**Title case.** Títulos em inglês capitalizam palavras principais e deixam artigos, preposições curtas e conjunções em minúscula (exceto a primeira e a última palavra).
- ✓ "How to Debug a Memory Leak in Production"
- ✗ "How To Debug A Memory Leak In Production"
- ✗ "How to debug a memory leak in production" (sentence case — válido, e é o que Google e Microsoft recomendam para docs; só não misture os dois no mesmo documento)

O **Google Developer Documentation Style Guide** e o **Microsoft Writing Style Guide** ambos recomendam **sentence case** para headings de documentação técnica. Adote isso em README e docs; use title case em títulos de artigo e post.

### 6. Erros de escrita típicos de brasileiros

**Falsos cognatos formais** — os que mais aparecem em e-mail:

| Português | ✗ | ✓ |
|---|---|---|
| atualmente | actually | currently, right now (`actually` = "na verdade") |
| eventualmente (às vezes) | eventually | occasionally (`eventually` = "por fim") |
| pretender | pretend | intend, plan to |
| realizar (executar) | realize | carry out, perform, run |
| assistir (a uma reunião) | assist | attend (`assist` = ajudar) |
| avisar | advise | let (someone) know, notify |
| exigir | exige | require, demand |
| cobrar (alguém) | charge | follow up with, chase |
| resumir | resume | summarize (`resume` = retomar) |
| sensato | sensible ≠ sensitive | sensible = sensato; sensitive = delicado |
| suportar (tolerar) | support | tolerate, put up with |
| compromisso | compromise | commitment (`compromise` = concessão) |
| lembrar alguém | remember | remind |
| formação (acadêmica) | formation | education, background |
| propaganda | propaganda | advertising, ads |

**"The same" como pronome.** Tradução literal de "o mesmo" burocrático. Não existe em inglês natural.
- ✗ "I received your email and will reply to the same shortly."
- ✓ "Got your email — I'll reply shortly."
- ✗ "Please review the document and sign the same."
- ✓ "Please review and sign it."

**"Besides".** Em português "além disso" é neutro; `besides` em inglês tem um tom quase defensivo, de argumento adicional meio impaciente ("and anyway..."). Para adição neutra, use `also` ou `on top of that`.
- ✗ "The API is fast. Besides, it's cheap."
- ✓ "The API is fast, and it's cheap too."
- ✓ (uso natural de besides) "I don't have time. Besides, it's not my call."

**"No caso de".** `In case of` só antes de substantivo curto ("in case of fire"). Para oração, é `in case` sem `of`, ou `if`.
- ✗ "In case of you need help, let me know."
- ✓ "If you need help, let me know." / "Let me know in case you need help."

Nota: `in case` ≠ `if`. "Take an umbrella in case it rains" = por precaução. "Take an umbrella if it rains" = condicional.

**"Conforme".** Não existe tradução única e o brasileiro força `as per`, que soa arcaico e levemente ríspido.
- ✗ "As per our conversation, I'm sending the file."
- ✓ "Following up on our conversation, here's the file."
- ✓ "As we discussed, here's the file."
- ✗ "As per the documentation..." → ✓ "According to the docs..." / "The docs say..."

**"Segue anexo".** Tradução literal produz o infame `Follows attached`.
- ✗ "Follows attached the report." / "Please find attached the report."
- ✓ "I've attached the report." / "Attached is the report." / "Here's the report." (Slack)

`Please find attached` não está errado, mas é registro de 1995. Google e Microsoft o listam como a evitar.

**Outros tiques:** ✗ "Explain me this" → ✓ "Explain this to me" · ✗ "I'm agree" → ✓ "I agree" · ✗ "Make a question" → ✓ "Ask a question" · ✗ "Take a decision" → ✓ "Make a decision" · ✗ "Do a mistake" → ✓ "Make a mistake" · ✗ "Since 2 years" → ✓ "For two years" · ✗ "Informations/feedbacks/advices/softwares" (incontáveis, sem `-s`) · ✗ "People is" → ✓ "People are" · ✗ "Anyone knows?" → ✓ "Does anyone know?" · ✗ "I didn't understood" → ✓ "I didn't understand".

---

## Parte II — Inglês profissional

### 7. E-mail

#### 7.1 Estrutura

1. **Subject** — específico e acionável. O leitor decide em 2 segundos.
2. **Saudação**
3. **Propósito na primeira linha** (BLUF)
4. **Contexto/detalhe**
5. **Pedido explícito com prazo**
6. **Fechamento**

**Subject lines:**

| ✗ | ✓ |
|---|---|
| Question | Question about the auth timeout config |
| Update | Payments API: migration done, 2 items left |
| Urgent!!! | Prod incident — need approval to roll back by 3pm ET |
| Meeting | Can we move Thursday's sync to 2pm? |
| Hello | Intro: Mauricio from the Platform team |

Prefixos úteis: `[Action needed]`, `[FYI]`, `[Decision needed]`, `[No action]`, `[EOM]` (end of message — assunto é o e-mail inteiro).

#### 7.2 Saudações e fechamentos por formalidade

| Nível | Saudação | Fechamento |
|---|---|---|
| Muito formal (candidatura, jurídico, cliente novo) | Dear Ms. Chen, / Dear Hiring Manager, / To whom it may concern, | Sincerely, / Yours sincerely, (UK, quando sabe o nome) / Respectfully, |
| Formal (cliente, executivo externo) | Dear Sarah, / Good morning, Sarah, | Best regards, / Kind regards, / Regards, |
| Neutro profissional (padrão para 90% dos casos) | Hi Sarah, / Hello Sarah, / Hi team, / Hi all, | Best, / Thanks, / Thanks again, / Cheers, (UK/AU, informal) |
| Informal (colega próximo) | Hey Sarah, / Sarah — | Thanks! / Talk soon, / — Mauricio |
| Interno rápido | (sem saudação) | (sem fechamento, só o nome ou nada) |

Notas: `Dear` sozinho em e-mail interno americano soa cerimonioso demais. `To whom it may concern` é último recurso — pesquise o nome. `Cheers` é britânico/australiano; americanos usam, mas soa levemente afetado vindo de um americano. `Best regards` é seguro em qualquer lugar. **Nunca** `Dear Sir` num contexto onde o gênero é desconhecido.

#### 7.3 Hedging: pedir sem mandar

Hedging é o amortecedor. Em inglês corporativo (especialmente americano e britânico), pedidos diretos demais soam como ordens. Mas cuidado: o brasileiro erra nos dois sentidos — hedging demais no pedido simples, hedging de menos no desacordo.

Escala de força de pedido, do mais suave ao mais direto:

| Força | Frase |
|---|---|
| Muito suave | I was wondering if you might have a chance to look at this? |
| Suave | Would you mind taking a look when you get a chance? |
| Neutro | Could you / Would you be able to review this by Friday? |
| Direto (ok) | Can you review this by Friday? |
| Direto | Please review this by Friday. |
| Forte | I need this reviewed by Friday. |
| Urgente | This is blocking the release — I need your review today. |

Regra: quanto mais alto na hierarquia, mais externo, ou mais custoso o pedido, mais para cima na escala. Para um colega no mesmo time, `Can you...?` é perfeito e `I was wondering if you might possibly...` soa estranho e servil.

**Softeners úteis:** `when you get a chance`, `no rush`, `whenever works for you`, `if it's not too much trouble`, `just checking`, `I might be missing something, but`, `feel free to say no`.

**Intensifiers para quando é sério:** `this is blocking X`, `we're at risk of missing Y`, `I want to flag that`, `to be direct:`, `I'd push back on this`.

#### 7.4 Modelos comentados

**Follow-up (o mais usado de todos):**

```
Subject: Following up: auth migration sign-off

Hi Priya,

Just following up on the auth migration doc I sent last Tuesday.
No rush if you're heads-down on the release — but I'd like to
start implementation Monday, so a quick yes/no by Friday would
unblock me.

Happy to walk through it on a call if that's easier.

Thanks,
Mauricio
```

Por que funciona: primeira linha diz o que é, dá saída educada, dá prazo concreto **com justificativa**, oferece alternativa. Nenhum "I hope this email finds you well".

**Cobrança educada (segunda cobrança, já com atrito):**

```
Subject: Re: Vendor contract — still waiting on legal review

Hi Tom,

Circling back on this one. We're now two weeks past the date we
agreed on, and the delay is pushing the integration into next
quarter.

Can you let me know today either (a) a firm date for the review,
or (b) who else I should be talking to? Happy to escalate on my
side if that helps unblock you.

Thanks,
Mauricio
```

`Circling back` é o termo padrão. O "either (a) or (b)" — duas saídas concretas — é mais eficaz que reclamar. E "happy to escalate on my side if that helps unblock you" é escalonamento embrulhado em oferta de ajuda: a fórmula clássica.

**Recusa (dizer não sem queimar a relação):**

```
Subject: Re: Can you take the reporting dashboard?

Hi Ana,

I'd like to help, but I don't have the bandwidth this sprint —
I'm on the payments migration through the 20th and it's already
tight.

Two options: I could pick it up starting the 21st, or Rafael
has done similar work and might have room sooner. Want me to
check with him?

Best,
Mauricio
```

Estrutura canônica: apreciação breve → não claro, com motivo verificável → alternativa. Nunca só "no", e nunca um "yes" mole que vira atraso depois — isso destrói confiança mais rápido que uma recusa.

**Desculpa por erro seu:**

```
Subject: My mistake on the staging config

Hi team,

That's on me — I pushed the staging config to prod at 14:20,
which caused the 20-minute outage. I've rolled it back and
staging is isolated again.

To prevent a repeat, I've opened PR #4412 adding a required
environment check to the deploy script. I'll write up a short
postmortem by tomorrow.

Sorry for the disruption.
Mauricio
```

A cultura americana de tech valoriza `That's on me` — assumir rápido, sem drama e sem autoflagelação. Errado seria "I sincerely apologize for my terrible mistake, I feel awful, this was completely unacceptable of me...": isso obriga o time a te consolar, um custo adicional que você criou. A fórmula é `sorry` + fato + correção + prevenção. Fim.

**Escalonamento (envolver o chefe sem parecer delação):**

```
Subject: Blocked on the vendor review — need a decision

Hi Carla,

Flagging this since it's now on the critical path.

We've been waiting on legal's review of the vendor contract since
March 3 (two follow-ups, thread below). The integration can't start
without it, and we're now at risk of slipping the Q2 date.

Could you help push on the legal side, or should we scope a
temporary workaround instead? I'd like to decide by Wednesday.

Thanks,
Mauricio
```

`Flagging this`, `on the critical path`, `at risk of slipping` — vocabulário que sinaliza gravidade sem acusar ninguém. Note que o e-mail nunca diz "legal is being slow"; diz "we've been waiting since March 3" — o fato faz o trabalho.

**Frases-fórmula por função:**

| Função | Frases |
|---|---|
| Abrir (interno) | Quick question / Quick heads-up / Following up on / Circling back on / Flagging something |
| Abrir (externo) | I'm reaching out about / Thanks for getting back to me / It was great meeting you at |
| Dar contexto | For context, / Some background: / To recap, |
| Pedir | Could you...? / Would you be able to...? / Any chance you could...? |
| Prazo | by EOD Thursday / by end of week / no later than / ideally by |
| Oferecer ajuda | Happy to / Let me know if it'd help to / I can take that off your plate |
| Discordar | I see it a bit differently / I'd push back on / Have we considered / My concern is |
| Encerrar | Let me know if that works / Does that sound right? / Thanks in advance / Anything else you need from me? |
| Anexar | I've attached / Attached is / Here's the / See the doc here: |

**Frases a aposentar:** `I hope this email finds you well` (clichê morto), `Please be advised that`, `Kindly do the needful` (indianismo), `As per`, `Herewith`, `The undersigned`, `Awaiting your reply` (soa impaciente), `Thanks in advance` quando o pedido é grande (pressupõe o sim).

### 8. Slack / Teams

Slack é fala escrita. Registro curto, contrações, sem saudação formal, sem assinatura. Erro brasileiro clássico: escrever um e-mail dentro do Slack.

✗ "Good morning, everyone. I hope you're all doing well. I would like to inform the team that the deployment scheduled for today has been postponed. Best regards, Mauricio."
✓ "Heads-up: today's deploy is pushed to tomorrow."

**Regras culturais:** não escreva "hi" e espere — `nohello.net` existe por um motivo; pergunte de uma vez ("Hey — quick q: does the auth service cache tokens?"). Use thread para desdobramentos ("Let's take this to a thread"); responder no canal principal é ruído. Reaction é resposta válida e não é infantil, é economia. Editar mensagem é normal. Fora do horário, sinalize: "No rush, tomorrow is fine" — respeitar fuso alheio é etiqueta forte em time distribuído.

**Siglas essenciais:**

| Sigla | Significado | Uso |
|---|---|---|
| FYI | for your information | "FYI, the staging DB is down." |
| PTAL | please take another look | após corrigir um code review |
| LGTM | looks good to me | aprovação de PR |
| WFH | working from home | "WFH today, ping me on Slack." |
| OOO | out of office | "I'm OOO next week." |
| PTO | paid time off | "Taking PTO Friday." |
| EOD | end of day | "I'll have it by EOD." |
| COB | close of business | equivalente britânico/corporativo de EOD |
| EOW | end of week | — |
| ASAP | as soon as possible | use pouco — soa pressionador |
| TL;DR | too long; didn't read | resumo no topo de texto longo |
| IMO / IMHO | in my opinion / in my humble opinion | hedging leve |
| AFAIK | as far as I know | "AFAIK that endpoint is deprecated." |
| IIRC | if I recall correctly | — |
| nit | nitpick | comentário trivial em code review |
| +1 | concordo | "+1 to shipping Friday" |
| bump | subir a mensagem esquecida | "bump — any thoughts on this?" |
| WIP | work in progress | PR ainda não pronto |
| RFC | request for comments | doc de proposta |
| SGTM | sounds good to me | — |
| DM | direct message | "I'll DM you the creds." |
| ICYMI / TIL / YMMV | in case you missed it / today I learned / your mileage may vary | — |

`Heads-up` merece nota própria: substantivo (`a heads-up`) ou usado como interjeição (`Heads-up:`). É o aviso antecipado educado — a peça mais útil e mais subutilizada pelo brasileiro. "Just a heads-up that I'll be 10 minutes late."

### 9. Reuniões

Frases prontas por função. Decore estas.

| Função | Frases |
|---|---|
| Abrir | Alright, let's get started. / Thanks everyone for joining. / Let's give it another minute for people to join. / Quick agenda check: we've got three things today. |
| Passar a palavra | Sarah, do you want to walk us through it? / Over to you, Tom. / Ana, anything to add? / Let's hear from the folks who haven't spoken yet. |
| Interromper (educado) | Sorry to jump in — / Can I add something quickly? / Just to build on that — / Sorry, before we move on — |
| Pedir repetição | Sorry, could you repeat the last part? / You cut out for a second — could you say that again? / I want to make sure I got that: are you saying...? / Could you say that a bit more slowly? My connection is choppy. |
| Verificar entendimento | Just to make sure I understand — you mean X, right? / Let me play that back: ... / Am I following you correctly? |
| Concordar | Totally agree. / That makes sense. / Good point. / Yeah, I'm with you on that. / +1 |
| Concordar parcialmente | I agree with the general direction, but I'd change X. / Fair — though I'd add that... / Yes and — |
| Discordar (suave) | I see it a bit differently. / I'm not sure I agree — here's my concern. / Have we considered X? / What worries me is Y. |
| Discordar (firme) | I'd push back on that. / I don't think that'll work, and here's why. / I'd like to register a concern. |
| Redirecionar | Let's park that for now. / That's a good topic — can we take it offline? / Let's circle back to that at the end. / I want to keep us on time. |
| Pedir clareza | What's the actual ask here? / Who owns this? / What's the deadline? / Is this a decision or a discussion? |
| Resumir | So to summarize: ... / Where we landed is... / Let me recap the decisions. |
| Action items | Action items: Tom owns X by Friday, I'll take Y. / Who's picking this up? / I'll follow up in the channel with notes. |
| Encerrar | I think we've got what we need. / Let's wrap there. / Thanks everyone — I'll send notes. / Anything else before we close? |

Sobre pedir repetição: **é a habilidade mais importante e a que o brasileiro mais evita por vergonha.** Nativos pedem repetição uns aos outros o tempo todo. Culpar a conexão é socialmente gratuito e universalmente aceito: "Sorry, you froze for a second." Nunca finja que entendeu — o custo de descobrir isso três dias depois é infinitamente maior do que o de perguntar.

### 10. Cerimônias ágeis

**Daily standup** — três slots, presente/passado/bloqueio:

```
Yesterday I worked on the token refresh bug — I found the root
cause, it's a race condition in the retry logic.

Today I'm picking up the fix and I'll open a PR by the afternoon.

I'm blocked on the staging credentials — Ana, could you grant me
access after this call?
```

Variantes naturais: `Yesterday I wrapped up...`, `I'm still on...`, `I'm halfway through...`, `Today I'm jumping into...`, `No blockers`, `Nothing blocking on my end`, `I could use a hand with...`, `I'll sync with Tom offline about that`.

**Refinement / grooming:** "Can we break this down further?" / "I'd size this as a 5 — there's unknown work in the migration." / "This feels too big for one sprint." / "What's the acceptance criteria?" / "Is this a spike or actual implementation?"

**Planning:** "I have capacity for about two tickets this sprint." / "I'd like to pull this into the sprint if we have room." / "That's a stretch goal." / "Let's not overcommit."

**Retro:** "What went well: the deploy pipeline is much faster." / "What didn't go so well: we got surprised by the vendor outage." / "One thing I'd change: let's cut scope earlier when we see risk." / "I want to give a shout-out to Ana for covering on-call." / "Action item for next sprint:"

**Demo:** "I'll walk you through what we shipped." / "Let me share my screen." / "Can everyone see my screen?" / "This is still behind a feature flag." / "Any questions before I move on?"

### 11. Code review em inglês

A cultura de code review anglófona (especialmente GitHub) é **hedged por design**. O comentário é sobre o código, nunca sobre a pessoa, e formulado como observação ou pergunta, não como veredito. Isso não é frouxidão — é o que permite discordar tecnicamente sem custo social.

| ✗ Agressivo | ✓ Calibrado |
|---|---|
| This is wrong. | I think this might break when `items` is empty — the index would be -1. |
| You forgot the null check. | Should we guard against a null `user` here? |
| Why did you do it this way? | What's the reasoning behind this approach? I might be missing context. |
| This is unreadable. | This took me a couple of reads — would extracting the filter into a named function help? |
| Don't use `any`. | Could we type this more narrowly? `any` here loses the safety we get downstream. |
| Bad naming. | `data` is a bit vague — maybe `pendingInvoices`? |
| This will cause a memory leak. | I think this holds a reference after unmount — worth checking? |
| Rewrite this. | I'd suggest restructuring this into two functions, but happy to discuss if you see it differently. |

**Convenções de prefixo** (adote — elas eliminam ambiguidade sobre o peso do comentário):

| Prefixo | Significado |
|---|---|
| `nit:` | trivial, não bloqueia, ignore se quiser |
| `suggestion:` | ideia opcional |
| `question:` | quero entender, não estou pedindo mudança |
| `issue:` / `blocking:` | precisa mudar antes do merge |
| `non-blocking:` | mude se concordar, mas aprovo mesmo assim |
| `praise:` | elogio explícito — subutilizado e valioso |
| `chore:` | tarefa mecânica (formatação, import) |
| `FYI:` | contexto, sem ação |

Isso vem da convenção Conventional Comments. Exemplo: `nit: extra blank line here` deixa claro que ninguém deve gastar 20 minutos com aquilo.

**Aprovando:** "LGTM" / "LGTM with one nit." / "Approving — feel free to merge after the typo fix." / "Nice cleanup." / "This is much clearer than the old version."

**Recebendo review:** "Good catch, fixed." / "Fair point — updated." / "I went back and forth on this; here's why I landed on X: ..." / "Hmm, I'd like to keep it as is because Y — what do you think?" / "PTAL." / "Addressed all comments, ready for another look."

**Discordando de um reviewer:** "I hear you, but I think the tradeoff favors X because..." / "I'd rather not change this now — it's out of scope for this PR. Opened #4413 to track it." / "Can we get a third opinion on this one?"

Nota cultural crítica: o brasileiro tende a ler comentários hedged como **elogios** e ignorá-los. `I wonder if we should consider...` de um staff engineer geralmente significa "mude isso". E o inverso: comentário curto de um alemão ou holandês — "This is wrong, use a map" — **não é agressão**, é o registro normal deles. Não leve para o pessoal.

### 12. Documentação, commits e PRs

**Commit messages: imperativo, presente, sem ponto final.** A convenção vem do próprio Git ("Merge branch...", "Revert..."). Teste: a mensagem deve completar a frase *"If applied, this commit will ___"*.

- ✓ `fix: handle empty cart in checkout`
- ✓ `refactor: extract token validation into middleware`
- ✗ `fixed the empty cart bug` (passado)
- ✗ `fixing empty cart` (gerúndio)
- ✗ `Fix empty cart.` (ponto final; e com Conventional Commits, sem o tipo)
- ✗ `changes` / `wip` / `asdf`

Corpo do commit: explique **por quê**, não o quê — o diff já mostra o quê.

**Pull request:**

```
## What
Adds a Redis-backed rate limiter to the public API.

## Why
We saw 3 scraping incidents last month (see #4102). Rate limiting
at the gateway was rejected because it can't see the API key.

## How
Sliding window counter in Redis, 100 req/min per key. Falls open
if Redis is unavailable — availability over enforcement, per the
discussion in #4102.

## Testing
Unit tests for the window logic; manually verified with `hey`
against staging (results in the thread).

## Notes for reviewers
The `falls open` behavior is deliberate. Happy to revisit if
you disagree.
```

**README** — segunda pessoa (`you`), imperativo para instruções, presente simples para descrição. É o que o Google Developer Documentation Style Guide prescreve.

- ✓ "Install the CLI with `npm i -g foo`." (imperativo)
- ✓ "The CLI reads config from `~/.foorc`." (presente simples)
- ✗ "The CLI will read the config from..." (futuro desnecessário — em docs, `will` só para eventos genuinamente futuros)
- ✗ "We recommend that the user should configure..." → ✓ "Configure the timeout before deploying."
- Evite `simply`, `just`, `easy`, `obviously` — se não for fácil para o leitor, essas palavras o humilham. Ambos os style guides (Google e Microsoft) proíbem explicitamente.

**RFC / design doc:** presente e futuro condicional. Estrutura padrão: Context → Problem → Goals / Non-goals → Proposal → Alternatives considered → Risks → Open questions. `Non-goals` é uma seção subvalorizada e extremamente eficaz para cortar discussão.

**Incident postmortem:** passado, voz frequentemente passiva ou impessoal (blameless), e **timeline em bullets com timestamps e fuso**.

```
## Summary
Between 14:20 and 14:41 UTC, 38% of checkout requests returned 500.

## Impact
~4,200 failed checkouts. No data loss. Revenue impact estimated at $12k.

## Timeline
- 14:20 — A config change was deployed to production.
- 14:23 — Error-rate alert fired in #alerts.
- 14:31 — On-call identified the config as the likely cause.
- 14:41 — The change was rolled back; error rate returned to baseline.

## Root cause
The staging Redis URL was present in the production config bundle...

## What went well
Alerting fired within three minutes.

## Action items
- [ ] Add an environment assertion to the deploy script (owner: Mauricio, by Mar 20)
```

Note: `The change was rolled back`, não `Mauricio rolled back the change`. A passiva aqui é escolha cultural deliberada.

### 13. Entrevista de emprego

**"Tell me about yourself"** — não é biografia. Estrutura **present → past → future**, 90 a 120 segundos:

```
I'm a backend engineer with about eight years of experience,
currently at [Company] where I lead the payments platform team —
we process around 2 million transactions a day.

I got there through a fairly typical path: started in Java at a
consultancy, moved to Go when I joined a fintech in 2019, and
that's where I got deep into distributed systems and reliability.
The work I'm proudest of is a migration we did last year that cut
our p99 latency from 800ms to 120ms without downtime.

What I'm looking for now is a role with more architectural
ownership on a product that ships to a global audience — which is
why this role caught my attention.
```

**STAR para comportamentais** — Situation, Task, Action, Result. Sinalize verbalmente:

```
S: Last year our main API started timing out during peak hours.
T: I owned reliability for that service, so it was on me to fix it.
A: I profiled the hot path, found an N+1 query in the serializer,
   added a batch loader, and set up a load test in CI so it
   couldn't regress.
R: p99 dropped from 800ms to 120ms, and we haven't had a
   peak-hour incident since. I also wrote it up internally, and
   two other teams adopted the same pattern.
```

Perguntas que sempre vêm: "Tell me about a time you disagreed with your manager" / "...a project that failed" / "...you had to give difficult feedback" / "What's your biggest weakness?" Tenha três histórias STAR prontas e recicle-as.

**Vocabulário de senioridade** — verbos de propriedade, não de participação:

| ✗ Fraco | ✓ Forte |
|---|---|
| I helped with the migration | I led / I owned the migration |
| I participated in the design | I drove the design |
| I was part of a team that built | I built / I was responsible for |
| I worked on some improvements | I cut latency by 85% |
| I did some mentoring | I mentored three juniors, two of whom were promoted |
| We decided to | I proposed X, and after aligning with the team we shipped it |

Outros termos: `scoped`, `shipped`, `drove alignment`, `unblocked`, `de-risked`, `advocated for`, `influenced without authority`, `set the technical direction`, `cross-functional`.

**Dois erros brasileiros fatais:**

1. **Autodepreciação.** "My English is not very good, sorry." / "I'm not an expert but..." / "It was nothing special." Em cultura americana de contratação, isso é lido literalmente, não como modéstia. O entrevistador não vai descontar. Se a preocupação com o idioma for real, reformule em positivo: "I work in English daily with my team — let me know if you'd like me to slow down or repeat anything."

2. **Excesso de "we".** O brasileiro diz `we` por educação coletivista; o entrevistador americano ouve "essa pessoa não fez nada". Use `we` para contexto e `I` para contribuição: "We had a reliability problem. *I* profiled the service and found..."

**Negociação salarial:** "Could you share the range you have budgeted for this role?" (pergunte antes de dar número) / "Based on my experience and the market, I'm targeting the 180–200 range." / "I'd need to see something closer to X to make the move." / "Is there flexibility on the base, or would equity be easier?" / "I'm excited about the role — I just want to make sure we land somewhere that works for both of us."

E depois de dar o número: **cale a boca**. O silêncio é ferramenta. O brasileiro tende a preencher o silêncio negociando contra si mesmo ("...but I'm flexible!").

**Perguntas para o entrevistador** (não fazer nenhuma é sinal vermelho): "What does success look like in this role after six months?" / "How does the team make technical decisions when there's disagreement?" / "What's the on-call setup like?" / "What's the biggest challenge the team is facing right now?" / "How much of the work is greenfield vs. maintenance?" / "Why is this role open?" / "What's the promotion path from here?"

### 14. Small talk e cultura

Small talk anglófono não é conversa — é protocolo de handshake. Dura de 30 a 90 segundos, é obrigatório e é superficial **por design**. O brasileiro erra de duas maneiras: pula (parece frio) ou leva a sério demais e responde a "How are you?" com um relatório médico.

**Tópicos seguros:** clima, fim de semana (sem detalhes), viagem, esporte (com cuidado), comida, séries, o próprio trabalho, tecnologia, animais de estimação, o fato de estar chovendo em Londres.

**Tópicos inseguros nos EUA/UK:** salário, política, religião, idade, estado civil, filhos ("when are you having kids?" — nos EUA é potencialmente ilegal em contexto de trabalho), aparência física, peso, imigração, saúde. Coisas absolutamente normais numa mesa brasileira que causam silêncio constrangido numa call americana.

**Abridores prontos:** "How's your week going?" / "Anything fun planned for the weekend?" / "How was your weekend?" / "How's the weather over there?" / "Is it still snowing where you are?" / "How's the new setup working out?"

**Fechadores:** "Anyway — should we get started?" / "Alright, let's dive in."

E: `How are you?` **não é uma pergunta.** Resposta correta: "Good, you?" É um ritual. Responder honestamente ("Well, actually I've been quite tired because...") quebra o protocolo.

#### 14.1 The Culture Map

**Erin Meyer, _The Culture Map_ (2014)** é a referência prática. Ela mapeia culturas em oito escalas; três importam muito para o dev brasileiro em time internacional:

**Comunicação: low-context ↔ high-context.**
Em culturas low-context (EUA, Holanda, Alemanha, Austrália, países nórdicos), a mensagem está nas palavras. Diga o que quer dizer, repita, escreva depois. Em culturas high-context (Brasil, Japão, França, Índia, países árabes), o significado está no contexto, no tom, no que não foi dito. O brasileiro é high-context: fala em volta, deixa implícito, espera que o outro capte.

Consequência prática: **o americano não vai captar.** Se você escreveu "I think maybe we could possibly consider looking at the deadline again", ele leu "tudo certo com o prazo". Você precisa dizer: "We're going to miss the deadline. I need two more weeks."

Meyer tem uma regra ótima: em time multicultural, **o low-context vence sempre**. É o denominador comum. Escreva explícito, resuma decisões por escrito depois da call, confirme entendimento.

**Feedback negativo: direto ↔ indireto.**
Aqui a escala é diferente da anterior — Holanda, Alemanha, Dinamarca, Israel e Rússia dão feedback negativo **direto** ("This is wrong"); EUA e UK dão **indireto e embrulhado** apesar de serem low-context na comunicação; Brasil, Japão e Tailândia são bem indiretos.

- O holandês diz "I disagree, this approach is bad" e não quer ofender ninguém — é literalmente o registro neutro dele. Não é grosseria.
- O americano diz "That's an interesting idea — I wonder if we've thought about the edge cases here?" e quer dizer **não**. Isso é o famoso *sandwich* e é uma armadilha para o brasileiro, que ouve "interesting" e sai feliz.
- O britânico é o extremo: "I'm sure it's just me, but I'm slightly concerned that this might possibly not entirely work" = "isso está completamente errado". "Quite good" = mediano. "With the greatest respect" = você é um idiota. "Interesting" = ruim.

**Como calibrar, na prática:**
- Ao **receber** de holandês/alemão/israelense: desconte a dureza. É forma, não conteúdo.
- Ao **receber** de americano/britânico: aumente o volume da crítica. `might`, `slightly`, `I wonder`, `just a thought` são amortecedores em cima de um problema real. Pergunte: "Is this a blocker for you, or a preference?" — pergunta perfeita, resolve a ambiguidade sem custo.
- Ao **enviar** para americano: seja mais explícito do que seu instinto pede, mas mantenha o hedging. "I don't think this will work — here's my concern: X. Am I missing something?"
- Ao **enviar** para holandês/alemão: pode ser direto. Enfeitar demais gera desconfiança.

**Persuasão e disagreement.** Meyer também mapeia se o desacordo aberto é visto como saudável (França, Israel, Holanda, Alemanha) ou como desarmônico (Japão, Indonésia, e em boa parte o Brasil). Em time americano de tech, **discordar em público é esperado e valorizado** — silêncio numa design review é lido como falta de opinião, não como concordância. "Disagree and commit" (frase da Amazon) é a norma: brigue no debate, execute a decisão sem ressentimento.

Leitura complementar: **Mark Powell, _Dynamic Presentations_** para apresentar em inglês; **Ken Taylor, _50 Ways to Improve Your Business English_** e **Cambridge _Business Vocabulary in Use_** (Bill Mascull) para vocabulário corporativo estruturado.

### 15. Jargão de tech que confunde

| Termo | Significado real | Exemplo |
|---|---|---|
| deploy | colocar código no ambiente | "We deploy on Tuesdays." |
| ship | entregar ao usuário (mais cultural que deploy) | "Let's ship it and iterate." |
| rollout | liberação gradual | "We're doing a staged rollout to 5% of users." |
| roll back | reverter | "Roll it back and we'll debug tomorrow." |
| spike | investigação time-boxed (≠ pico de tráfego!) | "Let's do a two-day spike on GraphQL." |
| backlog grooming / refinement | detalhar e estimar tickets | "Grooming is Wednesday." |
| bandwidth | capacidade pessoal de trabalho | "I don't have the bandwidth this week." |
| circle back | voltar ao assunto depois | "Let's circle back on Friday." |
| take it offline | discutir fora desta reunião | "Good point — can we take that offline?" |
| low-hanging fruit | ganho fácil | "Let's start with the low-hanging fruit." |
| blocker | o que impede o progresso | "The missing creds are a blocker." |
| bikeshedding | discutir o trivial e ignorar o importante | "We're bikeshedding the button color." |
| stakeholder | quem tem interesse na decisão | "Who are the stakeholders here?" |
| alignment / align | consenso entre partes | "I need to align with Legal first." |
| sync | reunião curta / sincronizar | "Let's do a quick sync." / "I'll sync with Ana." |
| heads-down | concentrado, indisponível | "I'm heads-down until Thursday." |
| on my plate / off my plate | na minha responsabilidade / tirar dela | "Can you take that off my plate?" |
| loop in | incluir alguém | "Let me loop in the security team." |
| ping | mandar mensagem | "Ping me when it's deployed." |
| punt | adiar deliberadamente | "Let's punt on i18n until Q3." |
| scope creep | escopo crescendo sem controle | "This is scope creep — let's cut it." |
| tech debt | atalho que custará depois | "We're paying down tech debt this sprint." |
| dogfooding | usar o próprio produto | "We're dogfooding the new dashboard." |
| moving the needle | causar impacto mensurável | "That won't move the needle." |
| double down | investir mais no mesmo caminho | "Let's double down on reliability." |
| table it | **US: adiar. UK: pautar agora.** Sentidos opostos — evite | — |
| happy path | fluxo sem erro | "That only handles the happy path." |
| firefighting | apagar incêndio | "The team's been firefighting all week." |
| ballpark | estimativa grosseira | "Ballpark, two weeks." |
| 1:1 | reunião individual com o gestor | "I'll bring it up in my 1:1." |
| ramp up | subir a curva de aprendizado | "Give her a month to ramp up." |

---

## Referências

- Joseph M. Williams & Joseph Bizup, *Style: Lessons in Clarity and Grace* — o fundamento de tudo neste documento.
- William Zinsser, *On Writing Well*.
- Strunk & White, *The Elements of Style* — com as ressalvas de Pullum.
- Bryan A. Garner, *Garner's Modern English Usage*.
- *The Chicago Manual of Style* — pontuação, capitalização, serial comma.
- *Google Developer Documentation Style Guide* — developers.google.com/style.
- *Microsoft Writing Style Guide* — learn.microsoft.com/style-guide.
- Erin Meyer, *The Culture Map*.
- Bill Mascull, *Business Vocabulary in Use* (Cambridge).
- Mark Powell, *Dynamic Presentations* (Cambridge).
- Ken Taylor, *50 Ways to Improve Your Business English*.
- Conventional Comments (conventionalcomments.org) e Conventional Commits (conventionalcommits.org).
