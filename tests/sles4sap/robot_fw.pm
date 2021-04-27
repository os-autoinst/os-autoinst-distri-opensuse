# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check the sles4sap "from scratch" settings (without saptune/sapconf) using the robot framework.
#          This test is configured to be used with a 2 GB RAM system.
#          Some values depend of the hardware configuration.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base "sles4sap";
use testapi;
use strict;
use warnings;
use version_utils qw(is_sle);
use utils qw(zypper_call);
use hacluster qw(is_package_installed);

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
    my ($module, $os_version, $bsc_number, @parameters) = @_;
    foreach my $parameter (@parameters) {
        if (check_var("VERSION", $os_version) && check_failure($module, $parameter)) {
            record_soft_failure "$bsc_number - Wrong value for $parameter";
            remove_value($module, $parameter);
        }
    }
}

sub run {
    my ($self)           = @_;
    my $robot_fw_version = '3.2.2';
    my $test_repo        = "/robot/tests/sles-" . get_var('VERSION');
    my $robot_tar        = "robot.tar.gz";
    my $python_bin       = is_sle('15+') ? 'python3' : 'python';

    # Download and prepare the test environment
    assert_script_run "cd /; curl -f -v qa-css-hq.qa.suse.de/$robot_tar -o $robot_tar";
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
        select_console 'root-console';
    }

    # Execute each test and upload its results
    assert_script_run "cd $test_repo";
    foreach my $robot_test (split /\n/, script_output "ls $test_repo") {
        record_info("$robot_test", "Starting $robot_test");
        script_run "robot --log $robot_test.html --xunit $robot_test.xml $robot_test";
        # Soft fail section - How to add a new one
        # add_softfail("TEST_NAME", "OS_VERSION", "BUG_NUMBER", "PARAMETERS") if ("TEST_NAME" eq "TEST_NAME");
        # TEST_NAME  : In which test the bug was reported.
        # OS_VERSION : In which OS version the bug was reported because this test is run over all the SLE versions.
        # BUG_NUMBER : Bugzilla bug number for tracking the issue.
        # PARAMETER  : What parameters have changed.
        # TEST_NAME  : The function needs to be trigger only in the targeted test.
        if ($robot_test eq "sysctl.robot") {
            # bsc#1181163 - unexpected values for net.ipv6.conf.lo.use_tempaddr and net.ipv6.conf.lo.accept_redirects
            add_softfail("sysctl.robot", "15-SP1", "bsc#1181163", qw(Sysctl_net_ipv6_conf_lo_accept_redirects Sysctl_net_ipv6_conf_lo_use_tempaddr));
        }
        parse_extra_log("XUnit", "$test_repo/$robot_test.xml");
        upload_logs("$test_repo/$robot_test.html", failok => 1);
    }
}

1;
