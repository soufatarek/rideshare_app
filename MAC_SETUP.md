# Setting up RideShare App on macOS

Since you have moved to a Mac, here is how to get your Flutter app running.

## 1. Prerequisites
Ensure you have the following installed:
- **Xcode** (from Mac App Store) - required for iOS simulator and building.
- **Flutter SDK** (Follow instructions at [flutter.dev](https://flutter.dev/docs/get-started/install/macos)).
- **CocoaPods** (Required for iOS dependencies). Run `sudo gem install cocoapods` in terminal.

## 2. Clone the Repository
Open your terminal and run:
```bash
git clone https://github.com/soufatarek/rideshare_app.git
cd rideshare_app
```

## 3. Install Dependencies
```bash
flutter pub get
```

## 4. iOS Setup
The iOS project needs to install native pods (libraries).
```bash
cd ios
pod install
cd ..
```

## 5. App Signing (Important)
1. Open `ios/Runner.xcworkspace` in **Xcode**.
2. Select the "Runner" project in the left navigator.
3. Go to the **Signing & Capabilities** tab.
4. Add your **Apple ID** account.
5. Select your **Team** to valid signing.
6. Change the **Bundle Identifier** if necessary (e.g., `com.yourname.rideshareApp`).

## 6. Run the App
You can now run the app on the iOS Simulator or a physical iPhone.
```bash
flutter run
```

## Troubleshooting
- If `pod install` fails, try running `pod repo update` or `rm -rf Pods Podfile.lock` and running `pod install` again.
- If you see "CocoaPods not installed", make sure to run `sudo gem install cocoapods`.
