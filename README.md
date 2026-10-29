# Sony Headphones

[Noctalia](https://noctalia.dev) v5+ plugin for Sony Bluetooth headphones:
battery, ANC / Ambient Sound control, and per-model artwork over the
reverse-engineered **MDR V2** protocol, with safe BlueZ-only battery fallback
for **MDR V1** models (WH-1000XM4/XM3/XM2).

The plugin lives in [`sony_headphones/`](sony_headphones/) and is laid out for
a drop-in [community-plugins](https://github.com/noctalia-dev/community-plugins)
submission (`id = "estvoid/sony_headphones"`, directory `sony_headphones/`).

- **Plugin docs:** [`sony_headphones/README.md`](sony_headphones/README.md)
- **Backend CLI:** [`sony_headphones/scripts/sony_ctl.py`](sony_headphones/scripts/sony_ctl.py)
- **Tests:** `python3 -m unittest discover -s sony_headphones/tests`
- **Manifest lint:** `noctalia plugins lint sony_headphones`

## Development

Add the checkout root as a `path` source and enable the plugin:

```sh
noctalia msg plugins source add sony-dev path ~/Projects/Sony-headphones
noctalia msg plugins enable estvoid/sony_headphones
```

`.luau` edits hot-reload; manifest changes are picked up on the next config
reload.

## License

MIT — see [LICENSE](LICENSE).
