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
use caasp 'script_retry';
use version_utils 'is_caasp';

sub run {
    # Check that system is using UTC timezone
    assert_script_run 'date +"%Z" | grep -x UTC';

    return if get_var('EXTRA', '') =~ /RCSHELL/;

    # bsc#1019652 - Check that snapper is configured
    assert_script_run "snapper list";

    # Subvolume check
    if (is_caasp '4.0+') {
        assert_script_run "btrfs subvolume show /var";
    }
    else {
        # https://build.opensuse.org/request/show/583954
        assert_script_run "btrfs subvolume show /var/lib/cni";
    }

    # kubeadm role uses CRI-O
    unless (check_var('SYSTEM_ROLE', 'kubeadm')) {
        # bsc#1051762 - Docker is on btrfs partition
        assert_script_run 'stat -fc %T /var/lib/docker | grep -q btrfs';
    }

    if (check_var('SYSTEM_ROLE', 'worker')) {
        # poo#16574 - Check salt master configuration
        assert_script_run "grep \"master: 'dashboard-url'\" /etc/salt/minion.d/master.conf";
        # poo#18668 - Check ntp client configuration
        assert_script_run 'grep "^NTP=dashboard-url" /etc/systemd/timesyncd.conf';
    }

    if (check_var('SYSTEM_ROLE', 'admin')) {
        if (is_caasp 'caasp') {
            # check if installation script was executed https://trello.com/c/PJqM8x0T
            assert_script_run 'zgrep manifests/activate.sh /var/log/YaST2/y2log-1.gz';
            # bsc#1039863 - Check we are running only sles12 docker images
            assert_script_run '! docker images | sed 1d | grep -v ^sles12';
            # Check that ntp config from installer was applied
            assert_script_run 'grep "^server ns.openqa.test" /etc/ntp.conf';
        }
        # Velum is running
        script_retry 'curl -kLI localhost | grep _velum_session';
    }

    # Checks are applicable only on Kubic now
    if (is_caasp '4.0+') {
        assert_script_run 'which docker';

        # Should have unconfigured Kubernetes & container runtime environment
        if (check_var('SYSTEM_ROLE', 'plain')) {
            assert_script_run 'zypper se -i kubernetes | tee /dev/tty | grep -c kubernetes | grep 6';
            assert_script_run 'rpm -q etcd';
        }

        # Should not include any container runtime
        if (check_var('SYSTEM_ROLE', 'microos')) {
            assert_script_run '! zypper se -i kubernetes';
            assert_script_run '! rpm -q etcd';
        }
    }
}

1;
