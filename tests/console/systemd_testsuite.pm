# SUSE's openQA tests
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Run testsuite included in systemd sources
# Maintainer: Thomas Blume <tblume@suse.com>

use base "consoletest";
use warnings;
use strict;
use testapi;
use utils;

sub run() {
    # install systemd testsuite
    select_console 'root-console';
    if (check_var('VERSION', '12-SP2')) {
        zypper_call('ar http://download.suse.de/ibs/QA:/SLE12SP2/update/ systemd-testrepo');
    }

    elsif (check_var('VERSION', '12-SP3')) {
        zypper_call('ar http://download.suse.de/ibs/QA:/SLE12SP3/update/ systemd-testrepo');
    }
    else {
        my $version = get_var('VERSION');
        my $distri  = get_var('DISTRI');
        die "systemd testsuite tests not supported for $distri version $version";
    }

    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('in systemd-testsuite');

    # run the testsuite test scripts
    assert_script_run('cd /var/opt/systemd-tests; ./run-tests.sh --all 2>&1 | tee /tmp/testsuite.log', 300);
    assert_screen('systemd-testsuite-result');

    #cleanup
    zypper_call('rm systemd-testsuite');
}


sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    assert_script_run('cp /tmp/testsuite.log /var/opt/systemd-tests/logs; tar cjf systemd-testsuite-logs.tar.bz2 logs');
    upload_logs('systemd-testsuite-logs.tar.bz2');
}


1;
