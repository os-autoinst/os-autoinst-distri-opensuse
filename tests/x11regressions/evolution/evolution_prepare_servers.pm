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
use base "x11regressiontest";
use testapi;
use utils;

sub run() {
    # check for the SLE version, die if not supported
    # dovecot repository must be ajusted for versions > 12 to run full
    # evolution imap/pop tests
    die 'not supported SLE version' if not get_var('VERSION') =~ /12/;

    select_console('root-console');
    pkcon_quit;

    # add SLES repository and install dovecot
    zypper_call("ar http://download.suse.de/ibs/SUSE:/SLE-12:/Update/standard/ sle_server_repo");
    zypper_call("--gpg-auto-import-keys ref");
    zypper_call("in dovecot", exitcode => [0, 102, 103]);
    save_screenshot;

    # configure dovecot
    assert_script_run "sed -i -e 's/#mail_location =/mail_location = mbox:~\\/mail:INBOX=\\/var\\/mail\\/%u/g' /etc/dovecot/conf.d/10-mail.conf";
    assert_script_run "sed -i -e 's/#mail_access_groups =/mail_access_groups = mail/g' /etc/dovecot/conf.d/10-mail.conf";
    assert_script_run "sed -i -e 's/#ssl_cert =/ssl_cert =/g' /etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run "sed -i -e 's/#ssl_key =/ssl_key =/g' /etc/dovecot/conf.d/10-ssl.conf";
    assert_script_run "sed -i -e 's/auth_mechanisms = plain/auth_mechanisms = plain login/g' /etc/dovecot/conf.d/10-auth.conf";
    assert_script_run "sed -i -e '96,98 s/#//g' /etc/dovecot/conf.d/10-master.conf";

    # generate default certificate for dovecot and postfix
    assert_script_run "cd /usr/share/doc/packages/dovecot;./mkcert.sh";

    # configure postfix
    assert_script_run "postconf -e 'smtpd_use_tls = yes'";
    assert_script_run "postconf -e 'smtpd_tls_key_file = /etc/ssl/private/dovecot.pem'";
    assert_script_run "postconf -e 'smtpd_tls_cert_file = /etc/ssl/private/dovecot.crt'";
    assert_script_run "sed -i -e 's/#tlsmgr/tlsmgr/g' /etc/postfix/master.cf";
    assert_script_run "postconf -e 'smtpd_sasl_auth_enable = yes'";
    assert_script_run "postconf -e 'smtpd_sasl_path = private/auth'";
    assert_script_run "postconf -e 'smtpd_sasl_type = dovecot'";

    # start/restart services
    assert_script_run "systemctl start dovecot";
    assert_script_run "systemctl restart postfix";

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

    select_console 'x11';
}

sub test_flags() {
    return {milestone => 1};         # add milestone flag to save setup in lastgood VM snapshot
}

1;
# vim: set sw=4 et:
