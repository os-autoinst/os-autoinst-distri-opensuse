# Evolution tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dovecot postfix openssl
# Summary: Setup dovecot and postfix servers as backend for evolution
# - Stop packagekit service
# - Install dovecot if DOVECOT_REPO is defined or it is sled. Otherwise, install
#   dovecot and postfix and start the later
# - Configure dovecot enabling ssl and for use of plain login
# - Enable postix smtp auth in dovecot and generate certificates
# - Configure postfix enabling tls, smtpd sasl and hostname as localhost
# - Start dovecot and restart postfix
# - Create 2 test users: admin and nimda
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_jeos is_opensuse);

sub run() {
    my $self = shift;
    select_serial_terminal;

    quit_packagekit;

    if (check_var('SLE_PRODUCT', 'sled') || get_var('DOVECOT_REPO')) {
        my $dovecot_repo = get_required_var("DOVECOT_REPO");
        # Add dovecot repository and install dovecot
        zypper_call("ar ${dovecot_repo} dovecot_repo");

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in dovecot 'openssl(cli)'", exitcode => [0, 102, 103]);
        zypper_call("rr dovecot_repo");
    } else {
        if (is_opensuse) {
            # exim is installed by default in openSUSE, but we need postfix
            zypper_call("in --force-resolution postfix", exitcode => [0, 102, 103]);
            systemctl 'start postfix';
        }
        zypper_call("in dovecot 'openssl(cli)'", exitcode => [0, 102, 103]);
        zypper_call("in --force-resolution postfix", exitcode => [0, 102, 103]) if is_jeos;
    }

    # configure dovecot
    assert_script_run "sed -i -e 's/#mail_location =/mail_location = mbox:~\\/mail:INBOX=\\/var\\/mail\\/%u/g' /etc/dovecot/conf.d/10-mail.conf";
    assert_script_run "sed -i -e 's/#mail_access_groups =/mail_access_groups = mail/g' /etc/dovecot/conf.d/10-mail.conf";
    assert_script_run "sed -i -e 's/#ssl_cert =/ssl_cert =/g' /etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run "sed -i -e 's/#ssl_key =/ssl_key =/g' /etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run "sed -i -e 's/#ssl_dh =/ssl_dh =/g' /etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run "sed -i -e 's/auth_mechanisms = plain/auth_mechanisms = plain login/g' /etc/dovecot/conf.d/10-auth.conf";
    # Uncomment lines related to Postfix smtp-auth
    #  unix_listener /var/spool/postfix/private/auth {
    #   mode = 0666
    # }
    assert_script_run "sed -i -e '/unix_listener .*postfix.* {/,/}/ s/#//g' /etc/dovecot/conf.d/10-master.conf";

    # Generate SSL DH parameters for Dovecot >=2.3
    assert_script_run("openssl dhparam -out /etc/dovecot/dh.pem 2048", 900) unless is_sle('<15');

    # Generate default certificate for dovecot and postfix
    my $dovecot_path;
    if (is_jeos) {
        $dovecot_path = "/usr/share/dovecot";
    } else {
        $dovecot_path = "/usr/share/doc/packages/dovecot";
    }

    assert_script_run "(cd $dovecot_path; bash mkcert.sh)";

    # configure postfix
    assert_script_run "postconf -e 'smtpd_use_tls = yes'";
    assert_script_run "postconf -e 'smtpd_tls_key_file = /etc/ssl/private/dovecot.pem'";
    assert_script_run "postconf -e 'smtpd_tls_cert_file = /etc/ssl/private/dovecot.crt'";
    assert_script_run "sed -i -e 's/#tlsmgr/tlsmgr/g' /etc/postfix/master.cf";
    assert_script_run "postconf -e 'smtpd_sasl_auth_enable = yes'";
    assert_script_run "postconf -e 'smtpd_sasl_path = private/auth'";
    assert_script_run "postconf -e 'smtpd_sasl_type = dovecot'";
    assert_script_run "postconf -e 'myhostname = localhost'";

    # start/restart services
    systemctl 'start dovecot';
    systemctl 'restart postfix';

    # DH parameters are generated after start in Dovecot < 2.2.7
    assert_script_run("( journalctl -f -u dovecot.service & ) | grep -q 'ssl-params: SSL parameters regeneration completed'", 900) if is_sle('<15');

    # create test users
    assert_script_run "useradd -m admin";
    assert_script_run "useradd -m nimda";
    assert_script_run "echo 'admin:password123' | chpasswd";
    assert_script_run "echo 'nimda:password123' | chpasswd";

    systemctl 'status dovecot';
    systemctl 'status postfix';

    select_console 'x11' unless check_var('DESKTOP', 'textmode');
}

sub test_flags() {
    return get_var('PUBLIC_CLOUD') ? {milestone => 0, fatal => 1, no_rollback => 1} : {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
    $self->export_logs_basic;
}

1;
