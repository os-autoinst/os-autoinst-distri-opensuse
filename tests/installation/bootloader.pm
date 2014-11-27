use base "installbasetest";
use strict;
use testapi;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    if ( get_var("IPXE") ) {
        sleep 60;
        return;
    }
    if ( get_var("USBBOOT") ) {
        assert_screen "boot-menu", 1;
        send_key "f12";
        assert_screen "boot-menu-usb", 4;
        send_key( 2 + get_var("NUMDISKS") );
    }

    assert_screen "inst-bootmenu", 15;
    if ( get_var("ZDUP") ) {
        backend_send "eject -f ide1-cd0";
        backend_send "system_reset";
        sleep 10;
        send_key "ret";    # boot
        return;
    }

    # assume bios+grub+anim already waited in start.sh
    if ( !get_var("LIVETEST") && !get_var("RESCUECD") ) {

        # installation (instead of HDDboot on non-live)
        # installation (instead of live):
        send_key "down";
        if ( get_var("UPGRADE") ) {
            send_key "down";    # upgrade
        }
    }
    else {
        if ( get_var("PROMO") ) {
            send_key "down";    # upgrade
            if ( check_var( "DESKTOP", "gnome" ) ) {
                send_key "down" unless get_var("OSP_SPECIAL");
                send_key "down";
            }
            elsif ( check_var( "DESKTOP", "kde" ) ) {
                send_key "down" unless get_var("OSP_SPECIAL");
                send_key "down";
                send_key "down";
            }
            else {
                die "unsupported desktop " . get_var("DESKTOP");
            }
        }
    }

    # 1024x768
    if ( get_var("RES1024") ) {    # default is 800x600
        send_key "f3";
        send_key "down";
        assert_screen "inst-resolutiondetected";
        send_key "ret";
    }
    elsif ( check_var( 'VIDEOMODE', "text" ) ) {
        send_key "f3";
        for ( 1 .. 2 ) {
            send_key "up";
        }
        assert_screen "inst-textselected", 5;
        send_key "ret";
    }

    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string "vga=791 ";
    type_string "Y2DEBUG=1 ";
    type_string "video=1024x768-16 ", 13;

    assert_screen "inst-video-typed", 13;
    if ( !get_var("NICEVIDEO") ) {
        type_string "plymouth.ignore-serial-consoles ", 4; # make plymouth go graphical
        type_string "console=ttyS0 ", 4;    # to get crash dumps as text
        type_string "console=tty ",   4;    # to get crash dumps as text
        assert_screen "inst-consolesettingstyped", 30;
        my $e = get_var("EXTRABOOTPARAMS");

        #	if(get_var("RAIDLEVEL")) {$e="linuxrc=trace"}
        if ($e) { type_string "$e ", 4; sleep 10; }
    }

    # type_string "kiwidebug=1 ";

    if ( get_var("RESCUECD") ) {
        send_key "ret";    # boot
        return;
    }

    # set HTTP-source to not use factory-snapshot
    if ( get_var("NETBOOT") ) {
        send_key "f4";
        assert_screen "inst-instsourcemenu", 4;
        send_key "ret";
        assert_screen "inst-instsourcedialog", 4;
        my $mirroraddr = "";
        my $mirrorpath = "/factory";
        if ( get_var("SUSEMIRROR", '') =~ m{^([a-zA-Z0-9.-]*)(/.*)$} ){
            ( $mirroraddr, $mirrorpath ) = ( $1, $2 );
        }

        #download.opensuse.org
        if ($mirroraddr) {
            for ( 1 .. 22 ) { send_key "backspace" }
            type_string $mirroraddr;
        }
        send_key "tab";

        # change dir
        # leave /repo/oss/ (10 chars)
        if ( get_var("FULLURL") ) {
            for ( 1 .. 10 ) { send_key "backspace" }
        }
        else {
            for ( 1 .. 10 ) { send_key "left"; }
        }
        for ( 1 .. 22 ) { send_key "backspace"; }
        type_string $mirrorpath;

        assert_screen "inst-mirror_is_setup", 2;
        send_key "ret";

        # HTTP-proxy
        if ( get_var("HTTPPROXY", '') =~ m/([0-9.]+):(\d+)/ ) {
            my ( $proxyhost, $proxyport ) = ( $1, $2 );
            send_key "f4";
            for ( 1 .. 4 ) {
                send_key "down";
            }
            send_key "ret";
            type_string "$proxyhost\t$proxyport\n";
            assert_screen "inst-proxy_is_setup", 2;

            # add boot parameters
            # ZYPP... enables proxy caching
        }

        #type_string "ZYPP_ARIA2C=0 "; sleep 9;
        #type_string "ZYPP_MULTICURL=0 "; sleep 2;
    }

    # set language last so that above typing will not depend on keyboard layout
    if ( get_var("INSTLANG") ) {

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
        $n = $isolinuxlangmap{ lc( get_var("INSTLANG") ) };
        my $en_us = $isolinuxlangmap{en_us};

        if ( $n && $n != $en_us ) {
            $n -= $en_us;
            send_key "f2";
            assert_screen "inst-languagemenu", 6;
            for ( 1 .. abs($n) ) {
                send_key( $n < 0 ? "up" : "down" );
            }

            # TODO: add needles for some often tested
            sleep 2;
            send_key "ret";
        }
    }

    my $args = "";
    if ( get_var("AUTOYAST") ) {
        $args .= " ifcfg=*=dhcp";
        $args .= " autoyast=" . get_var("AUTOINSTURL"). "/data/" . get_var("AUTOYAST") . " ";
    }
    type_string $args, 13;
    save_screenshot;

    if ( get_var("LIVETEST") && get_var("LIVEOBSWORKAROUND") ) {
        send_key "1";      # runlevel 1
        send_key "ret";    # boot
        sleep(40);
        type_string( "
ls -ld /tmp
chmod 1777 /tmp
init 5
exit
" );

    }

    if (get_var("FIPS")) {
        type_string " fips=1", 13;
        save_screenshot;
    }

    # boot
    send_key "ret";
}

1;

# vim: set sw=4 et:
