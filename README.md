# Startupper

A platform where founders, investors, and early users build together.

## Overview

Startupper is a Flutter app that connects three types of users in the startup ecosystem:
- **Founders** - Build and grow startups, find investors and talent
- **Investors** - Discover and fund promising startups  
- **End-users** - Join startups, freelance, collaborate or test products

## Project Structure

```
startupper/
├── lib/
│   ├── main.dart          # App shell, auth, onboarding, routing
│   ├── app_config.dart    # App-wide config flags (e.g., validation bypass)
│   ├── auth/
│   │   └── auth_screen.dart
│   ├── onboarding/
│   │   ├── reason_screen.dart
│   │   ├── common_onboarding_screen.dart
│   │   ├── founder_onboarding_screen.dart
│   │   ├── investor_onboarding_screen.dart
│   │   └── end_user_onboarding_screen.dart
│   ├── theme/
│   │   ├── app_theme.dart     # Centralized theming, buttons, chips, cards
│   │   └── spacing.dart       # Shared spacing tokens
│   ├── services/
│   │   └── supabase_service.dart # Profile/avatar + role detail upserts
│   └── feed/
│       ├── feed_screen.dart    # Feed UI, cards, refresh/load-more
│       ├── feed_models.dart    # Feed models and enums
│       └── feed_repository.dart # Supabase data layer (fetches feed_items)
├── ios/                   # iOS platform files
├── macos/                 # macOS platform files
├── supabase/
│   └── schema.sql         # DB tables, RLS, storage policies
├── pubspec.yaml           # Project dependencies and configuration
└── README.md              # This file
```

## Running the App

### Prerequisites
- Flutter 3.0+ installed
- For iOS: Xcode and iOS device or simulator
- For macOS: Xcode command line tools

### Installation

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd Startupper
   ```

2. (macOS once per machine) Enable desktop support:
   ```bash
   flutter config --enable-macos-desktop
   ```

3. (Android once per machine) Enable Android support:
   ```bash
   flutter config --enable-android
   ```
   Ensure Android SDK/Platform Tools are installed and an emulator/AVD is set up via Android Studio or `avdmanager`.

4. Get dependencies:
   ```bash
   flutter pub get
   ```

5. Run the app:
   ```bash
   # On iOS device
   flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon-key> -d <device-id>
   
   # On macOS
   flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_ANON_KEY=<anon-key> -d macos
   ```
Optional extras:
```bash
--dart-define=SUPABASE_EMAIL_REDIRECT=<redirect-url>  # deep link or HTTPS for email verification
--dart-define=BYPASS_VALIDATION=true                  # testing bypass
```

### Configuring dart-defines via environment variables

1. Export your values in the shell (e.g., zsh/bash):
   ```bash
   export SUPABASE_URL="https://abc.supabase.co"
   export SUPABASE_ANON_KEY="your-anon-key"
   export SUPABASE_EMAIL_REDIRECT="startupper://auth-callback" # optional
   export BYPASS_VALIDATION="true"                             # optional
   ```
2. Pass them into `flutter run`:
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL="$SUPABASE_URL" \
     --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
     --dart-define=SUPABASE_EMAIL_REDIRECT="$SUPABASE_EMAIL_REDIRECT" \
     --dart-define=BYPASS_VALIDATION="$BYPASS_VALIDATION"
   ```

## Current Implementation

### 🎨 Complete Onboarding Flow

**7 screens with polished UI:**

1. **Auth Screen** (`/auth`)
   - Email and password fields
   - Login and signup functionality
   - Clean, centered card design

2. **Role Selection** (`/onboarding/reason`)
   - "Why are you joining?" question
   - 3 interactive role cards (Founder, Investor, End-user)
   - Polished cards with elevation, gradients, and glow effects
   - Continue button disabled until selection
   - No back button (came from login)

3. **Common Onboarding** (`/onboarding/common`)
   - Profile picture upload (camera or gallery)
   - Full name, headline, and location fields
   - Freelancing availability toggle
   - Back chevron navigation
   - Routes to role-specific screens

4. **Founder Onboarding** (`/onboarding/founder`)
   - Startup name and one-liner pitch (300 char limit)
   - Stage selection dropdown
   - Multi-select chips: what you're looking for (no checkmarks)
   - Optional expandable "Product Details" section:
     - Yes/No question-based toggle
     - Website, demo video, App Store ID, Play Store ID fields
   - Back and Finish navigation

5. **Investor Onboarding** (`/onboarding/investor`)
   - Investor type dropdown
   - Ticket size field
   - Multi-select stage chips (no checkmarks)
   - Back and Finish navigation

6. **End-user Onboarding** (`/onboarding/end_user`)
   - Main role and experience level dropdowns
   - Multi-select interest checkboxes
   - Back and Finish navigation

7. **Feed Screen** (`/feed`, `lib/feed/feed_screen.dart`)
   - Main feed list with card variants:
     - Update cards (metrics, ask chips, applause/comment/interest actions)
     - Startup highlights (tags, metrics, asks, CTA)
     - Missions/tasks (reward badge, tags, claim/save CTAs)
     - Investor spotlights (thesis, tags, intro/share CTAs)
   - Filter chips row and role-accented styling
   - Search bar + tag/type filters (role-aware “Personalized” applies your role as a tag)
   - Compose dialog to post feed items (types, tags, asks, reward, featured) with preview + confirmation
   - Pull-to-refresh and auto load-more near scroll end
   - Fetches from Supabase `feed_items` (no mock fallback)
   - Post action in AppBar (hidden when signed out); role auto-tagging on posts
   - Profile entry in AppBar to view your profile

### ✨ Key Features

**Navigation & UX:**
- ✅ Named routes with proper navigation flow
- ✅ Back chevron buttons in AppBars
- ✅ Smart navigation (pushNamed vs pushReplacementNamed)
- ✅ Role-based routing to appropriate onboarding screens

**UI/UX Polish:**
- ✅ Material 3 design system
- ✅ Polished role selection cards:
  - Subtle elevation (2-4dp shadows)
  - Gradient backgrounds on selection
  - Glowing borders with smooth animations
  - AnimatedContainer transitions (200ms)
- ✅ Consistent FilterChip styling (no checkmarks)
- ✅ Color-based selection indicators
- ✅ Smooth expand/collapse animations
- ✅ Feed layouts with featured horizontal strip and responsive card actions
- ✅ Logout button on feed (Supabase sign out)

**Form Features:**
- ✅ Profile picture upload with image picker
  - Choose from gallery or take photo
  - Automatic resize (1024x1024) and compression
  - Uploaded to Supabase Storage (`avatars` bucket) with public URLs
  - Displayed in feed cards via `NetworkImage`
- ✅ Character limits on text fields (300 chars for pitch)
- ✅ Multi-line text inputs where appropriate
- ✅ Proper keyboard types (URL, email, number)
- ✅ Required field indicators (*)
- ✅ Inline validation on auth/onboarding forms; navigation gated on validity
- ✅ Supabase auth wired (sign up/login)
- ✅ Profile + role detail upserts to Supabase; optional avatar upload to Storage
  - Common onboarding writes to `profiles` (+ avatar to `avatars` bucket if provided)
  - Founder/Investor/End-user onboarding writes to respective tables
- ✅ Feed fetching from Supabase `feed_items` with avatars
- ✅ Feed search + tag/type filtering with role-aware personalization (reads)
- ✅ Feed posting with preview/confirmation, role auto-tagging, and sign-out guard
- ✅ Profile screen with edit mode, role-specific fields, avatar updates, and role switching (with confirmation)

**Code Quality:**
- ✅ Null-safe Dart
- ✅ Stateless/Stateful widgets appropriately used
- ✅ Clean widget separation (ProductDetailsSection)
- ✅ Proper controller disposal
- ✅ TODO comments for Supabase integration
- ✅ No linting errors
- ✅ Testing bypass flag for validation: `--dart-define=BYPASS_VALIDATION=true`

### 📦 Dependencies

```yaml
dependencies:
  flutter: sdk
  cupertino_icons: ^1.0.2
  image_picker: ^1.0.4      # Profile picture uploads
  supabase_flutter: ^2.5.5  # Supabase auth, database, storage
```

## Backend Schema (Supabase)

- See `supabase/schema.sql` for tables, indexes, and RLS policies (profiles, role details, feed_items).
- Create a project in Supabase, copy `SUPABASE_URL` and `SUPABASE_ANON_KEY`, apply `supabase/schema.sql` via SQL editor or `supabase db push`, then run the app with the dart-defines above.
- Intro requests: apply `supabase/migrations/2024-01-01_add_contact_requests.sql` (creates `contact_requests` with RLS allowing requester/target reads and requester inserts).

### Supabase Setup Checklist

1. **Apply database schema:**
   - Run `supabase/schema.sql` in SQL Editor (tables, indexes, RLS policies, storage policies)
   - Reset API cache (Settings → API → Reset cache) after creating tables/policies

2. **Create Storage bucket for avatars:**
   - Go to Storage → New bucket → Name: `avatars`
   - **⚠️ IMPORTANT: Enable "Public bucket"** toggle (required for public URL access)
   - The storage policies in `schema.sql` handle authenticated upload/update/delete
   - Avatar files are stored at `{user_id}.{ext}` (e.g., `abc123-def456.png`)

3. **Configure Auth redirect URL:**
   - Use a deep link (e.g., `startupper://auth-callback`) or HTTPS URL you control
   - Add it to Authentication → URL Configuration → Site URL and Redirect URLs

4. **Run the app with dart-defines:**
   ```bash
  flutter run \
     --dart-define=SUPABASE_URL=<your-project-url> \
     --dart-define=SUPABASE_ANON_KEY=<your-anon-key> \
     -d <device>
   ```
   Optional:
   - `--dart-define=SUPABASE_EMAIL_REDIRECT=<redirect-url>` for email verification
   - `--dart-define=BYPASS_VALIDATION=true` for testing

## Architecture

**Navigation Structure:**
```
AuthScreen
    ↓ (pushReplacementNamed)
ReasonScreen
    ↓ (pushNamed)
CommonOnboardingScreen
    ↓ (pushNamed, role-based)
[FounderOnboarding | InvestorOnboarding | EndUserOnboarding]
    ↓ (pushReplacementNamed)
FeedScreen
```

**State & Data:**
- Local state with StatefulWidget and setState()
- TextEditingController for form inputs
- Route arguments for passing selected role
- Supabase persistence via `services/supabase_service.dart`
  - Auth screen ensures a `profiles` row on signup/login
  - Common onboarding: upserts profile and uploads avatar to `avatars` bucket (public URL stored in `profiles.avatar_url`)
  - Role onboarding: upserts to `founder_details`, `investor_details`, or `enduser_details`
- Feed data fetched from Supabase `feed_items` via `feed_repository.dart` (includes author avatar URLs from joined `profiles` table)

## Next Steps

### Immediate Priorities
- [x] Add form validation (required fields, email format)
- [x] Add loading states and error handling
- [x] Integrate Supabase authentication (sessions, redirects) end-to-end
- [x] Set up Supabase Storage for profile pictures (bucket `avatars`, public URLs working)
- [x] Save user profiles to Supabase database (profile upsert + avatar upload working)
- [x] Move feed data to a service layer and wire to backend when ready
- [x] Add skeleton states for feed loading (no shimmer)
- [x] Wire feed search/filter to Supabase reads
- [x] Wire feed inserts to Supabase (compose dialog with preview/confirmation)
- [x] Session-aware routing to skip onboarding when profile/role exists

### Feature Development
- [ ] Build out the feed screen with real content (Supabase or API)
- [ ] Implement startup discovery and browsing
- [ ] Add user profile viewing and editing
- [ ] Create founder-investor matching
- [ ] Add messaging/communication features
- [ ] Implement search and filtering

### Polish & Optimization
- [ ] Add app icons and splash screens
- [x] Implement proper error messages
- [x] Add onboarding progress indicator
- [ ] Optimize images and performance
- [ ] Add analytics and monitoring

### Recent Improvements
- Startup guard: shows a config/error screen if `SUPABASE_URL`/`SUPABASE_ANON_KEY` are missing or Supabase init fails.
- Auth state routing: listens to Supabase auth changes and routes to feed or onboarding based on profile role.
- Loading UX: shared loading overlay + snackbars with retry across auth/onboarding; feed pagination now tracks `hasMore` to avoid infinite load-more.
- Feed discovery: search bar + tag/type filters with role-aware “Personalized” tag, all executed server-side; filters/search persisted with reset action and role defaults.
- Investor intros: request-intro action on investor cards posts to Supabase `contact_requests` (with RLS), including optional message and feed-item context.
- Intro inbox: two-tab view for incoming/sent contact requests with accept/decline actions and status updates (requires the contact_requests update policy migration).
- Investor cards disable repeat requests after sending (“Intro sent” state).
- Inbox polish: tap “Via feed” to preview the related feed item; accept/decline shows undo.
- Feed item deep link: “Via feed” now navigates to a dedicated feed-item screen route that renders the full card.
- Duplicate intro guard: investor cards are disabled when you’ve already sent (or have a pending/accepted) intro to that member.
- Author profile sheet: tap an author in the feed to open a bottom sheet with their info and request-intro action (respects duplicate-intro guard).
- Inbox authors open a profile sheet (with intro action); “Via feed” still links to the feed item for context.
- Profile sheets now show role chips and headline/affiliation for more context.
- Role-specific context: profile sheets fetch investor type/ticket/stages, founder stage/startup/looking-for, and end-user role/experience/interests.
- Role details are cached per user/role for faster repeat loads.
- Feed list taps open the detailed feed-item route; investor cards show an “Intro sent” badge when applicable.
- Feed-item detail includes profile opener and intro action (for investor items); investor cards link to sent intros.
- Intro inbox has status filters (pending/accepted/declined) and richer author sheets.
- Intro requests now support participant-visible notes that can be added/edited from the inbox.
- Feed-item detail has a copy-link action (deep link: startupper://feed/{id}).

## Platform Support

- ✅ iOS (tested on iPhone)
- ✅ macOS (tested on Mac desktop)
- ⏳ Android (enable with `flutter config --enable-android`; needs SDK/AVD setup)
- ⏳ Web (project scaffold present in `web/`, not yet tested or supported; expect fixes)

## Testing

- Smoke tests: `flutter test` (widget harness checks startup config screen when Supabase is not ready)

## Development Notes

- Auth/onboarding code is split into feature files under `lib/auth` and `lib/onboarding`; app shell routes live in `main.dart`
- No external state management (Provider, Riverpod, etc.) yet
- Inline form validation implemented; can be bypassed for testing with `--dart-define=BYPASS_VALIDATION=true`
- Supabase integration working for auth, profiles, role details, feed items, and avatar storage
- Profile images uploaded to Supabase Storage (`avatars` bucket) with public URLs
- Feed repository includes debug logging (`dart:developer`) for troubleshooting

## Learn More

- [Flutter Documentation](https://docs.flutter.dev/)
- [Material 3 Design](https://m3.material.io/)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Image Picker Package](https://pub.dev/packages/image_picker)

## License

TBD

---

**Built with Flutter 🚀**
