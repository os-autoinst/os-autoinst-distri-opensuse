# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: okurz <okurz@suse.de>

use strict;
use warnings;
use base 'opensusebasetest';
use testapi;
use power_action_utils 'power_action';
use utils 'workaround_type_encrypted_passphrase';
use bootloader_setup qw(stop_grub_timeout boot_into_snapshot);

sub run {
    my $self = shift;

    select_console 'root-console';
    power_action('reboot', keepconsole => 1, textmode => 1);
    reset_consoles;
    $self->wait_grub(bootloader_time => 200);
    # To keep the screen at grub page
    # Refer https://progress.opensuse.org/issues/49040
    stop_grub_timeout;
    boot_into_snapshot;
}
sub test_flags {
    return {fatal => 1};
}

1;
