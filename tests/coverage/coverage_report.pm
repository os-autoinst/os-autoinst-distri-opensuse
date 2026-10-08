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
    # Redirect funkoverage output to a log file. With 50+ targets the
    # report progress output can fill the serial buffer and break
    # subsequent serial commands.
    assert_script_run 'funkoverage report /var/coverage/data /var/coverage/report >/tmp/fv_report.log 2>&1', timeout => 600;
    # Raw coverage data is large; only upload it when explicitly requested.
    if (get_var('BINARY_COVERAGE_UPLOAD_DATA')) {
        assert_script_run 'tar -czf /tmp/coverage_data.tar.gz -C /var/coverage data';
        upload_logs('/tmp/coverage_data.tar.gz', failok => 1);
    }
    # List report files via a file to avoid serial buffer issues with large listings.
    assert_script_run 'ls /var/coverage/report/ > /tmp/rpt_files.txt';
    my @files = map { "/var/coverage/report/$_" }
      split(/\n/, script_output('cat /tmp/rpt_files.txt'));
    # parse_extra_log() uploads the file first, then parses it via OpenQA::Parser
    # (require'd internally); on a bare isotovideo worker without the full openQA
    # install (e.g. run_this_in_openqa's container) that module doesn't exist, so
    # it croaks — after the upload already happened. So: try the structured parse,
    # but don't let its absence fail this module.
    for (grep { /\.xml/ } @files) {
        eval { parse_extra_log('XUnit', $_) };
        record_info('XUnit parse skipped', $@) if $@;
    }
    # Upload HTML reports, skipping shared library reports (lib*.html) which
    # can number 200+ with large target sets and cause upload timeouts.
    upload_logs($_) for grep { /\.html$/ && !/\/lib/i } @files;
}

1;
