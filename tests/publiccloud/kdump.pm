# SUSE's openQA tests
#
# Copyright 2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable kdump on the public cloud instance
# Maintainer: QE-C team <qa-c@suse.de>

use Mojo::Base 'publiccloud::basetest';
use testapi;
use publiccloud::ssh_interactive qw(select_host_console);

sub enable_kdump {
    my ($instance) = @_;

    $instance->ssh_assert_script_run(q(sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT/ s/\\\\\\"$/ crashkernel=256M,high crashkernel=128M,low \\\\\\"/" /etc/default/grub));
    $instance->ssh_assert_script_run('sudo grub2-mkconfig -o /boot/grub2/grub.cfg');

    if ($instance->ssh_script_run('sudo grep -q "^KDUMP_CRASHKERNEL=" /etc/sysconfig/kdump') == 0) {
        $instance->ssh_assert_script_run(q(sudo sed -i "/^KDUMP_CRASHKERNEL/ s/\\\\\\"$/ crashkernel=256M,high crashkernel=128M,low \\\\\\"/" /etc/sysconfig/kdump));
    } else {
        $instance->ssh_assert_script_run(q(echo "KDUMP_CRASHKERNEL=\"crashkernel=256M,high crashkernel=128M,low\"" | sudo tee -a /etc/sysconfig/kdump));
    }

    $instance->ssh_assert_script_run('sudo systemctl enable kdump.service');
    $instance->softreboot();
}

sub run {
    my ($self, $args) = @_;

    select_host_console();    # select console on the host, not the PC instance

    return unless (get_var('PUBLIC_CLOUD_ENABLE_KDUMP'));
    enable_kdump($args->{my_instance});
}

sub test_flags {
    return {fatal => 0};
}

1;
