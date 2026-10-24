# Travessia por fase

Integração do pacote `Depois-dos-Humanos-Integracao.zip` e das regras do `INTEGRACAO_CODEX.md` enviado pelo autor.

## Fluxo

Ao confirmar um destino no mapa ferroviário, abre-se uma travessia com dez passos. A plataforma inicial continua sendo a partida do refúgio. Os oito passos intermediários combinam quatro patrulhas, dois suprimentos, um descanso e uma passagem livre. Cada par tem uma patrulha e uma pausa; a seed da expedição e o ID do destino determinam a ordem. O passo dez contém um guardião.

- Patrulha: um inimigo do perfil daquela região, com 6 ou 8 PV.
- Guardião: um inimigo do perfil regional com 26 PV. Na Eclusa Central, é O Porteiro.
- Suprimentos: um alimento e uma semente, uma vez por passo.
- Descanso: a tela existente permite gastar suprimentos e cuidar dos sobreviventes.
- Vitória sobre um guardião regional: seis sementes e uma sucata. O guardião final mantém a recompensa de conclusão da expedição.

O combate acontece no próprio corredor: o canvas, a câmera, o clima e a posição do encontro permanecem montados. A próxima patrulha é preparada antes da caminhada e aparece fisicamente durante a aproximação. Ao chegar, somente a HUD muda: controles de exploração saem, comandos táticos entram. As habilidades, poses, regras e salvamento continuam usando o controlador de combate existente. Ao vencer, a HUD tática sai e a caminhada é liberada no mesmo ponto.

Ao concluir uma travessia, resolve-se a ação original do destino: escolha narrativa, saque, descanso ou liberação das próximas escolhas do mapa. Uma escolha narrativa ainda pode provocar seu combate adicional. Só concluir a Eclusa conta como concluir a expedição e libera Casco.

## Movimento e descoberta

Segurar ←/→ ou A/D move a equipe continuamente; soltar para na posição atual e inverter a direção permite recuar entre etapas. Os botões do rodapé aceitam o mesmo gesto com mouse ou toque. Enter/Espaço no botão mantém a opção acessível de ir até a etapa seguinte. Perder o foco da janela interrompe a caminhada.

Os marcadores futuros exibem “Não explorado”, sem ícones ou descrições do evento. A etapa é revelada quando a equipe chega; locais já visitados permanecem conhecidos ao recuar. Combate e descanso bloqueiam a travessia até sua resolução. O movimento para exatamente no ponto do evento, sem saltar encontros ou repetir recompensas.

## Salvamento

`ExpeditionState.corridor` armazena seed, destino, índice e passos resolvidos. `corridorSettings` conserva clima, potência e ativação das luzes, inclusive ao sair e voltar de um combate. A potência inicial é 56%. O clima é sorteado pelo cenário e pela seed da fase uma única vez na entrada. Cada nova fase substitui os ajustes da anterior; recargas, retornos entre passos, descansos e combates preservam o sorteio salvo. Novas expedições usam novas seeds e podem repetir o mesmo clima por acaso. Ambientes internos não sorteiam chuva ou tempestade.

A chegada a cada passo é salva junto com sua recompensa ou encontro. Reabrir o jogo durante o deslocamento retoma o último passo confirmado; durante o combate, restaura o checkpoint tático existente. Voltar não gera novas recompensas. Callbacks atrasados são verificados pelo ID da expedição, destino e índice do passo.

Saves anteriores sem `corridor` continuam válidos. Um encontro antigo em andamento termina pelo fluxo anterior; o próximo destino inicia a travessia nova.

## Apresentação

`src/engine/corridor/` adapta composição, paredes procedurais, janelas, chuva e shader do exemplo para instâncias locais descartáveis. Não importa controles globais nem o minijogo de combate da prévia. As imagens utilizadas estão em `public/corridor/assets`.

A exploração renderiza a equipe na ordem salva. Todos os sprites usam a máscara `#ccffcc`, alpha próprio e sombra baseada nos pés de cada frame. Luzes locais recebem potência gradual e só acendem nos climas noturnos. Paredes longas alternam com grupos de 2–4 módulos; a ponte continua descoberta, com chuva no piso. As luzes dos cenários com paredes usam os centros das luminárias desenhadas na arquitetura (`wallLights.ts`), respeitando sobreposição de módulos e espaçamento mínimo. A ponte conserva os vãos transparentes dos módulos originais, sem a parede de preenchimento opaca; a base dos túneis também preserva o alpha da imagem.

A caminhada de Bento fornecida no pacote está registrada em `public/characters/animations.json`, também visível na galeria. Os demais personagens mantêm seus idles, com fases independentes, até receberem suas próprias animações Walking. O renderer lê os slots já preparados, sem reutilizar arte de outro personagem.

## Verificação

- `scripts/corridor-progress.test.ts`: 300 seeds, distribuição dos passos, limite de deslocamento, ranks de ataque do inimigo isolado, recompensas idempotentes e rejeição de checkpoint inválido.
- `scripts/session-persistence-ui.test.tsx`: handlers reais do App, recarga em cada passo/combate/descanso, conclusão da fase, eventos, retirada e callback antigo. Também conserva testes de saves legados.
- `scripts/noncombat-ui.test.tsx`: recompensas narrativas e retorno, agora atravessando a fase antes de resolver o destino.
- `/dev/corridor.html`: laboratório visual dos seis cenários, com seed variável e sem gravar campanha. A prévia usa combates reais no corredor; apenas descansos são concluídos automaticamente, sem afetar saves.

### Câmera e ações contínuas

O corredor iluminado é apresentado por uma câmera ortográfica Three.js, sem desmontar a cena. Os perfis de `closeCamera` e as trajetórias de `combatMotion` são compartilhados com a arena anterior: avanço, recuo, reação, esquiva, aproximação e retorno. A HUD permanece fixa; alvos e barras são projetados pela mesma câmera. O mouse desloca as camadas do cenário em profundidades diferentes, com suavização. Durante a ação, o foco prevalece sobre o mouse. Movimento reduzido desativa close, tremor e parallax. Se o Three.js não iniciar, permanece a apresentação compatível do corredor.

### Luminárias integradas

Cada ambiente fechado usa sua própria parede extensa em `public/corridor/assets/scenarios/{scene}-parede-extensa-v1.webp`: estação com tijolos e ferro, sala com revestimento azul e madeira, laboratório com azulejos e conduíte, túneis com pedra úmida e tubulação. São módulos longos e pouco mobiliados, gerados a partir da arte original de cada ambiente. A proporção da imagem é preservada, sem alongamento aleatório. A ponte não carrega parede opaca de preenchimento. Prompts e referências constam em `Docs/Scenarios/long-wall-prompts.md`.

O gerador compõe oito variantes longas por ambiente com faixas da respectiva textura, comprimentos diferentes, inversões locais e emendas suavizadas. As faixas simples excluem a luminária; três variantes incluem um único trecho com luz, com âncora recalculada na composição. Os módulos são preparados uma vez e reutilizados, sem recomposição por frame. A escolha usa uma bolsa embaralhada pela seed da fase: todas as variantes são visitadas antes de repetir, sem repetição na troca de bolsa. Voltar ou recarregar a mesma fase mantém o cenário. Rua e ponte conservam seus geradores próprios.

`scripts/wall-variants.test.ts` verifica limites das faixas, isolamento das luminárias, diversidade, determinismo e ausência de repetição entre bolsas em 100 seeds.

As luminárias fazem parte da arte, com o centro da luz ajustado ao vidro de cada imagem. As paredes genéricas anteriores permanecem no histórico de arquivos, mas não são carregadas pelo corredor.

O shader aplica luz descendente multiplicando a cor do material, preservando rachaduras e sombras da arte. As lanternas existentes não recebem mais discos de emissão ou bloom sobrepostos. As paredes extensas usam o vidro pintado na própria imagem, sem um núcleo artificial sobreposto. O efeito dos postes da rua mantém o perfil anterior; a ponte continua com suas lanternas de pedra e seus vãos transparentes.

### Painel de cenário

O painel “Admin · cenário” está disponível em desenvolvimento na travessia e no combate. Permite ajustar clima, potência e ativação das luzes, intensidade climática, parallax, zoom de 1× a 1,6× e close de combate, além de consultar o JSON e restaurar os valores visuais sem trocar o clima. As alterações valem para a fase atual. Na versão de produção permanece o painel básico “Luz e clima”. O painel da arena antiga continua disponível naquela arena; os controles acima atuam no renderer atual do corredor.

O seletor “Mapa da prévia” troca apenas a composição visual, preservando o canvas, a posição e o combate. “Mapa da fase” restaura o cenário original. A prévia não altera nós, inimigos, clima ou progresso e termina ao mudar de fase. O zoom é salvo nos ajustes da fase; o close tático retorna a esse enquadramento ao terminar a ação.
