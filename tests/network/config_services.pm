# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: apache2 openldap2 vsftpd dovecot openssl postfix
# Summary: Test preparing services to use with multimachine scenarios.
#  At least confiugre:
#   - http - A basic http support with apache2
#   - ldap - A simple openladp with users.
#   - ftp  - simple ftp server
#   - mail - Setup dovecot and postfix servers as backend for mail servers.:
#         - Based on configurations from tests/x11/evolution/evolution_prepare_servers.pm by Petr Cervinka <pcervinka@suse.com>
#         - Stop packagekit service
#         - Install dovecot if DOVECOT_REPO is defined
#         - Configure dovecot enabling ssl and for use of plain login
#         - Enable postix smtp auth in dovecot and generate certificates
#         - Configure postfix enabling tls, smtpd sasl and hostname as localhost
#         - Start dovecot and restart postfix
#         - Create 2 test users: admin and nimda
#
#  Use on test variables settings: SUPPORT_SERVER_ROLES=http,ldap
#  The firewall was disable and network configuration used was provide by  tests/network/setup_multimachine.pm
#  This script was based from tests/support_server/setup.pm, but not use serial
#  console or neddles. This is to facilites to run on all SLES/OPensuse versions.
#
# Maintainer: Marcelo Martins <mmartins@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use lockapi;
use mm_network 'setup_static_mm_network';
use utils qw(systemctl zypper_call);
use version_utils qw(is_sle is_jeos is_opensuse);

sub setup_http_server {
    #install and configure simple apache2 if $http_server_set;
    zypper_call('in  apache2');
    systemctl('stop apache2');
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/http/apache2  >/etc/sysconfig/apache";
    systemctl('start apache2');
}

sub setup_ldap_server {
    #install and configure basic openldap2 if $ldap_server_set
    zypper_call('in openldap2');
    systemctl('stop slapd');
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/ldap/slapd.conf > /etc/openldap/slapd.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/ldap/test.ldif > /etc/openldap/test.ldif";
    assert_script_run 'sudo -u ldap slapadd -l /etc/openldap/test.ldif';
    systemctl('start slapd');
}

sub setup_ftp_server {
    #install and start default ftp server
    zypper_call('in vsftpd');
    systemctl('start vsftpd');
}

sub setup_mail_server {
    if (check_var('SLE_PRODUCT', 'sled') || get_var('DOVECOT_REPO')) {
        my $mail_server_repo = get_required_var("DOVECOT_REPO");
        zypper_call("ar ${mail_server_repo} dovecot_repo");
        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in dovecot");
        zypper_call("rr dovecot_repo");
        save_screenshot;
    } else {
        zypper_call("in dovecot");
    }
    #conf /etc/services
    assert_script_run " echo 'smtps              465/tcp      # Secure Mail Transfer' >> /etc/services";
    assert_script_run " echo 'smtps              465/udp      # Secure Mail Transfer' >> /etc/services";

    # config dovecot
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/10-mail.conf >/etc/dovecot/conf.d/10-mail.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/10-ssl.conf >/etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/10-auth.conf >/etc/dovecot/conf.d/10-auth.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/10-master.conf >/etc/dovecot/conf.d/10-master.conf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/auth-system.conf.ext >/etc/dovecot/conf.d/auth-system.conf.ext";

    # Generate SSL DH parameters for Dovecot >=2.3
    assert_script_run("openssl dhparam -out /etc/dovecot/dh.pem 2048", 900) unless is_sle('<15');

    # Generate default certificate for dovecot and postfix
    my $dovecot_path;
    if (is_jeos) {
        $dovecot_path = "/usr/share/dovecot";
    } else {
        $dovecot_path = "/usr/share/doc/packages/dovecot";
    }
    assert_script_run "cd $dovecot_path;bash mkcert.sh";

    # configure postfix
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/master.cf >/etc/postfix/master.cf";
    assert_script_run 'curl -f -v ' . autoinst_url . "/data/supportserver/mail_server/main.cf >/etc/postfix/main.cf";

    # start/restart services
    systemctl 'start dovecot';
    systemctl 'restart postfix';

    # DH parameters are generated after start in Dovecot < 2.2.7
    script_run("( journalctl -f -u dovecot.service & ) | grep -q 'ssl-params: SSL parameters regeneration completed'", 900) if is_sle('<15');

    # create test users
    assert_script_run "useradd -m admin";
    enter_cmd q(expect -c 'spawn passwd admin;expect "New password:";send password123\n;expect "Retype new password:";send password123\n;expect #');
    assert_script_run "useradd -m nimda";
    enter_cmd q(expect -c 'spawn passwd nimda;expect "New password:";send password123\n;expect "Retype new password:";send password123\n;expect #');

    save_screenshot;

    systemctl 'status dovecot';
    systemctl 'status postfix';

}

sub run {
    select_serial_terminal;
    my $hostname = get_var('HOSTNAME');
    # Get variable SUPPORT_SERVER_ROLES from job settings.
    my @server_roles = split(',|;', lc(get_var("SUPPORT_SERVER_ROLES")));
    my %server_roles = map { $_ => 1 } @server_roles;

    # Configure the services set in SUPPORT_SERVER_ROLES
    if (exists $server_roles{http}) {
        setup_http_server();
    }

    if (exists $server_roles{ldap}) {
        setup_ldap_server();
    }
    if (exists $server_roles{ftp}) {
        setup_ftp_server();
    }
    if (exists $server_roles{mail}) {
        setup_mail_server();
    }

    mutex_create('service_setup_done');

}

1;
