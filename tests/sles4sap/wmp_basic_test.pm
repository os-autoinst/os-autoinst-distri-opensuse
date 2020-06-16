# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run Workload Memory Protection basic test
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "sles4sap";
use testapi;
use File::Basename qw(basename);
use utils qw(zypper_call file_content_replace);
use version_utils qw(is_sle);
use strict;
use warnings;

sub run {
    my ($self)        = @_;
    my $testname      = 'wmp_basic_tests';
    my $logdir        = '/root/wmp_logs';
    my $sapsvc        = '/usr/sap/sapservices';
    my $wmp_test_repo = get_required_var('WMP_TEST_REPO');
    my @testphases    = qw(initial takeover takeback);

    # Only run this test if WMP was configured. Do this by checking sap.slice cgroup
    my $ret = script_run $sles4sap::systemd_cgls_cmd;
    if ($ret) {
        record_info "WMP not configured", "This test module can only be used if the system was configured with Workload Memory Protection";
        return;
    }

    # Download python test script in HOME directory only if it has not been downloaded before
    if (script_run "ls -d /root/$testname") {
        my $dirname = basename $wmp_test_repo;
        # Remove extension from dirname. We expect tar.gz
        $dirname =~ s/(\.tar\.gz|\.tgz)//;
        assert_script_run 'cd /root';
        $ret = script_run "curl -k $wmp_test_repo | tar -zxvf -";
        record_info 'Download failed', "Could not download $testname script from repo [$wmp_test_repo]", result => 'fail'
          unless (defined $ret and $ret == 0);
        assert_script_run "mv -i $dirname $testname";
        zypper_call 'in python3-psutil python3-PyYAML';
        file_content_replace("/root/$testname/config/config.yml", '^log_path: .*' => "log_path: '$logdir/'",
            '^sapservices_path: .*' => "sapservices_path: '$sapsvc'");
    }

    # Run script
    my $current_test = get_var('WMP_PHASE', $testphases[0]);
    $current_test = $testphases[0] unless (grep /^$current_test$/, @testphases);
    type_string "cd /root/$testname\n";
    my $out = script_output "python3 check_process.py -n $current_test 2>&1";
    die "$testname failed with error [$out]" if ($out =~ /ERROR:/);
    my ($index) = grep { $testphases[$_] eq $current_test } (0 .. $#testphases);
    $index = ($index == $#testphases) ? $#testphases : ($index + 1);
    set_var('WMP_PHASE', $testphases[$index]);
    type_string "cd -\n";

    # Upload results
    assert_script_run "tar -zcvf /tmp/$current_test.tar.gz $logdir/*$current_test*";
    upload_logs("/tmp/$current_test.tar.gz", failok => 1);
    # Check results file for current test was created and then upload its results
    assert_script_run "ls $logdir/*_$current_test.results";
    # Wrap ls output with extra characters so we can get actual filename with a regexp
    my $results = script_output "echo \"FILE=`ls $logdir/*_$current_test.results`\"";
    $results =~ m/FILE=(.+)_$current_test.results/;
    $results = "${1}_${current_test}.results";
    parse_extra_log(IPA => $results);

    # Check sap.slice
    assert_script_run $sles4sap::systemd_cgls_cmd;
}

sub test_flags {
    return {milestone => 1};
}

1;
