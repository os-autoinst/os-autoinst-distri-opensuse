# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Set system hostname for test environment
# - Prevent DHCP from resetting hostname
# - Set hostname via hostnamectl
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use utils;

sub run {
    select_console 'root-console';

    # Prevent HOSTNAME from being reset by DHCP
    if (script_run('test -f /etc/sysconfig/network/dhcp') == 0) {
        file_content_replace('/etc/sysconfig/network/dhcp', 'DHCLIENT_SET_HOSTNAME="yes"' => 'DHCLIENT_SET_HOSTNAME="no"');
    }

    # Multi-machine tests need DHCP renewal to register the hostname with
    # the support server's DNS so other nodes can resolve it.
    set_hostname(get_var('HOSTNAME', 'susetest'), restart_network => check_var('NICTYPE', 'tap'));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
