# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Basic function check for PAM, and prepare the setup for other
#          pam tests, e.g., create user, install some packages
# Maintainer: QE Security <none@suse.de>
# Tags: poo#70345, tc#1767569

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;

    # Install the pam-config package, and make sure it can list all modules
    zypper_call 'in pam-config';
    assert_script_run 'rpm -qi pam';
    assert_script_run 'pam-config --list-modules';

    # Make sure all corresponding files are there
    assert_script_run 'ls /etc/pam.d';
    assert_script_run 'ls /lib*/security';
    assert_script_run 'ls /etc/security';

    # Make sure the binaries are controlled by PAM
    assert_script_run 'ldd `which login` | grep pam';
    assert_script_run 'ldd `which su `| grep pam';
    assert_script_run 'ldd `which passwd` | grep pam';

    # Add user "suse",and use this user for later tests
    my $user = 'suse';
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
