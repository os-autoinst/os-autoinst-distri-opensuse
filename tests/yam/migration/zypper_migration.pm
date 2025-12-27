# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform online minor release zypper migration for SLES 16
# Maintainer: QE Installation and Migration <none@suse.de>

use testapi;
use base 'opensusebasetest';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'upload_solvertestcase_logs';

sub run {
    my $self = shift;

    select_console 'root-console';

    my $target_version = get_required_var("VERSION");
    my ($major_version, $minor_version) = $target_version =~ /^(\d+)\.(\d+)/;
    my $zypper_prompts = {
        migrations_prompt => qr/\[num\/q\]/m,
        continue => qr/^Continue\? \[y/m,
        done => qr/ZYPPER-DONE/m
    };

    assert_script_run("echo 'url: " . get_required_var('SCC_URL') . "' > /etc/SUSEConnect");
    script_run("(zypper migration; echo ZYPPER-DONE) |& tee /dev/$serialdev", 0);
    while (my $out = wait_serial([values %$zypper_prompts], 600)) {
        if ($out =~ $zypper_prompts->{migrations_prompt}) {
            if ($out =~ /(?<num>\d+)\s+\|\s?SUSE Linux.*?$major_version\.$minor_version/m) {
                enter_cmd "$+{num}";
                save_screenshot;
            }
            else {
                die "Expected migration target version $target_version not found";
            }
        }
        elsif ($out =~ $zypper_prompts->{continue}) {
            enter_cmd "y";
        }
        elsif ($out =~ $zypper_prompts->{done}) {
            last;
        }
    }

    select_console('root-console', await_console => 0);
    power_action('reboot', textmode => 1);
    $self->wait_boot(bootloader_time => 300, ready_time => 300);
}

sub post_fail_hook {
    my $self = shift;

    select_serial_terminal;
    script_run("pkill zypper");
    upload_logs '/var/log/zypper.log';
    upload_solvertestcase_logs();
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return {milestone => 1};
}

1;
