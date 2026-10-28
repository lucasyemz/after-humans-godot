# Validação da reorganização

Data: 28/10/2026. Branch `codex-comic-generator`, iniciada na `main` atualizada (`5bb2928`). Checkout separado, limpo antes das mudanças. Nenhum arquivo da Godot foi alterado.

## Preservação

Origem somente leitura: `C:\Users\lucas\Documents\Codex\2026-10-15\task\`. Não havia `AGENTS.md` na origem nem em seus diretórios ancestrais; foram lidas as regras do destino antes da edição. Nenhum original foi movido ou apagado.

A sequência ativa foi identificada no `EMBEDDED_PROJECT` do `index.html`, no `After-Humans-direcao-v2.comic.json` e na entrega `entrega-direcao-v2/`. São oito cenas: Setor B, Alarme, Fuga, A queda, Captura, Corre Bento, Eu não vou te deixar e A saída. Duração real atual: 44,3 segundos. Não foi usada a duração dos antigos scripts de preparação.

Comparação estrutural com a origem: todas as propriedades das oito cenas são iguais, exceto a retirada de `assetHistory` e `referenceId` de biblioteca externa. A ordem, IDs, configuração, camadas, imagens associadas, notas, prompts, textos e transições permanecem. O SHA-256 do JSON serializado das configurações é `bc50d89480ce8a8132d0bcbd2e1182f300680783ad015a649d4e594037f0483c`; o teste de integridade verifica esse valor.

O código da entrega leve era idêntico ao do editor atual fora o projeto incorporado. Foram aproveitadas suas imagens WebP das cenas 2–8. Para a primeira cena, Pillow converteu os PNGs para WebP com `lossless=True, exact=True`, mesma resolução, comparando todos os pixels RGBA após reabrir os arquivos. Transparência e cores preservadas sem perdas. Total: 38 imagens, 11.906.596 bytes; maior imagem: 1.834.390 bytes. O inventário inclui hash, dimensão, modo e tamanho. Não há áudio utilizado pela sequência.

## Execução e QA

- Instalação pelo lockfile: `npm ci` (com `--ignore-scripts --no-audit --no-fund` na validação automatizada); 5 pacotes instalados.
- `npm run check`: 2/2 testes, sintaxe JavaScript válida, configurações originais preservadas, referências completas e hashes das imagens conferidos.
- `npm start`: servidor local em loopback; porta 8770 usada no teste, equivalente à porta padrão 8766.
- Chrome headless com perfil temporário: editor pronto, 8 cenas, 44,3 segundos, todos os recursos esperados carregados, nenhum erro JavaScript. Captura visual da primeira cena conferida.
- QA independente: **VEREDITO: APROVADO**. Navegação das oito cenas e seek repetido determinístico; história alternativa de uma cena carregada pelo mesmo código, persistida e reaberta. Retorno à URL padrão recuperou as oito cenas separadamente. `.env` e tentativa codificada de sair da pasta receberam HTTP 403.

## Conteúdo publicado

Somente `comic_generator/`. `git diff --cached --check`, lista de arquivos preparados, maiores arquivos e busca por padrões de credenciais conferidos. Nenhum vídeo, segredo, dependência instalada ou saída de QA incluído. As regras de ignore foram exercitadas com `.env`, `node_modules`, MP4 em `outputs` e WebM fora dela. O arquivo `.gdignore` evita importação do gerador pelo jogo.

Backups, alternativas, originais pesados, capturas e vídeos anteriores continuam na origem. Resultados e capturas desta execução ficam localmente em `outputs/`, ignorados. O exportador mantém a dependência existente `mp4-muxer`, cujo aviso de descontinuação está documentado no README.

## Exportação completa

Chrome headless exportou a sequência pelo próprio `preview.exportMP4({sequence:true, download:false, height:720, bitrate:2800000})`: MP4 H.264, 1280×720, 1.329 quadros a 30 FPS, 44,3 segundos e 15.021.359 bytes. Metadados lidos por um elemento `<video>`. O projeto empacotado antes e depois permaneceu idêntico; zero erros JavaScript. O vídeo existiu somente em memória, sem inclusão no Git.

O teste percorreu todas as cenas, conferiu assets e repetiu seeks antes da exportação. Não foi repetida exportação 1080p nesta reorganização; o suporte depende do codificador H.264/WebCodecs do navegador. A QA visual em Play do jogo não é parte desta alteração independente.

A busca completa também localizou os checkouts existentes em `Desktop/ah-claude/Godot` e `Desktop/replaced-estudos/after-humans-godot`: ambos estavam limpos na `main`. Permaneceram intactos; a entrega usa um clone separado do mesmo destino.

## Suíte do repositório Godot

`D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_all.gd`: **92/92 testes passaram**, saída 0, em 803.828 ms. Inclui paridade **48/48 lutas, 3.351 passos** e testes de save. `APPDATA` e `LOCALAPPDATA` foram direcionados a `comic_generator/outputs/godot_profile`, sem usar o perfil/saves reais do jogador. Log local: `outputs/godot_tests.log` (ignorado). A importação preparatória gerou apenas cache local; nenhuma mudança do jogo entrou no stage.

## Dashboard e prévia responsiva (evolução do aplicativo)

A raiz agora é a biblioteca de projetos; `editor.html` abre a história selecionada. O catálogo lê automaticamente os manifestos em `stories/`. Importações completas ficam no IndexedDB deste navegador, com IDs próprios. Projetos publicados usam resumos leves no painel; as imagens não são duplicadas nesse resumo. Alterações no nome, número de cenas e duração aparecem ao voltar do editor.

Validação desta entrega:

- `npm run check`: **4/4**. Sintaxe de todos os módulos, integridade do exemplo e regressões de importação inválida (nome não textual, 41 cenas e configuração incompleta).
- Chrome headless: dashboard e editor em 1440×1000 e 390×844; QA independente também em 375 px. Sem overflow horizontal no painel, no editor e na prévia.
- Prévia celular/tablet/tela livre: redimensiona sem alterar o projeto empacotado, câmera, enquadramento ou sequência narrativa.
- Importação, edição e retorno: dois projetos com os mesmos IDs de cena permaneceram independentes; o nome salvo reapareceu no cartão correto.
- Recuperação antiga em `comic_generator:/:default` preservada; entrar pelo cartão padrão retomou a edição anterior.
- Retorno ao dashboard aguarda persistência; bloqueado durante exportação e quando IndexedDB não consegue salvar.
- Exportação real de uma cena em 720p pela QA: 1.052.246 bytes. O motor de exportação continua o mesmo; a exportação completa de 44,3 s registrada acima permanece a referência.
- QA independente: primeira rodada identificou validação insuficiente de import e cobertura de sintaxe; correções com testes de regressão. Rodada final: **VEREDITO: APROVADO**.
- Capturas locais, ignoradas: `outputs/dashboard_desktop.png`, `dashboard_phone.png`, `preview_phone_desktop.png`, `preview_phone.png` e `editor_phone.png`. O registro anterior `outputs/editor.png` preserva a vista do editor antes do dashboard.

O teste desta seção cobre a prévia original em 16:9; o reenquadramento vertical está validado na seção seguinte. Testes de viewport foram feitos em Chrome headless; não substituem uma conferência em aparelhos físicos. Projetos importados e edições locais não são enviados ao servidor nem publicados automaticamente.

Suíte do repositório repetida após a entrega do dashboard, com o mesmo perfil isolado: **92/92 testes passaram**, saída 0, em 727.346 ms, incluindo paridade 48/48. Log local: `outputs/godot_dashboard_tests.log`, ignorado. Nenhum arquivo do jogo, história ou imagem foi alterado nesta evolução.

## Versão móvel com reenquadramento e exportação

- Prévia opcional 9:16, com zoom, deslocamento horizontal/vertical, escala do texto e altura do balão independentes por cena. Valores em `scene.mobileFraming`, separados de `scene.config`; presentes no salvamento, reimportação e duplicação.
- Prévia e MP4 vertical compartilham `composeMobile`; a arte é recortada, e as falas/legendas são recompostas na área segura. Textos máximos de 140/200 caracteres mantêm todos os caracteres e não se sobrepõem. Se necessário, a fonte diminui para caber.
- Configurações, textos, ordem, imagens e duração das oito cenas originais continuam intactos. Nenhuma edição dos arquivos da história ou arte foi preparada para commit.
- `npm run check`: **6/6**, incluindo limites geométricos do recorte em todos os extremos de zoom/pan e regressão de texto longo.
- Chrome headless: ajustes por cena, persistência após reload, reimportação, duplicação, reset, prévia das oito cenas e viewport de 390 px, sem erros JavaScript ou overflow horizontal.
- Exportações da sessão principal com fixture de duas cenas de 1 segundo, derivadas das cenas reais: **720×1280 / 60 quadros / 2 segundos / 836.593 bytes** (celular) e **1280×720 / 60 quadros / 2 segundos / 841.919 bytes** (original). Metadados lidos por `<video>`; projeto empacotado idêntico antes/depois. Resultado local: `outputs/mobile_export_validation.json`.
- QA independente repetiu a exportação da fixture nos dois formatos: 341.082 / 341.383 bytes, ambos com 60 quadros e 2 segundos; cena, tempo e projeto restaurados, sem pageerrors. Confirmou persistência/reimportação/reset/duplicação e as prévias das oito cenas.
- Rodada de QA identificou texto longo fora dos limites e duplicação do aviso de alarme em um recorte extremo. Corrigidos com encaixe sem truncamento e supressão dos textos no passe de arte; apenas o compositor móvel desenha os avisos. Rodada final: **VEREDITO: APROVADO**, sem pendências médias ou altas.
- Capturas locais ignoradas: `outputs/mobile_framing_desktop.png` e `outputs/mobile_framing_phone.png`. Os registros anteriores de prévia 16:9 permitem comparar tamanho de imagem e texto.

Limites desta validação: MP4 móvel validado em sequência curta; a história inteira foi percorrida na prévia, sem reexportar seus 44,3 s no novo formato. H.264/WebCodecs continuam dependendo do navegador. O recorte móvel é fixo por cena e acompanha a câmera original; não adiciona novos keyframes, não reescreve a história e não altera a exportação horizontal.


Suíte Godot executada novamente nesta entrega, em perfil isolado: **92/92 testes passaram**, saída 0, em 749.689 ms; paridade **48/48** preservada. Log local ignorado: `outputs/godot_mobile_tests.log`. O primeiro processo foi interrompido junto com a sessão anterior; a execução da retomada terminou integralmente.
