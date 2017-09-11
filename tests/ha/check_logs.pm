# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Grep logs to find segfaults
# Maintainer: Loic Devulder <ldevulder@suse.com>

use base 'hacluster';
use strict;
use testapi;
use autotest;
use lockapi;

sub run {
    my $self = shift;
    barrier_wait('FENCING_DONE_' . $self->cluster_name);
    select_console 'root-console';

    script_run 'hb_report -f 2014 hb_report', 120;
    upload_logs 'hb_report.tar.bz2';
    assert_script_run '(( $(grep -sR segfault /var/log | wc -l) == 0 ))';
    barrier_wait('LOGS_CHECKED_' . $self->cluster_name);
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

sub post_fail_hook {
    my $self = shift;

    # Save a screenshot before trying further measures which might fail
    save_screenshot;

    # Try to save logs as a last resort
    $self->export_logs();
}

1;
# vim: set sw=4 et:
