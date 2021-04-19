# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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
use virt_autotest::utils qw(is_xen_host);

sub run {
    my ($self) = @_;

    my $ip_out = script_output('ip route show | grep -Eo "src\s+([0-9.]*)\s+" | head -1 | cut -d\' \' -f 2', 30);
    set_var('DST_IP',   $ip_out);
    set_var('DST_USER', "root");
    set_var('DST_PASS', $password);
    bmwqemu::save_vars();

    #workaround for weird mount failure
    $self->workaround_for_reverse_lock("SRC_IP", 3600);
    my $src_ip       = $self->get_var_from_child("SRC_IP");
    my $src_user     = $self->get_var_from_child("SRC_USER");
    my $src_pass     = $self->get_var_from_child("SRC_PASS");
    my $hypervisor   = (is_xen_host) ? 'xen' : 'kvm';
    my $args         = "-d $src_ip -v $hypervisor -u $src_user -p $src_pass";
    my $pre_test_cmd = "/usr/share/qa/virtautolib/lib/guest_migrate.sh " . $args;
    enter_cmd("$pre_test_cmd ");
    save_screenshot;
    send_key("ctrl-c");
    save_screenshot;
    #workaround end

    # clean up logs from prevous tests
    script_run('[ -d /var/log/qa/ctcs2/ ] && rm -rf /var/log/qa/ctcs2/',                     30);
    script_run('[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/',     30);
    script_run('[ -d /tmp/prj3_migrate_admin_log/ ] && rm -rf /tmp/prj3_migrate_admin_log/', 30);

    #mark ready state
    mutex_create('DST_READY_TO_START');

    #wait for src host core test finish to upload dst log
    my $src_test_timeout = $self->get_var_from_child("MAX_MIGRATE_TIME") || 10800;
    $self->workaround_for_reverse_lock("SRC_TEST_DONE", $src_test_timeout);

    #upload logs
    script_run("xl dmesg > /tmp/xl-dmesg.log");
    my $xen_logs = "";
    if ($hypervisor =~ /XEN/im) {
        $xen_logs = "/var/lib/xen/dump /tmp/xl-dmesg.log";
        script_run("xl dmesg > /tmp/xl-dmesg.log");
        #separate the xen logs from other virt logs because it needs to be remained or xen service will fail to start
        script_run "tar -czf var_log_xen.tar.gz /var/log/xen";
        upload_logs "var_log_xen.tar.gz";
    }
    my $logs = "/var/log/libvirt /var/log/messages $xen_logs";
    virt_autotest_base::upload_virt_logs($logs, "guest-migration-dst-logs");
    upload_system_log::upload_supportconfig_log();
    script_run("rm -rf scc_* nts_*");
    save_screenshot;

    #mark dst upload log done
    mutex_create('DST_UPLOAD_LOG_DONE');

    #wait for child finish
    wait_for_children;
}

1;
