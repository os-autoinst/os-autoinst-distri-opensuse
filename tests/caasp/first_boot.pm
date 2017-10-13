# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: First boot and login into CaaSP
# Maintainer: Martin Kravec <mkravec@suse.com>

use base "opensusebasetest";
use strict;
use testapi;
use utils qw(is_caasp power_action);
use bootloader_setup 'set_framebuffer_resolution';
use caasp 'process_reboot';

sub run {
    # On VMX images bootloader_uefi eats grub2 needle
    assert_screen 'grub2' unless is_caasp('VMX');

    # Check ssh keys & ip information are displayed
    assert_screen 'linux-login-casp', 300;

    # Workers installed using autoyast have no password - bsc#1030876
    unless (get_var('AUTOYAST')) {
        # Workaround for bsc#1035968
        if (is_caasp 'VMX') {
            # FreeRDP is not sending 'Ctrl' as part of 'Ctrl-Alt-Fx', 'Alt-Fx' is fine though.
            my $ctrl = check_var('VIRSH_VMM_FAMILY', 'hyperv') ? '' : 'ctrl-';
            my $tty2 = wait_screen_change(sub { send_key "${ctrl}alt-f2"; }, 1);
            unless ($tty2) {
                wait_screen_change(undef, 180);
                wait_still_screen;
                record_soft_failure 'bsc#1035968';
            }
        }
        select_console 'root-console';

        # On Hyper-V we need to add special framebuffer provisions
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv') || check_var('VIRSH_VMM_TYPE', 'linux')) {
            set_framebuffer_resolution;
            assert_script_run 'transactional-update grub.cfg';
            process_reboot 1;
        }

        # Restart network to push hostname to dns
        if (is_caasp('VMX') && get_var('STACK_ROLE')) {
            script_run "systemctl restart network", 60;
            # Workaround for bsc#1062717 when admin node has no fqdn hostname
            record_soft_failure 'bsc#1062717';
            get_var('TEST') =~ /.*-(\w+)$/;
            my $fake_hostname = $1;
            script_run "hostnamectl set-hostname $fake_hostname.openqa.test";
            if (check_var('STACK_ROLE', 'admin')) {
                script_run "rm /etc/pki/ldap.crt /etc/pki/velum.crt";
                script_run "systemctl restart admin-node-setup.service";
                script_run "docker rm -f \$(docker ps -f \"name=k8s_velum-dashboard\" -q)";
                script_run "docker rm -f \$(docker ps -f \"name=k8s_openldap_velum\" -q)";
            }
            # End of workaround
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;

# vim: set sw=4 et:
