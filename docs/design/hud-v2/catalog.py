"""Atualiza a galeria após render.py; não executa o jogo."""
import sys
sys.dont_write_bytecode=True
from pathlib import Path
import json
OUT=Path(__file__).resolve().parent
NOTES={
'combat':'Saem os nomes e valores duplicados, as quatro descrições de habilidade e o texto fixo de instrução. Ficam posições, vida gráfica, trilha de instinto, ordem, ator e atalhos. Nome/valores/estados e intenção aparecem no foco.',
'combat-action-focus':'O ícone da ação revela o nome e a consequência antes de confirmar. Mesmo efeito no mouse, teclado e controle; o restante da barra não ganha descrições simultâneas.',
'combat-area-target':'Mira real do Coquetel Corrosivo. O corpo inteiro recebe o clique. Alvo e vizinho atingido têm luz e formas distintas; a legenda curta não substitui a lista de atingidos no foco. O frame de daltonismo foi renderizado pela Godot com a nova cor da luz, sem repintar o ator.',
'combat-target':'Prévia da primeira habilidade válida do herói capturado. O nome do alvo vem de “Atinge” da captura, não de uma escolha inventada. O outro inimigo mantém a luz fraca de alvo válido e não recebe a marca de atingido.',
'combat-skill-focus':'Arte e atalho ficam na barra; dano, posições, efeito e recarga/usos aparecem só no foco. Dica480 Normal/640 Maior; detalhe18/23. A dica muda de lado para deixar o ator atual e o alvo visíveis.',
'combat-unit-focus':'Vida numérica, instinto, limiar e posição ficam juntos no foco do ator atual. Os outros aliados e inimigos usam a mesma ficha, com seus próprios valores; não repetir a ficha inteira sob cada corpo.',
'combat-intent-focus':'O ícone da intenção revela a ação original e os afetados. A intenção não usa só laranja: símbolo, nome e direção continuam disponíveis no foco.',
'combat-crisis':'A crise interrompe a leitura com um aviso curto e texto explícito, sem abrir um segundo painel de dados. Estado encenado pela API real da HUD em campanha de captura.',
'combat-result':'A barra de comandos sai. Resultado, sobreviventes e vida ficam numa única superfície; uma ação continua. A vitória foi apresentada pela API para capturar a tela, não atesta uma batalha vencida.',
'combat-inventory':'A mesma Mochila da exploração, com o herói da vez da captura; a ação livre e o limite por vez aparecem no detalhe. Ampola continua habilidade do sapo dentro da luta. Comida custa1/3 para15%/35%, sem importar a regra da fogueira.',
'explore':'Lugar e sequência ficam; objetivo detalhado, esperança, achado e fichas de aliados saem da vista fixa para o foco. Retratos e ícones substituem rótulos repetidos. Comida e curativo continuam à vista.',
'explore-objective-focus':'O ícone do objetivo abre o texto real da rota e a condição do guardião; a instrução não ocupa a tela durante toda a caminhada.',
'explore-resources-focus':'Detalhe de comida, curativos, ampola, achado e esperança. Não confundir o achado ainda na expedição com as sementes já no estoque da Estação.',
'explore-team-focus':'Um aliado em foco revela vida, instinto, posição e estados. A mesma ficha vale para os quatro e para recrutas; não trocar a informação por uma cor sem legenda.',
'explore-interaction':'Aviso local com ícone e ação somente ao alcance do objeto. Os atalhos gerais não repetem a mesma instrução pela tela.',
'explore-patrol':'Aviso curto com símbolo de alerta e palavras, legível na rua clara e no escuro. A forma continua reconhecível sem vermelho.',
'explore-camp':'Mesmos painéis, fichas e botões. Antes de usar, mostrar comida, curativos, vida, instinto e efeito. No frame, os quatro estão cheios: ações indisponíveis com barras e motivo no foco. Não substituir as poses nesta proposta de HUD; a integração da arte de descanso é da #77/#82.',
'explore-risk':'A perda de metade do achado fica no próprio diálogo. Continuar é o foco inicial; voltar exige uma ação explícita e mantém a consequência escrita.',
'explore-event':'A narrativa e as três escolhas permanecem completas. A ilustração redundante sai desta vista para reduzir o painel; requisitos e risco ficam junto da opção, com símbolo de bloqueio e foco separado.',
'scenario-event':'Mesmo cartão, molduras e hierarquia no Abrigo Lacrado. Texto e escolhas são os da Sala dos Esporos; nenhuma HUD nova para esta fase.',
'explore-inventory':'A grade é dividida por categorias e só um detalhe fica aberto. O aliado, custo, efeito e motivo de bloqueio acompanham o item. Estoque de ferramentas vazio é indicado no foco da categoria, sem ocupar a vista de suprimentos.',
'explore-interior':'Mesmo HUD dentro da mercearia; o texto de progresso vira Interior. A casa foi aberta em campanha isolada com a patrulha marcada como vencida, usando a cena real.',
'explore-search':'A captura mostra a busca concluída: comida sobe de4 para5 e chega1 semente ao achado. O aviso diz o que foi encontrado, sem fingir que a busca ainda está em curso.',
'explore-loot':'Um achado sobe perto do objeto, com ícone e quantidade. Fonte recapturada com o ícone correto lobby-scrap; a captura auxiliar com o ícone ausente não entrou na entrega.',
'explore-touch':'Mesma interface, com áreas de toque112×112 e espaço16. O detalhe abre no primeiro toque e a confirmação fica separada. A redução real a40% deixa44,8px por alvo e testa hierarquia e formas; não comprimir os alvos interativos abaixo do mínimo do dispositivo.',
'station':'Os doze serviços não se acumulam sobre o cenário. Recursos principais, próximo passo e entrada da expedição ficam; cômodos são escolhidos na própria base. Materiais aparecem no custo da decisão.',
'station-room-focus':'Só o cômodo apontado recebe sua ficha e Gerenciar. Foco não aciona, nem troca os ids das salas; teclado e mouse usam a mesma ficha.',
'station-hidden':'Ocultar HUD remove também o cabeçalho; fica o frame real da Estação. F2 restaura e devolve o foco anterior.',
'station-plan':'Lista de cômodos à esquerda; um único detalhe e custo à direita. O mapa em corte continua visível entre os painéis. Cômodo vazio não ganha uma função que ainda não existe.',
'station-characters':'Quatro fichas de elenco e um detalhe selecionado, em vez de descrições e serviços de todos simultaneamente. Vida, instinto, expedições e relíquia são mantidos no detalhe; recrutar permanece uma ação separada.',
'station-character-focus':'Ficha selecionada com os valores reais de Bento e acessos a relíquia/trauma. Os demais usam a mesma estrutura, com seus próprios dados.',
'station-forge':'Estado vazio real: função e custo separados da ação Recuperar. Não oferecer fabricar antes da recuperação.9-slice e botão são os do kit.',
'station-research':'Estado vazio real com custo3 sucatas e2 fragmentos, sem criar melhoria ou receita. Texto e custo crescem para o Maior.',
'station-depot':'Fichas de estoque, capacidade e excesso separados do botão Melhorar. Custo5 sucatas e1 fragmento visível antes de confirmar; ferramentas e relíquias vazias por escrito.',
'station-canteen':'Produção, demanda da equipe, moradores, água e energia ficam juntos na decisão da Cantina. Os números são os do frame; não resumir previsão a uma luz verde.',
'station-dormitory':'Estado sem noite pendente: informa que ninguém precisa descansar agora. Não oferecer uma noite falsa para preencher o painel.',
'station-bar':'Estado vazio real, sem uso por enquanto; não inventar serviços nem uma ação de recuperar inexistente.',
'station-train':'Pedido em faixa superior, rosto e corpo de Dora livres, decisão lateral. Benefício, consumo de água e previsão antes/depois ficam à vista; Acolher e Recusar não dependem de cor.',
'station-preparation':'Posição, vida e quantidade de habilidades válidas nas fichas da equipe. Foco e comida têm controles claros; custo em sementes aparece junto do ajuste. Partir é a única decisão principal.',
'station-map':'Sai o bege e entra a variante #69. Estados são palavra e forma; escolha e foco são independentes. Nós mantêm o papel geográfico, etiquetas podem se deslocar com ligação; o cenário de fundo é o mapa atual.',
'station-report':'Resultado, três recursos entregues e os quatro sobreviventes num só painel. O ferimento de Nick8/24 permanece evidente. Narrativa e desbloqueios passam para o detalhe do relatório.',
'station-report-focus':'O detalhe conserva a observação narrativa original e os custos das obras liberadas. Não inventar eventos ou promessas de gameplay.',
'station-night':'Dormir/Vigiar por aliado, previsão da noite e custo do suprimento antes de Iniciar descanso. Nick8/24 recupera8 de vida. Estas regras não são as da fogueira.',
 'title':'A imagem e o logo reais continuam. Duas entradas claras sem save; foco inicial na Nova campanha.',
 'title-continue':'Continuar aparece com save; Nova campanha, Campanhas e Opções mantêm a mesma família de botões. O menu não vira uma HUD diferente.',
 'title-slots':'Os três espaços conservam ciclo, fases, vivos e data do save existente. Espaços vazios são explícitos; foco e seleção são separados.',
 'title-slots-empty':'Três espaços vazios, sem campanha falsa para ornamentar a tela. A mesma geometria cabe no Maior.',
 'title-confirm':'A perda do progresso do espaço1 e a preservação dos demais são escritas antes da escolha. Cancelar é o foco inicial.',
}
for n in ['title-options','station-options','explore-options']:
 NOTES[n]='Mesmas categorias e controles nas três entradas. Acessibilidade reúne os três tamanhos e daltonismo; Som, Imagem e Jogo têm pranchas próprias. Não repetir todos os ajustes numa lista longa sobre a cena.'
NOTES.update({'options-sound':'Som: Música, Ambiente e Efeitos em60%, com valor textual e barra. Mesmos painéis, fonte e foco das demais opções.','options-image':'Imagem: qualidade Alto, tela cheia, sincronização vertical e redução de efeitos. O controle em foco mostra o estado por escrito.','options-game':'Jogo: velocidade da batalha, dicas e idioma Português/English em teste. São os controles existentes, sem novo sistema de atalhos configuráveis.'})
def main():
 rows=json.loads((OUT/'counts.json').read_text());pages=sorted({r['page'] for r in rows});lines=['# Galeria da HUD v2 — #58','','54 telas/estados, cada um em Normal, Maior, daltonismo e Maior com daltonismo. PNG1920×1080; cinza e redução real a40% como evidência de QA. [Sistema, medidas e decisão de interação](system.md) · [Resumo antes/depois](summary.png) · [QA](qa.md).','','As variantes de foco novas usam a captura anterior indicada na tabela. Ela é referência da vista anterior, não uma alegação de que aquele novo estado já existia no jogo. Valores são do frame correspondente; capturas independentes podem começar com heróis diferentes. As contagens excluem textos encobertos pelo fundo opaco do mapa e glifos totalmente cortados, com o caminho e o motivo em `counts.json`.','','| Tela/estado | Normal | Maior | Daltonismo | Maior + daltonismo |','|---|---|---|---|---|']
 for p in pages:lines.append(f'| {p} | [PNG]({p}.png) | [PNG]({p}_large.png) | [PNG]({p}_colorblind.png) | [PNG]({p}_large_colorblind.png) |')
 for p in pages:
  lines+=['',f'## {p}','',NOTES[p],'',f'![Prévia a40%]({p}_40.webp)','','| Perfil | Referência real | Textos antes → depois | Números antes → depois |','|---|---|---|---|']
  for r in [q for q in rows if q['page']==p and q['profile'] in ['normal','_large']]:lines.append(f"| {'Maior' if r['profile']=='_large' else 'Normal'} | [JPG]({r['source']}) | {r['before']['text_blocks']} → {r['after']['text_blocks']} | {r['before']['numbers']} → {r['after']['numbers']} |")
  lines+=['',f'[Cinza]({p}_gray.webp) · [Normal completo]({p}.png) · [Maior completo]({p}_large.png) · medidas na [folha do sistema](system.md).']
 (OUT/'index.md').write_text('\n'.join(lines)+'\n')
if __name__=='__main__':main()
