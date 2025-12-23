# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform zypper migration for minor releases of SLES 16
# Maintainer: QE Installation and Migration <none@suse.de>

use testapi;
use base 'opensusebasetest';
use power_action_utils 'power_action';
use serial_terminal 'select_serial_terminal';
use Utils::Logging 'upload_solvertestcase_logs';

sub run {
    my $self = shift;

    my $arch = get_required_var("ARCH");
    my $target_version = get_required_var("VERSION");
    my $zypper_done = "ZYPPER-DONE";
    my $zypper_prompts = {
        migration_target => qr/(\d+)\s+\|\s?SUSE Linux Enterprise Server.*?$target_version\s+$arch/m,
        select_id => qr/\[num\/q\]:/m,
        continue => qr/^Continue\? \[y/m,
    };

    select_console 'root-console';
    assert_script_run("echo 'url: " . get_required_var('SCC_URL') . "' > /etc/SUSEConnect");

    script_run("(zypper migration; echo $zypper_done) |& tee /dev/$serialdev", 0);

    my $match = wait_serial($zypper_prompts->{migration_target}, 120)
      || die "Target version $target_version was not found.";

    my ($target_id) = $match =~ $zypper_prompts->{migration_target}
      || die "Target id was not found";

    wait_serial($zypper_prompts->{select_id}, 60) || die "ID selection prompt not found";
    enter_cmd $target_id;
    save_screenshot;

    wait_serial($zypper_prompts->{continue}, 120) || die "Continue prompt was not found";
    enter_cmd "y";

    wait_serial(qr/^$zypper_done/m, 900) || die "zypper migration completion was not found";

    select_console('root-console', await_console => 0);
    power_action('reboot', textmode => 1);
    $self->wait_boot(textmode => 1, bootloader_time => 300);
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
