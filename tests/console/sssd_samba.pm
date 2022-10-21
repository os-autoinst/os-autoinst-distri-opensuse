# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: sssd-wbclient samba coreutils
# Summary: Integration tests to sssd/samba (version conflicted libwbclient.so.0)
# Based on https://bugzilla.suse.com/show_bug.cgi?id=1162203
# The core issue was that samba has it's own version of libwbclient.so.0 but it
# is already present from winbind, which is not compatible with samba and causes
# the samba utilities to fail. So, we test to install winbind and then samba
# and check if smbclient is still working
#   * Install sssd winbind client
#   * Install (or force reinstall) samba
#   * Check if smbclient is still working
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';

sub run {
    select_serial_terminal;
    # Install sssd before samba and separately as we need to check, if the
    # libwbclient.so.0 module gets overwritten
    zypper_call 'in sssd-wbclient';
    # List affected modules before and after installing samba for debugging
    # purposes in case the test fails (check if the module got overwritten)
    script_run 'ls -l /usr/lib64/sssd/modules/';
    script_run 'md5sum /usr/lib64/sssd/modules/libwbclient.so.0';
    # Perform a force reinstall in case it is already installed to check,
    # if the modules get overwritten
    zypper_call 'in samba';
    script_run 'ls -l /usr/lib64/sssd/modules/';
    script_run 'md5sum /usr/lib64/sssd/modules/libwbclient.so.0';
    assert_script_run 'systemctl start smb';
    # Test if smbclient works
    assert_script_run 'smbclient -L localhost -N';
}

1;
