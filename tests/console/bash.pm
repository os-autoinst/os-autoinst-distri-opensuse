# SUSE's openQA tests
#
# Copyright (C) 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
# Summary: Bash regression test (https://progress.opensuse.org/issues/50747)
# Maintainer: Nalmpantis Orestis (onalmpantis)
 
use base "consoletest";
use strict;
use testapi;
use utils 'zypper_call';
use version_utils 'is_sle'; 

sub run {
    # Declaring repo and database variables that change depending on the product tested	
    my $repo="";
    my $database="";
    if (is_sle('=12-sp1')) {
	    $repo = "http://download.suse.de/ibs/QA:/SLE12SP1/update/QA:SLE12SP1.repo";
	    $database = "failed_tests_database_sle12-sp1";
    } 
    if (is_sle('=12-sp2')) {
	    $repo = "http://download.suse.de/ibs/QA:/SLE12SP2/update/QA:SLE12SP2.repo";
	    $database = "failed_tests_database_sle12-sp2";
    } 
    if (is_sle('=12-sp3')) {
	    $repo = "http://download.suse.de/ibs/QA:/SLE12SP3/update/QA:SLE12SP3.repo";
	    $database = "failed_tests_database_sle12-sp3";
    } 
    if (is_sle('=12-sp4')) {
	    $repo = "http://download.suse.de/ibs/QA:/SLE12SP4/update/QA:SLE12SP4.repo";
	    $database = "failed_tests_database_sle12-sp4";
    } 
    if (is_sle('=15')) {
	    $repo = "http://download.suse.de/ibs/QA:/SLE15/update/QA:SLE15.repo";
	    $database = "failed_tests_database_sle15";
    }
    if (is_sle('=15-sp1')) {
            $repo = "http://download.suse.de/ibs/QA:/SLE15SP1/update/QA:SLE15SP1.repo";
            $database = "failed_tests_database_sle15-sp1";
    }
 
    select_console "root-console";
    # Adding the testsuite repository
    assert_script_run "zypper ar --no-gpgcheck $repo";
    # Installing the testsuite
    assert_script_run "zypper --non-interactive --no-gpg-checks in qa_test_bash";
    # Running the testsuite
    assert_script_run "/usr/share/qa/tools/test_bash-run", timeout => 1200;	    
    # Locating the folder with testsuite results
    assert_script_run "cd /var/log/qa/ctcs2/";
    # Making sure the newest created folder is picked
    assert_script_run 'cd `ls -th|head -n 1`';
    # Locating Failed tests and put them on failed_tests file
    assert_script_run 'grep -l "FAILED: bash" * > failed_tests';
    # Sort them just in case they are not sorted
    assert_script_run 'sort -o failed_tests failed_tests';
    # Downloading the corresponding database of previous failed tests on this specific product
    assert_script_run 'curl -O ' . data_url("bash_regression_test/$database");
    # Display all the previous failed tests
    assert_script_run "cat $database";
    # Display all the current failed tests
    assert_script_run "cat failed_tests";
    # Comparing current fails with previous fails.
    assert_script_run('while read line; do grep $line '.$database.' > NULL; if [ $? -eq 1 ]; then echo $line; fi; done < failed_tests > possible_regressions'); 
    # Display the tests that failed only on this run and not on the previous run
    assert_script_run "cat possible_regressions";
    # Download the script that runs each failed test 20 times
    assert_script_run 'curl -O ' . data_url("bash_regression_test/test_run_script");
    assert_script_run 'bash test_run_script > results', timeout => 1200;
    # If there is a regression, show the test and a corresponding message
    assert_script_run '! grep "Its a regression" results'; 
}
 
 
1;
