# Orquestração: como o Lucas toca os agentes

Guia para continuar de qualquer máquina (Windows ou MacBook). O Lucas orquestra; o trabalho fica com os agentes na
nuvem. O Claude local (esta conversa, ou uma nova) revisa e integra os PRs.

## Quem faz o quê

| Agente | Branch | Faz | Ciclo |
|---|---|---|---|
| Claude da nuvem | `claude-cloud` | código, regras, integração, testes (issues `[Claude]`) | dev → QA (`.claude/agents/qa.md`) até APROVADO |
| Codex | `codex-design` | imagens e propostas de tela (issues `[Codex]`) | designer → QA de design (`docs/design/qa.md`) |
| Claude local | `main` | revisa, faz o merge, integra a arte do Codex e atualiza os branches | QA local antes do push |

Issues: `[Agente] Área: descrição`, etiquetas `agent:claude` ou `agent:codex` e o tipo; as de decisão do Lucas levam
`question`. Só o Lucas fecha uma issue, depois de jogar.

## Montar o MacBook (uma vez)

```bash
git clone https://github.com/lucasyemz/after-humans-godot.git
cd after-humans-godot
```

- Godot 4.7.2 para macOS (godotengine.org ou o GitHub `godotengine/godot-builds`, tag `4.7.2-stable`). O executável
  fica em `/Applications/Godot.app/Contents/MacOS/Godot`.
- `gh auth login` (GitHub CLI) e `pip3 install pillow soundfile`.
- Importar uma vez: `Godot --headless --path . --import`.
- Testes: `Godot --headless --path . -s tests/run_all.gd` (25 de 25, paridade 48/48).
- Captura da rua: `Godot --path . --resolution 1920x1080 -- --capture=/tmp/cap`. Do título: `-- --capture-title=/tmp/t`.
- Saves e opções do jogo no Mac: `~/Library/Application Support/Godot/app_userdata/After Humans`. As automações não
  gravam ali (conferir as datas antes e depois).
- A pasta da Unreal não está no Mac: `tools/sync_assets.py`, `sync_audio.py`, `unreal_export_*.py` e a parte da
  `sync_combat_art.py` que lê `SourceArt` só rodam no Windows. No Mac, a arte do Codex entra pelos WebP já convertidos.

## Rodada de um agente

Mandar na sessão do agente (a que já existe; não abrir duas no mesmo branch):

```
Nova rodada: git fetch origin && git checkout <branch> && git pull --ff-only origin <branch>.
Faça as issues #A, #B… nessa ordem, com o mesmo ciclo de sempre (QA até APROVADO, push no <branch>,
comentário em cada issue e um PR para a main no fim). Leia cada uma com "gh issue view N --comments".
```

## Integrar um PR (o Claude local faz; o Lucas pede "revisa e faz o merge do PR #N")

1. `git fetch origin`; ler o PR (`gh pr view N`), os commits e o CI (o workflow `tests.yml` roda em todo PR).
2. Conferir o escopo: o Codex não mexe em `scripts/`, `data/`, `tests/`; nada de PNG pesado fora de pasta com
   `.gdignore`; `docs/` não entra no pacote.
3. Merge na `main` local; resolver conflito mantendo os dois lados; testes inteiros; captura da rua e da luta (e do
   título, se mexeu).
4. Arte pesada do Codex: guardar o original numa tag (`codex-prN-originals`), deixar na `main` só o que o jogo usa.
5. Passar pela QA (agente `qa`) quando o merge pede código novo; corrigir até APROVADO.
6. Push na `main`, comentário no PR, e `git push origin main:claude-cloud main:codex-design` só quando o agente não
   estiver no meio de uma rodada.

## Onde paramos (22/10/2026)

- **Main:** 7270342, com o PR #47 do Claude da nuvem (CI, título, molduras, ícones, beliche, eventos, toque,
  recrutas) e o #46 do Codex (poses dos vilões do John). Os três branches iguais à `main`.
- **Mandar ao Claude da nuvem** quando ele terminar o que está fazendo: issues **#52, #48, #50, #51**, nessa ordem
  (revisão visual dos cenários, os pés escondidos no Depósito, os props vasculháveis da Rua, a silhueta da Unreal).
- **Mandar ao Codex:** issue **#49** (props da Rua das Vitrines, fechados e abertos).
- **Decisões do Lucas em aberto:** #9 (morte permanente), #11 (Bar e Dormitório), #12 (pacote do celular: resolução
  das texturas), #13 (quedas da Íris e da Véspera: ajoelhada ou deitada), nome final do golpe do Enraizado
  ("Golpe de Raízes (provisório)"), e o Núcleo Nulo como chefe.
- **Em espera:** #40 (respiração dos heróis), para o Auto Sprite.
- **Decidido:** treinos da Pesquisa valem na luta; dificuldade crescente dentro de cada fase (fases 3 e 4 mais duras,
  mantidas); vilões do John pela distribuição dele, com o Porteiro de chefe e o Robô de volta nas fases 2 e 5.
- **Só no Windows:** as fontes das poses do John estão em `SourceArt/CharacterGallery/JohnCombatPoses20261022` na
  pasta da Unreal (e na tag `codex-pr46-originals`); o metrô sai de `tools/unreal_export_metro.py`.
