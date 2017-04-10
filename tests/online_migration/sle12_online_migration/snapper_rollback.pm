# SLE12 online migration tests
#
# Copyright © 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Conduct a rollback after migration back to previous system
# Maintainer: mitiao <mitiao@gmail.com>

use base "consoletest";
use strict;
use testapi;
use utils;

sub check_rollback_system() {
    # first to check rollback-helper service is enabled and worked properly
    my $output = script_output "systemctl status rollback.service";
    if ($output !~ /enabled.*?code=exited,\sstatus=0\/SUCCESS/s) {
        die "rollback service was failed";
    }

    # second to check if repos were rolled back to original
    script_run("zypper lr -u | tee /dev/$serialdev");
}

sub run() {
    my ($self) = @_;

    # login to before online migration snapshot
    # tty would not appear quite often after booting snapshot
    # it is a known bug bsc#980337
    # in this case select tty1 first then select root console
    if (!check_screen('linux-login', 200)) {
        record_soft_failure 'bsc#980337';
        send_key "ctrl-alt-f1";
        assert_screen 'tty1-selected';
    }

    select_console 'root-console';
    script_run "snapper rollback";

    # reboot into the system before online migration
    script_run("systemctl reboot", 0);
    reset_consoles;
    $self->wait_boot(textmode => !is_desktop_installed);
    select_console 'root-console';

    check_rollback_system;
}

1;
# vim: set sw=4 et:
