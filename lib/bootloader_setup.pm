# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

package bootloader_setup;

use base Exporter;
use Exporter;

use strict;

use File::Basename 'basename';
use Time::HiRes 'sleep';

use testapi;
use utils;
use version_utils qw(is_jeos is_caasp is_leap);
use caasp 'pause_until';
use mm_network;

our @EXPORT = qw(
  stop_grub_timeout
  boot_local_disk
  boot_into_snapshot
  pre_bootmenu_setup
  select_bootmenu_option
  uefi_bootmenu_params
  bootmenu_default_params
  type_hyperv_fb_video_resolution
  bootmenu_network_source
  specific_bootmenu_params
  specific_caasp_params
  select_bootmenu_video_mode
  select_bootmenu_language
  tianocore_enter_menu
  tianocore_select_bootloader
  zkvm_add_disk
  zkvm_add_interface
  zkvm_add_pty
  $zkvm_img_path
  set_framebuffer_resolution
  set_extrabootparams_grub_conf
  ensure_shim_import
);

our $zkvm_img_path = "/var/lib/libvirt/images";

# prevent grub2 timeout; 'esc' would be cleaner, but grub2-efi falls to the menu then
# 'up' also works in textmode and UEFI menues.
sub stop_grub_timeout {
    send_key 'up';
}

sub boot_local_disk {
    if (get_var('OFW')) {
        # TODO use bootindex to properly boot from disk when first in boot order is cd-rom
        wait_screen_change { send_key 'ret' };
        assert_screen [qw(inst-slof bootloader grub2 inst-bootmenu)];
        if (match_has_tag 'grub2') {
            diag 'already in grub2, returning from boot_local_disk';
            stop_grub_timeout;
            return;
        }
        if (match_has_tag 'inst-slof') {
            diag 'specifying local disk for boot from slof';
            type_string_very_slow "boot /pci\t/sc\t4";
            save_screenshot;
        }
    }
    if (check_var('ARCH', 'aarch64') and get_var('UEFI')) {
        assert_screen 'boot-firmware';
    }
    send_key 'ret';
}

sub boot_into_snapshot {
    send_key_until_needlematch('boot-menu-snapshot', 'down', 10, 5);
    send_key 'ret';
    # assert needle to avoid send down key early in grub_test_snapshot.
    assert_screen 'snap-default' if get_var('OFW');
    # in upgrade/migration scenario, we want to boot from snapshot 1 before migration.
    if ((get_var('UPGRADE') && !get_var('ONLINE_MIGRATION', 0)) || get_var('ZDUP')) {
        send_key_until_needlematch('snap-before-update', 'down', 40, 5);
        save_screenshot;
    }
    # in an online migration
    send_key_until_needlematch('snap-before-migration', 'down', 40, 5) if (get_var('ONLINE_MIGRATION'));
    save_screenshot;
    send_key 'ret';
    # avoid timeout for booting to HDD
    save_screenshot;
    send_key 'ret';
}

sub pre_bootmenu_setup {
    if (get_var("IPXE")) {
        sleep 60;
        return 3;
    }
    if (get_var("USBBOOT")) {
        assert_screen "boot-menu", 5;
        # support multiple versions of seabios, does not harm to press
        # multiple keys here: seabios<1.9: f12, seabios=>1.9: esc
        send_key((match_has_tag 'boot-menu-esc') ? 'esc' : 'f12');
        assert_screen "boot-menu-usb", 4;
        send_key(2 + get_var("NUMDISKS"));
    }

    if (get_var("BOOT_HDD_IMAGE")) {
        assert_screen "grub2", 15;    # Use the same bootloader needle as in grub-test
        send_key "ret";               # boot from hd
        return 3;
    }
    return 0;
}

sub select_bootmenu_option {
    my ($timeout) = @_;
    assert_screen 'inst-bootmenu', $timeout;
    if (get_var('LIVECD')) {
        # live CDs might have a very short timeout of the initial bootmenu
        # (1-2s with recent kiwi versions) so better stop the timeout
        # immediately before checking more and having an opportunity to type
        # more boot parameters.
        stop_grub_timeout;
    }
    if (get_var('ZDUP') || get_var('ONLINE_MIGRATION')) {
        boot_local_disk;
        return 3;
    }

    if (get_var('UPGRADE')) {
        # OFW has contralily oriented menu behavior
        send_key_until_needlematch 'inst-onupgrade', get_var('OFW') ? 'up' : 'down', 10, 5;
    }
    else {
        if (get_var('PROMO') || get_var('LIVETEST') || get_var('LIVE_INSTALLATION')) {
            send_key_until_needlematch 'boot-live-' . get_var('DESKTOP'), 'down', 10, 5;
        }
        elsif (get_var('OFW')) {
            send_key_until_needlematch 'inst-oninstallation', 'up', 10, 5;
        }
        elsif (!get_var('JEOS')) {
            send_key_until_needlematch 'inst-oninstallation', 'down', 10, 5;
        }
    }
    return 0;
}

sub bootmenu_type_extra_boot_params {
    my $e = get_var("EXTRABOOTPARAMS");
    if ($e) {
        type_string_very_slow "$e ";
        save_screenshot;
    }
}

sub bootmenu_type_console_params {
    # To get crash dumps as text
    type_string_very_slow "console=$serialdev ";

    # See bsc#1011815, last console set as boot parameter is linked to /dev/console
    # and doesn't work if set to serial device.
    type_string_very_slow "console=tty ";
}

sub uefi_bootmenu_params {
    # assume bios+grub+anim already waited in start.sh
    # in grub2 it's tricky to set the screen resolution
    send_key "e";
    for (1 .. 2) { send_key "down"; }
    send_key "end";
    # delete "keep" word
    for (1 .. 4) { send_key "backspace"; }
    # hardcoded the value of gfxpayload to 1024x768
    type_string "1024x768";
    assert_screen "gfxpayload_changed", 10;
    # back to the entry position
    send_key "home";
    for (1 .. 2) { send_key "up"; }
    if (is_jeos) {
        send_key "up";
    }
    sleep 5;
    for (1 .. 4) { send_key "down"; }
    send_key "end";

    if (get_var("NETBOOT")) {
        type_string_slow " install=" . get_netboot_mirror;
        save_screenshot();
    }
    send_key "spc";

    # if(get_var("PROMO")) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if (!is_jeos && check_var('VIDEOMODE', "text")) {
        type_string_slow "textmode=1 ";
    }

    type_string " \\\n";    # changed the line before typing video params
}

# Returns kernel framebuffer configuration we have to
# explicitly set on Hyper-V to get 1024x768 resolution.
sub type_hyperv_fb_video_resolution {
    type_string_slow ' video=hyperv_fb:1024x768 ';
}

sub bootmenu_default_params {
    if (get_var('OFW')) {
        # edit menu, wait until we get to grub edit
        wait_screen_change { send_key "e" };
        # go down to kernel entry
        send_key "down";
        send_key "down";
        send_key "down";
        wait_screen_change { send_key "end" };
        # load kernel manually with append
        if (check_var('VIDEOMODE', 'text')) {
            type_string_very_slow " textmode=1";
        }
        type_string_very_slow " Y2DEBUG=1 ";
        bootmenu_type_extra_boot_params;
    }
    else {
        # On JeOS and CaaSP we don't have YaST installer.
        type_string_slow "Y2DEBUG=1 " unless is_jeos || is_caasp;

        # gfxpayload variable replaced vga option in grub2
        if (!is_jeos && !is_caasp && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'))) {
            type_string_slow "vga=791 ";
            type_string_slow "video=1024x768-16 ";
            assert_screen check_var('UEFI', 1) ? 'inst-video-typed-grub2' : 'inst-video-typed', 4;
        }

        if (!get_var("NICEVIDEO")) {
            if (is_caasp) {
                bootmenu_type_console_params;
            }
            elsif (!is_jeos) {
                type_string_very_slow "plymouth.ignore-serial-consoles ";    # make plymouth go graphical
                type_string_very_slow "linuxrc.log=/dev/$serialdev ";
                bootmenu_type_console_params;

                assert_screen "inst-consolesettingstyped", 30;

                # Enable linuxrc core dumps https://en.opensuse.org/SDB:Linuxrc#p_linuxrccore
                type_string_very_slow "linuxrc.core=/dev/$serialdev ";
            }
            bootmenu_type_extra_boot_params;
        }
    }
    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    # Default namescheme 'by-id' for devices is broken on Hyper-V (bsc#1029303),
    # we have to use something else.
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        type_hyperv_fb_video_resolution;
        type_string_slow 'namescheme=by-label ' unless is_jeos or is_caasp;
    }
}

sub bootmenu_network_source {
    # set HTTP-source to not use factory-snapshot
    if (get_var("NETBOOT")) {
        if (get_var('OFW')) {
            if (get_var("SUSEMIRROR")) {
                type_string_very_slow ' install=http://' . get_var("SUSEMIRROR");
            }
            else {
                type_string_very_slow ' kernel=1 insecure=1';
            }
        }
        else {
            my $m_protocol = get_var('INSTALL_SOURCE', 'http');
            my $m_mirror = get_netboot_mirror;
            my ($m_server, $m_share, $m_directory);

            # Parse SUSEMIRROR into variables
            if ($m_mirror =~ m{^[a-z]+://([a-zA-Z0-9.-]*)(/.*)$}) {
                ($m_server, $m_directory) = ($1, $2);
                if ($m_protocol eq "smb") {
                    ($m_share, $m_directory) = $m_directory =~ /\/(.+?)(\/.*)/;
                }
            }

            # select installation source (http, ftp, nfs, smb)
            send_key "f4";
            assert_screen "inst-instsourcemenu";
            send_key_until_needlematch "inst-instsourcemenu-$m_protocol", 'down';
            send_key "ret";
            assert_screen "inst-instsourcedialog-$m_protocol";

            # Clean server name and path
            if ($m_protocol eq "http") {
                for (1 .. 2) {
                    # just type enough backspaces
                    for (1 .. 32) { send_key "backspace" }
                    send_key "tab";
                }
            }

            # Type variables into fields
            type_string_slow "$m_server\t";
            type_string_slow "$m_share\t" if $m_protocol eq "smb";
            type_string_slow "$m_directory\n";
            save_screenshot;

            # HTTP-proxy
            if (get_var("HTTPPROXY", '') =~ m/([0-9.]+):(\d+)/) {
                my ($proxyhost, $proxyport) = ($1, $2);
                send_key "f4";
                for (1 .. 4) {
                    send_key "down";
                }
                send_key "ret";
                type_string_slow "$proxyhost\t$proxyport\n";
                assert_screen "inst-proxy_is_setup";

                # add boot parameters
                # ZYPP... enables proxy caching
            }

            my $remote = get_var("REMOTE_TARGET");
            if ($remote) {
                my $dns = get_host_resolv_conf()->{nameserver};
                type_string_slow " " . get_var("NETSETUP") if get_var("NETSETUP");
                type_string_slow " nameserver=" . join(",", @$dns);
                type_string_slow " $remote=1 ${remote}password=$password";
            }
        }
    }

    if (check_var("LINUXRC_KEXEC", "1")) {
        type_string_slow " kexec=1";
        record_soft_failure "boo#990374 - pass kexec to installer to use initrd from FTP";
    }
}

sub specific_bootmenu_params {
    my $args = "";

    if (!check_var('ARCH', 's390x')) {
        my $netsetup = "";
        my $autoyast = get_var("AUTOYAST", "");
        if ($autoyast || get_var("AUTOUPGRADE") && get_var("AUTOUPGRADE") ne 'local') {
            # We need to use 'ifcfg=*=dhcp' instead of 'netsetup=dhcp' as a default
            # due to BSC#932692 (SLE-12). 'SetHostname=0' has to be set because autoyast
            # profile has DHCLIENT_SET_HOSTNAME="yes" in /etc/sysconfig/network/dhcp,
            # 'ifcfg=*=dhcp' sets this variable in ifcfg-eth0 as well and we can't
            # have them both as it's not deterministic.
            $netsetup = get_var("NETWORK_INIT_PARAM", "ifcfg=*=dhcp SetHostname=0");
            # If AUTOYAST is url (://) or slp dont't translate it to openqa asset
            $autoyast = data_url($autoyast) if $autoyast !~ /^slp$|:\/\//;
            $args .= " $netsetup autoyast=$autoyast ";
        }
        else {
            $netsetup = " " . get_var("NETWORK_INIT_PARAM") if defined get_var("NETWORK_INIT_PARAM");    #e.g netsetup=dhcp,all
            $args .= $netsetup;
        }
    }
    if (get_var("AUTOUPGRADE")) {
        $args .= " autoupgrade=1";
    }

    if (get_var("IBFT")) {
        $args .= " withiscsi=1";
    }

    if (check_var("INSTALLER_NO_SELF_UPDATE", 1)) {
        diag "Disabling installer self update";
        $args .= " self_update=0";
    }
    elsif (my $self_update_repo = get_var("INSTALLER_SELF_UPDATE")) {
        $args .= " self_update=$self_update_repo";
        diag "Explicitly enabling installer self update with $self_update_repo";
    }

    if (get_var("FIPS")) {
        $args .= " fips=1";
    }

    if (check_var("LINUXRC_KEXEC", "1")) {
        $args .= " kexec=1";
        record_soft_failure "boo#990374 - pass kexec to installer to use initrd from FTP";
    }

    if (get_var("DUD")) {
        my $dud = get_var("DUD");
        if ($dud =~ /http:\/\/|https:\/\/|ftp:\/\//) {
            $args .= " dud=$dud insecure=1";
        }
        else {
            $args .= " dud=" . data_url($dud) . " insecure=1";
        }
    }

    # For leap 42.3 we don't have addon_products screen
    if (addon_products_is_applicable() && is_leap('42.3+')) {
        my $addon_url = get_var("ADDONURL");
        $addon_url =~ s/\+/,/g;
        $args .= " addon=" . $addon_url;
    }

    if (get_var('ISO_IN_EXTERNAL_DRIVE')) {
        $args .= " install=hd:/install.iso";
    }

    if (check_var('ARCH', 's390x')) {
        return $args;
    }
    else {
        type_string_very_slow $args;
        save_screenshot;
    }
}

sub select_bootmenu_video_mode {
    if (check_var("VIDEOMODE", "text")) {
        send_key "f3";
        send_key_until_needlematch("inst-textselected", "up", 5);
        send_key "ret";
        if (match_has_tag("inst-textselected-with_colormenu")) {
            # The video mode menu was enhanced to support various color profiles
            # Pressing 'ret' only 'toggles' text mode on/off, but no longer closes
            # the menu, as the user might also want to pick a color profile
            # close the menu by pressing 'esc'
            send_key "esc";
        }
    }
}

sub select_bootmenu_language {
    # set language last so that above typing will not depend on keyboard layout
    if (get_var("INSTLANG")) {

        # positions in isolinux language selection ; order matters
        # from cpio -i --to-stdout languages < /mnt/boot/*/loader/bootlogo
        my @isolinuxlangmap = qw(
          af_ZA
          ar_EG
          ast_ES
          bn_BD
          bs_BA
          bg_BG
          ca_ES
          cs_CZ
          cy_GB
          da_DK
          de_DE
          et_EE
          en_GB
          en_US
          es_ES
          fa_IR
          fr_FR
          gl_ES
          ka_GE
          gu_IN
          el_GR
          hi_IN
          id_ID
          hr_HR
          it_IT
          he_IL
          ja_JP
          jv_ID
          km_KH
          ko_KR
          ky_KG
          lo_LA
          lt_LT
          mr_IN
          hu_HU
          mk_MK
          nl_NL
          nb_NO
          nn_NO
          pl_PL
          pt_PT
          pt_BR
          pa_IN
          ro_RO
          ru_RU
          zh_CN
          si_LK
          sk_SK
          sl_SI
          sr_RS
          fi_FI
          sv_SE
          tg_TJ
          ta_IN
          th_TH
          vi_VN
          zh_TW
          tr_TR
          uk_UA
          wa_BE
          xh_ZA
          zu_ZA
        );
        my $n;
        my %isolinuxlangmap = map { lc($_) => $n++ } @isolinuxlangmap;
        $n = $isolinuxlangmap{lc(get_var("INSTLANG"))};
        my $en_us = $isolinuxlangmap{en_us};

        if ($n && $n != $en_us) {
            $n -= $en_us;
            send_key "f2";
            assert_screen "inst-languagemenu";
            for (1 .. abs($n)) {
                send_key($n < 0 ? "up" : "down");
            }
            send_key "ret";
        }
    }
}

sub specific_caasp_params {
    return unless is_caasp && get_var('STACK_ROLE');

    # Wait for supportserver (controller node)
    if (!check_var 'STACK_ROLE', 'controller') {
        pause_until 'support_server_ready';
    }

    if (check_var('STACK_ROLE', 'worker')) {
        # Wait until admin node genarates autoyast profile
        pause_until 'VELUM_CONFIGURED' if get_var('AUTOYAST');
        # Wait until first round of nodes are processed
        pause_until 'NODES_ACCEPTED' if get_var('DELAYED_WORKER');
    }
}

sub tianocore_enter_menu {
    # we need to reduce this waiting time as much as possible
    while (!check_screen('tianocore-mainmenu', 0, no_wait => 1)) {
        send_key 'f2';
        sleep 0.1;
    }
}

sub tianocore_select_bootloader {
    tianocore_enter_menu;
    send_key_until_needlematch('tianocore-bootmanager', 'down', 5, 5);
    send_key 'ret';
}

sub zkvm_add_disk {
    my ($svirt) = @_;
    if (my $hdd = get_var('HDD_1')) {
        my $basename = basename($hdd);
        my $hdd_dir  = "/var/lib/openqa/share/factory/hdd";
        chomp(my $hdd_path = `find $hdd_dir -name $basename | head -n1`);
        diag("HDD path found: $hdd_path");
        if (get_var('PATCHED_SYSTEM')) {
            diag('in patched systems just load the patched image');
            my $name        = $svirt->name;
            my $patched_img = "$zkvm_img_path/$name" . "a.img";
            $svirt->add_disk({file => $patched_img, dev_id => 'a'});
        }
        else {
            type_string("# copying image...\n");
            $svirt->add_disk({file => $hdd_path, backingfile => 1, dev_id => 'a'});    # Copy disk to local storage
        }
    }
    else {
        # For some tests we need more than the default 4GB
        my $size_i = get_var('HDDSIZEGB') || '4';
        $svirt->add_disk({size => $size_i . "G", create => 1, dev_id => 'a'});
    }
}

sub zkvm_add_pty {
    my ($svirt) = shift;
    # need that for s390
    $svirt->add_pty({pty_dev => 'console', pty_dev_type => 'pty', target_type => 'sclp', target_port => '0'});
}

sub zkvm_add_interface {
    my ($svirt) = shift;
    # temporary use of hardcoded '+4' to workaround messed up network setup on z/KVM
    my $vtap   = $svirt->instance + 4;
    my $netdev = get_required_var('NETDEV');
    # direct access to the tap device, use of $vtap temporarily
    $svirt->add_interface({type => 'direct', source => {dev => $netdev, mode => 'bridge'}, target => {dev => 'macvtap' . $vtap}});
}

# On Hyper-V and Xen PV we need to add special framebuffer provisions
sub set_framebuffer_resolution {
    my $video;
    if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
        $video = 'video=hyperv_fb:1024x768';
    }
    elsif (check_var('VIRSH_VMM_TYPE', 'linux')) {
        $video = 'xen-fbfront.video=32,1024,768 xen-kbdfront.ptr_size=1024,768';
    }
    else {
        return;
    }
    if ($video) {
        # On JeOS we have GRUB_CMDLINE_LINUX, on CaaSP we have GRUB_CMDLINE_LINUX_DEFAULT.
        my $grub_cmdline_label = is_jeos() ? 'GRUB_CMDLINE_LINUX' : 'GRUB_CMDLINE_LINUX_DEFAULT';
        assert_script_run("sed -ie '/${grub_cmdline_label}=/s/\"\$/ $video \"/' /etc/default/grub");
    }
}

# Add content of EXTRABOOTPARAMS to /etc/default/grub. Don't forget to run grub2-mkconfig
# in test code afterwards.
sub set_extrabootparams_grub_conf {
    if (my $extrabootparams = get_var('EXTRABOOTPARAMS')) {
        # On JeOS we have GRUB_CMDLINE_LINUX, on CaaSP we have GRUB_CMDLINE_LINUX_DEFAULT.
        my $grub_cmdline_label = is_jeos() ? 'GRUB_CMDLINE_LINUX' : 'GRUB_CMDLINE_LINUX_DEFAULT';
        assert_script_run("sed -ie '/${grub_cmdline_label}=/s/\"\$/ $extrabootparams \"/' /etc/default/grub");
    }
}

sub ensure_shim_import {
    my (%args) = @_;
    $args{tags} //= [qw(inst-bootmenu bootloader-shim-import-prompt)];
    assert_screen($args{tags}, 30);
    if (match_has_tag("bootloader-shim-import-prompt")) {
        send_key "down";
        send_key "ret";
    }
}

1;

# vim: sw=4 et
