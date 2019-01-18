# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
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
use warnings;
use testapi;
use utils;

sub select_kernel {
    my $kernel = shift;

    assert_screen ['grub2', "grub2-$kernel-selected"], 100;
    if (match_has_tag "grub2-$kernel-selected") {    # if requested kernel is selected continue
        send_key 'ret';
    }
    else {                                           # else go to that kernel thru grub2 advanced options
        send_key_until_needlematch 'grub2-advanced-options', 'down';
        send_key 'ret';
        send_key_until_needlematch "grub2-$kernel-selected", 'down';
        send_key 'ret';
    }
    if (get_var('NOAUTOLOGIN')) {
        my $ret = assert_screen 'displaymanager', 200;
        mouse_hide();
        if (get_var('DM_NEEDS_USERNAME')) {
            type_string $username;
        }
        else {
            wait_screen_change { send_key 'ret' };
        }
        type_password;
        send_key 'ret';
    }
}

sub run {
    assert_screen 'generic-desktop';
    select_console 'root-console';
    # Stop packagekit
    systemctl 'mask packagekit.service';
    systemctl 'stop packagekit.service';
    # allow to load unsupported modules
    script_run 'sed -i s\'/^allow_unsupported_modules 0/allow_unsupported_modules 1/\' /etc/modprobe.d/10-unsupported-modules.conf';
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

1;

