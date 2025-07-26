## Copyright 2024 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Boot to agama adding bootloader kernel parameters and expecting web ui up and running.
# At the moment redirecting to legacy handling for remote architectures booting.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "installbasetest";
use strict;
use warnings;

use testapi;
use autoyast qw(create_file_as_profile_companion expand_agama_profile generate_json_profile);
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

sub prepare_boot_params {
    my @params = ();

    # add mandatory boot params
    push @params, 'console=' . (is_x86_64 ? 'ttyS0' : (is_ppc64le ? 'hvc0' : 'ttyAMA0')), 'console=tty';
    push @params, 'kernel.softlockup_panic=1';
    push @params, "live.password=$testapi::password";

    # override default boot params
    if (get_var('BOOTPARAMS')) {
        push @params, split ' ', trim(get_var('BOOTPARAMS'));
        return @params;
    }

    # add default boot params
    if (my $inst_auto = get_var('INST_AUTO')) {
        create_file_as_profile_companion() if get_var('AGAMA_PROFILE_OPTIONS') =~ /files=true/;
        my $profile_url = ($inst_auto =~ /\.libsonnet/) ?
          generate_json_profile($inst_auto) :
          expand_agama_profile($inst_auto);
        set_var('INST_AUTO', $profile_url);
        push @params, "inst.auto=\"$profile_url\"", "inst.finish=stop";
    }
    push @params, 'inst.register_url=' . get_var('SCC_URL') if get_var('SCC_URL') && get_var('FLAVOR') =~ /^(Online.*|agama-installer)$/;

    push @params, "inst.install_url=" . get_var("INST_INSTALL_URL") if get_var('INST_INSTALL_URL');

    # add extra boot params along with the default ones
    push @params, split ' ', trim(get_var('EXTRABOOTPARAMS', ''));

    # add extra boot params for agama network, e.g. ip=2c-ea-7f-ea-ad-0c:dhcp
    push @params, split ' ', trim(get_var('AGAMA_NETWORK_PARAMS', ''));

    # additional parameters requiring parsing
    if (get_var('INST_DUD')) {
        foreach my $item (split(',', get_var('INST_DUD'))) {
            push @params, 'inst.dud=' . data_url($item);
        }
        push @params, 'rd.neednet=1';
    }


    return @params;
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

    my @params = prepare_boot_params();

    $grub_menu->expect_is_shown();
    $grub_menu->select_check_installation_medium_entry() if check_var('AGAMA_GRUB_SELECTION', 'check_medium');
    $grub_menu->select_rescue_system_entry() if check_var('AGAMA_GRUB_SELECTION', 'rescue_system');
    $grub_menu->edit_current_entry();
    $grub_entry_edition->move_cursor_to_end_of_kernel_line();
    $grub_entry_edition->type(\@params);
    $grub_entry_edition->boot();

    return if check_var('AGAMA_GRUB_SELECTION', 'rescue_system');
    if (get_var('EXTRABOOTPARAMS', '') =~ /systemd.unit=multi-user.target/ || check_var('AGAMA_ALERT_POPUP', 'invalid_profile')) {
        wait_serial('Connect to the Agama installer using these URLs:', 300) || die "Agama installer didn't start";
    } else {
        $agama_up_an_running->expect_is_shown();
    }
}

sub post_fail_hook {
    Yam::Agama::agama_base::upload_agama_logs();
}

1;
