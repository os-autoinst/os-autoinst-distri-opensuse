# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Create new test module encrypted volume activation
#    When the variable ENCRYPTED_CANCEL_EXISTING is set, it will cancel the
#    activate encrypted volume prompt which appears during installation to a
#    storage device with existing encrypted lvm volume. A workaround is
#    implemented for bsc#989770 which causes the activation prompt to be
#    displayed twice.
#
#    When the variable ENCRYPTED_ACTIVATE_EXISTING is set it will enter the
#    password for the existing volume to activate it.
# Maintainer: Oliver Kurz <okurz@suse.de>

use strict;
use warnings;
use base "y2logsstep";
use testapi;

my $after_cancel_tags = [
    qw(
      encrypted_volume_activation_prompt enable-multipath scc-registration
      inst-instmode
      )];

sub run {
    assert_screen 'encrypted_volume_activation_prompt';
    if (get_var('ENCRYPT_CANCEL_EXISTING')) {
        assert_screen_change { send_key 'alt-c'; };
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
