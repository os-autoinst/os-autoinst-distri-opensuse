# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Verify hostname is setup according options selected in the installer.
# - Verify variable DHCLIENT_SET_HOSTNAME is set to 'no'
# - Verify hostname is of the form linux-xxxx https://github.com/openSUSE/linuxrc/blob/master/linuxrc_hostname.md,
# which means that is not taken into account dhcp configuration provided for this test via NICTYPE_USER_OPTIONS=hostname=myguest
# Maintainer: Joaquín Rivera <jeriveramoya@suse.de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use version_utils 'is_sle';

sub run {
    select_console 'root-console';
    assert_script_run 'grep DHCLIENT_SET_HOSTNAME=\"no\" /etc/sysconfig/network/dhcp';

    # YaST tries to configure the local system hostname during installation.
    # Currently (since SLE 15 SP2) YaST configures target system hostname only if
    # it is explicitly set when booting installation with linuxrc's hostname option.
    # In all other cases no hostname is proposed and you have to set the hostname
    # later when booted into installed system.
    my $hostname = is_sle('>=15-SP2') ? 'localhost' : 'linux-[[:alnum:]]{4}';
    assert_script_run "hostname | grep -E '$hostname'";
}

1;
