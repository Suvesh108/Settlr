# 📱 Settlr Mobile — Native Android App (Flutter & Dart)

Native Android implementation of **Settlr** built with Flutter, Material 3, and automatic background bank SMS transaction detection.

---

## 🏗️ Directory Architecture

```
mobile/
├── android/
│   └── app/
│       └── src/main/
│           ├── AndroidManifest.xml           # Android SMS & Network permissions
│           ├── kotlin/com/settlr/app/        # Native Android MainActivity
│           └── res/values/styles.xml         # Launch themes
├── lib/
│   ├── main.dart                             # App bootstrap & session routing
│   ├── models/
│   │   └── models.dart                       # Ledger models (User, Group, Expense, Debt)
│   ├── services/
│   │   ├── api_service.dart                  # REST & session communication with Go backend
│   │   └── sms_detector.dart                 # Native regex debit SMS parsing
│   ├── screens/
│   │   ├── onboarding_screen.dart            # First-time user profile & invite code entry
│   │   └── home_screen.dart                  # Continuous netting, bilateral matrix & logout modal
│   └── theme/
│       └── colors.dart                       # Design system color tokens
└── pubspec.yaml                              # Flutter dependencies & metadata
```

---

## ⚡ Key Mobile Features

1. **Native Bank SMS Parsing (`sms_detector.dart`)**:
   - Automatically intercepts bank debit SMS (UPI, Netbanking, Cards).
   - Extracts merchant (`Swiggy`, `Uber`, `Zomato`), amounts, and categories.

2. **Full Ledger Feature Parity**:
   - **Continuous Netting & Bilateral Matrix**: Automatically balances debts across active groups.
   - **Personal vs Group Mode**: Gliding pill switcher keeps solitary expenses separate from shared room/trip ledgers.
   - **Custom Logout Message Bar**: Warns users before erasing local device session data.

---

## 🔨 Building the Android APK

### Prerequisites:
- Flutter SDK (v3.0.0+)
- Android SDK & Java 17

### Commands:
```bash
cd mobile

# 1. Fetch dependencies
flutter pub get

# 2. Run in debug mode on connected device or emulator
flutter run

# 3. Build release Android APK
flutter build apk --release
```

The compiled APK will be generated at:
```
mobile/build/app/outputs/flutter-apk/app-release.apk
```
