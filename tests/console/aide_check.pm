# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: aide
# Summary: FIPS case for AIDE (Advanced Intrusion Detection Environment) check tool
#          Test basic function of AIDE and check differences between aide.db and file system
#
#          1. Install aide if it has not been installed
#          2. Initialized the aide database and check
#          3. Check the difference between datebase and file system
#          4. Modified the file system and run aide check again
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

    zypper_call "in aide";
    assert_script_run "cp /etc/aide.conf /etc/aide.conf.bak";

    # Initialize the database and move it to the appropriate place before using the --check command
    validate_script_output "aide --init 2>&1 || true", sub { m/AIDE initialized database/ }, 300;
    send_key 'ret';

    assert_script_run "cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db";

    # Checks the database for inconsistencies and there is 1 new added entry
    validate_script_output "aide --check 2>&1 || true", sub { m/AIDE found differences between database and filesystem/ && m/Added entries:(\s+)1/ }, 300;

    assert_script_run "touch /var/log/testlog";

    # Checks the database for inconsistencies and there is 2 new added entry
    validate_script_output "aide --check 2>&1 || true", sub { m/AIDE found differences between database and filesystem/ && m/Added entries:(\s+)2/ }, 300;

    assert_script_run "mv /etc/aide.conf.bak /etc/aide.conf && rm /var/log/testlog";

    # Checks the database for inconsistencies and there is 1 new added entry, 1 removed entries, 2 entries changed
    validate_script_output "aide --check 2>&1 || true",
      sub { m/AIDE found differences between database and filesystem/ && m/Added entries:(\s+)1/ && m/Removed entries:(\s+)1/ && m/Changed entries:(\s+)2/ },
      300;
}

sub test_flags {
    return {always_rollback => 1};
}

1;
