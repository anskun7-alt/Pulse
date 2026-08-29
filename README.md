# 🎵 Pulse

**Your media, your way.**

Pulse is a feature-rich media player built with Flutter, designed for playing audio and video files on your device. It scans your local storage, organizes your media into categories, and 
provides a seamless playback experience with background audio support.

## ✨ Features

- **Audio & Video Playback** — Play local audio and video files with a polished player UI
- **Background Audio** — Keep listening to music while using other apps
- **Playlist Management** — Create, edit, and manage custom playlists
- **Folder Browsing** — Browse and play media organized by folders
- **Media Metadata** — View song info, album art, and video thumbnails
- **Lyrics Support** — Fetch and display lyrics for your music
- **Dynamic Theming** — Adaptive colors extracted from album art
- **Settings & Customization** — Configure playback behavior and app preferences

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart)
- **Audio Engine:** just_audio + audio_service (background playback)
- **Video Engine:** better_player_plus
- **Local Storage:** Hive
- **Metadata:** flutter_media_metadata, audiotags
- **UI Enhancements:** flutter_animate, shimmer, palette_generator

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point & initialization
├── app.dart                  # MaterialApp configuration
├── theme.dart                # Theme definitions
├── models/                   # Data models
├── players/                  # Audio & video player screens
├── providers/                # State management
├── screens/                  # App screens & tabs
│   ├── home_screen.dart      # Main tabbed interface
│   ├── music_tab.dart        # Music library view
│   ├── audio_tab.dart        # Audio files view
│   ├── videos_tab.dart       # Video library view
│   ├── folders_tab.dart      # Folder browser
│   ├── playlists_tab.dart    # Playlist management
│   └── settings_screen.dart  # App settings
├── services/                 # Core services
│   ├── media_scanner.dart    # Device media scanning
│   ├── playback_service.dart # Audio playback engine
│   ├── playlist_service.dart # Playlist persistence
│   ├── lyrics_service.dart   # Lyrics fetching
│   └── metadata_service.dart # Media metadata extraction
├── theme/                    # Theme components
└── widgets/                  # Reusable UI components
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0 <4.0.0`
- Android SDK (for Android builds)

### Installation

```bash
# Clone the repository
git clone https://github.com/anskun7-alt/Pulse.git
cd Pulse

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Permissions

Pulse requires storage permissions to scan and play media files on your device. You'll be prompted to grant these permissions on first launch.

## 📄 License

This project is for personal use.
