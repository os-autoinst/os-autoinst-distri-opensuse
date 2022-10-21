# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Fetch some infos about CPU, KVM and Kernel
# Maintainer: Dominik Heidler <dheidler@suse.de>

use strict;
use warnings;
use base "consoletest";
use testapi;
use utils;


sub run {
    select_console 'root-console';

    script_run 'lscpu';
    script_run 'uname -a';
    script_run "grep -E -o '(vmx|svm|sie)' /proc/cpuinfo | sort | uniq";
    script_run 'lsmod | grep kvm';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }

    script_run 'cat /sys/module/kvm{_intel,_amd,}/parameters/nested';
}

1;
