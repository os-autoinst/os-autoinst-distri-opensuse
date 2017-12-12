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
use version_utils 'sle_version_at_least';
use registration;

sub add_repos {
    my $qa_head_repo = get_required_var('QA_HEAD_REPO');
    zypper_call("ar $qa_head_repo qa_repo",   dumb_term => 1);
    zypper_call('--gpg-auto-import-keys ref', dumb_term => 1);
}

sub scc_we_enabled {
    script_run("zypper -n products -i", 0);
    return wait_serial(qr/Workstation Extension/);
}

sub add_desktop_productivity_module {
    if (get_required_var('ARCH') eq 'x86_64' and check_var('DISTRI', 'sle') and sle_version_at_least('15')) {
        add_suseconnect_product("sle-module-desktop-productivity");
    }
}

sub add_we_repo_if_available {
    # opensuse (doesn't have extensions) or SLE as registered product
    if (check_var('DISTRI', 'opensuse') || scc_we_enabled) {
        return;
    }
    # productQA test with enabled we as iso_2
    if (get_var('BUILD_WE') && get_var('ISO_2')) {
        zypper_call('ar dvd:///?devices=/dev/sr2 WSE', log => 'add-WSE.txt', dumb_term => 1);
        zypper_call('--gpg-auto-import-keys ref',      log => 'ref-WSE.txt', dumb_term => 1);
    }
}

sub install_runtime_dependencies {
    my @deps = qw(
      sysstat
      iputils
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

    # kernel-default-extra are only for SLE (in WE)
    # net-tools-deprecated are not available for SLE15
    # ntfsprogs are for SLE in WE, openSUSE has it in default repository
    my @maybe_deps = qw(
      kernel-default-extra
      net-tools
      net-tools-deprecated
      tpm-tools
      sssd-tools
      numactl
      wget
      psmisc
      binutils
      acl
      quota
      sudo
      ntfsprogs
    );
    for my $dep (@maybe_deps) {
        script_run('zypper -n -t in ' . $dep . ' | tee');
    }
}

sub install_build_dependencies {
    my @deps = qw(
      autoconf
      automake
      bison
      expect
      flex
      gcc
      git-core
      kernel-default-devel
      keyutils-devel
      libacl-devel
      libaio-devel
      libcap-devel
      libnuma-devel
      libopenssl-devel
      libselinux-devel
      libtirpc-devel
      make
    );
    zypper_call('-t in ' . join(' ', @deps), dumb_term => 1);

    my @maybe_deps = qw(
      gcc-32bit
      kernel-default-devel-32bit
      keyutils-devel-32bit
      libacl-devel-32bit
      libaio-devel-32bit
      libcap-devel-32bit
      libnuma-devel-32bit
      libopenssl-devel-32bit
      libselinux-devel-32bit
      libtirpc-devel-32bit
    );
    for my $dep (@maybe_deps) {
        script_run('zypper -n -t in ' . $dep . ' | tee');
    }
}

sub install_from_git {
    my $url = get_var('LTP_GIT_URL') || 'https://github.com/linux-test-project/ltp';
    my $tag = get_var('LTP_RELEASE') || '';
    my $configure = './configure --with-open-posix-testsuite --with-realtime-testsuite';
    my $extra_flags = get_var('LTP_EXTRA_CONF_FLAGS') || '';
    if ($tag) {
        $tag = ' -b ' . $tag;
    }
    assert_script_run("git clone -q --depth 1 $url" . $tag, timeout => 360);
    assert_script_run 'cd ltp';
    assert_script_run 'make autotools';
    assert_script_run("$configure $extra_flags", timeout => 300);
    assert_script_run 'make -j$(getconf _NPROCESSORS_ONLN)', timeout => 1440;
    script_run 'export CREATE_ENTRIES=1';
    assert_script_run 'make install', timeout => 360;
    assert_script_run "find ~/ltp/testcases/open_posix_testsuite/conformance/interfaces -name '*.run-test' > ~/openposix_test_list.txt";
    # It is a shallow clone so 'git describe' won't work
    script_run 'git log -1 --pretty=format:"git %h" > /opt/ltp_version';
}

sub install_from_repo {
    zypper_call('in qa_test_ltp', dumb_term => 1);
    assert_script_run q(find ${LTPROOT:-/opt/ltp}/testcases/bin/openposix/conformance/interfaces/ -name '*.run-test' > ~/openposix_test_list.txt);
    script_run 'rpm -q qa_test_ltp > /opt/ltp_version';
}

sub run {
    my $self     = shift;
    my $inst_ltp = get_var 'INSTALL_LTP';

    if ($inst_ltp !~ /(repo|git)/i) {
        die 'INSTALL_LTP must contain "git" or "repo"';
    }

    $self->wait_boot;

    # poo#18980
    if (check_var('ARCH', 'ppc64le') && check_var('VIRTIO_CONSOLE', 1)) {
        select_console('root-console');
        add_serial_console('hvc1');
        select_console('root-virtio-terminal');
    }
    else {
        select_console(get_var('VIRTIO_CONSOLE') ? 'root-virtio-terminal' : 'root-console');
    }

    add_desktop_productivity_module;
    add_we_repo_if_available;

    install_runtime_dependencies;

    if ($inst_ltp =~ /git/i) {
        install_build_dependencies;
        # bsc#1024050 - Watch for Zombies
        script_run('(pidstat -p ALL 1 > /tmp/pidstat.txt &)');
        install_from_git;
    }
    else {
        add_repos;
        install_from_repo;
    }

    # check kGraft if KGRAFT=1
    if (check_var("KGRAFT", '1')) {
        assert_script_run("uname -v | grep '/kGraft-'");
    }

    upload_logs '/root/openposix_test_list.txt';

    select_console('root-console');
    type_string "reboot\n";
}

sub post_fail_hook {
    my $self = shift;

    # bsc#1024050
    script_run('pkill pidstat');
    upload_logs('/tmp/pidstat.txt');
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

# vim: set sw=4 et:
