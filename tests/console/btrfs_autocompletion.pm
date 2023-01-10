# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: bash-completion btrfsprogs
# Summary: Bash autocompletion for btrfs
# - Installs bash-completion package in case jeos
# - Call compare_commands with btrfs commands wth "short" (tabbed) version and
# compare obtained results
# - Call "complete" and check for btrfs functions
# - Run "btrfs inspect-internal min-dev-size / | grep -E '^[0-9]{6,} bytes'" to
# check if device is working and it is at least 1MB in size.
# Maintainer: Martin Kravec <mkravec@suse.com>

use base 'btrfs_test';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils 'is_jeos';

# Btrfs understands short commands like "btrfs d st"
# Compare autocompleted commands as strings
sub compare_commands {
    for my $i (1 .. 2) {
        type_string shift;
        type_string "\" > /tmp/command$i";
        send_key "home";
        enter_cmd "echo \"";
    }
    assert_script_run "diff /tmp/command\[12\]";
}

sub run {
    select_console 'root-console';

    # On JeOS 'bash-completion' is not expected to be present. On general
    # SLES installation it is. Thus on JeOS we have to enable it manually.
    if (is_jeos) {
        zypper_call('in bash-completion');
        assert_script_run('source $(rpmquery -l bash-completion | grep bash_completion.sh)');
    }

    compare_commands("btrfs device stats ", "btrfs d\tst\t");
    compare_commands("btrfs subvolume get-default ", "btrfs su\tg\t");
    compare_commands("btrfs filesystem usage ", "btrfs fi\tu\t");
    compare_commands("btrfs inspect-internal min-dev-size ", "btrfs i\tmi\t");

    # Check loading of complete function
    assert_script_run "complete | grep '_btrfs btrfs'";

    # Getting minimum device size is working and returning at least 1MB
    assert_script_run "btrfs inspect-internal min-dev-size / | grep -E '^[0-9]{6,} bytes'";
}

sub post_fail_hook {
    my ($self) = @_;
    assert_script_run('rpm -qa > /tmp/rpm_qa.txt');
    upload_logs('/tmp/rpm_qa.txt');
    upload_logs('/var/log/zypper.log');
    $self->SUPER::post_fail_hook;
}

1;
