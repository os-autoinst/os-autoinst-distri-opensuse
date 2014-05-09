use base "basetest";
use strict;
use bmwqemu;
use Time::HiRes qw(sleep);

sub is_applicable() {
    return !$ENV{UEFI};
}

# hint: press shift-f10 trice for highest debug level
sub run() {
    if ( $ENV{IPXE} ) {
        sleep 60;
        return;
    }
    if ( $ENV{USBBOOT} ) {
        assert_screen  "boot-menu", 1 ;
        send_key "f12";
        assert_screen  "boot-menu-usb", 4 ;
        send_key( 2 + $ENV{NUMDISKS} );
    }

    assert_screen  "inst-bootmenu", 15 ;
    if ( $ENV{ZDUP} || $ENV{WDUP} ) {
        qemusend "eject -f ide1-cd0";
        qemusend "system_reset";
        sleep 10;
        send_key "ret";    # boot
        return;
    }

    if ( $ENV{MEMTEST} ) {    # special
                              # only run this one
        for ( 1 .. 6 ) {
            send_key "down";
        }
        assert_screen  "inst-onmemtest", 3 ;
        send_key "ret";
        sleep 6000;
        exit 0;               # done
    }

    # assume bios+grub+anim already waited in start.sh
    if ( !$ENV{LIVETEST} ) {

        # installation (instead of HDDboot on non-live)
        # installation (instead of live):
        send_key "down";
        if ( $ENV{MEDIACHECK} ) {
            send_key "down";    # rescue
            send_key "down";    # media check
            assert_screen  "inst-onmediacheck", 3 ;
        }

    }
    else {
        if ( $ENV{PROMO} ) {
            if ( checkEnv( "DESKTOP", "gnome" ) ) {
                send_key "down" unless $ENV{OSP_SPECIAL};
                send_key "down";
            }
            elsif ( checkEnv( "DESKTOP", "kde" ) ) {
                send_key "down" unless $ENV{OSP_SPECIAL};
                send_key "down";
                send_key "down";
            }
            else {
                die "unsupported desktop $ENV{DESKTOP}\n";
            }
        }
    }

    # 1024x768
    if ( $ENV{RES1024} ) {    # default is 800x600
        send_key "f3";
        send_key "down";
        assert_screen "inst-resolutiondetected";
        send_key "ret";
    }
    elsif ( checkEnv( 'VIDEOMODE', "text" ) ) {
        send_key "f3";
        for ( 1 .. 2 ) {
            send_key "up";
        }
        assert_screen  "inst-textselected", 5 ;
        send_key "ret";
    }

    #type_string "nohz=off "; # NOHZ caused errors with 2.6.26
    #type_string "nomodeset "; # coolo said, 12.3-MS0 kernel/kms broken with cirrus/vesa #fixed 2012-11-06

    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string "vga=791 ";
    type_string "Y2DEBUG=1 ";
    type_string  "video=1024x768-16 ",                              13 ;
    type_string  "drm_kms_helper.edid_firmware=edid/1024x768.bin ", 7 ;
    assert_screen  "inst-video-typed", 13 ;
    if ( !$ENV{NICEVIDEO} ) {
        type_string  "console=ttyS0 ", 7 ;    # to get crash dumps as text
        type_string  "console=tty ",   7 ;    # to get crash dumps as text
        assert_screen  "inst-consolesettingstyped", 30 ;
        my $e = $ENV{EXTRABOOTPARAMS};

        #	if($ENV{RAIDLEVEL}) {$e="linuxrc=trace"}
        if ($e) { type_string  "$e ", 13 ; sleep 10; }
    }

    #type_string "kiwidebug=1 ";

    # set HTTP-source to not use factory-snapshot
    if ( $ENV{NETBOOT} ) {
        send_key "f4";
        assert_screen  "inst-instsourcemenu", 4 ;
        send_key "ret";
        assert_screen  "inst-instsourcedialog", 4 ;
        my $mirroraddr = "";
        my $mirrorpath = "/factory";
        if ( $ENV{SUSEMIRROR} && $ENV{SUSEMIRROR} =~ m{^([a-zA-Z0-9.-]*)(/.*)$} ) {
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
        if ( $ENV{FULLURL} ) {
            for ( 1 .. 10 ) { send_key "backspace" }
        }
        else {
            for ( 1 .. 10 ) { send_key "left"; }
        }
        for ( 1 .. 22 ) { send_key "backspace"; }
        type_string $mirrorpath;

        assert_screen  "inst-mirror_is_setup", 2 ;
        send_key "ret";

        # HTTP-proxy
        if ( $ENV{HTTPPROXY} && $ENV{HTTPPROXY} =~ m/([0-9.]+):(\d+)/ ) {
            my ( $proxyhost, $proxyport ) = ( $1, $2 );
            send_key "f4";
            for ( 1 .. 4 ) {
                send_key "down";
            }
            send_key "ret";
            type_string "$proxyhost\t$proxyport\n";
            assert_screen  "inst-proxy_is_setup", 2 ;

            # add boot parameters
            # ZYPP... enables proxy caching
        }

        #type_string "ZYPP_ARIA2C=0 "; sleep 9;
        #type_string "ZYPP_MULTICURL=0 "; sleep 2;
    }

    #if($ENV{BTRFS}) {sleep 9; type_string "squash=0 loadimage=0 ";sleep 21} # workaround 697671

    # set language last so that above typing will not depend on keyboard layout
    if ( $ENV{INSTLANG} ) {

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
        $n = $isolinuxlangmap{ lc( $ENV{INSTLANG} ) };
        my $en_us = $isolinuxlangmap{en_us};

        if ( $n && $n != $en_us ) {
            $n -= $en_us;
            send_key "f2";
            assert_screen  "inst-languagemenu", 6 ;
            for ( 1 .. abs($n) ) {
                send_key($n < 0 ? "up" : "down");
            }

            # TODO: add needles for some often tested
            sleep 2;
            send_key "ret";
        }
    }

    if ( $ENV{ISO} =~ m/i586/ ) {

        #	type_string "info=";sleep 4; type_string "http://zq1.de/i "; sleep 15; type_string "insecure=1 "; sleep 15;
    }
    my $args = "";
    if ( $ENV{AUTOYAST} ) {
        $args .= " netsetup=dhcp,all autoyast=$ENV{AUTOYAST} ";
    }
    type_string $args;
    if ( 0 && $ENV{RAIDLEVEL} ) {

        # workaround bnc#711724
        $ENV{ADDONURL} = "http://download.opensuse.org/repositories/home:/snwint/openSUSE_Factory/";    #TODO: drop
        $ENV{DUD}      = "dud=http://zq1.de/bl10";
        type_string "$ENV{DUD} ";
        sleep 20;
        type_string "insecure=1 ";
        sleep 20;
    }

    if ( $ENV{LIVETEST} && $ENV{LIVEOBSWORKAROUND} ) {
        send_key "1";       # runlevel 1
        send_key "ret";    # boot
        sleep(40);
        type_string( "
ls -ld /tmp
chmod 1777 /tmp
init 5
exit
" );

    }

    # boot
    send_key "ret";
}

sub test_flags() {
    return { 'fatal' => 1 };
}

1;
# vim: set sw=4 et:
