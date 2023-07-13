# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test audit function for IMA measurement
# Maintainer: QE Security <none@suse.de>
# Tags: poo#48926

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use bootloader_setup qw(add_grub_cmdline_settings replace_grub_cmdline_settings);
use power_action_utils "power_action";
use version_utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    my $meas_file = "/sys/kernel/security/ima/ascii_runtime_measurements";

    my @func_list = (
        {func => "BPRM_CHECK", file => "/usr/bin/ping", cmd => "ping -c 1 localhost"},
        {func => "FILE_CHECK", file => "/dev/shm/sample", cmd => "echo 'sample' > /dev/shm/sample"},
        {func => "MMAP_CHECK", file => "/usr/bin/ping", cmd => "ping -c 1 localhost"},
    );

    for my $f (@func_list) {
        assert_script_run("echo 'audit func=$f->{func}' >/etc/sysconfig/ima-policy");

        # Reboot to make settings work
        power_action('reboot', textmode => 1);
        $self->wait_boot;
        select_serial_terminal;

        # Clear audit log
        assert_script_run("echo -n '' > /var/log/audit/audit.log");

        ($f->{cmd}) ? assert_script_run($f->{cmd}) : die "Get command failure";

        # We do not check the exact file hash here, but to ensure the audit
        # record existed
        assert_script_run("ausearch -m INTEGRITY_RULE |grep '$f->{file}.*hash='");
    }
}

sub test_flags {
    return {always_rollback => 1};
}

1;
