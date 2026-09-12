# Device artwork (optional)

Drop per-model headphone images here as PNG or WEBP, then map them in
`DEVICE_ART` at the top of `panel.luau`:

    assets/wh-1000xm5.png   <- ["WH-1000XM5"]

Recommended size: ~360x276 (panel shows them at 180x138, `fit = "contain"`).
Transparent background looks best on both themes. If no file matches the
connected model, the panel falls back to a headphones glyph.
