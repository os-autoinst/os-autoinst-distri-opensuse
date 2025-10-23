# SUSE's openQA tests
#
# Copyright @ SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: NVIDIA open source driver test
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use registration;
use testapi;
use utils;
use nvidia_utils;
use version_utils qw(is_sle is_sle_micro);

sub run
{
    my ($self, $args) = @_;

    nvidia_utils::install(variant => "cuda");
    $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
    nvidia_utils::validate();
    nvidia_utils::validate_cuda() if is_sle;

    if (is_sle('15-SP6+') || is_sle_micro('6.0+')) {
        nvidia_utils::install();
        $args->{my_instance}->softreboot(timeout => get_var('PUBLIC_CLOUD_REBOOT_TIMEOUT', 600));
        nvidia_utils::validate();
    }
}

sub test_flags {
    return {
        publiccloud_multi_module => 1
    };
}

1;
