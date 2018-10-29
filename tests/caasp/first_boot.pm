# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
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

use utils qw(zypper_call systemctl);
use version_utils 'is_caasp';
use bootloader_setup 'set_framebuffer_resolution';
use caasp qw(process_reboot script_retry microos_login);

sub run {
    # On DVD images stall prevents reliable matching of BIOS needle - poo#28648
    if (is_caasp('DVD') && !get_var('AUTOYAST')) {
        assert_screen 'grub2';
        send_key 'ret';
    }

    microos_login;
    if (check_var('DISTRI', 'kubic')) {
        zypper_call("lr");
        if (get_var("MIRROR_HTTP")) {
            record_info('Staging Repos', "Using staging repositories");
            zypper_call("mr -da");
            my $mirror = get_required_var('MIRROR_HTTP');
            zypper_call("--no-gpg-check ar -f '$mirror' mirror_http");
        }
        else {
            record_info('Default Repos', "Using default repositories");
        }
        zypper_call('ref');
    }

    if (is_caasp 'VMX') {
        # Help cloud-init on cluster tests
        if (get_var 'STACK_ROLE') {
            # Wait for cloud-init initialization - bsc#1088654
            script_retry 'ls /run/cloud-init/result.json';
            # Restart network to push hostname to dns
            systemctl 'restart network', timeout => 60;
        }

        # On Hyper-V we need to add special framebuffer provisions
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv') || check_var('VIRSH_VMM_TYPE', 'linux')) {
            set_framebuffer_resolution;
            assert_script_run 'transactional-update grub.cfg';
            process_reboot 1;
        }
    }
}

sub test_flags {
    return {fatal => 1};
}

1;
