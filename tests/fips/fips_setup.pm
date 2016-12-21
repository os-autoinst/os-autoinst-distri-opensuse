# SUSE's FIPS tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Setup system work into fips mode
#    Install fips pattern and update grub.cfg with fips=1
#
#    Also include workaround of bsc#982268:
#    Due to bsc#982268, openssl couldn't enter fips mode even the
#    system is booted with fips=1. Workaround is create the file
#    /etc/system-fips manually.
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;

# Install fips pattern and update grub.cfg to boot with fips=1
sub run {
    select_console 'root-console';

    my $setup_script = "
    grep 'fips=1' /proc/cmdline && exit 0
    zypper -n install --type pattern fips
    sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT/s/\\(\"\\)\$/ fips=1\\1/' /etc/default/grub
    grub2-mkconfig -o /boot/grub2/grub.cfg
    grep 'fips=1' /boot/grub2/grub.cfg
    ";

    print $setup_script;
    script_output($setup_script, 300);
}

sub test_flags {
    return {important => 1};
}

1;
# vim: set sw=4 et:
