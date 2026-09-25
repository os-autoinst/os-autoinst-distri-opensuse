---
name: osado-review
description: Review OSADO patches, commit ranges, working tree changes, or GitHub pull requests for test correctness, compatibility, and verification coverage. Use when a review of os-autoinst-distri-opensuse is requested.
---

<!-- SPDX-License-Identifier: FSFAP -->

# OSADO review

Review the requested change. Return findings in the conversation unless the
user requests another output. A review does not authorize edits or publication
of GitHub comments.

## Establish scope and rules

1. Read the repository `AGENTS.md`, `CONTRIBUTING.md`, and `README.md`.
   Map changed paths to the area guidelines listed in `CONTRIBUTING.md`.
   Use `.github/CODEOWNERS` to identify shared code and additional consumers.
   Follow the conflict procedure in `AGENTS.md` if guidelines conflict.
2. Identify the requested base and head. For a PR, use its actual target branch
   and head revision. For a local branch, inspect its upstream and merge base.
   Do not assume every change targets `master`. Include uncommitted changes
   only when they are part of the request. State the reviewed scope.
3. Read the diff, commit messages, and relevant surrounding code. For a series,
   inspect individual commits and the combined result. Check renamed or deleted
   modules for remaining callers, schedules, and data references.
4. When reviewing a PR, read its description, review summaries, inline threads,
   and author responses. Check whether previous findings still apply to the
   current revision. A resolved thread or an author's statement is not proof
   that the code changed.

Repository paths in this skill are relative to the repository root. Reference
links below are relative to this skill directory.

## Select the review checks

- For Perl helpers, test modules, shell commands, or product conditions, read
  [Runtime behavior](references/runtime.md).
- For changed tests, libraries, schedules, variables, or verification claims,
  read [Verification](references/verification.md).
- For SUT provisioning code or proposed extraction of setup helpers from test
  modules, read [Provisioning helpers](references/provisioning.md).
- For the origin and limits of these checks, read
  [Review evidence](references/evidence.md). This is research evidence, not
  additional project policy. Routine reviews do not need to load it.

Apply the current contribution rules for synchronization, architecture and
backend helpers, Tumbleweed support, soft failures, formatting, and commit
messages. Read `docs/KERNEL_README.md` when its scope applies. Do not impose
kernel commit prefixes on other teams. Check LLM attribution only when
assistance is known; do not infer it from writing style.

## Confirm each candidate finding

- Locate the affected line in the reviewed revision. Show a reachable caller,
  schedule, or input and explain the resulting failure or lost coverage.
- Read the helper implementation and base class hooks. Check return values,
  exceptions, defaults, guards, and inherited cleanup before requesting checks.
- Keep architecture, backend, product, host, guest, and console state separate.
  Similar conditions or names do not prove equivalent behavior.
- Check the rest of the series and thread replies. Do not repeat a finding
  that the final change fixes. Separate unrelated pre-existing problems.
- Distinguish a code defect from a documented rule violation, missing
  verification, and an optional design suggestion. For a rule violation, cite
  the rule and show why it applies. A personal preference is not a rule.
- If evidence is missing, state the uncertainty or ask a focused question.
  Do not report an unverified suspicion as a defect. A merged PR, approval,
  bot comment, or passing job alone does not establish correctness.

## Report

### Tone and brevity

- Factual and terse. State each finding in 1-3 sentences: what is wrong,
  why, and the fix. No preamble, no narration of what you are about to do,
  no restating the request.
- Never hedge or pad ("I noticed that...", "It might be worth...",
  "Interesting note..."). State the claim directly.
- Never summarize code that is correct, unaffected files, or the general
  shape of the diff. If something needs no comment, omit it entirely.
- Point at the fix directly (`file:line`, the function or rule name), not
  at the reasoning process used to find it.
- Do not write more than one short paragraph of prose outside the findings
  list and the closing verdict line.

### Structure

Open with the verdict as a one-line headline, before anything else:

`Verdict: Accepted` -- no confirmed findings remain, or
`Verdict: Not accepted` -- one or more confirmed findings remain.

Under `Not accepted`, list what is not ok, ordered by impact. Each entry is
`file:line` -- one-line defect statement, triggering condition,
consequence, and a concise fix direction. Cite the applicable rule for a
policy finding. This list IS the justification for the verdict -- do not
also restate it in prose elsewhere.

Close with compressed lines, not prose paragraphs:

- `Reviewed: <base>..<head>, N commit(s)` -- the exact scope.
- `Checks:` one line naming what was run, only where it bears on a finding
  or its absence.
- `Limits:` one line on genuine verification gaps (unreachable job logs,
  unverifiable external state) -- omit if none.

Keep optional suggestions in their own short subsection, separate from the
"not ok" list, same brevity rules, even under an `Accepted` verdict.
Identify untested paths without implying they are defects.

Do not invent findings to fill a quota. The verdict reflects this local
review only, not merge approval.
