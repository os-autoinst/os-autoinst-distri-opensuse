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
    # Install python311-virtualenv
    if (zypper_call("se -x python311-pipx", exitcode => [0, 104]) == 104) {
        die("python311-pipx doesn't exist");
    }
    zypper_call("in python311-pipx");
    # create a virtual environment named myenv using virtualenv with Python 3.11 and activate it
    assert_script_run("pipx run --python=python3.11 virtualenv myenv");
    assert_script_run("source myenv/bin/activate");
    # Install build tools and build, install the package locally
    assert_script_run("pip install setuptools wheel");
    assert_script_run("python setup.py sdist bdist_wheel");
    validate_script_output("pip install dist/user_package_setuptools-1.0-py3-none-any.whl", sub { m/Successfully installed/ });
    # Verify the installed package
    validate_script_output('pip list', sub { m/user_package_setuptools/ });
    assert_script_run("python3.11 sample_test_module/test_module.py");
}

sub post_run_hook {
    script_run("deactivate");
    zypper_call('rm python311-pipx', exitcode => [0, 104]);
    zypper_call('rm python311-base', exitcode => [0, 104]);
}

sub post_fail_hook {
    script_run("deactivate");
    zypper_call('rm python311-Django', exitcode => [0, 104]);
    zypper_call('rm python311-base', exitcode => [0, 104]);
}

1;
