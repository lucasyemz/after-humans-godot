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

## Revisor dos PRs (terceiro agente)

O workflow `.github/workflows/review.yml` põe um Claude independente para revisar todo PR para a `main` (aberto, saído
de rascunho ou atualizado). Ele usa os critérios das duas QAs e do `AGENTS.md` e responde com um veredito no próprio
PR: PRONTO PARA O MERGE, AJUSTAR ANTES ou NÃO INTEGRAR. Ele só comenta; o merge continua com o Lucas (ou o Claude
local). As instruções ficam em `.github/review-instructions.md`.

Roda pela assinatura do Lucas, sem chave de API: gasta da cota do plano, como as sessões. Para ligar, uma vez só, num
terminal com o `claude`:

```bash
claude setup-token
gh secret set CLAUDE_CODE_OAUTH_TOKEN --repo lucasyemz/after-humans-godot
```

O primeiro comando gera o token da conta; o segundo pede para colar e guarda como segredo do repositório (ninguém mais
vê). Para revisar de novo um PR: em Actions, "Revisão", "Run workflow", com o número do PR.

## Fila de trabalho (24/10/2026)

- **Claude da nuvem:**
  1. #61 (trem fora do tempo);
  2. #62 (paredes sem textura);
  3. #57 (alvo pelo personagem inteiro);
  4. #13 (quedas ajoelhadas);
  5. #63 (varredura visual);
  6. #64 (narrativa);
  7. #35 (inglês);
  8. a parte segura da #56.
  - A #60 (componentes) e o resto da #56 esperam o Lucas aprovar a #59 e a #58.
- **Codex:** #59 (kit de componentes), depois #58 (telas novas montadas com o kit).
- **Regras novas no `AGENTS.md`:** narrativa coerente com `docs/narrative/` e coerência visual, que a QA confere.

## Onde paramos (23/10/2026)

- **Main:** 729e310, com o PR #55 do Claude da nuvem (#52 lutas nos cenários, #50 props de busca, #51 silhueta e as
  pendências de #33 a #39 e #48) e as entregas do Codex #53 (props, #49) e #54 (quedas ajoelhadas, #13). Os três
  branches iguais à `main`. Testes: 34 de 34, paridade 48/48.
- **Originais do Codex fora da main:** tags `codex-pr53-originals` (props) e `codex-pr54-originals` (quedas). As tags
  são publicadas da máquina do Lucas (a sessão na nuvem não publica tags).
- **Próximo para o Claude da nuvem:** integrar as quedas ajoelhadas da #13 (converter da tag `codex-pr54-originals`
  para WebP e ligar hurt e death da Íris e da Véspera) e as telas que faltam em inglês (#35, cerca de 2.000 literais).
- **Codex:** sem issue pendente.
- **Para o Lucas no Play:** a #55 pede conferir a luta pequena na ponta de uma zona (até 5,5 m da patrulha), a cerca
  do Portão de Triagem que esmaece sozinha e o caixa vasculhado da mercearia (pouca diferença do fechado).
- **Decisões do Lucas em aberto:** #9 (morte permanente), #11 (Bar e Dormitório), #12 (pacote do celular: resolução
  das texturas), nome final do golpe do Enraizado ("Golpe de Raízes (provisório)"), o Núcleo Nulo como chefe, e a
  proposta de o Codex entregar já em WebP, com os originais fora do repositório.
- **Em espera:** #40 (respiração dos heróis), para o Auto Sprite.
- **Decidido:** treinos da Pesquisa valem na luta; dificuldade crescente dentro de cada fase (fases 3 e 4 mais duras,
  mantidas); vilões do John pela distribuição dele, com o Porteiro de chefe e o Robô de volta nas fases 2 e 5; quedas
  da Íris e da Véspera ajoelhadas.
- **Só no Windows:** as fontes das poses do John estão em `SourceArt/CharacterGallery/JohnCombatPoses20261022` na
  pasta da Unreal (e na tag `codex-pr46-originals`); o metrô sai de `tools/unreal_export_metro.py`.
