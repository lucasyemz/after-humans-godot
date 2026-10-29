# Female recruits: normal expedition costumes — issue #247

Three costume comparison PNG sheets, not production sprites. In each pair male is left, female right. Founders Bento/Nick/Iris/Vespera are not changed. Six female expedition proposals preserve the identities from lobby PR #244 r4 and canonical equipment/coverage, pending Lucas visual approval before pose/portrait production.

No alpha sprites, production anchors or automatic wardrobe switching are implemented. Do not convert sheets directly with sync_combat_art.py. Main only receives WebP review images and docs; PNGs are archived separately in the PR's independent source tag/Release.

build_review.py records local Pillow conversion to review WebP and genuine 40%/grayscale sheets. Its absolute paths describe the authoring environment, not portable runtime dependencies. assets.json records PNG/WebP dimensions, hashes and reference origins. Reference images are not duplicated here: game canonical dog/cat/frog/owl in main, approved raccoon/armadillo redesign in codex-pr229-originals, lobby identities in codex-pr244-originals-r4.

Lobby comfortable clothes; character inspection/departure/exploration/combat/camp/arrival use normal expedition costume. Switch to comfortable only after arrival. Sex/save integration and final poses are outside this concept delivery.

Publication: PR #248, independent source tag codex-pr248-originals, folder art/combat/source/recruit_female_expedition_20261029/. Three PNG concept sheets only; reference inputs remain in the other origins documented in assets.json.
