# CIVICSETU Auto Report Proxy

This backend accepts a complaint image from the Flutter app, sends it to OpenAI vision, and returns a structured complaint draft.

Recommended model:

- `gpt-5-mini`

## Returns

- `category`
- `title`
- `description`
- `urgency`
- `confidence`
- `detectedObjects`
- `summary`
- `reasoning`
- `needsManualReview`
- `autoSubmitRecommended`
- `reviewWindowSeconds`

## Setup

```bash
cp .env.example .env
npm install
npm start
```

## Flutter run example

```bash
flutter run --dart-define=CIVICSETU_AUTOREPORT_ENDPOINT=http://10.0.2.2:8787/v1/analyze-complaint-image
```

If you set `AUTOREPORT_TOKEN` in `.env`, also pass:

```bash
flutter run --dart-define=CIVICSETU_AUTOREPORT_ENDPOINT=http://10.0.2.2:8787/v1/analyze-complaint-image --dart-define=CIVICSETU_AUTOREPORT_TOKEN=<same-token>
```

For a physical Android phone, replace `10.0.2.2` with your machine's LAN IP.
