# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: *-mini packages must not be delivered in the image
# There are several packages that should be excluded according to prjconf
# check for packages listed in *Substitute*
# for instance L#40 of prjconf sle15sp1
# https://build.suse.de/projects/SUSE:SLE-15-SP1:GA/prjconf
# Maintainer: Michal Nowak <mnowak@suse.com>

use Mojo::Base qw(consoletest);
use testapi;
use serial_terminal qw(select_serial_terminal);

sub run {
    select_serial_terminal;

    # Check that no *-mini RPM package is present
    assert_script_run 'rpm -qa *-mini *-mini1 systemd-mini-sysvinit dummy-release *-upstream | tee excluded_rpms';
    die "System contains excluded rpms from prjconf!\n" if (script_run('test -s ./excluded_rpms') == 0);
}

sub post_fail_hook {
    my $self = shift;
    select_console 'log-console';
    upload_logs './excluded_rpms';
    $self->save_and_upload_log('rpm -qa', '/tmp/rpmquery_all', {screenshot => 1});
}

1;
