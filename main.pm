#!/usr/bin/perl -w
use strict;
use testapi;
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
        my $e = get_var("$k");
        next unless defined $e;
        bmwqemu::diag("usingenv $k=$e");
    }
}

sub setrandomenv() {
    for my $k (@can_randomize) {
        next if defined get_var("$k");
        next if $k eq "DESKTOP" && get_var("LIVECD");
        if ( get_var("DOCRUN") ) {
            next if $k eq "VIDEOMODE";
            next if $k eq "NOIMAGES";
        }
        my @range = @{ $valueranges{$k} };
        my $rand  = int( rand( scalar @range ) );
        set_var($k, $range[$rand]);
        logcurrentenv($k);
    }
}

sub check_env() {
    for my $k ( keys %valueranges ) {
        next unless get_var($k);
        unless ( grep { get_var($k) eq $_ } @{ $valueranges{$k} } ) {
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

    if ( !get_var("LIVECD") ) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if ( !check_var( "VIDEOMODE", "text" ) ) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }
    if ( get_var("INSTLANG") && get_var("INSTLANG") ne "en_US" ) {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

}

sub is_staging () {
    return get_var('STAGING');
}

#assert_screen "inst-bootmenu",12; # wait for welcome animation to finish

# defaults for username and password
if (get_var("LIVETEST")) {
    $testapi::username = "root";
    $testapi::password = '';
}
else {
    $testapi::username = "bernhard";
    $testapi::password = "nots3cr3t";
}

$testapi::username = get_var("USERNAME") if get_var("USERNAME");
$testapi::password = get_var("PASSWORD") if defined get_var("PASSWORD");

if ( get_var("LIVETEST") && ( get_var("LIVECD") || get_var("PROMO") ) ) {
    $testapi::username = "linux";    # LiveCD account
    $testapi::password = "";
}

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

check_env();
setrandomenv if ( get_var("RANDOMENV") );

unless ( get_var("DESKTOP") ) {
    if ( check_var( "VIDEOMODE", "text" ) ) {
        set_var("DESKTOP", "textmode");
    }
    else {
        set_var("DESKTOP", "kde");
    }
}
if ( check_var( 'DESKTOP', 'minimalx' ) ) {
    set_var("NOAUTOLOGIN", 1);
    set_var("XDMUSED", 1);
}

# openSUSE specific variables
set_var("PACKAGETOINSTALL", "xdelta");
set_var("WALLPAPER", '/usr/share/wallpapers/openSUSEdefault/contents/images/1280x1024.jpg');
if ( !defined get_var( "YAST_SW_NO_SUMMARY" ) ) {
    set_var("YAST_SW_NO_SUMMARY", 1) if get_var('UPGRADE') || get_var("ZDUP");
}

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# for GNOME pressing enter is enough to login bernhard
if ( check_var( 'DESKTOP', 'minimalx' ) ) {
    set_var('DM_NEEDS_USERNAME', 1);
}

# now Plasma 5 is default KDE desktop
if ( check_var( 'DESKTOP', 'kde' ) ) {
    set_var("PLASMA5", 1);
}

# ZDUP_IN_X imply ZDUP
if ( get_var('ZDUP_IN_X')) {
    set_var('ZDUP', 1);
}

$needle::cleanuphandler = \&cleanup_needles;

bmwqemu::save_vars(); # update variables

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE LIVECD NETBOOT NICEVIDEO NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");


sub xfcestep_is_applicable() {
    return check_var("DESKTOP", "xfce");
}

sub rescuecdstep_is_applicable() {
    return get_var("RESCUECD");
}

sub consolestep_is_applicable() {
    return !get_var("INSTALLONLY") && !get_var("NICEVIDEO") && !get_var("DUALBOOT") && !get_var("RESCUECD");
}

sub kdestep_is_applicable() {
    return check_var("DESKTOP", "kde");
}

sub installzdupstep_is_applicable() {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && get_var("ZDUP");
}

sub noupdatestep_is_applicable() {
    return !get_var("UPGRADE");
}

sub bigx11step_is_applicable() {
    return get_var("BIGTEST");
}

sub installyaststep_is_applicable() {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && !get_var("ZDUP");
}

sub gnomestep_is_applicable() {
    return check_var("DESKTOP", "gnome");
}

sub lxdestep_is_applicable() {
    return check_var("DESKTOP", "lxde");
}

sub snapper_is_applicable() {
    my $fs = get_var("FILESYSTEM", 'btrfs');
    return ( $fs eq "btrfs" && get_var("HDDSIZEGB", 10) > 10);
}

sub need_clear_repos() {
    return get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub have_addn_repos() {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub system_is_livesystem() {
  return (check_var("FLAVOR", 'Rescue-CD') || get_var("LIVETEST"))
}

sub is_server() {
  return (get_var("OFW") || check_var("FLAVOR","Server-DVD"));
}

sub loadtest($) {
    my ($test) = @_;
    autotest::loadtest("tests/$test");
}

sub load_x11regresion_tests() {
    if (( check_var("DESKTOP", "gnome") )) {
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
    if (get_var("DESKTOP") =~ /kde|gnome/) {
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
    if (!get_var("UEFI")) {
        loadtest "login/boot.pm";
    }
}

sub load_boot_tests(){
    if (get_var("ISO_MAXSIZE")) {
        loadtest "installation/isosize.pm";
    }
    if (get_var("OFW")) {
        loadtest "installation/bootloader_ofw.pm";
    }
    elsif (get_var("UEFI")) {
        loadtest "installation/bootloader_uefi.pm";
    }
    elsif ( get_var("IPMI_HOSTNAME") ) { # abuse of variable for now
        loadtest "installation/qa_net.pm";
    }
    else {
        loadtest "installation/bootloader.pm";
    }
}

sub is_reboot_after_installation_necessary() {
    return 0 if get_var("NICEVIDEO") || get_var("DUALBOOT") || get_var("RESCUECD") || get_var("ZDUP");

    return get_var("REBOOTAFTERINSTALL") && !get_var("UPGRADE");
}

sub load_inst_tests() {
    loadtest "installation/welcome.pm";
    if (get_var("MULTIPATH")) {
        loadtest "installation/multipath.pm";
    }
    loadtest "installation/good_buttons.pm";
    if (noupdatestep_is_applicable && !get_var("LIVECD")) {
        loadtest "installation/installation_mode.pm";
    }
    if (!get_var("LIVECD") && get_var("UPGRADE")) {
        loadtest "installation/upgrade_select.pm";
    }
    if (!get_var("LIVECD") && get_var("ADDONURL")) {
        loadtest "installation/addon_products.pm";
    }
    if (noupdatestep_is_applicable && get_var("LIVECD")) {
        loadtest "installation/livecd_installer_timezone.pm";
    }
    if (noupdatestep_is_applicable) {
        loadtest "installation/partitioning.pm";
        if ( defined( get_var("RAIDLEVEL") ) ) {
            loadtest "installation/partitioning_raid.pm";
        }
        elsif ( get_var("LVM") ) {
            loadtest "installation/partitioning_lvm.pm";
        }
        if ( get_var("FILESYSTEM") ) {
            loadtest "installation/partitioning_filesystem.pm";
        }
        if ( get_var("TOGGLEHOME") ) {
            loadtest "installation/partitioning_togglehome.pm";
        }
        if ( get_var("SPLITUSR") ) {
            loadtest "installation/partitioning_splitusr.pm";
        }
        loadtest "installation/partitioning_finish.pm";
    }
    if (noupdatestep_is_applicable && !get_var("LIVECD")) {
        loadtest "installation/installer_timezone.pm";
    }
    if (noupdatestep_is_applicable && !get_var("LIVECD") && !get_var("NICEVIDEO")) {
        loadtest "installation/logpackages.pm";
    }
    if (noupdatestep_is_applicable && !get_var("LIVECD")) {
        loadtest "installation/installer_desktopselection.pm";
    }
    if (noupdatestep_is_applicable) {
        loadtest "installation/user_settings.pm";
        if ( get_var("DOCRUN") ) {    # root user
            loadtest "installation/user_settings_root.pm";
        }
    }
    if (noupdatestep_is_applicable) {
        if (get_var('PATTERNS')) {
            loadtest "installation/installation_overview_before.pm";
            loadtest "installation/select_patterns.pm";
        }
    }
    if (get_var("UEFI") && get_var("SECUREBOOT")) {
        loadtest "installation/secure_boot.pm";
    }
    if (installyaststep_is_applicable) {
        loadtest "installation/installation_overview.pm";
        loadtest "installation/start_install.pm";
    }
    loadtest "installation/livecdreboot.pm";
}

sub load_reboot_tests() {
    if (get_var("ENCRYPT")) {
        loadtest "installation/boot_encrypt.pm";
    }
    if (installyaststep_is_applicable) {
        loadtest "installation/first_boot.pm";
    }
    if (is_reboot_after_installation_necessary()) {
        loadtest "installation/reboot_eject_cd.pm";
        loadtest "installation/reboot_after_install.pm";
    }

    if (get_var("DUALBOOT")) {
        loadtest "installation/reboot_eject_cd.pm";
        loadtest "installation/boot_windows.pm";
    }
}

sub load_rescuecd_tests() {
    if (rescuecdstep_is_applicable) {
        loadtest "rescuecd/rescuecd.pm";
    }
}

sub load_zdup_tests() {
    if (get_var('ZDUP_IN_X')) {
        loadtest 'installation/setup_zdup_keepX.pm';
    }
    else {
        loadtest 'installation/setup_zdup.pm';
    }
    loadtest 'installation/zdup.pm';
    loadtest 'installation/post_zdup.pm';
}

sub load_consoletests() {
    if (consolestep_is_applicable) {
        loadtest "console/consoletest_setup.pm";
        loadtest "console/textinfo.pm";
        loadtest "console/hostname.pm";
        if (snapper_is_applicable) {
            if (get_var("UPGRADE")) {
                loadtest "console/upgrade_snapshots.pm";
            } else {
                loadtest "console/installation_snapshots.pm";
            }
        }
        if (get_var("DESKTOP") !~ /textmode/) {
            loadtest "console/xorg_vt.pm";
        }
        loadtest "console/zypper_lr.pm";
        if (need_clear_repos) {
            loadtest "console/zypper_clear_repos.pm";
        }
        if (have_addn_repos) {
            loadtest "console/zypper_ar.pm";
        }
        loadtest "console/zypper_ref.pm";
        loadtest "console/yast2_lan.pm";
        loadtest "console/curl_https.pm";
        if (!is_staging) {
            # TEST DEVELOPERS - Put tests that you don't want to run in stagings below here
            if (!get_var("OFW")) {
                loadtest "console/aplay.pm";
            }
            loadtest "console/yast2_cmdline.pm";
            loadtest "console/yast2_dns_server.pm";
            loadtest "console/yast2_nfs_client.pm";
        }
        if (!get_var("OFW")) {
            loadtest "console/glibc_i686.pm";
        }
        loadtest "console/zypper_up.pm";
        loadtest "console/zypper_in.pm";
        loadtest "console/yast2_i.pm";
        if (!get_var("LIVETEST")) {
            loadtest "console/yast2_bootloader.pm";
        }
        loadtest "console/sshd.pm";
        if (!get_var("LIVETEST") && !( get_var("FLAVOR", '') =~ /^Staging2?[\-]DVD$/ )) {
            # in live we don't have a password for root so ssh doesn't
            # work anyways, and except staging_core image, the rest of
            # staging_* images don't need run this test case
            loadtest "console/sshfs.pm";
        }
        if (get_var("BIGTEST")) {
            loadtest "console/sntp.pm";
            loadtest "console/curl_ipv6.pm";
            loadtest "console/wget_ipv6.pm";
            loadtest "console/syslinux.pm";
        }
        loadtest "console/mtab.pm";
        if (!get_var("NOINSTALL") && !get_var("LIVETEST") && ( check_var("DESKTOP", "textmode") )) {
            loadtest "console/http_srv.pm";
            loadtest "console/mysql_srv.pm";
            if (check_var('ARCH', 'x86_64')) {
                loadtest "console/docker.pm";
            }
        }
        if (get_var("MOZILLATEST")) {
            loadtest "console/mozmill_setup.pm";
        }
        if (check_var("DESKTOP", "xfce")) {
            loadtest "console/xfce_gnome_deps.pm";
        }
        if (get_var("CLONE_SYSTEM")) {
            loadtest "console/yast2_clone_system.pm";
        }
        loadtest "console/consoletest_finish.pm";
    }
}

sub load_x11tests(){
    return unless (!get_var("INSTALLONLY") && get_var("DESKTOP") !~ /textmode|minimalx/ && !get_var("DUALBOOT") && !get_var("RESCUECD"));

    if ( get_var("NOAUTOLOGIN") || get_var("XDMUSED") ) {
        loadtest "x11/x11_login.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/xfce_close_hint_popup.pm";
        loadtest "x11/xfce4_terminal.pm";
    }
    if (!get_var("NICEVIDEO")) {
        loadtest "x11/xterm.pm";
        loadtest "x11/sshxterm.pm" unless get_var("LIVETEST");
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
    if (!get_var("NICEVIDEO")) {
        loadtest "x11/firefox_audio.pm" unless get_var("OFW");
    }
    if (bigx11step_is_applicable && !get_var("NICEVIDEO")) {
        loadtest "x11/firefox_stress.pm";
    }
    if (gnomestep_is_applicable && !get_var("LIVECD") || !is_server) {
        loadtest "x11/thunderbird.pm";
    }
    if (get_var("MOZILLATEST")) {
        loadtest "x11/mozmill_run.pm";
    }
    if (!( get_var("FLAVOR", '') =~ /^Staging2?[\-]DVD$/ || system_is_livesystem )) {
        loadtest "x11/chromium.pm";
        if (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64')) {
            # GOOGLE Chrome only exists for i586 and x86_64 arch
            loadtest "x11/chrome.pm";
        }
    }
    if (bigx11step_is_applicable) {
        loadtest "x11/imagemagick.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/ristretto.pm";
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/eog.pm";
    }
    if (!get_var("NICEVIDEO") && get_var("DESKTOP") =~ /kde|gnome/ && !is_server) {
        loadtest "x11/oomath.pm";
    }
    if (!get_var("NICEVIDEO") && get_var("DESKTOP") =~ /kde|gnome/ && !get_var("LIVECD") && !is_server) {
        loadtest "x11/oocalc.pm";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/ && !is_server) {
        loadtest "x11/ooffice.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/khelpcenter.pm";
        loadtest "x11/systemsettings.pm";
        loadtest "x11/dolphin.pm";
    }
    loadtest "x11/yast2_users.pm";
    if (snapper_is_applicable) {
        loadtest "x11/yast2_snapper.pm";
    }
    if (gnomestep_is_applicable && get_var("GNOME2")) {
        loadtest "x11/application_browser.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/thunar.pm";
        loadtest "x11/reboot_xfce_pre.pm";
    }
    if (lxdestep_is_applicable) {
        loadtest "x11/reboot_lxde_pre.pm";
    }
    if (bigx11step_is_applicable && !get_var("NICEVIDEO")) {
        loadtest "x11/glxgears.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/amarok.pm";
        loadtest "x11/kontact.pm";
        if ( get_var("PLASMA5") ) {
            loadtest "x11/reboot_plasma5_pre.pm";
        }
        else {
            loadtest "x11/reboot_kde_pre.pm";
        }
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/nautilus.pm" unless get_var("LIVECD");
        loadtest "x11/gnome_music.pm";
        loadtest "x11/evolution.pm" unless is_server;
        loadtest "x11/reboot_gnome_pre.pm";
    }
    loadtest "x11/reboot.pm";
    loadtest "x11/desktop_mainmenu.pm";

    if (xfcestep_is_applicable) {
        loadtest "x11/xfce4_appfinder.pm";
        if (!( get_var("FLAVOR") eq 'Rescue-CD' )) {
            loadtest "x11/xfce_lightdm_logout_login.pm";
        }
    }

    unless (get_var("LIVECD")) {
        loadtest "x11/inkscape.pm";
        if (!get_var("NICEVIDEO")) {
            loadtest "x11/gimp.pm";
        }
    }
    if (!( get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ ) &&
        !system_is_livesystem ) {
        loadtest "x11/gnucash.pm";
    }
    loadtest "x11/shutdown.pm";
}

sub load_applicationstests {
    if (my $val = get_var("APPTESTS")) {
        for my $test (split(/,/, $val)) {
            loadtest "$test.pm";
        }
        return 1;
    }
    return 0;
}

sub load_skenkins_tests {
    if (get_var("SLENKINS_NODEFILE")) {
        my $node = get_var("SLENKINS_NODE");
        if ($node && $node ne 'control' ) {
            loadtest "slenkins/slenkins_node.pm";
        }
        else {
            loadtest "slenkins/slenkins_control.pm";
        }
        return 1;
    }
    return 0;
}

# load the tests in the right order
if ( get_var("REGRESSION") ) {
    if ( get_var("KEEPHDDS") ) {
        load_login_tests();
    }
    else {
        load_inst_tests();
        load_reboot_tests();
    }

    load_x11regresion_tests();
}
elsif (get_var("MEDIACHECK")) {
    loadtest "installation/mediacheck.pm";
}
elsif (get_var("MEMTEST")) {
    loadtest "installation/memtest.pm";
}
elsif (get_var("RESCUESYSTEM")) {
    loadtest "installation/rescuesystem.pm";
    loadtest "installation/rescuesystem_validate_131.pm";
}
elsif (get_var("LINUXRC")) {
    loadtest "linuxrc/system_boot.pm";
}
elsif (get_var("SYSAUTHTEST")) {
    load_boot_tests();
    loadtest "installation/finish_desktop.pm";
    # sysauth test scenarios run in the console
    loadtest "console/consoletest_setup.pm";
    loadtest "console/zypper_ar.pm";
    loadtest "sysauth/sssd.pm";
}
else {
    if (get_var("LIVETEST")) {
        load_boot_tests();
        loadtest "installation/finish_desktop.pm";
    }
    elsif (get_var("AUTOYAST")) {
        # autoyast is very easy
        load_boot_tests();
        loadtest "installation/start_install.pm";
        loadtest "installation/autoyast_reboot.pm";
        load_reboot_tests();
    }
    elsif (installzdupstep_is_applicable) {
        load_boot_tests();
        load_zdup_tests();
    }
    elsif (get_var("BOOT_HDD_IMAGE")) {
        loadtest "boot/boot_to_desktop.pm";
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }

    unless (load_applicationstests() || load_skenkins_tests()) {
        load_rescuecd_tests();
        load_consoletests();
        load_x11tests();
    }
}

if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) {
    if (get_var("INSTALLONLY")) {
        loadtest "shutdown/shutdown.pm";
    }
}

1;
# vim: set sw=4 et:
