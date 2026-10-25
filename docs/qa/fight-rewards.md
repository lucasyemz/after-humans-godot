# O fim de luta que recompensa (#91)

Fotos de `tools/capture_rewards.gd` (1920x1080, gl_compatibility): o fim de uma patrulha vencida no automático; com o
guardião vencido, a carga recuperada antes e depois de escolher.

![antes e depois](fight-rewards/before-after.jpg)

À esquerda, o antes, na `main`: a vitória, o retrato e a vida de cada herói. À direita, o depois:
- as estrelas;
- os quatro critérios, cada um cumprido ou não;
- o nível e o XP ganho de cada herói, com a barra que enche no ritmo da luta.

![a carga recuperada](fight-rewards/cargo.jpg)

A carga do guardião: seis compartimentos fechados. Depois da escolha, a caixa escolhida fica em dourado com "(sua)", as
outras se revelam uma a uma, apagadas, e aparece o Continuar.

![a rua depois do guardião](fight-rewards/street-before-after.jpg)

A rua com o guardião vencido: antes, nada; agora, a carga espera a escolha antes de a equipe andar.

## Como funciona

- **As estrelas** (`data/fight-stars.json`):
  - a vitória dá 1 estrela, e a derrota e a fuga não dão nenhuma;
  - os critérios são quatro: ninguém caiu; a luta durou até 4 rodadas (até 8 no guardião); o golpe final foi de um
    herói (o sangramento na vez do inimigo não conta); o instinto ficou controlado (ninguém em colapso);
  - 2 critérios cumpridos dão 2 estrelas, e os 4 dão 3 estrelas;
  - a melhor nota do guardião de cada fase fica no save (`mission_stars`), para a #92 liberar a próxima missão;
  - o save de antes abre sem estrelas.
- **A carga recuperada** (`data/recovered-cargo.json`, por fase):
  - depois do guardião, são sorteadas 6 caixas com sementes, sucata, fragmentos, suprimentos, curativos e, no máximo,
    uma relíquia;
  - o sorteio usa a semente da expedição. Salvar e voltar mostra as mesmas caixas e não deixa escolher de novo;
  - sementes, sucata, fragmentos e suprimentos entram no achado da rota e chegam na volta, como o resto do achado;
  - os curativos vão na hora para a Mochila, e a relíquia para o Depósito.
- **O XP na tela do fim:** é o XP da #90 (`xp_gained` da sessão), e mostra "Treino pronto" quando o herói já pode
  treinar.

## Como testar

- `tests/test_fight_rewards.gd` cobre:
  - os critérios e as estrelas, e quem deu o golpe final;
  - a nota no save e o save antigo;
  - o sorteio igual depois de salvar e carregar, a escolha única, e o achado na volta, na Mochila e no Depósito;
  - a revelação das caixas;
  - reabrir com a carga pendente;
  - a tela do fim de uma luta de verdade.
- `tests/test_full_journey.gd` escolhe a carga depois do guardião e segue até o trem.
- A suíte inteira, `tests/run_all.gd`, passa.

## Para o Lucas decidir

- **Os números das tabelas novas são uma primeira proposta:** o par de rodadas (4 e 8), os critérios por estrela (2 e
  4) e o que cada fase guarda na carga. Nenhum número que já existia mudou.
- **No automático, a tela do fim fecha sozinha em 1,5 s,** como antes. Com as estrelas e o XP, talvez valha segurar
  mais tempo.
- **A rota da #87 ainda não existe:** a carga usa a semente da expedição. Quando o mapa novo entrar, ela passa a usar a
  semente da rota.
- **Os suprimentos da carga não aparecem no "Achado" do HUD.** Ele só mostra sementes, sucata e fragmentos, então os
  suprimentos aparecem só no relatório da volta. Dá para pôr os suprimentos no HUD.
- **Os curativos e a relíquia entram na hora,** como o que vem "do refúgio". Se a equipe cair depois, perde o achado da
  rota mas fica com eles.

## Rodadas da QA

1. **Reprovada,** com dois bugs médios e três observações baixas, todos corrigidos:
   - o "Concluir jornada" ficava clicável com a carga na tela, e a carga se perdia. Agora o botão some enquanto a carga
     espera, e concluir só funciona depois do Continuar;
   - uma fase sem linha na tabela travava a equipe. Agora ela não tem carga, e um teste confere que toda fase tem
     linha;
   - as caixas reveladas estavam quase ilegíveis e passaram a ser legíveis, apagadas;
   - a relíquia passou a usar o ícone dela, e não sempre o do Botão de Cobre.
2. **Aprovada.** A suíte passou 45 de 45, e os scripts da QA também passaram: concluir antes e durante a revelação,
   reabrir com a carga pendente, fase sem linha na tabela, e guardião no automático com estrelas, save, foco, teclado e
   Esc. Ficou uma observação baixa: com a carga na tela, o painel do objetivo ainda diz "botão ou Esc".
