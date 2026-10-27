# Ambientação: o que o REPLACED faz e como trazer para o After Humans

Pedido do Lucas (26/10/2026): deixar a ambientação e o jogo mais interessantes, como no REPLACED. Ele mandou cinco
capturas e um vídeo de 32 s do hub da estação do jogo. As imagens não entram neste repositório, que é público. Aqui
fica a leitura e a proposta.

## 1. O que o REPLACED faz

- **Profundidade em camadas.** São quatro planos:
  - um primeiro plano escuro, em silhueta (grades, postes, cabos, pessoas passando perto da câmera), quase sempre
    desfocado;
  - a faixa onde se anda;
  - o fundo, com arquitetura grande e detalhada;
  - um "longe" (prédios, céu e névoa).

  O olho entende a distância sem esforço.
- **Luz prática.** Toda luz é um objeto do cenário: letreiros, gambiarras de lâmpadas coloridas, lampiões, tambores
  com fogo, luminárias penduradas. Cada uma faz uma poça no chão e um halo no ar. O contraste é quase sempre quente
  contra frio: laranja contra ciano, vermelho contra verde.
- **Atmosfera.** Névoa volumétrica com raios de luz entrando, poeira e fagulhas no ar, chuva com respingo, vapor. O
  fundo some na névoa, o que dá escala.
- **Pós-processamento de cinema.** Uma cor forte por cena (o grading), grão de filme, vinheta, bloom nos letreiros e
  desfoque de profundidade na frente e no fundo. A tela é larga, quase como cinema.
- **Vida.** Muita gente no fundo fazendo coisas, falas curtas em balão quando o herói passa, coisas que se mexem
  (cabos e panos balançando, luz piscando).
- **Câmera.** Nos lugares grandes (o hub), a câmera desce e abre devagar, mostrando o espaço. Nos corredores, ela fica
  mais perto. Os enquadramentos são de cinema.
- **Densidade e história no cenário.** Placas, cartazes, grafites, bancas, entulho e folhas no chão. Nada fica vazio, e
  cada detalhe conta quem vive ali.

## 2. Onde o After Humans está

- **O que já temos:**
  - os cenários são pinturas em camadas num mundo 3D (2.5D), com a luz do cenário, clima, hora e chuva;
  - o glow e a névoa;
  - o SSAO, a névoa volumétrica e o reflexo no chão molhado, no Forward+ e na qualidade Alta ou mais.
- **O que falta perto do REPLACED:**
  - pouca luz prática: as cenas são iluminadas mais pelo "céu" do que por objetos;
  - quase nenhum primeiro plano nem "longe";
  - nenhum desfoque de profundidade, grão ou vinheta, e uma cor parecida em todos os mapas;
  - os cenários vazios: não há vida de fundo, e nada se mexe além da chuva;
  - a Estação Raiz em corte parece uma casa de bonecas no escuro, e não um lugar habitado.

A nossa arte é pintada, não pixel art, e continua assim: as técnicas acima valem para qualquer estilo.

## 3. Proposta, em fases

Cada fase pode ir para um mapa piloto (a Rua das Vitrines) antes dos outros.

### Fase 1: a câmera de cinema (código, barata)
- **Um perfil de ambiência por cenário** em `data/` (por exemplo, `data/presentation/ambience.json`):
  - o grading (a cor da cena, por correção de cor);
  - a névoa (a cor, a densidade e a altura, com a volumétrica onde houver);
  - o glow;
  - o desfoque de profundidade na frente e no fundo;
  - o grão;
  - a vinheta.
- **As partículas de ar por cenário:** poeira na luz, fagulhas perto do fogo, folhas, vapor dos canos e respingos da
  chuva.
- **Tudo ajustável ao vivo pelo Admin** (#151), para o Lucas afinar cada mapa jogando.
- **A qualidade gráfica manda:** no Baixo, sem volumetria nem desfoque. No celular e na web (Compatibility), as versões
  falsas: faixas de luz desenhadas e névoa em cartões.

### Fase 2: luz prática (arte e código)
- **Um kit de fontes de luz,** cada uma com a luz, o halo e a poça no chão:
  - a gambiarra de lâmpadas coloridas;
  - o lampião;
  - o tambor com fogo;
  - a luminária pendurada;
  - o letreiro velho que pisca (sem texto humano legível, pela regra da narrativa);
  - a luz de emergência.
- **Em cada cenário,** algumas dessas fontes, com um contraste quente contra frio próprio do mapa. Por exemplo:
  - o Cais, ciano da água contra o laranja dos lampiões;
  - a Rua, o laranja do fim de tarde contra o verde das vitrines;
  - os Túneis, verde contra vermelho.

### Fase 3: as camadas (arte e código)
- **O primeiro plano em silhueta:** grades, cabos, postes, raízes e entulho perto da câmera, escuros e desfocados.
- **O "longe":** um fundo distante para cada mapa (a cidade alagada, as torres, a ponte), sumindo na névoa.
- A Awesomic faz a arte, no contrato dos cenários, e o Claude monta.

### Fase 4: a vida nos mapas é das máquinas (arte e código)
**Decisão do Lucas (26/10):** os mapas são pouco habitados por animais com personalidade, ao contrário do mercado
cheio do REPLACED. Quem ocupa a cidade são as máquinas. Os poucos sobreviventes que existem lá fora se escondem. A
Estação Raiz é o único lugar cheio de vida.
- **A vida de fundo são as máquinas,** e é ela que faz a cidade parecer habitada e perigosa:
  - drones passando ao longe com o farol varrendo a névoa;
  - robôs de serviço repetindo rotinas sem sentido (varrendo uma calçada vazia, conferindo uma porta);
  - máquinas quebradas que ainda piscam, faíscam ou tentam se mexer;
  - sensores, câmeras e alto-falantes que acordam quando a equipe passa.
  - Nada disso luta: é cenário, coerente com a VIGIA de cada fase (`docs/narrative/`).
- **Os sobreviventes escondidos:** sinais de que há alguém (uma fogueira apagada ainda quente, um esconderijo, um
  vulto que some na janela). Poucos, e quase nunca à vista.
- **Encontros com sobreviventes específicos, raros e marcados:** um animal escondido que a equipe encontra, com uma
  escolha. Ajudar (dar comida ou um curativo, levar até a Estação pelo trem, #122), negociar ou saquear o que ele tem,
  com consequência na Esperança, nos recursos ou num recruta futuro. Os textos passam pela regra de consistência da
  narrativa, e os números ficam em `data/`, como os eventos.
- **As coisas que se mexem:** cabos e panos balançando, placas rangendo, luz piscando, água pingando.

### Fase 5: a Estação Raiz como lugar habitado (o contraste com a cidade vazia)
- **Na chegada e na Visão geral,** a câmera desce e abre devagar, como no vídeo do hub.
- **Mais luz prática** (gambiarra na plataforma, lampiões nos cômodos), névoa com raios de luz e a poeira no ar.
- **Os moradores circulando** entre os cômodos e a plataforma.

## 4. Cuidados

- **Desempenho:** cada fase mede o custo no Baixo e no Ultra (`docs/perf.md`). O celular fica com as versões falsas.
- **Legibilidade:** a luta e a HUD continuam claras. O desfoque e a vinheta não pegam a faixa onde se anda nem os
  inimigos, e a cor forte não apaga o daltonismo.
- **Narrativa:** placas, cartazes e falas seguem `docs/narrative/`: nada de texto humano legível que revele a
  história antes da hora.
