# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: openssh expect netcat-openbsd psmisc shadow coreutils
# Summary: Test to verify sshd starts and accepts connections.
#  We need this test to succeed for followup tests using ssh localhost
#  This regression test has also an interactive part (in VirtIO console)
#   * Systemd unit is checked
#   * The default port is checked on both IPv4 and IPv6
#   * Password authentication is tested
#   * Publik key authentication is tested
#   * SSH Interactive mode is tested using VirtIO console
#   * Utilities ssh-keygen and ssh-copy-id are used
#   * Local and remote port forwarding are tested
#   * The SCP is tested by copying various files
#
# Maintainer: Pavel Dostál <pdostal@suse.cz>
# Tags: poo#65375, poo#68200

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use utils qw(systemctl exec_and_insert_password zypper_call random_string clear_console);
use version_utils qw(is_upgrade is_sle is_tumbleweed is_leap is_opensuse);
use services::sshd;
use ssh_crypto_policy;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Backup/rename ~/.ssh , generated in consotest_setup, to ~/.ssh_bck
    # poo#68200. Confirm the ~/.ssh directory is exist in advance, in order to avoid the null backup
    assert_script_run 'if [ -d ~/.ssh ]; then mv ~/.ssh ~/.ssh_bck; fi';

    # Backup the /etc/ssh/sshd_config
    assert_script_run 'cp /etc/ssh/sshd_config{,_before}';

    # new user to test sshd
    my $ssh_testman        = "sshboy";
    my $ssh_testman_passwd = get_var('PUBLIC_CLOUD') ? random_string(8) : 'let3me2in1';

    # Allow password authentication for $ssh_testman
    assert_script_run(qq(echo -e "Match User $ssh_testman\\n\\tPasswordAuthentication yes" >> /etc/ssh/sshd_config)) if (get_var('PUBLIC_CLOUD'));

    # Install software needed for this test module
    zypper_call("in netcat-openbsd expect psmisc");

    # Stop the firewall if it's available
    if (is_upgrade && check_var('ORIGIN_SYSTEM_VERSION', '11-SP4')) {
        record_info("SuSEfirewall2 not available", "bsc#1090178: SuSEfirewall2 service is not available after upgrade from SLES11 SP4 to SLES15");
    }
    else {
        systemctl('stop ' . $self->firewall) if (script_run("which " . $self->firewall) == 0);
    }

    # Restart sshd and check it's status
    systemctl 'restart sshd';
    systemctl 'status sshd';

    # Check that the daemons listens on right addresses/ports
    services::sshd::check_sshd_port();

    # create a new user to test sshd
    my $changepwd = $ssh_testman . ":" . $ssh_testman_passwd;
    assert_script_run("useradd -m $ssh_testman");
    assert_script_run("echo $changepwd | chpasswd");
    assert_script_run("usermod -aG \$(stat -c %G /dev/$serialdev) $ssh_testman");

    # avoid harmless failures in virtio-console due to unexpected PS1
    assert_script_run("echo \"PS1='# '\" >> ~$ssh_testman/.bashrc") unless check_var('VIRTIO_CONSOLE', '0');

    # Make interactive SSH connection as the new user
    enter_cmd "expect -c 'spawn ssh $ssh_testman\@localhost -t;expect \"Are you sure\";send yes\\n;expect sword:;send $ssh_testman_passwd\\n;expect #;send \\n;interact'";
    sleep(1);

    # Check that we are really in the SSH session
    assert_script_run 'echo $SSH_TTY | grep "\/dev\/pts\/"';
    assert_script_run 'ps ux | egrep ".* \? .* sshd\:"';
    assert_script_run "whoami | grep $ssh_testman";
    assert_script_run "mkdir .ssh";

    # Exit properly and check we're root again
    script_run("exit", 0);
    assert_script_run "whoami | grep root";

    # Generate RSA key for root and the user
    assert_script_run "ssh-keygen -t rsa -P '' -C 'root\@localhost' -f ~/.ssh/id_rsa";
    assert_script_run "su -c \"ssh-keygen -t rsa -P '' -C '$ssh_testman\@localhost' -f /home/$ssh_testman/.ssh/id_rsa\" $ssh_testman";

    # Make sure user has both public keys in authorized_keys
    assert_script_run "su -c \"cp /home/$ssh_testman/.ssh/{id_rsa.pub,authorized_keys}\"";
    assert_script_run "cat ~/.ssh/id_rsa.pub >> /home/$ssh_testman/.ssh/authorized_keys";

    # Test non-interactive SSH
    assert_script_run "ssh -4v $ssh_testman\@localhost bash -c 'whoami | grep $ssh_testman'";

    # Port forwarding (bsc#1131709 bsc#1133386)
    assert_script_run "echo 'sshd.pm: Testing port forwarding' | logger";
    assert_script_run "( ssh -vNL 4242:localhost:22 $ssh_testman\@localhost & )";
    assert_script_run "( ssh -vNR 0.0.0.0:5252:localhost:22 $ssh_testman\@localhost & )";
    assert_script_run 'until ss -tulpn|grep sshd|egrep "4242|5252";do sleep 1;done';

    # Scan public keys on forwarded ports
    assert_script_run "ssh-keyscan -p 4242 localhost >> ~/.ssh/known_hosts";
    assert_script_run "ssh-keyscan -p 5252 localhost >> ~/.ssh/known_hosts";

    # Connect to forwarded ports
    assert_script_run "ssh -v -p 4242 $ssh_testman\@localhost whoami";
    assert_script_run "ssh -v -p 5252 $ssh_testman\@localhost whoami";

    # Copy the list of known hosts to $ssh_testman's .ssh directory
    assert_script_run "install -m 0400 -o $ssh_testman ~/.ssh/known_hosts /home/$ssh_testman/.ssh/known_hosts";

    # Test SSH command within SSH command
    assert_script_run "ssh -v -p 4242 -tt $ssh_testman\@localhost ssh -tt $ssh_testman\@localhost whoami";

    # Test ProxyCommand option
    assert_script_run "ssh -v -t -o ProxyCommand='ssh -v $ssh_testman\@localhost nc localhost 4242' $ssh_testman\@localhost whoami";

    # Test JumpHost option
    if (is_leap('15.0+') || is_tumbleweed || is_sle('15+')) {
        assert_script_run("ssh -v -J $ssh_testman\@localhost:4242 $ssh_testman\@localhost whoami");
    }

    # SCP (poo#46937)
    assert_script_run "echo 'sshd.pm: Testing SCP subsystem' | logger";
    assert_script_run "scp -4v $ssh_testman\@localhost:/etc/resolv.conf /tmp";
    assert_script_run "scp -4v '$ssh_testman\@localhost:/etc/{group,passwd}' /tmp";
    assert_script_run "scp -4v '$ssh_testman\@localhost:/etc/ssh/*.pub' /tmp";

    # poo#80716 Test all available ciphers, key exchange algorithms, host key algorithms and mac algorithms.
    assert_script_run "echo 'sshd.pm: Testing cryptographic policies' | logger";
    test_cryptographic_policies(remote_user => $ssh_testman);

    # Restore ~/.ssh generated in consotest_setup
    # poo#68200. Confirm the ~/.ssh_bck directory is exist in advance and then restore, in order to avoid the null restore
    assert_script_run 'rm -rf ~/.ssh';
    assert_script_run 'if [ -d ~/.ssh_bck ]; then mv ~/.ssh_bck ~/.ssh; fi';

    # Restore the /etc/ssh/sshd_config
    assert_script_run 'cp /etc/ssh/sshd_config{_before,}';

    # Kill $ssh_testman to stop all SSH sessions
    assert_script_run "killall -u $ssh_testman || true";
    wait_still_screen 3;

    record_info("Restart sshd", "Restart sshd.service");
    systemctl("restart sshd");

    # Clear the remains from background commands
    clear_console if !is_serial_terminal;
}

sub test_cryptographic_policies() {
    my %args        = @_;
    my $remote_user = $args{remote_user};

    # TODO: This does not work for Tumbleweed because of nmap
    # See pull request #11930 for more details
    my @crypto_params = (["Ciphers", "cipher", "-c "], ["KexAlgorithms", "kex", "-o kexalgorithms="], ["MACS", "mac", "-m "]);
    push(@crypto_params, ["HostKeyAlgorithms", "key", "-o HostKeyAlgorithms="]) unless (is_opensuse);
    my @policies;

    # Create an array of the different cryptographic policies that will be tested
    for my $i (0 .. $#crypto_params) {
        my $obj = ssh_crypto_policy->new(name => $crypto_params[$i][0], query => $crypto_params[$i][1], cmd_option => $crypto_params[$i][2]);
        push(@policies, $obj);
    }

    # Add all available algorithms to sshd_config
    foreach my $policy (@policies) {
        $policy->add_to_sshd_config();
    }

    record_info("Restart sshd", "Restart sshd.service");
    systemctl("restart sshd");

    # Add all the ssh public key hashes as known hosts
    assert_script_run("ssh-keyscan -H localhost > ~/.ssh/known_hosts");

    # Test all the policies
    foreach my $policy (@policies) {
        $policy->test_algorithms(remote_user => $remote_user);
    }
}

sub check_journal {
    # bsc#1175310 bsc#1181308 - Detect serious errors as they can be invisible because sshd may silently recover
    if (script_run("journalctl -b -u sshd.service | grep -A6 -B24 'segfault\\|fatal'") == 0) {
        my $journalctl = script_output("journalctl -b -u sshd.service | grep 'segfault\\|fatal'", proceed_on_failure => 1);
        if (is_sle('<15') && $journalctl =~ /diffie-hellman-group1-sha1/) {
            record_info("diffie-hellman-group1-sha1", "Expected message - bsc#1185584 diffie-hellman-group1-sha1 is not enabled on this product");
        } else {
            die("Please check the journalctl! Segfault or fatal journal entry detected.");
        }
    }
}

sub post_run_hook {
    my $self = shift;
    check_journal();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    check_journal();
    $self->SUPER::post_fail_hook;
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {milestone => 0, no_rollback => 1} : {milestone => 1, fatal => 1};
}

1;
