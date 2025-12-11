# Ski Application

A Flutter application for ski technique analysis using device sensors and video processing.

## Features
- **Sensor Analysis**: Records accelerometer/gyroscope data to analyze skiing style.
- **Video Analysis**: Records video of the skier and uploads it to Firebase for processing.
- **Cloud Processing**: Python Cloud Functions (2nd Gen) process uploaded videos and generate keypoints (Mock implementation currently).

## Development Guide

### Prerequisites
- **Flutter SDK**: [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Node.js & npm**: Required for Firebase Tools.
- **Python 3.12**: Required for Cloud Functions.
- **Firebase CLI**: Install via `npm install -g firebase-tools`.

### Setup

1.  **Clone the repository:**
    ```bash
    git clone <repository_url>
    cd ski_app
    ```

2.  **Install Flutter dependencies:**
    ```bash
    flutter pub get
    ```

### Firebase Configuration

This project relies on Firebase for Storage, Firestore, and Cloud Functions.

1.  **Login to Firebase:**
    ```bash
    firebase login
    ```

2.  **Configure FlutterFire (if setting up from scratch):**
    ```bash
    flutterfire configure
    ```
    *Select your project and platforms (Android/iOS).*

3.  **Deploy Cloud Functions:**
    The project uses Python Cloud Functions (2nd Gen).

    *   Navigate to functions directory (optional, for venv setup):
        ```bash
        cd functions
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        ```
    *   Deploy functions:
        ```bash
        firebase deploy --only functions
        ```

### Running the App

1.  **Physical Device Required**: The Camera module requires a physical Android/iOS device.
2.  **Run:**
    ```bash
    flutter run
    ```

### Project Structure
- `lib/`: Flutter application code.
    - `main.dart`: Entry point and Home Screen.
    - `camera_screen.dart`: Video recording and upload logic.
- `functions/`: Firebase Cloud Functions (Python).
    - `main.py`: Trigger logic (`on_video_uploaded`).
