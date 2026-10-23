# Revisão do acervo Unreal

Consulta remota em 22/10/2026 a `lucasyemz/After-Humans`, branch `main`, pela API do GitHub: listagem completa de caminhos (`truncated=false`) e leitura de textos. Nenhum clone, download de imagens ou alteração no projeto Unreal. Esta revisão não certifica compatibilidade visual dos pixels.

| Acervo | Evidência | Consequência para a entrega Godot |
|---|---|---|
| Reações recentes de Bento/Nick | [README e fontes de Reactions20261020](https://github.com/lucasyemz/After-Humans/tree/main/SourceArt/AllyActions/Reactions20261020) | Derrota aprovada é ajoelhada e compacta; versões horizontais anteriores estão superadas. Rever as novas quedas da #13. |
| Reações antigas da coruja | [SourceArt/Legacy/public/characters](https://github.com/lucasyemz/After-Humans/tree/main/SourceArt/Legacy/public/characters): `coruja-hurt-76c6f9e59a3f51c6.png`, `coruja-death-1766fb84a052e79b.png`, `coruja-defense-4267dd5743df3255.png`, `coruja-dodge-9e34f5dfdb4b8300.png` | Comparar identidade, roupa e escala com Véspera antes de escolher entre fonte antiga e proposta nova. Não declarar esses assets ausentes. |
| Íris atual (sapo) | Não encontrei caminhos de dano/queda identificados como sapo/Íris. Documentação legada usava Íris também para uma coruja. | Não associar arte antiga pelo nome sem conferir a espécie e a identidade. A ausência por nome não prova inexistência de arquivo com outro nome. |
| Recrutas das quatro classes | Não encontrei variantes explicitamente identificadas como recrutas; [IdleForClass](https://github.com/lucasyemz/After-Humans/blob/main/Source/AfterHumans/Characters/AHHeroDefinition.cpp) seleciona os quatro fundadores. | A #14 continua uma proposta útil; não afirmar que todo o acervo de personagens seja novo ou inexistente. |
| Outros personagens e retratos | [Approved static poses](https://github.com/lucasyemz/After-Humans/blob/main/Docs/Art/approved-static-poses.md) documenta 96 PNGs de 11 identidades; CharacterGallery inclui inimigos e auxiliares. | Há material reutilizável. A existência desses personagens não confirma variantes de recrutamento para cão/gato/sapo/coruja. |

As fontes e os PNGs novos deste lote são propostas de design, não substituições automáticas da direção aprovada na Unreal. Os retratos da #26 são recortes dos idles usados neste checkout e continuam sujeitos à escolha final dos recrutas da #14. A integração permanece com Claude na #16, sem alteração de ids.

Atualização em 23/10/2026: Lucas escolheu quedas ajoelhadas na #13. A [entrega revisada](combat-reactions.md) fornece duas quedas compactas a partir dos idles Godot atuais, com canvas, âncora e referência corporal preservados. Esta revisão textual do acervo não foi convertida em uma comparação visual das imagens remotas.
