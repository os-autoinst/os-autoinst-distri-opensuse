# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: collect coverage data, create reports and exports them
# Maintainer: Andrea Manzini <andrea.manzini@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    assert_script_run 'mkdir -p /var/coverage/report';
    # funkoverage report reads eBPF trace logs, resolves symbols via eu-unstrip
    # and DWARF debug info, and writes XML + HTML for every instrumented binary
    # and shared library.  With the default 90 s timeout this reliably fails
    # once the schedule tracks more than ~5 binaries.  600 s is sufficient for
    # schedules with up to ~20 targets and their transitive shared libraries.
    assert_script_run 'funkoverage report /var/coverage/data /var/coverage/report', timeout => 600;
    # Upload the coverage report files
    my @files = split("\n", script_output 'ls -1 /var/coverage/report/*');
    # parse the XML reports
    parse_extra_log('XUnit', $_) for grep { /\.xml/ } @files;
    # upload the files except the XML reports
    upload_logs($_) for grep { $_ !~ /\.xml/ } @files;
}

1;
