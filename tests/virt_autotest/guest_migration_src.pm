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
#          This is the part to run on the source host.
# Maintainer: alice <xlai@suse.com>

use base multi_machine_job_base;
use strict;
use testapi;
use lockapi;
use mmapi;

sub get_script_run() {
    my ($self) = @_;

    my $dst_ip       = $self->get_var_from_parent('DST_IP');
    my $dst_user     = $self->get_var_from_parent('DST_USER');
    my $dst_pass     = $self->get_var_from_parent('DST_PASS');
    my $guests       = get_var("GUEST_LIST", "");
    my $hypervisor   = get_var("HOST_HYPERVISOR", "kvm");
    my $test_time    = get_var("MAX_MIGRATE_TIME", "10800") - 90;
    my $args         = "-d $dst_ip -v $hypervisor -u $dst_user -p $dst_pass -i \"$guests\" -t $test_time";
    my $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-guest-migrate-run " . $args;

    return "$pre_test_cmd";
}

sub run() {
    my ($self) = @_;

    #preparation
    my $ip_out = $self->execute_script_run('ip route show|grep kernel|cut -d" " -f12|head -1', 30);
    set_var('SRC_IP',   $ip_out);
    set_var('SRC_USER', "root");
    set_var('SRC_PASS', "nots3cr3t");
    bmwqemu::save_vars();

    #wait for destination to be ready
    mutex_lock('DST_READY_TO_START');
    mutex_unlock('DST_READY_TO_START');

    #real test start
    my $timeout         = get_var("MAX_MIGRATE_TIME", "10800") - 30;
    my $log_dirs        = "/var/log/qa";
    my $upload_log_name = "guest-migration-src-logs";
    $self->execute_script_run("rm -r /var/log/qa/ctcs2/* /tmp/prj3* -r", 30);
    $self->run_test($timeout, "", "no", "yes", "$log_dirs", "$upload_log_name");

    #display test result
    my $cmd = "cd /tmp; zcat $upload_log_name.tar.gz | sed -n '/Executing check validation/,/[0-9]* fail [0-9]* succeed/p'";

    my $guest_migrate_log_content = &script_output("$cmd");
    save_screenshot;

    #mark test result
    if ($guest_migrate_log_content =~ /0 succeed/m) {
        die "Guest migration failed! It had unsuccessful migration cases!";
    }
}

1;
