# Morpho

System-level input translation for macOS (MVP).

中文文档: [README.zh-CN.md](README.zh-CN.md)

## Slogan

**Native-First, Seamless Input Translation**

## Why Morpho

Morpho started from one concrete problem: in chat, article writing, and other typing-heavy workflows, users need to translate what they are currently typing into a target language immediately, without leaving the current input field.

It keeps translation inside the writing flow, so language switching feels instant instead of disruptive.

## Design Principles

- Solve one core problem deeply: help users translate what they are typing instantly, without breaking their writing flow.
- Keep the product small and purposeful: Morpho is not an all-in-one tool; every feature must serve this core writing scenario and avoid feature bloat.
- Obsess over interaction quality: every action should feel fast, predictable, and effortless, with clear feedback and minimal learning cost.

## Core MVP Capabilities

- Menu bar app with a dedicated settings window.
- Global hotkey to trigger translation.
- Translation rule: translate selection if selected; otherwise translate full input.
- Auto-detect bidirectional routing: source -> target, target -> source.
- Cloud translation via SiliconFlow, with API key persisted in local settings.
- Unified failure feedback through menu bar status and system notifications.
- Layered input channel: AX primary path, controlled paste as final fallback.

## Scope and Boundaries

- Prioritizes mainstream app input scenarios.
- Does not process password/secure input fields.
- Non-standard custom-drawn controls may not be directly readable/writable.
- Clipboard-based path is used only as the last fallback.

## Architecture

- `Sources/MorphoKit/Domain`: domain models and contracts
- `Sources/MorphoKit/Application`: use-case orchestration and routing
- `Sources/MorphoKit/Infrastructure`: AX, controlled paste, cloud translation, hotkey, notifications, persistence
- `Sources/MorphoApp`: menu bar UI and settings

## Development

```bash
swift test
swift run MorphoApp
```

## Packaging (macOS App Bundle)

Use the reusable packaging script:

```bash
./scripts/package-macos-app.sh --clean
```

Output artifacts:

- `dist/Morpho.app`
- `dist/Morpho.app.zip`

Useful options:

```bash
# custom output directory
./scripts/package-macos-app.sh --output-dir dist

# sign with a stable certificate (recommended)
./scripts/package-macos-app.sh --sign-identity "Apple Development: Your Name (TEAMID)"

# inspect available signing identities
security find-identity -v -p codesigning
```

Notes:

- For stable Accessibility/TCC identity across upgrades, use `--sign-identity` with the same certificate each build.
- Default ad-hoc signing is convenient for local testing, but macOS may treat each rebuild as a new app identity.
