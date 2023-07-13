# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This test verifies guest migration between two different hosts, either xen to xen, or kvm to kvm.
#          This is the part to run on the destination host.
# Maintainer: alice <xlai@suse.com>

use base multi_machine_job_base;
use strict;
use warnings;
use testapi;
use lockapi;
use mmapi;
use upload_system_log 'upload_supportconfig_log';
use virt_autotest::utils qw(is_xen_host is_kvm_host upload_virt_logs);
use version_utils 'is_sle';

sub run {
    my ($self) = @_;

    my $ip_out = script_output('ip route show | grep -Eo "src\s+([0-9.]*)\s+" | head -1 | cut -d\' \' -f 2', 30);
    set_var('DST_IP', $ip_out);
    set_var('DST_USER', "root");
    set_var('DST_PASS', $password);
    bmwqemu::save_vars();

    # clean up logs from prevous tests
    script_run('[ -d /var/log/qa/ctcs2/ ] && rm -rf /var/log/qa/ctcs2/');
    script_run('[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/');
    script_run('[ -d /tmp/prj3_migrate_admin_log/ ] && rm -rf /tmp/prj3_migrate_admin_log/');

    #mark ready state
    mutex_create('DST_READY_TO_START');

    #wait for src host core test finish to upload dst log
    my $src_test_timeout = $self->get_var_from_child("MAX_MIGRATE_TIME") || 10800;
    $self->workaround_for_reverse_lock("SRC_TEST_DONE", $src_test_timeout);

    #upload logs
    my $xen_logs = "";
    if (is_xen_host) {
        $xen_logs = "/var/lib/xen/dump /tmp/xl-dmesg.log";
        script_run("xl dmesg > /tmp/xl-dmesg.log");
        #separate the xen logs from other virt logs because it needs to be remained or xen service will fail to start
        script_run "tar -czf var_log_xen.tar.gz /var/log/xen";
        upload_logs "var_log_xen.tar.gz";
    }
    my $logs = "/var/log/libvirt /var/log/messages $xen_logs";
    upload_virt_logs($logs, "guest-migration-dst-logs");
    upload_system_log::upload_supportconfig_log();
    script_run("rm -rf scc_* nts_*");
    save_screenshot;

    #mark dst upload log done
    mutex_create('DST_UPLOAD_LOG_DONE');

    #wait for child finish
    wait_for_children;
}

1;
