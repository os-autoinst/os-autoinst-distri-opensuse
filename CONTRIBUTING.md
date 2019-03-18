## How to contribute

Fork the repository and make some changes.
Once you're done with your changes send a pull request. You have to agree to
the license. Thanks!
If you have questions, visit us on irc.freenode.net in #opensuse-factory or
ask on our mailing list opensuse-factory@opensuse.org

### How to get started

It can be beneficial to learn how an openQA job is executed. To setup your own
openQA instance, please refer to the documentation of the [openQA project](https://github.com/os-autoinst/openQA).

Please, find up-to-date documentation references on the official [openQA project web-page](http://open.qa/documentation/).

If you are looking for a task to start with, check out the [openQA Tests](https://progress.opensuse.org/projects/openqatests/issues/)
Redmine project. Look for tickets with [easy] or [easy-hack] tags.

### Reporting an issue

As mentioned above, we use Redmine as issue tracking tool. In case you found some
problem with the tests, please do not hesitate report [a new issue](https://progress.opensuse.org/projects/openqatests/issues/new)
Please, refer to the [template](https://progress.opensuse.org/projects/openqav3/wiki/#Defects).

If in doubt, contact us, we will be happy to support you.

### Coding style

The project follows the rules of the parent project
[os-autoinst](https://github.com/os-autoinst/os-autoinst#how-to-contribute).
and additionally the following rules:

* Take
  [example boot.pm](https://github.com/os-autoinst/os-autoinst-distri-example/blob/master/tests/boot.pm)
  as a template for new files
* The test code should use simple perl statements, not overly hacky
  approaches, to encourage contributions by newcomers and test writers which
  are not programmers or perl experts
* Update the copyright information with the current year and *SUSE LLC* as the
  legal entity. For new files make sure to only state the year during which
  the code was written.
* Use `my ($self) = @_;` for parameter parsing in methods when accessing the
  `$self` object. Do not parse any parameter if you do not need any.
* [DRY](https://en.wikipedia.org/wiki/Don't_repeat_yourself)
* Every pull request is tested by the travis CI by calling the equivalent of
  `make test` on the tests. It is recommended to call `tools/tidy` or
  `make tidy` locally to fix the style of your changes before providing a
  pull request. Call `make test` to conduct all tests.


Also see the
[DoD/DoR](https://progress.opensuse.org/projects/openqatests/wiki/Wiki#Definition-of-DONEREADY)
as a helpful (but not mandatory) guideline for new contributions.
