# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Reenable openldap testing for 15SP5+
#
# Maintainer: QE Core <qe-core@suse.de>
# Tags: poo#165258
#
use base 'consoletest';
use testapi;
use utils;
use lockapi;
use serial_terminal 'select_serial_terminal';
use version_utils 'is_sle';
use registration 'add_suseconnect_product';

sub run {
    select_serial_terminal;
    assert_script_run qq(sed -i 's/server/ldapserver/g' /etc/hosts);
    assert_script_run qq(sed -i 's/client/ldapclient/g' /etc/hosts);

    add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1) if is_sle;
    zypper_call('in sssd sssd-ldap openldap2-client sshpass');


    mutex_wait('Openldap_server_READY');

    # Configure sssd on client
    assert_script_run("curl " . data_url("sssd/openldap/sssd.conf") . " -o /etc/sssd/sssd.conf");
    assert_script_run("curl " . data_url("sssd/openldap/nsswitch.conf") . " -o /etc/nsswitch.conf");
    assert_script_run("curl " . data_url("sssd/openldap/ldapserver.crt") . " -o /etc/sssd/ldapserver.crt");
    assert_script_run("curl " . data_url("sssd/openldap/config") . " --create-dirs -o ~/.ssh/config");
    # https://progress.opensuse.org/issues/195908
    assert_script_run('chmod 600 /etc/sssd/sssd.conf');
    systemctl('disable --now nscd.service');
    systemctl('enable --now sssd.service');

    # Remote user indentify
    validate_script_output("id bob", sub { m/(?=.*uid=5009\(bob\))(?=.*gid=5000\(testgroup\))/ });
    # Remote user authentification
    assert_script_run("pam-config -a --sss --mkhomedir");
    validate_script_output('sshpass -p open5use ssh adam@localhost whoami', sub { m/adam/ });
    # Change password of remote user
    assert_script_run('sshpass -p open5use ssh bob@localhost \'echo -e "open5use\nn0vell88\nn0vell88" | passwd\'');
    validate_script_output('sshpass -p n0vell88 ssh bob@localhost echo "login as new password!"', sub { m/new password/ });
    validate_script_output('ldapwhoami -x -H ldap://ldapserver -D uid=bob,ou=users,dc=sssdtest,dc=com -w n0vell88', sub { m/bob/ });
    # Sudo run a command as another user
    assert_script_run("echo 'Defaults !targetpw' >/etc/sudoers.d/notargetpw");
    validate_script_output('sshpass -p open5use ssh adam@localhost "echo open5use|sudo -S -l"', sub { m#/usr/bin/cat# });
    assert_script_run(qq(su -c 'echo "file read only by owner bob" > hello && chmod 600 hello' -l bob));
    validate_script_output('sshpass -p open5use ssh adam@localhost "echo open5use|sudo -S -u bob /usr/bin/cat /home/bob/hello"',
        sub { m/file read only by owner bob/ });
    # Change back password of remote user
    assert_script_run('sshpass -p n0vell88 ssh bob@localhost \'echo -e "n0vell88\nopen5use\nopen5use" | passwd\'');
    validate_script_output('sshpass -p open5use ssh bob@localhost echo "Password changed back!"', sub { m/Password changed back/ });
}

sub post_fail_hook {
    upload_logs("/var/log/messages");
    upload_logs("/etc/sssd/sssd.conf");
}

1;
