# Evolution tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup dovecot and postfix servers as backend for evolution
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use version_utils qw(is_sle is_jeos is_opensuse);

sub run() {
    select_console('root-console');
    pkcon_quit;

    if (check_var('SLE_PRODUCT', 'sled') || get_var('DOVECOT_REPO')) {
        my $dovecot_repo = get_required_var("DOVECOT_REPO");
        # Add dovecot repository and install dovecot
        zypper_call("ar ${dovecot_repo} dovecot_repo");

        zypper_call("--gpg-auto-import-keys ref");
        zypper_call("in dovecot", exitcode => [0, 102, 103]);
        zypper_call("rr dovecot_repo");
        save_screenshot;
    } else {
        if (is_opensuse) {
            # exim is installed by default in openSUSE, but we need postfix
            zypper_call("in --force-resolution postfix", exitcode => [0, 102, 103]);
            systemctl 'start postfix';
        }
        zypper_call("in dovecot",                    exitcode => [0, 102, 103]);
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

    assert_script_run "cd $dovecot_path;bash mkcert.sh";

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
    script_run "passwd admin", 0;    # set user's password
    type_password "password123";
    wait_still_screen(1);
    send_key 'ret';
    type_password "password123";
    wait_still_screen(1);
    send_key 'ret';

    assert_script_run "useradd -m nimda";
    script_run "passwd nimda", 0;    # set user's password
    type_password "password123";
    send_key 'ret';
    type_password "password123";
    send_key 'ret';
    save_screenshot;

    systemctl 'status dovecot';
    systemctl 'status postfix';

    select_console 'x11' unless check_var('DESKTOP', 'textmode');
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
