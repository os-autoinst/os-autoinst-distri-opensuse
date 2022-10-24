# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: timezone coreutils
# Summary: Check that it's possible to dump a zone data and to set a
#          custom rule for a given zone.
# - Check if timezone is installed
# - Run "zdump Europe/London", check output string format
# - Run "date", check output string format
# - Create custom command "zdump -v Europe/Rome | grep -E 'Sun Mar 25
# [0-9]{2}:[0:9]{2}:[0-9]{2} 2018'"" and validate output for "Europe" "Rome" and isdst=1
# - Compile a custom timezone rule using the command above, check "isdst=" output
# - Revert timezone changes
# Maintainer: Paolo Stivanin <pstivanin@suse.com>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use strict;
use warnings;

sub get_tz_data {
    my $save = shift;
    my $test_data = <<EOF;
Rule    EU      1981    max     -       Mar     lastSun  1:00u  $save   S
Rule    EU      1996    max     -       Oct     lastSun  1:00u  0       -
Zone Europe/Rome -1:00 EU CE%sT
EOF
    return $test_data;
}

sub set_data_and_validate {
    my $tz_data = get_tz_data($_[0]);
    script_run("echo '$tz_data' > $_[1]", 0);
    assert_script_run("zic " . $_[1]);
    my @dst = split /:/, $_[0];
    validate_script_output($_[2], sub { m/Europe\/Rome.*isdst=$dst[0].*/ });
}

sub run {
    select_serial_terminal;

    assert_script_run("rpm -q timezone");

    validate_script_output("zdump Europe/London", sub { m/Europe\/London\s+\w{3} \w{3}\s+\d+ (\d{2}|:){5} \d{4} (GMT|BST)/ });
    validate_script_output("date", sub { m/\w{3} \w{3}\s+\d+ (\d{2}|:){5} \w+ \d{4}/ });

    my $filename = "testdata.zone";
    my $zdump_cmd = "zdump -v Europe/Rome | grep -E 'Sun Mar 25 [0-9]{2}:[0:9]{2}:[0-9]{2} 2018'";

    # validate that isdst is set to 1 (default, from upstream)
    validate_script_output($zdump_cmd, sub { m/Europe\/Rome.*isdst=1.*/ });

    # write a file with a custom rule for Europe/Rome with isdst set to 0, compile it with zic and verify that the change was applied
    set_data_and_validate("0", $filename, $zdump_cmd);

    # revert back the change
    set_data_and_validate("1:00", $filename, $zdump_cmd);
}

1;
