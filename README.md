# SpecEI - Smart AI Spectacle Companion 🕶️

<p align="center">
  <strong>Your AI-Powered Smart Glasses Companion</strong>
</p>

---

## Overview

SpecEI is an innovative smart spectacle application that transforms the way you capture, remember, and interact with your world. Using cutting-edge AI technology, SpecEI allows users to:

- 🎥 **Record Moments** - Capture video and audio from your smart glasses
- 🧠 **Memory Recall** - Ask questions about your recorded experiences
- 🎤 **Voice Interaction** - Natural language queries about what you've seen and heard
- 📹 **Video Analysis** - AI-powered understanding of recorded content
- 🔊 **Audio Processing** - Intelligent audio transcription and analysis
- 💬 **Contextual Q&A** - Get answers based on your memory bank

## Features

### Core Capabilities
- **Real-time Recording** - Seamlessly capture video and audio through connected smart glasses
- **AI Memory Bank** - Store and index your experiences for instant recall
- **Natural Language Queries** - Ask questions like "What did John say in the meeting yesterday?"
- **Multi-modal Analysis** - Process both visual and audio information
- **Secure Storage** - Your memories are encrypted and private

### Technology Stack
- **Frontend**: Flutter (Cross-platform: Android, iOS, Windows, Web)
- **Backend**: Firebase Authentication + Supabase Database
- **AI**: Advanced language models for memory analysis

## Project Structure

```
SpecEI/
├── SpecEI_app/          # Flutter mobile application
│   └── specei_app/      # Main application codebase
├── SpecEI_UI-UX/        # UI/UX design references
│   ├── ai_camera_ultimate_ui/
│   ├── glasses_control_&_status/
│   ├── home_/           # Home screen designs
│   └── ...
└── README.md            # This file
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code
- Firebase account
- Supabase account

### Installation

1. Clone the repository:
```bash
git clone https://github.com/VK-Amogh/Spec-EI.git
cd Spec-EI
```

2. Navigate to the app directory:
```bash
cd SpecEI_app/specei_app
```

3. Set up environment configuration:
```bash
cp lib/core/env_config.example.dart lib/core/env_config.dart
# Edit env_config.dart with your API keys
```

4. Install dependencies:
```bash
flutter pub get
```

5. Run the app:
```bash
flutter run
```

## Security Note

⚠️ **Important**: Never commit `env_config.dart` or any file containing API keys to version control. The `.gitignore` is configured to exclude sensitive files.

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under a proprietary license - see the [LICENSE](LICENSE) file for details.

## Contact

- **Developer**: VK-Amogh
- **GitHub**: [@VK-Amogh](https://github.com/VK-Amogh)

---

<p align="center">
  Made with ❤️ for the future of wearable AI
</p>
