#!/usr/bin/env bash
# Aviso de leveza do PR (#38): roda no GitHub Actions e nunca falha.
#   tools/ci_size_check.sh <commit da base> [<commit do PR>]
# Avisa quando o PR acrescenta mais de 5 MB em art/ (conta líquida: o que cresce menos o que encolhe ou sai) ou uma imagem em
# docs/ que a Godot importaria (fora de uma pasta com .gdignore). Escreve anotações ::warning:: e, se houver
# $GITHUB_STEP_SUMMARY, um resumo em Markdown. Os nomes saem sem escape (core.quotePath=false): acento e espaço contam.
set -euo pipefail

base="${1:?uso: tools/ci_size_check.sh <base> [<head>]}"
head="${2:-HEAD}"
limit=$((5 * 1024 * 1024))
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

size_at() {  # size_at <commit> <caminho>: bytes do arquivo naquele commit, 0 se não existe.
	git cat-file -s "$1:$2" 2>/dev/null || echo 0
}

mb() {
	awk -v b="$1" 'BEGIN { printf "%.1f MB", b / 1048576 }'
}

# art/: quanto o pacote cresce, arquivo a arquivo.
total=0
rows=""
while IFS=$'\t' read -r status path; do
	[ -z "$path" ] && continue
	delta=$(( $(size_at "$head" "$path") - $(size_at "$base" "$path") ))
	total=$((total + delta))
	if [ "$delta" -gt 0 ]; then
		rows+="$delta"$'\t'"$path"$'\n'
	fi
done < <(git -c core.quotePath=false diff --name-status --no-renames "$base" "$head" -- art/)

{
	echo "## Leveza do PR"
	echo
	echo "art/: $(mb "$total") a mais (limite do aviso: 5 MB)."
} >> "$summary"
if [ "$total" -gt "$limit" ]; then
	echo "::warning title=art/ cresceu $(mb "$total")::O PR acrescenta mais de 5 MB em art/. Confira se tudo entra no jogo e se a arte passou por tools/sync_combat_art.py (WebP na metade da resolução)."
	{
		echo
		echo "| Arquivo | Acrescenta |"
		echo "| --- | --- |"
		printf "%s" "$rows" | sort -rn | head -n 15 | while IFS=$'\t' read -r bytes path; do
			echo "| \`$path\` | $(mb "$bytes") |"
		done
	} >> "$summary"
fi

# docs/: imagem nova fora de uma pasta com .gdignore (a Godot importaria e ela iria para o pacote).
ignored() {  # ignored <caminho>: há .gdignore na pasta do arquivo ou acima, no commit do PR?
	local dir
	dir=$(dirname "$1")
	while [ "$dir" != "." ] && [ "$dir" != "/" ]; do
		git cat-file -e "$head:$dir/.gdignore" 2>/dev/null && return 0
		dir=$(dirname "$dir")
	done
	return 1
}

loose=0
while IFS= read -r path; do
	[ -z "$path" ] && continue
	case "${path,,}" in
		*.png | *.jpg | *.jpeg | *.webp | *.gif | *.svg | *.bmp | *.tga | *.exr) ;;
		*) continue ;;
	esac
	if ! ignored "$path"; then
		loose=$((loose + 1))
		echo "::warning file=$path,title=Imagem em docs/ sem .gdignore::A Godot importa esta imagem e ela entra no pacote. Ponha um .gdignore na pasta ou tire a imagem do Git."
		echo "- \`$path\` está em docs/ fora de uma pasta com .gdignore." >> "$summary"
	fi
done < <(git -c core.quotePath=false diff --name-only --diff-filter=A --no-renames "$base" "$head" -- docs/)

echo "docs/: $loose imagem(ns) nova(s) fora de .gdignore." >> "$summary"
echo "art/ +$(mb "$total"); imagens soltas em docs/: $loose"
