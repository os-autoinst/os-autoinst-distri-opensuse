# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Reboot GNOME with or without authentication and ensure proper boot
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use power_action_utils 'power_action';

sub run {
    my ($self) = @_;
    # 'keepconsole => 1' is workaround for bsc#1044072
    power_action('reboot', keepconsole => 1);

    # In 88388900d2dfe267230972c6905b3cc18fb288cf the wait timeout was
    # bumped, due to tianocore being a bit slower, this brings this module
    # in sync
    my $bootloader_timeout = check_var('ARCH', 'aarch64') ? 400 : 300;
    $self->wait_boot(bootloader_time => $bootloader_timeout);
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    $self->export_logs;
}

sub test_flags {
    return {milestone => 1};
}

1;

