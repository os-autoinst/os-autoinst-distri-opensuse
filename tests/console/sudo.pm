# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
use version_utils 'is_sle';

sub sudo_with_pw {
    my ($command, %args) = @_;
    my ($grep, $env);
    $grep = '|grep ' . $args{grep} if defined $args{grep};
    $env  = "set $args{env};"      if defined $args{env};
    my $password = $args{password} //= $testapi::password;
    assert_script_run 'sudo -K';
    if ($command =~ /sudo -i|sudo -s|sudo su/) {
        type_string "expect -c 'spawn $command;expect \"password\";send \"$password\\r\";interact'\n";
        sleep 2;
    }
    else {
        assert_script_run "expect -c '${env}spawn $command;expect \"password\";send \"$password\\r\";interact'$grep";
    }
}

sub test_sudoers {
    my ($sudo_password) = @_;
    assert_script_run 'sudo journalctl -n10 --no-pager';
    sudo_with_pw 'sudo zypper -n in -f yast2', password => $sudo_password;
}

sub run {
    my $test_password = 'Sud0_t3st';
    select_console 'root-console';
    zypper_call 'in sudo expect';
    # set drop_caches to 1 for later IO redirection test
    assert_script_run 'echo 1 >/proc/sys/vm/drop_caches';
    # prepare sudoers and test user
    assert_script_run 'echo "bernhard ALL = (root) NOPASSWD: /usr/bin/journalctl, /usr/bin/dd, /usr/bin/cat, PASSWD: /usr/bin/zypper, /usr/bin/su" >/etc/sudoers.d/test';
    # use script_run because yes is still writing to the pipe and then command is exiting with 141
    script_run "groupadd sudo_group && useradd -m -d /home/sudo_test -G sudo_group,\$(stat -c %G /dev/$serialdev) sudo_test && yes $test_password|passwd -q sudo_test";
    assert_script_run 'echo "%sudo_group ALL = (root) NOPASSWD: /usr/bin/journalctl, PASSWD: /usr/bin/zypper" >/etc/sudoers.d/sudo_group';
    select_console 'user-console';
    # single command
    assert_script_run 'id -un|grep ^bernhard';
    sudo_with_pw 'sudo id -un', grep => '^root';
    # I/O redirection
    sudo_with_pw 'sudo echo 2 >/proc/sys/vm/drop_caches';
    assert_script_run 'grep 1 /proc/sys/vm/drop_caches';
    # fail with permission denied
    if (is_sle('=12-sp1')) {
        record_soft_failure 'bsc#1130159';
    }
    else {
        script_run 'sudo cat 2> check_err.log </proc/1/maps';
        assert_script_run 'grep -i "permission denied" check_err.log';
    }
    assert_script_run 'echo 2 | sudo dd of=/proc/sys/vm/drop_caches';
    assert_script_run 'grep 2 /proc/sys/vm/drop_caches';
    assert_script_run 'sudo dd if=/proc/1/maps|cat|grep lib';
    # starting shell
    sudo_with_pw 'sudo -i';
    assert_script_run 'whoami|grep ^root';
    assert_script_run 'pwd|grep /root';
    type_string "exit\n";
    sudo_with_pw 'sudo -s';
    assert_script_run 'whoami|grep ^root';
    assert_script_run 'pwd|grep /home/bernhard';
    type_string "exit\n";
    # environment variables
    assert_script_run 'ENVVAR=test132 env | grep ENVVAR=test132';
    sudo_with_pw 'sudo env', grep => '-v ENVVAR=test132', env => 'ENVVAR test132';
    # sudoers configuration
    test_sudoers;
    sudo_with_pw 'sudo sed -i "s/^Defaults\[\[\:space\:\]\]*targetpw/Defaults\ !targetpw/" /etc/sudoers';
    sudo_with_pw 'sudo sed -i "s/^ALL\[\[\:space\:\]\]*ALL/#ALL ALL/" /etc/sudoers';
    sudo_with_pw 'sudo su - sudo_test';
    test_sudoers $test_password;
    sudo_with_pw 'bash -c "sudo su - sudo_test 2>check_err.log"', password => "$test_password";
    assert_script_run 'grep -i "not allowed" check_err.log';
    type_string "exit\n";
}

sub post_run_hook {
    select_console 'root-console';
    # change sudoers back to default
    assert_script_run 'sed -i "s/^Defaults\[\[\:space\:\]\]*\!targetpw/Defaults\ targetpw/" /etc/sudoers';
    assert_script_run 'sed -i "s/^#ALL\[\[\:space\:\]\]*ALL/ALL ALL/" /etc/sudoers';
    assert_script_run 'rm -f /etc/sudoers.d/test /etc/sudoers.d/sudo_group';
    # remove test user
    assert_script_run 'userdel -r sudo_test && groupdel sudo_group';
}

1;
