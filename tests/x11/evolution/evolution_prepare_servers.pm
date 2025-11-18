# Evolution tests
#
# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: dovecot postfix openssl
# Summary: Setup dovecot and postfix servers as backend for evolution
# - Stop packagekit service
# - Install on SLED dovecot from Server Apllications module else install dovecot and postfix
# - Configure dovecot enabling ssl and for use of plain login
# - Enable postix smtp auth in dovecot and generate certificates
# - Configure postfix enabling tls, smtpd sasl and hostname as localhost
# - Start dovecot and restart postfix
# - Create 2 test users: admin and nimda
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_sle is_jeos is_opensuse is_public_cloud is_leap);

sub run() {
    select_serial_terminal;

    quit_packagekit;

    if (check_var('SLE_PRODUCT', 'sled')) {
        my $version = get_var('VERSION');
        # Add server-applications to get dovecot, dovecot or server applications repo is not available on SLE Desktop
        zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Updates/SLE-Module-Server-Applications/$version/x86_64/update/ sle-module-server-applications:${version}::pool");
        zypper_call("ar -f http://dist.suse.de/ibs/SUSE/Products/SLE-Module-Server-Applications/$version/x86_64/product/ sle-module-server-applications:${version}::update");

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in dovecot 'openssl(cli)'", exitcode => [0, 102, 103]);
        zypper_call("rr sle-module-server-applications:${version}::pool sle-module-server-applications:${version}::update");
    } else {
        if (is_opensuse) {
            # exim is installed by default in openSUSE, but we need postfix
            zypper_call("in --force-resolution postfix", exitcode => [0, 102, 103]);
            systemctl 'start postfix';
        }

        zypper_call("in dovecot 'openssl(cli)'", exitcode => [0, 102, 103]);
        zypper_call("in --force-resolution postfix", exitcode => [0, 102, 103]) if ((script_run('rpm -q postfix') != 0) || is_jeos);
    }

    # Configure dovecot for sle16 and tumbleweed, see https://progress.opensuse.org/issues/182768
    my $dovecot24 = !is_sle('<16') && !is_leap('<16.0');
    if ($dovecot24) {
        assert_script_run('cd /etc/dovecot');
        assert_script_run('rm dovecot.conf');
        # The sample configre files are downloaded from https://github.com/dovecot/tools/blob/main/dovecot-2.4.0-example-config.tar.gz
        assert_script_run('curl -o dovecot.tar ' . data_url('dovecot.tar'));
        assert_script_run('tar xf dovecot.tar');
        assert_script_run('cd');
    }
    assert_script_run "sed -i -e 's/#mail_location =/mail_location = mbox:~\\/mail:INBOX=\\/var\\/mail\\/%u/g' /etc/dovecot/conf.d/10-mail.conf" unless $dovecot24;
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

    # Provision our own dovecot-openssl.cnf see https://bugzilla.suse.com/show_bug.cgi?id=1244597
    assert_script_run("cp /etc/dovecot/dovecot-openssl.cnf $dovecot_path") if $dovecot24;
    assert_script_run "(cd $dovecot_path; bash mkcert.sh)";

    # configure postfix
    assert_script_run "postconf -e 'smtpd_use_tls = yes'";
    assert_script_run "postconf -e 'smtpd_tls_security_level = encrypt'" if $dovecot24;
    assert_script_run "postconf -e 'smtpd_tls_key_file = /etc/ssl/private/dovecot.pem'";
    assert_script_run "postconf -e 'smtpd_tls_cert_file = /etc/ssl/private/dovecot.crt'";
    assert_script_run "sed -i -e 's/#tlsmgr/tlsmgr/g' /etc/postfix/master.cf";
    assert_script_run "postconf -e 'smtpd_sasl_auth_enable = yes'";
    assert_script_run "postconf -e 'smtpd_sasl_path = private/auth'";
    assert_script_run "postconf -e 'smtpd_sasl_type = dovecot'";
    assert_script_run "postconf -e 'myhostname = localhost'";
    assert_script_run "postconf -e 'home_mailbox = Maildir/'" if $dovecot24;

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
    return {milestone => 1, fatal => 0};
}

sub post_fail_hook {
    my ($self) = shift;
    select_console('log-console');
    $self->SUPER::post_fail_hook;
}

1;
