#!/usr/bin/perl -w
use strict;
use testapi;
use autotest;
use needle;
use File::Find;

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES           => [0, 1],
    REBOOTAFTERINSTALL => [0, 1],
    DOCRUN             => [0, 1],

    #   BTRFS=>[0,1],
    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode)],

    #   ROOTFS=>[qw(ext3 xfs jfs btrfs reiserfs)],
    VIDEOMODE => ["", "text"],
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
        if (get_var("DOCRUN")) {
            next if $k eq "VIDEOMODE";
            next if $k eq "NOIMAGES";
        }
        my @range = @{$valueranges{$k}};
        my $rand  = int(rand(scalar @range));
        set_var($k, $range[$rand]);
        logcurrentenv($k);
    }
}

sub check_env() {
    for my $k (keys %valueranges) {
        next unless get_var($k);
        unless (grep { get_var($k) eq $_ } @{$valueranges{$k}}) {
            die sprintf("%s must be one of %s\n", $k, join(',', @{$valueranges{$k}}));
        }
    }
}

sub unregister_needle_tags($) {
    my $tag = shift;
    my @a   = @{needle::tags($tag)};
    for my $n (@a) { $n->unregister(); }
}

sub remove_desktop_needles($) {
    my $desktop = shift;
    if (!check_var("DESKTOP", $desktop)) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

sub remove_flavor_needles($) {
    my ($flavor) = @_;

    if (!check_var("FLAVOR", $flavor)) {
        unregister_needle_tags("ENV-FLAVOR-$flavor");
    }
}

sub cleanup_needles() {
    remove_desktop_needles("lxde");
    remove_desktop_needles("kde");
    remove_desktop_needles("gnome");
    remove_desktop_needles("xfce");
    remove_desktop_needles("minimalx");
    remove_desktop_needles("textmode");

    remove_flavor_needles('Server-DVD');
    remove_flavor_needles('Desktop-DVD');
    remove_flavor_needles('Core-DVD');

    remove_flavor_needles('Server-MINI');
    remove_flavor_needles('Desktop-MINI');

    if (!get_var("LIVECD")) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if (!check_var("VIDEOMODE", "text")) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }
    if (get_var("INSTLANG") && get_var("INSTLANG") ne "en_US") {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

}

sub is_server() {
    return check_var('FLAVOR', 'Server-DVD') || check_var('FLAVOR', 'Server-MINI');
}

sub is_desktop() {
    return check_var('FLAVOR', 'Desktop-DVD') || check_var('FLAVOR', 'Desktop-MINI');
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

if (get_var("LIVETEST") && (get_var("LIVECD") || get_var("PROMO"))) {
    $testapi::username = "linux";    # LiveCD account
    $testapi::password = "";
}

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

check_env();
setrandomenv if (get_var("RANDOMENV"));

unless (get_var("DESKTOP")) {
    if (check_var("VIDEOMODE", "text")) {
        set_var("DESKTOP", "textmode");
    }
    else {
        set_var("DESKTOP", "gnome");
    }
}

# SLE specific variables
set_var('NOAUTOLOGIN', 1);
set_var('HASLICENSE',  1);

set_var('OLD_IFCONFIG',      1);
set_var('DM_NEEDS_USERNAME', 1);
set_var('NOIMAGES',          1);

if (is_desktop) {
    # now that's fun - if AUTOCONF is set, autoconf is disabled
    set_var('AUTOCONF', 1);
}
else {
    # Server-DVD with gnome & kde need SHUTDOWN_NEEDS_AUTH
    set_var('SHUTDOWN_NEEDS_AUTH', 1);
}

if (check_var('DESKTOP', 'minimalx')) {
    set_var("XDMUSED", 1);
}

set_var("PACKAGETOINSTALL",   "x3270");
set_var("WALLPAPER",          '/usr/share/wallpapers/default-1600x1200.png');
set_var("YAST_SW_NO_SUMMARY", 1);

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# for GNOME pressing enter is enough to login bernhard
if (check_var('DESKTOP', 'minimalx')) {
    set_var('DM_NEEDS_USERNAME', 1);
}

$needle::cleanuphandler = \&cleanup_needles;

bmwqemu::save_vars();    # update variables

# dump other important ENV:
logcurrentenv(
    qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE LIVECD NETBOOT NICEVIDEO NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE"
);


sub xfcestep_is_applicable() {
    return check_var("DESKTOP", "xfce");
}

sub rescuecdstep_is_applicable() {
    return get_var("RESCUECD");
}

sub consolestep_is_applicable() {
    return !get_var("NICEVIDEO") && !get_var("DUALBOOT") && !get_var("RESCUECD");
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

sub need_clear_repos() {
    return get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ && get_var("SUSEMIRROR");
}

sub have_addn_repos() {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub loadtest($) {
    my ($test) = @_;
    autotest::loadtest(get_var("CASEDIR") . "/tests/$test");
}

sub load_x11regresion_tests() {
    loadtest "x11regressions/firefox/sle11/firefox_launch.pm";
    loadtest "x11regressions/firefox/sle11/firefox_menu.pm";
    loadtest "x11regressions/firefox/sle11/firefox_contentmenu.pm";
    loadtest "x11regressions/firefox/sle11/firefox_help.pm";
    loadtest "x11regressions/firefox/sle11/firefox_newwindow.pm";
    loadtest "x11regressions/firefox/sle11/firefox_home_page.pm";
    loadtest "x11regressions/firefox/sle11/firefox_topsite.pm";
    loadtest "x11regressions/firefox/sle11/firefox_https.pm";
    loadtest "x11regressions/firefox/sle11/firefox_importssl.pm";
    loadtest "x11regressions/firefox/sle11/firefox_loadie6.pm";
    loadtest "x11regressions/firefox/sle11/firefox_page_control.pm";
    loadtest "x11regressions/firefox/sle11/firefox_password_i.pm";
    loadtest "x11regressions/firefox/sle11/firefox_print.pm";
    loadtest "x11regressions/firefox/sle11/firefox_remember_passwd.pm";
    loadtest "x11regressions/firefox/sle11/firefox_search.pm";
    loadtest "x11regressions/firefox/sle11/firefox_sidebar.pm";
    loadtest "x11regressions/firefox/sle11/firefox_urlprotocols.pm";
    loadtest "x11regressions/firefox/sle11/firefox_url.pm";
    loadtest "x11regressions/firefox/sle11/firefox_localpage.pm";
    loadtest "x11regressions/firefox/sle11/firefox_mhtml.pm";
    loadtest "x11regressions/firefox/sle11/firefox_tab.pm";
    loadtest "x11regressions/firefox/sle11/firefox_sendlink.pm";
    loadtest "x11regressions/firefox/sle11/firefox_java.pm";
    loadtest "x11regressions/firefox/sle11/firefox_autocomplete.pm";
    loadtest "x11regressions/firefox/sle11/firefox_bookmarks.pm";
    loadtest "x11regressions/firefox/sle11/firefox_printing.pm";
    loadtest "x11regressions/firefox/sle11/firefox_printing_images.pm";
    loadtest "x11regressions/firefox/sle11/firefox_bookmark.pm";
    if ((check_var("DESKTOP", "gnome"))) {
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

sub load_login_tests() {
    if (!get_var("UEFI")) {
        loadtest "login/boot.pm";
    }
}

sub load_boot_tests() {
    if (get_var("ISO_MAXSIZE")) {
        loadtest "installation/isosize.pm";
    }
    if (get_var("OFW")) {
        loadtest "installation/bootloader_ofw_yaboot.pm";
    }
    elsif (get_var("UEFI")) {
        loadtest "installation/bootloader_uefi.pm";
    }
    elsif (check_var("BACKEND", "ipmi")) {
        loadtest "installation/qa_net.pm";
    }
    elsif (check_var("BACKEND", "s390x")) {
        bmwqemu::diag "trying installation/bootloader_s390.pm";
        loadtest "installation/bootloader_s390.pm";
    }
    elsif (get_var("PROXY")) {
        loadtest "installation/proxy_boot.pm";
    }
    elsif (get_var("PXEBOOT")) {
        set_var("DELAYED_START", "1");
        loadtest "autoyast/pxe_boot.pm";
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
    if (!check_var('BACKEND', 'ipmi') && !check_var('BACKEND', 's390x') && !get_var('USBBOOT') && !get_var('NETBOOT'))
    {    # network installs in general, but we have no setting for it yet
        loadtest "installation/check_medium.pm";
    }
    if (check_var('BACKEND', 's390x')) {
        loadtest "installation/disk_activation.pm";
    }
    if (get_var("MULTIPATH")) {
        loadtest "installation/multipath.pm";
    }
    loadtest "installation/mouse_hide.pm";
    loadtest "installation/installation_mode.pm";
    if (!get_var('LIVECD') && get_var('UPGRADE')) {
        loadtest "installation/upgrade_select_sle11.pm";
    }

    if (noupdatestep_is_applicable) {
        if (get_var("ADDONURL") || get_var("ADDONS")) {
            loadtest "installation/addon_products.pm";
        }

        loadtest "installation/installer_timezone.pm";
        if (is_server && !get_var("OFW") && !check_var('BACKEND', 's390x')) {
            loadtest "installation/server_base_scenario.pm";
        }
        if (is_desktop) {
            loadtest "installation/user_settings.pm";
            loadtest "installation/user_settings_root.pm";
        }

        if (!get_var("LIVECD") && !get_var("NICEVIDEO") && !get_var("PROXY")) {
            loadtest "installation/logpackages.pm";
        }

        if (defined(get_var('RAIDLEVEL'))) {
            loadtest "installation/partitioning_raid_sle11.pm";
        }
        elsif (get_var('FILESYSTEM') || get_var('LVM')) {
            loadtest "installation/partitioning_sle11.pm";
        }
        elsif (is_desktop && get_var("ADDONS") =~ /sdk/ && get_var('PATTERNS')) {
            loadtest "installation/partitioning_sle11_desktop_sdk.pm";
        }

        if (get_var('PATTERNS')) {
            loadtest "installation/installation_overview_before.pm";
            loadtest "installation/select_patterns_sle11.pm";
        }
        elsif (!check_var('DESKTOP', 'gnome')) {
            loadtest "installation/installation_overview_before.pm";
            loadtest "installation/change_desktop.pm";
        }
    }
    if (get_var("UEFI") && get_var("SECUREBOOT")) {
        loadtest "installation/secure_boot.pm";
    }
    if (installyaststep_is_applicable) {
        loadtest "installation/installation_overview.pm";
        loadtest "installation/start_install.pm";
    }
    loadtest "installation/install_and_reboot.pm";

    # 2nd stage
    if (get_var("PROXY")) {
        loadtest "installation/proxy_start_2nd_stage.pm";
    }
    loadtest "installation/sle11_wait_for_2nd_stage.pm";
    if (noupdatestep_is_applicable && is_server) {
        loadtest "installation/user_settings_root.pm";
    }
    loadtest "installation/sle11_network.pm";
    if (get_var('NCC')) {
        loadtest "installation/sle11_ncc.pm";
        loadtest "installation/sle11_online_update.pm";
    }
    else {
        loadtest "installation/sle11_skip_ncc.pm";
    }
    if (noupdatestep_is_applicable && is_server) {
        loadtest "installation/sle11_service.pm";
        loadtest "installation/sle11_user_authentication_method.pm";
        loadtest "installation/user_settings.pm";
    }
    if (noupdatestep_is_applicable && get_var("ADDONS") =~ /smt/) {
        loadtest "installation/smt_configuration.pm";
    }
    loadtest "installation/sle11_releasenotes.pm";
    if (noupdatestep_is_applicable) {
        loadtest "installation/sle11_hardware_config.pm";
    }
    loadtest "installation/sle11_install_finish.pm";
}

sub load_reboot_tests() {

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
    loadtest "installation/setup_zdup.pm";
    loadtest "installation/zdup.pm";
    loadtest "installation/post_zdup.pm";
}

sub load_consoletests() {
    if (consolestep_is_applicable) {
        loadtest "console/sle11_consoletest_setup.pm";
        loadtest "console/textinfo.pm";
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
        if (!get_var("OFW")) {
            loadtest "console/aplay.pm";
            loadtest "console/glibc_i686.pm";
        }
        loadtest "update/zypper_up.pm";
        loadtest "console/zypper_in.pm";
        loadtest "console/yast2_i.pm";
        if (!get_var("LIVETEST")) {
            loadtest "console/yast2_bootloader.pm";
        }
        loadtest "console/sshd.pm";
        if (get_var("BIGTEST")) {
            loadtest "console/sntp.pm";
            loadtest "console/curl_ipv6.pm";
            loadtest "console/wget_ipv6.pm";
            loadtest "console/syslinux.pm";
        }
        if (get_var("MOZILLATEST")) {
            loadtest "console/mozmill_setup.pm";
        }
        if (check_var("DESKTOP", "xfce")) {
            loadtest "console/xfce_gnome_deps.pm";
        }
        if (get_var("NCC")) {
            loadtest "console/sle11_ncc_checkrepos.pm";
        }
        loadtest "console/postgresql94.pm";
        if (is_server) {
            loadtest "console/postgresql94server_sle11.pm";
        }
        loadtest "console/consoletest_finish.pm";
    }
}

sub load_x11tests() {
    return unless (get_var("DESKTOP") !~ /textmode|minimalx/ && !get_var("DUALBOOT") && !get_var("RESCUECD"));

    if (kdestep_is_applicable) {
        loadtest "x11/sle11_kde_setup.pm";
    }
    if (get_var("XDMUSED")) {
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
        loadtest "x11/gnome_terminal.pm";
        loadtest "x11/gedit.pm";
    }
    loadtest "x11/sle11_firefox.pm";
    if (!get_var("NICEVIDEO")) {
        loadtest "x11/firefox_audio.pm" unless get_var("OFW");
    }
    if (bigx11step_is_applicable && !get_var("NICEVIDEO")) {
        loadtest "x11/firefox_stress.pm";
    }
    if (get_var("MOZILLATEST")) {
        loadtest "x11/mozmill_run.pm";
    }
    if (bigx11step_is_applicable) {
        loadtest "x11/imagemagick.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/ristretto.pm";
    }
    if (!is_server) {
        if (gnomestep_is_applicable) {
            loadtest "x11/eog.pm";
            loadtest "x11/banshee.pm";
        }
        if (get_var('DESKTOP') =~ /kde|gnome/) {
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
    if (gnomestep_is_applicable && get_var("GNOME2")) {
        loadtest "x11/application_browser.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/thunar.pm";
        loadtest "x11/reboot_xfce.pm";
    }
    if (bigx11step_is_applicable && !get_var("NICEVIDEO")) {
        loadtest "x11/glxgears.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/reboot_kde.pm";
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/nautilus.pm"  unless get_var("LIVECD");
        loadtest "x11/evolution.pm" unless (is_server);
        loadtest "x11/reboot_gnome_sle11.pm";
    }
    loadtest "x11/desktop_mainmenu.pm";

    if (xfcestep_is_applicable) {
        loadtest "x11/xfce4_appfinder.pm";
        loadtest "x11/xfce_notification.pm";
        if (!(get_var("FLAVOR") eq 'Rescue-CD')) {
            loadtest "x11/xfce_lightdm_logout_login.pm";
        }
    }

    loadtest "x11/shutdown_sle11.pm";
}

sub load_ha_tests() {
    loadtest "ha/sle11_ha_preparation.pm";
    loadtest "ha/iscsi_config.pm";
    loadtest "ha/sle11_cluster_init.pm";
    loadtest "ha/corosync.pm";
    loadtest "ha/fencing.pm";
    loadtest "ha/hawk.pm";
    loadtest "ha/ocfs2.pm";
}

sub load_autoyast_tests() {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation.pm");
    loadtest("autoyast/console.pm");
    loadtest("autoyast/login.pm");
    loadtest("autoyast/repos.pm") unless get_var("SUPPORT_SERVER_GENERATOR");
    loadtest("autoyast/autoyast_verify.pm") if get_var("AUTOYAST_VERIFY");
    loadtest("autoyast/autoyast_reboot.pm");
    #    next boot in load_reboot_tests
}

sub load_online_migration_tests() {
    loadtest("boot/boot_to_console.pm");
    loadtest("online_migration/sle11/add_beta_repos.pm");
    loadtest("online_migration/sle11/yast2_online_update.pm");
    loadtest("online_migration/sle11/yast2_wagon.pm");
    loadtest("online_migration/sle11/reboot_to_console.pm");
    loadtest("online_migration/sle11/check_upload_repos.pm");
}

sub load_slepos_tests() {
    if (get_var("SLEPOS") =~ /^adminserver/) {
        loadtest("boot/boot_to_desktop.pm");
        loadtest "slepos/prepare.pm";
        loadtest "slepos/zypper_add_repo.pm";
        loadtest "slepos/zypper_install_adminserver.pm";
        loadtest "slepos/run_posInitAdminserver.pm";
        loadtest "slepos/check_services.pm";
        loadtest "slepos/adminserver_configured.pm";
        loadtest "slepos/zypper_install_imageserver.pm";
        loadtest "slepos/use_smt_for_kiwi.pm";
        loadtest "slepos/download_images.pm" if get_var("IMAGE_DOWNLOAD");
        loadtest "slepos/build_images_kiwi.pm" if get_var("IMAGE_KIWI");
        loadtest "slepos/build_images_creator.pm" if get_var("IMAGE_CREATOR");
        loadtest "slepos/register_images.pm";
        loadtest "slepos/build_offline_images_kiwi.pm" if get_var("IMAGE_OFFLINE_KIWI");
        loadtest "slepos/build_offline_images_creator.pm" if get_var("IMAGE_OFFLINE_CREATOR");
        loadtest "slepos/wait.pm";
    }
    elsif (get_var("SLEPOS") =~ /^branchserver/) {
        loadtest("boot/boot_to_desktop.pm");
        loadtest "slepos/prepare.pm";
        loadtest "slepos/zypper_add_repo.pm";
        loadtest "slepos/zypper_install_branchserver.pm";
        loadtest "slepos/run_posInitBranchserver.pm";
        loadtest "slepos/check_services.pm";
        loadtest "slepos/run_possyncimages.pm";
        loadtest "slepos/wait.pm";
    }
    elsif (get_var("SLEPOS") =~ /^terminal-online/) {
        set_var("DELAYED_START", "1");
        loadtest "slepos/boot_image.pm";
    }
    elsif (get_var("SLEPOS") =~ /^terminal-offline/) {
        loadtest "slepos/boot_image.pm";
    }
}

# load the tests in the right order
if (get_var("REGRESSION")) {
    if (get_var("KEEPHDDS")) {
        load_login_tests();
    }
    else {
        load_inst_tests();
        load_reboot_tests();
    }

    load_x11regresion_tests();
}
elsif (get_var("MEDIACHECK")) {
    if (get_var("OFW")) {
        loadtest "installation/mediacheck_yaboot.pm";
    }
    else {
        loadtest "installation/mediacheck.pm";
    }
}
elsif (get_var("MEMTEST")) {
    loadtest "installation/memtest.pm";
}
elsif (get_var("RESCUESYSTEM")) {
    if (get_var("OFW")) {
        loadtest "installation/rescuesystem_yaboot.pm";
    }
    else {
        loadtest "installation/rescuesystem.pm";
        loadtest "installation/rescuesystem_validate_sle11sp3.pm";
    }
}
elsif (get_var("SUPPORT_SERVER")) {
    loadtest "support_server/boot.pm";
    loadtest "support_server/login.pm";
    loadtest "support_server/setup.pm";
    loadtest "support_server/wait.pm";
}
elsif (get_var("SLEPOS")) {
    load_slepos_tests();
}
elsif (get_var("ONLINE_MIGRATION")) {
    load_online_migration_tests();
}
elsif (get_var("UPGRADE_PANGO")) {
    loadtest "boot/boot_to_desktop.pm";
    loadtest "offline_migration/upgrade_glib2_pango32bit.pm";
    loadtest "shutdown/shutdown.pm";
}
else {
    load_boot_tests();
    if (get_var("PROXY")) {
        loadtest "installation/proxy_init.pm";
        if (get_var("SSH")) {
            loadtest "installation/proxy_ssh.pm";
        }
    }
    if (get_var("LIVETEST")) {
        loadtest "installation/finish_desktop.pm";
    }
    elsif (get_var("AUTOYAST")) {
        # TODO: merge with autoyast/system.pm?
        #        loadtest "installation/start_install.pm";
        load_autoyast_tests();
        load_reboot_tests();

    }
    elsif (installzdupstep_is_applicable) {
        load_zdup_tests();
    }
    else {
        load_inst_tests();
        load_reboot_tests();
    }
    load_rescuecd_tests();
    if (!get_var('INSTALLONLY')) {
        load_consoletests();
        load_x11tests();
    }
    if (get_var("HAVALIDATION")) {
        load_ha_tests();
    }
}

if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) {
    if (get_var("INSTALLONLY")) {
        loadtest "shutdown/shutdown.pm";
    }
}

1;
# vim: set sw=4 et:
