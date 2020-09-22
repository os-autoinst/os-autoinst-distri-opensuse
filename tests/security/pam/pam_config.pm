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
# Summary: PAM tests for pam-config, create, add or delete service
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#70345, tc#1767580

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use registration qw(add_suseconnect_product remove_suseconnect_product);
use utils 'zypper_call';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Create a simple Unix authentication configuration, all backup files will not be deleted
    assert_script_run 'pam-config --create';
    assert_script_run 'ls /etc/pam.d | grep config-backup';

    # Add a new authentication method, add the module to install the "pam_ldap" package
    add_suseconnect_product('sle-module-legacy');
    zypper_call 'in pam_ldap';
    assert_script_run 'pam-config --add --ldap';
    assert_script_run 'find /etc/pam.d -type f | grep common | xargs egrep ldap';
    assert_script_run 'pam-config --add --ldap-debug';
    assert_script_run 'journalctl | grep ldap';

    # Delete a method
    assert_script_run 'pam-config --delete --ldap';
    assert_script_run 'pam-config --delete --ldap-debug';
    validate_script_output "find /etc/pam.d -type f | grep common | xargs egrep ldap || echo 'check pass'", sub { m/check pass/ };
    upload_logs("/var/log/messages");

    # Tear down, remove the added module
    remove_suseconnect_product('sle-module-legacy');
}

sub test_flags {
    return {always_rollback => 1};
}

sub post_fail_hook {
    assert_script_run 'cp -pr /mnt/pam.d /etc';
}

1;
