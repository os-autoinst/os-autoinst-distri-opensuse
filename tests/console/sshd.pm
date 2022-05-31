# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

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
# Tags: poo#65375, poo#68200, poo#104415

use warnings;
use base "consoletest";
use strict;
use testapi qw(is_serial_terminal :DEFAULT);
use utils qw(systemctl exec_and_insert_password zypper_call random_string clear_console);
use version_utils qw(is_upgrade is_sle is_tumbleweed is_leap is_opensuse);
use services::sshd;
use ssh_crypto_policy;

# The test disables the firewall, if true reenable afterwards.
my $reenable_firewall = 0;

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    my $ssh_testman = "sshboy";
    services::sshd::prepare_test_data();
    # Stop the firewall if it's available
    if (is_upgrade && check_var('ORIGIN_SYSTEM_VERSION', '11-SP4')) {
        record_info("SuSEfirewall2 not available", "bsc#1090178: SuSEfirewall2 service is not available after upgrade from SLES11 SP4 to SLES15");
    }
    elsif (script_run('systemctl is-active ' . $self->firewall) == 0) {
        $reenable_firewall = 1;
        systemctl('stop ' . $self->firewall);
    }

    #  Restart sshd and check it's status
    my $ret = systemctl('restart sshd', ignore_failure => 1);
    my $fips_enabled = script_output('cat /proc/sys/crypto/fips_enabled', proceed_on_failure => 1) eq '1';

    # If restarting sshd service is not successful and fips is enabled, we have encountered bsc#1189534
    if (($ret != 0) && $fips_enabled && is_sle("=15-SP2")) {
        record_soft_failure("bsc#1189534");
        return;
    }

    systemctl 'status sshd';
    services::sshd::ssh_basic_check();

    # poo#80716 Test all available ciphers, key exchange algorithms, host key algorithms and mac algorithms.
    assert_script_run "echo 'sshd.pm: Testing cryptographic policies' | logger";
    test_cryptographic_policies(remote_user => $ssh_testman);

    # do the sshd test cleanup
    services::sshd::do_ssh_cleanup();
}

sub test_cryptographic_policies() {
    my %args = @_;
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
    $self->cleanup();
    $self->SUPER::post_run_hook;
}

sub post_fail_hook {
    my $self = shift;
    $self->cleanup();
    $self->SUPER::post_fail_hook;
}

sub cleanup() {
    my $self = shift;
    systemctl('start ' . $self->firewall) if $reenable_firewall;
    # Show debug log contents
    script_run('cat /tmp/ssh_log*');
    script_run('rm -f /tmp/ssh_log*');
    check_journal();
}

sub test_flags {
    return get_var('PUBLIC_CLOUD') ? {milestone => 0, no_rollback => 1} : {milestone => 1, fatal => 1};
}

1;
