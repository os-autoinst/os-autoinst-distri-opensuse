# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Toolchain module test environment installation
# Maintainer: Michal Nowak <mnowak@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Systemd 'disable_and_stop_service';
use version_utils 'is_sle';
use registration;

sub run {
    my ($self) = @_;

    select_console('root-console');

    disable_and_stop_service('packagekit.service', mask_service => 1);

    if (is_sle '<15') {
        # toolchain channels
        if (!check_var('ADDONS', 'tcm')) {
            my $arch = get_var('ARCH');
            zypper_call "ar -f http://download.suse.de/ibs/SUSE/Products/SLE-Module-Toolchain/12/$arch/product/ SLE-Module-Toolchain12-Pool";
            zypper_call "ar -f http://download.suse.de/ibs/SUSE/Updates/SLE-Module-Toolchain/12/$arch/update/ SLE-Module-Toolchain12-Updates";
        }
        zypper_call('in -t pattern gcc5');
        zypper_call('up');

        # reboot when runing processes use deleted files after packages update
        type_string "zypper ps|grep 'PPID' || echo OK | tee /dev/$serialdev\n";
        if (!wait_serial("OK", 100)) {
            type_string "shutdown -r now\n";
            $self->wait_boot;
            select_console('root-console');
        }
        script_run 'export CC=/usr/bin/gcc-5';
        script_run 'export CXX=/usr/bin/g++-5';
    }
    else {
        # No need to be fixed to version (that is only for products receiving the yearly gcc update)
        # but it needs to activate development tool module
        if (is_sle) {
            add_suseconnect_product("sle-module-desktop-applications");
            add_suseconnect_product("sle-module-development-tools");
        }
        zypper_call 'in -t pattern devel_basis';
        zypper_call 'in gcc-fortran';    # from Base System Module
        script_run 'export CC=/usr/bin/gcc';
        script_run 'export CXX=/usr/bin/g++';
    }

    script_run 'lscpu';
    script_run 'free -m';
    save_screenshot;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
