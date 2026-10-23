"""Baixa só o modelo de exportação da web (web_nothreads_release.zip, ~10 MB) de dentro do pacote de modelos da Godot
(~1,3 GB), lendo o índice do zip e o arquivo pedido por intervalos de bytes (HTTP Range). Usado pelo workflow da versão
web (#39) e para exportar a web numa máquina sem os modelos:
  python tools/fetch_web_template.py 4.7.2 [pasta]
A pasta padrão é a dos modelos da Godot (~/.local/share/godot/export_templates/<versão>.stable).
"""
import struct
import sys
import urllib.request
import zlib
from pathlib import Path

WANTED = ["templates/web_nothreads_release.zip", "templates/version.txt"]


def fetch(url, start, end):
    request = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(request) as response:
        return response.read()


def size_of(url):
    request = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(request) as response:
        return int(response.headers["Content-Length"])


def entries(url):
    """O diretório central do zip (com o Zip64, que o pacote de modelos usa): {nome: (método, tamanho, posição)}."""
    size = size_of(url)
    tail = fetch(url, size - 65536, size - 1)
    end = tail.rfind(b"PK\x05\x06")
    cd_size, cd_offset = struct.unpack("<II", tail[end + 12:end + 20])
    if cd_offset == 0xFFFFFFFF:
        z64 = tail.rfind(b"PK\x06\x06")
        cd_size, cd_offset = struct.unpack("<QQ", tail[z64 + 40:z64 + 56])
    directory = fetch(url, cd_offset, cd_offset + cd_size - 1)
    found = {}
    p = 0
    while directory[p:p + 4] == b"PK\x01\x02":
        method, = struct.unpack("<H", directory[p + 10:p + 12])
        csize, usize = struct.unpack("<II", directory[p + 20:p + 28])
        name_len, extra_len, comment_len = struct.unpack("<HHH", directory[p + 28:p + 34])
        offset, = struct.unpack("<I", directory[p + 42:p + 46])
        name = directory[p + 46:p + 46 + name_len].decode()
        extra = directory[p + 46 + name_len:p + 46 + name_len + extra_len]
        q = 0
        while q < len(extra):
            header, length = struct.unpack("<HH", extra[q:q + 4])
            if header == 1:
                values = list(struct.unpack("<" + "Q" * (length // 8), extra[q + 4:q + 4 + length]))
                if usize == 0xFFFFFFFF:
                    usize = values.pop(0)
                if csize == 0xFFFFFFFF:
                    csize = values.pop(0)
                if offset == 0xFFFFFFFF:
                    offset = values.pop(0)
            q += 4 + length
        crc, = struct.unpack("<I", directory[p + 16:p + 20])
        found[name] = (method, csize, offset, crc)
        p += 46 + name_len + extra_len + comment_len
    return found


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "4.7.2"
    target = Path(sys.argv[2]) if len(sys.argv) > 2 else Path.home() / f".local/share/godot/export_templates/{version}.stable"
    url = f"https://github.com/godotengine/godot/releases/download/{version}-stable/Godot_v{version}-stable_export_templates.tpz"
    target.mkdir(parents=True, exist_ok=True)
    index = entries(url)
    for name in WANTED:
        method, csize, offset, crc = index[name]
        header = fetch(url, offset, offset + 29)
        name_len, extra_len = struct.unpack("<HH", header[26:30])
        start = offset + 30 + name_len + extra_len
        data = fetch(url, start, start + csize - 1)
        data = zlib.decompress(data, -15) if method == 8 else data
        # O CRC32 do índice do zip: um download corrompido não fica no cache do CI.
        if zlib.crc32(data) & 0xFFFFFFFF != crc:
            sys.exit(f"{name}: CRC32 não confere (download corrompido)")
        (target / Path(name).name).write_bytes(data)
        print(f"{target / Path(name).name}: {len(data)} bytes")


if __name__ == "__main__":
    main()
