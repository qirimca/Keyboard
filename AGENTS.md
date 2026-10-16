# AGENTS.md

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Simulator Rules
- NEVER create new simulators without explicit user permission. Use only existing simulators (`xcrun simctl list devices`).
- You MAY erase/reset an existing simulator, but NEVER create a new one.
- Delete a simulator ONLY if it occupies > 1 GB of disk space. Never delete simulators < 1 GB without user approval.
- Approved simulators for this project: **iPhone 15 Pro** (iOS 27) and **iPad Air 3rd generation** (iOS 26.5).

## Browser Rules
- NEVER use headless mode. Always use a real browser with GUI.
- Chrome DevTools MCP connects to `http://127.0.0.1:9222`. Ensure Chrome is running with `--remote-debugging-port=9222` before using browser tools.
- To launch Chrome with remote debugging: `/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --remote-debugging-port=9222`

## Copilot Rules
- When consulting Microsoft Copilot at `copilot.cloud.microsoft`, always select model **"5.6 Thinking"** if available.
