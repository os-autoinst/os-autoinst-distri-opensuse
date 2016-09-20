# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils qw/wait_boot/;

sub run() {
    my $self = shift;

    select_console('root-console');

    # disable packagekitd
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # hpc channels
    my $arch     = get_var('ARCH');
    my $build    = get_var('BUILD_HPC');
    my $reponame = "SLE-Module-HPC12";
    assert_script_run "zypper ar -f http://download.suse.de/ibs/SUSE:/SLE-12-SP2:/GA/images/repo/SLE-12-Module-HPC-POOL-$arch-Build$build-Media1/ $reponame";
    assert_script_run "zypper -n in cpuid rasdaemon memkind hwloc";
    assert_script_run 'zypper -n up';
    # reboot when running processes use deleted files after packages update
    type_string "zypper ps|grep 'PPID' || echo OK | tee /dev/$serialdev\n";
    if (!wait_serial("OK", 100)) {
        type_string "shutdown -r now\n";
        wait_boot;
        select_console('root-console');
    }
    save_screenshot;
}

sub test_flags() {
    return {fatal => 1, milestone => 1};
}

1;
# vim: set sw=4 et:
