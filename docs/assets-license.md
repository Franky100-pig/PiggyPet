# Asset provenance

Pig images used by PiggyPet are sourced from:

- <https://github.com/BadFish-HSrui/PigHub-DB> (`data/` directory)

The upstream repository does **not** declare a license. These images are included
in this repository only as a small, processed, local-use subset. Do not treat
them as MIT-licensed; if you want to publish or redistribute this app widely,
replace them with your own artwork or obtain permission from the rights holders.

`scripts/process_assets.py` can regenerate `Resources/sprites/` from a local
clone of the upstream repository. The raw clone is gitignored and never committed.
