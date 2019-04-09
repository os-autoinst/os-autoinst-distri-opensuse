# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
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

sub get_script_run {
    my $pre_test_cmd         = "/usr/share/qa/tools/test_virtualization-guest-upgrade-run";
    my $product_upgrade_repo = get_var("PRODUCT_UPGRADE_REPO", "");
    my $max_test_time        = get_var("MAX_TEST_TIME", "36000");

    handle_sp_in_settings_with_sp0("PRODUCT_UPGRADE");
    my $product_upgrade = get_var("PRODUCT_UPGRADE", "sles-12-sp2-64");

    handle_sp_in_settings_with_fcs("GUEST_LIST");
    my $guest_list = get_var("GUEST_LIST", "sles-12-sp1-64");

    $pre_test_cmd = "$pre_test_cmd -p $product_upgrade -r $product_upgrade_repo -t $max_test_time -g \"$guest_list\"";
    return $pre_test_cmd;
}

sub analyzeResult {
    my ($self, $text) = @_;
    my $result;
    # In the case the log does not tell the exact failure
    if ($text !~ /Overall guest upgrade result is:(.*)Test done/s) {
        $result->{subtest}->{status} = 'FAILED';
        $result->{subtest}->{error}  = 'Please check the guest_upgrade_test log in the guest_upgrade_run-guest-upgrade-logs.tar.gz';
        return $result;
    }
    my $rough_result = $1;

    foreach (split("\n", $rough_result)) {
        if ($_ =~ /(?<testcase_name>\S+)\s+\-{3}\s+(PASS|FAIL|SKIP|TIMEOUT)(\s+\-{3}\s+(.*))?/ig) {
            my ($testcase_name, $status, $error) = ($+{testcase_name}, $2, $4);
            $result->{$testcase_name}->{status} = $status =~ /pass/i ? 'PASSED' : 'FAILED';
            $result->{$testcase_name}->{error}  = $error             ? $error   : 'none';
        }
    }

    # if there are failing guest installation
    unless ($text =~ /Congratulations! No guest failed in installation/) {
        $text =~ /The guests failed in guest installation phase before core test are:(.*)Installation failed guest list done./s;
        my $installation_failed_guests = $1;
        foreach my $guest (split('\n', $installation_failed_guests)) {
            next unless $guest !~ /^\s*$/;
            $result->{$guest}->{status} = 'FAILED';
            $result->{$guest}->{error}  = "Guest $guest installation failed.";
        }
    }
    return $result;
}

sub run {
    my $self            = shift;
    my $timeout         = get_var('MAX_TEST_TIME', '36000') + 10;
    my $upload_log_name = 'guest-upgrade-logs';
    script_run("echo \"Debug info: max_test_time is $timeout\"");
    # Modify source configuration file sources.* of virtauto-data pkg on host
    # to use openqa daily build installer repo and module repo for guests,
    # and it will be copied into guests to be used during guest upgrade test
    repl_module_in_sourcefile();

    $self->execute_script_run("[ -d /var/log/qa/ctcs2 ] && rm -r /var/log/qa/ctcs2 ; [ -d /tmp/prj4_guest_upgrade ] && rm -r /tmp/prj4_guest_upgrade", 30);

    $self->run_test($timeout, '', 'no', 'yes', '/var/log/qa/', $upload_log_name);

    # display test result
    # print the test output to the openQA output
    my $cmd                       = "cd /tmp; zcat $upload_log_name.tar.gz | sed -n '/Overall guest upgrade result/,/[0-9]* fail [0-9]* succeed/p'";
    my $guest_upgrade_log_content = script_output($cmd);
    save_screenshot;

    # print the sub test junit log
    $self->{'package_name'} = 'Guest Upgrade Test';
    $self->add_junit_log($guest_upgrade_log_content);
}

1;
