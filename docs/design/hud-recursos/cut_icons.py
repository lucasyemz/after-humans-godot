"""Recorta a folha dos ícones de recurso pintados (fundo magenta #FF00FF) em WebP com alfa limpo.

Uso: python3 docs/design/hud-recursos/cut_icons.py <folha_dos_recursos.png> <energia.png>
As folhas brutas ficam fora do Git. A Energia da folha (a bateria escura) sumia a 24 px no painel: saiu de novo numa
imagem só, mais clara e com o raio maior, e substitui a da folha. Mesmo recorte dos traços (docs/design/hud-station/cut_icons.py): grade 4x2, alfa pela
distância ao magenta, rebarba rosada da borda em cinza. Sem numpy: só Pillow.
"""
import sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "hud-station"))
from cut_icons import OUT, unmix, cells, fit, despill_edges, clean  # noqa: E402

# A ordem da folha. Os nomes são os que o código procura (AHKit.icon("resource_<tipo>")): o relatório usa seeds, scrap,
# fragments, water e supplies (station_report.gd); a barra do alto da Estação usa food, water e power (station_frame.gd,
# os ids de AHStationRules.vitals). Comida e suprimentos são o mesmo recurso: a mesma arte sai com os dois nomes.
SHEET = [["seeds"], ["scrap"], ["fragments"], ["supplies", "food"],
         ["water"], ["bandages"], ["hope"], ["power"]]
# Os que têm luz própria: o halo vazou o magenta da folha e o rosa vira a luz do próprio ícone.
GLOW = {"hope": "warm", "fragments": "violet"}


def relight(icon: Image.Image, kind: str) -> Image.Image:
    px = icon.load()
    for y in range(icon.height):
        for x in range(icon.width):
            r, g, b, a = px[x, y]
            if a == 0 or not (b > g and r > g):
                continue
            if kind == "warm":
                px[x, y] = (r, max(g, int(r * 0.78)), int(g * 0.6), a)
            elif a < 250:
                # Só o halo semitransparente: o violeta do cristal (opaco) fica como foi pintado.
                px[x, y] = (int(min(r, b) * 0.72), int(g), b, a)
    return icon


def main(sheet_path: str, power_path: str, out: Path = OUT) -> None:
    out.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(sheet_path)
    pieces = list(zip(SHEET, cells(sheet, 4, 2)))
    pieces[-1] = (SHEET[-1], Image.open(power_path))
    count = 0
    for names, cell in pieces:
        icon = unmix(cell)
        if names[0] in GLOW:
            icon = relight(icon, GLOW[names[0]])
        icon = clean(despill_edges(fit(icon, 128, 0.04)))
        for name in names:
            icon.save(out / f"resource_{name}.webp", lossless=True, exact=True, method=6)
            count += 1
    print("ícones:", count)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
