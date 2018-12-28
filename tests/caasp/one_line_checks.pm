# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run simple checks after installation
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use version_utils 'is_caasp';

sub run_rcshell_checks {
    # Check that system is using UTC timezone
    assert_script_run 'date +"%Z" | grep -x UTC';
}

sub run_common_checks {
    # bsc#1019652 - Check that snapper is configured
    assert_script_run "snapper list";

    # bsc#1051762 - Docker is on btrfs partition (kubeadm role uses CRI-O)
    assert_script_run('stat -fc %T /var/lib/docker | grep -q btrfs') unless check_var('SYSTEM_ROLE', 'kubeadm');

    # Subvolume check - https://build.opensuse.org/request/show/583954
    assert_script_run "btrfs subvolume show /var";
}

sub run_caasp_checks {
    unless (check_var('SYSTEM_ROLE', 'plain')) {
        # poo#18668 - Check ntp client configuration
        assert_script_run 'grep "^pool ns.openqa.test" /etc/chrony.conf';
    }

    if (check_var('SYSTEM_ROLE', 'worker')) {
        # poo#16574 - Check salt master configuration
        assert_script_run "grep \"master: 'dashboard-url'\" /etc/salt/minion.d/master.conf";
    }

    if (check_var('SYSTEM_ROLE', 'admin')) {
        # Check we are running ntp server
        if (script_run 'grep "^allow" /etc/chrony.conf') {
            record_soft_failure 'bsc#1118473';
        }
        # check if installation script was executed https://trello.com/c/PJqM8x0T
        assert_script_run 'zgrep manifests/activate.sh /var/log/YaST2/y2log-1.gz';
        # bsc#1039863 - Check we are running only sles12 docker images
        assert_script_run '! docker images | sed 1d | grep -v ^registry.suse.com/sles12';
    }
}

sub run_kubic_checks {
    # Should not include any container runtime
    if (check_var('SYSTEM_ROLE', 'microos')) {
        assert_script_run 'which docker';
        assert_script_run '! zypper se -i kubernetes';
        assert_script_run '! rpm -q etcd';
    }
    # Should have unconfigured Kubernetes & container runtime environment
    if (check_var('SYSTEM_ROLE', 'kubeadm')) {
        assert_script_run 'which crio';
        assert_script_run 'zypper se -i kubernetes';
    }
}

sub run {
    run_rcshell_checks;
    return if get_var('EXTRA', '') =~ /RCSHELL/;

    run_common_checks;
    run_caasp_checks if is_caasp('caasp');
    run_kubic_checks if is_caasp('kubic');
}

1;
