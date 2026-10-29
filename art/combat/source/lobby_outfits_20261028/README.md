# Lobby outfits — issue #243 / PR #244, revision 3

Initial four founder/six recruit outfits approved by Lucas after the owl arms correction (r2). Six female recruit concepts newly proposed, pending visual approval before their production poses. No final sprites, no usable foot anchors, no automatic outfit switching implemented.

Six concept PNG sheets: founders, recruits, raccoon_armadillo (byte-identical to approved r2), plus three male/female comparison sheets. Male comparison drawings do not replace canonical art. All remain outside main in independent source tag codex-pr244-originals-r3. Prior tags are preserved.

Do NOT convert these sheets directly with sync_combat_art.py. They are costume illustrations with backgrounds, not alpha sprites. Pose production is a separate package after the required visual approval.

Local conversion recipes: build_review.py for initial sheets then build_variants.py for new comparison sheets, using Pillow. Absolute paths record the authoring environment, not portable game dependencies. Final assets.json/verification.json record approval and hashes.

Lobby comfortable clothes; character inspection, departure and arrival keep original expedition clothes; switch after arrival. Combat/exploration/camp keep original. The palette selector remains cancelled.
