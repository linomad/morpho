# Morpho

System-level input translation for macOS (MVP).

中文文档: [README.zh-CN.md](README.zh-CN.md)

## Slogan

**Native-First, Seamless Input Translation**

## Why Morpho

Morpho started from one concrete problem: in chat, article writing, and other typing-heavy workflows, users need to translate what they are currently typing into a target language immediately, without leaving the current input field.

It keeps translation inside the writing flow, so language switching feels instant instead of disruptive.

## Design Principles

- Focus and simplicity: do one thing extremely well.
- AX First: prefer Accessibility direct read/write to minimize clipboard usage.
- Clear layering: keep business policy and platform implementation decoupled.
- Incremental extension: SiliconFlow first, multi-provider ready, no premature complexity.

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
