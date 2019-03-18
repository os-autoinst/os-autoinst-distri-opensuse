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
use warnings;
use testapi;
use lockapi;
use mmapi;
use virt_utils;
use Data::Dumper;

sub get_script_run {
    my ($self) = @_;

    my $dst_ip   = $self->get_var_from_parent('DST_IP');
    my $dst_user = $self->get_var_from_parent('DST_USER');
    my $dst_pass = $self->get_var_from_parent('DST_PASS');
    handle_sp_in_settings_with_sp0("GUEST_LIST");
    my $guests     = get_var("GUEST_LIST",       "");
    my $hypervisor = get_var("HOST_HYPERVISOR",  "kvm");
    my $test_time  = get_var("MAX_MIGRATE_TIME", "10800") - 90;
    my $args       = "-d $dst_ip -v $hypervisor -u $dst_user -p $dst_pass -i \"$guests\" -t $test_time";
    my $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-guest-migrate-run " . $args;

    return "$pre_test_cmd";
}

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;

    #parse the guest migration result
    $text =~ /Overall migration result start:(.*)Overall migration result end/s;
    my $rough_result = $1;

    foreach my $full_testcase_info (split("\n", $rough_result)) {
        #remove lines that are not testcases
        next if ($full_testcase_info =~ /(^\s*$|testcase|##)/m);
        #parse result with format: case separator status [separator error]
        my ($testcase_name, $status, $error) = (split("----------", $full_testcase_info));
        foreach my $item ($testcase_name, $status, $error) {
            $item =~ s/(^\s*|\s*$)//g;
        }
        if ($status =~ /pass/) {
            $status = "PASSED";
        }
        elsif ($status =~ /fail/) {
            $status = "FAILED";
        }
        $result->{$testcase_name}->{status} = $status;
        $result->{$testcase_name}->{error}  = $error;
    }

    #parse the reported guest installation failures at the end of log
    unless ($text =~ /Congratulations! No guest failed in installation/) {
        $text =~ /The guests failed in guest installation phase before core test are:(.*)Installation failed guest list done/s;
        my $installation_failed_guests = $1;
        foreach my $guest (split('\n', $installation_failed_guests)) {
            next unless $guest !~ /^\s*$/;
            #add the installation failed guest into junit log
            $result->{$guest}->{status} = 'FAILED';
            $result->{$guest}->{error}  = "Guest $guest installation failed before guest migration test.";
        }
    }

    return $result;
}

sub run {
    my ($self) = @_;

    #preparation
    my $ip_out = $self->execute_script_run('ip route show | grep -Eo "src\s+([0-9.]*)\s+" | head -1 | cut -d\' \' -f 2', 30);
    set_var('SRC_IP',   $ip_out);
    set_var('SRC_USER', "root");
    set_var('SRC_PASS', $password);
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
    my $cmd                       = "cd /tmp; zcat $upload_log_name.tar.gz | sed -n '/Executing check validation/,/[0-9]* fail [0-9]* succeed/p'";
    my $guest_migrate_log_content = &script_output("$cmd");
    save_screenshot;

    #upload junit log
    $self->{"package_name"} = "Guest Migration Test";
    $self->add_junit_log("$guest_migrate_log_content");

    #let dst host upload logs
    set_var('SRC_TEST_DONE', 1);
    bmwqemu::save_vars();
    mutex_lock('DST_UPLOAD_LOG_DONE');
    mutex_unlock('DST_UPLOAD_LOG_DONE');

    #mark test result
    if ($guest_migrate_log_content =~ /0 succeed/m) {
        die "Guest migration failed! It had unsuccessful migration cases!";
    }
}

1;
