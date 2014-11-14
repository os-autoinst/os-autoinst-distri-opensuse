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
if ( check_var( 'DESKTOP', 'minimalx' ) ) {
    $vars{'NOAUTOLOGIN'} = 1;
    $vars{XDMUSED} = 1;
}

$vars{SUSEMIRROR} ||= "download.opensuse.org/factory";

$needle::cleanuphandler = \&cleanup_needles;

$vars{SCREENSHOTINTERVAL} ||= .5;

save_vars(); # update variables

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT TUMBLEWEED ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE LIVECD NETBOOT NICEVIDEO NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");

sub load_x11regresion_tests() {
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/355_firefox_launch.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/360_firefox_menu.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/361_firefox_contentmenu.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/363_firefox_help.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/364_firefox_newwindow.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/365_firefox_home_page.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/368_firefox_topsite.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_https.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_importssl.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_loadie6.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_page_control.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_password_i.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_print.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_remember_passwd.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_search.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_sidebar.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/403_firefox_urlprotocols.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/404_firefox_url.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/405_firefox_localpage.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/406_firefox_mhtml.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/407_firefox_tab.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/408_firefox_sendlink.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/409_firefox_java.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/410_firefox_autocomplete.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/411_firefox_bookmarks.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/412_firefox_printing.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/413_firefox_printing_images.pm");
    autotest::loadtest("$vars{CASEDIR}/x11regression.d/firefox.d/457_firefox_bookmark.pm");
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/gnomecase.d/1019_Gnomecutfile.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/101_pidgin_IRC.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/102_pidgin_googletalk.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/103_pidgin_aim.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/100_prep_pidgin.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/104_pidgin_msn.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/pidgin.d/199_clean_pidgin.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/304_tomboy_Hotkeys.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/307_tomboy_AlreadyRunning.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/312_tomboy_TestFindFunctionalityInSearchAllNotes.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/313_tomboy_TestUndoRedoFeature.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/301_tomboy_firstrun.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/302_tomboy_StartNoteCannotBeDeleted.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/303_tomboy_Open.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/309_tomboy_Print.pm");
    }
    if (( $vars{DESKTOP} eq "gnome" )) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tomboy.d/300_tomboy_checkinstall.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/100_prep_tracker.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/101_tracker_starts.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/102_tracker_searchall.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/103_tracker_pref_starts.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/104_tracker_open_apps.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/105_tracker_by_command.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/107_tracker_search_in_nautilus.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/199_clean_tracker.pm");
    }
    if ($vars{DESKTOP} =~ /kde|gnome/) {
        autotest::loadtest("$vars{CASEDIR}/x11regression.d/tracker.d/106_tracker_info.pm");
    }
}

sub load_login_tests(){
    if (!$vars{UEFI}) {
        autotest::loadtest("$vars{CASEDIR}/login.d/010_boot.pm");
    }
}

sub load_boot_tests(){
    if ($vars{ISO_MAXSIZE}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/isosize.pm");
    }
    if (installbasetest_is_applicable && $vars{OFW}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/bootloader_ofw.pm");
    }
    if (installbasetest_is_applicable && !$vars{UEFI} && !$vars{OFW} && !$vars{MEDIACHECK} && !$vars{MEMTEST} && !$vars{RESCUESYSTEM}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/bootloader.pm");
    }
    if (installbasetest_is_applicable && $vars{UEFI}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/bootloader_uefi.pm");
    }
    if ($vars{MEDIACHECK}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/mediacheck.pm");
    }
    if ($vars{MEMTEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/memtest.pm");
    }
    if (opensusebasetest_is_applicable && $vars{RESCUESYSTEM}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/rescuesystem.pm");
    }
}

sub load_inst_tests() {
    if (y2logsstep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/welcome.pm");
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/installation_mode.pm");
    }
    if (y2logsstep_is_applicable && !$vars{LIVECD} && $vars{UPGRADE}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/upgrade_select.pm");
    }
    if (y2logsstep_is_applicable && !$vars{LIVECD} && $vars{ADDONURL} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/addon_products.pm");
    }
    if (noupdatestep_is_applicable && $vars{LIVECD}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/livecd_installer_timezone.pm");
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/partitioning.pm");
    }
    if (y2logsstep_is_applicable && $vars{LVM} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/partitioning_lvm.pm");
    }
    if (y2logsstep_is_applicable && $vars{SPLITUSR}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/partitioning_splitusr.pm");
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/partitioning_finish.pm");
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/installer_timezone.pm");
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{NICEVIDEO} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/logpackages.pm");
    }
    if (noupdatestep_is_applicable && !$vars{LIVECD} && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/installer_desktopselection.pm");
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/user_settings.pm");
    }
    if (noupdatestep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/installation_overview.pm");
    }
    if (y2logsstep_is_applicable && $vars{UEFI} && $vars{SECUREBOOT}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/secure_boot.pm");
    }
    if (y2logsstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/start_install.pm");
    }
    if (y2logsstep_is_applicable && $vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/autoyast_reboot.pm");
    }
    if (y2logsstep_is_applicable && !$vars{AUTOYAST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/livecdreboot.pm");
    }
    if (y2logsstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/first_boot.pm");
    }
    autotest::loadtest("$vars{CASEDIR}/tests.d/installation/BNC847880_QT_cirrus.pm");
    autotest::loadtest("$vars{CASEDIR}/tests.d/installation/reboot_after_install.pm");
    if (y2logsstep_is_applicable && $vars{DUALBOOT}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/boot_windows.pm");
    }
    if (installbasetest_is_applicable && $vars{LIVETEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/finish_desktop.pm");
    }
}

sub load_rescuecd_tests() {
    if (rescuecdstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/rescuecd/rescuecd.pm");
    }
}

sub load_zdup_tests() {
    if (installzdupstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/setup_zdup.pm");
    }
    if (installzdupstep_is_applicable && $vars{ZDUP}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/zdup.pm");
    }
    if (installzdupstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/installation/post_zdup.pm");
    }
}

sub load_consoletests() {
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/consoletest_setup.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/textinfo.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/hostname.pm");
    }
    if (consolestep_is_applicable && $vars{DESKTOP} !~ /textmode/) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/xorg_vt.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/zypper_ref.pm");
    }
    if (yaststep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/yast2_lan.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/aplay.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/glibc_i686.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/zypper_up.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/zypper_in.pm");
    }
    if (yaststep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/yast2_i.pm");
    }
    if (bigconsolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/sntp.pm");
    }
    if (yaststep_is_applicable && !$vars{LIVETEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/yast2_bootloader.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/sshd.pm");
    }
    autotest::loadtest("$vars{CASEDIR}/tests.d/console/sshfs.pm");
    if (bigconsolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/curl_ipv6.pm");
    }
    if (bigconsolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/wget_ipv6.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/mtab.pm");
    }
    if (serverstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/http_srv.pm");
    }
    if (serverstep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/mysql_srv.pm");
    }
    if (bigconsolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/syslinux.pm");
    }
    if (consolestep_is_applicable && $vars{MOZILLATEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/mozmill_setup.pm");
    }
    if (consolestep_is_applicable && ( $vars{DESKTOP} eq "xfce" )) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/xfce_gnome_deps.pm");
    }
    if (consolestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/console/consoletest_finish.pm");
    }

}

sub load_x11tests(){
    if (x11step_is_applicable && ( $vars{NOAUTOLOGIN} || $vars{XDMUSED} )) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/x11_login.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xfce_close_hint_popup.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xterm.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO} && !$vars{LIVETEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/sshxterm.pm");
    }
    if (gnomestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gnome_control_center.pm");
    }
    if (gnomestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gnome_terminal.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xfce4_terminal.pm");
    }
    if (gnomestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gedit.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/kate.pm");
    }
    if (x11step_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/firefox.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/firefox_audio.pm");
    }
    if (bigx11step_is_applicable && !$vars{NICEVIDEO}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/firefox_stress.pm");
    }
    if (gnomestep_is_applicable && !$vars{LIVECD}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/thunderbird.pm");
    }
    if (x11step_is_applicable && $vars{MOZILLATEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/mozmill_run.pm");
    }
    if (x11step_is_applicable && !( $vars{FLAVOR} =~ /^Staging2?[\-]DVD$/ || $vars{FLAVOR} eq 'Rescue-CD' )) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/chromium.pm");
    }
    if (bigx11step_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/imagemagick.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/ristretto.pm");
    }
    if (gnomestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/eog.pm");
    }
    if (x11step_is_applicable && $vars{DESKTOP} =~ /kde|gnome/ && $vars{FLAVOR} ne "Server-DVD") {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/ooffice.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO} && $vars{DESKTOP} =~ /kde|gnome/ && !$vars{LIVECD} && $vars{FLAVOR} ne "Server-DVD") {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/oomath.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO} && $vars{DESKTOP} =~ /kde|gnome/ && !$vars{LIVECD} && $vars{FLAVOR} ne "Server-DVD") {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/oocalc.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/khelpcenter.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/systemsettings.pm");
    }
    if (x11step_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/yast2_users.pm");
    }
    if (gnomestep_is_applicable && $vars{GNOME2}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/application_browser.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/dolphin.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/thunar.pm");
    }
    if (gnomestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/nautilus.pm");
    }
    if (bigx11step_is_applicable && !$vars{NICEVIDEO}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/glxgears.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/amarok.pm");
    }
    if (gnomestep_is_applicable && !$vars{LIVECD}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gnome_music.pm");
    }
    if (gnomestep_is_applicable && $vars{FLAVOR} ne "Server-DVD") {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/evolution.pm");
    }
    if (kdestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/kontact.pm");
    }
    if (x11step_is_applicable && !$vars{LIVETEST}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/reboot.pm");
    }
    if (x11step_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/desktop_mainmenu.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xfce4_appfinder.pm");
    }
    if (xfcestep_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xfce_notification.pm");
    }
    if (xfcestep_is_applicable && !( $vars{FLAVOR} eq 'Rescue-CD' )) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/xfce_lightdm_logout_login.pm");
    }
    if (x11step_is_applicable && !$vars{NICEVIDEO} && !$vars{LIVECD}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gimp.pm");
    }
    if (x11step_is_applicable && !$vars{LIVECD}) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/inkscape.pm");
    }
    if (x11step_is_applicable && !( $vars{FLAVOR} =~ m/^Staging2?[\-]DVD$/ ) && !( $vars{FLAVOR} =~ m/^Rescue-CD$/ )) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/gnucash.pm");
    }
    if (x11step_is_applicable) {
        autotest::loadtest("$vars{CASEDIR}/tests.d/x11/shutdown.pm");
    }
}

# load the tests in the right order
if ( $vars{REGRESSION} ) {
    if ( $vars{KEEPHDDS} ) {
        load_login_tests();
    }
    else {
        load_inst_tests();
    }

    if ( $vars{DESKTOP} =~ /gnome/ ) {
        load_x11regresion_tests();
    }

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
