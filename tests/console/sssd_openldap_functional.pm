# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: sssd test with openldap as provider
#
# Set up openldap server in container and run test cases below:
#
# 1. nss_sss test: look up user identity with id: uid and gid
# 2. pam_sss test: ssh login localhost as remote user.
# 3. write permission test: change remote user password with passwd
# 4. sssd-sudo test: Sudo run command as another remote user with sudoers rules defined in server
# 5. offline test: shutdown server, run test cases above again
#
# Detailed testcases: https://bugzilla.suse.com/tr_show_case.cgi?case_id=1768711
# Maintainer: Tony Yuan <tyuan@suse.com>

package sssd_openldap_functional;
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils;
use registration qw(add_suseconnect_product get_addon_fullname);

sub run {
    select_serial_terminal;
    if (is_sle) {
        add_suseconnect_product('PackageHub', undef, undef, undef, 300, 1);
        is_sle('<15') ? add_suseconnect_product("sle-module-containers", 12) : add_suseconnect_product("sle-module-containers");
    }
    zypper_call("in sssd sssd-ldap openldap2-client sshpass docker");
    systemctl('enable --now docker');
    #Select container base image by specifying variable BASE_IMAGE_TAG. (for sles using sle15sp3 by default)
    my $pkgs = "openldap2 sudo";
    my $tag = get_var("BASE_IMAGE_TAG");
    my $maint_test_repo = get_var('MAINT_TEST_REPO');
    unless ($tag) {
        if (is_opensuse) { $tag = (is_tumbleweed) ? "opensuse/tumbleweed" : "opensuse/leap";
        } else { $tag = "registry.suse.com/suse/sle15:15.3"; }
    }
    # build container
    # build image, create container, setup openldap database and import testing data
    assert_script_run("mkdir /tmp/sssd && cd /tmp/sssd");
    assert_script_run("curl -s " . "--remote-name-all " . data_url('sssd/openldap/{user.ldif,slapd.conf,Dockerfile,add_test_repositories.sh}'));
    assert_script_run("curl -s " . "--remote-name-all " . data_url('sssd/openldap/ldapserver.{key,crt,csr}'));
    assert_script_run(qq(docker build -t openldap2_image --build-arg tag="$tag" --build-arg pkgs="$pkgs" --build-arg maint_test_repo="$maint_test_repo" .), timeout => 600);
    assert_script_run('docker run -itd --name ldap_container --hostname ldapserver --restart=always openldap2_image');
    assert_script_run("docker exec ldap_container sed -n '/ldapserver/p' /etc/hosts >> /etc/hosts");

    # Configure sssd on the host
    assert_script_run("curl -s " . data_url("sssd/openldap/sssd.conf") . " -o /etc/sssd/sssd.conf");
    assert_script_run("curl -s " . data_url("sssd/openldap/nsswitch.conf") . " -o /etc/nsswitch.conf");
    assert_script_run("curl -s " . data_url("sssd/openldap/ldapserver.crt") . " -o /etc/sssd/ldapserver.crt");
    assert_script_run("curl -s " . data_url("sssd/openldap/config") . " --create-dirs -o ~/.ssh/config");
    systemctl('disable --now nscd.service');
    systemctl("enable --now sssd.service");

    #execute test cases
    #get remote user indentity
    validate_script_output("id bob", sub { m/(?=.*uid=5009\(bob\))(?=.*gid=5000\(testgroup\))/ });
    #remote user authentification test
    assert_script_run("pam-config -a --sss --mkhomedir");
    validate_script_output('sshpass -p open5use ssh adam@localhost whoami', sub { m/adam/ });
    #Change password of remote user
    assert_script_run('sshpass -p open5use ssh bob@localhost \'echo -e "open5use\nn0vell88\nn0vell88" | passwd\'');
    validate_script_output('sshpass -p n0vell88 ssh bob@localhost echo "login as new password!"', sub { m/new password/ });
    validate_script_output('ldapwhoami -x -H ldap://ldapserver -D uid=bob,ou=users,dc=sssdtest,dc=com -w n0vell88', sub { m/bob/ });
    #Sudo run a command as another user
    assert_script_run("sed -i '/Defaults targetpw/s/^/#/' /etc/sudoers");
    validate_script_output('sshpass -p open5use ssh adam@localhost "echo open5use|sudo -S -l"', sub { m#/usr/bin/cat# });
    assert_script_run(qq(su -c 'echo "file read only by owner bob" > hello && chmod 600 hello' -l bob));
    validate_script_output('sshpass -p open5use ssh adam@localhost "echo open5use|sudo -S -u bob /usr/bin/cat /home/bob/hello"', sub { m/file read only by owner bob/ });

    #Change back password of remote user
    assert_script_run('sshpass -p n0vell88 ssh bob@localhost \'echo -e "n0vell88\nopen5use\nopen5use" | passwd\'');
    validate_script_output('sshpass -p open5use ssh bob@localhost echo "Password changed back!"', sub { m/Password changed back/ });
    #offline identity lookup and authentification
    assert_script_run('docker stop ldap_container');
    #offline cached remote user indentity lookup
    validate_script_output("id bob", sub { m/uid=5009\(bob\)/ });
    #offline remote user authentification test
    validate_script_output('sshpass -p open5use ssh adam@localhost whoami', sub { m/adam/ });
    #offline sudo run a command as another user
    validate_script_output('sshpass -p open5use ssh adam@localhost "echo open5use|sudo -S -u bob /usr/bin/cat /home/bob/hello"', sub { m/file read only by owner bob/ });
}

sub test_flags {
    return {always_rollback => 1};
}

1;
