# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Make sure the nproc limits are not set in limits.conf
# Maintainer: QE Security <none@suse.de>
# Tags: poo#43724, poo#123763

use base "opensusebasetest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(check_version is_sle is_leap is_tumbleweed);

sub run {
    my ($self) = @_;

    select_serial_terminal;

    my $current_pam_ver = script_output("rpm -q --qf '%{version}\n' pam");
    record_info('pam version', "Version of Current pam package: $current_pam_ver");

    my $pathprefix = check_version('>=1.5.2', $current_pam_ver) ? "/usr" : "";
    unless ($pathprefix) {
        script_run('test ! -f /etc/security/limits.conf && install /usr/etc/security/limits.conf -t /etc/security');
    }

    # Set systemd config file and check with ulimit command
    my $file_path = "$pathprefix/etc/security/limits.d/nproc.conf";
    assert_script_run(qq{echo -e "* soft nproc unlimited\n* hard nproc unlimited" > $file_path});

    # 'systemctl daemon-reexec' does not work here, so we have to reboot
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;

    validate_script_output("ulimit -u", sub { m/unlimited/ });    # soft limit
    validate_script_output("ulimit -u -H", sub { m/unlimited/ });    # hard limit
}

sub test_flags {
    return {always_rollback => 1};
}

1;
