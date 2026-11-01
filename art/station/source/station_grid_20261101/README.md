# After Humans — Station grid art / issue 275

Originals for the six illustrated buried blocks, three state borders, room chooser template and four tintable glyphs. This bundle is archived on an independent Git tag; **do not merge the tag into main**. Production integration belongs to Claude 1, PR #284.

## Approved conversion inputs

Use only the 14 PNG named in `assets.json`, under `illustrations/`, `frames/` and `icons/`. The `qa/raw/` PNG are generation originals and superseded iterations, preserved for traceability; do not convert the old wagon or the halo-bearing icon sheet directly. The normalized wagon uses `overturned_wagon_r2.png`; the masks use `icons_sheet_r2.png` and alpha-mask cleanup.

- Room illustrations: source 1200×640, runtime 600×320, matching a 6 m × 3.2 m bay.
- Borders: source 1200×640 / runtime 600×320. Three states have 96 / 48 px nine-slice margins. Center fully transparent.
- Room chooser: same canvas, fixed aspect with blank header; do not stretch its header. Compose a separate kit plaque for a different aspect.
- Glyphs: source 192×192 / runtime 96×96, white tintable mask; inspect 22 and 32 px review samples.
- Source and runtime transparent RGB are zeroed. The normalized PNG are authoritative; runtime output is WebP lossless, half resolution.

## Convert for integration (Pillow only)

Extract this bundle outside the game checkout. From this folder:

```bash
python -m pip install pillow
python convert_webp.py --out /tmp/station_275_prepared
```

On Windows use a new folder under your temporary art workspace as `--out`. The converter verifies all source hashes/canvases before creating the output, refuses an existing output folder and never modifies a game project. It emits the 14 WebP plus the contract. These WebP were independently reproduced byte for byte against the art used in review.

Suggested integration paths are in `assets.json` and in the design page. They are new files only; do not rename existing game ids/files. Keep text, counts, rewards, names, focus and actions as runtime UI. Do not extract them from the review sheets.

## Review reproduction

The repo used for proof is main `7345f7a1` (Godot 4.7.2). `qa/capture_game.gd` is an external proof harness, not a game script to install. It creates an isolated campaign/save, sets the L2 landing open and 2:7 free, and sets 1:2 progress 1/2. It renders an orthographic cutaway before and after adding the external cards. Actual game rules supply adjacency, reward, ETA, costs and disabled state. No production file is patched.

```bash
Godot --path /path/to/after-humans-godot --rendering-method gl_compatibility \
  --audio-driver Dummy --resolution 1920x1080 --script /path/to/this/qa/capture_game.gd \
  -- --out=/tmp/station_275_proof --assets=/tmp/station_275_prepared
python qa/make_boards.py --repo /path/to/after-humans-godot \
  --captures /tmp/station_275_proof --prototypes /tmp/station_275_prepared --out /tmp/station_275_review
```

Set isolated `XDG_DATA_HOME`, `XDG_CONFIG_HOME` and `XDG_CACHE_HOME` on Linux. The captures use CPU/Mesa llvmpipe Compatibility, with no physical GPU. They approve the art/layout, not Forward+ lighting/GI; final integration remains to be checked on Lucas's PC.

`qa/prepare.py --out /tmp/station_275_regenerated` rebuilds normalized inputs from raw generations (requires Pillow, NumPy and SciPy). It is a traceability recipe, not the recommended game import path. Technical cleanup includes transparent-edge RGB, low-alpha haze, tiny disconnected pixels and white glyph masks. Illustration cropping is uniform, never squashed; border normalization preserves corners by nine-slice. No borrowed game image is part of this bundle; the material references are After Humans' own workshop and steel kit.
