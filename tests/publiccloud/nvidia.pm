# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Opensource Nvidia test
#          Test the opensourced nvidia drivers (SLE15-SP4+)
# Maintainer: ybonatakis <ybonatakis@suse.com>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils;
use publiccloud::utils;

sub validate_nvidia {
    validate_script_output("hwinfo --gfxcard", sub { /nVidia.*Tesla T4/mg });    # depends on terraform setup
        # nvidia-smi is delivered by nvidia-compute-utils-G06. Not available on PublicCloud
        # Check device files and loaded modules instead.
    validate_script_output("lsmod", sub { m/nvidia/ }, fail_message => "nvidia module not loaded");
    assert_script_run("ls -la /dev/{nvidia-modeset,nvidia-uvm-tools,nvidiactl,nvidia-uvm,nvidia0}", fail_message => "nvidia device files are missing");
}

sub run {
    my ($self, $args) = @_;
    script_run("cat /etc/os-release");
    if (get_var('NVIDIA_REPO')) {
        zypper_call('--gpg-auto-import-keys addrepo -p 90 ' . get_required_var('NVIDIA_REPO') . ' nvidia_repo');
        zypper_call '--gpg-auto-import-keys ref';
    }
    # First check cuda variant as is more important in PublicCloud enviroment
    zypper_call("in nvidia-open-driver-G06-signed-cuda-kmp-default kernel-firmware-nvidia-gspx-G06-cuda", quiet => 1);
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    validate_nvidia;
    # Check gfx nvidia driver
    zypper_call("in nvidia-open-driver-G06-signed-kmp-default kernel-firmware-nvidia-gspx-G06 -nvidia-open-driver-G06-signed-cuda-kmp-default -kernel-firmware-nvidia-gspx-G06-cuda", quiet => 1);
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    validate_nvidia;

    assert_script_run("SUSEConnect --status-text", 300);
}


sub test_flags {
    return {publiccloud_multi_module => 1};
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
