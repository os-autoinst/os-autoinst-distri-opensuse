# Copyright 2019-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA measurement function
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48374

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils "power_action";
use version_utils qw(is_sle);
use Utils::Architectures qw(is_aarch64);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $meas_file = "/sys/kernel/security/ima/ascii_runtime_measurements";
    my $meas_tmpfile = "/tmp/ascii_runtime_measurements";
    my $sample_file = "/etc/sample.txt";

    add_grub_cmdline_settings('ima_policy=tcb', update_grub => 1);

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    my $boot_method = ((is_aarch64 && is_sle('>=16')) ? 'wait_boot_past_bootloader' : 'wait_boot');
    $self->$boot_method;
    select_serial_terminal;

    # Upload files for reference before test dies
    assert_script_run("cp $meas_file $meas_tmpfile");
    upload_logs "$meas_tmpfile";

    # Format verification
    assert_script_run(
        "head -n1 $meas_file |grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-ng\\s*sha256:0\\{64\\}\\s*boot_aggregate'",
        timeout => '60',
        fail_message => 'boot_aggregate item check failed'
    );
    my $retries = 30;
    while ($retries--) {
        sleep 0.1;
        my $out = script_output("grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-ng\\s*sha256:[a-fA-F0-9]\\{64\\}\\s*\/' $meas_file |wc -l");
        last if ($out >= 800);    # exit when we have enough entries. 800 is a rough estimate, not a strict requirement
    }
    die('Too few sha256 items') unless $retries;
    # Test a sample file created in run time
    assert_script_run("echo 'This is a test!' > $sample_file");
    assert_script_run("cat $sample_file");
    my $sample_sha = script_output("sha256sum $sample_file |cut -d' ' -f1");
    my $sample_meas_sha = script_output("grep '$sample_file' $meas_file |awk -F'[ :]' '{print \$5}'");
    die 'The SHA256 values does not match' if ($sample_sha ne $sample_meas_sha);
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
