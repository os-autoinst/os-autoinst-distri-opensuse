# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Package: rmt-server mariadb yast2-rmt
# Summary: setup one RMT server, sync, enable, mirror and list
# products. Then export RMT data to one folder. Wait another RMT
# Server to import those data
# Maintainer: Yutao Wang <yuwang@suse.com>

use strict;
use warnings;
use testapi;
use base 'x11test';
use repo_tools;
use utils;
use x11utils 'turn_off_gnome_screensaver';
use lockapi 'mutex_create';
use mmapi 'wait_for_children';

sub run {
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    # Avoid blank screen since smt sync needs time
    turn_off_gnome_screensaver;
    become_root;
    rmt_wizard();
    # sync, enable, mirror and list products
    rmt_sync();
    rmt_enable_pro();
    rmt_mirror_repo();
    rmt_list_pro();
    # export data and repos
    rmt_export_data();
    mutex_create("FINISH_EXPORT_DATA");
    wait_for_children;
    enter_cmd "killall xterm";
}

sub test_flags {
    return {fatal => 1};
}

1;
