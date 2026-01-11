# Contributing to SpecEI

Thank you for your interest in contributing to SpecEI! This document provides guidelines and instructions for contributing.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [How to Contribute](#how-to-contribute)
5. [Pull Request Process](#pull-request-process)
6. [Coding Standards](#coding-standards)
7. [Commit Guidelines](#commit-guidelines)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive environment. All contributors are expected to:

- Be respectful and considerate in all interactions
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards others

### Unacceptable Behavior

- Harassment, discrimination, or personal attacks
- Trolling or insulting comments
- Publishing others' private information
- Any conduct inappropriate for a professional setting

### Enforcement

Violations may result in temporary or permanent ban from the project. Report issues to the maintainers via GitHub.

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Git
- A GitHub account
- Android Studio or VS Code with Flutter extensions

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork:
```bash
git clone https://github.com/YOUR-USERNAME/Spec-EI.git
cd Spec-EI
```

3. Add upstream remote:
```bash
git remote add upstream https://github.com/VK-Amogh/Spec-EI.git
```

---

## Development Setup

### 1. Environment Configuration

```bash
cd SpecEI_app/specei_app
cp lib/core/env_config.example.dart lib/core/env_config.dart
```

Edit `env_config.dart` with test API keys (use your own Firebase/Supabase projects for development).

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run -d windows  # or android, ios, chrome
```

### 4. Run Tests

```bash
flutter test
flutter analyze
```

---

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the bug report template
3. Include:
   - Clear description of the issue
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable
   - Device/OS information

### Suggesting Features

1. Check existing feature requests
2. Open a new issue with:
   - Clear use case description
   - Proposed solution
   - Alternative approaches considered

### Code Contributions

1. Look for issues labeled `good first issue` or `help wanted`
2. Comment on the issue to claim it
3. Create a feature branch
4. Implement changes
5. Submit a pull request

---

## Pull Request Process

### Before Submitting

- [ ] Code follows the project's style guidelines
- [ ] All tests pass (`flutter test`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] New features include tests
- [ ] Documentation is updated if needed
- [ ] Commit messages follow conventions

### PR Requirements

1. **Title**: Use conventional commit format
   - `feat: add user profile screen`
   - `fix: resolve login crash on iOS`
   - `docs: update README setup instructions`

2. **Description**: Include:
   - What changes were made
   - Why they were made
   - Link to related issue(s)

3. **Review**: At least one maintainer approval required

### After Submission

- Respond to review feedback promptly
- Keep the PR updated with the main branch
- Be patient - reviews take time

---

## Coding Standards

### Dart/Flutter Guidelines

```dart
// Use descriptive names
class UserAuthenticationService { }  // ✓ Good
class UAS { }                        // ✗ Bad

// Document public APIs
/// Authenticates user with email and password.
/// 
/// Throws [AuthException] if credentials are invalid.
Future<User> signIn(String email, String password) async { }

// Use const constructors where possible
const EdgeInsets.all(16);  // ✓ Good

// Prefer named parameters for clarity
CustomButton(
  text: 'Submit',
  onPressed: _handleSubmit,
  isLoading: false,
);
```

### File Organization

```
lib/
├── core/           # App-wide utilities, themes, constants
├── screens/        # Full-page UI components
├── widgets/        # Reusable UI components
├── services/       # Business logic and API calls
├── models/         # Data models
└── main.dart       # Entry point
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `user_profile_screen.dart` |
| Classes | PascalCase | `UserProfileScreen` |
| Variables | camelCase | `userName` |
| Constants | lowerCamelCase | `defaultPadding` |
| Private | _prefix | `_handleTap` |

---

## Commit Guidelines

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style (no functionality change)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build/tool changes

### Examples

```bash
feat(auth): add phone number verification

Implement OTP verification for phone numbers during registration.
Includes 60-second countdown timer and resend functionality.

Closes #42
```

```bash
fix(ui): resolve overflow on small screens

Wrap text in registration form to prevent horizontal overflow
on devices with screen width < 360px.
```

---

## Questions?

If you have questions, open a discussion on GitHub or comment on the relevant issue.

Thank you for contributing to SpecEI! 🎉
