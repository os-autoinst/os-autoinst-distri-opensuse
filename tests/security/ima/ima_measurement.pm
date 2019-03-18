# Copyright (C) 2019 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test IMA measurement function
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#48374

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use bootloader_setup 'add_grub_cmdline_settings';
use power_action_utils "power_action";

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my $meas_file    = "/sys/kernel/security/ima/ascii_runtime_measurements";
    my $meas_tmpfile = "/tmp/ascii_runtime_measurements";
    my $sample_file  = "/tmp/sample.txt";

    add_grub_cmdline_settings('ima_policy=tcb', 1);

    # Reboot to make settings work
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;

    # Format verification
    assert_script_run(
        "head -n1 $meas_file |grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-ng\\s*sha1:0\\{40\\}\\s*boot_aggregate'",
        timeout      => '60',
        fail_messege => 'boot_aggregate item check failed'
    );

    my $out = script_output("grep '^10\\s*[a-fA-F0-9]\\{40\\}\\s*ima-ng\\s*sha256:[a-fA-F0-9]\\{64\\}\\s*\\/' $meas_file |wc -l");
    die('Too few sha256 items') if ($out < 800);

    # Test a sample file created in run time
    assert_script_run("echo 'This is a test!' > $sample_file");
    my $sample_sha      = script_output("sha256sum $sample_file |cut -d' ' -f1");
    my $sample_meas_sha = script_output("grep '$sample_file' $meas_file |awk -F'[ :]' '{print \$5}'");
    die 'The SHA256 values does not match' if ($sample_sha ne $sample_meas_sha);

    assert_script_run("cp $meas_file $meas_tmpfile");
    upload_logs "$meas_tmpfile";
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
