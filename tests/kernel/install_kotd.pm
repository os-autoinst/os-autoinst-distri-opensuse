# SUSE's openQA tests
#
# Copyright 2016-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: kernel-default
# Summary: Module installs the KOTD (kernel of the day) and then reboots.
# Maintainer: Petr Cervinka <pcervinka@suse.com>

use 5.018;
use warnings;
use base "opensusebasetest";
use testapi;
use serial_terminal 'select_serial_terminal';
use Utils::Backends;
use utils;
use kernel;
use power_action_utils 'power_action';

sub run {
    my $self = shift;
    $self->wait_boot;
    # Use root-console for KOTD installation on svirt instead of root-sut-serial poo#54275
    is_svirt ? select_console('root-console') : select_serial_terminal;
    # Get url of kotd/kmp repositories
    my $kotd_repo = get_required_var('KOTD_REPO');
    my $kmp_repo = get_var('KMP_REPO');
    # Make sure that system is fully updated
    fully_patch_system;
    # Insert isofs module to be able to access repositories on CD after
    # kernel removal
    assert_script_run 'modprobe isofs';
    # Remove all installed kernel and related packages
    remove_kernel_packages;
    # Enable kotd/kmp repositories
    zypper_ar($kotd_repo, name => 'KOTD', priority => 90, no_gpg_check => 1);
    zypper_ar($kmp_repo, name => 'KMP', priority => 90, no_gpg_check => 1) if $kmp_repo;
    # Install latest kernel
    zypper_call("in -l kernel-default");
    # Check for multiple kernel installation
    assert_script_run '[ "$(zypper se -s kernel-default | grep -c i+)" = "1" ]', fail_message => 'More than one kernel was installed';
    # Reboot system after kernel installation
    power_action('reboot');
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Notes

=head2 INSTALL_KOTD
Set 1 to enable KOTD.

=head2 KOTD_REPO
URL of a kernel of the day repository:
http://download.suse.de/ibs/Devel:/Kernel:/SLE12-SP5/standard/
http://download.opensuse.org/repositories/Kernel:/HEAD/standard/

=head2 KMP_REPO
URL of kernel module packages repository for SLES in development:
http://download.suse.de/ibs/Devel:/Kernel:/SLE12-SP5:/KMP/standard/
=cut
