# SUSE's openQA tests
#
# Copyright 2016-2017 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Create new test module encrypted volume activation
#    When the variable ENCRYPTED_CANCEL_EXISTING is set, it will cancel the
#    activate encrypted volume prompt which appears during installation to a
#    storage device with existing encrypted lvm volume. A workaround is
#    implemented for bsc#989770 which causes the activation prompt to be
#    displayed twice.
#
#    When the variable ENCRYPTED_ACTIVATE_EXISTING is set it will enter the
#    password for the existing volume to activate it.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base 'y2_installbase';
use strict;
use warnings;
use testapi;
use version_utils 'is_storage_ng';

my $after_cancel_tags = [
    qw(
      enable-multipath scc-registration
      inst-instmode addon-products
    )];

sub run {
    assert_screen 'encrypted_volume_activation_prompt';
    if (get_var('ENCRYPT_CANCEL_EXISTING')) {
        wait_screen_change { send_key 'alt-c'; };
        assert_screen($after_cancel_tags, 60);
    }
    elsif (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        # pre storage NG has an additional question dialog
        if (match_has_tag 'encrypted_volume_activation_prompt-embedded_password_prompt') {
            type_password;
            send_key $cmd{ok};
        }
        else {
            send_key 'alt-p';
            assert_screen 'encrypted_volume_password_prompt';
            type_password;
            send_key 'ret';
        }
    }
}

1;
