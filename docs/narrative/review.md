# Revisão narrativa dos textos do jogo (#64)

Base: `docs/narrative/lore.md` (Bíblia), `narrative-design.md` (escada §7, regra de consistência §14),
`bento-nick-arc.md`, `corridor-progression.md`, `AGENTS.md` ("Narrativa e coerência visual").


> **Estado (24/10):** os 17 erros claros da seção 2 estão corrigidos no jogo. A descrição da fase 5 entra no `en.po` com
> as telas da #35, e "Guard Dog" passou a "Protector Dog". `tests/test_narrative_terms.gd` impede a volta dos termos
> descontinuados (Programa Continuidade, guerra, aprendizagem, VIGIA, Théo, "(provisório)") e confere que os nomes
> próprios dos textos dos dados e das fases estão em `known_names.txt` (a seção 5) ou nos próprios dados. No mapa, a
> fase bloqueada não mostra mais a descrição (que conta a camada da história dela). As perguntas da seção 3 e
> a progressão da seção 4 (os eventos de história fora do sorteio e a linha "O que a equipe viu" no relatório) esperam
> o Lucas na issue #64.

## 1. Resumo

- **Textos revistos:** cerca de 520. São as 5 fases (`PHASES`), os 10 nós (`expedition-nodes.json`), os 10 eventos (cerca de 60
  textos), os 14 resultados de busca, os 26 inimigos e as 45 ações deles, as 6 classes e as 24 habilidades, as relíquias,
  os perks e as pesquisas, os 3 civis, os bancos de nomes, as 10 dicas, o Próximo passo, o relatório da volta, o mapa de
  fases, o corredor, o HUD, os nomes dos cenários e das zonas e, no `en.po`, só o desvio de sentido.
- **Erros claros:** 17 (tabela 2). Os mais graves:
  - o **Programa Continuidade** (descontinuado pela Bíblia, §29) aparece na fase 3;
  - "**a guerra**" é dada como origem da ordem do Porteiro e da falha das máquinas, em 4 textos;
  - o **Eco** é tratado como mistério do mundo;
  - a fase 4 retoma a explicação descontinuada por "interfaces e aprendizagem";
  - textos de tela prometem algo que o jogo não faz ("Risco vai se juntar", "seus Condutores", "Bento" e "Íris" fixos
    numa classe, "(provisório)" na tela).
- **Perguntas para o Lucas:** 18 (tabela 3).
- **Achado estrutural:** os três eventos de história (`porta_espera`, `voz_interfone`, `sobrevivente_tuneis`) e o
  `expedition-nodes.json` **não são alcançáveis no jogo da Godot**. `AHJourneyRules.event_pool` só sorteia eventos
  `busca_*`, e o nó só é lido para os perfis de `encounters.json`. Por isso, hoje as fases 2 a 5 **não contam a parte delas
  da escada**: o que o jogador lê é só a descrição da fase (mapa e Próximo passo), e o relatório da volta não tem nenhuma
  linha narrativa (tabela 4).

## 2. Erros claros

| Onde | Texto atual (curto) | Problema | Correção proposta |
|---|---|---|---|
| `scripts/flow/journey_rules.gd:35` (descrição da `fase_3`, mostrada no mapa e no Próximo passo) | "Uma placa do Programa Continuidade aponta para o subsolo. Os registros não dizem quem retornou." | §14.1 contradiz a Bíblia: `lore.md` §29 remove "o **Programa Continuidade** como explicação central do desaparecimento humano". §14.2 revela cedo: "quem retornou" aponta para humanos que voltaram, que é assunto da fase 5 (`narrative-design.md` §7, "Fase 5 — Presença humana"; §10, "O primeiro humano não deve aparecer cedo"). A fase 3 é a da **Origem**. | "Atrás da porta lacrada de uma Toca dos Antigos, um Arquivo de fichas: cães, gatos e outros bichos, medidos e numerados. Ninguém na Estação sabe por que os Antigos nos estudavam." (no jogo, "outros bichos" no lugar de "roedores", até o Lucas decidir a espécie da Íris, seção 3) |
| `data/expedition-nodes.json` `node_2_event` (Description) | "Uma placa do Programa Continuidade aponta para o subsolo…" | O mesmo da linha acima (`lore.md` §29). | "A placa desbotada aponta para o subsolo: ZONA SANITÁRIA. Os registros falam de quarentena, não de quem saiu." |
| `scripts/flow/journey_rules.gd:39` (descrição da `fase_5`) | "…o Porteiro conserva uma ordem de isolamento da guerra." | §14.1 contradiz: a ordem nasceu na pandemia. `lore.md` §9: "Durante a pandemia, animais eram classificados como possíveis vetores biológicos. Instalações humanas receberam ordens rígidas…". §29 descontinua "a queda causada primariamente por… conflito político". Os conflitos só "aceleraram o colapso" (§4). | "Bombas antigas mantêm a água em movimento. Na eclusa central, o Porteiro guarda uma ordem de contenção da Peste que ninguém cancelou." |
| `data/expedition-nodes.json` `node_9_boss` | "O Porteiro conserva uma ordem de isolamento da guerra. Seus relés…" | O mesmo (`lore.md` §9 e §29). | "O Porteiro guarda uma ordem de contenção da Peste que ninguém cancelou. Seus relés sustentam a defesa da eclusa." |
| `data/enemies.json:156` (`porteiro`) | "Ainda executa a ordem de isolamento dada durante a guerra; na segunda fase…" | O mesmo (`lore.md` §9: "Décadas depois, esses protocolos continuam ativos"; §9: "obedecem a uma ordem que ninguém cancelou"). | "Guardião industrial da eclusa, formado por portas blindadas, pistões e uma lente central de vigilância. Ainda executa a ordem de contenção dada durante a Peste; na segunda fase, abandona a contenção e ativa força letal." |
| `data/enemies.json:124` (`carcaca_colonizada`, Coletor de Sucata) | "A guerra deixou sua identificação defeituosa: trata seres vivos como material recuperável." | §14.1: a falha da máquina vem da degradação. `lore.md` §10.3: "Décadas sem manutenção corromperam bancos de dados e rotinas." | "…braços de coleta. Décadas sem manutenção corromperam sua identificação: trata seres vivos como material recuperável." |
| `data/enemies.json:25` (`robot_fungo`) | "…a colonização visível não explica o Eco nem prova quem o comanda." | §14.1: `lore.md` §29 descontinua "o **Eco** como eixo principal do mistério do mundo". O texto trata "o Eco" como um mistério que o jogador deveria resolver. | "Umidade e fungos cobrem este chassi de serviço. Ele continua executando rotinas de contenção, sem saber que ninguém mais as confere." |
| `scripts/flow/journey_rules.gd:37` (descrição da `fase_4`) e `data/expedition-nodes.json` `node_5_combat` | "Restam interfaces de comunicação e anotações de aprendizagem…" | §14.1: `lore.md` §29 descontinua "a transformação animal explicada apenas por aprendizagem, interfaces e cultura sem programa biológico dirigido". Além disso, a fase 4 é a da **Contradição sobre a Peste** (`narrative-design.md` §7), e o texto não conta isso. | Fase: "Na Casa de Vidro silenciosa, dois relatórios sobre a Peste não batem: um culpa os animais portadores, o outro para no meio. As máquinas da triagem só conhecem o primeiro." Nó: "Restam bancadas, ampolas e relatórios sobre a Peste. Os papéis não contam a mesma história." |
| `scripts/ui/phase_map.gd:270` | "O Porteiro e seus Condutores guardam a eclusa." | §14.4 promete algo que não existe: na luta, os ajudantes se chamam "Relé de Defesa Alfa/Beta" (`enemies.json` `condutor_raiz`). "Condutores" é um nome antigo que o jogador nunca vê. | "O Porteiro e seus Relés de Defesa guardam a eclusa." |
| `data/enemy-actions.json:603` (`enraizado.golpe_provisorio`, DisplayName que flutua na tela da fase 2) | "Golpe de Raízes (provisório)" | §14.4: um rótulo de desenvolvimento aparece na luta (o Enraizado está em `encounters.json` `fase_2`). A descrição também é nota interna ("Não faz parte do kit conceitual aprovado…"). | DisplayName: "Golpe de Raízes". Description: "Açoita a linha de frente com raízes presas ao chassi." (o nome final está na tabela 3) |
| `data/events.json:76` (`sobrevivente_tuneis`, `alimentar_rato`) | "Encontro vocês na Estação Raiz!" (…) "Risco vai se juntar ao refúgio." | §14.4 promete o que não acontece: `RecruitName` não é lido e o efeito só libera a classe (`journey_rules.gd:932-934`). Para ter o guaxinim, é preciso recrutá-lo por 10 sementes, e ele fica na Estação sem arte de combate (`station_rules.gd:916-923`). | "O guaxinim guarda uma ração e volta a desmontar o terminal. \"Sou Risco. Ainda tem energia útil nessas máquinas, e eu sei tirar sem acordar ninguém. Se a Estação Raiz tiver lugar, me procurem.\" (Classe Guaxinim Sabotador liberada: dá para recrutar um guaxinim na Sala dos Personagens.)" (no jogo, "um guaxinim": o nome do recruta é sorteado" |
| `data/abilities.json:52` (`cao_fique_atras_de_mim`) | "Protege um aliado até o início do próximo turno de Bento; Bento recebe 1 Bloqueio." | §14.5 (individualidade): a habilidade é da classe `cao`, e os recrutas se chamam Brutus, Argos… (`station_rules.gd:101`). Com outro cão, o texto fala de Bento. | "Protege um aliado até o início do próximo turno do cão; o cão recebe 1 Bloqueio." |
| `scripts/ui/inventory_panel.gd:85,86,215` | "Ampola da Íris" / "Habilidade da Íris: cura um aliado orgânico…" | §14.5: `exploration_care.gd:39` aceita **qualquer** sapo vivo, e há recrutas sapo (Minerva, Atena…). | Nome: "Ampola de Reparo". Texto: "Habilidade do sapo: cura um aliado orgânico. Recarrega após uma vitória." |
| `scripts/flow/exploration_care.gd:86` | "Íris precisa estar viva e na equipe." | O mesmo. | "Um sapo vivo precisa estar na equipe." |
| `scripts/flow/exploration_care.gd:96` | "Sem cargas. Íris recarrega após uma vitória." | O mesmo. | "Sem cargas. A ampola recarrega após uma vitória." |
| `scripts/flow/station_rules.gd:71` (Dora, `need`) | "Quer recuperar um caderno de receitas numa cozinha abandonada." | §14.4: não existe cozinha. O pedido sai da mercearia (`FOCI`: `request_civil_dora`, shop 0, "as prateleiras"). | "Quer recuperar um caderno de receitas esquecido numa mercearia abandonada." |
| `scripts/flow/journey_rules.gd:39` (texto PT da `fase_5`) e `data/i18n/en.po` | (a descrição da fase 5 não está no PO; só a versão do `node_9_boss` está) | A descrição da fase 5 fica sem tradução. Não é desvio de sentido, mas vale corrigir junto com o texto novo. | Depois de trocar o texto, rodar `tools/i18n_update.gd` e traduzir: "Old pumps keep the water moving. In the central lock, the Gatekeeper keeps a Plague containment order that no one ever cancelled." |

Desvio de sentido no `en.po` (breve): o resto bate com o português. Há um caso de ajuste: "Cão Protetor" → "Guard Dog" puxa
para cão de guarda (o animal de estimação que serve), e a lore diz que, para Bento, "proteger o grupo é… responsabilidade
central" (§15.1). A proposta é "Protector Dog". Quando os textos acima mudarem, as entradas antigas ("Continuity
Program", "from the war", "the Echo", "learning notes") somem com o `i18n_update`.

## 3. Perguntas para o Lucas

| Onde | O que decidir | Proposta (com o texto sugerido) | Por quê |
|---|---|---|---|
| `data/initial-heroes.json` e `classes.json` (`sapo` = Íris) | **Íris é sapo no jogo e roedora na lore.** `lore.md` §15.3: "Populações de roedores… A cultura de Íris valoriza preparação, informação…". | Manter o jogo (arte, sons e ids já existem) e revisar a lore §15.3: tirar Íris dos Roedores e dar a ela uma cultura anfíbia, por exemplo "Íris cresceu entre canais e cisternas; valoriza preparação, informação e química de sobrevivência". A decisão é do Lucas. | É a maior contradição entre a lore e o jogo. Afeta o teste de nomes e qualquer fala futura da Íris. |
| `initial-heroes.json` (`coruja` = Véspera) | **Amora (capivara) não está no jogo, e Véspera não está na lore.** O arco inicial é Bento, Íris e Amora com Nick (`bento-nick-arc.md` §3, §21). | Registrar Véspera na lore (espécie, cultura, papel) e dizer se Amora entra depois. Sugestão para a lore: "Véspera, coruja das torres de vigia da Estação, observa antes de opinar". | Hoje o quarteto do jogo não é o do arco. Uma cena do resgate de Íris e Amora não fecha com o elenco. |
| `classes.json` (`gato` "Gato Assassino", `coruja` "Coruja Sniper") | Tom dos nomes de classe. | "Gato Batedor" (Nick lê rotas e encontra a saída) e "Coruja Atiradora". | `lore.md` §15.2: o felino é marcado por "exploração individual… leitura constante do ambiente"; §27: "Espécie influencia cultura… não moralidade". "Assassino" vai contra o Nick do arco. |
| `scenarios.json` `estacao-raiz`, títulos e dicas ("Estação Raiz") | **O nome da comunidade.** A lore só diz "a Estação" (`bento-nick-arc.md` §3; `lore.md` §17). | Manter "Estação Raiz" e acrescentar em `lore.md` §17: "A comunidade chama sua casa de Estação Raiz, pelas raízes que atravessam a plataforma." (eco de §13, "Raízes atravessaram estações") | "Raiz" pode ser lida como laço com a **Raiz Livre** (§14.3), que rejeita a tecnologia humana, quando a comunidade de Bento é **Remendadora** (§14.1). Precisa estar escrito para não virar confusão. |
| `phase_map.gd:119`, `combat_engine.gd:344` ("Bairro Submerso") | Registrar a região. | Acrescentar à lore: "Bairro Submerso: a região alagada ao redor da Estação, ligada por trilhos, cais e túneis." | O nome só existe no jogo. |
| `PHASES` `fase_4` (nome "Laboratório Silencioso", mapa `TriageGate` "Portão de Triagem") | O nome da fase e o lugar que o jogador vê ("Local: Portão de Triagem") não batem. | Ou "Portão de Triagem" como fase com o laboratório atrás dele (a descrição da tabela 2 já fala da "triagem"), ou um mapa de laboratório. | `narrative-design.md` §2: "a missão imediata deve continuar clara". O jogador lê "laboratório" e anda num portão. |
| `PHASES` → escada de revelações | **O mapeamento fase do jogo → camada da escada.** A proposta usa 1 Sobrevivência, 2 Despertar, 3 Origem, 4 Contradição, 5 Presença humana. | Confirmar o 1:1. A alternativa é a escada correr ao longo de mais fases (o mapa tem só 5) e a 6–7 ficar para depois. | A escada (§7) tem 7 camadas. O jogo tem 5 fases. |
| `enemies.json` `porteiro` | **O papel do Porteiro.** É um Sistema de Segurança (§10.1) ligado ao VIGIA? A vitória sobre ele mostra o primeiro sinal da fase 5? | Sim: "um dos portões do VIGIA". Na vitória, mostrar a linha "AUTENTICAÇÃO HUMANA VÁLIDA · registro recente" (tabela 4). Descrição: a da tabela 2. | `lore.md` §11: "Grande parte dos sistemas… responde a… VIGIA"; §25.4: "O jogador inicialmente sabe apenas que houve uma autenticação humana válida". Encaixa no fim da fase 5 sem revelar Théo (`bento-nick-arc.md` §11: "não deve ser revelada… de forma antecipada"). |
| `enemies.json` `nucleo_nulo` "Núcleo Nulo", "Chefe de interferência (teste)" | **O papel do Núcleo Nulo.** Não pode ser "o VIGIA" encarnado. | Torná-lo um Sistema Degradado (§10.3): "Núcleo de uma central esquecida. Mistura ordens de décadas diferentes e transmite todas ao mesmo tempo." | §10: "As IAs não são uma só"; §27: "A IA não é simplesmente vilã". Um chefe "VIGIA" revelaria cedo e simplificaria. |
| `enemies.json` `enraizado` e a ação `golpe_provisorio` | O que é o Enraizado (Category Machine) e o nome final do golpe. | "Enraizado: máquina de jardinagem dos Antigos tomada por raízes; ainda poda o que considera praga." Golpe: "Açoite de Raízes". | Hoje não há descrição de lore. O "(provisório)" vai sair (tabela 2). |
| `enemies.json`: os vilões do John (`recreador`, `pipoco`, `carrasco_industrial`, `faisca`, `broto`; o Enraizado acima) | Descrições de lore. Hoje todos têm "Protótipo jogável para teste isolado…", e eles **lutam** nas fases 1, 2 e 5 (`encounters.json`). | Recreador: "Robô de festas do cinema. Repete a rotina de animar crianças que não vêm há gerações." Pipoco: "Carrinho de pipoca do Recreador; ainda estoura o que encontra." Carrasco Industrial → "Demolidor Industrial": "Máquina de demolição que segue derrubando o que o plano antigo mandava derrubar." Faísca: "Serra auxiliar do Demolidor." Broto: "Muda de raízes que segue o Enraizado." | §10.3: "Algumas repetem rotinas humanas como rituais mecânicos". §27: "As máquinas não são necessariamente malignas". "Carrasco" pinta a máquina como algoz. |
| `enemies.json` `remendador` | O inimigo tem o nome de uma facção animal. | Renomear o DisplayName para "Soldador" (o id `remendador` fica). | `lore.md` §14.1: "Os Remendadores", a filosofia da comunidade de Bento. Uma máquina hostil com esse nome confunde. |
| `enemies.json` `hospede_rubro`, `felina_ferro`, `patinadora_choque`, `ilusionista_sucata`, `acoplador`, `eco_01..03` ("Eco de Sucata") | Estes não estão em nenhum encontro. Entram na campanha? Com que história? | Deixar fora do teste de nomes até ter lore. Para os Eco-0x, "Eco" vale como nome local (`lore.md` §29: "Elementos antigos podem continuar existindo como nomes locais"). | Evita texto de protótipo em produção. |
| `station_rules.gd:101-106` (`NAME_POOLS`) | Nomes de recruta tirados da cultura humana (Snoopy, Pluto, Zelda, Thor, Loki, Bastet, Hórus, Atena, Minerva, Salem, Félix, Max, Jasper, Titan, Squeeze), mais "Vigília" e "Eco". | Trocar por nomes que a comunidade daria, de objetos, lugares e traços: Snoopy→"Farol", Pluto→"Trilho", Zelda→"Antena", Thor→"Pistão", Loki→"Fresta", Bastet→"Telha", Hórus→"Mirante", Atena→"Cisterna", Minerva→"Lupa", Salem→"Breu", Titan→"Bigorna", Squeeze→"Pinça", Vigília→"Sentinela" (Vigília lembra o VIGIA). | §13: "o conhecimento sobre sua função original se fragmentou"; §15.4: interpretação animal "não de conhecimento correto sobre a cultura humana". Alguns são marcas registradas. |
| `data/events.json:290-296` (`busca_choro_porta`, `prometer_voltar`) | A promessa nunca volta. O filhote fica para sempre atrás da porta. | Opção A: um evento seguinte na mesma fase, com o pé de cabra ("A porta do filhote, de novo"). Opção B: trocar a escolha por "Passar comida pela fresta e seguir" → "A equipe empurra uma ração por baixo da porta. O choro para por um momento. (−1 Comida, −5 de Esperança)". | `narrative-design.md` §12: "Evitar escolhas que parecem importantes mas nunca reaparecem"; §14.6. |
| `events.json` `porta_espera`, `voz_interfone`, `sobrevivente_tuneis` | Eventos de história fora do jogo. Em que fase cada um entra? | `voz_interfone` → fase 2 (é o "PROTOCOLO DE PRESERVAÇÃO HUMANA ATIVO" de `lore.md` §19); `porta_espera` → fase 3 (Abrigo Lacrado, Arquivo); `sobrevivente_tuneis` → fase 5 (Dutos de Esgoto). Um evento fixo por fase, num trecho de pausa. | Sem eles, a escada não chega ao jogador (tabela 4). |
| `station_rules.gd:36` ("Sala dos Personagens") e `:40` ("Bar") | Nome de sala que não pertence ao mundo ("Personagens" é termo de UI). | "Alojamento" (ou "Sala do Elenco"); manter "Bar". | §13 (tom): "O mundo precisa parecer vivido". |
| `data/relics.json:5,11` | "época dos humanos" e "vidro de laboratório aerodinâmico". | "Um talismã sólido do tempo dos Antigos." e "Cortada do vidro de uma Casa de Vidro." | Vocabulário do novo mundo (§16). "Aerodinâmico" não quer dizer nada para um vidro. É ajuste de tom, por isso fica aqui. |

### Respostas aplicadas (24/10, rodada 2 da #64)

O Lucas pediu para seguir com as propostas desta tabela e, onde não havia, fazer uma para ele revisar. Marcado
**(proposta do Claude)** o que não estava na revisão.

1. **Íris:** fica sapo. Lore §15.3 sem a Íris; §15.5 nova, Povos dos Canais (anfíbios), com a cultura dela.
2. **Véspera e Amora:** Véspera entra na lore (§15.6, Aves das Torres). Amora continua na lore e no arco e entra no jogo
   quando o arco do resgate for jogável **(proposta do Claude)**.
3. **Classes:** "Gato Batedor" e "Coruja Atiradora" (e os papéis "Batedor e Mobilidade", "Atiradora e Controle"); ids
   iguais.
4. **Estação Raiz:** fica; lore §17 explica o nome (as raízes da plataforma) e que não tem ligação com a Raiz Livre.
5. **Bairro Submerso:** entra na lore §17.
6. **Fase 4:** o nome fica "Laboratório Silencioso": a descrição já põe o laboratório (a Casa de Vidro) atrás do Portão
   de Triagem, e trocar o nome mudaria o que os memoriais já gravaram **(proposta do Claude)**.
7. **Escada × fases:** 1:1, registrado em `narrative-design.md` (seção "No jogo da Godot"); as camadas 6 e 7 ficam
   para quando o mapa crescer.
8. **Porteiro:** um dos portões de VIGIA (lore §11, sem citar VIGIA na tela); a vitória sobre ele traz a linha da
   autenticação humana (item 16).
9. **Núcleo Nulo:** Sistema Degradado (lore §10.3), com a descrição proposta; "(teste)" saiu do papel.
10. **Vilões do John:** as descrições propostas; "Carrasco Industrial" virou "Demolidor Industrial" (id igual); o
    Enraizado ganhou descrição e o golpe virou "Açoite de Raízes".
11. **Remendador:** "Soldador" na tela (id igual), com descrição **(proposta do Claude)**.
12. **Inimigos fora dos encontros:** continuam fora da campanha; nada mudou **(proposta do Claude)**.
13. **Nomes de recruta:** os da tabela; e **(proposta do Claude)** Max→Brasa, Félix→Calha, Jasper→Lampião, e o recruta
    Faísca→Centelha (Faísca é inimigo). Quem já foi recrutado mantém o nome.
14. **Filhote de lontra:** **(proposta do Claude)** nem A nem B, para não mexer em números: a escolha virou "Passar o que
    der pela fresta e seguir", sem promessa, com o mesmo −5 de Esperança.
15. **Eventos de história:** um por fase na primeira Passagem no mapa da fase (não na travessia), uma vez por campanha
    (o Sobrevivente dos Túneis volta até o guaxinim ser liberado, para a classe não se perder de vez) (fase 2: Voz no Interfone;
    3: A Porta que Ainda Espera; 5: Sobrevivente dos Túneis). A "Voz no Interfone" prometia uma luta que o jogo nunca
    começava: **(proposta do Claude)** "Seguir o sinal" agora leva ao painel de contenção e mostra o visor, sem luta.
16. **"O que a equipe viu":** a linha no relatório da primeira vitória de cada fase, gravada no save
    (`station.story_reports`, saves antigos ganham a lista vazia). As linhas das fases 3 e 4 que citavam a Íris
    ficaram sem nome, porque ela pode não estar na equipe **(proposta do Claude)**.
17. **"Sala dos Personagens":** "Alojamento" (id igual). A Mochila dizia para equipar a relíquia "no Depósito do
    refúgio"; é no Alojamento.
18. **Relíquias:** "do tempo dos Antigos" e "Cortada do vidro de uma Casa de Vidro".

As descrições das fases 1, 2 e 5 e o Próximo passo final ("Os Antigos ainda existem?…") são as da seção 4.

## 4. Progressão das fases

| Fase | O que a escada pede (`narrative-design.md` §7) | O que os textos do jogo contam hoje | O que falta (proposta concreta) |
|---|---|---|---|
| 1 · Rua das Vitrines (Sobrevivência) | A comunidade depende de tecnologia antiga; os recursos estão acabando; as máquinas são perigosas; os humanos são tidos como desaparecidos. "Como manter nossa comunidade viva?" | Descrição: vitrines com suprimentos, sensores que separam "clientes humanos" de "fauna". O mapa fala da Estação ("ferramentas herdadas"). Civis, comida e água no ciclo. Buscas (`desenho_casa`, `pote_sementes`). | **Descrição:** "Vitrines tomadas por raízes ainda guardam comida e peças que a Estação não sabe mais fabricar. Os sensores das Galerias seguem separando clientes dos Antigos de fauna não autorizada." **Relatório da volta (vitória, 1ª vez):** "A Estação aguenta mais alguns dias. O que os Antigos deixaram, ninguém aqui sabe fazer de novo." |
| 2 · Ponte das Raízes (O despertar) | Mais patrulhas, regiões seladas, sistemas que falam de preservação humana. "Por que as máquinas despertaram agora?" | Descrição: "sensores agora vigiam permissões". O "agora" é fraco. O `voz_interfone`, que é exatamente esta camada, está fora do jogo. A noite tem "ruídos distantes", sem ligação com a fase. | **Descrição:** "A ponte ligava bairros. Há pouco tempo, seus sensores voltaram a acender e a patrulha dobrou: a passagem livre agora pede permissões que ninguém na Estação possui." **Evento:** `voz_interfone` fixo na fase 2. **Relatório:** "Na volta, alguém repete a frase do alto-falante: \"preservação humana\". Ninguém sabe por que a ponte acordou." |
| 3 · Sala Esquecida / Abrigo Lacrado (Origem) | Animais resistentes foram estudados; houve modificação genética; IAs participaram da pesquisa; os antropomórficos descendem dessas linhagens. "O que fizeram com nossos ancestrais?" | Descrição: Programa Continuidade (descontinuado) e "quem retornou" (fase 5). Nada sobre a origem. `porta_espera` (fora do jogo) fala de quarentena. | **Descrição:** a da tabela 2. **Evento novo** (busca no "Arquivo" ou no "Fichário" do `SealedShelter`), "Ficha de Linhagem": "Uma ficha com o retrato de um cão de quatro patas, sem roupa, sem ferramenta. Carimbo: RESISTENTE · LINHAGEM 3 · ANÁLISE AUTOMÁTICA." Escolhas: levar (+1 Fragmento, +Instinto no cão) ou deixar. **Relatório:** "Íris lê as fichas em voz alta. Algumas palavras ela não sabe o que querem dizer: \"edição\", \"linhagem\", \"incubação\"." (a interpretação vem antes do fato, §6) |
| 4 · Laboratório Silencioso (Contradição) | Os documentos sobre a Peste entram em conflito. "A versão oficial sobre a origem da doença é verdadeira?" | Descrição: interfaces e aprendizagem (ideia descontinuada). Nenhuma menção à Peste em todo o jogo. | **Descrição:** a da tabela 2 (dois relatórios que não batem). **Relatório:** "Íris guarda os dois relatórios. \"Um deles está errado, ou os dois estão incompletos.\"" Sem dizer qual: §14.3 e `lore.md` §25.1, "Isso pode ser verdade apenas parcialmente". |
| 5 · Túneis do Eco (Presença humana) | Sinais recentes: autenticações, portas abertas, transmissões, consumo recente de recursos, manutenção impossível de ser antiga. "Os humanos ainda existem?" | Descrição: bombas antigas e "ordem… da guerra" (erro). Nenhum sinal recente. O fim da campanha diz só "Todas as fases foram concluídas". | **Descrição:** "Bombas antigas mantêm a água em movimento, e os filtros foram trocados há pouco tempo, não há gerações. Na eclusa central, o Porteiro guarda uma ordem de contenção que ninguém cancelou." **Relatório (vitória sobre o Porteiro):** "No painel da eclusa, uma linha nova piscava: AUTENTICAÇÃO HUMANA VÁLIDA · registro recente. Ninguém fala no caminho de casa." **Próximo passo final** (`station_rules.gd:1001`): "Os Antigos ainda existem? A pergunta voltou com a equipe. Dá para jogar qualquer fase de novo pelo mapa." |

Notas:
- O relatório da volta (`refuge_hud.gd:_report`) só mostra números. Para levar a escada até o jogador, a proposta é uma
  linha "O que a equipe viu" por fase, na primeira vitória, guardada no save para não repetir. É gameplay novo: a decisão
  é do Lucas, e o texto vem pronto acima.
- Respeitar `narrative-design.md` §10 e `bento-nick-arc.md` §11: nenhuma linha mostra um humano nem cita Théo. O máximo é
  a autenticação, que é o que a lore deixa o jogador saber (§25.4).

## 5. Nomes próprios e lugares conhecidos

Da lore e dos documentos:
- Depois dos Humanos — lore.md (título; §13)
- Peste — lore.md §2
- Primeira Contenção — lore.md §3
- O Retorno — lore.md §4, §26
- Programa de Adaptação — lore.md §6, §26
- Protocolo de Contenção — lore.md §9
- Protocolo de Preservação Humana — lore.md §19 ("PROTOCOLO DE PRESERVAÇÃO HUMANA ATIVO")
- VIGIA — lore.md §11
- Sistemas de Segurança — lore.md §10.1
- Sistemas de Pesquisa — lore.md §10.2
- Sistemas Degradados — lore.md §10.3
- Remendadores — lore.md §14.1
- Herdeiros do Eco — lore.md §14.2
- Raiz Livre — lore.md §14.3
- Canídeos — lore.md §15.1
- Felinos — lore.md §15.2
- Roedores — lore.md §15.3
- Povos das Margens — lore.md §15.4
- Antigos — lore.md §16
- Criadores — lore.md §16
- Peles-Lisas — lore.md §16
- Galerias — lore.md §16
- Casulos de Ferro — lore.md §16
- Casa do Remédio — lore.md §16
- Casas de Vidro — lore.md §16
- Tocas dos Antigos — lore.md §16 (o jogo usa o singular "Toca dos Antigos")
- Segunda Pele — lore.md §16
- Arquivos — lore.md §16
- Caminhos Mortos — lore.md §16
- Estação — bento-nick-arc.md §3 (a comunidade; lore.md §17, "assentamento")
- Bento — lore.md §1; bento-nick-arc.md
- Nick — lore.md §1; bento-nick-arc.md
- Íris — lore.md §15.3; bento-nick-arc.md §21
- Amora — lore.md §15.4; bento-nick-arc.md §21 (não está no jogo)
- Théo — bento-nick-arc.md §1, §11 (não deve aparecer cedo)
- O Surto — lore.md §26
- A Contenção — lore.md §26
- A Falsa Vitória — lore.md §26
- O Colapso — lore.md §26
- Linhagens Experimentais — lore.md §26
- O Silêncio — lore.md §26
- As Primeiras Comunidades — lore.md §26
- Eclusa Central — corridor-progression.md; expedition-nodes.json
- O Porteiro — corridor-progression.md; enemies.json
- Casco — corridor-progression.md ("libera Casco"); NAME_POOLS `tatu`
- Programa Continuidade — lore.md §29 (DESCONTINUADO; não usar)
- Eco — lore.md §29 (descontinuado como eixo; vale só como nome local: Túneis do Eco, Herdeiros do Eco, Eco-0x)

Só no jogo (decidir se entram na lore):
- Estação Raiz — lore.md §17
- Bairro Submerso — lore.md §17
- Mapa ferroviário — só no jogo (phase_map.gd)
- Plataforma da Estação — só no jogo (expedition-nodes.json)
- Rua das Vitrines — só no jogo (PHASES, scenarios.json)
- Ponte das Raízes — só no jogo
- Sala Esquecida — só no jogo
- Laboratório Silencioso — só no jogo
- Túneis do Eco — só no jogo
- Cais do Rio — só no jogo (scenario_world.gd DISPLAY)
- Depósito Inundado — só no jogo
- Abrigo Lacrado — só no jogo
- Dutos de Esgoto — só no jogo
- Portão de Triagem — só no jogo
- Câmara Seca — só no jogo (expedition-nodes.json)
- Central Telefônica — só no jogo (expedition-nodes.json)
- Posto Avançado Provisório — só no jogo (expedition-nodes.json)
- Zona Sanitária 7 — só no jogo (events.json `porta_espera`; "zonas sanitárias" está na lore §3)
- Cantina — só no jogo (station_rules ROOMS)
- Depósito — só no jogo (sala)
- Preparação — só no jogo (sala)
- Alojamento — só no jogo (sala; era "Sala dos Personagens")
- Forja — só no jogo (sala)
- Centro de Pesquisa — só no jogo (sala)
- Dormitório — só no jogo (sala)
- Bar — só no jogo (sala)
- Memorial — só no jogo (refuge_hud)
- Dora — só no jogo (civil, Texugo)
- Otto — só no jogo (civil, Castor)
- Cora — só no jogo (civil, Gambá)
- Risco — só no jogo (events.json `sobrevivente_tuneis`; NAME_POOLS `rato`)
- Véspera — lore.md §15.6 (Aves das Torres)
- Cão Protetor — só no jogo (classe)
- Gato Batedor — só no jogo (classe; era "Gato Assassino")
- Sapo Química — só no jogo (classe)
- Coruja Atiradora — só no jogo (classe; era "Coruja Sniper")
- Guaxinim Sabotador — só no jogo (classe)
- Tatu de Resgate — só no jogo (classe)
- Robô — só no jogo (enemies.json)
- Robô Fungo — só no jogo
- Rastreador Quadrúpede — só no jogo
- Drone de Expurgo — só no jogo
- Sentinela de Triagem — só no jogo
- Emissor de Comando — só no jogo
- Rastejante de Cabos — só no jogo
- Coletor de Sucata — só no jogo
- Relé de Defesa — só no jogo (Alfa e Beta no chefe)
- Condutores — só no jogo (phase_map.gd; nome velho, sai pela tabela 2)
- Demolidor Industrial — só no jogo (vilão do John; era "Carrasco Industrial")
- Recreador — só no jogo (vilão do John)
- Enraizado — só no jogo (vilão do John)
- Pipoco — só no jogo (vilão do John)
- Faísca — só no jogo (vilão do John; também nome de recruta `rato`)
- Broto — só no jogo (vilão do John)
- Hóspede Rubro — só no jogo (fora dos encontros)
- Núcleo Nulo — só no jogo (fora dos encontros)
- Ilusionista de Sucata — só no jogo (fora dos encontros)
- Soldador — só no jogo (inimigo; era "Remendador", que chocava com a facção)
- Acoplador — só no jogo (fora dos encontros)
- Felina de Ferro — só no jogo (fora dos encontros)
- Patinadora de Choque — só no jogo (fora dos encontros)
- Eco-01 — só no jogo (fora dos encontros)
- Eco-02 — só no jogo (fora dos encontros)
- Eco-03 — só no jogo (fora dos encontros)
- Eco de Sucata — só no jogo (Role dos Eco-0x)
- Botão de Cobre — só no jogo (relics.json)
- Pena de Vidro — só no jogo (relics.json)
- Coleira de Lembrança — só no jogo (relics.json)
- Pé de cabra — só no jogo (ferramenta)
- Lanterna — só no jogo (ferramenta)
- Máscara com filtro — só no jogo (ferramenta; a lore §2.1 cita máscaras e filtros)
- Ampola de Reparo — só no jogo (inventory_panel; era "Ampola da Íris")
- Zonas dos cenários (só no jogo, `tools/sync_scenarios.py` AREAS): Cais, Navio, Galpão, Hall, Estoque, Manutenção, Arquivo, Convivência, Sala técnica, passagem

Nomes de recruta (só no jogo, `station_rules.gd` NAME_POOLS; uma linha por classe, para o teste ler como lista):
- cao — Bento, Brutus, Argos, Tobias, Balto, Rufus, Lorde, Barão, Brasa, Trovão, Pistão, Farol, Fumaça, Trilho, Bóris
- gato — Nix, Sombra, Breu, Telha, Maya, Nuvem, Fresta, Calha, Chico, Puma, Luna, Antena, Veludo, Mimi, Lampião
- sapo — Íris, Lupa, Cisterna, Garganta, Mirante, Bubo, Estrela, Eco, Alerta, Sábio, Pluma, Penumbra, Gisela, Noctis
- coruja — Véspera, Sereno, Jasmim, Pacato, Rio, Sol, Dengoso, Flora, Paz, Brisa, Lótus, Chico Rei, Pingo, Mel, Cacau
- rato — Risco, Pólvora, Chispola, Pipeta, Ferrugem, Duto, Pipoca, Veneno, Mola, Centelha, Fuligem, Pinça, Engrenagem
- tatu — Casco, Carapaça, Couraça, Fortaleza, Tromba, Pedregulho, Bigorna, Escudo, Baluarte, Granito, Tanque, Rochedo

Observações para o teste automático: "vigia" (minúsculo, quem vigia a noite) não é o VIGIA, então a comparação deve
distinguir maiúsculas. O nome do jogo em `project.godot` é "After Humans"; os textos de tela usam "Depois dos Humanos"
só na lore.
