# RehabAI

RehabAI is a Flutter-based physiotherapy and rehabilitation platform for
students/patients, physiotherapists, and administrators. It combines exercise
planning, camera-based pose tracking, progress monitoring, communication,
appointments, and equipment rental in one application.

## Main features

### Student application

- Email/password and Google authentication
- Assigned and self-selected rehabilitation exercises
- Rep counting and posture/joint-angle feedback
- Sets, repetitions, duration, pain scores, and session summaries
- Spoken exercise feedback through text-to-speech
- Progress history and daily treatment-plan tracking
- Live chat and on-demand teleconference invitations
- Appointment booking and equipment rental
- Notifications and profile-picture upload
- Persistent light and dark appearance modes
- Help centre with contact details and a physiotherapy dictionary

### Physiotherapist portal

- Assigned live chats with unread indicators
- Patient progress and exercise-performance analysis
- Appointment assessment, transfer, video call, and prescription recording
- Exercise prescription by days, sets, repetitions, or duration
- Equipment-rental approval and rejection
- Section-specific activity indicators and refresh controls

### Administrator portal

- Rental lookup by student matric number
- Collection/return processing and evidence photos
- Equipment inventory, stock, information, and image management

## Technology

- Flutter and Dart for Android, web, and desktop clients
- FastAPI and SQLAlchemy for the backend API
- Supabase PostgreSQL, Authentication, Realtime, and Storage
- Google ML Kit pose detection on the Flutter client
- MediaPipe/OpenCV utilities in the Python backend
- Gemini for AI-assisted chat
- Jitsi Meet links for teleconferencing

## Project structure

```text
rehab_ai/
|-- android/                 Android platform configuration
|-- assets/
|   |-- exercise_sources/   Posture, movement, and rep-count rules
|   `-- images/             Application and equipment images
|-- backend/
|   |-- ai/                 Python pose and chatbot helpers
|   |-- migrations/         Historical/additive database scripts
|   |-- main.py             FastAPI routes and application entry point
|   |-- models.py           SQLAlchemy database models
|   `-- requirements.txt    Python dependencies
|-- docs/                    Exercise-rule documentation and drafts
|-- lib/
|   |-- models/             Flutter data models
|   |-- screens/
|   |   |-- admin/          Administrator portal
|   |   |-- auth/           Landing, sign-in, sign-up, and profile setup
|   |   |-- physiotherapist/ Physiotherapist portal and patient analysis
|   |   |-- student/
|   |   |   |-- account/    Profile, settings, password, and terms
|   |   |   |-- appointments/
|   |   |   |-- chat/
|   |   |   |-- exercises/  Exercise library and AI tracking flows
|   |   |   `-- rentals/
|   |   `-- support/        Help centre, dictionary, and contact details
|   |-- services/           Pose, movement, voice, and call services
|   |-- theme/              Shared visual design system
|   |-- utils/              Shared formatters and state helpers
|   `-- widgets/            Reusable UI components
|-- test/                    Flutter unit and widget tests
|-- tools/                   Offline AI and diagnostic utilities
|-- web/                     Flutter Web host configuration
`-- .env.example            Environment variable template
```

Flutter-generated platform folders (`ios`, `linux`, `macos`, `windows`) remain
at the root because Flutter tooling expects that structure.

## Prerequisites

- Flutter SDK compatible with Dart `^3.11.5`
- Python 3.10-3.12 (recommended for MediaPipe compatibility)
- A Supabase project with the RehabAI database schema
- Google OAuth credentials for Google Sign-In
- A Gemini API key if AI chat responses are required

## Environment configuration

Copy `.env.example` to `.env` and replace every placeholder:

```powershell
Copy-Item .env.example .env
```

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-supabase-anon-key
DATABASE_URL=postgresql://user:password@host:5432/database
GOOGLE_WEB_CLIENT_ID=your-google-web-client-id.apps.googleusercontent.com
API_URL=http://10.0.2.2:8000
GEMINI_API_KEY=your-gemini-api-key
```

Do not commit `.env`. It contains credentials and is excluded by `.gitignore`.

### API URL by device

- Flutter Web: the app uses `http://127.0.0.1:8000`.
- Android emulator: use `API_URL=http://10.0.2.2:8000`.
- Physical phone: use the development computer's LAN address, for example
  `API_URL=http://192.168.1.20:8000`. The phone and computer must be on the
  same network, and the firewall must permit port 8000.

## Install and run the backend

From the repository root:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r backend\requirements.txt
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000 --reload
```

Useful API pages after startup:

- API documentation: `http://127.0.0.1:8000/docs`
- Alternative documentation: `http://127.0.0.1:8000/redoc`

The backend performs required additive column checks on startup. Older manual
migrations are documented in `backend/migrations/README.md`.

## Install and run Flutter

```powershell
flutter pub get
flutter analyze
flutter test
```

Run on an Android emulator:

```powershell
flutter run
```

Run the web portal on its fixed OAuth-compatible port:

```powershell
flutter run -d chrome --web-port=5000
```

Android Studio's included `main.dart` run configuration also uses port 5000.

## Google Sign-In configuration

For Flutter Web, add the exact origin below to the Google Cloud OAuth **Web
application** client:

```text
http://localhost:5000
```

Add it under **Authorized JavaScript origins** without a trailing slash or
path. Put that Web client ID in `GOOGLE_WEB_CLIENT_ID`.

For Android, also configure an Android OAuth client with the application
package name and the SHA-1 certificate fingerprint. Changing the web port does
not affect Android emulator or physical-phone authentication.

## Supabase notes

- Enable the authentication providers used by the application.
- Create a Storage bucket named `profile_picture` for student profile images.
- Apply suitable Storage and table Row Level Security policies for your
  environment.
- The `Student.profile_picture` field stores the uploaded object's path.
- Keep Realtime enabled for the chat and notification tables that need live
  updates.

## Exercise AI rules

Runtime exercise rules are stored in:

- `assets/exercise_sources/posture_rules.json`
- `assets/exercise_sources/rep_count_rules.json`
- `assets/exercise_sources/heuristics.json`

Human-readable drafts are kept under `docs/`. When changing a rule, keep the
JSON configuration and its corresponding documentation consistent, then run:

```powershell
flutter test test\posture_analyzer_test.dart
flutter test test\movement_analyzer_test.dart
```

## Development utilities

The `tools/` directory contains offline video review, dataset inspection, and
camera-pose diagnostics. See `tools/README.md`. Run these utilities from the
repository root so relative asset paths remain valid.

## Security and deployment

The current backend CORS configuration allows all origins for local
development. Before production deployment, restrict it to the deployed web
origin, store secrets in the hosting platform, use HTTPS, and review Supabase
RLS policies. Never expose the database password or Gemini key in a public
repository.
