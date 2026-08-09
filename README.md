# Do X

[![Netlify Status](https://api.netlify.com/api/v1/badges/bbdc9c84-6a3c-4f4c-ac12-d63ad0132147/deploy-status)](https://app.netlify.com/sites/do-x/deploys)

A cross-platform Flutter app that brings together personal and household
utilities. The release version is managed in `pubspec.yaml`.

## Features

- **Market news:** gold, silver, and cryptocurrency prices; JPY/VND exchange
  rates; price charts; and scheduled AI-generated gold market digests.
- **Chicken management:** batches, vaccination schedules, multiple sales per
  batch, fighting/meat chicken sales, shared expenses, yearly statistics, JSON
  data import, and Supabase synchronization.
- **MyLife:** sign in, capture or select photos and videos, trim videos, and add
  weather overlays.
- **Electricity:** sign in to Central Power Corporation's customer service,
  monitor consumption and usage history, and schedule monthly meter-reading
  reminders.
- **Lunar calendar and feng shui:** solar/lunar date conversion, Can Chi, lucky
  hours, solar terms, tide information, and a feng shui compass.
- **Local network:** manage the router/Wi-Fi connection, run speed tests, and
  scan for devices on the LAN.
- **Movies:** connect to multiple movie servers, browse, filter, search, stream,
  use a mini player, and synchronize watch history and favorites by account.
- Light and dark themes, Vietnamese and English localization, configurable tab
  visibility/order, and Android update checks through GitHub Releases.

The repository includes platform runners for **Android, iOS, macOS, and Web**.
CI publishes an Android APK, an unsigned iOS IPA, and a macOS DMG. The Web app
is deployed through Netlify.

## Tech stack

- Flutter `3.44.8` and Dart `>=3.10.0 <4.0.0`, pinned with FVM
- Provider and AutoRoute
- Firebase Core, Crashlytics, and Firebase APIs used by MyLife
- Supabase Auth, Postgres, RLS, RPC, Edge Functions, and Cron
- Dio, `video_player`, camera/image picker, and local notifications
- `json_serializable`, `build_runner`, Flutter Gen, and Flutter localization

## Prerequisites

- [FVM](https://fvm.app/documentation/getting-started/installation)
- JDK 17 for Android builds
- Xcode 26.6 for iOS and macOS builds
- CocoaPods for iOS and macOS
- `make` (optional; the underlying commands can also be run directly)
- Supabase CLI only when changing or deploying the backend
- FlutterFire CLI only when regenerating Firebase configuration

## Local setup

```bash
git clone <repository-url>
cd do_x
fvm install
fvm flutter pub get
```

Create `envs/dev/` (this directory is excluded from Git) with the following
structure:

```text
envs/dev/
├── dart-define.env
├── google-services.json
└── GoogleService-Info.plist
```

Example `envs/dev/dart-define.env`:

```dotenv
FLAVOR=dev
ML_API_KEY=
FIREBASE_API_KEY_IOS=
FIREBASE_API_KEY_ANDROID=
FIREBASE_API_KEY_WEB=
MARKET_API_URL=
MARKET_WS_URL=
SUPABASE_URL=
SUPABASE_KEY=
ML_API_URL=
ELECTRIC_API_URL=
```

The backends the app talks to are configured here, not in the source — see
`lib/constants/env.dart`. `MARKET_API_URL` / `MARKET_WS_URL` are the market data
REST and websocket hosts. Fixed addresses stay in the code that calls them: the
public APIs (Google, open-meteo, Cloudflare), the GitHub releases endpoint the
updater polls, and the companion site in `AuthLinks`, which the platform
manifests have to agree with anyway.

Never commit real values. Restore the Firebase files to their platform runners,
then start the app:

```bash
make env
fvm flutter run --dart-define-from-file envs/dev/dart-define.env
```

The `do_ai (dev)` VS Code launch configuration automatically runs the env
restore script and passes the dart-define file. For Web development, it also
adds `--disable-web-security` to the browser so the app can work with APIs that
do not fully support CORS.

### Firebase configuration

Environment-specific Firebase files are kept out of Git. To create or update
them with FlutterFire CLI:

```bash
fvm dart pub global activate flutterfire_cli
flutterfire configure
```

Place the resulting `google-services.json` and `GoogleService-Info.plist` files
in `envs/<environment>/`, then run
`scripts/restore-env-configs.sh <environment>`. The
`lib/firebase_options.dart` file contains non-secret FlutterFire configuration;
platform API keys are still supplied through `dart-define.env`.

## Code generation and localization

Generated files for JSON models, routes, assets, and localization are committed
to the repository. After changing annotations, routes, assets, or ARB files,
run:

```bash
make gen
```

Individual commands:

```bash
make l10n          # Generate localization only
make gen-app-icon  # Generate launcher icons
make clean         # Clean, fetch packages, and regenerate code
```

## Quality checks

```bash
fvm flutter analyze
fvm flutter test
```

The current test suite covers lunar-calendar and chicken-date logic, chicken
data import, merged electricity data, and key widgets.

## Building

The `Makefile` targets use `envs/dev/` by default:

```bash
make build-apk
make build-ipa
make build-macos
```

Before building for iOS, apply the repository-maintained patches for
`easy_video_editor`:

```bash
fvm flutter pub get
bash scripts/patch-easy-video-editor.sh
```

Build the Web app locally:

```bash
fvm flutter build web --release \
  --dart-define-from-file envs/dev/dart-define.env
```

`scripts/netlify_build.sh` reads the Flutter version from `pubspec.yaml`,
creates the dart-define file from Netlify environment variables, and builds the
app into `build/web`.

## Supabase backend

The app currently connects to Supabase project `fyyrgwohjgvsmwqgxiga`.
Chicken-management and movie routes require email/password authentication, and
user data is protected with `auth.uid()`-based RLS policies.

The repository follows an **imperative migration** workflow under
`supabase/migrations/`. Existing migrations cover:

- chicken-management schemas and RPC functions;
- the `gold_news` table and a Cron schedule that generates three digests daily;
- the `movie_library` table for watch history and favorites.

Link the project and apply existing migrations with:

```bash
supabase login
supabase link --project-ref fyyrgwohjgvsmwqgxiga
supabase db push
```

The gold-news Edge Function requires a Supabase secret. Do not put this value in
`dart-define.env`:

```bash
supabase secrets set GEMINI_API_KEY=<your-key>
# Optional: supabase secrets set GEMINI_MODEL=<model-name>
supabase functions deploy summarize-gold-news
```

See
[`supabase/functions/summarize-gold-news/README.md`](supabase/functions/summarize-gold-news/README.md)
for RSS sources, the Cron schedule, and manual testing instructions.

> Note: the app also reads the existing remote `fx_rates` table, but its schema
> and refresh job are not currently included in this repository's migrations.
> Applying only the checked-in migrations is therefore not enough to reproduce
> the complete production backend in a new project.

## CI/CD

The `.github/workflows/flutter_build.yml` workflow runs on pushes to `main` or
through a manual dispatch using the `dev`, `staging`, or `prod` environment. It:

1. generates environment and Firebase files from GitHub Environment Secrets;
2. builds an Android arm64 APK, an unsigned iOS IPA, and a macOS DMG;
3. uploads artifacts to the GitHub Release tagged from `pubspec.yaml`;
4. updates the release notes from commit history.

Required CI secrets include `DART_DEFINE_BASE64`, `GOOGLE_SERVICES_BASE64`,
`GOOGLE_SERVICE_INFO_BASE64`, and the Android signing secrets
(`PLAY_STORE_UPLOAD_KEY`, `KEYSTORE_KEY_ALIAS`, `KEYSTORE_KEY_PASSWORD`, and
`KEYSTORE_STORE_PASSWORD`).

## Repository structure

```text
lib/
├── screen/        # Feature UI
├── view_model/    # State and presentation logic
├── services/      # APIs, Supabase, storage, notifications, and devices
├── repository/    # Data access and HTTP client
├── model/         # Domain and API models
├── router/        # AutoRoute configuration and generated routes
├── widgets/       # Shared components
├── l10n/          # ARB and generated localization files
└── utils/         # Algorithms and utilities

supabase/
├── migrations/    # Postgres schema history
└── functions/     # Supabase Edge Functions

scripts/           # Env restore, CI web build, iOS patches, and helper tools
test/              # Unit and widget tests
tool/              # Import-data verification and conversion scripts
import_data/        # Historical chicken data and import documentation
```

## Chicken data import

`import_data/chicken_import_2023_2026.json` contains digitized historical data.
See [`import_data/README.md`](import_data/README.md) for its format, import steps,
and reconciliation notes.

## Contributing

Community contributions are welcome. Bug reports, feature proposals,
documentation improvements, tests, and code changes all help improve the
project.

Before opening a pull request:

1. open an issue first for substantial changes so the approach can be agreed
   upon;
2. fork the repository and create a focused branch;
3. follow the existing project structure and code style;
4. regenerate and commit affected generated files when changing routes,
   models, assets, or localization;
5. run `fvm flutter analyze` and `fvm flutter test`;
6. describe the problem, solution, platforms tested, and any setup or migration
   steps in the pull request.

Keep pull requests small and focused when possible. Never include credentials,
API keys, private user data, signing files, or environment-specific Firebase
configuration in commits, issues, logs, or screenshots.

## Disclaimer

Do X is an independent, community-maintained project provided on an “as is” and
“as available” basis, without warranties of any kind. It is not affiliated
with, endorsed by, or sponsored by Supabase, Firebase, MyLife, Central Power
Corporation, Gemini, movie providers, market-data providers, or any other
third-party service used by the app.

- Market prices, exchange rates, charts, news summaries, electricity data, and
  other displayed information may be delayed, incomplete, or inaccurate. They
  are provided for informational purposes only and are not financial,
  investment, legal, or professional advice.
- Third-party APIs, websites, and services may change, become unavailable, or
  impose their own terms, fees, rate limits, and privacy practices. Users are
  responsible for reviewing and complying with those terms.
- The project does not host or supply movie content. Users must configure their
  own sources and are solely responsible for ensuring they have the right to
  access and view any content.
- Network discovery and router-management features must only be used on
  networks and devices the user owns or is explicitly authorized to manage.
- Users are responsible for protecting their credentials, API keys, imported
  data, and backups. Review the code and configuration before using the app
  with sensitive or production data.

By using or contributing to the project, you accept responsibility for your
use of the software and any resulting data loss, service disruption, account
action, legal obligation, or other consequence to the extent permitted by
applicable law.

## License

This project is available under the [MIT License](LICENSE).
