# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NVIDIA helper functions
# Maintainer: Kernel QE <kernel-qa@suse.de>

package nvidia_utils;

use Exporter;
use testapi;
use strict;
use warnings;
use utils;
use version_utils 'is_transactional';
use transactional;
use base 'opensusebasetest';
use serial_terminal qw(select_serial_terminal);
use power_action_utils qw(power_action);

our @EXPORT = qw(
  install
  validate
);

=head2 install

 install([ variant => 'cuda' ], [ reboot => 0 ]);

Install the NVIDIA driver and the compute utils, making sure to remove
any conflicting variant first. Also, it tries to add the relevant
repositories to grab the packages from, defined by the job through
NVIDIA_REPO and NVIDIA_CUDA_REPO. Make sure to reboot the SUT after
calling this subroutine.

Options:

C<$variant> if set to "cuda", install the CUDA variant of the driver.

C<$reboot> reboot the SUT after a successful installation. Implies
serial_terminal and opensusebasetest.

=cut

sub install
{
    my %args = @_;
    my $variant_std = 'nvidia-open-driver-G06-signed-kmp-default';
    my $variant_cuda = 'nvidia-open-driver-G06-signed-cuda-kmp-default';
    my $variant = $args{variant} eq "cuda" ? $variant_cuda : $variant_std;
    my $reboot = $args{reboot} // 0;

    enter_trup_shell if is_transactional;

    zypper_ar(get_required_var('NVIDIA_REPO'), name => 'nvidia', no_gpg_check => 1, priority => 90);
    zypper_ar(get_required_var('NVIDIA_CUDA_REPO'), name => 'cuda', no_gpg_check => 1, priority => 90);

    # Make sure to remove the other variant first
    my $remove_variant = script_run("rpm -q $variant_std") ? $variant_cuda : $variant_std;
    zypper_call("remove --clean-deps ${remove_variant}", exitcode => [0, 104]);

    # Install driver and compute utils which packages `nvidia-smi`
    zypper_call("install -l $variant");
    my $version = script_output("rpm -qa --queryformat '%{VERSION}\n' $variant | cut -d '_' -f1 | sort -u | tail -n 1");
    record_info("NVIDIA Version", $version);

    my $workaround;
    if ($version < 580) {
        $workaround = "nvidia-persistenced == $version";
        record_soft_failure("bsc#1249098 - workaround for Nvidia driver dependency issue");
    }
    zypper_call("install -l nvidia-compute-utils-G06 == $version $workaround");

    exit_trup_shell if is_transactional;

    if ($reboot eq 1) {
        my $opensuse = opensusebasetest->new();
        power_action('reboot', textmode => 1);
        $opensuse->wait_boot(bootloader_time => 300);
        select_serial_terminal();
    }
}

=head2 validate

 validate();

Do basic testing of the NVIDIA driver: check the GPU name,
make sure the module is loaded and log `nvidia-smi` output.

=cut

sub validate
{
    # Check card name
    if (my $gpu = get_var("NVIDIA_EXPECTED_GPU_REGEX")) {
        validate_script_output("hwinfo --gfxcard", sub { /$gpu/mg });
    }
    # Check loaded modules
    assert_script_run("lsmod | grep nvidia", fail_message => "NVIDIA module not loaded");
    # Check driver works
    my $smi_output = script_output("nvidia-smi");
    record_info("NVIDIA SMI", $smi_output);
}

1;
