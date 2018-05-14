# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: setup grub for IMA LTP tests.
# Maintainer: Petr Vorel <pvorel@suse.cz>
# Implements poo#35637

use 5.018;
use warnings;
use base 'opensusebasetest';
use testapi;
use utils;
use serial_terminal 'select_virtio_console';

sub run {
    my $policy = get_var('LTP_IMA_GRUB') || 'ima_policy=tcb';

    select_virtio_console();

    script_run("cat /proc/cmdline");
    if (script_run("grep '$policy' /etc/default/grub")) {
        assert_script_run("sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT=/s/\"\$/ ${policy}\"/' /etc/default/grub");
        assert_script_run("grep '^GRUB_CMDLINE_LINUX_DEFAULT=.*${policy}\"\$' /etc/default/grub");
        assert_script_run('grub2-mkconfig -o /boot/grub2/grub.cfg');
    }

    type_string("reboot\n");
}

sub test_flags {
    return {fatal => 1};
}

1;

=head1 Configuration

=head2 LTP_IMA_GRUB

What to add to GRUB_CMDLINE_LINUX_DEFAULT variable in grub configuration.
