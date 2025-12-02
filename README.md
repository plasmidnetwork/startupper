# Startupper

A platform where founders, investors, and early users build together.

## Overview

Startupper is a Flutter app that connects three types of users in the startup ecosystem:
- **Founders** - Build and grow startups, find investors and talent
- **Investors** - Discover and fund promising startups  
- **End-users** - Join startups, freelance, or test products

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
│   └── feed/
│       ├── feed_screen.dart    # Feed UI, cards, refresh/load-more
│       ├── feed_models.dart    # Feed models and enums
│       └── feed_repository.dart # Mocked data/service layer
├── ios/                   # iOS platform files
├── macos/                 # macOS platform files
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
   cd /path/to/Startupper
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
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
   - Hero featured strip with horizontal cards
   - Main feed list with card variants:
     - Update cards (metrics, ask chips, applause/comment/interest actions)
     - Startup highlights (tags, metrics, asks, CTA)
     - Missions/tasks (reward badge, tags, claim/save CTAs)
     - Investor spotlights (thesis, tags, intro/share CTAs)
   - Filter chips row and role-accented styling
   - Pull-to-refresh and auto load-more near scroll end
   - Feed repository now fetches from Supabase `feed_items` (no mock fallback)
   - Debug-only “Add sample item” action in feed AppBar to seed `feed_items`

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
  - Circular avatar with border
- ✅ Character limits on text fields (300 chars for pitch)
- ✅ Multi-line text inputs where appropriate
- ✅ Proper keyboard types (URL, email, number)
- ✅ Required field indicators (*)
- ✅ Inline validation on auth/onboarding forms; navigation gated on validity
- ✅ Supabase auth wired (sign up/login)
- ✅ Profile + role detail upserts to Supabase; optional avatar upload to Storage
  - Common onboarding writes to `profiles` (+ avatar to `avatars` bucket if provided)
  - Founder/Investor/End-user onboarding writes to respective tables

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
 - Create a Storage bucket `avatars` and apply the storage policies in `schema.sql` (authenticated upload/read).

### Supabase Setup Checklist
- Apply `supabase/schema.sql` (tables, indexes, RLS, storage policies).
- Reset API cache (Settings → API → Reset cache) after creating tables/policies.
- Create Storage bucket `avatars`; allow authenticated upload/read (or signed URLs).
- Set Auth redirect URL: use a deep link (e.g., `startupper://auth-callback`) or HTTPS you control. Add it to Site URL and Allowed Redirect URLs.
- Run the app with dart-defines:
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY`
  - Optional: `SUPABASE_EMAIL_REDIRECT` for verification links (deep link/HTTPS)
  - Optional: `BYPASS_VALIDATION=true` for testing

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
- File storage for profile images
- Supabase persistence via `services/supabase_service.dart`
  - Auth screen ensures a `profiles` row on signup/login
  - Common onboarding: upserts profile and avatar to `avatars` bucket
  - Role onboarding: upserts to `founder_details`, `investor_details`, or `enduser_details`
- Feed data fetched from Supabase `feed_items` (fallback to mock if empty/error) via `feed_repository.dart`

## Next Steps

### Immediate Priorities
- [x] Add form validation (required fields, email format)
- [ ] Add loading states and error handling
- [ ] Integrate Supabase authentication (sessions, redirects) end-to-end
- [ ] Set up Supabase Storage for profile pictures (bucket `avatars`, policies in schema.sql)
- [ ] Save user profiles to Supabase database (profile upsert done; ensure flow skips onboarding when role exists)
- [x] Move feed data to a service layer and wire to backend when ready
- [ ] Add empty/skeleton states for feed loading/empty
- [ ] Wire feed inserts/search/filter to Supabase (fetch now uses `feed_items`; inserts seeded via debug action)
- [ ] Session-aware routing to skip onboarding when profile/role exists

### Feature Development
- [ ] Build out the feed screen with real content (Supabase or API)
- [ ] Implement startup discovery and browsing
- [ ] Add user profile viewing and editing
- [ ] Create founder-investor matching
- [ ] Add messaging/communication features
- [ ] Implement search and filtering

### Polish & Optimization
- [ ] Add app icons and splash screens
- [ ] Implement proper error messages
- [ ] Add onboarding progress indicator
- [ ] Optimize images and performance
- [ ] Add analytics and monitoring

## Platform Support

- ✅ iOS (tested on iPhone)
- ✅ macOS (tested on Mac desktop)
- ⏳ Android (platform files not yet added)
- ⏳ Web (platform files not yet added)

## Development Notes

- Auth/onboarding code is split into feature files under `lib/auth` and `lib/onboarding`; app shell routes live in `main.dart`
- No external state management (Provider, Riverpod, etc.) yet
- Inline form validation implemented; can be bypassed for testing with `--dart-define=BYPASS_VALIDATION=true`
- No backend integration yet (Supabase ready)
- Profile images stored locally only

## Learn More

- [Flutter Documentation](https://docs.flutter.dev/)
- [Material 3 Design](https://m3.material.io/)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Image Picker Package](https://pub.dev/packages/image_picker)

## License

TBD

---

**Built with Flutter 🚀**
