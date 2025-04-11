# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python311-pipx
# Summary: testsuite python3-pipx
# - verify the systems python3-pipx
# - creating and installing source distribution package for a python
# in the form of wheel file
# - verify the available python3-pipx with creation of package locally.
# - install also the package via pipx
# Maintainer: QE Core <qe-core@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils;
use python_version_utils;
use utils "zypper_call";
use feature qw(signatures);
no warnings qw(experimental::signatures);

sub run {
    select_serial_terminal;
    # Import the project directory for creating a source distribution package.
    assert_script_run('curl -L -s ' . data_url('python/python3-pipx') . ' | cpio --make-directories --extract && cd data');
    # Verify the system's python3 version
    my $system_python_version = get_system_python_version();
    record_info("System python version", "$system_python_version");
    # Run the package creation and install test for system python
    run_tests($system_python_version);
    # Test all available new python3 versions in SLEs if any
    if (is_sle() || is_leap('>15.5')) { run_tests($_) foreach (get_available_python_versions()); }
}

sub run_tests ($python3_spec_release) {
    record_info("$python3_spec_release");
    # Install pipx and wheel
    if ((zypper_call("se -x $python3_spec_release-pipx", exitcode => [0, 104]) == 104) or (zypper_call("se -x $python3_spec_release-wheel", exitcode => [0, 104]) == 104)) {
        record_info("Skip!", "either $python3_spec_release-pipx or $python3_spec_release-wheel doesn't exist");
        return;
    }
    zypper_call("in $python3_spec_release-pipx $python3_spec_release-setuptools $python3_spec_release-wheel");
    my $python_binary = get_python3_binary($python3_spec_release);
    my $version_number = (split("python", $python_binary))[1];
    script_run("$python_binary setup.py bdist_wheel");
    assert_script_run("$python_binary -mpipx install dist/package-0.1-py3-none-any.whl");
    script_run("pipx list");
    assert_script_run("export PATH=\$PATH:~/.local/bin");
    validate_script_output("hello-world", sub { m/Hello world from package!/ });
    validate_script_output("pipx uninstall package", sub { m/uninstalled package!/ });
    validate_script_output("pipx list", sub { m/nothing has been installed with pipx/ });
}

sub cleanup {
    if (is_sle() || is_leap('>15.5')) {
        remove_installed_pythons();
    }
    assert_script_run("cd ..");
    script_run("rm -r data");
}

sub post_run_hook {
    cleanup();
}

sub post_fail_hook {
    cleanup();
}

1;
