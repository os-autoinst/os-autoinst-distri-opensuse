# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable AppArmor during installation
# Maintainer: Fabian Vogt <fvogt@suse.de>

use base 'y2_installbase';
use testapi;

sub run {
    my ($self) = @_;
    my $textmode = check_var('VIDEOMODE', 'text');

    $self->go_to_security_settings();

    send_key 'alt-s';
    send_key_until_needlematch 'security-module-apparmor', 'down';
    send_key 'ret' if $textmode;

    send_key $cmd{ok};

    # Make sure the overview is fully loaded and not being recalculated
    wait_still_screen(3);
    assert_screen 'installation-settings-overview-loaded';
}

1;
