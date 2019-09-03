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
# - Stop packagekit service
# - Add qa-head repository
# - Install qa_test_xfstests fio
# - If XFSTESTS_REPO is set, install xfstests, filesystems
# - Otherwise, run "/usr/share/qa/qa_test_xfstests/install.sh"
# Maintainer: Yong Sun <yosun@suse.com>
package install;

use 5.018;
use strict;
use warnings;
use base 'opensusebasetest';
use utils;
use testapi;
use repo_tools 'add_qa_head_repo';

my $STATUS_LOG  = '/opt/status.log';
my $VERSION_LOG = '/opt/version.log';

# Create log file used to generate junit xml report
sub log_create {
    my $file = shift;
    my $cmd  = "[[ -f $file ]] || echo 'Test in progress' > $file";
    assert_script_run($cmd);
}

sub collect_version {
    my $file = shift;
    my $cmd  = "(cd /tmp/xfstests-dev; git rev-parse HEAD; cd - > /dev/null; rpm -qa xfsprogs xfsdump btrfsprogs; uname -r) | tee $file";
    script_run($cmd);
}

sub run {
    my $self = shift;
    $self->select_serial_terminal;

    # Disable PackageKit
    # This is done by the previous module (enable_kdump) only if NO_KDUMP is not set
    pkcon_quit;

    add_qa_head_repo;

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
    collect_version($VERSION_LOG);
}

sub test_flags {
    return {fatal => 1};
}

1;
