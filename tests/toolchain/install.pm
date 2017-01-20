# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Toolchain module test environment installation
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use testapi;

sub run() {
    my ($self) = @_;

    select_console('root-console');

    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # toolchain channels
    if (!check_var('ADDONS', 'tcm')) {
        my $arch = get_var('ARCH');
        assert_script_run
"zypper ar -f http://download.suse.de/ibs/SUSE/Products/SLE-Module-Toolchain/12/$arch/product/ SLE-Module-Toolchain12-Pool";
        assert_script_run
"zypper ar -f http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Toolchain/12/$arch/update/ SLE-Module-Toolchain12-Updates";
    }
    assert_script_run 'zypper -n in -t pattern gcc5';
    assert_script_run 'zypper -n up';
    # reboot when runing processes use deleted files after packages update
    type_string "zypper ps|grep 'PPID' || echo OK | tee /dev/$serialdev\n";
    if (!wait_serial("OK", 100)) {
        type_string "shutdown -r now\n";
        $self->wait_boot;
        select_console('root-console');
    }
    script_run 'export CC=/usr/bin/gcc-5';
    script_run 'export CXX=/usr/bin/g++-5';
    script_run 'lscpu';
    script_run 'free -m';
    save_screenshot;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
