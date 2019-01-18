# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Select 'snapshot' boot option from grub menu
# Maintainer: dmaiocchi <dmaiocchi@suse.com>

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
    $self->handle_uefi_boot_disk_workaround if (get_var('MACHINE') =~ /aarch64/ && get_var('UEFI') && get_var('BOOT_HDD_IMAGE'));

    my @tags = ('grub2');
    push @tags, 'encrypted-disk-password-prompt' if get_var('ENCRYPT');
    assert_screen(\@tags, 200);
    if (match_has_tag('encrypted-disk-password-prompt')) {
        workaround_type_encrypted_passphrase;
        assert_screen 'grub2', 15;
    }
    stop_grub_timeout;
    boot_into_snapshot;
}
sub test_flags {
    return {fatal => 1};
}

1;
