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
use base "opensusebasetest";
use testapi;
use utils;
use version_utils "is_sle";

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
    }
    else {
        zypper_call("in dovecot", exitcode => [0, 102, 103]);
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

    # Generate SSL DH parameters
    assert_script_run "openssl dhparam -out /etc/dovecot/dh.pem 2048", 300;

    # Generate default certificate for dovecot and postfix
    assert_script_run "cd /usr/share/doc/packages/dovecot;bash mkcert.sh";

    # configure postfix
    assert_script_run "postconf -e 'smtpd_use_tls = yes'";
    assert_script_run "postconf -e 'smtpd_tls_key_file = /etc/ssl/private/dovecot.pem'";
    assert_script_run "postconf -e 'smtpd_tls_cert_file = /etc/ssl/private/dovecot.crt'";
    assert_script_run "sed -i -e 's/#tlsmgr/tlsmgr/g' /etc/postfix/master.cf";
    assert_script_run "postconf -e 'smtpd_sasl_auth_enable = yes'";
    assert_script_run "postconf -e 'smtpd_sasl_path = private/auth'";
    assert_script_run "postconf -e 'smtpd_sasl_type = dovecot'";

    # start/restart services
    systemctl 'start dovecot';
    systemctl 'restart postfix';

    # create test users
    assert_script_run "useradd -m admin";
    script_run "passwd admin", 0;    # set user's password
    type_password "password123";
    send_key 'ret';
    type_password "password123";
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
    return {milestone => 1};
}

1;
