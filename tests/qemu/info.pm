# SUSE's openQA tests
#
# Copyright 2018-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Fetch some infos about CPU, KVM and Kernel
# Maintainer: Dominik Heidler <dheidler@suse.de>

use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_text_console';
use utils;


sub run {
    select_text_console;

    # Record the output: unlike the VGA console, the serial terminal keeps
    # no screenshot of it.
    record_info('lscpu', script_output('lscpu', proceed_on_failure => 1));
    record_info('uname', script_output('uname -a', proceed_on_failure => 1));
    record_info('virtualization', script_output("grep -E -o '(vmx|svm|sie)' /proc/cpuinfo | sort | uniq", proceed_on_failure => 1));
    record_info('kvm', script_output('lsmod | grep kvm', proceed_on_failure => 1));
    record_info('nested', script_output('cat /sys/module/kvm{_intel,_amd,}/parameters/nested', proceed_on_failure => 1));

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }
}

1;
