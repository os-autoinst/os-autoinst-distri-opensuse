# SUSE's openQA tests
#
# Copyright Â© 2009-2013 Bernhard M. Wiedemann
# Copyright Â© 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: RT tests
#    test kmp modules & boot RT kernel script for further automated and regression RT tests
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub run() {
    assert_screen 'generic-desktop';
    select_console 'root-console';
    # Stop packagekit
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # allow to load unsupported modules
    script_run
'sed -i s\'/^allow_unsupported_modules 0/allow_unsupported_modules 1/\' /etc/modprobe.d/10-unsupported-modules.conf';
    # install kmp packages
    assert_script_run 'zypper -n in *-kmp-rt', 500;
    type_string "reboot\n";
    select_kernel('rt');
    assert_screen 'generic-desktop';
    reset_consoles;
    select_console 'root-console';
    # check if kernel is proper $kernel
    assert_script_run('uname -r|grep rt', 90, 'Expected rt kernel not found');
    # get bash script
    my $package = data_url('modprobe_kmp_modules.sh');
    script_run "wget $package";
=modprobe_kmp_modules.sh
    #!/bin/bash
    # load modules
    for pkg in $(rpm -qa \*-kmp-rt); do
      for mod in $(rpm -ql $pkg | grep '\.ko$'); do
        modname=$(basename $mod .ko)
        modprobe -v $modname || fail=1
      done
    done
    if [ $fail ] ; then exit 1 ; fi
=cut
    script_run 'chmod +x modprobe_kmp_modules.sh';
    # run script printed above, modprobe kmp-rt modules
    assert_script_run('./modprobe_kmp_modules.sh', 90, 'Failed to load modules below');
    type_string "exit\n";
    reset_consoles;
}

sub test_flags() {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
