# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: CPU BUGS on Linux kernel check
# Maintainer: James Wang <jnwang@suse.com>

package itlb;

use strict;
use warnings;


use base "consoletest";
use bootloader_setup;
use strict;
use testapi;
use utils;
use power_action_utils 'power_action';

use Mitigation;


sub run {
    my $self = shift;

    check_param('/sys/module/kvm/parameters/nx_huge_pages', "Y");
    my $damn  = script_run('modprobe -r kvm_intel');
    my $damn1 = script_run('modprobe -r kvm');
    if ($damn or $damn1) {
        record_info('fail', "Uninstall kvm and kvm_intel failed.");
        die;
    }
    assert_script_run('modprobe kvm nx_huge_pages=0;lsmod | grep "kvm"');
    assert_script_run('modprobe kvm_intel; lsmod | grep "kvm_intel"');
    check_param('/sys/module/kvm/parameters/nx_huge_pages', "N");
}

sub check_param {
    my ($param, $value) = @_;
    assert_script_run("cat $param | grep $value");
}

1;
