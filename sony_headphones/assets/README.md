# Device artwork

## Provenance & license

- **Source:** original artwork created for this plugin. No third-party product
  photography or vendor renders are bundled, and no Sony or other trademarked
  logo is reproduced.
- **Author:** the plugin author (`estvoid`).
- **License:** MIT, the same license declared in `plugin.toml`.

These images are intentionally generic placeholders; the author plans to
replace them with their own hand-drawn sketches. Any replacement keeps the
same MIT licensing and stays free of third-party branding.

The images are **stylised, flat illustrations** of over-ear and in-ear
headphones. Each `.webp` is rasterised from the matching `.svg` source next to
it. Regenerate or tweak the set with:

```sh
python3 tools/generate_art.py           # writes the .svg sources
for f in assets/*.svg; do
  rsvg-convert -o /tmp/art.png "$f"
  magick /tmp/art.png -quality 92 "${f%.svg}.webp"
done
```

Files:

- `over_ear_{black,white,silver,lavender}.webp` — over-ear models
- `in_ear_{black,white}.webp` — true-wireless models

The per-model mapping lives in `DEVICE_ART` in `panel.luau`; the panel header
button cycles the variants. To use your own image for a model, drop a PNG/WEBP
here and point that model's entry at it.
