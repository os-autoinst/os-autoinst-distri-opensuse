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
use serial_terminal 'select_serial_terminal';

sub run {
    # On ppc64le (OFW) the root-virtio-terminal is hvc1 and only gets its getty
    # from prepare_serial_console in system_prepare. Schedules that run hostname
    # before system_prepare (e.g. the yast gpt/RAID0 installation tests) would
    # otherwise wait forever for a login prompt, so keep the VGA console there.
    if (get_var('OFW')) {
        select_console 'root-console';
    }
    else {
        select_serial_terminal;
    }

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
