# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify hostname is setup according options selected in the installer.
# - Verify variable DHCLIENT_SET_HOSTNAME is set to 'no'
# - Verify hostname is of the form linux-xxxx https://github.com/openSUSE/linuxrc/blob/master/linuxrc_hostname.md,
# which means that is not taken into account dhcp configuration provided for this test via NICTYPE_USER_OPTIONS=hostname=myguest
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;

sub run {
    select_console 'root-console';
    assert_script_run 'grep DHCLIENT_SET_HOSTNAME=\"no\" /etc/sysconfig/network/dhcp';
    assert_script_run 'hostname | grep -E "linux-[[:alnum:]]{4}"';
}

1;
