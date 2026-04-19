@README.md

# QuickIcons — SwiftUI Icon Composer (macOS)

## Project Map

```
QuickIcons/                        Main macOS app (SwiftUI, AppKit)
├── QuickIconsApp.swift            App entry point
├── ExportableIcon.swift           Enum: icon names, directory names, view factory
├── IconExportService.swift        Renders SwiftUI views to AppIcon.appiconset bundles
└── Views/
    ├── ContentView.swift          Root view
    ├── IconExportView.swift       Legacy export UI (being superseded by EditorView)
    └── Icons/
        ├── KindleExporterIcon.swift
        └── ScrapesBookIconView.swift

QuickIconsTests/                   Unit and integration tests (Swift Testing)
tasks/
├── backlog/                       Planned, not started
├── in-progress/                   Currently being worked on
└── done/                          Completed and merged
```

## Build & Test

```bash
# Build
xcodebuild -project QuickIcons.xcodeproj -scheme QuickIcons \
  -destination 'platform=macOS' -configuration Debug build

# Run unit tests
xcodebuild test -project QuickIcons.xcodeproj -scheme QuickIconsTests \
  -destination 'platform=macOS'

# With xcbeautify
xcodebuild test -project QuickIcons.xcodeproj -scheme QuickIconsTests \
  -destination 'platform=macOS' | xcbeautify
```

## Tech Stack

- **Language:** Swift 6 (`SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`)
- **UI:** SwiftUI (macOS 26.4+), AppKit where needed (NSOpenPanel, STTextView bridge)
- **Build:** Xcode 26, Swift Package Manager
- **Testing:** Swift Testing framework (`@Test`, `#expect`)
- **Dependencies (planned):** STTextView, Plugin-Neon, Plugin-Annotations, SourceKittenFramework

## SwiftUI Skills

Always use these skills when working on SwiftUI code:

- `swiftui-pro` — SwiftUI view design, layout correctness, macOS-specific patterns
- `swift-concurrency-pro` — async/await, Task, Actor, @MainActor correctness
- `/simplify` — after implementing, review code quality and reduce complexity
- `/security-review` — before committing changes that handle user input, file I/O, or subprocess execution

# Multi-agent Work Environment

## How It Works

1. The user discusses the plan and confirms direction
2. The lead agent decomposes work into tasks (files in `tasks/backlog/`)
3. The lead spawns worker agents via the `Agent` tool to execute tasks in parallel
4. Workers build code, write tests, and open pull requests from worktrees
5. Reviewer agents review PRs, post feedback, and keep quality high
6. The lead coordinates, merges PRs, and moves task files through backlog → in-progress → done

## Lead Agent Behavior

1. **Read** `README.md` and other top-level docs
2. **Fetch** — always run `git fetch && git pull --ff` before checking task or branch status
3. **Create tasks** as markdown files in `tasks/backlog/` with clear objectives, acceptance criteria, and `dependencies` frontmatter
4. **Spawn workers** via the `Agent` tool — pass the task file path and full context in the prompt
5. **Track state** — move task files between directories as status changes:
   - Worker starts: `mv tasks/backlog/<task>.md tasks/in-progress/`
   - PR merged: `mv tasks/in-progress/<task>.md tasks/done/`
6. **Assign reviews** — once a worker opens a PR, assign a reviewer agent
7. **Merge** — after a clean review, merge the PR and pull `--ff` on main

## Worker Agent Instructions

Each worker MUST:

1. Read their assigned task file for full requirements
2. Create a git worktree — **never work in the main checkout**:
   ```bash
   git fetch origin && git pull --ff
   git worktree add ../worktrees/quickicons-task-N -b task-N-description
   cd ../worktrees/quickicons-task-N
   ```
3. Read existing code before writing — understand the current state
4. Implement the task with tests
5. Verify before committing:
   - `xcodebuild -project QuickIcons.xcodeproj -scheme QuickIcons -destination 'platform=macOS' build` — must build cleanly with **zero warnings**
   - `xcodebuild test -project QuickIcons.xcodeproj -scheme QuickIconsTests -destination 'platform=macOS'` — all tests pass
6. Commit: `[task-N] description`
7. Push and open a PR:
   ```bash
   git push -u origin task-N-description
   gh pr create --title "feat/chore/fix [task-N] description" --body "..."
   ```
8. Update the task file with PR URL, then wait for lead to assign a reviewer
9. Address all review feedback, push fixes
10. After lead confirms merge, clean up worktree:
    ```bash
    cd ~/src/natikgadzhi/QuickIcons
    git worktree remove ../worktrees/quickicons-task-N
    ```

## Reviewer Agent Instructions

1. Check out PR branch in a worktree:
   ```bash
   git worktree add ../worktrees/quickicons-review-N origin/task-N-description
   ```
2. Verify it rebases cleanly on latest `main`
3. Run quality checks (build + test, zero warnings)
4. Verify acceptance criteria from the task file are all met
5. Run `/simplify` and `/security-review` skills
6. Post review via `gh pr review` — approve, request changes, or comment
7. Clean up worktree after review

## Git Conventions

- Main checkout stays on `main` — workers always use worktrees
- `git pull --ff` after every merge
- Every code change goes through a PR — no direct commits to `main`
- One logical change per commit
- Workers `git pull --rebase` before pushing

## Task File Format

```markdown
---
dependencies: [01-task-name, 02-other-task]
status: backlog
---

# Task Title

## Objective
One paragraph describing what this task produces.

## Acceptance Criteria
- [ ] Specific, verifiable items the user can check

## Notes
Implementation guidance, file paths, design decisions.
```

## Important Rules

- **Always fetch before checking task status** — workers may have merged PRs not yet on your local main
- **Always read before writing** — understand existing code before changing it
- **Zero warnings** — fix all Swift compiler warnings before committing
- **Tests for everything** — use Swift Testing (`@Test`, `#expect`). Integration tests over unit tests where possible
- **Small, focused tasks** — each task completable in one agent session
- **No premature abstraction** — build what the task needs, nothing more
- **SwiftUI skills always** — use `swiftui-pro` when writing or reviewing SwiftUI views
