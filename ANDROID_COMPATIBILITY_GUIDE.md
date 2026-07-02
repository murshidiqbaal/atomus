# ATOMUS Android Compatibility & Release Guide

This guide contains information on Android device compatibility, build instructions, signing details, and installation troubleshooting for the ATOMUS Flutter application.

---

## 📱 Supported Android Versions & Architectures

The ATOMUS application is fully optimized to run on low-end, mid-range, and flagship Android devices.

| Specification | Support Status | Notes |
|---|---|---|
| **Minimum OS Version** | Android 5.0 (API 21) | Supports Lollipop, Marshmallow, Nougat, Oreo, Pie, 10, 11, 12, 13, 14, 15+ |
| **Target OS Version** | Android 15 (API 35) | Fully targets the runtime behavior optimizations of Android 15 |
| **Supported CPU ABIs** | `armeabi-v7a` (32-bit), `arm64-v8a` (64-bit), `x86_64` (Intel/Emulator) | Compatible with both 32-bit only and 64-bit only Android architectures |
| **MultiDex Support** | Native (minSdk 21) | Fully enabled to prevent DEX compiler overflow limits |

---

## 🛠️ Production Build Process

Always run a clean build to ensure all compilation caches are refreshed and ProGuard/R8 optimizations are correctly applied.

### Step 1: Clean and Fetch Dependencies
```bash
flutter clean
flutter pub get
```

### Step 2: Build APK Options

#### Option A: Build Universal (Fat) APK
Generates a single APK containing all CPU architectures. (Larger file size, but works on any device).
```bash
flutter build apk --release
```
- **Output Path**: `build/app/outputs/flutter-apk/app-release.apk`
- **Typical Size**: ~61.4 MB

#### Option B: Build Split (Optimized) APKs (Recommended)
Generates separate, lightweight APKs optimized for specific CPU architectures.
```bash
flutter build apk --release --split-per-abi
```
- **Output Paths**:
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (For 32-bit ARM devices)
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (For 64-bit ARM devices)
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk` (For Intel x64 emulators)
- **Typical Size**: ~20 MB - 23 MB

---

## 📲 Device Installation & ABI Matching Guide

To prevent **"There was a problem while parsing the package"** errors, make sure you install the correct APK for your device's architecture:

### 1. Low-End / Budget Devices (e.g., Samsung Galaxy M03, M02, Xiaomi Redmi 9A, 10A)
* **The Root Cause**: Many budget devices use a 64-bit CPU but run a **32-bit Android operating system** (Android Go Edition) to save memory (2GB-3GB RAM).
* **The Solution**: 
  - Install the **Universal APK (`app-release.apk`)**, or
  - Install the **32-bit Split APK (`app-armeabi-v7a-release.apk`)**.
  - *If you attempt to install the 64-bit APK (`app-arm64-v8a-release.apk`) on these devices, Android will throw a parsing/compatibility error.*

### 2. High-End / Modern Flagship Devices (e.g., Samsung S-Series, Pixel, OnePlus)
* These devices run a full 64-bit Android OS.
* **The Solution**:
  - Install the **64-bit Split APK (`app-arm64-v8a-release.apk`)** for maximum CPU efficiency and speed.

---

## 🔍 Troubleshooting "There was a problem while parsing the package"

If you encounter this error during installation, check the following steps:

### 1. Incorrect CPU ABI (Architecture)
* **Check**: If you downloaded a split APK, you might have installed the `arm64-v8a` version on a 32-bit Android Go device (like Samsung M03).
* **Fix**: Uninstall any existing versions, and install `app-armeabi-v7a-release.apk` or `app-release.apk`.

### 2. Incomplete or Corrupt APK File
* **Check**: The APK file may have been corrupted during transfer (WhatsApp, Google Drive, email, or USB).
* **Fix**: Re-transfer the APK file using a reliable method (e.g., ADB, Google Drive download, or direct USB cable) and ensure the file size matches the build output exactly.

### 3. Google Play Protect Block
* **Check**: Android's security features might block installations of apps signed with debug/self-signed certificates.
* **Fix**:
  1. Open **Google Play Store**.
  2. Tap your profile icon, then select **Play Protect**.
  3. Tap the **Settings (gear)** icon.
  4. Temporarily toggle off **Scan apps with Play Protect**.

### 4. Existing App Version Conflict
* **Check**: An older version of the app might be installed with a different signature key.
* **Fix**: Completely uninstall any older versions of ATOMUS for all users on the device before installing the new APK.

---

## ⚙️ Manufacturer-Specific Fixes

### 🛡️ Samsung Devices (Knox Security & Android Go)
- **Problem**: Samsung Knox or package parser rejects unsigned or incompletely signed APKs.
- **Fix**: The build script is configured to explicitly sign release APKs with **both V1 (JAR) and V2 (APK Signature Scheme)** signatures. If you sign using a custom keystore, ensure both signature versions remain checked.
- On Android Go editions (e.g., M03), ensure you do not turn on developer options that restrict background execution, as it can cause the installer to abort.

### ⚡ Xiaomi / Redmi Devices (MIUI & HyperOS Optimization)
- **Problem**: Xiaomi's installer blocks third-party APKs with general errors.
- **Fix**:
  1. Go to **Settings** > **About Phone**.
  2. Tap **MIUI Version** (or **OS Version**) 7 times to enable Developer Options.
  3. Go to **Settings** > **Additional Settings** > **Developer Options**.
  4. Find **Turn on MIUI optimization** (or system optimization) and toggle it off temporarily if the install is blocked.
  5. Enable **Install via USB** if installing through ADB.

### 📱 Oppo / Vivo / Realme / OnePlus
- **Problem**: The native package manager warns that the app is unsafe.
- **Fix**: Select **"Install anyway"** or **"More details"** -> **"Install"** during the prompt. Ensure that "Unknown Sources" permission is enabled for the browser or file manager used to open the APK.
