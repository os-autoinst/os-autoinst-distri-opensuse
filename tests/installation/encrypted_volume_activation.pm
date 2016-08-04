# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "basetest";
use strict;
use testapi;

my $after_cancel_tags = [
    qw/
      encrypted_volume_activation_prompt enable-multipath scc-registration
      /
];

sub run {
    assert_screen 'encrypted_volume_activation_prompt';
    if (get_var('ENCRYPT_CANCEL_EXISTING')) {
        send_key 'alt-c';
        assert_screen($after_cancel_tags);
        if (match_has_tag('encrypted_volume_activation_prompt')) {
            record_soft_failure 'bsc#989770';
            send_key 'alt-c';
        }
    }
    elsif (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        send_key 'alt-p';
        assert_screen 'encrypted_volume_password_prompt';
        type_password;
        send_key 'ret';
    }
}

1;
