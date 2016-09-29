# SUSE's FIPS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# G-Summary: Setup system work into fips mode
#    Install fips pattern and update grub.cfg with fips=1
#
#    Also include workaround of bsc#982268:
#    Due to bsc#982268, openssl couldn't enter fips mode even the
#    system is booted with fips=1. Workaround is create the file
#    /etc/system-fips manually.
# G-Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;

# Install fips pattern and update grub.cfg to boot with fips=1
sub run() {
    select_console 'root-console';

    if (!script_output "grep 'fips=1' /proc/cmdline | tee") {
        script_run 'zypper -n install --type pattern fips', 300;
        script_run 'sed -i \'/^GRUB_CMDLINE_LINUX_DEFAULT/s/\("\)$/ fips=1\1/\' /etc/default/grub';
        script_run 'grub2-mkconfig -o /boot/grub2/grub.cfg';
    }
}

sub test_flags() {
    return {important => 1};
}

1;
# vim: set sw=4 et:
