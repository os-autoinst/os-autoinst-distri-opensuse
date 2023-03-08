os-autoinst/openQA tests for openSUSE and SUSE Linux Enterprise [![Build Status](https://github.com/os-autoinst/os-autoinst-distri-opensuse/workflows/ci/badge.svg)](https://github.com/os-autoinst/os-autoinst-distri-opensuse/actions)


- Gnome on Tumbleweed: [![Gnome on Tumbleweed](https://openqa.opensuse.org/tests/latest/badge?arch=x86_64&distri=opensuse&flavor=DVD&machine=64bit&test=gnome&version=Tumbleweed)](https://openqa.opensuse.org/tests/latest?arch=x86_64&distri=opensuse&flavor=DVD&machine=64bit&test=gnome&version=Tumbleweed)
- KDE on Tumbleweed: [![KDE on Tumbleweed](https://openqa.opensuse.org/tests/latest/badge?arch=x86_64&distri=opensuse&flavor=DVD&machine=64bit&test=kde&version=Tumbleweed)](https://openqa.opensuse.org/tests/latest?arch=x86_64&distri=opensuse&flavor=DVD&machine=64bit&test=kde&version=Tumbleweed)

=================================================================================================================================================================================================================================
os-autoinst-distri-opensuse is repo which contains tests, which are executed
by openQA for openSUSE and SLE distributions.

Needles for openSUSE distributions are located in [os-autoinst-needles-opensuse](https://github.com/os-autoinst/os-autoinst-needles-opensuse)

Some documentation from the test library is published at https://os-autoinst.github.io/os-autoinst-distri-opensuse/, however this is still WIP

For more details see http://os-autoinst.github.io/openQA/

Please, find test variables description [here](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/variables.md)

For using new mechanism to schedule modules, check [declarative schedule docs](declarative-schedule-doc.md)

In case of adding new test for Installation, please use approach
described in the
[documentation for UI Test Automation Framework](ui-framework-documentation.md)

## How to contribute
Please, refer to [Contributing Guide](https://github.com/os-autoinst/os-autoinst-distri-opensuse/blob/master/CONTRIBUTING.md).

## License

Most files are licensed under a minimal copyleft conforming to the [FSF All
Permissive License](https://spdx.org/licenses/FSFAP.html), but some more
complex tests are licensed under the  GPL. So please check the license within
the files.
