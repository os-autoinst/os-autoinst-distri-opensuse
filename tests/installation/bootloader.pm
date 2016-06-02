# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "installbasetest";
use strict;

use Time::HiRes qw(sleep);

use testapi;
use registration;
use utils;
use mm_network;

# hint: press shift-f10 trice for highest debug level
sub run() {
    my ($self) = @_;

    if (get_var("IPXE")) {
        sleep 60;
        return;
    }
    if (get_var("USBBOOT")) {
        assert_screen "boot-menu", 1;
        # support multiple versions of seabios, does not harm to press
        # multiple keys here: seabios<1.9: f12, seabios=>1.9: esc
        send_key((match_has_tag 'boot-menu-esc') ? 'esc' : 'f12');
        assert_screen "boot-menu-usb", 4;
        send_key(2 + get_var("NUMDISKS"));
    }

    if (get_var('BOOT_HDD_IMAGE')) {
        assert_screen 'grub2', 15;    # Use the same bootloader needle as in grub-test
        send_key 'ret';               # boot from hd
        return;
    }

    assert_screen 'inst-bootmenu', 15;
    if (get_var('ZDUP') || get_var("ONLINE_MIGRATION")) {
        send_key 'ret';               # boot from hard disk
        return;
    }

    if (get_var("UPGRADE")) {
        # random magic numbers
        send_key_until_needlematch('inst-onupgrade', 'down', 10, 5);
    }
    else {
        if (get_var("PROMO") || get_var('LIVETEST')) {
            send_key_until_needlematch("boot-live-" . get_var("DESKTOP"), 'down', 10, 5);
        }
        elsif (!get_var("JEOS")) {
            send_key_until_needlematch('inst-oninstallation', 'down', 10, 5);
        }
    }

    if (check_var('VIDEOMODE', "text")) {
        send_key "f3";
        for (1 .. 2) {
            send_key "up";
        }
        assert_screen "inst-textselected";
        send_key "ret";
    }

    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string "vga=791 ";
    type_string "Y2DEBUG=1 ";
    type_string_slow "video=1024x768-16 ";

    assert_screen "inst-video-typed", 4;
    if (!get_var("NICEVIDEO")) {
        type_string_very_slow "plymouth.ignore-serial-consoles ";    # make plymouth go graphical
        type_string_very_slow "linuxrc.log=$serialdev ";             #to get linuxrc logs in serial
        type_string_very_slow "console=$serialdev ";                 # to get crash dumps as text
        type_string_very_slow "console=tty ";                        # to get crash dumps as text
        assert_screen "inst-consolesettingstyped", 30;
        my $e = get_var("EXTRABOOTPARAMS");
        if ($e) {
            type_string_very_slow "$e ";
            save_screenshot;
        }
    }

    # set HTTP-source to not use factory-snapshot
    if (get_var("NETBOOT")) {
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
        type_string "$m_server\t";
        type_string "$m_share\t" if $m_protocol eq "smb";
        type_string "$m_directory\n";

        # HTTP-proxy
        if (get_var("HTTPPROXY", '') =~ m/([0-9.]+):(\d+)/) {
            my ($proxyhost, $proxyport) = ($1, $2);
            send_key "f4";
            for (1 .. 4) {
                send_key "down";
            }
            send_key "ret";
            type_string "$proxyhost\t$proxyport\n";
            assert_screen "inst-proxy_is_setup";

            # add boot parameters
            # ZYPP... enables proxy caching
        }

        my $remote = get_var("REMOTE_SLAVE");
        if ($remote) {
            my $dns = get_host_resolv_conf()->{nameserver};
            type_string_slow " " . get_var("NETSETUP") if get_var("NETSETUP");
            type_string_slow " nameserver=" . join(",", @$dns);
            type_string_slow " $remote=1 ${remote}password=$password";
        }
        #type_string "ZYPP_ARIA2C=0 "; sleep 9;
        #type_string "ZYPP_MULTICURL=0 "; sleep 2;
    }

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

            # TODO: add needles for some often tested
            sleep 2;
            send_key "ret";
        }
    }

    my $args = "";
    if (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
        my $netsetup = " ifcfg=*=dhcp";    #need this instead of netsetup as default, see bsc#932692
        $netsetup = " " . get_var("NETWORK_INIT_PARAM") if defined get_var("NETWORK_INIT_PARAM");    #e.g netsetup=dhcp,all
        $netsetup = " netsetup=dhcp,all" if defined get_var("USE_NETSETUP");                         #netsetup override for sle11
        $args .= $netsetup;
        $args .= " autoyast=" . data_url(get_var("AUTOYAST")) . " ";
    }

    if (get_var("AUTOUPGRADE")) {
        $args .= " autoupgrade=1";
    }

    if (get_var("IBFT")) {
        $args .= " withiscsi=1";
    }

    type_string_very_slow $args;
    save_screenshot;

    if (get_var("FIPS")) {
        type_string_very_slow " fips=1";
        save_screenshot;
    }

    registration_bootloader_params(utils::VERY_SLOW_TYPING_SPEED);

    # boot
    send_key "ret";
}

1;
# vim: set sw=4 et:
