# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Interface with the zKVM bootloader based on test settings
# Maintainer: Matthias Grießmeier <mgriessmeier@suse.de>

package bootloader_zkvm;

use base "installbasetest";

use strict;
use warnings;

use bootloader_setup;
use registration;
use testapi;
use utils qw(OPENQA_FTP_URL type_line_svirt);

sub set_svirt_domain_elements {
    my ($svirt) = shift;

    if (!get_var('BOOT_HDD_IMAGE') or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        my $repo    = "$utils::OPENQA_FTP_URL/" . get_required_var('REPO_0');
        my $cmdline = get_var('VIRSH_CMDLINE') . " install=$repo ";
        my $name    = $svirt->name;

        $cmdline .= remote_install_bootmenu_params;

        if (get_var('UPGRADE')) {
            $cmdline .= "upgrade=1 ";
        }

        if (my $autoyast = get_var('AUTOYAST')) {
            $autoyast = data_url($autoyast) if $autoyast !~ /^slp$|:\/\//;
            $cmdline .= " autoyast=" . $autoyast;
        }

        $cmdline .= ' ' . get_var("EXTRABOOTPARAMS") if get_var("EXTRABOOTPARAMS");
        $cmdline .= specific_bootmenu_params;
        $cmdline .= registration_bootloader_cmdline if check_var('SCC_REGISTER', 'installation');

        $svirt->change_domain_element(os => initrd  => "$zkvm_img_path/$name.initrd");
        $svirt->change_domain_element(os => kernel  => "$zkvm_img_path/$name.kernel");
        $svirt->change_domain_element(os => cmdline => $cmdline);

        # show this on screen and make sure that kernel and initrd are actually saved
        type_string "wget $repo/boot/s390x/initrd -O $zkvm_img_path/$name.initrd\n";
        assert_screen "initrd-saved";
        type_string "wget $repo/boot/s390x/linux -O $zkvm_img_path/$name.kernel\n";
        assert_screen "kernel-saved";
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

    set_svirt_domain_elements $svirt;
    zkvm_add_disk $svirt;
    zkvm_add_pty $svirt;
    zkvm_add_interface $svirt;

    $svirt->define_and_start;

    if (!get_var("BOOT_HDD_IMAGE") or (get_var('PATCHED_SYSTEM') and !get_var('ZDUP'))) {
        if (check_var("VIDEOMODE", "text")) {
            wait_serial("run 'yast.ssh'", 300) || die "linuxrc didn't finish";
            select_console("installation");
            type_string("TERM=linux yast.ssh\n") && record_soft_failure('bsc#1054448');
        }
        else {
            wait_serial(' Starting YaST2 ', 300) || die "yast didn't start";
            select_console('installation');
        }
    }
}
sub post_fail_hook {
    reset_consoles;
    select_console 'svirt';

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
