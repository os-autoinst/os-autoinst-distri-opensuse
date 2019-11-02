# Copyright © 2019 SUSE LLC
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
# Summary: Setup KDC service for krb5 cryptographic testing
# Maintainer: wnereiz <wnereiz@member.fsf.org>
# Ticket: poo#51560, poo#51563

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi;
use krb5crypt;    # Import public variables

sub run {
    select_console 'root-console';

    # Create KDC database
    validate_script_output "kdb5_util create -r $dom -s -P $pass_db", sub {
        m/
            Initializing\sdatabase.*for\srealm.*\Q$dom\E.*
            master\skey\sname.*\Q$dom\E.*/sxx
    };
    validate_script_output "kadmin.local -q listprincs", sub {
        m/krbtgt\/\Q$dom\E\@\Q$dom\E/;
    };

    # Add admin user
    assert_script_run "kadmin.local -q 'addprinc -pw $pass_a $adm'";
    validate_script_output "kadmin.local -q listprincs", sub {
        m/\Q$adm\E\@\Q$dom\E/;
    };

    systemctl("start krb5kdc");
    systemctl("enable krb5kdc");

    script_run("kinit $adm |& tee /dev/$serialdev", 0);
    wait_serial(qr/Password.*\Q$adm\E/) || die "Matching output failed";
    type_string "$pass_a\n";
    script_output "echo \$?", sub { m/^0$/ };
    validate_script_output "klist", sub {
        m/
            Ticket\scache.*\/root\/kcache.*
            Default\sprincipal.*\Q$adm\E\@\Q$dom\E.*
            krbtgt\/\Q$dom\E\@\Q$dom\E.*
            renew\suntil.*/sxx
    };

    my $kadm_conf = '/var/lib/kerberos/krb5kdc/kadm5.acl';
    assert_script_run "sed -Ei 's/^#(.*\\/admin\@\Q$dom\E.*)/\\1/g' $kadm_conf";
    assert_script_run "cat $kadm_conf";

    systemctl("start kadmind");
    systemctl("enable kadmind");

    mutex_create('CONFIG_READY_KRB5_KDC');

    # Waiting for the finish of krb5 and other testing server
    my $children = get_children();
    mutex_wait('TEST_DONE_SERVER',     (keys %$children)[0]);
    mutex_wait('TEST_DONE_SSH_SERVER', (keys %$children)[0]);
    mutex_wait('TEST_DONE_NFS_SERVER', (keys %$children)[0]);
}

sub test_flags {
    return {fatal => 1};
}

1;
