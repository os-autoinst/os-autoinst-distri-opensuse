# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: iproute2 systemd
# Summary: smoke test for autoyast post-installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use version_utils 'is_opensuse';

sub run {
    select_serial_terminal;

    record_info('INFO', 'Check environment');
    assert_script_run "env | grep \"SHELL=/bin/bash\"";
    assert_script_run "env | grep \"HOME=\/root\"";
    assert_script_run "env | grep \"OSTYPE=linux\"";

    record_info('INFO', 'Check user');
    assert_script_run "id -u $username |grep 1000";

    if (is_opensuse()) {
        # opensuse_gnome has simpler configuration and timezone or network are not defined
        record_info('INFO', 'Check firewall is not enabled and not running');
        my $service = opensusebasetest::firewall();
        assert_script_run qq{systemctl status $service | grep \"active \(running\)\"};
        assert_script_run qq{systemctl is-enabled $service | grep enabled};

        record_info('INFO', 'Verify networking');
        assert_script_run "ip link show | grep -E \"(ens|enp|eth)[0-9]\" | grep UP";
    }
    else {
        record_info('INFO', 'Check firewall is enabled and running');
        assert_script_run qq{systemctl is-active firewalld.service};
        assert_script_run qq{systemctl is-enabled firewalld.service | grep enabled};

        record_info('INFO', 'Check timezone is set correctly');
        assert_script_run "timedatectl | grep Berlin";

        record_info('INFO', 'Verify networking');
        assert_script_run "ip link show eth0 | grep UP";
    }
}

1;
