# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify hostname is setup according options selected in the installer.
# - Verify variable DHCLIENT_SET_HOSTNAME is set to 'no'
# - Verify hostname is of the form linux-xxxx https://github.com/openSUSE/linuxrc/blob/master/linuxrc_hostname.md,
# which means that is not taken into account dhcp configuration provided for this test via NICTYPE_USER_OPTIONS=hostname=myguest
# Maintainer: QE YaST <qa-sle-yast@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    assert_script_run
      'grep DHCLIENT_SET_HOSTNAME=\"no\" /etc/sysconfig/network/dhcp';
    assert_script_run 'hostname | grep ' . is_sle('<=15-SP1')
      ? '-E "linux-[[:alnum:]]{4}"'
      : 'localhost';
}

1;
