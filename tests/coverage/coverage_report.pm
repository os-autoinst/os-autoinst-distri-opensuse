# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: collect coverage data, create reports and exports them
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run 'mkdir -p /var/coverage/report';
    assert_script_run 'funkoverage report /var/coverage/data /var/coverage/report';
    # Upload the coverage report files
    my @files = split("\n", script_output 'ls -1 /var/coverage/report/*');
    # parse the XML reports
    parse_extra_log('XUnit', $_) for grep { /\.xml/ } @files;
    # upload the files except the XML reports
    upload_logs($_) for grep { $_ !~ /\.xml/ } @files;
}

1;
