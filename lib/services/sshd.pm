# SUSE's openQA tests
#
# Copyright 2021-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: Package for ssh service tests
#
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

package services::sshd;
use base 'opensusebasetest';
use testapi qw(is_serial_terminal :DEFAULT);
use utils;
use version_utils;
use package_utils;
use strict;
use warnings;

our @EXPORT = qw(check_sshd_port check_sshd_service prepare_test_data ssh_basic_check do_ssh_cleanup);

# The test disables the firewall, if true reenable afterwards.
my $reenable_firewall = 0;
my $ssh_testman = "sshboy";
my $ssh_testman_passwd = is_public_cloud() ? random_string(8) : 'let3me2in1';
my $changepwd = $ssh_testman . ":" . $ssh_testman_passwd;

sub check_sshd_port {
    assert_script_run q(ss -pnl4 | grep -E 'tcp.*LISTEN.*:22.*sshd');
    assert_script_run q(ss -pnl6 | grep -E 'tcp.*LISTEN.*:22.*sshd');
}

sub check_sshd_service {
    systemctl 'show -p ActiveState sshd|grep ActiveState=active';
    systemctl 'show -p SubState sshd|grep SubState=running';
}

sub prepare_test_data {
    # Backup/rename ~/.ssh , generated in consotest_setup, to ~/.ssh_bck
    assert_script_run 'if [ -d ~/.ssh ]; then mv ~/.ssh ~/.ssh_bck; fi';

    # prepare /etc/ssh configuration for openssh with default config in /usr/etc
    script_run 'test -f /usr/etc/ssh/sshd_config -a ! -f /etc/ssh/sshd_config && cp /usr/etc/ssh/sshd_config /etc/ssh/sshd_config';

    # Backup the /etc/ssh/sshd_config
    assert_script_run 'cp /etc/ssh/sshd_config{,_before}';

    # Allow password authentication for $ssh_testman
    assert_script_run(qq(echo -e "Match User $ssh_testman\\n\\tPasswordAuthentication yes" >> /etc/ssh/sshd_config)) if (is_public_cloud());

    if (script_run('rpm -q busybox-psmisc') == 0) {
        record_soft_failure("boo#1198137 - busybox-psmisc preferred by zypper");
        zypper_call("in psmisc -busybox-psmisc");
    }

    # on Micro, the 'expect' package is in the IBS QA:Head repo
    zypper_ar(get_required_var('QA_HEAD_REPO'), name => 'qa_head', no_gpg_check => 1) if is_transactional();

    # Install software needed for this test module
    install_package("netcat-openbsd expect psmisc", trup_reboot => 1);

}

sub configure_service {
    prepare_test_data();
    # stop firewalld if it's running
    if (script_run('systemctl is-active firewalld') == 0) {
        systemctl('stop firewalld');
        $reenable_firewall = 1;
    }
    systemctl('restart sshd');
}

sub check_service {
    systemctl 'is-enabled sshd.service';
    systemctl 'is-active sshd';
}

sub ssh_basic_check {
    # Check that the daemons listens on right addresses/ports
    check_sshd_port();
    # create a new user to test sshd
    script_run("userdel -rf $ssh_testman");
    assert_script_run("useradd -m $ssh_testman");
    assert_script_run("echo $changepwd | chpasswd");
    assert_script_run("usermod -aG \$(stat -c %G /dev/$serialdev) $ssh_testman");

    # avoid harmless failures in virtio-console due to unexpected PS1
    assert_script_run("echo \"PS1='# '\" >> ~$ssh_testman/.bashrc") unless check_var('VIRTIO_CONSOLE', '0');

    # Make interactive SSH connection as the new user
    # poo#205149: the sub-shell spawned via expect doesn't inherit the outer
    # shell's PROMPT_COMMAND marker hook, so fall back to classic markers
    # for this interactive region only.
    {
        my $marker_guard = $testapi::distri->pretty_serial_marker_guard(0);
        # expect's braced multi-pattern form needs real newlines between
        # clauses, so the script is a downloaded file, not one typed line.
        my $sync_marker = 'SSHRDY' . int(rand(90000) + 10000);
        # -v aids debugging; retry is safe since -o always overwrites the file.
        script_retry('curl -f -v ' . data_url('console/sshd_interactive_login.exp') . ' -o /tmp/ssh_expect.exp', retry => 3, delay => 5, timeout => 90);
        file_content_replace(
            '/tmp/ssh_expect.exp',
            '%SSH_TESTMAN%' => $ssh_testman,
            '%SSH_PASSWD%' => $ssh_testman_passwd,
            '%SYNC_MARKER%' => $sync_marker,
            '%SERIALDEV%' => $serialdev,
            '--sed-modifier' => 'g',
        );
        enter_cmd "expect -f /tmp/ssh_expect.exp";
        # See data/console/sshd_interactive_login.exp for how the marker is emitted.
        die "interactive ssh login did not complete, no $sync_marker marker seen\n"
          unless wait_serial(qr/$sync_marker-\d+/, timeout => 420);

        # Check that we are really in the SSH session
        assert_script_run 'echo $SSH_TTY | grep "\/dev\/pts\/"';
        assert_script_run 'ps ux | grep -E ".* \? .* sshd(-session)?\:"';
        assert_script_run "whoami | grep $ssh_testman";
        assert_script_run "mkdir .ssh";

        # Exit properly and check we're root again
        script_run("exit", 0);
        assert_script_run "whoami | grep root";
    }

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
    background_script_run "ssh -vNL 4242:localhost:22 $ssh_testman\@localhost 2>/tmp/ssh_log1";
    background_script_run "ssh -vNR 0.0.0.0:5252:localhost:22 $ssh_testman\@localhost 2>/tmp/ssh_log2";
    assert_script_run 'until ss -tulpn|grep sshd|grep -E "4242|5252";do sleep 1;done';

    # Scan public keys on forwarded ports
    # Add a workaround about bsc#1193275 in FIPS test
    my $output_4242 = script_output("ssh-keyscan -p 4242 localhost >> ~/.ssh/known_hosts", proceed_on_failure => 1);
    if ($output_4242 =~ /choose_kex: unsupported KEX method curve25519-sha256/) {
        record_info('bsc#1193275 - Currently the curve25519 is not FIPS approved');
    }

    my $output_5252 = script_output("ssh-keyscan -p 5252 localhost >> ~/.ssh/known_hosts", proceed_on_failure => 1);
    if ($output_5252 =~ /choose_kex: unsupported KEX method curve25519-sha256/) {
        record_info('bsc#1193275 - Currently the curve25519 is not FIPS approved');
    }

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
    assert_script_run "scp -4v $ssh_testman\@localhost:/etc/{group,passwd} /tmp";
    assert_script_run "scp -4v $ssh_testman\@localhost:/etc/ssh/*.pub /tmp";
}

sub do_ssh_cleanup {
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

sub check_function {
    ssh_basic_check();

    wait_still_screen 3;
    systemctl("restart sshd");
}

# check sshd service
sub full_sshd_check {
    configure_service();

    check_service();

    check_function();

    sshd_cleanup();
}

# Cleanup for exceptions during before and after migration
sub sshd_cleanup {
    select_console "root-console";

    do_ssh_cleanup();

    # remove user sshboy
    assert_script_run('getent passwd sshboy > /dev/null && userdel -fr sshboy');
    systemctl('start firewalld') if $reenable_firewall;
    systemctl("restart sshd");

    script_run('cat /tmp/ssh_log*');
    script_run('rm -f /tmp/ssh_log*');
}

1;
