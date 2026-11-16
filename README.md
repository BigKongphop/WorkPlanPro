# 📱 WorkPlanPro — Collaborative Work & Task Planning App

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.5+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-brightgreen?style=for-the-badge" alt="Platform" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License" />
</p>

---

## 📖 Overview

**WorkPlanPro** is a comprehensive, modern cross-platform mobile application built with **Flutter** and **Firebase**. Designed to streamline both individual task management and collaborative team workflows, it offers intuitive scheduling, real-time group collaboration, interactive calendar views, and biometric security.

---

## ✨ Key Features (ฟีเจอร์เด่น)

### 1. 📅 Personal Task & Activity Management
- **Task Scheduling:** Create, update, filter, and organize tasks by priority, date, and status.
- **Dynamic Filtering & Sorting:** Quickly find tasks using status filters, chronological sorting, and custom search criteria.
- **Detailed Bottom Sheet View:** Inspect, modify, or complete activities with an intuitive bottom sheet interface.

### 2. 🗓️ Interactive Calendar View
- Powered by `table_calendar` for seamless daily, weekly, and monthly schedule tracking.
- Direct synchronization with personal and team milestones.

### 3. 👥 Team & Group Workspaces (การทำงานร่วมกันเป็นทีม)
- **Create & Customize Groups:** Set up project workspaces with custom avatars and descriptions.
- **Member Invitations & Notifications:** Send invites, manage group members, and receive real-time notifications.
- **Shared Group Calendar:** Plan team deadlines and synchronize group activities in real time.

### 4. 📝 Built-in Notes & Documentation
- Fast, reliable note-taking system for recording ideas, meeting notes, and action items.
- Synchronized with Cloud Firestore for cross-device access.

### 5. 🔐 Security & Multi-Method Authentication
- **Email & Password Authentication** with real-time validation.
- **Google Sign-In** for fast, frictionless onboarding.
- **Biometric Authentication:** Face ID and Fingerprint login support powered by `local_auth`.

### 6. 🎨 Polished UI & Delightful UX
- **Motion Tab Bar:** Animated, fluid bottom navigation powered by `motion_tab_bar_v2`.
- **Micro-interactions:** Interactive Lottie animations, Shimmer loading placeholders, and smooth transitions.
- **Offline Resilience:** State caching with `shared_preferences` and connection monitoring with `connectivity_plus`.

---

## 🛠️ Tech Stack & Architecture

| Layer | Technologies / Packages |
|---|---|
| **Framework & Language** | [Flutter](https://flutter.dev/) (v3.5+), [Dart](https://dart.dev/) (v3.5.3) |
| **Backend as a Service** | [Firebase](https://firebase.google.com/) (Auth, Cloud Firestore, Realtime Database, Storage) |
| **Monitoring & Quality** | Firebase Crashlytics, Analytics, Performance Monitoring, App Check |
| **State Management** | Provider Pattern (`provider`), Reactive Programming (`rxdart`) |
| **Authentication & Security** | `firebase_auth`, `google_sign_in`, `local_auth` (Biometrics) |
| **UI & UX Libraries** | `motion_tab_bar_v2`, `table_calendar`, `lottie`, `flutter_animate`, `shimmer` |
| **Local Storage & Hardware** | `shared_preferences`, `path_provider`, `image_picker`, `file_picker` |

---

## 📂 Project Architecture

```text
workplanpro/
├── android/                  # Native Android configuration & assets
├── ios/                      # Native iOS configuration
├── assets/                   # Lottie animations, group icons & static media
│   ├── animation/            # Login and loading JSON animations
│   └── group_images/         # Preset team/group avatars
└── lib/
    ├── main.dart             # Application entry point & Firebase initialization
    ├── models/               # Data models (Activity, Group, Note, User, etc.)
    │   ├── activity.dart
    │   ├── group.dart
    │   ├── group_member.dart
    │   └── note.dart
    ├── screens/              # Application UI Screens & Controllers
    │   ├── home_page.dart    # Dashboard & Motion Tab Navigation
    │   ├── calendar_page.dart# Personal interactive calendar
    │   ├── group_page.dart   # Team collaboration & group manager
    │   ├── note_page.dart    # Quick notes & documentation
    │   ├── login_page.dart   # Authentication & Biometric login
    │   └── account_page.dart # Profile management & preferences
    ├── services/             # Cloud Firestore & Realtime Database handlers
    │   ├── activity_database.dart
    │   └── note_database.dart
    └── widgets/              # Reusable UI components & custom sheets
```

---

## 🚀 Getting Started (วิธีติดตั้งและรันโปรเจกต์)

### 📋 Prerequisites (สิ่งที่ต้องเตรียม)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.5.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.5.3`)
- Android Studio / VS Code with Flutter extension
- An Android Device / Emulator or iOS Simulator

### 🔧 Installation Steps

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/BigKongphop/WorkPlanPro.git
   cd WorkPlanPro/workplanpro
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup:**
   - Ensure your `google-services.json` is located in `android/app/`
   - For iOS, place `GoogleService-Info.plist` in `ios/Runner/`

4. **Run the Application:**
   ```bash
   flutter run
   ```

---

## 👤 Author

- **Kongphop Suanma**
  - GitHub: [@BigKongphop](https://github.com/BigKongphop)
  - Portfolio: [kongphop-webport.framer.website](https://kongphop-webport.framer.website/)

---

## 📄 License

This project is open-source and available under the [MIT License](LICENSE).
