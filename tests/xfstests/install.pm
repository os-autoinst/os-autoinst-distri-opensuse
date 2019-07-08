# SUSE's openQA tests
#
# Copyright © 2018-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Install xfstests
# Maintainer: Yong Sun <yosun@suse.com>
package install;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;

my $STATUS_LOG = '/opt/status.log';

# Create log file used to generate junit xml report
sub log_create {
    my $file = shift;
    my $cmd  = "[[ -f $file ]] || echo 'Test in progress' > $file";
    assert_script_run($cmd);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Disable PackageKit
    # This is done by the previous module (enable_kdump) only if NO_KDUMP is not set
    pkcon_quit;

    # Add QA repo
    if (script_run('zypper lr qa-ibs')) {
        my $qa_head_repo = get_var('QA_HEAD_REPO', '');
        zypper_call("--no-gpg-check ar -f '$qa_head_repo' qa-ibs", timeout => 600);
    }

    # Install qa_test_xfstests
    zypper_call('--gpg-auto-import-keys ref', timeout => 600);
    zypper_call('in qa_test_xfstests',        timeout => 1200);
    zypper_call('in fio');

    if (get_var('XFSTESTS_REPO')) {
        # Add filesystems repository and install xfstests package
        zypper_call '--no-gpg-check ar -f ' . get_var('XFSTESTS_REPO') . ' filesystems';
        zypper_call '--gpg-auto-import-keys ref';
        zypper_call 'in xfstests';
        zypper_call 'rr filesystems';
        # Link the tests as the wrapper expects this somewhere else
        script_run 'ln -s /var/lib/xfstests/ /opt/xfstests';
    }
    else {
        # Build test suite from git snapshot provided by the qa_test_xfstests package
        assert_script_run('/usr/share/qa/qa_test_xfstests/install.sh', 600);
    }

    # Create log file
    log_create($STATUS_LOG);
}

sub test_flags {
    return {fatal => 1};
}

1;
