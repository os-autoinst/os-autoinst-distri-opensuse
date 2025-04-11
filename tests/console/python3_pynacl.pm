# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Simple pynacl libsodium smoke test with transactional and non-transactional support
#
# Maintainer: QE Core <qe-core@suse.de>
#
use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';
use registration qw(runtime_registration);
use transactional qw(trup_call process_reboot);
use version_utils;
use python_version_utils;

my $requires_scc_registration = is_sle_micro || is_sle;
my $script_download_path = "~/test_pynacl.py";

sub run_test {
    my ($python_package) = @_;
    my $pkg = "$python_package-PyNaCl";

    if ($python_package eq 'python311' && is_sle('>=16.0')) {
        # python311-setuptools is not available on sle16
        record_info("Skip python311", 'Skip python311-PyNaCl test on SLE 16.0');
        return;
    }

    zypper_call("se $pkg");

    if (is_transactional) {
        trup_call("pkg in $python_package $pkg");
        process_reboot(expected_grub => 1, trigger => 1);
        select_serial_terminal;
    } else {
        zypper_call("in $python_package $pkg");
    }

    my $python_interpreter = get_python3_binary($python_package);
    record_info("running python version " . script_output("$python_interpreter --version"));

    assert_script_run("$python_interpreter " . $script_download_path);

    # clean up for the next run
    if (is_transactional) {
        trup_call("pkg rm $python_package $pkg");
        process_reboot(expected_grub => 1, trigger => 1);
        select_serial_terminal;
    } else {
        zypper_call("rm $python_package $pkg");
    }
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    # Download the test script
    assert_script_run("curl -v -o $script_download_path " . data_url("python/pynacl/test_pynacl.py"));
    runtime_registration() if $requires_scc_registration;
    my @python3_versions = get_available_fullstack_pythons();
    run_test($_) foreach @python3_versions;
}

sub post_fail_hook {
    my $self = shift;
    cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup {
    remove_installed_pythons();
    select_serial_terminal;
    script_run("rm -f " . $script_download_path);
}

1;
