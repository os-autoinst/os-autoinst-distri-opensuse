<!-- SPDX-License-Identifier: FSFAP -->

# Review evidence and limits

## Sample

Research date: 2026-09-21. Expanded merge window: 2026-05-21 through
2026-09-21, inclusive. The public GitHub searches returned 989 merged PRs:
221 from May 21 through June 20, 71 from June 21 through June 30, 266 in July,
252 in August, and 179 from September 1 through September 21.

The search used `repo:os-autoinst/os-autoinst-distri-opensuse is:pr is:merged`
with `merged:START..END` for each interval, sorted by comment count. Thirty
candidates were retrieved per interval for the original June 21 through
September 21 window. Sixteen PRs were selected across
virtualization, kernel/storage, containers, public cloud, SAP/HA, shared
helpers, and repository instructions. A recent closed-PR list and recent
inline comments supplied the additional September candidate #26752.

For those original PRs, the API returned 245 inline comments, 117 conversation comments,
and 268 review records, including empty approvals and bot records. Each
endpoint returned fewer than its 100-record page limit. These counts describe
retrieved records, not independent maintainer recommendations. Read the thread
responses when interpreting a recommendation. Reviews can predate the merge
window; post-merge comments available on the research date are included.

The expansion adds 16 PRs, for 32 distinct PRs in total. Eight additions merged
from May 21 through June 20; eight add coverage of later security, desktop,
installer, CI, and test-replacement changes. The early interval search returned
60 candidates. Separate searches across the full window added `security`,
`agama`, and `desktop` as search terms, each with a limit of 30 results, sorted
by comment count. The searches overlap and match discussion text as well as
titles; they are not a classification of changed files.

After the unauthenticated API limit was reached, the additional PRs were read
from public GitHub pages. The collection included 126 review fragments and
67 deferred threads, including resolved threads. It yielded 241 distinct,
nonempty comment bodies: 158 inline comments, 66 conversation comments, and
17 review summaries. All 158 comment IDs listed as hidden in the collected
pages were retrieved. These counts exclude PR descriptions and empty reviews;
they are not directly comparable to the original API review-record count.

The selected PRs and source links are listed below. Relevant merged code was
also checked for the snpguest version probe, SCAP helper use, PAM version
comparison, and rollback revert. This research does not rerun historic openQA
jobs or independently validate every author claim. Sparse discussions are
retained as sample limits, not used to invent additional review rules.

This is a purposive sample, biased toward discussion. It is not a statistical
survey or a complete review of 989 PRs. Security and desktop coverage is broader
but still too small to establish complete area-specific rules. Merged status does not mean
every suggestion was accepted or that the merged code was correct.

## Findings used in the draft

| PR and merge date | Evidence and bounded lesson |
| --- | --- |
| #25847, June 23 | [Stderr discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25847#discussion_r3428272746) and replies distinguish warning output from errors. Inspect command status and result reporting separately. |
| #25872, June 24 | [Guest version discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25872#discussion_r3464206041) identifies guest metadata and OS release helpers. Some refinement was deferred to unblock tests; do not treat every suggestion as a merge requirement. |
| #25864, June 26 | [Resource stop discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25864#discussion_r3461297240) questions force flags after stopping resources; the author removed them. Check actual preconditions before adding force or duplicate setup. |
| #25909, June 26 | [Documentation discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25909#discussion_r3471847798) moves setting detail to `variables.md`. The separate progress-output discussion was contested; it does not justify a rule to remove progress output. |
| #25471, July 6 | [SSH review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25471#pullrequestreview-4321218810) separates connection readiness from system readiness. The thread debates API shape; preserve caller semantics rather than imposing one preferred function name. |
| #26017, July 9 | [Timeout configurability](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26017#discussion_r3535933470) and [test follow-up](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26017#discussion_r3544494259) support checking timeout arguments and exception propagation. Human replies rejected some bot suggestions; do not automatically wrap exceptions or overwrite parameters. |
| #25931, July 9 | [Test scope](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25931#discussion_r3503676957) and [mocked time](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25931#discussion_r3504291255) support behavior-focused unit tests with controlled waits. These are scoped recommendations, not a ban on testing private helpers. |
| #26015, July 22 | [Pipeline failure](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26015#discussion_r3535965341) demonstrates a hidden failure before `tail`; the author accepted the correction. The larger throttling design was later removed, so it is not an established library contract. |
| #26332, August 17 | [Console reply](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26332#discussion_r3793281434) explains why two named SSH sessions are required. The reviewer accepted the distinction. Avoid deduplication based only on a common device path. |
| #26342, August 19 | [Cleanup review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26342#discussion_r3749369656) covers failure paths. [Coverage discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26342#discussion_r3803554928) explains how a missing component can hide a product regression behind a skip or soft failure. |
| #26347, August 21 | [Dependency reply](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26347#discussion_r3773641316) explains the required NFSv4 decoding capability. A smaller dependency is not a sufficient replacement if it cannot perform the assertion. |
| #26447, August 27 | [Unit-test review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26447#discussion_r3841254225) rejects ordinary diagnostic text as the assertion for this behavior. Test the failure contract instead. |
| #26597, September 8 | [Repeated ownership typo](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26597#discussion_r3949744154) remained after a claimed fix. Recheck the latest code rather than relying on a resolved comment. Current `AGENTS.md` defines the attribution rules. |
| #26486, September 11 | [Verification question](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26486#discussion_r3899930425) asks whether jobs executed the helper. Later [regression and revert discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26486#issuecomment-5631098926) shows why merged status and many runs do not establish complete coverage. |
| #26642, September 15 | [Library-test review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26642#pullrequestreview-5169045132) asks for unit tests. [CI discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26642#issuecomment-5679645657) has conflicting observations, followed by an author report of reruns; verify job status rather than asserting that this PR merged with failing tests. |
| #26752, September 21 | [Language branch](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26752#discussion_r4059799886) and [skip cleanup](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26752#discussion_r4059846032) comments led to author changes. The package-installation concern was deferred as pre-existing work. |

## Additional four-month sample

These additions strengthen existing checks and add checks for version probes,
rollback requirements, transactional setup, and replacement-test coverage.
Rows with limited review feedback do not establish new policy.

| PR and merge date | Evidence and bounded lesson |
| --- | --- |
| #25576, May 21 | [Version probe review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25576#discussion_r3264705171) asks for failure when the required tool version cannot be read. [Verification discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25576#issuecomment-4494736339) distinguishes old and new argument order from host-product labels. The merged probe uses `script_output` without the old failure fallback, but its parser still selects the old CLI for unrecognized output. The review request is not proof of strict parsing. |
| #25527, May 21 | [Registration conditions](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25527#discussion_r3217651790) separates flavor, registration, and product conditions. The author revised the code. Use explicit conditions to check behavior; the later naming debate does not establish a universal naming rule. |
| #25541, May 26 | [Crypto result review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25541#pullrequestreview-4270348285) questions treating every ML-DSA failure as optional when only the FIPS case is expected. [Cleanup feedback](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25541#discussion_r3224736433) asks for removal of build artifacts. These support the existing expected-result and cleanup checks; the review alone does not define current algorithm support. |
| #24986, June 1 | [Aeon verification discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/24986#issuecomment-4563166209) traces a clone failure to the server checkout layout. A later author reply provides a run. Distinguish infrastructure failures before test execution from defects in the new test; do not generalize the server-side repair into a test requirement. |
| #25441, June 4 | [Transactional installation feedback](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25441#discussion_r3346260540) proposes package-helper options for applying the installation. The PR also changes writable NFS paths. Check when installed packages become available and where tests write, without assuming every product has the filesystem layout discussed here. |
| #25718, June 15 | [Staged rollout discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25718#issuecomment-4659652948) separates adding an Agama profile block from enabling it in production. The author creates a follow-up PR. Check schedule and job-group dependencies; a merged building block is not proof that production coverage is active. |
| #25738, June 16 | [Input-test motivation](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25738#issuecomment-4645914009) identifies unresponsive mouse and keyboard input in VMware guests. A possible Puppeteer replacement was deferred. Preserve the input behavior being tested before choosing a different automation API. |
| #25816, June 18 | [Package-helper review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25816#discussion_r3411576699) leads to reuse of `install_package`. Python formatting requirements were also discussed; the merged change adds `get_current_python_version` to the shared Python module. Do not interpret the thread as proof that every proposed helper already existed or that every suggestion was implemented literally. |
| #25276, July 7 | [CI permissions PR](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/25276) has an explicit permissions change but little substantive review text beyond a rebase request. Retained as a CI sample; it does not support a new CI review rule. |
| #26144, July 22 | [Desktop verification reply](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26144#issuecomment-5044594281) explains the author's SLE 15-SP7 scope after a request for more versions. Use actual affected schedules to select runs. This historical reply is not a current product-support matrix. |
| #26223, July 30 | [Rollback objection](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26223#issuecomment-5131275134) explains why backend-dependent rollback flags obscure module requirements. The [author response](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26223#issuecomment-5140424398) agrees to revert and examine cleanup needs. Determine the required restored state before changing isolation behavior. |
| #26247, July 31 | [Revert](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26247) removes the helper and conditional flags introduced by #26223. The merged diff confirms the reversal. Treat the two PRs as one outcome, not two independent recommendations. |
| #26313, August 6 | [X11 login fix](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26313) describes relogin and boot-from-HDD paths without an initial desktop login. The public discussion has little substantive reviewer feedback. It illustrates the existing lifecycle check, but does not establish a new desktop rule. |
| #26320, August 10 | [Version comparison thread](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26320#discussion_r3734398449) finds that older `zypper vcmp` versions do not return the assumed status. A passing updated SLE run did not settle original-package compatibility. The author switches to terse output; the merged helper confirms it. A suggestion to call a Perl helper from shell was withdrawn. |
| #26336, August 19 | [Setup ordering](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26336#discussion_r3758100208) moves profile import before Agama. [Behavior discussion](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26336#discussion_r3758079477) distinguishes a displayed message from actual remote-access restriction; the author explains that the serial message is also needed for synchronization. Keep both purposes distinct. |
| #26713, September 17 | [Coverage question](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26713#issuecomment-5697194208) asks whether the sudo replacement preserves prior tests. [Cloud review](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26713#issuecomment-5698103620) identifies default user configuration as a separate assertion. [VR correction](https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/26713#issuecomment-5697813552) confirms some supplied runs did not execute sudo. The final PR description leaves the public-cloud path unchanged. |

## Authority and design

Project rules come from the current `CONTRIBUTING.md`, `AGENTS.md`, and applicable
area documentation. The PR discussions supply questions to investigate, not new
mandatory policy. Historical examples that differ from current guidance do not
override it. Naming preferences, disputed suggestions, and bot findings require
independent verification.

The local `ltp-agent` project inspired the structure: one review entry point,
references selected by scope, and a final check for false positives. This draft
uses original OSADO instructions. It does not copy the LTP requirement for a
branch ahead of master, email output files, or LTP-specific rules.

Keep one review skill until an area has enough distinct checks to justify a
separate skill. Add evidence from further reviews as needed. Verify the final
code and thread outcome before promoting a recurring suggestion into guidance.
