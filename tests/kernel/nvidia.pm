# SUSE's openQA tests

# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NVIDIA open source driver test
# Maintainer: Kernel QE <kernel-qa@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use nvidia_utils;
use serial_terminal qw(select_serial_terminal);
use version_utils qw(is_sle is_sle_micro);

sub run
{
    my $self = shift;

    select_serial_terminal();

    nvidia_utils::install(variant => "cuda", reboot => 1);
    nvidia_utils::validate();
    nvidia_utils::validate_cuda() if is_sle;

    if (is_sle('15-SP6+') || is_sle_micro('6.0+')) {
        nvidia_utils::install(reboot => 1);
        nvidia_utils::validate();
    }
}

1;

=head1 Description

Test the NVIDIA open source driver. The test installs the CUDA variant of the
driver, reboots, and checks that the C<nvidia> module is loaded and
C<nvidia-smi> works. On SLE it also installs the CUDA toolkit, then builds
and runs a hello world program and the NVIDIA cuda-samples.

On SLE 15-SP6+ and SLE Micro 6.0+ it then switches to the standard (non-CUDA)
variant of the driver, reboots and checks the driver again.

The SUT needs an NVIDIA GPU. See C<lib/nvidia_utils.pm> for details.

=head1 Configuration

=head2 NVIDIA_CUDA_REPO

Required. Repository with the CUDA variant of the driver.

=head2 NVIDIA_REPO

Repository with the standard variant of the driver. Required on SLE 15-SP6+
and SLE Micro 6.0+.

=head2 NVIDIA_DRIVER_BRANCH

Driver branch to install. Defaults to C<G06>.

=head2 NVIDIA_EXPECTED_GPU_REGEX

Optional regex that must match the C<hwinfo --gfxcard> output.

=head2 NVIDIA_CUDA_VERSION

Version of C<cuda-toolkit> to install on SLE. Defaults to the latest.

=head2 NVIDIA_CUDA_GCC_VERSION

Optional GCC version to install and use as the CUDA host compiler on SLE.

=head2 NVIDIA_CUDA_SAMPLES_BRANCH

Branch of the NVIDIA cuda-samples repository to build on SLE. Defaults to
C<v13.4>.

=cut
