# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: rmt-server mariadb yast2-rmt
# Summary: setup one RMT server, sync, enable, mirror and list
# products. Then export RMT data to one folder. Wait another RMT
# Server to import those data
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'consoletest';
use repo_tools;
use utils;
use lockapi 'mutex_create';
use mmapi 'wait_for_children';

sub run {
    select_console 'root-console';
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
