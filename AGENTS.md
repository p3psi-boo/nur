# Agent 指南（本仓库）

## Nix 打包小工具

- 打包前先用 `nh search <query>` 在 nixpkgs 里查一下是否已有相关包；如果已有（满足需求），不要在本仓库继续打包/新增。
- 在写/更新 Nix 包（需要 `fetchFromGitHub`、`fetchgit`、`fetchurl` 等）时，优先用 `nurl` 快速生成/获取 `owner/repo`、`rev`、`hash` 等信息：`https://github.com/nix-community/nurl`。

## nvfetcher（统一维护源码版本）

用 `nvfetcher` 统一维护 `pkgs/` 下包的上游版本与源码信息（配置：`./nvfetcher.toml`，输出：`_sources/generated.{nix,json}`）。

- 更新方式：
  - 修改 `./nvfetcher.toml`
  - 运行 `nvfetcher -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml`
  - 提交更新后的 `_sources/generated.{nix,json}`
- 使用方式：
  - 包的 `default.nix` 引用 `generated.<pkg>.src`、`generated.<pkg>.version` 等字段
  - NUR overlay 会自动把 `generated` 传给同名包（目录名与 `nvfetcher.toml` 的段名一致即可）
- 获取命令：
  - 使用 `nix develop ./nur -c $SHELL`，或 `nix run nixpkgs#nvfetcher -- -o _sources -c ./nvfetcher.toml --keyfile ./keyfile.toml`
- 重要：必须使用 `--keyfile ./keyfile.toml` 参数，否则会因 GitHub API 速率限制导致 403 错误
- 禁止直接修改 `_sources/` 下的文件（`generated.{nix,json}`），这些文件均由 `nvfetcher` 从 `./nvfetcher.toml` 自动生成。如需更新或删除包，请修改 `./nvfetcher.toml` 后重新运行 `nvfetcher` 命令

参考：`https://github.com/berberman/nvfetcher`

---

打包请查看 `nix-package` SKILL

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

## Subagents

- ALWAYS wait for every spawned subagent to reach a terminal status before yielding, acting on partial results, or spawning followups.
  - On Codex, this means calling the `wait` tool with the subagent's thread id (requires `multi_agent_v2`). Do NOT infer completion from elapsed time.
  - On Claude Code / OpenCode, this means awaiting the Task/agent tool result before continuing.
- NEVER cancel or re-spawn a subagent that hasn't finished. If a subagent appears stuck, raise the wait timeout (Codex default 30s, max 1h) before judging it broken.
- Spawn subagents automatically when:
  - Parallelizable work (e.g., install + verify, npm test + typecheck, multiple tasks from plan)
  - Long-running or blocking tasks where a worker can run independently
  - Isolation for risky changes or checks

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->
