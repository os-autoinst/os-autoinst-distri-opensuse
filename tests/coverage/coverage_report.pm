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
    assert_script_run 'funkoverage report /var/coverage/data /var/coverage/report';
    # Raw coverage data is large; only upload it when explicitly requested.
    if (get_var('BINARY_COVERAGE_UPLOAD_DATA')) {
        assert_script_run 'tar -czf /tmp/coverage_data.tar.gz -C /var/coverage data';
        upload_logs('/tmp/coverage_data.tar.gz', failok => 1);
    }
    # Upload the coverage report files
    my @files = split("\n", script_output 'ls -1 /var/coverage/report/*');
    # parse_extra_log() uploads the file first, then parses it via OpenQA::Parser
    # (require'd internally); on a bare isotovideo worker without the full openQA
    # install (e.g. run_this_in_openqa's container) that module doesn't exist, so
    # it croaks — after the upload already happened. Installing OpenQA::Parser
    # there isn't a lightweight fix: it comes from openQA-common, which pulls in
    # ~140 packages (Mojolicious, DateTime, Selenium, even a different os-autoinst
    # build) — the "openQA stack" a bare isotovideo worker deliberately doesn't
    # have. So: try the structured parse, but don't let its absence fail this
    # module — the raw (already uploaded) file is enough outside a full openQA install.
    for (grep { /\.xml/ } @files) {
        eval { parse_extra_log('XUnit', $_) };
        record_info('XUnit parse skipped', $@) if $@;
    }
    # upload the files except the XML reports
    upload_logs($_) for grep { $_ !~ /\.xml/ } @files;
}

1;
