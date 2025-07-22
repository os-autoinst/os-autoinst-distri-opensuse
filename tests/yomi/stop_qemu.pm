# Yomi's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Stop QEMU
# Maintainer: Alberto Planas <aplanas@suse.de>

use base "consoletest";
use testapi;
use utils;

sub run {
    select_console 'root-console';

    script_run 'pkill -9 qemu';
    script_run 'rm hda.qcow2';
}

1;
