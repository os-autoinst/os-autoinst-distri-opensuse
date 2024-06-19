# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: python311-pipx
# Summary: testsuite python3-pipx
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
    # Install python311-virtualenv
    if (zypper_call("se -x python311-pipx", exitcode => [0, 104]) == 104) {
        die("python311-pipx doesn't exist");
    }
    zypper_call("in python311-pipx python311-wheel");
    script_run("python3.11 setup.py bdist_wheel");
    script_run("ls");
    assert_script_run("pipx install dist/package-0.1-py3-none-any.whl");
    script_run("pipx list");
    assert_script_run("export PATH=\$PATH:~/.local/bin");
    validate_script_output("hello-world", sub {m/Hello world from package!/});
}

sub post_run_hook {
    zypper_call('rm python311-pipx', exitcode => [0, 104]);
    zypper_call('rm python311-base', exitcode => [0, 104]);
}

sub post_fail_hook {
    zypper_call('rm python311-Django', exitcode => [0, 104]);
    zypper_call('rm python311-base', exitcode => [0, 104]);
}

1;
