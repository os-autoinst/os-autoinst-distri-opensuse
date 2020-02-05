# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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

    # Since 15SP1 DHCLIENT_SET_HOSTNAME must be disable bsc#1153402
    file_content_replace('/etc/sysconfig/network/dhcp', 'DHCLIENT_SET_HOSTNAME="yes"' => 'DHCLIENT_SET_HOSTNAME="no"') if is_sle('15-SP1+');

    set_hostname(get_var('HOSTNAME', 'susetest'));
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
