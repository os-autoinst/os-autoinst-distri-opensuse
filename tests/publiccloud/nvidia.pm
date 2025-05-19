# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Opensource Nvidia test
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils;
use publiccloud::utils;

my $driver_std = "nvidia-open-driver-G06-signed-kmp-default";
my $driver_cuda = "nvidia-open-driver-G06-signed-cuda-kmp-default";

sub pre_run_hook {
    zypper_call('addrepo -fG -p 90 ' . get_required_var('NVIDIA_REPO') . ' nvidia');
    zypper_call('addrepo -fG -p 90 ' . get_required_var('NVIDIA_CUDA_REPO') . ' cuda');
}

sub install {
    my ($cuda) = @_;
    my $variant;    # Used to pin the installed driver version

    # Make sure to remove the other variant first
    if (!script_run("rpm -q $driver_cuda")) {
        zypper_call("remove --clean-deps $driver_cuda");
    }
    if (!script_run("rpm -q $driver_std")) {
        zypper_call("remove --clean-deps $driver_std");
    }
    if (!script_run("rpm -q nvidia-compute-utils-G06")) {
        zypper_call("remove --clean-deps nvidia-compute-utils-G06");
    }

    if (defined $cuda) {
        $variant = $driver_cuda;
    } else {
        $variant = $driver_std;
    }

    # Install driver and compute utils which packages `nvidia-smi`
    zypper_call("install -l $variant");
    my $version = script_output("rpm -qa --queryformat '%{VERSION}\n' $variant | cut -d '_' -f1 | sort -u | tail -n 1");
    record_info("NVIDIA Version", $version);
    zypper_call("install -l nvidia-compute-utils-G06 == $version");
}

sub validate {
    # Check card name
    if (my $gpu = get_var("NVIDIA_EXPECTED_GPU_REGEX")) {
        validate_script_output("hwinfo --gfxcard", sub { /$gpu/mg });
    }
    # Check loaded modules
    assert_script_run("lsmod | grep nvidia", fail_message => "NVIDIA module not loaded");
    # Check driver works
    my $smi_output = script_output("nvidia-smi");
    record_info("NVIDIA SMI Output", $smi_output);
}

sub run {
    my ($self, $args) = @_;

    install;
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    validate;

    install "cuda";
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    validate;
}

1;

=head1 Discussion

Test module to run Opensource Nvidia test on publiccloud with Turing or Ampere architecture GPUs.
To do so, Public Cloud instance is provisioned by terraform. Setting instance with required hardware
apply on F<publiccloud/terraform/gce.tf> using the C<guest_accelerator>. If you want to provide a
custom terraform, C<PUBLIC_CLOUD_TERRAFORM_FILE> job variable can be used to define an alternative
file.

At the moment, the test uses https://download.opensuse.org/repositories/X11:/Drivers:/Video:/Redesign/openSUSE_Leap_15.4/ repo to get the open source drivers, however it is expected to be shipping the opengpu kernel modules, so that these no longer need to be installed from a separate repository.

=head1 Configuration

=head2 Hardware requirement and GCE instance configuration

Most of the supported GPU are listed on https://sndirsch.github.io/nvidia/2022/06/07/nvidia-opengpu.html.
One of them which GCE provides is B<Tesla T4>. GPU is provided via the B<europe-west1-*> regions, series C<N1>
and machine type C<n1-standard-1>.

Terraform can request which GPU to use, through C<guest_accelerator> inside the C<google_compute_instance> resource.

=begin txt

accelerator_config {
    type         = "NVIDIA_TESLA_T4"
    core_count   = 1
  }

=end txt

The terraform configuration creates the required block with a dynamic block which reads the variable inputs
assigned to the C<gnu> variable. If the job variable C<PUBLIC_CLOUD_NVIDIA> is true, then the following
parameter will be passed in the terraform plan

=begin bash
  -var 'gpu={"count":1,"type":"nvidia-tesla-t4"}'
=end bash

This gives us agility to pass any I<type> or I<count> as value.

If the C<PUBLIC_CLOUD_NVIDIA> is false, the object will be null and it will return an empty list. That disables
the C<guest_accelerator>.

=cut
