#!/usr/bin/perl -w
use strict;
use bmwqemu;
use autotest;
use needle;
use File::Find;

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES           => [ 0, 1 ],
    REBOOTAFTERINSTALL => [ 0, 1 ],
    DOCRUN             => [ 0, 1 ],

    #   BTRFS=>[0,1],
    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode)],

    #   ROOTFS=>[qw(ext3 xfs jfs btrfs reiserfs)],
    VIDEOMODE => [ "", "text" ],
);

our @can_randomize = qw/NOIMAGES REBOOTAFTERINSTALL DESKTOP VIDEOMODE/;

sub logcurrentenv(@) {
    foreach my $k (@_) {
        my $e = $vars{$k};
        next unless defined $e;
        diag("usingenv $k=$e");
    }
}

sub setrandomenv() {
    for my $k (@can_randomize) {
        next if defined $vars{$k};
        next if $k eq "DESKTOP" && $vars{LIVECD};
        if ( $vars{DOCRUN} ) {
            next if $k eq "VIDEOMODE";
            next if $k eq "NOIMAGES";
        }
        my @range = @{ $valueranges{$k} };
        my $rand  = int( rand( scalar @range ) );
        $vars{$k} = $range[$rand];
        logcurrentenv($k);
    }
}

sub check_env() {
    for my $k ( keys %valueranges ) {
        next unless exists $vars{$k};
        unless ( grep { $vars{$k} eq $_ } @{ $valueranges{$k} } ) {
            die sprintf( "%s must be one of %s\n", $k, join( ',', @{ $valueranges{$k} } ) );
        }
    }
}

sub unregister_needle_tags($) {
    my $tag = shift;
    my @a   = @{ needle::tags($tag) };
    for my $n (@a) { $n->unregister(); }
}

sub remove_desktop_needles($) {
    my $desktop = shift;
    if ( !check_var( "DESKTOP", $desktop ) ) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

sub cleanup_needles() {
    remove_desktop_needles("lxde");
    remove_desktop_needles("kde");
    remove_desktop_needles("gnome");
    remove_desktop_needles("xfce");
    remove_desktop_needles("minimalx");
    remove_desktop_needles("textmode");

    if ( !$vars{LIVECD} ) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if ( !check_var( "VIDEOMODE", "text" ) ) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }
    if ( $vars{INSTLANG} && $vars{INSTLANG} ne "en_US" ) {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

}

# wait for qemu to start
while ( !getcurrentscreenshot() ) {
    sleep 1;
}

#assert_screen "inst-bootmenu",12; # wait for welcome animation to finish

if ( $vars{LIVETEST} && ( $vars{LIVECD} || $vars{PROMO} ) ) {
    $username = "linux";    # LiveCD account
    $password = "";
}

check_env();
setrandomenv if ( $vars{RANDOMENV} );

unless ( $vars{DESKTOP} ) {
    if ( check_var( "VIDEOMODE", "text" ) ) {
        $vars{DESKTOP} = "textmode";
    }
    else {
        $vars{DESKTOP} = "kde";
    }
}

# SLE specific variables
$vars{NOAUTOLOGIN} = 1;
$vars{HASLICENSE} = 1;

if ( check_var( 'DESKTOP', 'minimalx' ) ) {
    $vars{XDMUSED} = 1;
}

# openSUSE specific variables
$vars{SUSEMIRROR} ||= "download.opensuse.org/factory";
$vars{PACKAGETOINSTALL} = "sysstat";
$vars{DEFAULT_WALLPAPER} = 'SLEdefault';

$needle::cleanuphandler = \&cleanup_needles;

$vars{SCREENSHOTINTERVAL} ||= .5;

save_vars(); # update variables

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT TUMBLEWEED ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE LIVECD NETBOOT NICEVIDEO NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");


sub xfcestep_is_applicable() {
    return $vars{DESKTOP} eq "xfce";
}

sub rescuecdstep_is_applicable() {
    return $vars{RESCUECD};
}

sub consolestep_is_applicable() {
    return !$vars{INSTALLONLY} && !$vars{NICEVIDEO} && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && !$vars{MEMTEST};
}

sub kdestep_is_applicable() {
    return $vars{DESKTOP} eq "kde";
}

sub installzdupstep_is_applicable() {
    return !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && $vars{ZDUP};
}

sub noupdatestep_is_applicable() {
    return !$vars{UPGRADE};
}

sub bigx11step_is_applicable() {
    return $vars{BIGTEST};
}

sub installyaststep_is_applicable() {
    return !$vars{NOINSTALL} && !$vars{LIVETEST} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM} && !$vars{ZDUP};
}

sub gnomestep_is_applicable() {
    return $vars{DESKTOP} eq "gnome";
}

sub loadtest($) {
    my ($test) = @_;
    autotest::loadtest("$vars{CASEDIR}/tests/$test");
}

sub load_x11regresion_tests() {
    loadtest "x11regressions/firefox/firefox_launch.pm";
    loadtest "x11regressions/firefox/firefox_menu.pm";
    loadtest "x11regressions/firefox/firefox_contentmenu.pm";
    loadtest "x11regressions/firefox/firefox_help.pm";
    loadtest "x11regressions/firefox/firefox_newwindow.pm";
    loadtest "x11regressions/firefox/firefox_home_page.pm";
    loadtest "x11regressions/firefox/firefox_topsite.pm";
    loadtest "x11regressions/firefox/firefox_https.pm";
    loadtest "x11regressions/firefox/firefox_importssl.pm";
    loadtest "x11regressions/firefox/firefox_loadie6.pm";
    loadtest "x11regressions/firefox/firefox_page_control.pm";
    loadtest "x11regressions/firefox/firefox_password_i.pm";
    loadtest "x11regressions/firefox/firefox_print.pm";
    loadtest "x11regressions/firefox/firefox_remember_passwd.pm";
    loadtest "x11regressions/firefox/firefox_search.pm";
    loadtest "x11regressions/firefox/firefox_sidebar.pm";
    loadtest "x11regressions/firefox/firefox_urlprotocols.pm";
    loadtest "x11regressions/firefox/firefox_url.pm";
    loadtest "x11regressions/firefox/firefox_localpage.pm";
    loadtest "x11regressions/firefox/firefox_mhtml.pm";
    loadtest "x11regressions/firefox/firefox_tab.pm";
    loadtest "x11regressions/firefox/firefox_sendlink.pm";
    loadtest "x11regressions/firefox/firefox_java.pm";
    loadtest "x11regressions/firefox/firefox_autocomplete.pm";
    loadtest "x11regressions/firefox/firefox_bookmarks.pm";
    loadtest "x11regressions/firefox/firefox_printing.pm";
    loadtest "x11regressions/firefox/firefox_printing_images.pm";
    loadtest "x11regressions/firefox/firefox_bookmark.pm";
    if (( $vars{DESKTOP} eq "gnome" )) {
        loadtest "x11regressions/tomboy/tomboy_Hotkeys.pm";
        loadtest "x11regressions/tomboy/tomboy_AlreadyRunning.pm";
        loadtest "x11regressions/tomboy/tomboy_TestFindFunctionalityInSearchAllNotes.pm";
        loadtest "x11regressions/tomboy/tomboy_TestUndoRedoFeature.pm";
        loadtest "x11regressions/tomboy/tomboy_firstrun.pm";
        loadtest "x11regressions/tomboy/tomboy_StartNoteCannotBeDeleted.pm";
        loadtest "x11regressions/tomboy/tomboy_Open.pm";
        loadtest "x11regressions/tomboy/tomboy_Print.pm";
        loadtest "x11regressions/tomboy/tomboy_checkinstall.pm";
        loadtest "x11regressions/gnomecase/Gnomecutfile.pm";
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        loadtest "x11regressions/pidgin/pidgin_IRC.pm";
        loadtest "x11regressions/pidgin/pidgin_googletalk.pm";
        loadtest "x11regressions/pidgin/pidgin_aim.pm";
        loadtest "x11regressions/pidgin/prep_pidgin.pm";
        loadtest "x11regressions/pidgin/pidgin_msn.pm";
        loadtest "x11regressions/pidgin/clean_pidgin.pm";
        loadtest "x11regressions/tracker/prep_tracker.pm";
        loadtest "x11regressions/tracker/tracker_starts.pm";
        loadtest "x11regressions/tracker/tracker_searchall.pm";
        loadtest "x11regressions/tracker/tracker_pref_starts.pm";
        loadtest "x11regressions/tracker/tracker_open_apps.pm";
        loadtest "x11regressions/tracker/tracker_by_command.pm";
        loadtest "x11regressions/tracker/tracker_search_in_nautilus.pm";
        loadtest "x11regressions/tracker/clean_tracker.pm";
        loadtest "x11regressions/tracker/tracker_info.pm";
    }
}

sub load_login_tests(){
    if (!$vars{UEFI}) {
        loadtest "login/boot.pm";
    }
}

sub load_boot_tests(){
    if ($vars{ISO_MAXSIZE}) {
        loadtest "installation/isosize.pm";
    }
    if ($vars{OFW}) {
        loadtest "installation/bootloader_ofw.pm";
    }
    elsif ($vars{UEFI}) {
        loadtest "installation/bootloader_uefi.pm";
    }
    elsif ($vars{MEDIACHECK}) {
        loadtest "installation/mediacheck.pm";
    }
    elsif ($vars{MEMTEST}) {
        loadtest "installation/memtest.pm";
    }
    elsif ($vars{RESCUESYSTEM}) {
        loadtest "installation/rescuesystem.pm";
    }
    else {
        loadtest "installation/bootloader.pm";
    }
}

sub is_reboot_after_installation_necessary() {
    return 0 if $vars{LIVETEST} || $vars{NICEVIDEO} || $vars{DUALBOOT} || $vars{MEDIACHECK} || $vars{MEMTEST} || $vars{RESCUECD} || $vars{RESCUESYSTEM} || $vars{ZDUP};

    return $vars{REBOOTAFTERINSTALL} && !$vars{UPGRADE};
}

sub load_inst_tests() {
    if (!$vars{AUTOYAST}) {
        loadtest "installation/welcome.pm";
    }
    if (!$vars{LIVECD} && $vars{UPGRADE}) {
        loadtest "installation/upgrade_select.pm";
    }
    if (!$vars{LIVECD} && !$vars{AUTOYAST}) {
        loadtest "installation/scc_registration.pm";
        loadtest "installation/addon_products_sle.pm";
    }
    if (noupdatestep_is_applicable && $vars{LIVECD}) {
        loadtest "installation/livecd_installer_timezone.pm";
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        loadtest "installation/partitioning.pm";
    }
    if ($vars{LVM} && !$vars{AUTOYAST}) {
        loadtest "installation/partitioning_lvm.pm";
    }
    if ($vars{SPLITUSR}) {
        loadtest "installation/partitioning_splitusr.pm";
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        loadtest "installation/partitioning_finish.pm";
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{AUTOYAST}) {
        loadtest "installation/installer_timezone.pm";
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{NICEVIDEO} && !$vars{AUTOYAST}) {
        loadtest "installation/logpackages.pm";
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        loadtest "installation/user_settings.pm";
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        loadtest "installation/installation_overview.pm";
    }
    if ($vars{UEFI} && $vars{SECUREBOOT}) {
        loadtest "installation/secure_boot.pm";
    }
    if (installyaststep_is_applicable) {
        loadtest "installation/start_install.pm";
    }
    if ($vars{AUTOYAST}) {
        loadtest "installation/autoyast_reboot.pm";
    }
    else {
        loadtest "installation/livecdreboot.pm";
    }
    if (installyaststep_is_applicable) {
        loadtest "installation/first_boot.pm";
    }
    if (is_reboot_after_installation_necessary()) {
        loadtest "installation/reboot_after_install.pm";
    }

    if ($vars{DUALBOOT}) {
        loadtest "installation/boot_windows.pm";
    }
    if ($vars{LIVETEST}) {
        loadtest "installation/finish_desktop.pm";
    }
}

sub load_rescuecd_tests() {
    if (rescuecdstep_is_applicable) {
        loadtest "rescuecd/rescuecd.pm";
    }
}

sub load_zdup_tests() {
    if (installzdupstep_is_applicable) {
        loadtest "installation/setup_zdup.pm";
    }
    if (installzdupstep_is_applicable && $vars{ZDUP}) {
        loadtest "installation/zdup.pm";
    }
    if (installzdupstep_is_applicable) {
        loadtest "installation/post_zdup.pm";
    }
}

sub load_consoletests() {
    if (consolestep_is_applicable) {
        loadtest "console/consoletest_setup.pm";
        loadtest "console/textinfo.pm";
        loadtest "console/hostname.pm";
        if ($vars{DESKTOP} !~ /textmode/) {
            loadtest "console/xorg_vt.pm";
        }
        loadtest "console/zypper_ref.pm";
        loadtest "console/yast2_lan.pm";
        loadtest "console/aplay.pm";
        loadtest "console/glibc_i686.pm";
        loadtest "console/zypper_up.pm";
        loadtest "console/zypper_in.pm";
        loadtest "console/yast2_i.pm";
        if (!$vars{LIVETEST}) {
            loadtest "console/yast2_bootloader.pm";
        }
        loadtest "console/sshd.pm";
        if ($vars{BIGTEST}) {
            loadtest "console/sntp.pm";
            loadtest "console/curl_ipv6.pm";
            loadtest "console/wget_ipv6.pm";
            loadtest "console/syslinux.pm";
        }
        loadtest "console/mtab.pm";
        if (!$vars{NOINSTALL} && !$vars{LIVETEST} && ( $vars{DESKTOP} eq "textmode" )) {
            loadtest "console/http_srv.pm";
            loadtest "console/mysql_srv.pm";
        }
        if ($vars{MOZILLATEST}) {
            loadtest "console/mozmill_setup.pm";
        }
        if ($vars{DESKTOP} eq "xfce") {
            loadtest "console/xfce_gnome_deps.pm";
        }
        loadtest "console/consoletest_finish.pm";
    }
}

sub load_x11tests(){
    return unless (!$vars{INSTALLONLY} && $vars{DESKTOP} !~ /textmode|minimalx/ && !$vars{DUALBOOT} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUECD} && !$vars{RESCUESYSTEM});

    if ( $vars{XDMUSED} ) {
        loadtest "x11/x11_login.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/xfce_close_hint_popup.pm";
        loadtest "x11/xfce4_terminal.pm";
    }
    if (!$vars{NICEVIDEO}) {
        loadtest "x11/xterm.pm";
        loadtest "x11/sshxterm.pm" unless $vars{LIVETEST};
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/gnome_control_center.pm";
        loadtest "x11/gnome_terminal.pm";
        loadtest "x11/gedit.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/kate.pm";
    }
    loadtest "x11/firefox.pm";
    if (!$vars{NICEVIDEO}) {
        loadtest "x11/firefox_audio.pm";
    }
    if (bigx11step_is_applicable && !$vars{NICEVIDEO}) {
        loadtest "x11/firefox_stress.pm";
    }
    if ($vars{MOZILLATEST}) {
        loadtest "x11/mozmill_run.pm";
    }
    if (bigx11step_is_applicable) {
        loadtest "x11/imagemagick.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/ristretto.pm";
    }
    if ( $vars{FLAVOR} ne "Server-DVD" ) {
        if (gnomestep_is_applicable) {
            loadtest "x11/eog.pm";
            loadtest "x11/rhythmbox.pm";
        }
        if ( $vars{DESKTOP} =~ /kde|gnome/ ) {
            loadtest "x11/ooffice.pm";
            loadtest "x11/oomath.pm";
            loadtest "x11/oocalc.pm";
        }
    }
    if (kdestep_is_applicable) {
        loadtest "x11/khelpcenter.pm";
        loadtest "x11/systemsettings.pm";
        loadtest "x11/dolphin.pm";
    }
    loadtest "x11/yast2_users.pm";
    if (gnomestep_is_applicable && $vars{GNOME2}) {
        loadtest "x11/application_browser.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/thunar.pm";
    }
    if (bigx11step_is_applicable && !$vars{NICEVIDEO}) {
        loadtest "x11/glxgears.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/amarok.pm";
        loadtest "x11/kontact.pm";
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/nautilus.pm" unless $vars{LIVECD};
        loadtest "x11/evolution.pm" unless ($vars{FLAVOR} eq "Server-DVD");
    }
    if (!$vars{LIVETEST}) {
        loadtest "x11/reboot.pm";
    }
    loadtest "x11/desktop_mainmenu.pm";

    if (xfcestep_is_applicable) {
        loadtest "x11/xfce4_appfinder.pm";
        loadtest "x11/xfce_notification.pm";
        if (!( $vars{FLAVOR} eq 'Rescue-CD' )) {
            loadtest "x11/xfce_lightdm_logout_login.pm";
        }
    }

    loadtest "x11/shutdown.pm";
}

# load the tests in the right order
if ( $vars{REGRESSION} ) {
    if ( $vars{KEEPHDDS} ) {
        load_login_tests();
    }
    else {
        load_inst_tests();
    }

    load_x11regresion_tests();
}
else {
    load_boot_tests();
    load_inst_tests();
    load_rescuecd_tests();
    load_zdup_tests();
    load_consoletests();
    load_x11tests();
}

1;
# vim: set sw=4 et:
