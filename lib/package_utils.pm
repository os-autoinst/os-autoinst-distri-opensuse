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
use transactional qw(trup_call reboot_on_changes trup_apply);
use utils qw(zypper_call zypper_search);

our @EXPORT = qw(install_package install_available_packages uninstall_package);

=head1 DESCRIPTION

    Wrapper for zypper_call and trup_call

=head2 install_package

    install_package('kernel-devel' [, trup_packages => 'kernel-default-base] [, zypper_packages => 'kernel-devel']);

C<packages> defines packages to install for both zypper and trup call,
Parameters C<trup_extra> and C<zypper_extra> define transactional
or zypper specific packages.
C<skip_trup> or C<skip_zypper> will return from fucntion,
record_info is used if sentence is argument value.
C<trup_reboot> parameter will run reboot_on_changes after trup_call,
reboot if diff between the current FS and the new snapshot.
C<trup_apply> parameter will apply pending changes from the new snapshot
without rebooting, using C<transactional-update apply>.
C<trup_reboot> and C<trup_apply> are mutually exclusive.

B<Warning>: Only use C<trup_apply> for end user applications and server services.
Do not use it for kernel packages or system libraries that require a reboot,
as doing so may leave the system in an inconsistent state.

=cut

sub install_package {
    my $ret;
    my ($packages, %args) = @_;
    die 'Paramater packages is required' unless defined($packages);
    my $timeout = $args{timeout} // 500;

    if (is_transactional) {
        die "install_package: 'trup_reboot' and 'trup_apply' are mutually exclusive" if $args{trup_reboot} && $args{trup_apply};
        record_info('install_package', $args{skip_trup}) if $args{skip_trup} =~ /\w+/;
        return if $args{skip_trup};
        $packages .= ' ' . $args{trup_extra} // '';
        my $cmd = 'pkg in -l ' . $packages;
        $cmd = '-c ' . $cmd if $args{trup_continue} // 0;
        $ret = trup_call($cmd, timeout => $args{timeout});
        reboot_on_changes if $args{trup_reboot};
        trup_apply if $args{trup_apply};
    }
    else {
        record_info('install_package', $args{skip_zypper}) if $args{skip_zypper} =~ /\w+/;
        return if $args{skip_zypper};
        $packages .= ' ' . $args{zypper_extra} // '';
        $ret = zypper_call('in -l ' . $packages, timeout => $args{timeout});
    }
    return $ret;
}

=head2 install_available_packages

    install_available_packages($packages, %args);

C<packages> defines packages to install for both zypper and trup call,
keyword parameters are identical to C<install_package()>.
C<trup_continue> will be enabled by default.

=cut

sub install_available_packages {
    my ($packlist, %args) = @_;

    if (is_transactional) {
        $packlist .= ' ' . ($args{trup_extra} // '');
    }
    else {
        $packlist .= ' ' . ($args{zypper_extra} // '');
    }

    my $result = zypper_search("-t package --match-exact $packlist");
    my @foundpacks = map { $_->{name} } @$result;

    return 0 unless @foundpacks;
    $args{trup_continue} //= 1;
    delete $args{trup_extra};
    delete $args{zypper_extra};
    return install_package(join(' ', @foundpacks), %args);
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
C<trup_reboot> parameter will run reboot_on_changes after trup_call,
reboot if diff between the current FS and the new snapshot.
C<trup_apply> parameter will apply pending changes from the new snapshot
without rebooting, using C<transactional-update apply>.
C<trup_reboot> and C<trup_apply> are mutually exclusive.

B<Warning>: Only use C<trup_apply> for end user applications and server services.
Do not use it for kernel packages or system libraries that require a reboot,
as doing so may leave the system in an inconsistent state.

=cut

sub uninstall_package {
    my $ret;
    my ($packages, %args) = @_;
    die 'Paramater packages is required' unless defined($packages);
    my $timeout = $args{timeout} // 500;

    if (is_transactional) {
        die "uninstall_package: 'trup_reboot' and 'trup_apply' are mutually exclusive" if $args{trup_reboot} && $args{trup_apply};
        record_info('uninstall_package', $args{skip_trup}) if $args{skip_trup} =~ /\w+/;
        return if $args{skip_trup};
        $packages .= ' ' . $args{trup_extra} // '';
        my $cmd = 'pkg remove ' . $packages;
        $cmd = '-c ' . $cmd if $args{trup_continue} // 0;
        $ret = trup_call($cmd, timeout => $args{timeout});
        reboot_on_changes if $args{trup_reboot};
        trup_apply if $args{trup_apply};
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
