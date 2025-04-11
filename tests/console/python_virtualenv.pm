# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python3-virtualenv
# Summary: testsuite python3-virtualenv
# - Install python311-pipx and with pipx download the latest version of
# a package to a temporary virtual environment, then run the app from it
# - Activate virtual environment
# - Install build tools
# - Setup the package structure and
# - Build the local package and install it
# - Verify the installation
# - Deactivate the virtual environment
# Summary: testsuite python3-virtualenv
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
    # The directory should contain setup.py and a Python module named test_module.py
    assert_script_run('curl -L -s ' . data_url('python/python3-setuptools') . ' | cpio --make-directories --extract && cd data');
    # Verify the system's python3 version
    my $system_python_version = get_system_python_version();
    record_info("System python version", "$system_python_version");
    # Run the package creation and install test for system python
    run_tests($system_python_version);
    # Test all available new python3 versions in SLEs if any
    if (is_sle() || is_leap('>15.5')) { run_tests($_) foreach (get_available_python_versions()); }
}

sub run_tests ($python3_spec_release) {
    if ($python3_spec_release eq 'python39' && check_var('VERSION', '15-SP5')) {
        # python39-pip not availbale on 15sp5  https://progress.opensuse.org/issues/159777
        record_info("Skip python39", 'https://jira.suse.com/browse/PED-8196');
        return;
    }
    record_info("$python3_spec_release");
    # Install python311-virtualenv
    if ((zypper_call("se -x $python3_spec_release-pipx", exitcode => [0, 104]) == 104) or (zypper_call("se -x $python3_spec_release-virtualenv", exitcode => [0, 104]) == 104)) {
        record_info("Skip! either $python3_spec_release-pipx or $python3_spec_release-virtualenv doesn't exist");
        return;
    }
    zypper_call("in $python3_spec_release-pipx $python3_spec_release-virtualenv");
    # create a virtual environment named myenv using virtualenv with Python 3.11 and activate it
    my $python_binary = get_python3_binary($python3_spec_release);
    my $version_number = (split("python", $python_binary))[1];
    assert_script_run("pipx run --python=$python_binary virtualenv myenv");
    assert_script_run("source myenv/bin/activate");
    # Install build tools and build, install the package locally
    assert_script_run("pip$version_number  install setuptools wheel");
    assert_script_run("python$version_number setup.py sdist bdist_wheel");
    validate_script_output("pip$version_number  install dist/user_package_setuptools-1.0-py3-none-any.whl", sub { m/Successfully installed/ });
    # Verify the installed package
    validate_script_output("pip$version_number list", sub { m/user_package_setuptools/ });
    assert_script_run("python$version_number sample_test_module/test_module.py");
    uninstall_package($version_number);
    assert_script_run("deactivate");
}

# Uninstall the installed user_package_setuptools and verify it.
sub uninstall_package ($version_number) {
    assert_script_run("pip$version_number uninstall user_package_setuptools -y");
    my $out = script_output "python$version_number sample_test_module/test_module.py", proceed_on_failure => 1;
    die("pip uninstall failed for the package") if (index($out, "ModuleNotFoundError") == -1);
    assert_script_run("rm -rf dist user_package_setuptools.egg-info");
}

sub cleanup {
    if (is_sle()) {
        remove_installed_pythons();
    }
    assert_script_run("cd ..");
    script_run("rm -r data");
}

sub post_run_hook {
    script_run("deactivate");
    cleanup();
}

sub post_fail_hook {
    script_run("deactivate");
    cleanup();
}

1;
