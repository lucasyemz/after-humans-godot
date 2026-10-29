# Lobby outfits — issue #243 / PR #244, revision 4

Lucas approved the ten initial outfits after the owl arm correction. The six female recruit proposals are still pending visual approval before their production poses.

Revision 4 responds to Lucas requesting DISTINCT female clothes, rather than adjusted copies of male garments. Three new comparison sheets replace r3 comparisons: dog bib overalls / cat wrap blouse; frog long tunic + shorts / owl collarless blouse without vest; raccoon soft vest over tee / armadillo collarless blouse + cropped trousers. All are comfortable station clothes with no expedition gear. Male comparison figures are redraws only, not canonical replacements.

Six PNG concept sheets total. Initial founders/recruits/raccoon_armadillo concepts remain identical to approved r2. Previous tags remain untouched; current sources are codex-pr244-originals-r4. No PNG enters main.

Not production sprites: no alpha/foot anchors, no automatic switching, no sex/save system implemented. Do NOT convert sheets directly with sync_combat_art.py. Female production poses remain blocked until Lucas approves their outfits.

build_review.py and build_variants.py record local review-sheet conversion with Pillow, not portable game dependencies. Final assets.json and verification.json record dimensions/hashes/approval.

Lobby comfortable clothing only; character inspection, departure and arrival keep original expedition clothing, switching after arrival. Combat/exploration/camp retain original outfits. No palette selector.
