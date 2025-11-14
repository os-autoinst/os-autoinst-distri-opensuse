# secure boot libs
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Summary: secure boot enablment/disablement support
#
# Maintainer: QE Security <none@suse.de>

package security::secureboot;

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use Exporter 'import';
use Utils::Architectures 'is_aarch64';
use bootloader_setup qw(tianocore_disable_secureboot tianocore_enter_menu);
use version_utils qw(is_sle);

our @EXPORT = qw(handle_secureboot);

#
# _set_secure_boot_aarch64(enable => $bool)
#
# Private helper function to handle Secure Boot toggling in Tianocore firmware
# for SLE >= 16 on aarch64. This replaces the original 'tianocore_disable_secureboot'.
#
# Arguments:
#   'enable': A boolean value. If true, it enables Secure Boot. If false, it disables it.
#
sub _set_secure_boot_aarch64 {
    my ($self, %args) = @_;
    my $enable = $args{enable} // 0;    # Default to disabling

    my $needle_sb_current_state = $enable ? 'tianocore-secureboot-not-enabled' : 'tianocore-secureboot-enabled';
    my $needle_sb_target_state = $enable ? 'tianocore-devicemanager-sb-conf-enabled' : 'tianocore-devicemanager-sb-conf-disabled';
    my $needle_sb_conf_attempt = $enable ? 'tianocore-devicemanager-sb-conf-disabled' : 'tianocore-devicemanager-sb-conf-attempt-sb';

    tianocore_enter_menu;

    # Navigate from the main menu to the Secure Boot configuration
    assert_screen 'tianocore-mainmenu';
    send_key_until_needlematch('tianocore-devicemanager', 'down', 10, 5);
    send_key 'ret';
    send_key_until_needlematch('tianocore-devicemanager-sb-conf', 'down', 10, 5);
    send_key 'ret';
    send_key_until_needlematch($needle_sb_conf_attempt, 'down', 6, 5);
    send_key 'spc';
    assert_screen 'tianocore-devicemanager-sb-conf-changed';
    send_key 'ret';
    assert_screen($enable ? 'tianocore-devicemanager-sb-conf-enabled' : 'tianocore-devicemanager-sb-conf-disabled');
    send_key 'f10';
    assert_screen 'tianocore-bootmanager-save-changes';
    send_key 'Y';
    send_key_until_needlematch 'tianocore-devicemanager', 'esc';
    send_key_until_needlematch 'tianocore-mainmenu-reset', 'down';
    send_key 'ret';
}

#
# handle_secureboot($action)
#
# Main public function to enable or disable Secure Boot.
#
# Arguments:
#   $action: A string, either 'enable' or 'disable'. Defaults to 'disable'.
#
sub handle_secureboot {
    my ($self, $action) = @_;
    $action //= 'disable';    # Default action is to disable

    my $enable_flag = ($action eq 'enable');

    if (is_sle('>=16') && is_aarch64) {
        record_info('SecureBoot', "Calling aarch64-specific handler to $action Secure Boot (bsc#1189988)");
        _set_secure_boot_aarch64($self, enable => $enable_flag);
    } else {
        record_info('SecureBoot', "Calling standard handler to $action Secure Boot (bsc#1189988)");
        $self->wait_grub(bootloader_time => 200);
        # The original tianocore_disable_secureboot uses 're_enable' to enable.
        my $legacy_action = $enable_flag ? 're_enable' : undef;
        $self->tianocore_disable_secureboot($legacy_action);
    }
    $self->wait_boot(textmode => 1);
}

1;
