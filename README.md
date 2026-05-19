# Runbook

A dog-sports Q tracker. Conversational entry, AKC agility / FastCAT /
scentwork rules engine, and a ribbon-OCR scanner for batch-importing
trial results.

## Local development

```sh
flutter pub get
dart run tool/build_dog_assets.dart   # YAML → JSON for bundled dog data
flutter run -d web-server             # iterate in browser
flutter build apk --debug             # for phone
```

## Layout

- `lib/feed/` – feed, cards, drill-in pages
- `lib/convo/` – conversational Q/dog entry
- `lib/rules/` – AKC rules engine and title definitions
- `lib/scan/` – ribbon OCR scanner (Android/iOS; web no-ops)
- `data/dogs/*.yaml` – source-of-truth Q records (one file per AKC ID)
- `assets/dogs/*.json` – generated bundle from the YAML above
