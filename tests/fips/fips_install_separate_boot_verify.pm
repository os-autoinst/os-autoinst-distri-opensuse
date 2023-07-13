# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: FIPS installation with separate boot partition,
#          We need make sure FIPS is in enabled status;
#          boot loader should add right boot partition.
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#112028

use base 'opensusebasetest';
use strict;
use warnings;
use base 'consoletest';
use testapi;

sub run {
    select_console 'root-console';

    # Make sure FIPS is enabled
    assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT.*fips=1' /etc/default/grub");
    assert_script_run("grep '^1\$' /proc/sys/crypto/fips_enabled");
    record_info 'Kernel Mode', 'FIPS kernel mode (for global) configured!';

    # Make sure there is a separate /boot partition
    assert_script_run('lsblk |grep "/boot$"');

    # Due to https://www.suse.com/support/kb/doc/?id=000019432
    # We should add the kernel parameter boot=<partition of /boot or /boot/efi>
    assert_script_run('grep "boot=" /proc/cmdline');
    record_info 'Separate boot partition';
}

1;
