# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Add rmt configuration test and basic configuration via
#    rmt-wizard, import RMT data and repos from one folder which
#    stored RMT export data, then verify the imported data can list
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use testapi;
use base 'consoletest';
use repo_tools;
use utils;
use lockapi qw(mutex_create mutex_wait);

sub run {
    select_console 'root-console';
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
    enter_cmd "killall xterm";
}

sub test_flags {
    return {fatal => 1};
}

1;
