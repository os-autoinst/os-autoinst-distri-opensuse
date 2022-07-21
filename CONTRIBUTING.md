## How to contribute

Fork the repository and make some changes.
Once you're done with your changes send a pull request. You have to agree to
the license. Thanks!
If you have questions, visit us in #opensuse-factory on irc.libera.chat,
[Discord](https://discord.gg/opensuse), [Matrix](https://matrix.to/#/#space:opensuse.org) or
ask on our mailing list opensuse-factory@opensuse.org

### How to get started

It can be beneficial to learn how an openQA job is executed. To setup your own
openQA instance, please refer to the documentation of the [openQA project](https://github.com/os-autoinst/openQA).

Please, find up-to-date documentation references on the official [openQA project web-page](https://open.qa/documentation/).

If you are looking for a task to start with, check out the [openQA Tests](https://progress.opensuse.org/projects/openqatests/issues/)
Redmine project. Look for tickets with [easy] or [easy-hack] tags.

## How to get this repository working

Upon setting up a new openQA instance, it's also necessary to install some aditional dependencies that are inherent to this repository,
for which there are two ways:

* In case you're using cpanm (with or without local::lib, or others), from within the working copy: call `cpanm -n --mirror http://no.where/ --installdeps . `
* In case you're using openSUSE: `zypper in os-autoinst-distri-opensuse-deps perl-JSON-Validator gnu_parallel`
* For linting YAML, you need the openSUSE package `python3-yamllint` or install `yamllint` via pip

#### Relevant documentation

* All openQA documentation in a single [html page](https://open.qa/docs/)
* openQA [testapi](http://open.qa/api/testapi/) documentation
* (wip) Available test library documentation http://os-autoinst.github.io/openQA/

### Reporting an issue

As mentioned above, we use Redmine as issue tracking tool. In case you found some
problem with the tests, please do not hesitate report [a new issue](https://progress.opensuse.org/projects/openqatests/issues/new)
Please, refer to the [template](https://progress.opensuse.org/projects/openqav3/wiki/#Defects).

If in doubt, contact us, we will be happy to support you.

### Coding style

The project follows the rules of the parent project
[os-autoinst](https://github.com/os-autoinst/os-autoinst#how-to-contribute).
and additionally the following rules:

* Use a "SPDX-License-Identifier" to declare the used license. Do not copy
  verbatim license texts into new files
* Prefer to not update the copyright years in file headers as this is not
  required. In new files the year can be skipped completely, e.g. just
  "Copyright SUSE LLC". See https://progress.opensuse.org/issues/98616 for
  details.
* Take [example boot.pm](https://github.com/os-autoinst/os-autoinst-distri-example/blob/master/tests/boot.pm)
  as a template for new files
* The test code should use simple perl statements, not overly hacky
  approaches, to encourage contributions by newcomers and test writers which
  are not programmers or perl experts
* Use `my ($self) = @_;` for parameter parsing in methods when accessing the
  `$self` object. Do not parse any parameter if you do not need any.
* [DRY](https://en.wikipedia.org/wiki/Don't_repeat_yourself)
* Use defined architecture and backend functions defined in
  'lib/Utils/Architecture.pm' and 'lib/Utils/Backends.pm' for checking specific 
  ARCH and BACKEND types instead of calling the function calls check_var(). 
  If they don't exist, add them.
* Avoid `sleep()`: Do not use `sleep()` or simulate a sleep-like
  functionality. This introduces the risk of either unnecessarily wasting time
  or just shifting race conditions and making them even harder to investigate.
  You *can* use sleep but there are only very limited cases where is the best
  solution (e.g. yield threads in low-level system code). Here you have the
  classical problem in software design of
  [Synchronization](https://en.wikipedia.org/wiki/Synchronization_(computer_science)).
  `sleep()` should not be used in place of proper synchronization methods.
  https://blogs.msmvps.com/peterritchie/2007/04/26/thread-sleep-is-a-sign-of-a-poorly-designed-program/
  is one of multiple references that explains this: "The original problem is
  likely a timing/synchronization issue, ignoring it by hiding it with
  Thread.Sleep is only going to delay the problem and make it occur in random,
  hard to reproduce ways." And if the problem does not occur at least time is
  wasted.
  We are waiting because some condition changes some time ... keyword(s) is/are
  *some time*. It is important to know the exact condition that the code should
  wait for and check for that instead of delaying program execution for an
  arbitrary amount of time. For openQA tests in general just try to do what you
  as a human user would also do. You would not look on your watch waiting for
  exactly 100s before you look at the screen again, right? :)
* Avoid `is_tumbleweed()`: Our tests should always consider openSUSE Tumbleweed
  as the default product without a version. That means any differing behaviour
  should have an explicit exclude rule for the "older products" and potentially
  an explanation why the behaviour should differ. You can try to negate the logic
  check. As alternative consider the approach documented in
  [ui-framework-documentation.md](ui-framework-documentation.md)
* Support openSUSE Tumbleweed as primary product: Because of
  [Factory First](https://opensource.suse.com/suse-open-source-policy)
  Tumbleweed is the default test target. So ensure and test that your code
  changes work with a current Tumbleweed snapshot and then add to the
  according schedule for Tumbleweed tests, e.g. in schedule/ or main.pm.
  Exceptions are any special SLE-specific behaviour or packages not in
  Tumbleweed or the case not being relevant otherwise.
* Avoid "dead code": Don't add disabled code as nobody but you will understand
  why this is not active. Better leave it out and keep in your local git
  repository, either in `git stash` or a temporary "WIP"-commit.
* Details in commit messages: The commit message should have enough details,
  e.g. what issue is fixed, why this needs to change, to which versions of which
  product it applies, link to a bug or a feature entry, the choices you made,
  etc. Also see https://commit.style/ or http://chris.beams.io/posts/git-commit/
  as a helpful guide how to write good commit messages. And make code
  reviewers fall in love with you :) https://mtlynch.io/code-review-love/
  Keep in mind that the text in the github pull request description is only
  visible on github, not in the git log which can be considered permanent
  information storage.
* Add comments to the source code if the code is not self-explanatory:
  Comments in the source code should describe the choices made, to answer the
  question "why is the code like this". The git commit message should describe
  "why did we change it".
* Consider "multi-tag `assert_screen` with `match_has_tag`": Please use a
  multi-tag `assert_screen` with `match_has_tag` instead of `check_screen`
  with non-zero timeout to prevent introducing any timing dependant behaviour,
  to save test execution time as well as state more explicitly from the testers
  point of view what are the expected alternatives. For example:

```perl
assert_screen([qw(yast2_console-finished yast2_missing_package)]);
if (match_has_tag('yast2_missing_package')) {
    send_key 'alt-o';  # confirm package installation
    assert_screen 'yast2_console-finished';
}
```

### Preparing a new Pull Request
* All code needs to be tidy, for this use `make prepare` the first time you
  set up your local environment, use `make tidy` before commiting your changes,
  ensure your new code adheres to our coding style or use `make tidy-full` if
  you have already few commits.
* Every pull request is tested by our CI system for different perl versions,
  if something fails, run `make test` (don't forget to `make prepare` if your setup is new)
  but the CI results are available too, in case they need to be investigated further
* Whenever possible, [provide a verification run][1] of a job that runs the code [provided in the pull request][2]

Also see the [DoD/DoR][3] as a helpful (but not mandatory) guideline for new contributions.

[1]: https://open.qa/docs/#_cloning_existing_jobs_openqa_clone_job
[2]: https://open.qa/docs/#_triggering_tests_based_on_an_any_remote_git_refspec_or_open_github_pull_request
[3]: https://progress.opensuse.org/projects/openqatests/wiki/Wiki#Definition-of-DONEREADY


### Handling separate product codebases or versions

This test distribution manages to support older SLE products as well as
openSUSE Tumbleweed to give the widest span. By default test code should keep
support for all currently supported product versions in mind and where
necessary introduce conditional code (e.g. "if/else") to support all relevant
products, variants and versions.

Consider introducing a branch in version control only if a corresponding
product is also handled in the same way. For example an older SLE version
going to LTSS or ELTSS is a good point in time. In general it is likely still
less effort to keep everything in master and just separate with functional
conditions to manage the differences. Otherwise there would need to be a
diligent process of backporting new features, extended test coverage, etc.
