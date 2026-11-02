# After Humans — node-rescue / issue 295

One white tintable raised-hand glyph, matching the station kit's existing route node icons. Source PNG 128×128; lossless WebP runtime 64×64; center anchors 64/64 and 32/32. No nine-slice. Approved usage sizes: 22/32 px, route 25.76 px and map beacon 30 px. Existing game tints and frames supply all states. Unknown route nodes must retain `?` under existing discovery rules.

The authoritative input is `node-rescue.png`. `node-rescue.webp` is its prepared half-resolution output. `assets.json` records dimensions, safe area, destination and SHA256. For integration, stage outside the Godot checkout:

```sh
python convert_webp.py --out /tmp/rescue_295_prepared
```

Requires Pillow; output directory must not exist. The script validates hashes and reproduces the WebP byte for byte. Integration/manifest and game behavior belong to Claude 2 (#188); do not install the proof harness as game code.

The independent source tag must NOT be merged into main. The PR contains only review sheets and documentation. `qa/raw` contains two generated source iterations; they are not production textures. Alpha threshold, largest component and uniform downsampling in `qa/prepare.py` remove generated haze/stray pixels, create the white tintable mask and center it on the required canvas; requires Pillow, NumPy and SciPy.

`qa/capture.gd` runs against main e2f0b58a, isolated save, with `--out=<folder> --icon=<absolute runtime WebP>`. Godot 4.7.2 Compatibility/CPU, 1920×1080; use isolated XDG data/config/cache folders. It captures the actual rescue route node and mission-map beacon before/after replacing only their texture. `qa/board.py` composes the sheets from these captures. No borrowed game image is included. Physical GPU/Forward+ proof remains with integration.
