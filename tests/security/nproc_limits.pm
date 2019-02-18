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
# Summary: Make sure the nproc limits are not set in limits.conf
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Tags: poo#43724

use base "opensusebasetest";
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    # Check the limits.conf config file
    my $limits_d = script_output('find /etc/security/limits.d/ -name *.conf -exec echo -n "{} " \;');
    my $out      = script_output("awk '!/^\$/ && !/^\\s*#/ {print \$3}' /etc/security/limits.conf $limits_d");
    die("Failed: nproc limits have been set") if $out =~ m/nproc/;

    # Set systemd config file and check with ulimit command
    assert_script_run("sed -i 's/\\s*#.*DefaultLimitNPROC.*/DefaultLimitNPROC=infinity/gI' /etc/systemd/system.conf");

    # 'systemctl daemon-reexec' does not work here, so we have to reboot
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    $self->select_serial_terminal;

    validate_script_output "ulimit -u",    sub { m/unlimited/ };    # soft limit
    validate_script_output "ulimit -u -H", sub { m/unlimited/ };    # hard limit
}

sub test_flags {
    return {always_rollback => 1};
}

1;
