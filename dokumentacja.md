# SkiCapture
Aplikacja służąca do predykcji techniki jazdy narciarskiej z użyciem kamery i modelu sztucznej inteligencji. Stworzona pod urządzenia z systemem Android.

## Funkcjonalności
- **Analiza wideo**: Nagrywa wideo narciarza i przesyła je do Firebase w celu przetworzenia na dane dla modelu sztucznej inteligencji.
- **Przechowywanie i przetwarzanie w chmurze**: wideo jest przechowywane w Firebase Storage i za pomocą funkcjonalności Cloud Functions jest przetwarzany na punkty danych w odpowiednim formacie za pomocą YOLO (?) po czym jest przechowywany w Firestore Database.
- **Podgląd wideo i predykcja**: wideo wraz z przetworzonymi punktami danych jest dostępne w aplikacji do przeglądu, można uruchomić predykcję techniki jazdy dla dowolnego wideo.
- **Predykcja lokalnych danych na urządzeniu**: Opcja wybrania własnych punktów danych w odpowiednim formacie do predykcji techniki jazdy bez wykorzystania zdalnej bazy danych.

## Instrukcja obsługi

### Nagranie wideo
1. Z dolnego paska funkcjonalności wybieramy "Kamera", następnie klikamy przycisk "Nagraj wideo".

<img width="540" height="1070" alt="kamera" src="https://github.com/user-attachments/assets/080ef70c-52e5-452a-99c9-272423c2f3b7" />

2. W nowym widoku możemy kliknąć strzałkę w lewym górnym rogu do powrotu do poprzedniego ekranu, albo kliknąć czerwony przycisk rozpoczynający nagrywanie.
   
<img width="540" height="1070" alt="nagrywanie_wideo" src="https://github.com/user-attachments/assets/8870342c-c4e8-4a33-9e2a-7ccf5906df85" />

3. Klikamy ponownie czerwony przycisk aby zakończyć nagrywanie, wyświetli się powiadomienie o przetwarzaniu nagrania i zakończonym wysłaniu nagrania. Możemy wrócić do startowego widoku strzałką w lewym górnym rogu.

<img width="540" height="480" alt="wideo_wyslane" src="https://github.com/user-attachments/assets/d98dae8f-eb0b-4432-be06-f19e235fea91" />

### Podgląd wideo
1. Z dolnego paska funkcjonalności wybieramy "Lista nagrań", ukaże nam się lista wszystkich nagrań w aplikacji z możliwością ich usunięcia i zmiany nazwy.

<img width="540" height="1070" alt="lista_nagran" src="https://github.com/user-attachments/assets/91cf0609-a362-499e-ae26-6f1e908afbee" />

2. Wybieramy dany film przyciskiem uruchamiającym obok nazwy wybranego filmu. Zostaniemy przeniesieni do widoku podglądu danego filmu. Można w nim zobaczyć nałożony szkielet na nagranie, sterować danym nagraniem jak i zobaczyć predykcję modelu i ją edytować.

<img width="540" height="1070" alt="podglad_nagrania" src="https://github.com/user-attachments/assets/aabb7684-fccc-4f42-9a54-0aed1001ec3f" />

### Predykcja techniki jazdy
1. Z dolnego paska funkcjonalności wybieramy "Lista nagrań", wybieramy konkretny film na którym chcemy uruchomić predykcję.

2. W podglądzie wideo klikamy przycisk "Uruchom model". Wynik zostanie wyświetlony na ekranie.

### Wczytanie i predykcja lokalnych danych
1. Z dolnego paska funkcjonalności wybieramy "Analiza CSV".
   
<img width="540" height="1070" alt="analiza_csv" src="https://github.com/user-attachments/assets/386b18bf-ba0d-4910-96e7-18c19114c337" />

2. Wczytujemy plik CSV przyciskiem "Wczytaj plik CSV z danymi".

3. Klikamy przycisk "Wykonaj Predykcję na danych z CSV".

4. Wynik predykcji będzie zamieszczony na tym samym widoku.

## Uruchomienie aplikacji deweloperskiej

### Wymagania wstępne
- **Flutter SDK**: [Zainstaluj Flutter](https://flutter.dev/docs/get-started/install)
- **Node.js & npm**: Wymagane dla narzędzi Firebase Tools.
- **Python 3.12**: Wymagany dla Cloud Functions.
- **Firebase CLI**: Zainstaluj za pomocą polecenia `npm install -g firebase-tools`.

### Konfiguracja

1.  **Sklonuj repozytorium:**
    ```bash
    git clone <repository_url>
    cd ski_app
    ```

2.  **Zainstaluj zależności Flutter:**
    ```bash
    flutter pub get
    ```

### Konfiguracja Firebase

Ten projekt opiera się na Firebase w zakresie Storage, Firestore oraz Cloud Functions.

1.  **Zaloguj się do Firebase:**
    ```bash
    firebase login
    ```

2.  **Skonfiguruj FlutterFire (jeśli konfigurujesz projekt od zera):**
    ```bash
    flutterfire configure
    ```
    *Wybierz swój projekt i platformy (Android/iOS).*

3.  **Wdróż Cloud Functions:**
    Projekt korzysta z funkcji Cloud Functions w języku Python (2. generacji).

    * Nawiguj do katalogu functions (opcjonalnie, w celu konfiguracji venv):
        ```bash
        cd functions
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
        ```
    * Wdróż funkcje:
        ```bash
        firebase deploy --only functions
        ```

### Uruchamianie aplikacji

1.  **Wymagane urządzenie fizyczne**: Moduł aparatu wymaga fizycznego urządzenia z systemem Android lub iOS.
2.  **Uruchom:**
    ```bash
    flutter run
    ```

### Lokalne testowanie Cloud Functions

Możesz testować funkcje Cloud Functions oraz interakcje z Firestore lokalnie, korzystając z pakietu Firebase Emulator Suite.

1.  **Uruchom emulatory:**
    To polecenie uruchamia lokalne wersje Functions, Firestore i Storage.
    ```bash
    firebase emulators:start
    ```

2.  **Dostęp do interfejsu emulatora:**
    Otwórz [http://localhost:4000](http://localhost:4000) w swojej przeglądarce.

3.  **Wyzwól funkcję:**
    * Przejdź do karty **Storage** w interfejsie emulatora.
    * Utwórz folder o nazwie `videos`.
    * Prześlij plik wideo (np. `test.mp4`) do folderu `videos`.

4.  **Zweryfikuj wyniki:**
    * Sprawdź logi w terminalu, w którym uruchomiono `firebase emulators:start`. Powinieneś zobaczyć komunikaty „Processing started” oraz „Successfully saved results”.
    * Przejdź do karty **Firestore** w interfejsie emulatora.
    * Poszukaj kolekcji `video_results`. Powinieneś zobaczyć dokument o takiej samej nazwie jak Twój plik wideo, zawierający wyniki przetwarzania.

### Struktura projektu
- `lib/`: Kod źródłowy aplikacji Flutter.
    - `main.dart`: Punkt wejścia i ekran główny.
    - `camera_screen.dart`: Logika nagrywania wideo i przesyłania go do Firebase Storage.
    - `models.dart`: Logika do wczytania modelu i uruchomienia predykcji techniki jazdy narciarskiej.
    - `recordings_list_screen.dart`: Logika do pobrania listy filmów do predykcji z Firestore Database.
    - `video_preview_screen`: Logika do wizualizacji podglądu wideo przed predykcją techniki jazdy.
    - `skeleton_painter.dart`: Logika do rysowania szkieletu w podglądzie wideo.
- `functions/`: Firebase Cloud Functions (Python).
    - `main.py`: Logika wyzwalacza (`on_video_uploaded`).
