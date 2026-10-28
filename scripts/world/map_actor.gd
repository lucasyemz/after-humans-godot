## Um personagem parado no mapa da exploração, fora da fila da equipe, com quem a equipe interage pela ação "interact"
## (#179): o caído deitado no lugar da luta. Feito para ser reaproveitado (#188, o herói preso que pede ajuda): a pose
## numa placa de personagem, o texto da ação ("E  Levantar %s") e o ponto do marcador acima da cabeça.
class_name AHMapActor
extends AHSpriteCard

## Quanto o marcador fica acima da cabeça (m).
const MARKER_ABOVE := 0.3

## O herói (ou o id do personagem) que a placa mostra.
var actor_id := ""
## O texto do aviso da ação, já traduzido e com o nome.
var action_text := ""
## A altura do marcador sobre o pé (m); negativa, acima da cabeça da pose de pé (o caído deitado fica mais baixo).
var marker_height := -1.0


## Monta a placa: a pose (uma entrada de combat_art.json), a altura do corpo e o tom.
static func create(id: String, pose: Dictionary, height: float, tint: Color = Color.WHITE) -> AHMapActor:
	var actor := AHMapActor.new()
	actor.actor_id = id
	actor.name = "MapActor_%s" % id
	actor.body_height = height
	actor.show_art(pose)
	actor.set_tint(tint)
	return actor


## Onde fica o losango e o aviso da ação, no mundo.
func marker_point() -> Vector3:
	return global_position + Vector3(0, marker_height if marker_height >= 0.0 else head_height() + MARKER_ABOVE, 0)
