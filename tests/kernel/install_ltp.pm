# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: This module installs the LTP (Linux Test Project) and then reboots.
# Maintainer: Richard palethorpe <rpalethorpe@suse.com>
# Usage details are at the end of this file.
use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;

sub add_repos {
    my $qa_head_repo = get_var 'QA_HEAD_REPO';
    die 'No QA_HEAD_REPO' unless $qa_head_repo;
    $qa_head_repo =~ s/\/$//;

    zypper_call "ar '$qa_head_repo/QA:Head.repo'";
    zypper_call '--gpg-auto-import-keys ref';
}

sub try_add_workstation_addon {
    my $have_wse = get_var('BUILD_WE') && get_var('ISO_2');
    if ($have_wse) {
        zypper_call 'ar dvd:///?devices=/dev/sr2 WSE', log => 'add-WSE.txt';
        zypper_call '--gpg-auto-import-keys ref',      log => 'ref-WSE.txt';
    }
    return $have_wse;
}

sub install_dependencies {
    my @deps = qw(git-core make automake autoconf gcc expect libnuma-devel libaio-devel
      numactl flex bison dmapi-devel kernel-default-devel libopenssl-devel libselinux-devel
      libacl-devel libtirpc-devel keyutils-devel libcap-devel net-tools sysstat
      tpm-tools tpm2.0-tools psmisc acl quota);
    if (check_var('DISTRI', 'opensuse') || try_add_workstation_addon()) {
        push @deps, 'ntfsprogs';
    }
    else {
        record_soft_failure 'Need Workstation Extension for ntfsprogs; poo#15652';
    }
    zypper_call('in ' . join(' ', @deps), log => 'install-deps.txt');

    script_run('zypper -n in net-tools-deprecated');
}

sub install_from_git {
    my $url = get_var('LTP_GIT_URL') || 'https://github.com/linux-test-project/ltp';
    my $tag = get_var('LTP_RELEASE') || '';
    if ($tag) {
        $tag = ' -b ' . $tag;
    }
    assert_script_run("git clone $url --depth 1" . $tag, timeout => 360);
    assert_script_run 'cd ltp';
    assert_script_run 'make autotools';
    assert_script_run('./configure --with-open-posix-testsuite --with-realtime-testsuite', timeout => 300);
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)', timeout => 1440;
    assert_script_run 'make install',                        timeout => 360;
    assert_script_run "find ~/ltp/testcases/open_posix_testsuite/conformance/interfaces -name '*.run-test' > ~/openposix_test_list.txt";
}

sub install_from_repo {
    zypper_call 'in qa_test_ltp';
    assert_script_run "find /opt/ltp/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > ~/openposix_test_list.txt";
}

sub run {
    my $self     = shift;
    my $inst_ltp = get_var 'INSTALL_LTP';
    $self->wait_boot;
    select_console(get_var('VIRTIO_CONSOLE') ? 'root-virtio-terminal' : 'root-console');

    if ($inst_ltp =~ /git/i) {
        install_dependencies;
        install_from_git;
    }
    elsif ($inst_ltp =~ /repo/i) {
        add_repos;
        install_from_repo;
    }
    else {
        die 'INSTALL_LTP must contain "git" or "repo"';
    }
    upload_logs '/root/openposix_test_list.txt';

    select_console('root-console');
    type_string "reboot\n";
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 Required Repositories

For OpenSUSE the standard OSS repositories will suffice. On SLE the SDK addon
is essential when installing from Git. The Workstation Extension is nice to have,
but most tests will run without it. At the time of writing their is no appropriate
HDD image available with WE already configured so we must add its media inside this
test.

=head2 Example

Example SLE test suite configuration for installation by Git:

BOOT_HDD_IMAGE=1
DESKTOP=textmode
HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_sdk_installed.qcow2
INSTALL_LTP=from_git
ISO=SLE-%VERSION%-Server-DVD-%ARCH%-Build%BUILD%-Media1.iso
ISO_1=SLE-%VERSION%-SDK-DVD-%ARCH%-Build%BUILD_SDK%-Media1.iso
ISO_2=SLE-%VERSION%-WE-DVD-%ARCH%-Build%BUILD_WE%-Media1.iso
PUBLISH_HDD_1=SLES-%VERSION%-%ARCH%-minimal_with_ltp_installed.qcow2
QEMUCPUS=4
QEMURAM=4096
RUN_AFTER_TEST=sles12_minimal_base+sdk_create_hdd

For openSUSE the configuration should be simpler as you can install git and the
other dev tools from the main repository. You just need a text mode installation
image to boot from (a graphical one will probably work as well). Depending how
OpenQA is configured the ISO variable may not be necessary either.

=head2 INSTALL_LTP

Either should contain 'git' or 'repo'. Git is recommended for now. If you decide
to install from the repo then also specify QA_HEAD_REPO.

=head2 LTP_RELEASE

When installing from Git this can be set to a release tag, commit hash, branch
name or whatever else Git will accept. Usually this is set to a release, such as
20160920, which will cause that release to be used. If not set, then the default
clone action will be performed, which probably means the latest master branch
will be used.

=head2 LTP_GIT_URL

Overrides the official LTP GitHub repository URL.

=cut
