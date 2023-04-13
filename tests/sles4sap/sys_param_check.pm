# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check the sles4sap "from scratch" settings (without saptune/sapconf) using the robot framework.
#          This test is configured to be used with a 2 GB RAM system.
#          Some values depend of the hardware configuration.
#          External robotfw testkit is supplied in the SYS_PARAM_CHECK_TEST setting. Defaults to
#          qa-css-hq.qa.suse.de/robot.tar.gz.
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use version_utils qw(is_sle);
use utils qw(zypper_call);
use hacluster qw(is_package_installed);
use kdump_utils qw(deactivate_kdump_cli);

sub remove_value {
    my ($module, $parameter) = @_;
    assert_script_run "perl -e 'while (<>) { /testcase.+name=\"([^\"]+)\"/; \$testcase = \$1; unless (\$testcase eq $parameter) { print; } }' < $module.xml > result.xml";
    # As we just removed a failed value, we have to decrease the failure counter by 1.
    assert_script_run 'awk -i inplace \'/failures=/ { new=substr($5,11,length($5)-11); new--; gsub($5, "failures=\""new"\"") } /./ { print }\' result.xml';
    assert_script_run "mv result.xml $module.xml";
}

sub check_failure {
    my ($module, $parameter) = @_;
    return 1 if script_run("perl -e 'while (<>) { /testcase.+name=\"([^\"]+)\"/; \$testcase = \$1; exit 0 if (/\<failure/ && \$testcase eq \"$parameter\"); } exit 1' < $module.xml") == 0;
}

sub add_softfail {
    my ($module, $os_version, $reference, @parameters) = @_;
    foreach my $parameter (@parameters) {
        if (check_var("VERSION", $os_version) && check_failure($module, $parameter)) {
            record_soft_failure("$reference - Wrong value for $parameter");
            remove_value($module, $parameter);
        }
    }
}

sub run {
    my ($self) = @_;
    my $robot_fw_version = '3.2.2';
    my $distro_ver = is_sle ? "sles-" . get_var('VERSION') : 'Tumbleweed';
    my $test_repo = "/robot/tests/$distro_ver";
    my $robot_tar = "robot.tar.gz";
    my $testkit = get_var('SYS_PARAM_CHECK_TEST', "qa-css-hq.qa.suse.de/$robot_tar");
    my $python_bin = is_sle('<15') ? 'python' : 'python3';
    select_serial_terminal;

    # regenerate initrd bsc#1204897
    assert_script_run 'dracut --force', 180;

    # Download and prepare the test environment
    assert_script_run "cd /; curl -f -v \"$testkit\" -o $robot_tar";
    assert_script_run "tar -xzf $robot_tar";

    # Install the robot framework
    assert_script_run "unzip /robot/bin/robotframework-$robot_fw_version.zip";
    assert_script_run "cd robotframework-$robot_fw_version";
    zypper_call "in $python_bin-setuptools" unless is_package_installed("$python_bin-setuptools");
    assert_script_run "$python_bin setup.py install";

    # Disable extra tuning for testing "from scratch" system
    if (check_var('SLE_PRODUCT', 'sles4sap')) {
        assert_script_run "systemctl disable sapconf";
        $self->reboot;
    }

    # It can only happen on sle product
    # Only use by test not fully migrated to YAML
    if (get_var('DISABLE_KDUMP') && is_package_installed('kdump')) {
        record_info('Disabling kdump', 'Disabling kdump and crashkernel option');
        deactivate_kdump_cli;
        $self->reboot;
    }

    # Execute each test and upload its results
    assert_script_run "cd $test_repo";
    foreach my $robot_test (split /\n/, script_output "ls -1 $test_repo") {
        # Sanitize $robot_test
        $robot_test =~ s/[\n|\r]//g;
        record_info("$robot_test", "Starting [$robot_test]");
        script_run "robot --log $robot_test.html --xunit $robot_test.xml $robot_test", timeout => 90;
        # Soft fail section - How to add a new one
        # add_softfail("TEST_NAME", "OS_VERSION", "BUG_NUMBER", "PARAMETERS") if ("TEST_NAME" eq "TEST_NAME");
        # TEST_NAME  : In which test the bug was reported.
        # OS_VERSION : In which OS version the bug was reported because this test is run over all the SLE versions.
        # BUG_NUMBER : Bugzilla bug number for tracking the issue.
        # PARAMETER  : What parameters have changed.
        # TEST_NAME  : The function needs to be trigger only in the targeted test.
        parse_extra_log("XUnit", "$test_repo/$robot_test.xml");
        upload_logs("$test_repo/$robot_test.html", failok => 1);
    }
}

1;
