# SUSE's openQA tests
#
# Copyright 2016-2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: aide
# Summary: FIPS case for AIDE (Advanced Intrusion Detection Environment) check tool
#          Test basic function of AIDE and check differences between aide.db and file system
#
#          1. Install aide if it has not been installed
#          2. Initialize the aide database and check
#          3. Check the difference between database and file system
#          4. Modify the file system and run aide check again
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64364, poo#102032, tc#1744128

use base "consoletest";
use testapi;
use utils "zypper_call";
use strict;
use warnings;

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    zypper_call "in aide wget";

    assert_script_run "wget --quiet " . data_url("security/aide_conf");
    assert_script_run "mv aide_conf /etc/aide.conf";


    assert_script_run "mkdir /testdir";
    assert_script_run "echo hello > /testdir/t1.log";

    # Initialize the database and move it to the appropriate place before using the --check command
    validate_script_output "aide --init 2>&1 || true", sub { m/AIDE initialized database/ }, 300;
    send_key 'ret';

    assert_script_run "cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db";

    # Checks the database for added entries
    validate_script_output "aide --check 2>&1 || true", sub { m/AIDE found NO differences between database and filesystem. Looks okay!!/ && m/Number of entries:(\s+)1/ }, 300;

    assert_script_run "touch /testdir/t2.log";

    # Checks the database for added/changed entries
    validate_script_output "aide --check 2>&1 || true", sub { m/AIDE found differences between database and filesystem/ && m/Added entries:(\s+)1/ && m/Changed entries:(\s+)0/ }, 300;

    assert_script_run "rm /testdir/t2.log && echo world >> /testdir/t1.log";

    # Checks the database for changed entries
    validate_script_output "aide --check 2>&1 || true",
      sub { m/AIDE found differences between database and filesystem/ && m/Added entries:(\s+)0/ && m/Removed entries:(\s+)0/ && m/Changed entries:(\s+)1/ },
      300;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
