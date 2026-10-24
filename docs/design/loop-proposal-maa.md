# Proposta: o laço de jogo do Marvel: Avengers Alliance adaptado ao After Humans

Estudo de um vídeo de gameplay de 11 minutos do Marvel: Avengers Alliance (Playdom, Facebook, 2012; a versão do vídeo é
a recriação de fãs "MAA Redux"), enviado pelo Lucas em 24/10/2026. Sem imagens do jogo neste repositório, que é público:
os quadros estudados ficaram só na máquina do Lucas. Aqui fica a leitura e a proposta.

## 1. O laço deles

```
Base (Helicarrier) → Mapa do bairro → Missão (briefing) → Equipe → Luta em ondas → Pontuação e roleta de prêmio
      ↑                                                                                         │
      └──────── Pesquisa (timers) · Treino dos heróis · Equipamento · Loja · Temporadas ←───────┘
```

1. **A base é um hub com tudo à mão.** O porta-aviões, com os botões Missão, Equipe, Pesquisa, Loja e Temporadas (Spec
   Ops). Avisos verdes sobre ele: "Treino disponível", "Pesquisa concluída". Embaixo, uma fileira de aliados com
   "Coletar tudo" (presentes de tempos em tempos).
2. **O mapa do bairro** (Times Square, Empire State): a cidade de cima, à noite, com prédios em holograma. Pinos com o
   rosto do vilão em cada missão, o nível recomendado no topo e o progresso do bairro.
3. **Briefing com retrato:** o Nick Fury ou um herói fala uma ou duas linhas numa caixa ("Próximo"), antes e depois.
4. **Equipe:** três na luta. O agente do jogador é fixo; dois heróis escolhidos. O "Team-up" dá bônus a certos pares.
   "Lutar" ou "Abortar". As lutas vêm em ondas.
5. **A luta:**
   - a faixa de iniciativa com rostos no alto e "Vez do X" no meio;
   - a barra de habilidades embaixo, em ícones, mais o item e o fugir;
   - "Selecione um alvo" e o clique no próprio personagem;
   - os estados em ícones sobre a cabeça;
   - a vida e a energia (stamina) numa faixa fina embaixo;
   - a ficha do personagem ao apontar, com a classe, os números e os efeitos passivos;
   - o crítico grande no alvo.
6. **O fim da luta:** a pontuação por critério (vitalidade, rodadas, abates, dano em excesso, resistência), o XP de cada
   herói numa barra e a **roleta de prêmio** (escolher uma entre nove caixas viradas).
7. **A progressão:**
   - a Pesquisa em árvore, com pré-requisitos e tempo (8 h), que libera equipamento e melhorias, e o aviso de pesquisa
     concluída;
   - o Treino, que sobe o nível do herói (XP mais um custo);
   - os uniformes e o equipamento por herói, com a ficha de cada item;
   - as classes (Generalista, Tático, Brigão, Infiltrador, Atirador, Combatente) em triângulo de vantagem;
   - as Temporadas, com capítulos de chefes e estrelas por missão (1 a 5) para repetir e melhorar.
8. **O que segura o jogador:** a energia por tempo, o prêmio diário, os timers de pesquisa e treino e a coleta dos
   aliados. Isso servia ao Facebook (voltar todo dia) e não serve inteiro a um jogo de PC sem loja.

## 2. O que o After Humans já tem

| Deles | Nosso hoje |
|---|---|
| Base hub com salas | Estação Raiz em corte, cômodos clicáveis, Próximo passo, Plano |
| Mapa com pinos de vilão | Mapa de fases; o novo mapa com chefes e radar está pedido (#86, #87) |
| Briefing com retrato | Dicas da primeira vez e eventos; sem briefing de missão |
| Equipe e "Team-up" | Preparação com 4 heróis, posições, equipes menores; laços entre heróis (amizade e rivalidade) existem nas regras, mas quase não aparecem |
| Luta com iniciativa, alvo e estados | Combate por posições, ordem da rodada, intenção dos inimigos, prévia de atingidos, alvo pelo personagem, crise de instinto |
| Pontuação e XP no fim | Relatório da volta com o que cada herói fez; **sem XP e sem nível dos heróis** (o nível vem da fase) |
| Roleta de prêmio | Achado por busca; sem prêmio de fim de luta |
| Pesquisa em árvore com timers | Pesquisa com quatro melhorias, uma por classe, sem árvore nem tempo |
| Treino e equipamento | Uma relíquia por herói (Forja); sem treino e sem arma |
| Classes com vantagem | Espécies (cão, gato, sapo, coruja) com papéis; máquinas com estados próprios; sem triângulo |
| Temporadas e estrelas | Fases repetíveis ("Jogar de novo"); sem estrelas nem desafio |
| Energia e diário | Comida e ciclo da Estação por expedição (sem relógio real) |

## 3. Proposta (o que trazer, adaptado)

Por prioridade. Cada item diz o motivo, como fica na nossa história e o que não copiar.

### P1. Missões dentro de cada lugar, com estrelas
- **Hoje:** cada fase é uma travessia longa de 10 trechos.
- **Proposta:** no mapa, cada lugar abre um **painel de missões curtas**, além da travessia principal:
  - **patrulha:** limpar uma rua de máquinas;
  - **resgate:** levar um morador até a Estação;
  - **coleta:** achar uma peça para a Forja;
  - **o chefe do lugar.**
- **Estrelas:** cada missão dá de 1 a 3 estrelas pelo desempenho (ninguém caído, poucas rodadas, comida economizada), e
  as estrelas liberam a próxima e um prêmio.
- **Por quê:** é o laço curto que prendia no MAA (entrar, lutar de 3 a 5 minutos, sair com algo), sem perder a jornada
  longa, que vira a "missão de história" do lugar.
- **Na história:** os pedidos chegam pelo Mapa da Rede e pelos moradores (Dora, Otto, Cora).
- **Não copiar:** a energia por tempo. O limite continua sendo a comida e o ciclo da Estação.

### P2. Fim de luta que recompensa: estrelas, XP e a "carga recuperada"
- **Proposta:** no fim de cada luta, uma tela curta com:
  - os critérios (ninguém caiu, rodadas, golpe final, instinto controlado);
  - as estrelas;
  - o XP de cada herói enchendo a barra.
- **Depois do chefe:** a **carga recuperada**, escolher 1 de 6 caixas viradas da carga que a máquina guardava, com as
  outras reveladas depois. É a roleta do MAA, sem loja, sem dinheiro de verdade, sem repetir para "tentar de novo".
- **Por quê:** fecha a luta com uma emoção e um ganho visível.

### P3. Nível dos heróis e Treino
- **Hoje:** os heróis não sobem de nível.
- **Proposta:**
  - **XP** por luta e por missão;
  - **Treino** na Sala dos Personagens, que sobe o nível com XP mais sementes e libera uma melhoria escolhida (vida, uma
    habilidade nova da lista do herói, mais instinto antes da crise);
  - os **recrutas** sobem mais rápido que os fundadores, para valer a pena trocar.
- **Por quê:** é a principal razão de voltar no MAA (ver o herói ficar forte).
- **Cuidado:** mexe no equilíbrio. A paridade da luta não muda; o nível só soma por cima e precisa da decisão do Lucas
  sobre a curva.

### P4. Pesquisa em árvore, medida em expedições
- **Proposta:** a Pesquisa vira uma árvore curta por ramo, com pré-requisito e custo:
  - **Classe:** as melhorias de hoje e as próximas;
  - **Estação:** produção, capacidade, energia;
  - **Radar:** as leituras do Mapa da Rede da #87.
- **O tempo:** em vez de horas reais, cada pesquisa leva de 1 a 3 expedições. O aviso "Pesquisa concluída" aparece na
  volta, no Próximo passo.
- **Por quê:** os timers do MAA criavam expectativa ("quando voltar, terminou"). Aqui a expectativa é por jornada, que
  combina com o ciclo que já existe.

### P5. Laços à vista ("Team-up")
- **Hoje:** os laços entre os heróis existem nas regras, mas não aparecem.
- **Proposta:** na Preparação, pares com laço mostram o ícone e o bônus ("Bento e Nick: amigos de longa data: +1 dano
  quando um protege o outro"). A rivalidade mostra o custo. Na luta, um pequeno destaque quando o bônus acontece.
- **Por quê:** é o "Team-up" do MAA, que dá vontade de montar equipes; e o arco do Bento e do Nick já existe na
  narrativa.

### P6. Briefing e debriefing com retrato
- **Proposta:** antes de cada missão, duas ou três falas com o retrato de quem pede (morador, Mapa da Rede, um
  fundador). Depois, uma fala de volta. Dá para pular, e funciona com o teclado e o controle.
- **Por quê:** é como o MAA conta história sem atrapalhar. Cumpre a regra de narrativa (cada missão diz por que a
  equipe está ali).

### P7. Ficha do personagem ao apontar
- **Proposta:** na luta e na Preparação, apontar para um personagem abre a ficha:
  - classe ou espécie;
  - vida, instinto, velocidade;
  - os efeitos passivos;
  - os estados com o que fazem.
- **Por quê:** o MAA esconde quase tudo na tela fixa e mostra ao apontar. É o que a HUD nova (#56, #58) precisa.

### P8. (retirada)
Arma por herói na Forja: retirada pelo Lucas em 24/10. Cada personagem já tem a sua arma no próprio desenho e nas
habilidades; o equipamento continua sendo a relíquia.

### P9. Desafios dos chefes ("Temporadas", depois)
- **Proposta:** depois de vencer um chefe, um desafio dele fica disponível no Mapa da Rede, com modificadores (sem
  curativos, inimigos mais fortes, equipe de dois) e estrelas. É o endgame para quem já terminou as cinco fases.

### A exploração continua
- **A travessia não sai:** a jornada longa de cada lugar continua como é hoje (andar pelos trechos, patrulhas que veem a
  equipe, buscas, interiores, acampamento, eventos e o guardião no fim), e vira a **missão de história** do lugar.
- **As missões curtas (P1) também são exploração:** num trecho menor do mesmo mapa, com a mesma equipe andando, as
  buscas e a patrulha, só que com um objetivo só (salvar, achar, limpar) e duração de 3 a 5 minutos.
- **O resultado:** o jogador escolhe entre uma saída curta para um objetivo e a travessia inteira para avançar a
  história. Nada da exploração atual é trocado por menu.

### O que não trazer
- **Energia por tempo real, prêmio diário e coleta de aliados por relógio:** feitos para trazer o jogador de volta todo
  dia num jogo de rede social. Num jogo de PC sem loja, viram espera sem sentido.
- **Loja com moeda premium e PvP.**
- **O triângulo de classes rígido:** o nosso combate já tem posições, máquinas e estados. Um triângulo por cima
  complicaria a leitura que o Lucas pediu para simplificar.

## 4. Ordem sugerida
1. **P6, P7 e P2 (sem a carga recuperada):** dão sensação de MAA logo, com pouco risco, e entram junto com a HUD nova.
2. **P3 e P2 completo (carga recuperada):** precisam da decisão do Lucas sobre a curva de nível e os prêmios.
3. **P1:** junto com o mapa novo (#86, #87), porque as missões moram nos lugares do mapa.
4. **P5 e P4.**
5. **P8 e P9.**

## 5. Decisões do Lucas
- **Missões curtas (P1):** aprovar a ideia e quantas por lugar (sugestão: 3 mais o chefe).
- **Nível dos heróis (P3):** aprovar e escolher entre uma curva curta (nível máximo 10) e uma longa.
- **Carga recuperada (P2):** 1 de 6 caixas está bom, ou prefere o prêmio fixo?
- **Pesquisa por expedições (P4):** aprovar no lugar dos timers reais.
