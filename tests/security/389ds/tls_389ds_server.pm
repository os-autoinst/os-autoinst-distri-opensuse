# Copyright (C) 2021 SUSE LLC
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
# Summary: Implement & Integrate 389ds + sssd test case into openQA,
#          This test module covers the server setup processes
#
# Maintainer: rfan1 <richard.fan@suse.com>
# Tags: poo#88513, poo#92410, tc#1768672

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use lockapi;
use mmapi 'wait_for_children';
use opensslca;

sub run {
    select_console("root-console");

    my $local_ip    = '10.0.2.101';
    my $remote_ip   = '10.0.2.102';
    my $local_name  = '389ds';
    my $remote_name = 'sssdclient';
    my $ca_dir      = '/etc/openldap/ssl';
    my $inst_ca_dir = '/etc/dirsrv/slapd-localhost';

    # Install 389-ds and create an server instance
    zypper_call("in 389-ds openssl");
    assert_script_run("wget --quiet " . data_url("389ds/instance.inf") . " -O /tmp/instance.inf");
    assert_script_run("dscreate from-file /tmp/instance.inf");
    validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });

    # Configure CA Certificates for TLS
    assert_script_run("wget --quiet " . data_url("389ds/.dsrc") . " -O /root/.dsrc");
    self_sign_ca("$ca_dir", "$local_name");

    # Deleted the default CA files since it can only resolve "localhost",
    # Please refer to bug 1180628 for more detail information
    assert_script_run("certutil -D -d $inst_ca_dir -n Server-Cert");
    assert_script_run("certutil -D -d $inst_ca_dir -n Self-Signed-CA");

    # Import new CA files and resart the instance
    assert_script_run("dsctl localhost tls import-server-key-cert $ca_dir/server.pem $ca_dir/server.key");
    assert_script_run("dsctl localhost tls import-ca $ca_dir/myca.pem myca");
    assert_script_run("cp $ca_dir/myca.pem $inst_ca_dir/ca.crt");
    systemctl("restart dirsrv\@localhost.service");

    # Configure host names for C/S communication
    assert_script_run("sed -i -e 's/master/$local_name.example.com/' -e 's/minion/$remote_name.example.com/' /etc/hosts");

    # Create ldap user and group
    my $ldap_user    = $testapi::username;
    my $ldap_passwd  = $testapi::password;
    my $ldap_group   = 'server_admins';
    my $uid          = '1003';
    my $gid          = '1003';
    my $display_name = 'Domain User';
    assert_script_run(
"dsidm localhost user create --uid $ldap_user --cn $ldap_user --displayName '$display_name' --uidNumber $uid --gidNumber $gid --homeDirectory /home/$ldap_user"
    );
    script_run_interactive(
        "dsidm localhost account reset_password uid=$ldap_user,ou=people,dc=example,dc=com",
        [
            {
                prompt => qr/Enter new password.*/m,
                string => "$ldap_passwd\n",
            },
            {
                prompt => qr/CONFIRM.*/m,
                string => "$ldap_passwd\n",
            },
        ],
        60
    );
    script_run_interactive(
        "dsidm localhost group create",
        [
            {
                prompt => qr/Enter value.*/m,
                string => "$ldap_group\n",
            },
        ],
        60
    );
    assert_script_run("dsidm localhost group add_member $ldap_group uid=$ldap_user,ou=people,dc=example,dc=com");

    # Generate the sample sssd configuration file
    assert_script_run("dsidm localhost client_config sssd.conf $ldap_group > /tmp/sssd.conf");

    # Delete the first 2 lines for the sample sssd.conf due to invalid messages there
    assert_script_run("sed -i '1,2d' /tmp/sssd.conf");

    # Set the ldap_uri with LDAP over SSL (LDAPS) Certificate
    assert_script_run("sed -i 's/^ldap_uri =.*\$/ldap_uri = ldaps:\\/\\/$local_name.example.com/' /tmp/sssd.conf");

    mutex_create("389DS_READY");

    # Finish job
    wait_for_children;
}

1;
