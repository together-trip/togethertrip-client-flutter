# togethertrip

A new Flutter project.

## Local run

Create a local config file first:

```bash
cp config/local.example.json config/local.json
```

Run the app with local `dart-define` values:

```bash
./scripts/run_app.sh
```

The script automatically selects the first iPhone listed by `flutter devices`
when no device option is provided.

Flutter run options can be passed through:

```bash
./scripts/run_app.sh -d chrome
./scripts/run_app.sh -d ios --debug
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
