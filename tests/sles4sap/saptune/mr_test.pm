# SUSE's openQA tests
#
# Copyright 2019-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: saptune testing with mr_test, setup mr_test environments and load mr_test
#          mr_test repo: https://gitlab.suse.de/qa/mr_test
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>, llzhao <llzhao@suse.com>

use strict;
use warnings;
use base "sles4sap";
use autotest;
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils;
use version_utils qw(is_sle is_public_cloud);
use Utils::Architectures;
use Utils::Systemd qw(systemctl);
use mr_test_lib qw(load_mr_tests);
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::instances;
use sles4sap_publiccloud;

sub reboot_wait {
    my ($self) = @_;

    if (is_public_cloud) {
        # Reboot on publiccloud needs to happen via their dedicated reboot routine
        my $instance = publiccloud::instances::get_instance();
        $instance->softreboot(timeout => 1200);
    }
    else {
        $self->reboot;
    }

    # Wait for saptune to tune everything
    my $timeout = 60;
    sleep bmwqemu::scale_timeout($timeout);
}

sub setup {
    my ($self) = @_;

    my $tarball = get_var('MR_TEST_TARBALL', 'https://gitlab.suse.de/qa/mr_test/-/archive/master/mr_test-master.tar.gz');

    select_serial_terminal;
    # Disable packagekit
    quit_packagekit;
    # Install saptune
    zypper_call "in saptune";
    zypper_call "in sapconf";
    if (systemctl("-q is-active sapconf.service", ignore_failure => 1)) {
        record_soft_failure("bsc#1190787 - sapconf is not started");
    }
    # Install mr_test dependencies
    # 'zypper_call "-n in python3-rpm"' returns error message:
    #   "There are running programs which still use files and libraries deleted or updated by recent upgrades.
    #   They should be restarted to benefit from the latest updates.
    #   Run 'zypper ps -s' to list these programs."
    zypper_call "in python3-rpm", exitcode => [0, 106];
    # Download mr_test and extract it to $HOME
    assert_script_run "curl -sk $tarball | tar zxf - --strip-components 1" unless get_var('PUBLIC_CLOUD_SLES4SAP');
    # Add $HOME to $PATH
    assert_script_run "echo 'export PATH=\$PATH:\$HOME' >> /root/.bashrc";
    # Add '/root' to $PATH for public cloud instance
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        assert_script_run "echo 'export PATH=\$PATH:/root' >> /root/.bashrc";
        assert_script_run('. /root/.bashrc');
    }

    # Remove any configuration set by sapconf
    assert_script_run "sed -i.bak '/^@/,\$d' /etc/security/limits.conf";
    script_run "mv /etc/systemd/logind.conf.d/sap.conf{,.bak}" unless check_var('DESKTOP', 'textmode');
    systemctl '--now disable sapconf';
    assert_script_run 'saptune service enablestart';
    if (is_qemu) {
        # Ignore disk_elevator on VM's
        assert_script_run "sed -ri '/:scripts\\/disk_elevator/s/^/#/' \$(grep -F -rl :scripts/disk_elevator Pattern/)";
        # Skip nr_requests on VM's. Fix bsc#1177888
        assert_script_run 'sed -i "/:scripts\/nr_requests/s/^/#/" Pattern/SLE15/testpattern_*';
        # Skip tcp_keepalive on public cloud
        assert_script_run 'sed -i "/:\/proc\/sys\/net\/ipv4\/tcp_keepalive/s/^/#/" Pattern/SLE15/testpattern_*';
        assert_script_run 'sed -i "/:\/proc\/sys\/net\/ipv4\/tcp_keepalive/s/^/#/" Pattern/SLE12/testpattern_*';
    }
    $self->reboot_wait;
}

sub run {
    my ($self, $run_args) = @_;

    # This test module is using sles4sap and not sles4sap_publiccloud_basetest
    # as base class. network_peering_present and ansible_present are propagated here
    # to a different context than usual
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});
    $self->{ansible_present} = 1 if ($run_args->{ansible_present});
    record_info('MR_TEST CONTEXT', join(' ',
            'cleanup_called:', $self->{cleanup_called} // 'undefined',
            'network_peering_present:', $self->{network_peering_present} // 'undefined',
            'ansible_present:', $self->{ansible_present} // 'undefined')
    );

    # Preserve args for post_fail_hook
    $self->{provider} = $run_args->{my_provider};    # required for cleanup
    $self->setup;

    my $test_list = get_required_var("MR_TEST");
    record_info("MR_TEST=$test_list");
    mr_test_lib::load_mr_tests("$test_list", $run_args);
}

sub post_fail_hook {
    my ($self) = @_;
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        select_host_console(force => 1);
        my $run_args = OpenQA::Test::RunArgs->new();
        record_info('CONTEXT LOG', join(' ', 'network_peering_present:', $self->{network_peering_present} // 'undefined'));
        if ($self->{network_peering_present}) {
            delete_network_peering();
            $run_args->{network_peering_present} = $self->{network_peering_present} = 0;
        }
        $run_args->{my_provider} = $self->{provider};
        $run_args->{my_provider}->cleanup($run_args);
        return;
    }
    $self->SUPER::post_fail_hook;
}

1;
