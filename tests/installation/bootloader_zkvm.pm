# SUSE's openQA tests
#
# Copyright 2009-2013 Bernhard M. Wiedemann
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Interface with the zKVM bootloader based on test settings
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

package bootloader_zkvm;

use base "installbasetest";


use bootloader_setup;
use registration;
use testapi;
use utils qw(OPENQA_FTP_URL type_line_svirt save_svirt_pty);
use ntlm_auth;
use version_utils qw(is_agama);
use autoyast qw(expand_agama_profile parse_dud_parameter);

sub set_svirt_domain_elements {
    my ($svirt) = shift;

    if (!get_var('BOOT_HDD_IMAGE') or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        my $repo = "$utils::OPENQA_HTTP_URL/" . get_required_var('REPO_0');
        $repo = get_var('MIRROR_HTTP') if get_var('NTLM_AUTH_INSTALL');
        my $name = $svirt->name;

        my $ntlm_p = get_var('NTLM_AUTH_INSTALL') ? $ntlm_auth::ntlm_proxy : '';
        my $cmdline = get_var('VIRSH_CMDLINE') . $ntlm_p . " ";
        if (is_agama) {
            $cmdline .= " root=live:http://" . get_var('OPENQA_HOSTNAME') .
              ((get_var('FLAVOR') eq "Full") ?
                  "/assets/repo/" . get_required_var('REPO_0') . "/LiveOS/squashfs.img" :
                  "/assets/iso/" . get_required_var('ISO'));
            $cmdline .= " live.password=$testapi::password";
            # add extra boot params for agama network, e.g. ip=2c-ea-7f-ea-ad-0c:dhcp
            $cmdline .= ' ' . get_var('AGAMA_NETWORK_PARAMS') if get_var('AGAMA_NETWORK_PARAMS');

            # additional parameters requiring parsing
            $cmdline .= parse_dud_parameter(get_var('INST_DUD')) if get_var('INST_DUD');
        } else {
            $cmdline .= "install=$repo";
            $cmdline .= remote_install_bootmenu_params;
        }
        if (get_var('UPGRADE')) {
            $cmdline .= "upgrade=1 ";
        }

        if (get_var('AUTOYAST')) {
            $cmdline .= ' ' . join(' ', autoyast_boot_params);
        }

        $cmdline .= ' ' . get_var("EXTRABOOTPARAMS") if get_var("EXTRABOOTPARAMS");
        # inst.auto and inst.install_url are defined in 'specific_bootmenu_params'
        $cmdline .= specific_bootmenu_params;
        if (!(is_agama && check_var('FLAVOR', 'Full'))) {
            $cmdline .= registration_bootloader_cmdline if check_var('SCC_REGISTER', 'installation') && !get_var('NTLM_AUTH_INSTALL');
        }

        $svirt->change_domain_element(os => initrd => "$zkvm_img_path/$name.initrd");
        $svirt->change_domain_element(os => kernel => "$zkvm_img_path/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);

        # show this on screen and make sure that kernel and initrd are actually saved
        enter_cmd "wget $repo/boot/s390x/initrd -O $zkvm_img_path/$name.initrd";
        assert_screen("initrd-saved", timeout => 300);
        enter_cmd "wget $repo/boot/s390x/linux -O $zkvm_img_path/$name.kernel";
        assert_screen("kernel-saved", timeout => 300);
    }
    # after installation we need to redefine the domain, so just shutdown
    # on zdup and online migration we need to redefine in between
    # If boot from existing hdd image, we expect shutdown on reboot, so remove the
    # default value 'destroy' for on_reboot
    if (get_var('ZDUP') or get_var('ONLINE_MIGRATION') or get_var('BOOT_HDD_IMAGE') or get_var('AUTOYAST')) {
        $svirt->change_domain_element(on_reboot => undef);
    }
}

sub run {
    my $svirt = select_console('svirt', await_console => 0);

    record_info('free -h', $svirt->get_cmd_output('free -h'));
    record_info('virsh freecell --all', $svirt->get_cmd_output('virsh freecell --all'));
    record_info('virsh domstats', $svirt->get_cmd_output('virsh domstats'));
    set_svirt_domain_elements $svirt;
    zkvm_add_disk $svirt;
    zkvm_add_pty $svirt;
    zkvm_add_interface $svirt;

    $svirt->define_and_start;
    record_info('SUT hostname', get_var('VIRSH_HOSTNAME'));
    record_info('VM instance', get_var('VIRSH_INSTANCE'));
    record_info('Guest ip', get_var('VIRSH_GUEST'));

    if (is_agama) {
        wait_serial('Connect to the Agama installer using these URLs', 300) || die "Agama installer didn't start";
        return;
    }
    if (!get_var("BOOT_HDD_IMAGE") or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        if (check_var("VIDEOMODE", "text")) {
            wait_serial("run 'yast.ssh'", 300) || die "linuxrc didn't finish";
            select_console("installation");
            script_run("clear");
            # If libyui REST API is used, we set it up in installation/setup_libyui
            enter_cmd("TERM=linux yast.ssh") unless get_var('YUI_REST_API');
        }
        else {
            # On s390x zKVM we have to process startshell in bootloader
            wait_serial(' Starting YaST(2|) ', 300) || die "yast didn't start";
            select_console('installation');
        }
    }
}

sub post_fail_hook {
    reset_consoles;
    select_console 'svirt';

    upload_logs("/tmp/os-autoinst-openQA-SUT-" . get_var("VIRSH_INSTANCE") . "-stderr.log", failok => 1);
    enter_cmd "tail /tmp/os-autoinst-openQA-SUT-" . get_var("VIRSH_INSTANCE") . "-stderr.log";

    # Enter Linuxrc extra mode
    type_line_svirt 'x', expect => 'Linuxrc extras';

    # Start linuxrc shell
    type_line_svirt '3', expect => 'ttysclp0:install';

    # Collect Linuxrc logs
    type_line_svirt "'cat /var/log/linuxrc.log > /dev/$serialdev && echo 'LINUXRC_LOG_SAVED' > /dev/$serialdev'";
    wait_serial "LINUXRC_LOG_SAVED" ? record_info 'Logs collected', 'Linuxrc logs can be found in serial0.txt' : die "could not collect linuxrc logs";

    # Collect Wicked logs
    type_line_svirt "'cat /var/log/wickedd.log > /dev/$serialdev && echo 'WICKED_LOG_SAVED' > /dev/$serialdev'";
    wait_serial "WICKED_LOG_SAVED" ? record_info 'Logs collected', 'Wicked logs can be found in serial0.txt' : die "could not collect linuxrc logs";
}

1;
