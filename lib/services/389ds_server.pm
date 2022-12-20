# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for 389ds_server service tests
#
# Maintainer: QE Security <none@suse.de>

package services::389ds_server;
use base "opensusebasetest";
use testapi;
use utils;
use warnings;
use strict;
use opensslca;

our @EXPORT = qw($local_ip $remote_ip $local_name $remote_name $ca_dir $inst_ca_dir);
our $local_ip = '10.0.2.101';
our $remote_ip = '10.0.2.102';
our $local_name = '389ds';
our $remote_name = 'sssdclient';
our $ca_dir = '/etc/openldap/ssl';
our $inst_ca_dir = '/etc/dirsrv/slapd-localhost';

sub install_service {
    zypper_call("in 389-ds openssl");
}

# The function below covers all required steps for 389ds server's configuration
sub config_service {
    # Start a local instance with basic configuration file
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

    # Import new CA files and restart the instance
    assert_script_run("dsctl localhost tls import-server-key-cert $ca_dir/server.pem $ca_dir/server.key");
    assert_script_run("dsctl localhost tls import-ca $ca_dir/myca.pem myca");
    assert_script_run("cp $ca_dir/myca.pem $inst_ca_dir/ca.crt");
    systemctl("restart dirsrv\@localhost.service");

    # Configure host names for C/S communication
    assert_script_run("sed -i -e 's/master/$local_name.example.com/' -e 's/minion/$remote_name.example.com/' /etc/hosts");

    # Create ldap user and group
    my $ldap_user = get_var('SSS_USERNAME');
    my $ldap_passwd = $testapi::password;
    my $ldap_group = 'server_admins';
    my $uid = '1003';
    my $gid = '1003';
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

    # Permit ssh/scp from client as root
    permit_root_ssh();
}

sub enable_service {
    systemctl("enable dirsrv\@localhost.service");
}

sub check_service {
    systemctl("is-active dirsrv\@localhost.service");
    validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });
}

1;
