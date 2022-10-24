# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test IMA kernel command line for IMA template
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48929

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $meas_file = "/sys/kernel/security/ima/ascii_runtime_measurements";
    my $part_n = "[a-fA-F0-9]\\{40\\}";
    my $part_ng = "sha256:[a-fA-F0-9]\\{64\\}";

    my @cmdline_list = (
        {
            cmdline => "ima_template=ima",
            pattern => "^10\\s*$part_n\\s*ima\\s*$part_n\\s*\\/",
            name => "ima"
        },
        {
            cmdline => "ima_template=ima-ng",
            pattern => "^10\\s*$part_n\\s*ima-ng\\s*$part_ng\\s*\\/",
            name => "ima-ng"
        },
        {
            cmdline => "ima_template=ima-sig",
            pattern => "^10\\s*$part_n\\s*ima-sig\\s*$part_ng\\s*\\/",
            name => "ima-sig"
        },
        {
            cmdline => "ima_template_fmt='\\''d-ng|n-ng|d|n'\\''",
            pattern => "^10\\s*$part_n\\s*d-ng|n-ng|d|n\\s*$part_ng\\s*\\/.*\\s*$part_n\\s*\\/",
            name => "fmt\\:d-ng\\|n-ng\\|d\\|n"
        },
    );

    add_grub_cmdline_settings('ima_policy=tcb ima_template');
    my $last_cmdline = "ima_template";

    for my $k (@cmdline_list) {
        replace_grub_cmdline_settings($last_cmdline, @$k{cmdline}, update_grub => 1);
        $last_cmdline = @$k{cmdline};

        # Grep and output grub settings to the terminal for debugging
        assert_script_run("grep GRUB_CMDLINE_LINUX /etc/default/grub");

        # Reboot to make settings work
        power_action('reboot', textmode => 1);
        $self->wait_boot;
        select_serial_terminal;

        my $meas_tmpfile = "/tmp/ascii_runtime_measurements-" . @$k{name};
        assert_script_run("cp $meas_file $meas_tmpfile");
        upload_logs "$meas_tmpfile";

        my $out = script_output("grep '@$k{pattern}' $meas_file |wc -l");
        die('Too few items') if ($out < 600);
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
