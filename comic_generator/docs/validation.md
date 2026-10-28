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
