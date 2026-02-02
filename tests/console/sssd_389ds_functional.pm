# Copyright SUSE LLC
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
# Maintainer: QE Security <none@suse.de>

package sssd_389ds_functional;
use base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils qw(is_opensuse is_tumbleweed is_sle);
use registration 'add_suseconnect_product';
use feature 'signatures';
no warnings 'experimental::signatures';

sub install_dependencies($container_engine) {

    zypper_call("in sudo nscd") unless (is_tumbleweed || is_sle('>=16'));
    zypper_call("in sssd sssd-ldap openldap2-client sshpass $container_engine");
    systemctl("enable --now $container_engine") if ($container_engine eq "docker");
    return $container_engine;
}

sub setup_389ds_container ($container_engine) {

    my $pkgs = "awk systemd systemd-sysvinit 389-ds openssl";
    my $tag = "";
    if (is_opensuse) {
        $tag = (is_tumbleweed) ? "registry.opensuse.org/opensuse/tumbleweed" : "registry.opensuse.org/opensuse/leap";
    }
    else {
        $tag = 'registry.suse.com/suse/sle15:15.7';
    }

    assert_script_run("mkdir /tmp/sssd && cd /tmp/sssd");

    my @artifacts = qw(user_389.ldif access.ldif instance_389.inf sssd.conf nsswitch.conf config);
    push(@artifacts, "Dockerfile_$container_engine");

    my $data_url = sprintf("sssd/398-ds/{%s}", join(',', @artifacts));
    assert_script_run("curl --remote-name-all " . data_url($data_url));

    assert_script_run(qq($container_engine build -t ds389_image --build-arg tag="$tag" --build-arg pkgs="$pkgs" -f Dockerfile_$container_engine .), timeout => 600);

    script_run(qq($container_engine rm -f ds389_container));

    my $container_run_389_ds = "$container_engine run -itd --shm-size=256m --name ds389_container --hostname ldapserver";
    $container_run_389_ds .= " --privileged -v /sys/fs/cgroup:/sys/fs/cgroup:rw --restart=always" if ($container_engine eq "docker");

    assert_script_run("$container_run_389_ds ds389_image");

    script_retry("$container_engine inspect -f '{{.State.Running}}' ds389_container | grep true", retry => 60, delay => 1, fail_message => "Cannot start container");

    assert_script_run("$container_engine exec ds389_container chown dirsrv:dirsrv /var/lib/dirsrv");
    assert_script_run("$container_engine exec ds389_container sed -n '/ldapserver/p' /etc/hosts >> /etc/hosts");
    assert_script_run("$container_engine exec ds389_container dscreate from-file /tmp/instance_389.inf");
    assert_script_run('ldapadd -x -H ldap://ldapserver -D "cn=Directory Manager" -w opensuse -f user_389.ldif');
    assert_script_run('ldapadd -x -H ldap://ldapserver -D "cn=Directory Manager" -w opensuse -f access.ldif');
}

sub configure_sssd_client ($container_engine) {

    assert_script_run('mkdir -p /etc/sssd/');
    assert_script_run("$container_engine cp ds389_container:/etc/dirsrv/slapd-frist389/ca.crt /etc/sssd/ldapserver.crt");
    assert_script_run("install --mode 0644 -D ./nsswitch.conf /etc/nsswitch.conf");
    assert_script_run("install --mode 0600 -D ./sssd.conf /etc/sssd/sssd.conf");
    assert_script_run("install --mode 0600 -D ./config ~/.ssh/config");

    systemctl("disable --now nscd.service") unless (is_sle('>=16') || is_tumbleweed);
    systemctl("enable --now sssd.service");
}

sub change_and_verify_password ($user, $old_pass, $new_pass) {
    # Change password
    assert_script_run("sshpass -p '$old_pass' ssh -o StrictHostKeyChecking=no $user\@localhost 'echo -e \"$old_pass\\n$new_pass\\n$new_pass\" | passwd'");

    # Verify password change
    validate_script_output("ldapwhoami -x -H ldap://ldapserver -D uid=$user,ou=users,dc=sssdtest,dc=com -w $new_pass", sub { m/$user/ });

    # Verify login with new password
    assert_script_run("sshpass -p '$new_pass' ssh -o StrictHostKeyChecking=no $user\@localhost 'echo \"Password changed successfully!\" > /tmp/passwd_change_verified'");
    validate_script_output('cat /tmp/passwd_change_verified', sub { m/Password changed successfully/ });
}

sub run ($self) {
    select_serial_terminal;

    my $container_engine = "podman";
    if (is_sle('<16')) {
        $container_engine = "docker" if is_sle("<15-SP5");
        is_sle('<15') ? add_suseconnect_product("sle-module-containers", 12) : add_suseconnect_product("sle-module-containers");
    }
    install_dependencies($container_engine);
    setup_389ds_container($container_engine);
    configure_sssd_client($container_engine);

    #execute test cases
    #get remote user indentity
    validate_script_output("id alice", sub { m/uid=9998\(alice\)/ });
    #remote user authentification test
    assert_script_run("pam-config -a --sss --mkhomedir");

    run_online_tests($container_engine);
    run_offline_tests($container_engine);
}

sub run_online_tests ($container_engine) {
    select_console 'root-console';

    user_test();

    # Change password of remote user 'alice'
    change_and_verify_password('alice', 'open5use', 'n0vell88');

    # Sudo run a command as another user
    assert_script_run("echo 'Defaults !targetpw' >/etc/sudoers.d/notargetpw");
    assert_script_run("sshpass -p 'open5use' ssh -o StrictHostKeyChecking=no mary\@localhost 'echo open5use | sudo -S -l > /tmp/sudouser'");
    validate_script_output('cat /tmp/sudouser', sub { m#/usr/bin/cat# });

    assert_script_run(qq(su -c 'echo "file read only by owner alice" > hello && chmod 600 hello' -l alice));
    sudo_user_test();

    # Change back password of remote user 'alice'
    change_and_verify_password('alice', 'n0vell88', 'open5use');
}

sub run_offline_tests ($container_engine) {

    assert_script_run("$container_engine stop ds389_container");

    validate_script_output("id alice", sub { m/uid=9998\(alice\)/ });
    user_test();
    sudo_user_test();
}

sub user_test {
    assert_script_run("sshpass -p 'open5use' ssh -o StrictHostKeyChecking=no mary\@localhost 'whoami > /tmp/mary'");
    validate_script_output('cat /tmp/mary', sub { m/mary/ });
}

sub sudo_user_test {
    assert_script_run("sshpass -p 'open5use' ssh -o StrictHostKeyChecking=no mary\@localhost 'echo open5use | sudo -S -u alice /usr/bin/cat /home/alice/hello > /tmp/readonly'");
    validate_script_output('cat /tmp/readonly', sub { m/file read only by owner alice/ });
}
sub test_flags {
    return {always_rollback => 1};
}

1;
