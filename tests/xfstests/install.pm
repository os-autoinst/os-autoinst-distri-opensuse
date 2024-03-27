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
use version_utils qw(is_sle is_leap is_tumbleweed is_sle_micro is_transactional);
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
        zypper_ar('http://download.opensuse.org/repositories/home:/yosun:/branches:/filesystems/openSUSE_Tumbleweed/', name => 'xfstests-repo', priority => 90, no_gpg_check => 1);
    }
    elsif (is_sle_micro('>=6.0')) {
        my $repo_url = get_var('XFSTESTS_REPO', 'http://download.suse.de/ibs/home:/yosun:/branches:/QA:/Head/SUSE_ALP_Products_Marble_6.0_standard/');
        my $dep_url = get_var('DEPENDENCY_REPO', 'http://download.suse.de/ibs/home:/yosun:/branches:/SUSE:/Factory:/Head/standard/');
        zypper_ar($repo_url, name => 'xfstests-repo');
        zypper_ar($dep_url, name => 'dependency-repo');
    }
    zypper_call('--gpg-auto-import-keys ref');
    record_info('repo info', script_output('zypper lr -U'));
    if (is_transactional) {
        script_run('id fsgqa &> /dev/null || useradd -d /home/fsgqa -k /etc/skel -ms /bin/bash -U fsgqa');
        script_run('id fsgqa2 &> /dev/null || useradd -d /home/fsgqa2 -k /etc/skel -ms /bin/bash -U fsgqa2');
        script_run('getent group sys >/dev/null || groupadd -r sys');
        script_run('id daemon &> /dev/null || useradd daemon -g sys');
        trup_call('pkg install xfstests');
        unless (is_sle_micro('>=6.0')) {
            trup_call('--continue pkg install fio');
        }
        reboot_on_changes;
    }
    else {
        zypper_call('in xfstests fio');
    }
    if (is_sle) {
        script_run 'ln -s /var/lib/xfstests /opt/xfstests';
    }
    elsif (is_tumbleweed || is_leap) {
        script_run 'ln -s /usr/lib/xfstests /opt/xfstests';
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
    # Return if xfstests installed
    script_run("zypper se -i xfstests") != 0 || return;

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
