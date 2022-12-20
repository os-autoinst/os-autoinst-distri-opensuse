# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use Utils::Architectures;
use virt_autotest::utils qw(is_xen_host);

sub get_script_run {
    my ($self) = @_;

    my $dst_ip = $self->get_var_from_parent('DST_IP');
    my $dst_user = $self->get_var_from_parent('DST_USER');
    my $dst_pass = $self->get_var_from_parent('DST_PASS');
    handle_sp_in_settings_with_sp0("GUEST_LIST");
    my $guests = get_var("GUEST_LIST", "");
    my $hypervisor = (is_xen_host) ? 'xen' : 'kvm';
    my $test_time = get_var("MAX_MIGRATE_TIME", "10800") - 90;
    my $args = "-d $dst_ip -v $hypervisor -u $dst_user -p $dst_pass -i \"$guests\" -t $test_time";
    my $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-guest-migrate-run " . $args;
    my $vm_xml_dir = "/tmp/download_vm_xml";
    if (get_var("SKIP_GUEST_INSTALL") && is_x86_64) {
        $pre_test_cmd .= " -k $vm_xml_dir";
    }

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
        $result->{$testcase_name}->{error} = $error;
    }

    #parse the reported guest installation or restoration failures at the end of log
    unless ($text =~ /Congratulations! No guest failed in (\w+)/) {
        $text =~ /The guests failed in guest \w+ phase before core test are:(.*)\n(\w+) failed guest list done/s;
        my $installation_failed_guests = $1;
        my $failing_phase = $2;
        foreach my $guest (split('\n', $installation_failed_guests)) {
            next unless $guest !~ /^\s*$/;
            #add the installation failed guest into junit log
            $result->{$guest}->{status} = 'FAILED';
            $result->{$guest}->{error} = "Guest $failing_phase failed so the guest migration tests did not run.";
        }
    }

    return $result;
}

#Mutex lock/unlock functionality
sub set_mutex_lock {
    my ($self, $lock_signal) = @_;

    mutex_lock($lock_signal);
    mutex_unlock($lock_signal);
}

sub post_execute_script_configuration {
    my $self = shift;

    #let dst host upload logs
    set_var('SRC_TEST_DONE', 1);
    bmwqemu::save_vars();
    $self->set_mutex_lock('DST_UPLOAD_LOG_DONE');
}

sub post_execute_script_assertion {
    my $self = shift;

    #display test result
    $self->{script_output} = script_output("cd /tmp; zcat $self->{compressed_log_name}.tar.gz | sed -n '/Executing check validation/,/[0-9]* fail [0-9]* succeed/p'");
    save_screenshot;

    my $output = $self->{script_output};

    my $guest_migration_src_assert_pattern = "[1-9]{1,}[[:space:]]fail|[1-9]{1,}[[:space:]]internal_error";
    script_output("shopt -s nocasematch;[[ ! \"$output\" =~ $guest_migration_src_assert_pattern ]]", type_command => 0, proceed_on_failure => 0);
    save_screenshot;
}

sub run {
    my ($self) = @_;

    #preparation
    my $ip_out = script_output('ip route show | grep -Eo "src\s+([0-9.]*)\s+" | head -1 | cut -d\' \' -f 2', 30);
    set_var('SRC_IP', $ip_out);
    set_var('SRC_USER', "root");
    set_var('SRC_PASS', $password);
    bmwqemu::save_vars();

    #wait for destination to be ready
    $self->set_mutex_lock('DST_READY_TO_START');

    #real test start
    my $timeout = get_var("MAX_MIGRATE_TIME", "10800") - 30;
    my $log_dirs = "/var/log/qa";
    my $upload_log_name = "guest-migration-src-logs";
    $self->{"package_name"} = "Guest Migration Test";

    # clean up logs from previous tests
    script_run('[ -d /tmp/prj3_guest_migration/ ] && rm -rf /tmp/prj3_guest_migration/', 30) if !get_var('SKIP_GUEST_INSTALL');
    script_run('[ -d /var/log/qa/ctcs2/ ] && rm -rf /var/log/qa/ctcs2/', 30);
    script_run('[ -d /tmp/prj3_migrate_admin_log/ ] && rm -rf /tmp/prj3_migrate_admin_log/', 30);

    $self->run_test($timeout, "", "yes", "yes", "$log_dirs", "$upload_log_name");
}

1;
