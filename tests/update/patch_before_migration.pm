# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Patch SLE qcow2 images before migration (offline)
# Maintainer: Dumitru Gutu <dgutu@suse.de>

use base "consoletest";
use strict;
use testapi;
use utils;
use migration;
use registration;

sub is_smt_or_module_tests {
    return get_var('SCC_ADDONS', '') =~ /asmm|contm|hpcm|lgm|pcm|tcm|wsm|idu|ids/ || get_var('TEST', '') =~ /migration_offline_sle12sp\d_smt/;
}

sub system_prepare() {
    select_console 'root-console';
    type_string "chown $username /dev/$serialdev\n";
    type_string "echo ' export Y2DEBUG = 1 ' >> /etc/bash.bashrc.local\n";
    script_run "source /etc/bash.bashrc.local";
}

sub patching_sle() {
    set_var("VIDEOMODE",    ' text ');
    set_var("SCC_REGISTER", ' installation ');
    # remember we perform registration on pre-created HDD images
    if (sle_version_at_least(' 12 -SP2 ', version_variable => ' HDDVERSION ')) {
        set_var(' HDD_SP2ORLATER ', 1);
    }

    # stop packagekit service
    script_run "systemctl mask packagekit.service";
    script_run "systemctl stop packagekit.service";

    assert_script_run("zypper lr && zypper mr --disable --all");
    save_screenshot;
    yast_scc_registration(check_var("ARCH", "ppc64le"));    #See poo#19230, pass true to type slowly
    assert_script_run(' zypper lr -d ');

    if (get_var(' MINIMAL_UPDATE ')) {
        minimal_patch_system(version_variable => ' HDDVERSION ');
    }

    if (get_var(' FULL_UPDATE ')) {
        fully_patch_system();
    }

    de_register(version_variable => ' HDDVERSION ');
    remove_ltss;
    assert_script_run("zypper mr --enable --all");
    set_var("VIDEOMODE", '');
    # keep the value of SCC_REGISTER for offline migration tests with smt pattern or modules
    # Both of them need registration during offline migration
    if (!is_smt_or_module_tests) { set_var("SCC_REGISTER", ''); }
}

sub run() {
    system_prepare();
    patching_sle();
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
