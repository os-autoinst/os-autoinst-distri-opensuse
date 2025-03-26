## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot to agama adding bootloader kernel parameters and expecting web ui up and running.
# At the moment redirecting to legacy handling for remote architectures booting.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;

use testapi;
use autoyast qw(expand_agama_profile generate_json_profile);
use Utils::Architectures;
use Utils::Backends;

use Mojo::Util 'trim';
use File::Basename;
use Yam::Agama::agama_base 'upload_agama_logs';

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../installation';
}
use bootloader_s390;
use bootloader_zkvm;
use bootloader_pvm;

sub post_fail_hook {
    Yam::Agama::agama_base::upload_agama_logs();
}

sub run {
    my $self = shift;

    # Please, avoid adding code here that would be a dependency for specific booting implementations
    # For now using legacy code to handle remote architectures
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
    elsif (is_pvm_hmc()) {
        $self->bootloader_pvm::boot_pvm();
        return;
    }

    my $grub_menu = $testapi::distri->get_grub_menu_agama();
    my $grub_entry_edition = $testapi::distri->get_grub_entry_edition();
    my $agama_up_an_running = $testapi::distri->get_agama_up_an_running();

    # prepare kernel parameters
    if (my $agama_auto = get_var('AGAMA_AUTO')) {
        my $profile_url = ($agama_auto =~ /\.libsonnet/) ?
          generate_json_profile() :
          expand_agama_profile($agama_auto);
        set_var('AGAMA_AUTO', $profile_url);
        set_var('EXTRABOOTPARAMS', get_var('EXTRABOOTPARAMS', '') . " inst.auto=\"$profile_url\"");
    }
    my @params = split ' ', trim(get_var('EXTRABOOTPARAMS', ''));

    $grub_menu->expect_is_shown();
    $grub_menu->edit_current_entry();
    $grub_entry_edition->move_cursor_to_end_of_kernel_line();
    $grub_entry_edition->type(\@params);
    $grub_entry_edition->boot();
    $agama_up_an_running->expect_is_shown();
}

1;
