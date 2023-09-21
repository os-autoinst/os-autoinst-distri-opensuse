# SUSE's openQA tests
#
# Copyright 2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: This test verifies whether on host installed with specific product, the guests can successfully upgrade to the target upgrade product.
#          It is provides as part of the test for fate https://fate.suse.com/320424.
#          The other part of the fate test is already added as prj2_host_upgrade test.
#
# Maintainer: xlai@suse.com

use strict;
use warnings;
use base "virt_autotest_base";
use virt_utils;
use testapi;
use Utils::Architectures;

sub get_script_run {
    #NOTE:Found that s390x arch used with the svirt backend
    #do not work very well with two times ctcs2 runs - test_virtualization-guest-upgrade-run
    #Also, found that svirt backend worked very well
    #with just only one time ctcs2 run - test_full_guest_upgrade.sh
    #So, change to use with test_full_guest_upgrade.sh directly for s390x arch
    my $pre_test_cmd = "";
    if (is_s390x) {
        #Use pipefail to keep the correct returns from test_full_guest_upgrade.sh
        $pre_test_cmd = "set -o pipefail;";
        $pre_test_cmd = "$pre_test_cmd/usr/share/qa/virtautolib/lib/test_full_guest_upgrade.sh";
    }
    else {
        $pre_test_cmd = "/usr/share/qa/tools/test_virtualization-guest-upgrade-run";
    }
    my $product_upgrade_repo = get_var("PRODUCT_UPGRADE_REPO", "");
    #Prefer to use offline media for upgrade to avoid guest registration
    $product_upgrade_repo =~ s/-Online-/-Full-/ if ($product_upgrade_repo =~ /15-sp[2-9]/i);
    my $max_test_time = get_var("MAX_TEST_TIME", "36000");
    my $vm_xml_dir = "/tmp/download_vm_xml";

    handle_sp_in_settings_with_sp0("PRODUCT_UPGRADE");
    my $product_upgrade = get_required_var("PRODUCT_UPGRADE");

    handle_sp_in_settings_with_fcs("GUEST_LIST");
    my $guest_list = get_required_var("GUEST_LIST");

    $pre_test_cmd = "$pre_test_cmd -p $product_upgrade -r $product_upgrade_repo -g \"$guest_list\"";
    if (is_s390x) {
        $pre_test_cmd .= " 2>&1 | tee /tmp/s390x_guest_upgrade_test.log";
    } else {
        $pre_test_cmd .= " -t $max_test_time";
    }
    if (get_var("SKIP_GUEST_INSTALL") && is_x86_64) {
        $pre_test_cmd .= " -k $vm_xml_dir";
    }

    my $do_registration = check_var('GUEST_SCC_REGISTER', 'installation') ? "true" : "false";
    my $registration_server = get_var('SCC_URL', 'https://scc.suse.com');
    my $registration_code = get_var('SCC_REGCODE', 'INVALID_REGCODE');
    $pre_test_cmd .= " -e $do_registration";
    $pre_test_cmd .= " -s $registration_server";
    $pre_test_cmd .= " -c $registration_code";

    return $pre_test_cmd;
}

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;
    # In the case the log does not tell the exact failure
    if ($text !~ /Overall guest upgrade result is:(.*)Test done/s) {
        my $subtest = get_var('GUEST_LIST');
        $result->{$subtest}->{status} = 'FAILED';
        $result->{$subtest}->{error} = 'Please check the guest_upgrade_test log in the guest_upgrade_run-guest-upgrade-logs.tar.gz';
        return $result;
    }
    my $rough_result = $1;

    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(?<testcase_name>\S+)\s+\-{3}\s+(PASS|FAIL|SKIP|TIMEOUT)(\s+\-{3}\s+(.*))?/ig) {
            my ($testcase_name, $status, $error) = ($+{testcase_name}, $2, $4);
            $result->{$testcase_name}->{status} = $status =~ /pass/i ? 'PASSED' : 'FAILED';
            $result->{$testcase_name}->{error} = $error ? $error : 'none';
        }
    }

    # if there are failing guest installation or in restoration
    unless ($text =~ /Congratulations! No guest failed in (\w+)/) {
        $text =~ /The guests failed in guest \w+ phase before core test are:(.*)\n(\w+) failed guest list done./s;
        my $installation_failed_guests = $1;
        my $failing_phase = $2;
        foreach my $guest (split('\n', $installation_failed_guests)) {
            next unless $guest !~ /^\s*$/;
            $result->{$guest}->{status} = 'FAILED';
            $result->{$guest}->{error} = "Guest $failing_phase failed.";
        }
    }
    return $result;
}

sub post_execute_script_assertion {
    my $self = shift;

    my $output = $self->{script_output};
    # display test result
    # print the test output to the openQA output
    $self->{script_output} = script_output "cd /tmp; zcat $self->{compressed_log_name}.tar.gz | sed -n '/Overall guest upgrade result/,/[0-9]* fail [0-9]* succeed/p'";
    save_screenshot;
    # Determine test result from test output directly
    $output =~ s/"|'|`//g;
    my $guest_upgrade_assert_pattern = "Test[[:space:]]in[[:space:]]progress.*(fail|timeout).*Test[[:space:]]run[[:space:]]complete";
    script_output("shopt -s nocasematch;[[ ! \"$output\" =~ $guest_upgrade_assert_pattern ]]", type_command => 0, proceed_on_failure => 0);
    save_screenshot;
}

sub run {
    my $self = shift;
    my $timeout = get_var('MAX_TEST_TIME', '36000') + 10;
    my $upload_log_name = 'guest-upgrade-logs';
    if (is_s390x) {
        #ues die_on_timeout=> 0 as workaround for s390x test during call script_run, refer to poo#106765
        script_run("echo \"Debug info: max_test_time is $timeout\"", die_on_timeout => 0);
    } else {
        script_run("echo \"Debug info: max_test_time is $timeout\"");
    }
    # Modify source configuration file sources.* of virtauto-data pkg on host
    # to use openqa daily build installer repo and module repo for guests,
    # and it will be copied into guests to be used during guest upgrade test
    repl_module_in_sourcefile();

    $self->{'package_name'} = 'Guest Upgrade Test';
    if (is_s390x) {
        #ues die_on_timeout=> 0 as workaround for s390x test during call script_run, refer to poo#106765
        script_run "[ -d /var/log/qa/ctcs2 ] && rm -r /var/log/qa/ctcs2 ; [ -d /var/lib/libvirt/images/prj4_guest_upgrade ] && rm -r /var/lib/libvirt/images/prj4_guest_upgrade /tmp/full_guest_upgrade_test-* /tmp/kill_zypper_procs-* /tmp/update-guest-*", die_on_timeout => 0;
    }
    else {
        $self->execute_script_run("[ -d /var/log/qa/ctcs2 ] && rm -r /var/log/qa/ctcs2 ; [ -d /tmp/prj4_guest_upgrade ] && rm -r /tmp/prj4_guest_upgrade", 30);
    }
    $self->run_test($timeout, '', 'yes', 'yes', '/var/log/qa/', $upload_log_name);
    #upload testing logs for s390x guest upgrade test
    if (is_s390x) {
        #upload s390x_guest_upgrade_test.log
        upload_asset("/tmp/s390x_guest_upgrade_test.log", 1, 1);
        #ues die_on_timeout=> 0 as workaround for s390x test during call script_run, refer to poo#106765
        script_run "rm -rf /tmp/s390x_guest_upgrade_test.log", die_on_timeout => 0;
    }

}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    if (is_s390x) {
        #upload s390x_guest_upgrade_test.log
        upload_asset("/tmp/s390x_guest_upgrade_test.log", 1, 1);
        #ues die_on_timeout=> 0 as workaround for s390x test during call script_run, refer to poo#106765
        script_run "rm -rf /tmp/s390x_guest_upgrade_test.log", die_on_timeout => 0;
    }
}

1;
