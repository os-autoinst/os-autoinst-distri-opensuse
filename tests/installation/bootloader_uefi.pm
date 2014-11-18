use base "installbasetest";
use strict;
use bmwqemu;
use Time::HiRes qw(sleep);

# hint: press shift-f10 trice for highest debug level
sub run() {
    if (check_screen "bootloader-shim-import-prompt", 15) {
        send_key "down";
        send_key "ret";
    }
    assert_screen "bootloader-grub2", 15;
    if ( $vars{QEMUVGA} && $vars{QEMUVGA} ne "cirrus" ) {
        sleep 5;
    }
    if ( $vars{ZDUP} ) {
        qemusend "eject -f ide1-cd0";
        qemusend "system_reset";
        sleep 10;
        send_key "ret";    # boot
        return;
    }

    if ( $vars{MEDIACHECK} ) {    # special
        # only run this one
        for ( 1 .. 2 ) {
            send_key "down";
        }
        sleep 3;
        send_key "ret";
        return;
    }
    if ( $vars{LIVETEST} && $vars{PROMO} ) {
        send_key "down";    # upgrade
        if ( check_var( "DESKTOP", "gnome" ) ) {
            send_key "down" unless $vars{OSP_SPECIAL};
            send_key "down";
        }
        elsif ( check_var( "DESKTOP", "kde" ) ) {

            # KDE is first entry for OSP image
            send_key "down" unless $vars{OSP_SPECIAL};
        }
        else {
            die "unsupported desktop $vars{DESKTOP}\n";
        }
    }

    # assume bios+grub+anim already waited in start.sh
    # in grub2 it's tricky to set the screen resolution
    send_key "e";
    for ( 1 .. 4 ) { send_key "down"; }
    send_key "end";
    if ( $vars{NETBOOT} && $vars{SUSEMIRROR} ) {
        assert_screen('no_install_url');
        type_string " install=http://" . $vars{SUSEMIRROR};
        save_screenshot();
    }
    send_key "spc";

    # if($vars{PROMO}) {
    #     for(1..2) {send_key "down";} # select KDE Live
    # }

    if ( check_var( 'VIDEOMODE', "text" ) ) {
        type_string "textmode=1 ";
    }

    #type_string "nohz=off "; # NOHZ caused errors with 2.6.26
    #type_string "nomodeset "; # coolo said, 12.3-MS0 kernel/kms broken with cirrus/vesa #fixed 2012-11-06

    type_string " \\\n"; # changed the line before typing video params
    # https://wiki.archlinux.org/index.php/Kernel_Mode_Setting#Forcing_modes_and_EDID
    type_string "vga=791 ";
    type_string "video=1024x768-16 ";

    # not needed anymore atm as cirrus has 1024 as default now:
    # https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/commit/?id=121a6a17439b000b9699c3fa876636db20fa4107
    #type_string "drm_kms_helper.edid_firmware=edid/1024x768.bin ";
    assert_screen "inst-video-typed-grub2", 13;

    if ( !$vars{NICEVIDEO} ) {
        type_string "plymouth.ignore-serial-consoles ", 7; # make plymouth go graphical
        type_string "console=ttyS0 ";    # to get crash dumps as text
        type_string "console=tty ";      # to get crash dumps as text
        my $e = $vars{EXTRABOOTPARAMS};

        #	if($vars{RAIDLEVEL}) {$e="linuxrc=trace"}
        if ($e) { type_string "$e "; }
    }

    #type_string "kiwidebug=1 ";

    #if($vars{BTRFS}) {sleep 9; type_string "squash=0 loadimage=0 ";sleep 21} # workaround 697671

    if ( $vars{ISO} =~ m/i586/ ) {

        #	type_string "info=";sleep 4; type_string "http://zq1.de/i "; sleep 15; type_string "insecure=1 "; sleep 15;
    }
    my $args = "";
    if ( $vars{AUTOYAST} ) {
        $args .= " ifcfg=*=dhcp autoyast=http://$vars{OPENQA_HOSTNAME}/tests/$vars{TEST_ID}/data/$vars{AUTOYAST} ";
    }
    type_string $args;
    save_screenshot;

    if ($vars{FIPS}) {
        type_string " fips=1", 13;
        save_screenshot;
    }

    if ( 0 && $vars{RAIDLEVEL} ) {

        # workaround bnc#711724
        $vars{ADDONURL} = "http://download.opensuse.org/repositories/home:/snwint/openSUSE_Factory/";    #TODO: drop
        $vars{DUD}      = "dud=http://zq1.de/bl10";
        type_string "$vars{DUD} ";
        sleep 20;
        type_string "insecure=1 ";
        sleep 20;
        save_vars();
    }

    if ( $vars{LIVETEST} && $vars{LIVEOBSWORKAROUND} ) {
        send_key "1";    # runlevel 1
        send_key "f10";  # boot
        sleep(40);
        type_string( "
ls -ld /tmp
chmod 1777 /tmp
init 5
exit
" );

    }

    # boot
    send_key "f10";

}

1;
# vim: set sw=4 et:
