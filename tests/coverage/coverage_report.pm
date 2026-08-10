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
    # Redirect funkoverage output to a log file to prevent serial console flooding.
    # With 50+ targets the report progress output fills the terminal buffer and
    # leaves the serial console in a degraded state for subsequent commands.
    assert_script_run 'funkoverage report /var/coverage/data /var/coverage/report >/tmp/fv_report.log 2>&1', timeout => 600;
    # Now the serial console is clean; ls redirect works reliably.
    assert_script_run 'ls /var/coverage/report/ > /tmp/rpt_files.txt', timeout => 120;
    my @files = split /\n/, script_output('cat /tmp/rpt_files.txt', timeout => 120);
    my @xmlfiles  = map { "/var/coverage/report/$_" } grep { /\.xml$/  } @files;
    my @htmlfiles = map { "/var/coverage/report/$_" }
                    grep { /\.html$/ && !/^lib/i } @files;  # skip lib*.html (220+ shared lib reports)
    parse_extra_log('XUnit', $_) for @xmlfiles;
    upload_logs($_)              for @htmlfiles;
    # Print XML coverage summaries to serial console for ease of diagnostics (poo#205467)
    assert_script_run 'grep -h "<testsuite" /var/coverage/report/*.xml || true';
}

1;
