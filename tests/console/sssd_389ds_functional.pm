# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: sssd test with 389-ds as provider
#
# Set up 389-ds in container and run test cases below:
# 1. nss_sss test: look up user identity with id: uid and gid
# 2. pam_sss test: ssh login localhost as remote user.
# 3. write permission test: change remote user password with passwd
# 4. sssd-sudo test: Sudo run command as another remote user with sudoers rules defined in server
# 5. offline test: shutdown server, run test cases above again
#
# Detailed testcases: https://bugzilla.suse.com/tr_show_case.cgi?case_id=1768710
#
# Maintainer: Tony Yuan <tyuan@suse.com>

package sssd_389ds_functional;
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils;
use version_utils;
use registration 'add_suseconnect_product';

sub run {
    select_serial_terminal;

    # Install runtime dependencies
    zypper_call("in sudo nscd");

    my $docker = "podman";
    if (is_sle) {
        $docker = "docker";
        is_sle('<15') ? add_suseconnect_product("sle-module-containers", 12) : add_suseconnect_product("sle-module-containers");
    }
    zypper_call("in sssd sssd-ldap openldap2-client $docker");

    #For released sle versions use sle15sp3 base image by default. For developing sle use corresponding image in registry.suse.de
    my $pkgs = "awk systemd systemd-sysvinit 389-ds openssl";
    my $tag = "";
    if (is_opensuse) {
        $tag = (is_tumbleweed) ? "registry.opensuse.org/opensuse/tumbleweed" : "registry.opensuse.org/opensuse/leap";
    }
    else {
        $tag = 'registry.suse.com/suse/sle15:15.3';
        if (check_var('BETA', '1')) {
            my ($v, $sp) = split("-SP", get_var("VERSION"));
            $tag = $sp > 0 ? "registry.suse.de/suse/sle-$v-sp$sp/ga/images/suse/sle$v:$v.$sp" : "registry.suse.de/suse/sle-$v/ga/images/suse/sle$v:$v.0";
            ensure_ca_certificates_suse_installed;
        }
    }
    systemctl("enable --now $docker") if ($docker eq "docker");
    #build image, create container, setup 389-ds database and import testing data
    assert_script_run("mkdir /tmp/sssd && cd /tmp/sssd");
    assert_script_run("curl " . "--remote-name-all " . data_url("sssd/398-ds/{user_389.ldif,access.ldif,Dockerfile_$docker,instance_389.inf}"));
    assert_script_run(qq(sed -i '/gpg-auto-import-keys/i\\RUN zypper rr SLE_BCI' Dockerfile_$docker)) if (check_var('BETA', '1'));
    assert_script_run(qq($docker build -t ds389_image --build-arg tag="$tag" --build-arg pkgs="$pkgs" -f Dockerfile_$docker .), timeout => 600);
    assert_script_run(
"$docker run -itd --shm-size=256m --name ds389_container --hostname ldapserver --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:ro --restart=always ds389_image"
    ) if ($docker eq "docker");
    assert_script_run("$docker run -itd --shm-size=256m --name ds389_container --hostname ldapserver ds389_image") if ($docker eq "podman");
    assert_script_run("$docker exec ds389_container sed -n '/ldapserver/p' /etc/hosts >> /etc/hosts");
    assert_script_run("$docker exec ds389_container dscreate from-file /tmp/instance_389.inf");
    assert_script_run('ldapadd -x -H ldap://ldapserver -D "cn=Directory Manager" -w opensuse -f user_389.ldif');
    assert_script_run('ldapadd -x -H ldap://ldapserver -D "cn=Directory Manager" -w opensuse -f access.ldif');

    # Configure sssd on the host side
    assert_script_run("$docker cp ds389_container:/etc/dirsrv/slapd-frist389/ca.crt /etc/sssd/ldapserver.crt");
    assert_script_run("curl " . data_url("sssd/398-ds/sssd.conf") . " -o /etc/sssd/sssd.conf");
    assert_script_run("curl " . data_url("sssd/398-ds/nsswitch.conf") . " -o /etc/nsswitch.conf");
    assert_script_run("curl " . data_url("sssd/398-ds/config") . " --create-dirs -o ~/.ssh/config");
    systemctl("disable --now nscd.service");
    systemctl("enable --now sssd.service");

    #execute test cases
    #get remote user indentity
    validate_script_output("id alice", sub { m/uid=9998\(alice\)/ });
    #remote user authentification test
    assert_script_run("pam-config -a --sss --mkhomedir");

    select_console 'root-console';

    user_test();
    #Change password of remote user
    enter_cmd('ssh -oStrictHostKeyChecking=no alice@localhost', wait_still_screen => 5);
    enter_cmd('open5use', wait_still_screen => 5);
    enter_cmd('echo -e "open5use\nn0vell88\nn0vell88" | passwd', wait_still_screen => 1);
    enter_cmd('exit', wait_still_screen => 1);
    #verify password changed in remote 389-ds.
    validate_script_output('ldapwhoami -x -H ldap://ldapserver -D uid=alice,ou=users,dc=sssdtest,dc=com -w n0vell88', sub { m/alice/ });
    #Sudo run a command as another user
    assert_script_run("sed -i '/Defaults targetpw/s/^/#/' /etc/sudoers");
    enter_cmd('ssh -oStrictHostKeyChecking=no mary@localhost', wait_still_screen => 5);
    enter_cmd('open5use', wait_still_screen => 5);
    enter_cmd('echo open5use|sudo -S -l > /tmp/sudouser', wait_still_screen => 1);
    enter_cmd('exit', wait_still_screen => 1);
    validate_script_output('cat /tmp/sudouser', sub { m#/usr/bin/cat# });
    assert_script_run(qq(su -c 'echo "file read only by owner alice" > hello && chmod 600 hello' -l alice));
    sudo_user_test();
    #Change back password of remote user
    enter_cmd('ssh -oStrictHostKeyChecking=no alice@localhost', wait_still_screen => 5);
    enter_cmd('n0vell88', wait_still_screen => 5);
    enter_cmd('echo -e "n0vell88\nopen5use\nopen5use" | passwd', wait_still_screen => 1);
    enter_cmd('exit', wait_still_screen => 1);
    enter_cmd('ssh -oStrictHostKeyChecking=no alice@localhost', wait_still_screen => 5);
    enter_cmd('open5use', wait_still_screen => 5);
    enter_cmd('echo "Password changed back!" > /tmp/passwdback', wait_still_screen => 1);
    enter_cmd('exit', wait_still_screen => 1);
    validate_script_output('cat /tmp/passwdback', sub { m/Password changed back/ });

    #offline identity lookup and authentification
    assert_script_run("$docker stop ds389_container") if ($docker eq "docker");
    #offline cached remote user indentity lookup
    validate_script_output("id alice", sub { m/uid=9998\(alice\)/ });
    #offline remote user authentification test
    user_test();
    #offline sudo run a command as another user
    sudo_user_test();
}

sub user_test {
    enter_cmd('ssh -oStrictHostKeyChecking=no mary@localhost', wait_still_screen => 5);
    enter_cmd('open5use', wait_still_screen => 5);
    enter_cmd('whoami > /tmp/mary', wait_still_screen => 1);
    enter_cmd('exit', wait_still_screen => 1);
    validate_script_output('cat /tmp/mary', sub { m/mary/ });
}

sub sudo_user_test {
    enter_cmd('ssh -oStrictHostKeyChecking=no mary@localhost', wait_still_screen => 5);
    enter_cmd('open5use', wait_still_screen => 5);
    enter_cmd('echo open5use|sudo -S -u alice /usr/bin/cat /home/alice/hello > /tmp/readonly', wait_still_screen => 5);
    enter_cmd('exit', wait_still_screen => 1);
    validate_script_output('cat /tmp/readonly', sub { m/file read only by owner alice/ });
}
sub test_flags {
    return {always_rollback => 1};
}

1;
