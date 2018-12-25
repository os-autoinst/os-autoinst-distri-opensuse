# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This test verifies sle and windows guest migration from xen to kvm using virt-v2v.
#          This is the part to run on source host.
# Maintainer: alice <xlai@suse.com>

use base multi_machine_job_base;
use strict;
use testapi;
use lockapi;
use mmapi;

sub run {
    my ($self) = @_;

    my $ip_out = $self->execute_script_run('ip route show|grep kernel|cut -d" " -f12|head -1', 30);
    set_var('SRC_IP',   $ip_out);
    set_var('SRC_USER', "root");
    set_var('SRC_PASS', $password);
    bmwqemu::save_vars();

    $self->execute_script_run("rm -r /var/log/qa/ctcs2/* /tmp/virt-v2v/* -r", 30);

    mutex_create('SRC_READY_TO_START');

    wait_for_children;

    script_run("xl dmesg > /tmp/xl-dmesg.log");
    &virt_autotest_base::upload_virt_logs("/var/log/libvirt /var/log/messages /var/log/xen /var/lib/xen/dump /tmp/xl-dmesg.log", "virt-v2v-xen-src-logs");
}

1;
