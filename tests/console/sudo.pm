# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sudo expect
# Summary: sudo test
#          - single command
#          - I/O redirection
#          - starting a shell
#          - environment variables
#          - sudoers configuration
#          https://www.suse.com/documentation/sles-12/singlehtml/book_sle_admin/book_sle_admin.html#cha.adm.sudo
# Maintainer: Jozef Pupava <jpupava@suse.com>


use base "consoletest";
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils qw(is_sle is_public_cloud);
use publiccloud::utils qw(is_azure is_byos);

my $test_password = 'Sud0_t3st';
my $parm_user = '';

sub sudo_with_pw {
    my ($command, %args) = @_;
    my ($grep, $env);
    $grep = '|grep ' . $args{grep} if defined $args{grep};
    $env = "set $args{env};" if defined $args{env};
    my $password = $args{password} //= $testapi::password;
    assert_script_run 'sudo -K';
    if ($command =~ /sudo -i|sudo -s|sudo su/) {
        enter_cmd "expect -c 'spawn $command;expect \"password\" {send \"$password\\r\";interact'} default {exit 1}";
        sleep 2;
    }
    else {
        assert_script_run("expect -c '${env}spawn $command;expect \"password\" {send \"$password\\r\";interact} default {exit 1}'$grep", timeout => $args{timeout});
    }
}

sub test_sudoers {
    my ($sudo_password) = @_;
    assert_script_run 'sudo journalctl -n10 --no-pager';
    sudo_with_pw 'sudo zypper -n in -f yast2', password => $sudo_password, timeout => 300;
}

sub prepare_sudoers {
    my $root_no_pass = shift // 0;
    $parm_user = ' (root)' if $root_no_pass;
    assert_script_run "echo 'bernhard ALL =$parm_user NOPASSWD: /usr/bin/journalctl, /usr/bin/dd, /usr/bin/cat, PASSWD: /usr/bin/zypper, /usr/bin/su, /usr/bin/id, /bin/bash' >/etc/sudoers.d/test";
    # use script_run because yes is still writing to the pipe and then command is exiting with 141
    script_run "groupadd sudo_group && useradd -m -d /home/sudo_test -G sudo_group,\$(stat -c %G /dev/$serialdev) sudo_test && yes $test_password|passwd -q sudo_test";
    assert_script_run "echo '%sudo_group ALL =$parm_user NOPASSWD: /usr/bin/journalctl, PASSWD: /usr/bin/zypper' >/etc/sudoers.d/sudo_group";
}

sub full_test {
    select_console 'user-console';
    # check if password is required
    assert_script_run 'sudo -K && ! timeout 5 sudo id -un';
    assert_script_run "(! sudo -n id -un) 2>&1 | grep -e '.*password .*required'";
    # single command
    assert_script_run 'id -un|grep ^bernhard';
    sudo_with_pw 'sudo id -un', grep => '^root';
    # I/O redirection; the redirection happens as user, not in sudo context, so should fail
    sudo_with_pw 'sudo echo 2 >/run/openqa_sudo_test';
    # confirm that the I/O redirection above indeed did not write to the file
    assert_script_run 'grep 1 /run/openqa_sudo_test';
    # fail with permission denied
    script_run 'sudo cat 2> check_err.log </proc/1/maps';
    assert_script_run 'grep -i "permission denied" check_err.log';
    assert_script_run 'echo 3 | sudo dd of=/run/openqa_sudo_test';
    assert_script_run 'grep 3 /run/openqa_sudo_test';
    assert_script_run 'sudo dd if=/proc/1/maps|cat|grep lib';
    # starting shell
    sudo_with_pw 'sudo -i';
    assert_script_run 'whoami|grep ^root';
    assert_script_run 'pwd|grep /root';
    enter_cmd "exit", wait_still_screen => 3;
    sudo_with_pw 'sudo -s';
    assert_script_run 'whoami|grep ^root';
    assert_script_run 'pwd|grep /home/bernhard';
    enter_cmd "exit", wait_still_screen => 3;
    # environment variables
    assert_script_run 'ENVVAR=test132 env | grep ENVVAR=test132';
    sudo_with_pw 'sudo env', grep => '-v ENVVAR=test132', env => 'ENVVAR test132';
    # sudoers configuration
    test_sudoers;
    become_root;
    assert_script_run 'test -f /etc/sudoers || (cp /usr/etc/sudoers /etc/sudoers && touch /tmp/sudoers.copied)';
    enter_cmd 'exit';
    sudo_with_pw 'sudo sed -i "s/^Defaults\[\[\:space\:\]\]*targetpw/Defaults\ !targetpw/" /etc/sudoers';
    sudo_with_pw 'sudo sed -i "s/^ALL\[\[\:space\:\]\]*ALL/#ALL ALL/" /etc/sudoers';
    sudo_with_pw 'sudo su - sudo_test';
    test_sudoers $test_password;
    sudo_with_pw 'bash -c "sudo su - sudo_test 2>check_err.log"', password => "$test_password";
    assert_script_run 'grep -i "not allowed" check_err.log';
    enter_cmd "exit", wait_still_screen => 3;
}

sub run {
    select_console 'root-console';
    zypper_call 'in sudo expect';
    select_console 'user-console';
    # Check if sudo asks for the root password.
    # On Azure from SLE15 onwards, 'Defaults targetpw' is disabled. There sudo is expected to ask for the user password
    my $exp_user = (is_azure && is_sle(">=15")) ? "$testapi::username" : "root";
    validate_script_output("expect -c 'spawn sudo id -un;expect \"password for $exp_user\" {send \"$testapi::password\\r\";interact}'", sub { $_ =~ m/^root$/m });

    foreach my $num (0, 1) {
        record_info "iteration $num";
        select_console 'root-console';
        # Prepare a file with content '1' for later IO redirection test
        assert_script_run 'echo 1 >/run/openqa_sudo_test';
        prepare_sudoers("$num");
        full_test;
    }
}

sub post_run_hook {
    select_console 'root-console';
    # change sudoers back to default
    assert_script_run 'sed -i "s/^Defaults\[\[\:space\:\]\]*\!targetpw/Defaults\ targetpw/" /etc/sudoers';
    assert_script_run 'sed -i "s/^#ALL\[\[\:space\:\]\]*ALL/ALL ALL/" /etc/sudoers';
    assert_script_run 'rm -f /etc/sudoers.d/test /etc/sudoers.d/sudo_group';
    script_run 'test -f /tmp/sudoers.copied && rm /etc/sudoers /tmp/sudoers.copied';
    # remove test user
    assert_script_run 'userdel -r sudo_test && groupdel sudo_group';
}

sub post_fail_hook {
    script_run('tar -cf /var/tmp/sudoers.tmp /etc/sudoers');
    upload_logs('/var/tmp/sudoers.tmp');
}

1;
