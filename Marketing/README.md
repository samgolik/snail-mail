# Snail Mail marketing assets

## App Store search results

`AppStoreSearch/` contains three 1920 × 1280, 3:2, opaque RGB PNG variants
for App Store Connect's Search Results creative placement and Product Page
Optimization testing. Each asset combines campaign illustration with real app UI.

Regenerate them with:

```sh
python3 Marketing/generate_search_assets.py
```

The first recommended treatment is `01-messages-take-time.png`. Test the other
two rather than changing all three simultaneously so conversion results remain
interpretable.

The generated illustration layers are retained in `SourceArt/`. The interface
shown in every final asset comes from the approved screenshots in
`AppStoreScreenshots/`.
