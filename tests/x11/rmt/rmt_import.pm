# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add rmt configuration test and basic configuration via
#    rmt-wizard, import RMT data and repos from one folder which
#    stored RMT export data, then verify the imported data can list
# Maintainer: Yutao wang <yuwang@suse.com>

use strict;
use warnings;
use testapi;
use base 'x11test';
use repo_tools;
use utils;
use x11utils 'turn_off_gnome_screensaver';
use lockapi qw(mutex_create mutex_wait);

sub run {
    x11_start_program('xterm -geometry 150x35+5+5', target_match => 'xterm');
    # Avoid blank screen since smt sync needs time
    turn_off_gnome_screensaver;
    become_root;
    rmt_wizard();
    # sync from SCC
    rmt_sync;
    # import data and repos from an existing RMT server
    my $datapath = "/rmtdata/";
    mutex_wait("FINISH_EXPORT_DATA");
    exec_and_insert_password("scp -o StrictHostKeyChecking=no -r root\@10.0.2.101:$datapath /");
    assert_script_run("chown -R _rmt:nginx $datapath");
    rmt_import_data($datapath);
    # check the imported products correct
    rmt_enable_pro;
    rmt_list_pro;
    my $pro_ls = get_var('RMT_PRO') || 'sle-module-legacy/15/x86_64';
    assert_script_run("rmt-cli product list | grep $pro_ls");
    type_string "killall xterm\n";
}

sub test_flags {
    return {fatal => 1};
}

1;
