# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Make sure the nproc limits are not set in limits.conf
# Maintainer: QE Security <none@suse.de>
# Tags: poo#43724

use base "opensusebasetest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Check the limits.conf config file
    script_run('test ! -f /etc/security/limits.conf && install /usr/etc/security/limits.conf -t /etc/security');
    my $limits_d = script_output('find /etc/security/limits.d/ -name *.conf -exec echo -n "{} " \;');
    my $out = script_output("awk '!/^\$/ && !/^\\s*#/ {print \$3}' /etc/security/limits.conf $limits_d");
    die("Failed: nproc limits have been set") if $out =~ m/nproc/;

    # Set systemd config file and check with ulimit command
    assert_script_run("sed -i 's/\\s*#.*DefaultLimitNPROC.*/DefaultLimitNPROC=infinity/gI' /etc/systemd/system.conf");

    # 'systemctl daemon-reexec' does not work here, so we have to reboot
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;

    validate_script_output "ulimit -u", sub { m/unlimited/ };    # soft limit
    validate_script_output "ulimit -u -H", sub { m/unlimited/ };    # hard limit
}

sub test_flags {
    return {always_rollback => 1};
}

1;
