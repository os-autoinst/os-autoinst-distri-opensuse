# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check sles4sap settings with and without tuning using robot framework.
#          This test is configured to be used with a 2 GB RAM system.
#          Some values depend of the hardware configuration.
# Maintainer: Julien Adamek <jadamek@suse.com>

use base "sles4sap";
use testapi;
use strict;
use warnings;
use version_utils 'is_sle';

sub run {
    my ($self)           = @_;
    my $robot_fw_version = '3.2.2';
    my $test_repo        = "/robot/tests/" . get_var('SLE_PRODUCT') . "-" . get_var('VERSION');
    my $robot_tar        = "robot.tar.gz";
    my $python_bin       = is_sle('15+') ? 'python3' : 'python';

    # Download and prepare the test environment
    assert_script_run "cd /; curl -f -v qa-css-hq.qa.suse.de/$robot_tar -o $robot_tar";
    assert_script_run "tar -xzf $robot_tar";

    # Install the robot framework
    assert_script_run "unzip /robot/bin/robotframework-$robot_fw_version.zip";
    assert_script_run "cd robotframework-$robot_fw_version";
    assert_script_run "$python_bin setup.py install";

    # Disable specific tuning if we are testing SLES
    if (check_var('SLE_PRODUCT', 'sles')) {
        assert_script_run "systemctl disable sapconf";
        $self->reboot;
        select_console 'root-console';
    }

    # Execute each test and upload its results
    assert_script_run "cd $test_repo";
    foreach my $robot_test (split /\n/, script_output "ls $test_repo") {
        record_info("$robot_test", "Starting $robot_test");
        script_run "robot --log $robot_test.html --xunit $robot_test.xml $robot_test";
        parse_extra_log("XUnit", "$test_repo/$robot_test.xml");
        upload_logs("$test_repo/$robot_test.html", failok => 1);
    }
}

1;
