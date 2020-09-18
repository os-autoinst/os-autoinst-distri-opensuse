# Copyright (C) 2020 SUSE LLC
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
# Summary: Basic function check for PAM, and prepare the setup for other
#          pam tests, e.g., create user, install some packages
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#70345, tc#1767569

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Install the pam-config package, and make sure it can list all modules
    zypper_call 'in pam-config';
    assert_script_run 'rpm -qi pam';
    assert_script_run 'pam-config --list-modules';

    # Make sure all corresponding files are there
    assert_script_run 'ls /etc/pam.d';
    assert_script_run 'ls /lib64/security';
    assert_script_run 'ls /etc/security';

    # Make sure the binaries are controlled by PAM
    assert_script_run 'ldd `which login` | grep pam';
    assert_script_run 'ldd `which su `| grep pam';
    assert_script_run 'ldd `which passwd` | grep pam';

    # Add user "suse",and use this user for later tests
    my $user   = 'suse';
    my $passwd = 'susetesting';
    assert_script_run "useradd -d /home/$user -m $user";
    assert_script_run "echo $user:$passwd | chpasswd";

    # Install expect package for later tests
    zypper_call 'in expect';

    # Backup the /etc/pam.d directory
    assert_script_run 'cp -pr /etc/pam.d /mnt';
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
