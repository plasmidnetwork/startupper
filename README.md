# Startupper

A platform where founders, investors, and early users build together.

## Getting Started

This Flutter app provides authentication and onboarding flows for three user types:
- **Founders** - Build and grow startups
- **Investors** - Discover and fund startups  
- **End-users** - Join startups or test products

## Project Structure

```
startupper/
├── lib/
│   └── main.dart          # Main app with all screens and navigation
├── pubspec.yaml           # Project dependencies and configuration
└── README.md              # This file
```

## Running the App

1. Make sure you have Flutter installed:
   ```bash
   flutter --version
   ```

2. Get dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Current Implementation

✅ Complete navigation flow with 7 screens:
- Auth screen (login/signup)
- Role selection screen
- Common onboarding screen
- Founder-specific onboarding
- Investor-specific onboarding
- End-user-specific onboarding
- Feed screen (placeholder)

✅ Features:
- Named routes navigation
- Role-based onboarding flow
- Form inputs with proper state management
- Material 3 design
- Null-safe Dart code

## Next Steps

- [ ] Add form validation
- [ ] Integrate Supabase authentication
- [ ] Save user profiles to database
- [ ] Build out the feed screen
- [ ] Add user profile viewing/editing
- [ ] Implement startup discovery features

## Learn More

- [Flutter Documentation](https://docs.flutter.dev/)
- [Material 3 Design](https://m3.material.io/)
- [Supabase Flutter Guide](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)

