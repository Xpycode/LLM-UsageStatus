# LLM-UsageStatus

## Quick Start

```bash
# Project does not exist yet; commands below are the target shape once 01_Project/ is scaffolded.
cd 01_Project
xcodegen generate
xcodebuild -scheme LLM-UsageStatus -configuration Debug -destination 'platform=macOS' build
```

## Tech Stack

- Swift / SwiftUI — macOS 15 or newer baseline
- Architecture: provider protocol + per-provider services, HUD panel via NSPanel (following CodexUsageStatus)
- Persistence: display preferences only (UserDefaults); no credentials or usage history stored

## Project Structure

```
01_Project/         # Xcode sources once implementation starts
02_Design/          # Icon design sources and exports
03_Screenshots/     # Promotional screenshots
04_Exports/         # Built apps (gitignored)
docs/               # Directions documentation
specs/              # Feature specifications
```

## Rules

### Threading
- ViewModels: Always `@MainActor`
- Services: Always `actor`
- Never access shared state from multiple threads without synchronization

### Error Handling
- Never use `try?` to swallow errors
- A failed provider refresh retains prior values with an update-failed message (CodexUsageStatus pattern)

### State Management
- Use `@Observable` for view models
- Reassign parent when mutating nested structs

### Security
- CLI credentials are read in memory only and never logged or persisted
- Estimates are always labeled as estimates

## Critical Rules (Learned the Hard Way)

- Provider asymmetry is real: Codex shows authoritative allowance; Claude and Vibe show
  locally aggregated usage. Never disguise an estimate as an authoritative value.

## Known Issues

- None yet.

## Current Focus

- Spec created; resolve open questions, then `/make-plan`. See `docs/PROJECT_STATE.md`.
