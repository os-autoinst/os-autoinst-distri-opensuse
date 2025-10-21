# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Wrapper for package installation, zypper or transactional update
# Maintainer: QE Core <qe-core@suse.de>

package package_utils;
use Mojo::Base qw(Exporter);
use testapi;
use version_utils qw(is_transactional);
use transactional qw(trup_call check_reboot_changes);
use utils qw(zypper_call);

our @EXPORT = qw(install_package uninstall_package);

=head1 DESCRIPTION

    Wrapper for zypper_call and trup_call

=head2 install_package

    install_package('kernel-devel' [, trup_packages => 'kernel-default-base] [, zypper_packages => 'kernel-devel']);

C<packages> defines packages to install for both zypper and trup call,
Parameters C<trup_extra> and C<zypper_extra> define transactional
or zypper specific packages.
C<skip_trup> or C<skip_zypper> will return from fucntion,
record_info is used if sentence is argument value.
C<trup_reboot> parameter will run check_reboot_changes after trup_call,
reboot if diff between the current FS and the new snapshot.

=cut

sub install_package {
    my $ret;
    my ($packages, %args) = @_;
    die 'Paramater packages is required' unless defined($packages);
    my $timeout = $args{timeout} // 500;

    if (is_transactional) {
        record_info('install_package', $args{skip_trup}) if $args{skip_trup} =~ /\w+/;
        return if $args{skip_trup};
        $packages .= ' ' . $args{trup_extra} // '';
        my $cmd = 'pkg in -l ' . $packages;
        $cmd = '-c ' . $cmd if $args{trup_continue} // 0;
        $ret = trup_call($cmd, timeout => $args{timeout});
        check_reboot_changes if $args{trup_reboot};
    }
    else {
        record_info('install_package', $args{skip_zypper}) if $args{skip_zypper} =~ /\w+/;
        return if $args{skip_zypper};
        $packages .= ' ' . $args{zypper_extra} // '';
        $ret = zypper_call('in -l ' . $packages, timeout => $args{timeout});
    }
    return $ret;
}

=head2 uninstall_package

    uninstall_package('kernel-devel' [, trup_extra => 'kernel-default-base'] [, zypper_extra => 'kernel-devel']);

C<packages> defines packages to uninstall for both zypper and trup call,
Parameters C<trup_extra> and C<zypper_extra> define transactional
or zypper specific packages.
C<skip_trup> or C<skip_zypper> will return from fucntion,
record_info is used if sentence is argument value.
C<trup_continue> parameter will add changes to the default snapshot.
Without this parameter, any changes in the default snapshot will be
discarded and a new snapshot will be created based on the active one.
C<trup_reboot> parameter will run check_reboot_changes after trup_call,
reboot if diff between the current FS and the new snapshot.

=cut

sub uninstall_package {
    my $ret;
    my ($packages, %args) = @_;
    die 'Paramater packages is required' unless defined($packages);
    my $timeout = $args{timeout} // 500;

    if (is_transactional) {
        record_info('uninstall_package', $args{skip_trup}) if $args{skip_trup} =~ /\w+/;
        return if $args{skip_trup};
        $packages .= ' ' . $args{trup_extra} // '';
        my $cmd = 'pkg remove ' . $packages;
        $cmd = '-c ' . $cmd if $args{trup_continue} // 0;
        $ret = trup_call($cmd, timeout => $args{timeout});
        check_reboot_changes if $args{trup_reboot};
    }
    else {
        record_info('uninstall_package', $args{skip_zypper}) if $args{skip_zypper} =~ /\w+/;
        return if $args{skip_zypper};
        $packages .= ' ' . $args{zypper_extra} // '';
        $ret = zypper_call('rm ' . $packages, timeout => $args{timeout});
    }
    return $ret;
}

1;
