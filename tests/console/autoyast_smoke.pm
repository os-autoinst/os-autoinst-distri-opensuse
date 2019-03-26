# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: smoke test for autoyast post-installation
# Maintainer: Yiannis Bonatakis <ybonatakis@suse.com>

use strict;
use warnings;
use base "opensusebasetest";
use testapi;
use utils;
use y2logsstep;
use version_utils 'is_opensuse';

sub run {
    my $self = shift;
    $self->select_serial_terminal;

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
        assert_script_run qq{systemctl status $service | grep \"inactive \(dead\)\"};
        assert_script_run qq{systemctl is-enabled $service | grep disabled};

        record_info('INFO', 'Verify networking');
        assert_script_run "ip link show | grep -E \"(ens|eth)[0-9]\" | grep UP";
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
