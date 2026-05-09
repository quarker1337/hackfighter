# Repo-local Hermes Skills

This directory contains project knowledge for future Hermes agents working on HACKFIGHTER 2.

Skills:

- `godot-web-game-release/` — reusable Godot 4 Web export, docs, licensing, screenshot, and GitHub Pages publishing workflow. This is intentionally generic and should be useful for other Godot Web game repos.
- `hackfighter2-repo-guide/` — HACKFIGHTER 2-specific orientation: repo layout, build commands, gameplay architecture, UI identity, controls, and verification checklist.

How to use:

1. Start Hermes from the repository root.
2. Ask the agent to read the relevant `hermes/skills/.../SKILL.md` before working, or install/copy the skill into your Hermes skills directory if you want it available globally.

These files avoid local machine paths, private ports, and session-specific artifact runner state so they are safe to keep in the repository.
