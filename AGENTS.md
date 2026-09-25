## General behavior

- Language Standard: Use Plain English by default for all pull requests, commit messages, etc.
- Technical Documentation: Use Simplified Technical English exclusively when authoring technical documentation, code comments, or architecture specs intended for technical audiences.

## Contributing to this project

- Entry Point: You SHOULD read `README.md`. It contains environment/test variables, declarative schedule details, and project usage patterns.
- Contribution Mandate: You MUST follow `CONTRIBUTING.md` to contribute properly.
- Areas and teams: This is a large repository that spans multiple teams with varying contribution styles. When working on a specific area, you MUST read the "Areas and scope of work" section in `CONTRIBUTING.md` to check for and follow its specific conventions (such as `docs/KERNEL_README.md` for kernel code). [CODEOWNERS](.github/CODEOWNERS) can help clarifying areas and teams behind them.
  - When guidelines conflict, `CONTRIBUTING.md` takes precedence over `CODEOWNERS` and individual area guidelines, when this happens you MUST inform the user and ask for guidance.
- LLM Attribution Standard:
  - Any work produced with LLM tool assistance MUST include an `Assisted-by:` trailer in the commit message metadata (e.g., `Assisted-by: Qwen3-4B`). Include one line per model involved.
  - Agents MUST NOT add `Signed-off-by:` or `Co-authored-by:` trailers, these are strictly reserved for human contributors.
- Atomic Commits: Agents MUST NOT bundle unrelated changes into a single commit. If a change touches a file or component unrelated to the main change, split it into its own atomic commit, per `CONTRIBUTING.md`.

## Review skills

For a requested patch or pull request review, read
[osado-review](skills/osado-review/SKILL.md). It provides review steps and
references for test behavior and verification. Load only the references that
apply to the change. `CONTRIBUTING.md` and the applicable area guidelines remain
the source of project rules.
