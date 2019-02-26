# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

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
    script_run "egrep -o '(vmx|svm)' /proc/cpuinfo | sort | uniq";
    script_run 'lsmod | grep kvm';

    if (script_run('stat /dev/kvm') != 0) {
        record_info('No nested virt', 'No /dev/kvm found');
    }

    script_run 'cat /sys/module/kvm{_intel,_amd,}/parameters/nested';
}

1;
