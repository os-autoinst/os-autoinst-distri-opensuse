# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test to verify sshd starts and accepts connections.
#  We need this test to succeed for followup tests using ssh localhost
#  This regression test has also an interactive part (in VirtIO console)
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use utils qw(systemctl exec_and_insert_password);
use version_utils qw(is_virtualization_server is_upgrade);

sub run {
    my $self = shift;
    # new user to test sshd
    my $ssh_testman        = "sshboy";
    my $ssh_testman_passwd = "let3me2in1";

    select_console 'root-console';

    # Stop the firewall if it's available
    if (is_upgrade && check_var('ORIGIN_SYSTEM_VERSION', '11-SP4')) {
        record_info("SuSEfirewall2 not available", "bsc#1090178: SuSEfirewall2 service is not available after upgrade from SLES11 SP4 to SLES15");
    }
    else {
        systemctl 'stop ' . $self->firewall if !is_virtualization_server;
    }

    # Restart sshd and check it's status
    systemctl 'restart sshd';
    systemctl 'status sshd';

    # Check that the daemons listens on right addresses/ports
    assert_script_run q(ss -pnl4 | egrep 'tcp.*LISTEN.*:22.*sshd');
    assert_script_run q(ss -pnl6 | egrep 'tcp.*LISTEN.*:22.*sshd');

    # create a new user to test sshd
    my $changepwd = $ssh_testman . ":" . $ssh_testman_passwd;
    assert_script_run("useradd -m $ssh_testman");
    assert_script_run("echo $changepwd | chpasswd");

    opensusebasetest::select_serial_terminal();
    if (is_serial_terminal()) {
        # Make interactive SSH connection as the new user
        type_string "ssh -v -l $ssh_testman localhost -t\n";
        wait_serial('Are you sure you want to continue connecting (yes/no)?', undef, 0, no_regex => 1);
        type_string "yes\n";
        wait_serial('Password:', undef, 0, no_regex => 1);
        type_string "$ssh_testman_passwd\n";
        wait_serial('sshboy@susetest:~>', undef, 0, no_regex => 1);
        type_string "export PS1='# '\n";

        # Check that we are really in the SSH session
        assert_script_run 'echo $SSH_TTY | grep "\/dev\/pts\/"';
        assert_script_run 'ps ux | egrep ".* \? .* sshd\:"';
        assert_script_run "whoami | grep $ssh_testman";
        assert_script_run "mkdir .ssh";

        # Exit properly and check we're root again
        script_run("exit", 0);
        assert_script_run "whoami | grep root";
    }
    else {
        record_info("VirtIO N/A", "The VirtIO serial terminal is not available over here");
        # Since we don't have the VirtIO serial terminal we need to gather public keys manually
        assert_script_run "install -m 1700 -d ~/.ssh";
        assert_script_run "ssh-keyscan localhost 127.0.0.1 ::1 > ~/.ssh/known_hosts";
    }

    select_console 'root-console';

    # Generate RSA key for SSH and copy it to our new user's profile
    assert_script_run "ssh-keygen -t rsa -P '' -C 'localhost' -f ~/.ssh/id_rsa";
    assert_script_run "install -m 1700 -o $ssh_testman -d /home/$ssh_testman/.ssh";
    assert_script_run "install -m 0644 -o $ssh_testman ~/.ssh/id_rsa.pub /home/$ssh_testman/.ssh/authorized_keys";

    # Test non-interactive SSH and after that remove RSA keys
    assert_script_run "ssh -4v $ssh_testman\@localhost bash -c 'whoami | grep $ssh_testman'";
    assert_script_run "rm -r ~/.ssh/";
}

sub test_flags {
    return {milestone => 1};
}

1;
