# Riscos, golpes e ética

Este documento trata do lado que ninguém coloca no post motivacional: o que dá errado. Vaga falsa, golpe montado especificamente contra desenvolvedor, conta restrita por automação, carreira queimada por um post mal calibrado, e as zonas cinzentas onde a pessoa acha que está "otimizando o perfil" quando na verdade está criando um passivo que explode seis meses depois, no background check, com o contrato já assinado.

O enquadramento aqui é defensivo e prático. Não é moralismo — é cálculo de risco. Quase todas as recomendações deste arquivo se justificam sozinhas por consequência esperada, sem precisar recorrer a "é errado". E a tese que atravessa tudo: **o mercado de trabalho remoto internacional é assimétrico contra você**. Você tem pouca informação sobre a contraparte, pouca capacidade de recurso jurídico, e um desejo forte de que a oportunidade seja real. Golpista e empregador ruim exploram exatamente essa combinação.

---

## Parte I — Vagas falsas e golpes contra devs brasileiros

### 1. Por que o dev brasileiro é alvo preferencial

Não é azar. É perfil:

- Fala inglês razoável, mas nem sempre bem o suficiente para captar dissonância de registro num texto de "recrutador".
- Busca ativamente trabalho fora, com uma forte expectativa de salto salarial — o que torna uma oferta alta demais plausível em vez de suspeita.
- Está acostumado a processos remotos assíncronos, então "nunca vi ninguém no vídeo" não soa anormal.
- Roda código de terceiros por profissão. Clonar um repositório e rodar `npm install` é trabalho rotineiro, não um evento de segurança.
- Tem acesso, na máquina de trabalho, a credenciais, chaves SSH, tokens de cloud e carteiras cripto. O laptop de um dev sênior vale muito mais que o de um analista de marketing.

Esse último ponto é o que muda tudo. Contra a maioria das pessoas, o golpe de emprego busca dinheiro direto (taxa, dados bancários). Contra desenvolvedor, o alvo frequentemente é **a máquina** — e o "processo seletivo" é só o vetor de entrega.

### 2. Catálogo defensivo

Cada padrão abaixo está descrito no nível necessário para reconhecê-lo. Sinal de alerta de um lado, verificação que desarma do outro.

#### 2.1 Recrutador que puxa o processo inteiro para chat

O contato começa no LinkedIn e migra rápido para Telegram, WhatsApp ou Discord. Entrevista por texto. Perguntas genéricas. Nenhuma chamada de vídeo, com desculpa plausível ("nosso time é async", "estamos em fuso diferente", "câmera com problema").

| Sinal de alerta | Verificação que desarma |
|---|---|
| Migração imediata para Telegram/Discord | Empresa real de verdade usa e-mail corporativo e um ATS (Greenhouse, Lever, Ashby). Peça: "pode me mandar o convite pelo e-mail da empresa?" |
| Entrevista 100% por texto | Peça 15 minutos de vídeo com câmera. Nenhuma empresa legítima recusa isso na etapa final |
| Recrutador não aparece no site da empresa nem no LinkedIn da empresa | Procure o nome dele na página de time e cruze com a lista de funcionários no LinkedIn |
| Pressa para "fechar hoje" | Urgência é a ferramenta principal do golpe. Empresa real tem processo, e processo tem calendário |

O ponto forte dessa defesa é barato: **uma chamada de vídeo com câmera elimina a maior parte dos casos**. Se a contraparte não faz uma videochamada de quinze minutos antes de você entregar qualquer coisa, encerre.

#### 2.2 Oferta alta demais, sem etapa técnica

USD 12k/mês para um pleno, sem live coding, sem system design, sem conversa técnica com alguém que claramente é engenheiro. Só um "papo com o hiring manager" que dura vinte minutos e termina com aprovação.

O que está acontecendo, na prática: a oferta alta existe para desligar seu ceticismo durante a próxima etapa — que é a etapa que interessa ao golpista (o "teste técnico", os dados, o adiantamento).

| Sinal de alerta | Verificação que desarma |
|---|---|
| Salário muito acima da faixa de mercado para o nível | Derive a faixa do seu nível na tabela de `vagas-remotas-no-exterior.md` e compare; cruze com Levels.fyi, Glassdoor e vagas públicas da mesma empresa. Oferta muito acima dessa faixa, sem justificativa, é bandeira |
| Aprovação sem nenhuma avaliação técnica séria | Empresa que paga bem avalia rigorosamente. Ausência de rigor com salário alto é contradição estrutural |
| Nenhum engenheiro no processo | Peça para conversar com quem seria seu tech lead. Recusa é resposta |

#### 2.3 O "teste técnico" que exige rodar o repositório

Este é o mais importante deste documento, e o que mais atinge desenvolvedores especificamente.

O padrão: depois de uma ou duas conversas amistosas, o "recrutador" envia um repositório privado (GitHub, GitLab, Bitbucket, às vezes um .zip ou um link do Google Drive) e pede que você clone, instale as dependências, **rode a aplicação** e corrija um bug ou adicione uma feature. Frequentemente há pressa e um prazo curto.

O que costuma estar escondido ali:

- Uma dependência de nome parecido com um pacote popular, apontando para um registry ou repositório controlado pelo atacante.
- Um script de ciclo de vida (`postinstall`, `prepare`) que executa no momento do `npm install`, antes de qualquer código de aplicação.
- Código ofuscado ou minificado dentro de um arquivo de configuração, de teste ou de build — lugares que ninguém lê antes de rodar.
- Um payload que, executado, coleta variáveis de ambiente, arquivos `.env`, chaves SSH, tokens de cloud, credenciais de navegador e carteiras cripto, e abre acesso remoto.

O detalhe cruel é que a tarefa é sempre **legítima na superfície**: o bug existe, o código faz sentido, e você precisa rodar para resolver. O convite a executar é a essência do ataque, não um acidente.

| Sinal de alerta | Verificação que desarma |
|---|---|
| Ênfase em **rodar** o projeto em vez de ler e escrever código, e sem nenhuma etapa técnica anterior com um engenheiro | Todo take-home legítimo exige execução — o sinal não é esse, é a combinação com repositório sem histórico, pressa e ausência de avaliação técnica antes. Em qualquer cenário, código de processo seletivo roda em container ou VM descartável, nunca na máquina principal |
| Repositório privado enviado por link direto, sem histórico | Cheque commits, contribuidores, idade do repositório. Repositório de um dia, um commit, um autor |
| `package.json` com dependências que você não reconhece, ou nomes quase-iguais a pacotes famosos | Leia o manifesto **antes** de instalar. Cheque cada dependência não óbvia no registry oficial: downloads, mantenedor, data de publicação |
| Scripts `postinstall`/`preinstall` presentes | Instale com scripts desativados (`npm install --ignore-scripts`) e leia o que eles fariam |
| Pressa ("precisa entregar em 24h") | Prazo curto existe para impedir a leitura cuidadosa. Peça mais prazo — a reação à recusa já é informação |
| Arquivo minificado/ofuscado em projeto que não deveria ter build artifact commitado | Nenhuma explicação inocente é comum aqui. Encerre |

**A regra de ouro**, e ela não tem exceção prática:

> Nunca execute código de processo seletivo na sua máquina principal. Sem exceção, sem "mas parece confiável".

Como isolar, em ordem de preferência:

1. **VM descartável** (UTM/Parallels no Mac, VirtualBox, Multipass), sem pastas compartilhadas, sem login em nada, snapshot antes e destruição depois.
2. **Codespaces / Gitpod / devcontainer remoto** — executa fora da sua máquina, com credenciais que você controla e pode revogar. Cuidado: mesmo aí, não injete tokens seus no ambiente.
3. **Container Docker** sem montagem do home, sem `--privileged`, sem sua chave SSH, sem socket do Docker mapeado. Bom, mas mais fraco que VM: container não é fronteira de segurança forte.

E dentro do isolamento: sem login em Google, GitHub, cloud, banco ou carteira. O ambiente descartável só protege se ele estiver realmente vazio.

Se você rodou antes de ler isto e depois desconfiou: trate como comprometimento. Rotacione tokens do GitHub, chaves de cloud, chaves SSH, senhas do gerenciador; revogue sessões ativas; avise a empresa onde você trabalha se a máquina for corporativa. Custa uma tarde. O contrário custa muito mais.

#### 2.4 Pedido de dados bancários ou documento cedo demais

Pedem CPF, RG, passaporte, comprovante de residência ou dados bancários ainda na fase de entrevistas, com a justificativa de "adiantar o onboarding" ou "verificação de identidade".

| Sinal de alerta | Verificação que desarma |
|---|---|
| Dado sensível pedido antes de oferta formal por escrito | Nada de documento ou conta bancária antes de contrato assinado. Sem exceção |
| Pedido feito por chat, em foto | Empresa real coleta isso em plataforma dedicada (Deel, Remote, Oyster, Velocity Global, RH próprio), com link em domínio da plataforma |
| Formulário em Google Forms para dados de identidade | Nenhuma empresa séria coleta documento em Forms |

#### 2.5 Taxa de processamento, equipamento ou "software obrigatório"

Pedem que você pague por treinamento, licença, taxa de visto/processamento, ou que compre o laptop e periféricos de um fornecedor específico, com promessa de reembolso na primeira folha.

Regra que fecha a categoria inteira: **em uma relação de trabalho legítima, o dinheiro flui do empregador para você. Sempre.** Qualquer arranjo em que você paga primeiro e é reembolsado depois é golpe até prova documental em contrário — e a prova quase nunca existe.

Nuance real: algumas empresas remotas oferecem stipend de home office com reembolso. Diferença: o stipend é opcional, vem depois da contratação, é para o fornecedor que você escolher, e está escrito no contrato. O golpe é obrigatório, é antes, e é para um fornecedor indicado por eles.

#### 2.6 Cheque, transferência ou adiantamento com devolução parcial

Enviam um valor (cheque, PIX, transferência internacional) "para você comprar equipamento" e pedem que devolva a diferença, ou que repasse parte a um "fornecedor". Semanas depois a transação original é revertida como fraudulenta e o valor que você devolveu saiu do seu bolso — e, pior, pode ter passado pela sua conta dinheiro de origem criminosa, o que transforma você em elo de lavagem.

| Sinal de alerta | Verificação que desarma |
|---|---|
| Qualquer dinheiro que entra e precisa sair parcialmente | Nunca movimente dinheiro em nome de um empregador que você ainda não conhece. Não há versão legítima disso na contratação |
| Fornecedor indicado por eles, pago por você | Empresa compra direto do fornecedor. Ponto |

#### 2.7 Empresa falsa clonando uma empresa real

Existe uma empresa de verdade. O golpista clona o site num domínio parecido (`empresa-careers.com`, `empresa.co`, `empresahiring.com`), cria um perfil de recrutador com o logo real e conduz o processo em nome dela. A vítima checa a empresa, encontra a empresa verdadeira, e conclui que está tudo certo.

| Sinal de alerta | Verificação que desarma |
|---|---|
| Domínio do e-mail difere do domínio institucional | Vá ao site oficial (busque, não clique no link do e-mail) e confira o domínio caractere por caractere. Hífens, `.co` vs `.com`, letras trocadas |
| E-mail gratuito (gmail, outlook, proton) | Recrutador de empresa real usa e-mail corporativo |
| A vaga não existe na página de carreiras oficial | Se não está no site oficial nem no ATS deles, a vaga não existe |
| Site clone com poucas páginas, sem blog, sem histórico | Cheque a idade do domínio (WHOIS) e o histórico no Internet Archive. Domínio de dois meses para empresa de dez anos é conclusivo |

Verificação decisiva: **entre em contato pelo canal oficial da empresa** — e-mail do site, LinkedIn corporativo verificado, ou um funcionário real que você encontrou por conta própria — e pergunte se aquela vaga e aquele recrutador existem. O golpe não sobrevive a esse cruzamento.

#### 2.8 A "entrevista" que só coleta dados

Processo inteiro conduzido, tempo investido, e o objetivo era apenas montar um dossiê: nome completo, documentos, histórico profissional detalhado, contatos de referência, endereço, às vezes uma foto sua com o documento na mão. Isso alimenta fraude de identidade e abertura de conta em seu nome.

Sinal característico: perguntas desproporcionalmente pessoais e desproporcionalmente pouco técnicas. Nome da mãe, escola onde estudou, primeiro emprego, cidade natal — o conjunto clássico de perguntas de recuperação de senha, embrulhado em "queremos te conhecer melhor".

Regra: entrevista de emprego pergunta sobre **trabalho**. Se o interesse pela sua biografia excede o interesse pela sua engenharia, algo está invertido.

---

### 3. Protocolo de verificação de uma oferta

Checklist prática. Rode antes de entregar qualquer coisa de valor — código executado, documento, dado bancário, ou aviso prévio no emprego atual.

**A empresa**
- [ ] Existe fora do LinkedIn: site próprio, produto real, clientes, imprensa, GitHub, blog de engenharia
- [ ] Domínio com idade compatível com a história que contam (WHOIS)
- [ ] A vaga está publicada na página de carreiras oficial, com o mesmo título e escopo
- [ ] Página do LinkedIn com histórico de posts, não criada há três semanas
- [ ] Encontro funcionários reais no LinkedIn, com perfis antigos e histórico coerente — não cinco perfis criados no mesmo mês

**O recrutador**
- [ ] Conta com mais de um ano de atividade, foto real, histórico de posts ou interações
- [ ] Conexões em número plausível para a senioridade (não 12, não só perfis estrangeiros aleatórios)
- [ ] Aparece como funcionário da empresa e a empresa o lista
- [ ] Busca reversa da foto de perfil não retorna banco de imagens ou outra pessoa

**O processo**
- [ ] Comunicação em e-mail corporativo, não em conta gratuita
- [ ] Convite de entrevista por ATS ou calendário corporativo
- [ ] Pelo menos uma videochamada com câmera aberta antes de qualquer entrega
- [ ] Existe etapa técnica conduzida por engenheiro
- [ ] Nenhuma pressa artificial; prazos razoáveis; recusa de prazo maior é bandeira

**O dinheiro e os dados**
- [ ] Nenhum pagamento seu, em nenhuma hipótese
- [ ] Nenhum documento ou dado bancário antes de contrato assinado
- [ ] Oferta formal por escrito, com CNPJ/entidade legal identificável, antes de qualquer compromisso seu
- [ ] Se há EOR (Deel, Remote, Oyster, Velocity Global), o convite chega **do domínio da plataforma** e você confirma no site oficial dela

**A segurança técnica**
- [ ] Nenhum código de terceiros executado fora de VM/container descartável
- [ ] Manifesto de dependências lido antes de instalar
- [ ] Nenhuma credencial sua presente no ambiente de teste

Se três ou mais itens falham, encerre. Um item isolado pode ser desorganização de startup; um padrão não é.

**A resposta de verificação.** Na prática você não precisa acusar ninguém nem sumir: precisa de uma resposta que seja cordial para um recrutador legítimo e intransponível para quem não é. Ela pede as três coisas que um golpe não consegue entregar — empresa nomeada, vaga no site oficial e e-mail corporativo — e adia qualquer entrega sua até uma videochamada. Use esta antes do modelo de resposta a recrutador de `networking-e-mensagens.md` §6.5, que assume legitimidade já verificada e entrega faixa salarial e disponibilidade de uma vez.

> Hi — thanks for reaching out. Happy to take a look.
>
> Before we go further, could you send me the company name and a link to the role on your careers page? I'd also prefer to keep this on email — feel free to write me from your company address.
>
> If it moves forward, I'd want a short video call with the hiring manager or someone from the engineering team before any technical exercise.
>
> Thanks.

Se voltar com nome de empresa, e-mail corporativo e a vaga publicada no site oficial, você tem um processo real e segue normalmente. Se voltar com pressa, desculpa para não usar e-mail ou insistência em Telegram, encerre — e não houve perda, porque não havia vaga. Confira o domínio caractere por caractere contra o site oficial que **você** buscou, não contra o link que ele mandou: existe a variante em que a empresa é real e o domínio foi clonado.

---

## Parte II — Dados pessoais

### 4. O que nunca vai no perfil público

| Nunca no perfil | Por quê |
|---|---|
| CPF, RG, passaporte, número de qualquer documento | Insumo direto de fraude de identidade. Nenhum benefício compensatório |
| Endereço residencial completo | Risco físico, e nenhum recrutador precisa |
| Telefone pessoal visível publicamente | Vira alvo de spam, phishing por SMS e tentativa de troca de SIM |
| Data de nascimento completa | Combinada com nome e cidade, é meio caminho para verificação de identidade em serviços |
| Foto de documento, crachá com número, ou carteira de trabalho | Expõe número de documento, empregador e dados de identidade de uma vez. Nenhum ganho compensa |
| E-mail pessoal principal em texto aberto | Use um e-mail dedicado à busca. Isola o spam e limita o dano |

**Entregar só depois do contrato assinado**: documento de identidade, comprovante de residência, dados bancários, dados de dependentes, informações fiscais.

### 5. EOR: pedido legítimo x golpe

Employer of Record é normal em contratação internacional — a empresa estrangeira não tem entidade no Brasil, então contrata via Deel, Remote, Oyster, Velocity Global, Globalization Partners e afins. Essas plataformas realmente pedem documento, comprovante de residência e dados bancários. O golpe imita exatamente isso.

Como distinguir:

| Legítimo | Golpe |
|---|---|
| Vem **depois** da oferta formal aceita, no onboarding | Vem durante as entrevistas, "para adiantar" |
| Link em domínio da própria plataforma (`deel.com`, `remote.com`), confirmado por você digitando o domínio no navegador | Link encurtado, domínio parecido, ou PDF/Forms |
| Você cria conta na plataforma e faz upload **você mesmo**, num portal com 2FA | Pedem que você envie foto do documento por chat ou e-mail |
| A plataforma tem contrato visível, suporte, e existe fora daquele processo | Plataforma que você nunca ouviu falar e cujo site tem três páginas |
| Nunca pedem dinheiro seu | Pedem taxa de setup, de compliance, de conversão |

Verificação decisiva: acesse a plataforma **digitando o endereço**, faça login pela porta da frente, e veja se o convite está lá. Se só existe no link que te mandaram, não existe.

---

## Parte III — Riscos de conta na plataforma

### 6. Automação, scraping e extensões

Ferramentas de auto-connect, envio automático de mensagens, scraping de perfis e extensões que "turbinam" o LinkedIn violam os termos de uso da plataforma sem ambiguidade. A detecção melhorou muito: padrão de requisição, cadência não-humana, endpoints acessados, fingerprint da extensão.

A consequência não é sempre imediata — e é exatamente esse atraso que faz a pessoa achar que "funciona". Funciona até virar restrição temporária, depois limitação permanente de funcionalidade, depois banimento.

### 7. Pods de engajamento e comportamento em rajada

Pod de engajamento é o grupo onde N pessoas curtem e comentam os posts umas das outras nos primeiros minutos. O algoritmo aprendeu a reconhecer o padrão: o mesmo conjunto de contas engajando reciprocamente, comentários genéricos, sincronia temporal. O resultado moderno é supressão de alcance — seus posts passam a performar pior do que performariam organicamente. Você paga para piorar.

Comportamento em rajada também dispara limites: 200 convites em uma tarde, 50 mensagens em uma hora, dezenas de perfis visitados por minuto. Convites em massa geram taxa alta de "não conheço esta pessoa", que é um sinal negativo forte.

Volume seguro, na prática: até cerca de 15 convites por semana, todos com nota, e atividade distribuída ao longo dos dias. O teto da plataforma é semanal e varia — quem precisa do número exato já está em volume alto demais. Cadência detalhada em `networking-e-mensagens.md`.

### 8. Conta restrita e recuperação

Restrição típica: você perde acesso, recebe pedido de verificação de identidade (documento, às vezes selfie), e entra numa fila de suporte que responde em dias ou semanas, com decisões pouco explicadas e recurso limitado. Não há SLA, não há ouvidoria, não há a quem apelar. Perfis com histórico de automação têm taxa de recuperação notavelmente pior.

**A assimetria que decide o assunto**: você constrói rede, histórico de recomendações, conexões com ex-colegas e prova social ao longo de anos. Uma ferramenta de automação te dá algumas semanas de atalho. Perder o primeiro para ganhar o segundo é uma troca terrível em valor esperado, mesmo que a probabilidade de punição fosse baixa — e ela não é. Some-se que, para quem busca trabalho no exterior, o LinkedIn muitas vezes é **o único** canal de descoberta funcional. Ficar sem ele no meio de uma busca é catastrófico.

Recomendação sem meio-termo: nada de automação, nada de scraping, nada de pod. Se o volume manual não é suficiente, o problema é o posicionamento do perfil, não a taxa de envio.

---

## Parte IV — Riscos de carreira do que você publica

### 9. O empregador atual

Post sobre a empresa onde você trabalha é sempre lido por três públicos que você não escolheu: seu gestor, o RH, e um futuro empregador daqui a três anos.

| Situação | Risco concreto | Recomendação |
|---|---|---|
| Crítica nominal ao empregador atual ou anterior | Queima com quem tem poder sobre sua referência; futuro recrutador projeta "vai falar de nós assim" | Nunca nomeie. Se precisa falar do problema, despersonalize e generalize |
| Screenshot de código proprietário | Violação de NDA. Rescisão por justa causa é possível, ação civil também | Nunca. Reescreva o exemplo do zero, com domínio fictício |
| Números internos (receita, usuários, churn, incidentes) | Confidencialidade; em empresa de capital aberto, potencialmente material não público | Só o que já é público em fonte oficial |
| Arquitetura interna detalhada | Cinza escuro. Muitos NDAs cobrem isso | Fale do padrão genérico, não da implementação da sua empresa |
| Anúncio de produto antes do lançamento oficial | Quebra de embargo. Consequência imediata | Espere o anúncio oficial e compartilhe-o |
| Discussão política partidária | Custo assimétrico: baixo ganho, perda real de parte do público e de recrutadores | Não no perfil profissional. Não é censura, é escolha de canal |
| Reclamação sobre colega, mesmo sem nome | O time reconhece. Sempre | Não publique |

### 10. Sinalizar busca de emprego estando empregado

Duas coisas diferentes, e a confusão entre elas custa emprego:

- **"Open to work" com moldura verde na foto**: público. Todo mundo vê, inclusive seu gestor — por isso é decisão situacional, e quem está empregado e discreto deve evitá-la.
- **"Open to work" restrito a recrutadores**: o LinkedIn oculta o sinal de recrutadores que trabalham na sua empresa atual. Não tem custo, então fica ligado sempre — procurando ou não.

Honestidade sobre a segunda: **não é garantia**. Recrutador de agência contratado pela sua empresa pode ver; a filtragem depende de o perfil dele estar corretamente associado à empresa; nada impede alguém de mostrar a tela para outra pessoa. Trate como redução de risco, não como sigilo.

Além disso, sinais indiretos vazam: atualização súbita do perfil inteiro, foto nova, headline reescrita, e um surto de conexões com recrutadores no mesmo mês. Gestor atento lê isso. Se você quer discrição, **desative as notificações de atualização de perfil antes de editar** e distribua as mudanças ao longo de semanas.

### 11. Permanência

O que você publica é permanente na prática. Print existe. Deletar remove da sua timeline, não da memória de quem viu nem do arquivo de quem salvou. Comentário em post alheio é ainda pior: fica no post do outro, indexado, fora do seu controle.

Teste antes de publicar, em uma pergunta: **isso me constrange se for lido em voz alta numa entrevista daqui a três anos, pelo entrevistador, com o nome da empresa citada presente na sala?** Se a resposta é sim, não publique.

### 12. O post de demissão ou layoff

É um dos posts de maior retorno que existe — a rede realmente ativa para ajudar. E é também um dos mais fáceis de errar, porque a emoção é recente.

**Ruim:**

> Depois de 3 anos de dedicação total, fui desligado da Vertexa hoje. Fui o cara que segurou o legado sozinho, virei noites em produção, e no fim quem decide não é competência, é política. Uma liderança que nunca entendeu tecnologia jogou fora o time que sustentava o produto. Se alguém aí souber de vaga, tô disponível — e dessa vez quero um lugar que valorize gente de verdade.

Por que falha: nomeia e acusa, transfere culpa, projeta amargura, sinaliza para o próximo empregador que o conflito viajará junto, e — o mais prático — **não diz o que a pessoa faz nem o que ela procura**. Quem quisesse ajudar não teria como.

**Bom:**

> Fui afetado pelo layoff da Vertexa esta semana, junto com outras 40 pessoas. Foram 3 anos muito bons: migrei nosso monólito Rails para serviços em Go, reduzi o p99 do checkout de 1.2s para 280ms e ajudei a formar dois engenheiros que hoje são plenos. Sou grato ao time.
>
> Agora estou procurando: backend sênior (Go, Node, Postgres, AWS), remoto, em empresa de produto — aberto a posições nos EUA e Europa, tenho inglês avançado e experiência de 4 anos em time distribuído.
>
> Se você souber de algo, ou puder me apresentar a alguém, respondo a todas as mensagens. Currículo no primeiro comentário.

Por que funciona: factual sobre o desligamento (layoff é estrutural, não pessoal — dizê-lo protege você), prova concreta de competência em três linhas, pedido específico o bastante para ser acionável, tom que um futuro gestor lê com tranquilidade.

Regras do formato: publique com um ou dois dias de distância emocional; não nomeie quem decidiu; inclua stack, senioridade e modalidade; termine com um pedido único e claro; responda todos os comentários nas primeiras 24h, que é quando o alcance existe.

---

## Parte V — Zonas cinzentas, com recomendação

Cada item traz a consequência prática, não o sermão. Todas têm recomendação fechada.

### 13. Inflar senioridade no título

Você é pleno e escreve "Senior Software Engineer".

Consequência prática: a entrevista técnica calibra para sênior. Você é avaliado contra expectativa de design de sistema, autonomia e mentoria, e reprova por um critério que não era o seu. Pior: quando a discrepância aparece só na verificação de referências ou no primeiro mês, a leitura não é "se superestimou" — é "mentiu no processo", e isso contamina tudo o mais que você disse.

**Recomendação**: use o título real. Se seu escopo excedia o cargo, escreva isso na descrição em vez do título: "Pleno com escopo de sênior: ownership do serviço X, on-call, mentoria de dois juniores". É verificável e vende melhor.

### 14. Declarar localização que não é a sua

Colocar "San Francisco Bay Area" ou "Lisboa" morando em Belo Horizonte, para passar em filtro de vaga.

Consequência prática: a maioria das vagas com filtro geográfico tem motivo legal ou fiscal — entidade jurídica, folha, obrigações trabalhistas, às vezes exigência de cliente ou de compliance. Você não fura o filtro; você desperdiça entrevistas até a etapa em que perguntam onde você reside, e aí a conversa termina com a percepção de que você fez o recrutador perder tempo deliberadamente. Em processo com background check, endereço declarado inconsistente é uma bandeira dura. E, quando a vaga era mesmo global, a mentira não trouxe nada, porque o filtro nunca teria te barrado.

**Recomendação**: declare sua localização real e resolva o filtro pelo caminho certo — "Brazil (UTC-3) · Remote, US/EU hours" na headline, e busque explicitamente empresas que contratam via EOR ou como contractor. Existe volume real nessa fatia.

### 15. Omitir um emprego curto

Três meses numa empresa que não deu certo, fora do perfil e do currículo.

Consequência prática: currículo não é declaração juramentada, e omitir experiência irrelevante é aceito. O risco surge quando a omissão cria **um buraco inexplicável** na linha do tempo ou quando o formulário oficial de contratação pede o histórico completo — aí a omissão vira declaração falsa em documento contratual, e é causa de rescisão em muitos contratos internacionais.

**Recomendação**: omita do LinkedIn se quiser; declare no formulário oficial de contratação e no background check, sempre. E tenha uma frase pronta e neutra caso perguntem: "não houve fit com a função, saí em três meses e o aprendizado foi ser mais específico sobre escopo na próxima escolha".

### 16. Arredondar datas

Jan/2021–Nov/2023 vira "2020–2024" para parecer quatro anos em vez de dois e dez meses.

Consequência prática: o LinkedIn só mostra mês e ano, então parece inofensivo. Mas verificação de emprego — feita por praticamente toda plataforma de EOR e por qualquer background check sério — retorna datas exatas do RH. Divergência de meses passa como arredondamento; divergência de mais de um ano é reportada como discrepância e cai na mesa do hiring manager já com a oferta emitida.

**Recomendação**: datas reais. Se o total de experiência é o problema, some corretamente contando freelance, projeto próprio e trabalho paralelo relevante — quase sempre o número real é maior do que a pessoa imagina.

### 17. Foto gerada por IA

Consequência prática: o custo não é ético, é de reconhecimento. Foto de IA tem artefatos que muita gente detecta hoje — e a videochamada te desmente em dois segundos, o que gera exatamente a sensação de que "essa pessoa se apresenta como não é" no momento mais delicado do processo. Retoque leve e fundo removido são aceitos e ninguém liga. Rosto sintético é outra categoria.

**Recomendação**: foto real, sua, recente. Luz de janela, celular, camisa lisa, fundo limpo, enquadramento do peito para cima. Custa dez minutos e supera qualquer geração.

### 18. Perfil escrito inteiramente por LLM

Consequência prática: o texto fica competente e genérico, e genérico é a única falha fatal do perfil — recrutador lê dezenas por dia e o seu precisa ter aresta. Além disso, o "Sobre" costuma virar pauta de entrevista; quando você não consegue defender ao vivo, no seu inglês real, a densidade e o registro do que está escrito, o contraste é péssimo.

**Recomendação**: use LLM para estruturar, cortar e revisar — não para inventar substância. O material bruto (números, decisões, contexto, opinião) tem que ser seu. Teste final: leia em voz alta. Se não soa como você falando, reescreva.

### 19. Comprar seguidores ou conexões

Consequência prática: pior custo-benefício da lista. Contas compradas não engajam, então sua taxa de engajamento despenca e o alcance dos seus posts cai — você paga para ser menos visto. É visualmente óbvio para qualquer recrutador (12 mil seguidores, 4 curtidas por post). E é violação de termos, com risco de restrição.

**Recomendação**: não. Rede pequena e relevante bate rede grande e falsa em toda métrica que importa.

### 20. Certificação não concluída listada como concluída

AWS Solutions Architect na seção de licenças, prova não prestada.

Consequência prática: é o item mais facilmente verificável de todos — certificadoras mantêm registro público e o número de credencial é conferível em segundos. E é o único da lista que muitos contratos internacionais tratam explicitamente como misrepresentation, ou seja, causa de rescisão com efeito imediato mesmo depois de meses de casa. Custo alto, ganho quase nulo, detecção trivial.

**Recomendação**: nunca. Se está estudando, isso tem lugar próprio: "AWS Solutions Architect Associate — em preparação, prova marcada para março" na seção de formação ou no Sobre. Isso soa bem e é verdade.

---

## Parte VI — Overemployment

Dois empregos remotos em tempo integral, simultâneos, sem conhecimento de nenhum dos dois.

**O que o contrato costuma dizer.** Contratos internacionais de tempo integral quase sempre trazem alguma combinação de: cláusula de exclusividade ou de dedicação integral; obrigação de declarar atividade externa e obter aprovação prévia; cláusula de não concorrência limitada ao setor; e cláusula de propriedade intelectual redigida de forma ampla, cobrindo o que você desenvolve durante a vigência. Contratos via EOR replicam isso e frequentemente endurecem, porque a plataforma carrega o risco de compliance.

**Os riscos reais**, em ordem de probabilidade:

1. **Detecção trivial.** Fusos incompatíveis, reuniões sobrepostas, latência de resposta, disponibilidade errática. Gestor sênior reconhece o padrão rápido.
2. **Cruzamento administrativo.** EOR, folha, seguro, benefícios, declaração fiscal e verificação de emprego cruzam dados entre si com mais frequência do que se imagina.
3. **Rescisão por justa causa**, com perda de qualquer valor não pago, de stock options não vested e, dependendo do contrato, obrigação de devolver valores.
4. **Contaminação de propriedade intelectual.** Código escrito com sobreposição de vigências cria uma disputa de titularidade que pode envolver as duas empresas — o cenário mais caro de todos.
5. **Queima reputacional.** O mercado de remoto internacional para devs brasileiros é menor do que parece; recrutadores conversam.

Também vale dizer o óbvio operacional: dois empregos full-time raramente rendem duas entregas boas. O modo de falha típico não é ser descoberto — é ter desempenho medíocre nos dois e ser desligado por performance de ambos.

**Posição desta skill**: não vou ajudar a montar disfarce, calendário de cobertura, narrativa de perfil para ocultar vínculo, nem estratégia para driblar verificação de emprego. Isso significa ajudar alguém a violar contrato assinado, e a assimetria de risco cai inteiramente sobre quem me pediria.

O que eu ajudo, com prazer: negociar remuneração no emprego atual com dados de mercado; estruturar consultoria ou freelance **declarado e aprovado**, que é legítimo e comum; avaliar troca de emprego; e posicionar o perfil para uma vaga melhor pagante em vez de duas medianas.

---

## Parte VII — Discriminação e o que você não é obrigado a informar

A prática brasileira normalizou coisas que, no processo norte-americano e em boa parte do europeu, são bandeiras vermelhas — e que só te expõem.

| Informação | Norma brasileira | Norma EUA/UE | Recomendação |
|---|---|---|---|
| Foto no currículo | Comum | Evitada nos EUA (risco de viés e de exposição legal do empregador); alguns RHs descartam o CV | LinkedIn: sim, foto. Currículo para vaga internacional: sem foto |
| Idade / data de nascimento | Comum | Não se pergunta; discriminação etária é ilegal nos EUA | Fora do perfil e do currículo |
| Estado civil, filhos | Comum | Não se pergunta; pergunta é imprópria | Nunca informe, e não é rude não responder |
| Nacionalidade e status de trabalho | Comum | Pode-se perguntar se você está autorizado a trabalhar; não se pergunta origem | Diga o essencial: "Brazil-based, available as contractor / via EOR" |
| Ano de formatura | Comum | Frequentemente omitido, porque revela idade | Pode omitir. Mantenha instituição e curso |
| Gênero, religião, orientação | Ocasional | Não se pergunta | Só se você quiser, por escolha própria |

Duas consequências práticas para o perfil: **tire ano de formatura e qualquer marcador etário se você tem 45+ ou 22 anos** — os dois extremos sofrem filtro informal; e **mantenha só os últimos 10-15 anos de experiência**, resumindo o resto em uma linha. Isso não é omissão desonesta; é a convenção do mercado que você está mirando.

Se perguntarem algo impróprio numa entrevista (idade, filhos, planos de gravidez, estado civil), duas coisas: você não é obrigado a responder, e a pergunta é informação valiosa sobre a empresa. Resposta que funciona sem criar atrito: "prefiro focar na parte técnica — sobre a disponibilidade, consigo cobrir de 9h a 18h no fuso de vocês sem problema". Redireciona para o que de fato importa e responde a preocupação real por trás da pergunta.

---

## Parte VIII — Assédio e mensagens inadequadas

O LinkedIn tem volume relevante de mensagens impróprias, sobretudo para mulheres: cantada disfarçada de networking, insistência depois de recusa, comentário sobre aparência, e o clássico "oportunidade" que é esquema de pirâmide ou marketing multinível.

Protocolo, sem drama:

| Situação | Ação |
|---|---|
| Mensagem inadequada isolada | Não responda. Responder alimenta. Bloqueie |
| Insistência depois de recusa | Bloquear e denunciar. Bloqueio remove o acesso ao seu perfil |
| Comentário público inadequado no seu post | Delete o comentário, bloqueie o autor. Não debata na thread — o debate dá alcance ao comentário |
| Assédio vindo de alguém da sua empresa ou de parceira | Screenshot com data, URL e nome antes de bloquear. Reporte internamente pelo canal formal |
| Ameaça, chantagem, extorsão (inclusive sextorsão) | Não pague, não negocie, não delete. Preserve tudo, denuncie na plataforma e registre boletim de ocorrência |
| MLM / "oportunidade de negócio" | Ignore e bloqueie. Não existe versão dessa conversa que termine bem |

Quando **responder**: só quando houver ambiguidade genuína e valor profissional real na relação. Um "obrigado, mas prefiro manter a conversa no profissional" resolve o mal-entendido honesto. Quem não era honesto vai insistir — e aí a resposta é bloqueio, não segunda tentativa.

Higiene preventiva que reduz muito o volume: restrinja quem pode te enviar mensagem, desative o "quem viu seu perfil" público, não exponha telefone, e limite a visibilidade de conexões.

---

## Regras de segurança, em uma lista curta

Memorize estas dez. Elas cobrem quase tudo que este documento detalhou.

1. **Nunca rode código de processo seletivo na sua máquina.** VM ou container descartável, sem credenciais dentro, sempre.
2. **Leia o manifesto de dependências antes de instalar.** Instale com scripts desativados.
3. **Dinheiro só flui do empregador para você.** Qualquer pagamento seu é golpe.
4. **Documento e conta bancária só depois de contrato assinado**, e só no portal oficial da plataforma, acessado por você digitando o endereço.
5. **Exija uma videochamada com câmera** antes de entregar qualquer coisa de valor. Recusa encerra o processo.
6. **Confira a vaga no site oficial da empresa** e o domínio do e-mail, caractere por caractere.
7. **Urgência é ferramenta de golpe.** Pressa para fechar hoje é motivo para desacelerar, nunca para acelerar.
8. **Nada de automação, scraping ou pod.** Semanas de atalho não valem anos de rede.
9. **Publique como se fosse lido em voz alta numa entrevista daqui a três anos.** Print existe; deletar não apaga.
10. **Tudo verificável, verifique-se sozinho.** Título, datas, certificação e localização são conferidos por rotina — a mentira barata é a que custa a oferta já assinada.

E a regra que resume as dez: **se a oportunidade só sobrevive enquanto você não verifica, ela não é uma oportunidade.**
