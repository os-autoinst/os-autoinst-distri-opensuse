# SUSE's openQA tests
#
# Copyright 2019-2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: saptune testing with mr_test, setup mr_test environments and load mr_test
#          mr_test repo: https://gitlab.suse.de/qa/mr_test
# Maintainer: QE-SAP <qe-sap@suse.de>, Ricardo Branco <rbranco@suse.de>, llzhao <llzhao@suse.com>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils;
use version_utils 'is_sle';
use Utils::Architectures;
use Utils::Systemd qw(systemctl);
use strict;
use warnings;
use mr_test_lib qw(load_mr_tests);

sub reboot_wait {
    my ($self) = @_;

    $self->reboot;

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
    # saptune is not installed by default on SLES4SAP 12 on ppc64le and in textmode profile
    zypper_call "-n in saptune" if ((is_ppc64le() and is_sle('<15')) or check_var('DESKTOP', 'textmode'));
    if (systemctl("-q is-active sapconf.service", ignore_failure => 1)) {
        record_soft_failure("bsc#1190787 - sapconf is not started");
        zypper_call "in sapconf";
    }
    # Install mr_test dependencies
    # 'zypper_call "-n in python3-rpm"' returns error message:
    #   "There are running programs which still use files and libraries deleted or updated by recent upgrades.
    #   They should be restarted to benefit from the latest updates.
    #   Run 'zypper ps -s' to list these programs."
    zypper_call "in python3-rpm", exitcode => [0, 106];
    # Download mr_test and extract it to $HOME
    assert_script_run "curl -sk $tarball | tar zxf - --strip-components 1";
    # Add $HOME to $PATH
    assert_script_run "echo 'export PATH=\$PATH:\$HOME' >> /root/.bashrc";
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
    }
    $self->reboot_wait;
}

sub run {
    my ($self) = @_;

    $self->setup;

    my $test_list = get_required_var("MR_TEST");
    record_info("MR_TEST=$test_list");
    mr_test_lib::load_mr_tests("$test_list");
}

1;
