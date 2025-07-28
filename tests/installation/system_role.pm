# SUSE's openQA tests
#
# Copyright 2016-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check default system role selection screen (only for SLE) and select system role. Added in SLE 12 SP2
# - Check default system role
# - Change system role according to SYSTEM_ROLE value
# Maintainer: Jozef Pupava <jpupava@suse.com>, Joaquín Rivera <jeriveramoya@suse.com>
# Tags: poo#16650, poo#25850

use base 'y2_installbase';
use testapi;
use Utils::Architectures;
use version_utils qw(is_sle is_sles4sap is_opensuse is_microos is_sle_micro);
use YaST::workarounds;

my %role_hotkey = (
    gnome => 's',
    textmode => 't',
    minimal => 'm',
    kvm => 'k',
    xen => 'x',
);

sub change_system_role {
    my ($system_role) = @_;
    # Since SLE 15 we do not have shortcuts for system roles anymore
    if (is_sle('15+') || is_opensuse || is_microos || is_sle_micro) {
        if (check_var('VIDEOMODE', 'text')) {
            # Expect that no actions are done before and default system role is preselected
            send_key_until_needlematch "system-role-$system_role-focused", 'down';    # select role
            send_key_until_needlematch "system-role-$system_role-selected", 'spc';    # enable role
        }
        else {
            assert_and_click "system-role-$system_role";
            if (is_aarch64) {
                if (!check_screen("system-role-$system_role-selected")) {
                    apply_workaround_poo124652("system-role-$system_role-selected", 100);
                }
            }
            assert_and_click "system-role-$system_role-selected";
        }
    }
    else {
        send_key 'alt-' . $role_hotkey{$system_role};
        assert_screen "system-role-$system_role-selected";
    }
}

sub assert_system_role {
    # Still initializing the system at this point, can take some time
    # Asserting screen with preselected role
    # Proper default role assertion will be addressed in poo#37504
    # Product might or might not have default selected
    assert_screen('before-role-selection', 180);
    if (is_opensuse || (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'))) {
        # on opensuse is system role 1:1 with DESKTOP, on SLE change system role if it's defined
        my $system_role = is_opensuse ? get_var('SYSTEM_ROLE', get_var('DESKTOP')) : get_var('SYSTEM_ROLE');
        change_system_role($system_role) unless check_screen("system-role-$system_role-selected");
    }
    elsif (check_var('SYSTEM_ROLE', 'default') || !get_var('SYSTEM_ROLE')) {
        record_info('Default', 'SYSTEM_ROLE is default or not defined, same result');
    }
    send_key $cmd{next};
}

sub run {
    # Check if the installer has a System Role screen.
    if (is_sle('=12-sp5') && is_sles4sap) {
        # This check is not enough to guarantee that we are in a SLES4SAP
        # installation. What this checks is that we are at a job with the
        # VERSION '12-SP5' and that the string 'SAP' is contained in FLAVOR OR
        # that SLE_PRODUCT is set to sles4sap, At the moment,
        # (qam_)create_hdd_sles will get past this check, so we need an extra
        # check_screen to know if the SUT runs SLE or SLES4SAP.
        if (check_screen('partitioning-edit-proposal-button')) {
            record_info("No System Role Screen", "The System Role screen is not shown in SLES4SAP 12SP5");
            return;
        }
    }
    if (is_sle('<15') && !is_x86_64) {
        record_info("Skip screen", "System Role screen is displayed only for x86_64 in SLE-12-SP5 due to it has more than one role available");
    }
    else {
        assert_system_role;
    }
}

1;
