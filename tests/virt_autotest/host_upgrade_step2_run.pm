# SUSE's openQA tests
#
# Copyright 2012-2016 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: virt_autotest: the initial version of virtualization automation test in openqa, with kvm support fully, xen support not done yet
# Maintainer: alice <xlai@suse.com>

use base "host_upgrade_base";
#use virt_utils qw(set_serialdev);
use testapi;
use Utils::Architectures;
use strict;
use warnings;
use virt_utils;
use Utils::Backends 'is_remote_backend';
use ipmi_backend_utils;

sub get_script_run {
    my $self = shift;

    my $pre_test_cmd = $self->get_test_name_prefix;
    $pre_test_cmd .= "-run 02";

    return "rm /var/log/qa/old* /var/log/qa/ctcs2/* -r;" . "$pre_test_cmd";
}

sub post_execute_script_configuration {
    my $self = shift;

    #online upgrade actually
    if (is_remote_backend && is_aarch64 && is_installed_equal_upgrade_major_release) {
        set_grub_on_vh('', '', 'kvm');
        set_pxe_efiboot('');
    }
}

sub run {
    my $self = shift;
    $self->run_test(12600, "Host upgrade to .* is done. Need to reboot system|Executing host upgrade to .* offline",
        "no", "yes", "/var/log/qa/", "host-upgrade-prepAndUpgrade");
}

1;
