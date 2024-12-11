## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot to agama adding bootloader kernel parameters and expecting web ui up and running.
# At the moment redirecting to legacy handling for s390x booting.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;

use testapi;
use Utils::Architectures;
use Utils::Backends;

use Mojo::Util 'trim';
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../installation';
}
use bootloader_s390;
use bootloader_zkvm;
use bootloader_pvm;

sub run {
    my $self = shift;

    # prepare kernel parameters
    if (my $agama_auto = get_var('AGAMA_AUTO')) {
        my $path = data_url($agama_auto);
        set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '') . " agama.auto=\"$path\"");
    }
    my @params = split ' ', trim(get_var('EXTRABOOTPARAMS', ''));

    # for now using legacy code to handle s390x
    if (is_s390x()) {
        if (is_backend_s390x()) {
            record_info('bootloader_s390x');
            $self->bootloader_s390::run();
        } elsif (is_svirt) {
            record_info('bootloader_zkvm');
            $self->bootloader_zkvm::run();
        }
        return;
    }

    my $grub_menu = $testapi::distri->get_grub_menu_agama();
    my $grub_editor = $testapi::distri->get_grub_editor();
    my $agama_up_an_running = $testapi::distri->get_agama_up_an_running();

    if (is_pvm_hmc()) {
        $self->bootloader_pvm::boot_pvm();
        $grub_menu->cmd();
        $grub_editor->add_boot_parameters();
    }
    else {
        $grub_menu->expect_is_shown();
        $grub_menu->edit_current_entry();
        $grub_editor->move_cursor_to_end_of_kernel_line();
        $grub_editor->type(\@params);
    }

    $grub_editor->boot();
    $agama_up_an_running->expect_is_shown();
}

1;
