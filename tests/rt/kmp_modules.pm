# SUSE's openQA tests
#
# Copyright Â© 2009-2013 Bernhard M. Wiedemann
# Copyright Â© 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "opensusebasetest";
use strict;
use testapi;
use utils;

sub kmp_module {
    my $kernel = shift;

    select_kernel("$kernel");
    assert_screen 'generic-desktop';
    send_key 'ctrl-alt-f4';
    assert_screen 'tty4-selected';
    assert_screen 'text-login';
    type_string "root\n";
    assert_screen 'password-prompt', 10;
    type_password;
    send_key 'ret';
    # check if kernel is proper $kernel
    script_run "uname -r|grep $kernel;echo \"$kernel-kernel-\$?\" > /dev/$serialdev";
    wait_serial("$kernel-kernel-0", 10) || die "no $kernel kernel";
    # get bash script
    my $package = data_url('modprobe_kmp_modules.sh');
    script_run "wget $package";
=modprobe_kmp_modules.sh
    #!/bin/bash
    # load modules
    for pkg in $(rpm -qa \*-kmp-$1); do
      for mod in $(rpm -ql $pkg | grep '\.ko$'); do
        modname=$(basename $mod .ko)
        modprobe -v $modname
      done
    done
=cut
    script_run 'chmod +x modprobe_kmp_modules.sh';
    # run script printed above, modprobe kmp-compute and kmp-rt modules
    assert_script_run "./modprobe_kmp_modules.sh $kernel";
}

sub run() {
    assert_screen 'generic-desktop';
    select_console 'root-console';
    # Stop packagekit
    script_run 'systemctl mask packagekit.service';
    script_run 'systemctl stop packagekit.service';
    # allow to load unsupported modules
    script_run 'sed -i s\'/^allow_unsupported_modules 0/allow_unsupported_modules 1/\' /etc/modprobe.d/10-unsupported-modules.conf';
    # install kmp packages
    assert_script_run 'zypper -n in *-kmp-rt *-kmp-compute', 500;
    script_run 'reboot';
    kmp_module('compute');
    script_run 'reboot';
    kmp_module('rt');
    script_run 'exit';
}

sub test_flags() {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
