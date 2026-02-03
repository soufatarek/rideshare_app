# iOS Build & Deployment Guide 🍎

Building iOS apps via GitHub Actions requires setting up **Command Line Signing**. This is more complex than Android because of Apple's security requirements.

## ⚠️ Prerequisites
1.  **Apple Developer Account** ($99/year) - Highly recommended. Without this, certificates expire in 7 days and automation is extremely difficult.
2.  **Mac with Xcode** (Local) - You need this **ONCE** initially to generate the Certificates and Provisioning Profiles.

---

## Step 1: Export Signing Files (On a Mac)
You need to generate two files to give GitHub permission to sign your app.

### A. The Certificate (.p12)
1.  Open **Keychain Access** on a Mac.
2.  Find your **Apple Distribution** certificate (or create one in Xcode).
3.  Right-click -> **Export**.
4.  Save as `certificate.p12`.
5.  Set a password (remember this!).

### B. The Provisioning Profile (.mobileprovision)
1.  Log in to [Apple Developer Portal](https://developer.apple.com/).
2.  Go to **Profiles** -> Create a new **Distribution (Ad Hoc)** profile (for testing on specific phones) or **App Store** (for TestFlight).
3.  Select your App ID and Certificate.
4.  **Crucial for Ad Hoc**: Add your iPhone's **UDID** to the device list.
5.  Download the profile as `profile.mobileprovision`.

---

## Step 2: Configure GitHub Secrets
1.  Go to your GitHub Repo -> **Settings** -> **Secrets and variables** -> **Actions**.
2.  Add the following Repository Secrets:

| Secret Name | Value |
| :--- | :--- |
| `BUILD_CERTIFICATE_BASE64` | Run `base64 -i certificate.p12 | clip` (Windows) or `base64 -i certificate.p12 | pbcopy` (Mac) and paste the result. |
| `P12_PASSWORD` | The password you set for the .p12 file. |
| `BUILD_PROVISION_PROFILE_BASE64` | Run `base64 -i profile.mobileprovision | clip` and paste the result. |
| `KEYCHAIN_PASSWORD` | Set this to any random string (e.g., `foobar`). It's used for a temporary keychain on the build server. |

---

## Step 3: Deployment (Installing the IPA)
Once the GitHub Action finishes (approx 20 mins), it will produce an `.ipa` file.

### Option A: TestFlight (Best)
If you used an **App Store** profile, you can upload the IPA to **Transporter** (on Mac) or configure the workflow to upload directly to TestFlight.

### Option B: Diawi (Easiest for Ad Hoc)
1.  Download the `.ipa` from GitHub Actions artifacts.
2.  Go to [diawi.com](https://www.diawi.com/).
3.  Drag and drop the `.ipa`.
4.  Scan the QR code with your iPhone to install.
   *   *Note: This ONLY works if your iPhone's UDID was in the Provisioning Profile.*

### Option C: AltStore (Free Account)
If you don't have a paid developer account:
1.  You cannot use GitHub Actions effectively (certificates expire too fast).
2.  You must build locally or use **AltServer** on your Windows PC to sideload the app.

---
