# SUSE's openQA tests
#
# Copyright 2018-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: zypper xfstests fio
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
use serial_terminal 'select_serial_terminal';
use repo_tools 'add_qa_head_repo';
use version_utils qw(is_sle is_leap is_tumbleweed is_alp is_transactional);
use File::Basename;
use transactional;

my $STATUS_LOG = '/opt/status.log';
my $VERSION_LOG = '/opt/version.log';

sub install_xfstests_from_repo {
    if (is_sle) {
        add_qa_head_repo(priority => 100);
    }
    elsif (is_tumbleweed) {
        zypper_ar('http://download.opensuse.org/tumbleweed/repo/oss/', name => 'repo-oss');
        zypper_ar('http://download.opensuse.org/tumbleweed/repo/non-oss/', name => 'repo-non-oss');
    }
    elsif (is_alp) {
        my $repo_url = get_var('XFSTESTS_REPO', 'http://download.suse.de/ibs/home:/yosun:/branches:/QA:/Head/ALP-Standard-Core-1.0-Build/');
        my $dep_url = get_var('DEPENDENCY_REPO', 'http://download.suse.de/ibs/home:/yosun:/branches:/SUSE:/Factory:/Head/standard/');
        zypper_ar($repo_url, name => 'xfstests-repo');
        zypper_ar($dep_url, name => 'dependency-repo');
    }
    zypper_call('--gpg-auto-import-keys ref');
    record_info('repo info', script_output('zypper lr -U'));
    if (is_transactional) {
        trup_call('pkg install xfstests');
        unless (is_alp) {
            trup_call('--continue pkg install fio');
        }
        reboot_on_changes;
    }
    else {
        zypper_call('in xfstests fio');
    }
    if (is_sle) {
        script_run 'ln -s /var/lib/xfstests/ /opt/xfstests';
    }
    elsif (is_tumbleweed || is_leap) {
        script_run 'ln -s /usr/lib/xfstests/ /opt/xfstests';
    }
}

# Create log file used to generate junit xml report
sub log_create {
    my $file = shift;
    my $cmd = "[[ -f $file ]] || echo 'Test in progress' > $file";
    assert_script_run($cmd);
}

sub collect_version {
    my $file = shift;
    my $cmd = "(rpm -qa xfsprogs xfsdump btrfsprogs e2fsprogs coreutils kernel-default xfstests; uname -r; rpm -qi kernel-default) | tee $file";
    script_run($cmd);
    upload_logs($file, timeout => 60, log_name => basename($file));
}

sub run {
    select_serial_terminal;

    # Disable PackageKit
    quit_packagekit;

    install_xfstests_from_repo;

    # Create log file
    log_create($STATUS_LOG);
    collect_version($VERSION_LOG);
}

sub test_flags {
    return {fatal => 1};
}

1;
