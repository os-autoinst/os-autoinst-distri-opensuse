## Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Select Check Installation Medium in Grub then perform boot log inspection to get mediacheck tool result.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;
use testapi;
use Mojo::Util 'trim';

sub run {
    my $grub_menu = $testapi::distri->get_grub_menu_agama();
    my $grub_entry_edition = $testapi::distri->get_grub_entry_edition();
    my $agama_up_an_running = $testapi::distri->get_agama_up_an_running();
    my @params = split ' ', trim(get_var('EXTRABOOTPARAMS', ''));

    $grub_menu->expect_is_shown();
    $grub_menu->check_installation_medium();
    $grub_menu->edit_current_entry();
    $grub_entry_edition->move_cursor_to_end_of_kernel_line();
    $grub_entry_edition->type(\@params);
    $grub_entry_edition->boot();
    $agama_up_an_running->expect_is_shown();

    select_console 'root-console';
    assert_script_run("journalctl -b | grep \"Finished Installation medium integrity check.\"", timeout => 60);
}

1;
