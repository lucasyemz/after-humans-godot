# Originais — recrutas em camadas (#191)

60 PNG RGBA normalizados, dez por classe. As seis classes são dog, cat, frog, owl, raccoon e armadillo. São fontes para conversão; não copiar esta pasta para a main.

Todas as camadas de uma classe têm o mesmo canvas e origem (0,0). Reutilizar a âncora canônica e a altura de corpo do contrato, convertendo coordenadas pela razão uniforme da largura. Não recentrar pelo alfa de acessórios. Usar os tamanhos WebP finais do contrato; existem canvases de altura ímpar.

Ordem: bag → uma base_a/base_b → clothes → scarf → cap → uma badge. Roupa/lenço/gorro em cinza para multiplicar a cor; demais sem tint. Fonte alfa normal, sem blend aditivo. As máscaras da roupa já deixam mãos/armas do corpo visíveis. Não empilhar as duas bases ou as quatro insígnias. As cores dos exemplos são amostras do kit, sujeitas à escolha do Lucas.

Integração pelo Claude na #189, usando tools/sync_combat_art.py e preservando ids. Documentação e gerador no PR, em docs/design/recruit_layers.md e docs/design/recruit_layers/. Os atlas brutos da geração ficam fora do Git; estes PNG individuais são as fontes normalizadas.

Esta tag tem árvore própria contendo apenas fontes/contrato. O ZIP automático do Release é o pacote baixável dos originais. O histórico do PR para a main não contém estes PNG.
