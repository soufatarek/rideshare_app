# RideShare App

A Flutter ride-sharing application inspired by Uber.

## Features

- **Authentication**:
  - Phone Number Login (UI)
  - OTP Verification (UI) using `pinput`
- **Home & Ride Request**:
  - Google Maps Integration (requires API Key)
  - Permission Handling (Location)
  - "Where to?" Destination Search (Mock)
  - **Ride Simulation Flow**:
    - Vehicle Selection (Standard, Black, XL)
    - Finding Driver State
    - Driver Arriving State
    - Trip In Progress State
    - Trip Completed & Rating
- **Navigation**:
  - Deep linking support with `go_router`
  - Side Menu (Drawer) Navigation
- **Profile & Settings**:
  - Profile Management
  - Saved Places (Home, Work)
  - Settings Screen
- **Wallet & History**:
  - Wallet UI (Balance, Payment Methods)
  - Ride History (Trips List)

## Setup

1.  **Clone the repository**.
2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```
3.  **App Configuration**:
    *   **Google Maps**: Add your API Key to `android/app/src/main/AndroidManifest.xml` and `ios/Runner/AppDelegate.swift`.
    *   **Firebase**: (Optional for now) Configure Firebase if you intend to implement real backend auth.
4.  **Run the app**:
    ```bash
    flutter run
    ```

## Project Structure

The project follows a **Feature-First** architecture:

```
lib/
├── core/
│   ├── constants/       # App Colors, Constants
│   ├── theme/           # App Theme, Typography
│   └── router.dart      # GoRouter configuration
├── features/
│   ├── auth/            # Login, OTP
│   ├── home/            # Map, Ride Request Flow
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   └── widgets/
│   │   │       └── sheets/   # Bottom Sheet states (WhereTo, VehicleSelection, etc.)
│   ├── payment/         # Wallet
│   ├── profile/         # Profile, Saved Places
│   ├── settings/        # App Settings
│   └── trips/           # Ride History
└── main.dart            # Entry point
```

## Note

Ensure you have a valid Google Maps API key enabled for Android and iOS SDKs to see the map rendering correctly. Without it, the map will show a blank screen.
