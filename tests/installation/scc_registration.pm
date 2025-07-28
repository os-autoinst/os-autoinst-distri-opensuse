# Copyright 2014-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Do the registration against SCC or skip it
# - If SCC_REGISTER or REGISTER is installation
#   - Handle registration (gpg key, nvidia validation, registration server,
#   repositories, beta, products, addons)
# - Otherwise, skip registration
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use parent "y2_installbase";

use testapi;
use utils qw(assert_screen_with_soft_timeout handle_untrusted_gpg_key is_uefi_boot);
use version_utils qw(is_sle is_sle_micro);
use registration qw(skip_registration assert_registration_screen_present fill_in_registration_data verify_scc investigate_log_empty_license);
use virt_autotest::hyperv_utils 'hyperv_cmd';

sub run {
    return record_info('Skip reg.', 'SCC registration is not required in media based upgrade since SLE15') if (is_sle('15+') && get_var('MEDIA_UPGRADE'));
    if (check_var('SCC_REGISTER', 'installation') || (check_var('REGISTER', 'installation'))) {
        record_info('SCC reg.', 'SCC registration');
        # This code checks if the environment is Hyper-V 2016 with UEFI. If true,
        # it adds a new VM network adapter connected to a virtual switch and logs a known UEFI boot issue.
        if (check_var('HYPERV_VERSION', '2016') && is_uefi_boot) {
            my $virsh_instance = get_var("VIRSH_INSTANCE");
            my $hyperv_switch_name = get_var('HYPERV_VIRTUAL_SWITCH', 'ExternalVirtualSwitch');
            hyperv_cmd("powershell -Command "
                  . "\"if ((Get-VMNetworkAdapter -VMName openQA-SUT-${virsh_instance} | Where-Object { \$_.SwitchName -eq '${hyperv_switch_name}' }) -eq \$null) "
                  . "{ Connect-VMNetworkAdapter -VMName openQA-SUT-${virsh_instance} -SwitchName ${hyperv_switch_name} }\"");
            record_soft_failure('bsc#1217800 - [Baremetal windows server 2016][guest VM UEFI]UEFI Boot Issues with Different Build ISOs on Hyper-V Guests');
            assert_screen 'scc_registration-net';
            send_key_until_needlematch "scc-registration-net-selected", "tab", 10 if check_var('DESKTOP', 'textmode');
            send_key 'alt-i';
            assert_screen 'scc_registration-net-setup';
            send_key 'alt-y';
            send_key 'alt-n';
            assert_screen 'scc_registration-net-dhcp';
            send_key 'alt-n';
        }
        assert_registration_screen_present();
        fill_in_registration_data();
        wait_still_screen();
        if ((is_sle('>=15-SP4') || is_sle_micro('5.4+')) && check_screen('import-untrusted-gpg-key', 5)) {
            handle_untrusted_gpg_key();
        }
    }
    else {
        return if check_var('SLE_PRODUCT', 'leanos');
        record_info('Skip reg.', 'Skip registration');
        assert_screen_with_soft_timeout(
            [qw(scc-registration yast2-windowborder-corner registration-online-repos)],
            timeout => 300,
            soft_timeout => 100,
            bugref => 'bsc#1028774'
        );
        if (match_has_tag('yast2-windowborder-corner')) {
            if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
                die "installer should not self-update, therefore window should not have respawned, file bug and replace this line with a soft-fail";
            }
            elsif (check_var('INSTALLER_SELF_UPDATE', 1)) {
                ensure_fullscreen(tag => 'yast2-windowborder-corner');
            }
            else {
                die "so far this should only be reached on s390x which we test only on SLE which has self-update disabled " .
                  "since SLE 12 SP2 GM so we should not reach here unless this is a new version of SLE which has the self-update enabled by default";
            }
            assert_screen_with_soft_timeout(
                'scc-registration',
                timeout => 300,
                soft_timeout => 100,
                bugref => 'bsc#1028774'
            );
        }

        # Tags: poo#53426
        # we need to confirm 'Yes' for the keep registered scenario,
        # while migrate from sle12sp4 to sle12sp5.
        #
        # In this scenario we migrate via Proxy SCC with system registered,
        # while do not need to de-register on base system then register
        # system again during migration process.
        #
        if (match_has_tag('registration-online-repos')) {
            if (is_sle('=12-SP5') && check_var('KEEP_REGISTERED', '1')) {
                wait_screen_change { send_key('alt-y') };
                assert_screen('module-selection', 300);
                return wait_screen_change { send_key('alt-n') };
            }
        }

        skip_registration();
    }
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    verify_scc();
    investigate_log_empty_license();
}

1;
