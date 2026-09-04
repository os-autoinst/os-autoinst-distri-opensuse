# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Package for 389ds_server service tests
#
# Maintainer: QE Security <none@suse.de>

package services::389ds_server;
use base 'consoletest';
use testapi;
use utils;
use warnings;
use strict;
use opensslca;
use network_utils 'iface';
use Utils::Architectures 'is_s390x';
use Utils::Systemd qw(disable_and_stop_service systemctl);
use version_utils qw(has_selinux is_sle);
use package_utils 'install_package';

my $local_name = '389ds';
my $remote_name = 'sssdclient';
my $ca_dir = '/etc/openldap/ssl';
my $inst_ca_dir = '/etc/dirsrv/slapd-localhost';

sub install_service {
    install_package("389-ds openssl", trup_reboot => 1);
}

# move ssh server to another port on s390x architecture
sub workaround_CC_s390x {
    my $server_ip = get_var('SERVER_IP', '10.0.2.101');
    my $client_ip = get_var('CLIENT_IP', '10.0.2.102');
    my $ssh_port = '2222';
    my $sshd_conf_file = is_sle('>=16') ? '/etc/ssh/sshd_config.d/root.conf' : '/etc/ssh/sshd_config';
    assert_script_run "ip addr add $server_ip/24 dev " . iface;
    assert_script_run "echo \"$server_ip server master\" >> /etc/hosts";
    assert_script_run "echo 'ListenAddress 0.0.0.0' >> $sshd_conf_file";
    assert_script_run "echo \"Port $ssh_port\" >> $sshd_conf_file";
    # on SELINUX enabled system, we need to add new port type to avoid sshd start failure
    assert_script_run "semanage port -a -t ssh_port_t -p tcp $ssh_port" if has_selinux;
    systemctl('restart sshd');
    disable_and_stop_service('firewalld', ignore_failure => 1);
    disable_and_stop_service('apparmor', ignore_failure => 1);
}

# The function below covers all required steps for 389ds server's configuration
sub config_service {
    my %args = @_;
    my $no_check = $args{no_check} // 0;    # Need to check by default
    my $workaround = $args{workaround} // 1;    # Need workaround for s390x
    permit_root_ssh();    # Permit ssh/scp from client as root
    workaround_CC_s390x if (is_s390x && $workaround);
    # Start a local instance with basic configuration file
    assert_script_run("wget --quiet " . data_url("389ds/instance.inf") . " -O /tmp/instance.inf");
    assert_script_run("sed -i 's/\{\{PASSWORD\}\}/$testapi::password/g' /tmp/instance.inf");
    # On s390x we need to set strict_host_checking to False, otherwise the test will fail
    assert_script_run("sed -i 's/True/False/g' /tmp/instance.inf") if (is_s390x || $no_check);

    # FIPS mode workaround for poo#206547: ns-slapd segfaults during dscreate in FIPS mode
    # The issue occurs because NSS database is not properly initialized for FIPS constraints
    if (get_var('FIPS_ENABLED')) {
        record_info('FIPS Workaround', 'Applying 389-ds FIPS compatibility workaround (poo#206547)');

        # Approach 1: Pre-create NSS database with FIPS mode enabled
        # This follows the same pattern as tests/fips/mozilla_nss/nss_smoke.pm
        record_info('FIPS Setup', 'Pre-creating NSS database in FIPS mode');

        # Create NSS database directory for the instance
        assert_script_run("mkdir -p $inst_ca_dir");

        # Initialize empty NSS database
        assert_script_run("certutil -N -d $inst_ca_dir --empty-password");

        # Check if FIPS is already enabled (auto-enabled when system is in FIPS mode)
        my $modutil_list = script_output("modutil -dbdir $inst_ca_dir -list", proceed_on_failure => 1);

        if ($modutil_list !~ /FIPS PKCS #11 Module/i) {
            # FIPS not enabled yet, enable it now
            record_info('FIPS Enable', 'Enabling FIPS mode in NSS database');

            script_run_interactive(
                "modutil -fips true -dbdir $inst_ca_dir",
                [
                    {
                        prompt => qr/'q <enter>' to abort, or <enter> to continue:/m,
                        string => "\n",
                    },
                ],
                60
            );
        } else {
            # FIPS already enabled (happens when system is in FIPS mode)
            record_info('FIPS Auto-Enabled', 'NSS database already has FIPS mode enabled by system');
        }

        # Verify FIPS mode is enabled in the database
        my $modutil_output = script_output("modutil -dbdir $inst_ca_dir -list", proceed_on_failure => 1);
        if ($modutil_output =~ /FIPS PKCS #11 Module/i) {
            record_info('FIPS Verified', 'NSS database successfully initialized in FIPS mode');

            # Set NSS_FIPS environment variable for ns-slapd process
            assert_script_run("export NSS_FIPS=1");
        } else {
            # Approach 1 failed - fallback to Approach 2
            record_soft_failure('poo#206547 - FIPS mode not enabled in NSS DB, trying fallback approach');
            record_info('FIPS Fallback', 'Using Approach 2: Disable TLS during initial creation');

            # Remove the pre-created NSS database
            assert_script_run("rm -rf $inst_ca_dir");

            # Disable secure port (TLS) during instance creation
            # This avoids NSS/FIPS issues during initialization
            assert_script_run("sed -i '/\\[slapd\\]/a secure_port = 0' /tmp/instance.inf");

            # We'll need to enable TLS after instance creation (handled later in the code)
            set_var('_389DS_FIPS_DELAYED_TLS', 1);
        }
    }

    assert_script_run("dscreate from-file /tmp/instance.inf");
    validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });

    # FIPS Approach 2 continuation: Re-enable TLS if we disabled it
    if (get_var('_389DS_FIPS_DELAYED_TLS')) {
        record_info('FIPS TLS', 'Re-enabling TLS after instance creation');

        # Enable secure port in configuration
        assert_script_run("dsconf localhost config replace nsslapd-secureport=636");

        # Restart to apply TLS configuration
        systemctl("restart dirsrv\@localhost.service");
        validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });
    }

    # Configure CA Certificates for TLS
    assert_script_run("wget --quiet " . data_url("389ds/.dsrc") . " -O /root/.dsrc");
    self_sign_ca("$ca_dir", "$local_name");

    # Stop the instance before modifying the NSS certificate database
    # to prevent race condition/corruption leading to segfault in libsoftokn3.so
    assert_script_run("dsctl localhost stop");

    # Deleted the default CA files since it can only resolve "localhost",
    # Please refer to bug 1180628 for more detail information
    assert_script_run("certutil -D -d $inst_ca_dir -n Server-Cert");
    assert_script_run("certutil -D -d $inst_ca_dir -n Self-Signed-CA");

    # Import new CA files while instance is stopped
    assert_script_run("dsctl localhost tls import-server-key-cert $ca_dir/server.pem $ca_dir/server.key");
    assert_script_run("dsctl localhost tls import-ca $ca_dir/myca.pem myca");
    assert_script_run("cp $ca_dir/myca.pem $inst_ca_dir/ca.crt");

    # Start the instance with new certificates
    assert_script_run("dsctl localhost start");
    validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });

    # Configure host names for C/S communication
    assert_script_run("sed -i -e 's/master/$local_name.example.com/' -e 's/minion/$remote_name.example.com/' /etc/hosts");

    # Create ldap user and group
    my $ldap_user = get_var('SSS_USERNAME');
    my $ldap_passwd = $testapi::password;
    my $ldap_group = 'server_admins';
    my $uid = '1003';
    my $gid = '1003';
    my $display_name = 'Domain User';
    my $basedn = "-b dc=example,dc=com";
    assert_script_run(
"dsidm $basedn localhost user create --uid $ldap_user --cn $ldap_user --displayName '$display_name' --uidNumber $uid --gidNumber $gid --homeDirectory /home/$ldap_user"
    );
    script_run_interactive(
        "dsidm $basedn localhost account reset_password uid=$ldap_user,ou=people,dc=example,dc=com",
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
        "dsidm $basedn localhost group create",
        [
            {
                prompt => qr/Enter value.*/m,
                string => "$ldap_group\n",
            },
        ],
        60
    );
    assert_script_run("dsidm $basedn localhost group add_member $ldap_group uid=$ldap_user,ou=people,dc=example,dc=com");

    # Generate the sample sssd configuration file
    assert_script_run("dsidm $basedn localhost client_config sssd.conf $ldap_group > /tmp/sssd.conf");

    # Delete the first 2 lines for the sample sssd.conf due to invalid messages there
    assert_script_run("sed -i '1,2d' /tmp/sssd.conf");

    # Set the ldap_uri with LDAP over SSL (LDAPS) Certificate
    assert_script_run("sed -i 's/^ldap_uri =.*\$/ldap_uri = ldaps:\\/\\/$local_name.example.com/' /tmp/sssd.conf");

}

sub enable_service {
    systemctl("enable dirsrv\@localhost.service");
}

sub check_service {
    systemctl("is-active dirsrv\@localhost.service");
    validate_script_output("dsctl localhost status", sub { m/Instance.*is running/ });
}

1;
