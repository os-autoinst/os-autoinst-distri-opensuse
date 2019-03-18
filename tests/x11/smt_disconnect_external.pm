# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Disconnect SMT external
# Maintainer: Dehai Kong <dhkong@suse.com>

use base "x11test";
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use mm_network;
use repo_tools;
use x11utils 'turn_off_gnome_screensaver';

sub run {
    my ($self) = @_;
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver;
    become_root;

    # setting external SMT configure
    smt_wizard();

    assert_script_run 'smt-sync', 600;
    assert_script_run 'smt-repos';

    # enable,mirror and sync one repo for internal using
    smt_mirror_repo();
    assert_script_run 'smt-sync --todir /mnt/Mobile-disk', 600;
    save_screenshot;

    mutex_create("disconnect_smt_1");

    # lock and unlock internal smt mutex to get update DB and sync to mobile disk
    my $children = get_children();
    my $child_id = (keys %$children)[0];
    mutex_lock('disconnect_smt_2', $child_id);
    mutex_unlock('disconnect_smt_2', $child_id);
    assert_script_run 'smt-mirror --dbreplfile /mnt/Mobile-disk/updateDB --fromlocalsmt --directory /mnt/Mobile-disk -L /var/log/smt/smt-mirror-example.log',
      600;
    assert_script_run 'smt-sync --todir /mnt/Mobile-disk', 600;

    # create mutex to let internal smt do daily operation
    mutex_create("disconnect_smt_3");
    type_string "killall xterm\n";
    wait_for_children;
}

sub test_flags {
    return {fatal => 1};
}

1;
