# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
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
use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use LTP::Install;
use upload_system_log;
use Utils::Backends 'use_ssh_serial_console';
use version_utils 'is_jeos';

sub run {
    my $self = shift;

    if (!get_var('LTP_BAREMETAL') && !is_jeos) {
        $self->wait_boot;
    }

    # poo#18980
    if (get_var('OFW') && !check_var('VIRTIO_CONSOLE', 0)) {
        select_console('root-console');
        add_serial_console('hvc1');
    }

    if (check_var('BACKEND', 'ipmi')) {
        use_ssh_serial_console;
    }
    else {
        $self->select_serial_terminal;
    }

    install_ltp;
}

sub post_fail_hook {
    my $self = shift;

    upload_system_logs();

    # bsc#1024050
    script_run('pkill pidstat');
    upload_logs('/tmp/pidstat.txt', failok => 1);
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Usage

This test is meant to be used on VM based testing, as it publish image via
PUBLISH_HDD_1. But it should not be used for baremetal/IPMI testing due
FOLLOW_TEST_DIRECTLY not yet implemented (see poo#41066). Instead LTP will
be installed on each baremetal/IPMI test (unless it happen by change test
is run directly after another LTP test), thus running it before is waste of time.

Tests expecting to be booted with additional kernel parameters added via
GRUB_PARAM variable in add_custom_grub_entries() (currently only IMA tests)
are rebooted to get grub with these parameters.

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
START_AFTER_TEST=create_hdd_minimal_base+sdk

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

=head2 GRUB_PARAM

Append custom group entries with appended group param via
add_custom_grub_entries().

=cut
