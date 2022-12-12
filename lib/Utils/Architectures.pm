# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

=head1 Utils::Architectures

C<Utils::Architectures> - Library for archtectures related functionality

=cut

package Utils::Architectures;
use strict;
use warnings;

use base 'Exporter';
use Exporter;
use testapi qw(check_var get_var script_output);

use constant {
    ARCH => [
        qw(
          is_s390x
          is_i586
          is_i686
          is_x86_64
          is_x86_64_v2
          is_aarch64
          is_arm
          is_ppc64le
          is_ppc64
          is_orthos_machine
          is_supported_suse_domain
          is_zvm
        )
    ]
};

our @EXPORT = @{(+ARCH)};

our %EXPORT_TAGS = (
    ARCH => (ARCH),
);

# specific architectures

=head2 is_s390x

 is_s390x();

Returns C<check_var('ARCH', 's390x')>.

=cut

sub is_s390x {
    return check_var('ARCH', 's390x');
}

=head2 is_i586

 is_i586();

Returns C<check_var('ARCH', 'is_i586')>.

=cut

sub is_i586 {
    return check_var('ARCH', 'i586');
}

=head2 is_i686

 is_i686();

Returns C<check_var('ARCH', 'is_i686')>.

=cut

sub is_i686 {
    return check_var('ARCH', 'i686');
}

=head2 is_x86_64

 is_x86_64();

Returns C<check_var('ARCH', 'x86_64')>.

=cut

sub is_x86_64 {
    return check_var('ARCH', 'x86_64');
}

=head2 is_x86_64_v2

 is_x86_64_v2();

Returns C<check_var('ARCH', 'is_x86_64_v2')>.

=cut

sub is_x86_64_v2 {
    return 0 unless is_x86_64;
    my $cpu_flags = script_output('lscpu | grep -i flags');
    foreach my $flag (qw(cx16 lahf popcnt sse4_1 sse4_2 ssse3)) {
        return 0 if ($cpu_flags !~ /$flag/);
    }
    return 1;
}

=head2 is_aarch64

 is_aarch64();

Returns C<check_var('ARCH', 'aarch64')>.

=cut

sub is_aarch64 {
    return check_var('ARCH', 'aarch64');
}

=head2 is_arm

 is_arm();

Returns C<get_var('ARCH') =~ /arm/>.

=cut

sub is_arm {
    return (get_var('ARCH') =~ /arm/);    # Can match arm, armv7, armv7l, armv7hl, ...
}

=head2 is_ppc64le

 is_ppc64le();

Returns C<check_var('ARCH', 'ppc64le')>.

=cut

sub is_ppc64le {
    return check_var('ARCH', 'ppc64le');
}

=head2 is_ppc64

 is_ppc64();

 Returns C<check_var('ARCH', 'ppc64')>.

=cut

sub is_ppc64 {
    return check_var('ARCH', 'ppc64');
}

=head2 is_orthos_machine

 is_orthos_machine();

Returns C<true if machine FQDN has arch.suse.de suffix>.

=cut

sub is_orthos_machine {
    my $sut_fqdn = get_var('SUT_IP', 'nosutip');
    return 1 if $sut_fqdn =~ /(arch\.suse\.de)/im;
    return 0;
}

=head2 is_supported_suse_domain

 is_supported_suse_domain();

Returns C<true if machine FQDN has qa.suse.de, qa2.suse.asia or arch.suse.de suffix>.

=cut

sub is_supported_suse_domain {
    my $sut_fqdn = get_var('SUT_IP', 'nosutip');
    return 1 if $sut_fqdn =~ /(arch\.suse\.de|qa2\.suse\.asia|qa\.suse\.de)/im;
    return 0;
}

=head2 is_zvm

 is_zvm();

Returns C<true if machine is s390x zVM>.

=cut

sub is_zvm {
    return (get_var('MACHINE') =~ /zvm/i);
}

1;
