# Orquestração: como o Lucas toca os agentes

Guia para continuar de qualquer máquina (Windows ou MacBook). O Lucas orquestra; o trabalho fica com os agentes na
nuvem. O Claude local (esta conversa, ou uma nova) revisa e integra os PRs.

## Quem faz o quê

### As frentes (desde 26/10/2026; a Awesomic 2 saiu em 27/10)

Cada frente tem a sua etiqueta nas issues. Ninguém pega issue de outra frente, para dois agentes nunca mexerem no mesmo
arquivo ao mesmo tempo.

| Agente | Etiqueta | Branches | Frente |
|---|---|---|---|
| **Claude 1** (nuvem) | `claude-1` | `claude-cloud-<issue>` | **Estação e regras:** ninguém morre e Enfermaria (#118, #121), a Estação (#131), a preparação (#123), o trem dos recrutas (#122), limites e postos (#119), a noite (#132), o som do trem (#133), as skins (#138) |
| **Claude 2** (nuvem) | `claude-2` | `claude2-<issue>` | **Exploração, mapas, tutorial e ambiência:** o tutorial (#144, #145, #147), a exploração (#129, #143, #142), a água e o Cais (#140, #141), a ambiência (#153, #154) |
| **Awesomic 1** | `awesomic-1` | `design-<assunto>` | **Design de telas e cenários:** a Estação e a HUD (#120, #124, PR #139; #134, PR #148) e, desde 27/10, os cenários, o tutorial e a ambiência que eram da Awesomic 2 (#146, a arte da #147, da #154 e as camadas da #141, se o Claude 2 pedir) |
| **Codex** (design) | `agent:codex` | `codex-<issue>` | **Poses de personagem** (desde 28/10, por ser mais consistente em manter o personagem igual): as 16 poses do Bento Mergulhador (#137), a pose de ferido (#195) e os recrutas em camadas (#191) |
| Claude local | — | `main` | Revisa e junta os PRs, roda os testes no Windows, faz o build e escreve as issues e as mensagens |

**Regras entre as frentes:**
- um PR por issue, para a `main`, com a `main` trazida para o branch antes de abrir o PR;
- uma branch nova por issue, saída da `main`; quando o PR entra, a branch é apagada (o GitHub apaga sozinho com
  "Automatically delete head branches" ligado; quem juntar confere) e ninguém volta a usá-la;
- os arquivos de todos (`data/i18n/en.po`, `tools/i18n_ignore.txt`, `data/presentation/*.json`, o kit) dão conflito: o
  Claude local resolve na junção;
- uma issue nova entra na frente da área dela. Na dúvida, o Lucas decide;
- a arte de cenário e de luz se prova na captura do jogo em Forward+, que só o Orquestrador PC (com placa de vídeo) tira:
  a nuvem e a Awesomic não têm placa de vídeo, e montagem 2D não vale como prova.

### Os dois orquestradores (desde 26/10/2026)

| Orquestrador | Onde | Faz |
|---|---|---|
| **Claude Orquestrador Nuvem** | claude.ai/code, pelo celular | conversa com o Lucas quando ele não está no PC; escreve issues e mensagens; revisa PRs; junta os PRs simples |
| **Claude Orquestrador PC** | o Claude local no Windows | o teste definitivo: junta os PRs que mexem no jogo, roda os testes e as capturas na Godot do Windows, faz o build, cuida da referência da Unreal (que só existe nesse PC) e dos saves do Lucas |

**Quem junta o quê:**
Desde 27/10/2026 o da nuvem junta sozinho, na ronda automática (abaixo), com o CI verde e o revisor em PRONTO PARA O MERGE:
- **os PRs de documentos;**
- **os PRs de código que não mudam o que se vê** (Claude 1 e Claude 2), com um comentário no PR avisando que falta o teste
  no Windows. O do PC faz esse teste depois, na `main`.

**O que muda o que se vê nunca entra sozinho** (decisão do Lucas, 27/10, depois do #156): arte em `art/`, cenários, telas,
HUD, luz e animação, seja PR de design ou de código. O revisor lê o diff, mas não vê se fica bonito no mapa. O da nuvem
resume o PR para o Lucas com as capturas do jogo e espera o ok dele no PR ou na conversa.

**Para os dois não juntarem ao mesmo tempo:** antes de juntar, comentar no PR "Integrando (Orquestrador Nuvem)" ou "Integrando (Orquestrador PC)". Se o outro já comentou, não mexer.

**O que os dois fazem igual:**
- as issues no formato `[Agente] Área: descrição`, com a frente certa (`claude-1`, `claude-2`, `awesomic-1`);
- os textos em português;
- as decisões do Lucas registradas na issue ou no PR;
- nunca escrever `@codex` ou `@claude` em comentários.

### A ronda automática do Orquestrador Nuvem (desde 27/10/2026)

Uma tarefa agendada acorda o Orquestrador Nuvem de hora em hora (e os eventos dos PRs também o acordam). Em cada ronda:

1. **Lê os PRs abertos para a `main`:** o CI, o comentário do revisor, o escopo (os arquivos), os conflitos e os
   comentários do Lucas.
2. **Junta** quando tudo bate: CI verde, revisor em PRONTO PARA O MERGE, sem conflito, sem pedido do Lucas em aberto no
   PR, sem a etiqueta `descartar` e sem "Integrando (Orquestrador PC)". O que muda o que se vê espera o ok do Lucas. Antes, comenta "Integrando (Orquestrador Nuvem)"; nos de código, avisa que
   falta o teste no Windows. A branch é apagada depois do merge.
3. **Devolve para o agente** quando o PR pede ajuste: o revisor em AJUSTAR ANTES, o CI vermelho ou um pedido do Lucas.
   O Claude 1 e o Claude 2 recebem a mensagem direto na sessão deles; o Awesomic 1 e o 2 recebem pela issue e pelo
   Lucas, até eles poderem ler o GitHub sozinhos.
4. **Passa a próxima tarefa** a um agente parado: a próxima issue aberta da etiqueta dele, na ordem da tabela das
   frentes. Só issues que o Lucas pediu; nada fora delas.
5. **Pergunta ao Lucas** e não junta quando: o revisor diz NÃO INTEGRAR; o PR traz uma escolha entre alternativas, uma
   regra nova ou um texto da história que o Lucas ainda não aprovou; o PR sai da issue dele; ou dois PRs se contradizem.
   Os números de balanceamento que o PR marca como proposta podem entrar, e a pergunta vai para o Lucas.

O que a ronda nunca faz: criar issue ou tarefa por conta própria, mudar o escopo de uma issue, mexer no código do jogo,
fechar issue sem o PR dela na `main`.

### Os papéis

| Agente | Branch | Faz | Ciclo |
|---|---|---|---|
| Claude da nuvem (1 e 2) | os da frente | código, regras, integração, testes (issues `[Claude]`) | dev → QA (`.claude/agents/qa.md`) até APROVADO |
| Codex e Awesomic (1 e 2) | os da frente | imagens e propostas de tela (issues `[Codex]`, `[Design]`) | designer → QA de design (`docs/design/qa.md`) |
| Claude local | `main` | revisa, faz o merge, integra a arte e atualiza os branches | QA local antes do push |

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
6. Push na `main`, comentário no PR e a branch do PR apagada. As branches fixas antigas (`claude-cloud`,
   `codex-design`) não existem mais: cada issue nova sai da `main` numa branch própria.

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

O revisor não chama agentes: o Lucas manda as correções manualmente para o Codex e para o Claude da nuvem, a partir
do comentário da revisão.

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
- **O novo laço de jogo** (`docs/design/loop-proposal-maa.md`, aprovado em 24/10), na ordem:
  - Claude: #88 (briefing), #89 (ficha ao apontar), #90 (nível até 10 e Treino), #91 (fim de luta e carga de 1 em 6),
    #92 (3 missões curtas mais o chefe, com o mapa #86 e #87), #93 (laços à vista), #94 (Pesquisa por expedições),
    #95 (desafios dos chefes);
  - Codex: #96 (as telas de todas elas com o kit).
- **Regras novas no `AGENTS.md`:** narrativa coerente com `docs/narrative/` e coerência visual, que a QA confere.

## Onde paramos (24/10/2026)

- **Main:** com os PRs #67, #68, #71 e #81 do Claude da nuvem (trem, paredes, quedas ajoelhadas, narrativa, alvo pelo
  corpo, inglês, HUD enxuto em parte, varredura visual e a história nas fases 2, 3 e 5) e os do Codex #65 (kit da
  interface #59, vagão e cartão de passagem #79, descanso dos recrutas #80) e #83 (fundadores sentados no chão #82,
  etiquetas do mapa #69). Testes: 40 de 40, paridade 48/48. `claude-cloud` e `codex-design` iguais à `main`.
- **Issues:** as concluídas foram fechadas em 24/10 a pedido do Lucas (49). Ficaram 24 abertas.
- **Em andamento, não mexer sem olhar antes:**
  - `claude-cloud-passagens`: fluxo A do Claude da nuvem, issues #74 (passagem com título), #75 (partida no vagão) e
    #76 (volta à Estação). Depois vem a #77 (acampamento), que já tem a arte das #80 e #82.
  - `claude-cloud-eventos`: fluxo B, a #78. Os 20 eventos de busca (4 por fase) estão no branch e esperam a aprovação
    do Lucas na issue, junto com a decisão (A) ou (B) sobre os efeitos de fase que não funcionam.
- **A fazer:** #84 (efeitos de impacto e de estados da #41 na luta, a arte já está em `art/combat/effects/`), #72
  (pendências da revisão dos PRs #67, #68 e #71), #70, #66 (segunda parte), #35 (zonas e props em inglês), e a HUD:
  #58 (Codex, telas com o kit), #60 (Claude, biblioteca do kit) e o resto da #56.
- **No PC com a Unreal:** a #73 (referência das passagens, do acampamento e da chegada) é do Claude local.
- **Decisões do Lucas em aberto:** #59 (aprovar o kit), #9 (morte permanente), #11 (Bar e Dormitório), #12 (pacote
  do celular), #78 (textos e efeitos de fase), o cartão de título da passagem (simples ou com mais presença) e as
  propostas do Claude em `docs/narrative/review.md` (nomes de recruta, descrições dos inimigos).
- **Em espera:** #40 (respiração dos heróis), para o Auto Sprite.
- **Formato da arte:** o Codex entrega em WebP, na resolução de uso, com os originais fora do repositório.
- **Decidido:** treinos da Pesquisa valem na luta; dificuldade crescente dentro de cada fase; vilões do John pela
  distribuição dele; quedas da Íris e da Véspera ajoelhadas; o acampamento é dos fundadores, sentados no chão; todas as
  cenas de passagem podem ser puladas; o acampamento funciona como o HUD da luta; 4 eventos de busca por mapa.
- **Só no Windows:** as fontes das poses do John estão em `SourceArt/CharacterGallery/JohnCombatPoses20261022` na
  pasta da Unreal (e na tag `codex-pr46-originals`); o metrô sai de `tools/unreal_export_metro.py`.
