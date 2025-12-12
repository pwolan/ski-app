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

### Testing Cloud Functions Locally

You can test the Cloud Functions and Firestore interactions locally using the Firebase Emulator Suite.

1.  **Start the Emulators:**
    This command starts local versions of Functions, Firestore, and Storage.
    ```bash
    firebase emulators:start
    ```

2.  **Access the Emulator UI:**
    Open [http://localhost:4000](http://localhost:4000) in your browser.

3.  **Trigger the Function:**
    *   Go to the **Storage** tab in the Emulator UI.
    *   Create a folder named `videos`.
    *   Upload a video file (e.g., `test.mp4`) into the `videos` folder.

4.  **Verify Results:**
    *   Check the terminal logs where you ran `firebase emulators:start`. You should see "Processing started" and "Successfully saved results".
    *   Go to the **Firestore** tab in the Emulator UI.
    *   Look for the `video_results` collection. You should see a document with the same name as your video file, containing the processing results.

### Project Structure
- `lib/`: Flutter application code.
    - `main.dart`: Entry point and Home Screen.
    - `camera_screen.dart`: Video recording and upload logic.
- `functions/`: Firebase Cloud Functions (Python).
    - `main.py`: Trigger logic (`on_video_uploaded`).
