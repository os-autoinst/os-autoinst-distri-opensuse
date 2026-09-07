## General behavior

- Language Standard: Use Plain English by default for all pull requests, commit messages, etc.
- Technical Documentation: Use Simplified Technical English exclusively when authoring technical documentation, code comments, or architecture specs intended for technical audiences.

## Contributing to this project

- Entry Point: You SHOULD read `README.md`. It contains environment/test variables, declarative schedule details, and project usage patterns.
- Contribution Mandate: You MUST follow `CONTRIBUTING.md` to contribute properly.
- Areas and teams: This is a large repository that spans multiple teams with varying contribution styles, `CONTRIBUTING.md` can point to area-specific guidelines. You MUST identify those areas and follow their guidelines, if they are not present in the areas section of the guide, assume global rules apply. [CODEOWNERS](.github/CODEOWNERS) can help clarifying areas and teams behind them.
  - When guidelines conflict, `CONTRIBUTING.md` takes precedence over `CODEOWNERS` and individual area guidelines, when this happens you MUST inform the user and ask for guidance.
- LLM Attribution Standard:
  - Any work produced with LLM tool assistance MUST include an `Assisted-by:` trailer in the commit message metadata (e.g., `Assisted-by: Qwen3-4B`). Include one line per model involved.
  - Agents MUST NOT add `Signed-off-by:` or `Co-authored-by:` trailers, these are strictly reserved for human contributors.
