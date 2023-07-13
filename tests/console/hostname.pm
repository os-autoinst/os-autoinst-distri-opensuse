# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: server hostname setup and check
# - Set hostname as "susetest"
# - If network is down (using ip command)
#   - Reload network
#   - Check network status
#   - Save screenshot
#   - Restart network
#   - Check status
#   - Save screenshot
# - Check network status (using ip command)
# - Save screenshot
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use version_utils "is_sle";

sub run {
    select_console 'root-console';

    # Prevent HOSTNAME from being reset by DHCP
    if (script_run('test -f /etc/sysconfig/network/dhcp') == 0) {
        file_content_replace('/etc/sysconfig/network/dhcp', 'DHCLIENT_SET_HOSTNAME="yes"' => 'DHCLIENT_SET_HOSTNAME="no"');
    }

    set_hostname(get_var('HOSTNAME', 'susetest'));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
