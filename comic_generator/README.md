# Gerador de tirinhas — After Humans

Editor de cenas em camadas, câmera, atmosfera e exportação MP4 no navegador. Independente da Godot; `.gdignore` impede que a engine importe esta pasta. O exemplo provisório preserva a perda do irmão de Bento: **8 cenas, 44,3 segundos**, sem revisão narrativa.

## Instalação e execução

Requer Node.js 22 ou superior e Chrome/Edge com WebGL. Na pasta `comic_generator/`:

```sh
npm ci
npm run check
npm start
```

Abra http://127.0.0.1:8766 para ver o dashboard. Escolha **Abrir projeto** no cartão da história e clique em **▶ Sequência** no editor. Para outra porta: defina a variável `PORT` antes de executar. A instalação precisa de internet; depois dela o editor, as imagens, Three.js, o muxer e a fonte funcionam localmente. Não abra `index.html` pelo protocolo `file://`.

**MP4 · Cena** exporta a cena; **MP4 · Sequência** exporta a história completa. Use Chrome/Edge com WebCodecs e codificador H.264 disponíveis. O navegador baixa o vídeo; escolha `outputs/` como destino. Vídeos são ignorados pelo Git em toda esta pasta. “Salvar projeto” baixa um `.comic.json` com imagens incorporadas, que pode ser reaberto em “Carregar”.

A recuperação automática fica no IndexedDB do navegador, separada por história ou projeto importado. O editor mantém acesso à recuperação anterior da URL raiz. “Abrir tirinha entregue” salva um backup antes de restaurar o exemplo selecionado. Para conferir a versão publicada após editar no navegador, use esse botão ou um perfil limpo.

## Estrutura

```text
index.html                dashboard de histórias
editor.html               editor e prévia responsiva
src/                      dashboard, biblioteca local, editor, estilos e servidor
config/default_story.json história aberta por padrão
stories/bento_loss/        único exemplo provisório: story.json e assets/
tests/                    verificações de integridade sem navegador
docs/                     inventário e registro de validação
outputs/                  renders, vídeos e relatórios locais (ignorados)
```

`package.json` e `package-lock.json` fixam as dependências. Os nomes obrigatórios dessas ferramentas, `index.html` e `README.md` são mantidos por convenção. O servidor escuta apenas em loopback; destina-se ao uso local.

## Adicionar outra história

1. Crie `stories/my_story/`, com `story.json` e `assets/`; não copie `src/`.
2. Parta do formato do exemplo: `format: "motion-comic-project"`, `version: 1`, `scenes` ordenadas, `selectedId` existente e `assets` indexados por id. Preserve as configurações necessárias de cada cena. Edite cenas, camadas e falas no editor, ou importe um `.comic.json` salvo.
3. Cada `scene.images` relaciona o nome da camada ao id do asset. No disco, cada asset contém `name` e `path` relativo ao `story.json`. Também é aceito `data` com uma imagem incorporada, como no arquivo salvo pelo editor. Camadas visíveis precisam de imagem; `full` é a referência opcional usada pelo botão O.
4. A história aparece automaticamente no dashboard quando há `stories/my_story/story.json`. Abra `http://127.0.0.1:8766/editor.html?story=stories/my_story/story.json`. Para torná-la padrão, altere `config/default_story.json`. A recuperação de cada URL de história fica separada.
5. Publique apenas os recursos usados por essa história, sem históricos ou versões alternativas. Os testes atuais também verificam o conteúdo específico do exemplo Bento; mantenha esse teste e acrescente validação própria para novas histórias.

Os textos podem continuar em português. IDs e chaves do formato existente são preservados para compatibilidade. A interface permite criar e duplicar cenas e adicionar camadas sem duplicar o gerador.

## Recursos e preservação

A origem local foi apenas lida. O código de `index.html` e o da entrega `entrega-direcao-v2` eram idênticos, fora o projeto incorporado. Foram mantidos ordem, IDs, configurações, falas, legendas, enquadramentos, trilhas e notas das oito cenas atuais.

Cenas 2–8 usam as cópias WebP da entrega leve já existente. Os quatro PNGs da primeira cena foram convertidos para WebP **lossless**, na mesma resolução, comparando todos os pixels RGBA (inclusive a transparência). Não houve geração nem substituição criativa de imagens. Os recursos somam cerca de 11,9 MB; o maior fica abaixo de 2 MB. O inventário em `docs/asset_inventory.json` registra dimensão, modo, bytes e SHA-256 de cada imagem. Georgia e as fontes de sistema continuam como alternativas de legendas; Comic Neue 700 é instalada via npm, com licença no pacote `@fontsource/comic-neue`.

Ficaram fora: backups de projetos, histórico de artes, exemplos alternativos, scripts de intervenção pontual, relatórios antigos, imagens de QA, originais pesados, MP4 e outros vídeos. Tudo continua na origem local. `node_modules/`, saídas, caches, builds, ambientes virtuais e `.env` com valores reais são ignorados. Não há dependência dos arquivos do jogo.

O exportador preserva `mp4-muxer@5.2.2`, que o fornecedor marcou como substituído por Mediabunny. A migração de biblioteca fica para outro trabalho; não é necessária para reproduzir esta versão.

Veja [a validação](docs/validation.md) e execute `npm run check` depois de mudar arquivos.


## Dashboard e telas menores

A página inicial lista as histórias existentes em `stories/*/story.json`, com capa, nome, número de cenas e duração. A busca filtra os cartões pelo nome. Use **Importar projeto** para adicionar um `.comic.json` completo, com imagens incorporadas, salvo pelo editor. Cada importação vira um projeto independente neste navegador; editar um não sobrescreve os outros nem os arquivos do disco. O painel reflete mudanças de nome, cenas e duração ao voltar do editor.

**← Histórias** aguarda o salvamento local antes de sair. Durante carregamento ou exportação, a navegação fica bloqueada; se o navegador não puder salvar, o editor avisa e permanece aberto. Continue usando **Salvar projeto** para guardar uma cópia portátil. Limpar os dados do navegador remove os projetos importados e suas edições locais.

**Ver prévia** no cartão abre a visualização em modo celular. Dentro do editor, **Prévia responsiva** alterna entre edição e visualização sem recarregar a história. Opções: **Celular horizontal · 844**, **Tablet · 768** e **Tela livre**; a medida real aparece ao lado. A largura se limita ao espaço disponível, inclusive ao abrir em um celular de verdade. O painel, os controles e o editor se reorganizam em telas menores.

A prévia original preserva o enquadramento 16:9. No modo celular, a opção de reenquadramento prepara uma versão horizontal de celular independente, com os controles abaixo. A narrativa, as câmeras e os tempos do original permanecem iguais.

## Reenquadramento e exportação para celular

1. Abra **Ver prévia** no cartão ou **Prévia responsiva → Celular horizontal · 844** dentro do editor.
2. Marque **Reenquadrar para celular · 16:9**. Escolha a cena no seletor desse painel.
3. Ajuste **Zoom** (1–3×), **Posição horizontal**, **Posição vertical**, **Tamanho do texto** (80–180%) e **Altura do balão**. O recorte acompanha o movimento original da cena. Na ampliação mínima, a imagem inteira é preservada. Os controles de posição ganham efeito conforme o zoom aumenta.
4. Confira o resultado pela linha do tempo e pelo botão **▶ Sequência**. Cada cena mantém ajustes próprios; as demais usam recorte central e texto no tamanho padrão até serem ajustadas. **Restaurar recorte desta cena** repõe apenas os valores dessa versão.
5. Use **MP4 celular · Cena** ou **MP4 celular · Sequência**. A saída é H.264, **1280×720, 16:9, 30 FPS**, com sufixo `_mobile.mp4`.

Quando o zoom é aumentado, a versão horizontal de celular recorta a imagem: revise os atores e o movimento em cada cena. Falas e legendas são recompostas na área segura, com quebra de linhas e ajuste de fonte para caber integralmente. Textos muito longos podem usar fonte menor que a escala solicitada para evitar cortes; os textos nunca são reescritos ou truncados.

Os ajustes ficam em `scene.mobileFraming`, separados de `scene.config`, no salvamento automático e no **Salvar projeto**. Também acompanham duplicação de cena e reimportação do arquivo. A prévia de celular e a exportação usam o mesmo compositor de recorte e texto. Desmarque o reenquadramento para comparar com a prévia original; os botões regulares **MP4 · Cena / Sequência** continuam exportando a versão horizontal, sem os ajustes de celular. Todo o jogo e todas as saídas permanecem na horizontal.

Formato opcional no manifesto da cena (posições de 0 a 1):

```json
"mobileFraming": {
  "zoom": 1,
  "x": 0.5,
  "y": 0.5,
  "textScale": 1,
  "speechY": 0.2
}
```

Cenas sem esse campo usam esses valores padrão na versão horizontal de celular. A exportação original ignora o campo.

## Recuperação por história

O salvamento usa o caminho canônico do manifesto, mesmo quando aberto como história padrão, URL absoluta ou caminho com `./`. Trocar `config/default_story.json` não mistura as edições de histórias diferentes. Projetos importados continuam isolados por UUID.

A compatibilidade com a antiga base `:default` pertence somente ao exemplo original, declarada em `legacyRecovery` com caminho proprietário. Copiar esse manifesto para outro caminho não transfere a propriedade do salvamento antigo. A migração copia `current` e `previous` apenas quando encontra identidade de cena compatível; nenhuma base antiga é apagada. Se houver ambiguidade, o menu **Recuperação → Recuperar projeto antigo (faz backup)** oferece acesso explícito e mantém essa opção mesmo após novos salvamentos.

Edições locais da mesma história continuam tendo prioridade sobre o arquivo no disco. Para carregar uma atualização do disco, use **Abrir tirinha entregue (faz backup)**. As notas editoriais originais podem conservar referências de produção antigas; elas não são dependências de execução. Foram retirados o histórico de artes e o campo `referenceId`, preservando as notas.
