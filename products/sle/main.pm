#!/usr/bin/perl -w
use strict;
use testapi;
use lockapi;
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
    VIDEOMODE => ["", "text", "ssh-x"],
);

sub logcurrentenv {
    for my $k (@_) {
        my $e = get_var("$k");
        next unless defined $e;
        bmwqemu::diag("usingenv $k=$e");
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

sub unregister_needle_tags {
    my $tag = shift;
    my @a   = @{needle::tags($tag)};
    for my $n (@a) { $n->unregister(); }
}

sub remove_desktop_needles {
    my $desktop = shift;
    if (!check_var("DESKTOP", $desktop) && !check_var("FULL_DESKTOP", $desktop)) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

sub is_server() {
    return is_sles4sap() || get_var('FLAVOR', '') =~ /^Server/;
}

sub is_desktop() {
    return get_var('FLAVOR', '') =~ /^Desktop/;
}

sub is_jeos() {
    return get_var('FLAVOR', '') =~ /^JeOS/;
}

sub is_staging () {
    return get_var('STAGING');
}

sub is_sles4sap () {
    return get_var('FLAVOR', '') =~ /SAP/;
}

sub is_sles4sap_standard () {
    return is_sles4sap && check_var('SLES4SAP_MODE', 'sles');
}

sub is_smt () {
    return (get_var("PATTERNS", '') || get_var('HDD_1', '')) =~ /smt/;
}

sub version_at_least;

sub version_at_least {
    my ($version) = @_;

    if ($version eq '12-SP1') {
        return !check_var('VERSION', '12');
    }

    if ($version eq '12-SP2') {
        return version_at_least('12-SP1') && !check_var('VERSION', '12-SP1');
    }

    if ($version eq '12-SP3') {
        return version_at_least('12-SP2') && !check_var('VERSION', '12-SP2');
    }

    die "unsupport VERSION $version in check";
}

sub cleanup_needles() {
    remove_desktop_needles("lxde");
    remove_desktop_needles("kde");
    remove_desktop_needles("gnome");
    remove_desktop_needles("xfce");
    remove_desktop_needles("minimalx");
    remove_desktop_needles("textmode");

    if (!check_var("VIDEOMODE", "text")) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }

    if (get_var("INSTLANG") && get_var("INSTLANG") ne "en_US") {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

    if (get_var('VERSION', '') ne '12') {
        unregister_needle_tags("ENV-VERSION-12");
    }

    if (get_var('VERSION', '') ne '12-SP1') {
        unregister_needle_tags("ENV-VERSION-12-SP1");
    }

    if (get_var('VERSION', '') ne '12-SP2') {
        unregister_needle_tags("ENV-VERSION-12-SP2");
    }

    my $tounregister = version_at_least('12-SP2') ? '0' : '1';
    unregister_needle_tags("ENV-SP2ORLATER-$tounregister");

    if (!is_server) {
        unregister_needle_tags("ENV-FLAVOR-Server-DVD");
    }

    if (!is_desktop) {
        unregister_needle_tags("ENV-FLAVOR-Desktop-DVD");
    }

    if (!is_jeos) {
        unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    }
    if (!check_var("ARCH", "s390x")) {
        unregister_needle_tags('ENV-ARCH-s390x');
    }

    if (get_var('OFW')) {
        unregister_needle_tags('ENV-OFW-0');
    }
    else {
        unregister_needle_tags('ENV-OFW-1');
    }
}


#assert_screen "inst-bootmenu",12; # wait for welcome animation to finish

# defaults for username and password
$testapi::username = "bernhard";
$testapi::password = "nots3cr3t";

$testapi::username = get_var("USERNAME") if get_var("USERNAME");
$testapi::password = get_var("PASSWORD") if defined get_var("PASSWORD");

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

check_env();

unless (get_var("DESKTOP")) {
    if (check_var("VIDEOMODE", "text")) {
        set_var("DESKTOP", "textmode");
    }
    else {
        set_var("DESKTOP", "gnome");
    }
}

# Tests currently rely on INSTLANG=en_US, so set it by default
unless (get_var('INSTLANG')) {
    set_var('INSTLANG', 'en_US');
}

# SLE specific variables
set_var('NOAUTOLOGIN', 1);
set_var('HASLICENSE',  1);

if (version_at_least('12-SP2')) {
    set_var('SP2ORLATER', 1);
}

if (!get_var('NETBOOT')) {
    set_var('DVD', 1);
}
if (!is_desktop) {
    set_var('NOIMAGES', 1);
}

if (check_var('DESKTOP', 'minimalx')) {
    set_var("XDMUSED", 1);
}
if (get_var('HDD_1', '') =~ /\D*-11-\S*/) {
    set_var('FILESYSTEM', 'ext4');
}

unless (get_var('PACKAGETOINSTALL')) {
    set_var("PACKAGETOINSTALL", "x3270");
}
set_var("WALLPAPER", '/usr/share/wallpapers/SLEdefault/contents/images/1280x1024.jpg');

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# SLE needs auth for shutdown
if (!defined get_var('SHUTDOWN_NEEDS_AUTH') && !is_desktop) {
    set_var('SHUTDOWN_NEEDS_AUTH', 1);
}

# for GNOME pressing enter is enough to login bernhard
if (check_var('DESKTOP', 'minimalx')) {
    set_var('DM_NEEDS_USERNAME', 1);
}

# use Fake SCC regcodes if none provided
if (!get_var('SCC_REGCODE') && get_var('FAKE_SCC_REGCODE')) {
    my @copy_vars = qw/REGCODE EMAIL URL CERT/;
    for my $i (map { uc } split(/,/, get_var('SCC_ADDONS', ''))) {
        push @copy_vars, "REGCODE_$i" if get_var("FAKE_SCC_REGCODE_$i");
    }
    for my $i (@copy_vars) {
        set_var("SCC_$i", get_var("FAKE_SCC_$i")) unless get_var("SCC_$i");
    }
}

$needle::cleanuphandler = \&cleanup_needles;

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE NETBOOT NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");


sub xfcestep_is_applicable() {
    return check_var("DESKTOP", "xfce");
}

sub rescuecdstep_is_applicable() {
    return get_var("RESCUECD");
}

sub consolestep_is_applicable() {
    return !get_var("INSTALLONLY") && !get_var("DUALBOOT") && !get_var("RESCUECD");
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

sub snapper_is_applicable() {
    my $fs = get_var("FILESYSTEM", 'btrfs');
    return ($fs eq "btrfs" && get_var("HDDSIZEGB", 10) > 10);
}

sub need_clear_repos() {
    return get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ && get_var("SUSEMIRROR");
}

sub have_scc_repos() {
    return check_var('SCC_REGISTER', 'console');
}

sub have_addn_repos() {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub rt_is_applicable() {
    return is_server && get_var("ADDONS", "") =~ /rt/;
}

sub we_is_applicable() {
    return is_server && (get_var("ADDONS", "") =~ /we/ or get_var("SCC_ADDONS", "") =~ /we/ or get_var("ADDONURL", "") =~ /we/);
}

sub uses_qa_net_hardware() {
    return check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw");
}

sub loadtest {
    my ($test) = @_;
    unless ($test =~ m,^tests/,) {
        $test = "tests/$test";
    }
    autotest::loadtest($test);
}

sub load_x11regression_firefox() {
    loadtest "x11regressions/firefox/sle12/firefox_smoke.pm";
    loadtest "x11regressions/firefox/sle12/firefox_localfiles.pm";
    loadtest "x11regressions/firefox/sle12/firefox_emaillink.pm";
    loadtest "x11regressions/firefox/sle12/firefox_urlsprotocols.pm";
    loadtest "x11regressions/firefox/sle12/firefox_downloading.pm";
    loadtest "x11regressions/firefox/sle12/firefox_extcontent.pm";
    loadtest "x11regressions/firefox/sle12/firefox_java.pm";
    loadtest "x11regressions/firefox/sle12/firefox_headers.pm";
    loadtest "x11regressions/firefox/sle12/firefox_pdf.pm";
    loadtest "x11regressions/firefox/sle12/firefox_pagesaving.pm";
    loadtest "x11regressions/firefox/sle12/firefox_changesaving.pm";
    loadtest "x11regressions/firefox/sle12/firefox_flashplayer.pm";
    loadtest "x11regressions/firefox/sle12/firefox_ssl.pm";
    loadtest "x11regressions/firefox/sle12/firefox_passwd.pm";
    loadtest "x11regressions/firefox/sle12/firefox_mhtml.pm";
    loadtest "x11regressions/firefox/sle12/firefox_plugins.pm";
    loadtest "x11regressions/firefox/sle12/firefox_extensions.pm";
    loadtest "x11regressions/firefox/sle12/firefox_appearance.pm";
    loadtest "x11regressions/firefox/sle12/firefox_html5.pm";
    loadtest "x11regressions/firefox/sle12/firefox_private.pm";
    loadtest "x11regressions/firefox/sle12/firefox_fullscreen.pm";
    loadtest "x11regressions/firefox/sle12/firefox_health.pm";
    loadtest "x11regressions/firefox/sle12/firefox_developertool.pm";
    loadtest "x11regressions/firefox/sle12/firefox_gnomeshell.pm";
    loadtest "x11regressions/firefox/sle12/firefox_rss.pm";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio.pm";
    }
}

sub load_x11regression_gnome() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/gnomecase/nautilus_cut_file.pm";
        loadtest "x11regressions/gnomecase/nautilus_permission.pm";
        loadtest "x11regressions/gnomecase/nautilus_open_ftp.pm";
        loadtest "x11regressions/gnomecase/application_starts_on_login.pm";
        loadtest "x11regressions/gnomecase/change_password.pm";
        loadtest "x11regressions/gnomecase/login_test.pm";
        loadtest "x11regressions/gnomecase/gnome_classic_switch.pm";
        loadtest "x11regressions/gnomecase/gnome_default_applications.pm";
        loadtest "x11regressions/gnomecase/gnome_window_switcher.pm";
    }
}

sub load_x11regression_documentation() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/gnote/gnote_first_run.pm";
        loadtest "x11regressions/gnote/gnote_link_note.pm";
        loadtest "x11regressions/gnote/gnote_rename_title.pm";
        loadtest "x11regressions/gnote/gnote_undo_redo.pm";
        loadtest "x11regressions/gnote/gnote_edit_format.pm";
        loadtest "x11regressions/gnote/gnote_search_all.pm";
        loadtest "x11regressions/gnote/gnote_search_body.pm";
        loadtest "x11regressions/gnote/gnote_search_title.pm";
        loadtest "x11regressions/evince/evince_open.pm";
        loadtest "x11regressions/evince/evince_view.pm";
        loadtest "x11regressions/evince/evince_rotate_zoom.pm";
        loadtest "x11regressions/evince/evince_find.pm";
        loadtest "x11regressions/gedit/gedit_launch.pm";
        loadtest "x11regressions/gedit/gedit_save.pm";
        loadtest "x11regressions/gedit/gedit_about.pm";
        loadtest "x11regressions/libreoffice/libreoffice_mainmenu_favorites.pm";
        loadtest "x11regressions/libreoffice/libreoffice_open_specified_file.pm";
        loadtest "x11regressions/libreoffice/libreoffice_double_click_file.pm";
        loadtest "x11regressions/libreoffice/libreoffice_mainmenu_components.pm";
        loadtest "x11regressions/libreoffice/libreoffice_recent_documents.pm";
        loadtest "x11regressions/libreoffice/libreoffice_default_theme.pm";
        loadtest "x11regressions/libreoffice/libreoffice_pyuno_bridge.pm";
    }
}

sub load_x11regression_message() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/empathy/empathy_aim.pm";
        loadtest "x11regressions/empathy/empathy_irc.pm";
        loadtest "x11regressions/evolution/evolution_smoke.pm";
        loadtest "x11regressions/evolution/evolution_mail_imap.pm";
        loadtest "x11regressions/evolution/evolution_mail_pop.pm";
        loadtest "x11regressions/evolution/evolution_mail_ews.pm";
        loadtest "x11regressions/evolution/evolution_timezone_setup.pm";
        loadtest "x11regressions/evolution/evolution_task_ews.pm";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/pidgin/prep_pidgin.pm";
        loadtest "x11regressions/pidgin/pidgin_IRC.pm";
        loadtest "x11regressions/pidgin/pidgin_aim.pm";
        loadtest "x11regressions/pidgin/clean_pidgin.pm";
    }
}

sub load_x11regression_other() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/shotwell/shotwell_import.pm";
        loadtest "x11regressions/shotwell/shotwell_edit.pm";
        loadtest "x11regressions/shotwell/shotwell_export.pm";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/tracker/prep_tracker.pm";
        loadtest "x11regressions/tracker/tracker_starts.pm";
        loadtest "x11regressions/tracker/tracker_searchall.pm";
        loadtest "x11regressions/tracker/tracker_pref_starts.pm";
        loadtest "x11regressions/tracker/tracker_open_apps.pm";
        loadtest "x11regressions/tracker/tracker_by_command.pm";
        loadtest "x11regressions/tracker/tracker_info.pm";
        loadtest "x11regressions/tracker/tracker_search_in_nautilus.pm";
        loadtest "x11regressions/tracker/tracker_mainmenu.pm";
        loadtest "x11regressions/tracker/clean_tracker.pm";
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
        loadtest "installation/bootloader_ofw.pm";
    }
    elsif (get_var("UEFI") || is_jeos) {
        if (check_var("BACKEND", "svirt")) {
            if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
                loadtest "installation/bootloader_hyperv.pm";
            }
            else {
                loadtest "installation/bootloader_svirt.pm";
            }
        }
        # TODO: rename to bootloader_grub2
        # Unless GRUB2 supports framebuffer on Xen PV (bsc#961638), grub2 tests
        # has to be skipped there.
        if (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux'))) {
            loadtest "installation/bootloader_uefi.pm";
        }
    }
    elsif (uses_qa_net_hardware) {
        loadtest "installation/qa_net.pm";
    }
    elsif (check_var("ARCH", "s390x")) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/bootloader_s390.pm";
        }
        else {
            loadtest "installation/bootloader_zkvm.pm";
        }
    }
    elsif (get_var("PXEBOOT")) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        loadtest "autoyast/pxe_boot.pm";
    }
    else {
        loadtest "installation/bootloader.pm";
    }
}

sub is_reboot_after_installation_necessary() {
    return 0 if get_var("DUALBOOT") || get_var("RESCUECD") || get_var("ZDUP");

    return get_var("REBOOTAFTERINSTALL") && !get_var("UPGRADE");
}

sub load_inst_tests() {
    loadtest "installation/welcome.pm";
    if (get_var('IBFT')) {
        loadtest "installation/iscsi_configuration.pm";
    }
    if (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/disk_activation.pm";
        }
        elsif (!version_at_least('12-SP2')) {
            loadtest "installation/skip_disk_activation.pm";
        }
    }
    if (get_var('MULTIPATH')) {
        loadtest "installation/multipath.pm";
    }
    if (get_var('UPGRADE')) {
        loadtest "installation/upgrade_select.pm";
    }
    if (get_var('SCC_REGISTER', '') eq 'installation') {
        loadtest "installation/scc_registration.pm";
    }
    else {
        loadtest "installation/skip_registration.pm";
    }
    if (is_sles4sap) {
        loadtest "installation/sles4sap_product_installation_mode.pm";
    }
    if (get_var('MAINT_TEST_REPO')) {
        loadtest 'installation/add_update_test_repo.pm';
    }
    loadtest "installation/addon_products_sle.pm";
    if (noupdatestep_is_applicable) {
        if (check_var('ARCH', 'x86_64') && version_at_least('12-SP2') && is_server && (!is_sles4sap || is_sles4sap_standard)) {
            loadtest "installation/system_role.pm";
        }
        loadtest "installation/partitioning.pm";
        if (defined(get_var("RAIDLEVEL"))) {
            loadtest "installation/partitioning_raid.pm";
        }
        elsif (get_var("LVM")) {
            loadtest "installation/partitioning_lvm.pm";
        }
        if (get_var("FILESYSTEM")) {
            loadtest "installation/partitioning_filesystem.pm";
        }
        if (get_var("TOGGLEHOME")) {
            loadtest "installation/partitioning_togglehome.pm";
        }

        if (get_var("ENLARGESWAP") && get_var("QEMURAM", 1024) > 4098) {
            loadtest "installation/installation_enlargeswap.pm";
        }

        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr.pm";
        }
        if (get_var("IBFT")) {
            loadtest "installation/partitioning_iscsi.pm";
        }
        if (uses_qa_net_hardware) {
            loadtest "installation/partitioning_firstdisk.pm";
        }
        loadtest "installation/partitioning_finish.pm";
    }
    # the VNC gadget is too unreliable to click, but we
    # need to be able to do installations on it. The release notes
    # functionality needs to be covered by other backends
    if (!check_var('BACKEND', 'generalhw')) {
        loadtest "installation/releasenotes.pm";
    }
    if (noupdatestep_is_applicable) {
        loadtest "installation/installer_timezone.pm";
        if (!get_var("REMOTE_MASTER")) {
            loadtest "installation/logpackages.pm";
        }
        if (is_sles4sap) {
            if (check_var("SLES4SAP_MODE", 'sles')) {
                loadtest "installation/user_settings.pm";
            }    # sles4sap wizard installation doesn't have user_settings step
        }
        else {
            loadtest "installation/user_settings.pm";
        }
        loadtest "installation/user_settings_root.pm";
        if (get_var('PATTERNS')) {
            loadtest "installation/installation_overview_before.pm";
            loadtest "installation/select_patterns.pm";
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
    if (check_var('BACKEND', 'svirt')) {
        # on svirt we need to redefine the xml-file to boot the installed kernel
        loadtest "installation/redefine_svirt_domain.pm";
    }
    if (is_sles4sap) {
        if (check_var('SLES4SAP_MODE', 'sles4sap_wizard')) {
            loadtest "installation/sles4sap_wizard.pm";
            if (get_var("TREX")) {
                loadtest "installation/sles4sap_wizard_trex.pm";
            }
            if (get_var("NW")) {
                loadtest "installation/sles4sap_wizard_nw.pm";
            }
            loadtest "installation/sles4sap_wizard_swpm.pm";
        }
    }

}

sub load_reboot_tests() {
    if (check_var("ARCH", "s390x")) {
        loadtest "installation/reconnect_s390.pm";
    }
    if (uses_qa_net_hardware) {
        loadtest "boot/qa_net_boot_from_hdd.pm";
    }
    if (installyaststep_is_applicable) {
        # test makes no sense on s390 because grub2 can't be captured
        if (!check_var("ARCH", "s390x")) {
            loadtest "installation/grub_test.pm";
            if ((snapper_is_applicable) && get_var("BOOT_TO_SNAPSHOT")) {
                loadtest "installation/boot_into_snapshot.pm";
            }
        }
        if (get_var("ENCRYPT")) {
            loadtest "installation/boot_encrypt.pm";
        }
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
    loadtest 'boot/boot_to_desktop.pm';
}

sub load_consoletests() {
    if (consolestep_is_applicable) {
        if (get_var("ADDONS", "") =~ /rt/) {
            loadtest "rt/kmp_modules.pm";
        }
        loadtest "console/consoletest_setup.pm";
        loadtest "console/check_console_font.pm";
        loadtest "console/textinfo.pm";
        loadtest "console/hostname.pm";
        if (get_var("SYSTEM_ROLE")) {
            loadtest "console/patterns.pm";
        }
        if (snapper_is_applicable) {
            if (get_var("UPGRADE")) {
                loadtest "console/upgrade_snapshots.pm";
            }
            elsif (!get_var("ZDUP") and !check_var('VERSION', '12')) {    # zypper and sle12 doesn't do upgrade or installation snapshots
                loadtest "console/installation_snapshots.pm";
            }
            loadtest "console/snapper_undochange.pm";
        }
        if (get_var("DESKTOP") !~ /textmode/ && !check_var("ARCH", "s390x")) {
            loadtest "console/xorg_vt.pm";
        }
        loadtest "console/zypper_lr.pm";
        if (need_clear_repos) {
            loadtest "console/zypper_clear_repos.pm";
        }
        #have SCC repo for SLE product
        if (have_scc_repos) {
            loadtest "console/yast_scc.pm";
        }
        elsif (have_addn_repos) {
            loadtest "console/zypper_ar.pm";
        }
        loadtest "console/zypper_ref.pm";
        loadtest "console/yast2_lan.pm";
        loadtest "console/curl_https.pm";
        if (check_var("ARCH", "x86_64")) {
            loadtest "console/glibc_i686.pm";
        }
        if (!gnomestep_is_applicable) {
            loadtest "console/zypper_up.pm";
        }
        if (is_jeos) {
            loadtest "console/console_reboot.pm";
        }
        loadtest "console/zypper_in.pm";
        loadtest "console/yast2_i.pm";
        loadtest "console/yast2_bootloader.pm";
        loadtest "console/vim.pm";
        if (!is_staging) {
            loadtest "console/firewall_enabled.pm";
        }
        if (is_jeos) {
            loadtest "console/gpt_ptable.pm";
            loadtest "console/kdump_disabled.pm";
            loadtest "console/sshd_running.pm";
        }
        if (rt_is_applicable) {
            loadtest "console/rt_is_realtime.pm";
            loadtest "console/rt_devel_packages.pm";
            loadtest "console/rt_peak_pci.pm";
            loadtest "console/rt_preempt_test.pm";
        }
        loadtest "console/sshd.pm";
        if (get_var("BIGTEST")) {
            loadtest "console/sntp.pm";
            loadtest "console/curl_ipv6.pm";
            loadtest "console/wget_ipv6.pm";
            loadtest "console/syslinux.pm";
        }
        loadtest "console/mtab.pm";
        if (!get_var("NOINSTALL") && !is_desktop && (check_var("DESKTOP", "textmode"))) {
            if (!is_staging && check_var('BACKEND', 'qemu')) {
                # The NFS test expects the IP to be 10.0.2.15
                loadtest "console/yast2_nfs_server.pm";
            }
            loadtest "console/http_srv.pm";
            loadtest "console/mysql_srv.pm";
            if (!is_staging) {
                # Very temporary removal of this test from staging - rbrown 6 Apr 2016
                loadtest "console/dns_srv.pm";
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

sub load_yast2ui_tests() {
    return unless (!get_var("INSTALLONLY") && get_var("DESKTOP") !~ /textmode|minimalx/ && !get_var("DUALBOOT") && !get_var("RESCUECD") && get_var("Y2UITEST"));

    loadtest "yast2_ui/yast2_control_center.pm";
    loadtest "yast2_ui/yast2_bootloader.pm";
    loadtest "yast2_ui/yast2_datetime.pm";
    loadtest "yast2_ui/yast2_firewall.pm";
    loadtest "yast2_ui/yast2_hostnames.pm";
    loadtest "yast2_ui/yast2_lang.pm";
    loadtest "yast2_ui/yast2_network_settings.pm";
    loadtest "yast2_ui/yast2_snapper.pm";
    loadtest "yast2_ui/yast2_software_management.pm";
    loadtest "yast2_ui/yast2_users.pm";
}

sub load_extra_test () {
    # Put tests that filled the conditions below
    # 1) you don't want to run in stagings below here
    # 2) the application is not rely on desktop environment
    # 3) running based on preinstalled image
    return unless get_var("EXTRATEST");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup.pm";
    loadtest "console/check_console_font.pm";
    loadtest "console/zypper_lr.pm";
    loadtest "console/zypper_ref.pm";
    loadtest "console/update_alternatives.pm";

    # start extra console tests from here
    if (!get_var("OFW") && !is_jeos) {
        loadtest "console/aplay.pm";
    }

    loadtest "console/command_not_found.pm";
    loadtest "console/yast2_http.pm";
    loadtest "console/yast2_ftp.pm";
    loadtest "console/yast2_proxy.pm";
    loadtest "console/yast2_ntpclient.pm";
    loadtest "console/yast2_tftp.pm";
    loadtest "console/yast2_vnc.pm";
    loadtest "console/yast2_samba.pm";
    # finished console test and back to desktop
    loadtest "console/consoletest_finish.pm";

    # start extra x11 tests from here

}

sub load_x11tests() {
    return unless (!get_var("INSTALLONLY") && get_var("DESKTOP") !~ /textmode|minimalx/ && !get_var("DUALBOOT") && !get_var("RESCUECD") && !get_var("HACLUSTER"));

    if (is_smt) {
        loadtest "x11/smt.pm";
    }
    if (get_var("XDMUSED")) {
        loadtest "x11/x11_login.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/xfce_close_hint_popup.pm";
        loadtest "x11/xfce4_terminal.pm";
    }
    loadtest "x11/xterm.pm";
    loadtest "x11/sshxterm.pm";
    if (gnomestep_is_applicable) {
        loadtest "x11/updates_gnome.pm";
        loadtest "x11/gnome_control_center.pm";
        loadtest "x11/gnome_terminal.pm";
        loadtest "x11/gedit.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/kate.pm";
    }
    loadtest "x11/firefox.pm";
    if (bigx11step_is_applicable) {
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
    if (!is_server || we_is_applicable) {
        if (gnomestep_is_applicable) {
            loadtest "x11/eog.pm";
            loadtest "x11/rhythmbox.pm";
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
    if (snapper_is_applicable) {
        loadtest "x11/yast2_snapper.pm";
    }
    if (gnomestep_is_applicable && get_var("GNOME2")) {
        loadtest "x11/application_browser.pm";
    }
    if (xfcestep_is_applicable) {
        loadtest "x11/thunar.pm";
        loadtest "x11/reboot_xfce.pm";
    }
    if (bigx11step_is_applicable) {
        loadtest "x11/glxgears.pm";
    }
    if (kdestep_is_applicable) {
        loadtest "x11/amarok.pm";
        loadtest "x11/kontact.pm";
        loadtest "x11/reboot_kde.pm";
    }
    if (gnomestep_is_applicable) {
        loadtest "x11/nautilus.pm";
        loadtest "x11/evolution.pm" if (!is_server || we_is_applicable);
        loadtest "x11/reboot_gnome.pm";
    }
    if (check_var("ARCH", "s390x")) {
        loadtest "installation/reconnect_s390.pm";
    }
    loadtest "x11/desktop_mainmenu.pm";

    if (xfcestep_is_applicable) {
        loadtest "x11/xfce4_appfinder.pm";
        loadtest "x11/xfce_notification.pm";
        if (!(get_var("FLAVOR") eq 'Rescue-CD')) {
            loadtest "x11/xfce_lightdm_logout_login.pm";
        }
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

sub load_autoyast_tests() {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation.pm");
    loadtest("autoyast/console.pm");
    loadtest("autoyast/login.pm");
    loadtest("autoyast/wicked.pm");
    loadtest("autoyast/autoyast_verify.pm") if get_var("AUTOYAST_VERIFY");
    if (get_var("SUPPORT_SERVER_GENERATOR")) {
        loadtest("support_server/configure.pm");
    }
    else {
        loadtest("autoyast/repos.pm");
        loadtest("autoyast/clone.pm");
        loadtest("autoyast/logs.pm");
    }
    loadtest("autoyast/autoyast_reboot.pm");
    #    next boot in load_reboot_tests
}

sub load_slenkins_tests {
    if (get_var("SLENKINS_CONTROL")) {
        unless (get_var("SUPPORT_SERVER")) {
            loadtest "slenkins/login.pm";
            loadtest "slenkins/slenkins_control_network.pm";
        }
        loadtest "slenkins/slenkins_control.pm";
        return 1;
    }
    elsif (get_var("SLENKINS_NODE")) {
        loadtest "slenkins/login.pm";
        loadtest "slenkins/slenkins_node.pm";
        return 1;
    }
    return 0;
}

sub load_hacluster_tests() {
    return unless (get_var("HACLUSTER"));
    sleep 10;    # wait to make sure that support server created locks
    if (get_var("HOSTNAME") eq 'host1') {
        mutex_lock("MUTEX_HA_" . get_var("CLUSTERNAME") . "_NODE1_WAIT");    #stop here until all nodes are running
        if (get_var("CTS")) {
            mutex_lock("MUTEX_CTS_INSTALLED");                               #mutex will be unlocked after cts is installed on all nodes
        }
    }
    else {
        mutex_lock("MUTEX_HA_" . get_var("CLUSTERNAME") . "_NODE2_WAIT");    #stop here until all nodes are running
    }
    loadtest("ha/barrier_init.pm");
    loadtest "installation/first_boot.pm";
    loadtest "console/consoletest_setup.pm";
    loadtest "console/hostname.pm";
    loadtest("ha/firewall_disable.pm");
    loadtest("ha/ntp_client.pm");
    loadtest("ha/iscsi_client.pm");
    loadtest("ha/watchdog.pm");
    if (get_var("HOSTNAME") eq 'host1') {
        loadtest("ha/ha_cluster_init.pm");                                   #node1 creates a cluster
    }
    else {
        loadtest("ha/ha_cluster_join.pm");                                   #node2 joins the cluster
    }
    if (get_var("CTS")) {
        loadtest("ha/cts.pm");
    }
    else {
        loadtest("ha/dlm.pm");
        loadtest("ha/clvm.pm");
        loadtest("ha/ocfs2.pm");
        loadtest("ha/crm_mon.pm");
        loadtest("ha/fencing.pm");
        if (!get_var("HACLUSTERJOIN")) {                                     #node1 will be fenced
            loadtest "ha/fencing_boot.pm";
            loadtest "ha/fencing_consoletest_setup.pm";
        }
    }
    loadtest("ha/check_logs.pm");                                            #check_logs must be after ha/fencing.pm
    return 1;
}

sub load_virtualization_tests() {
    # standalone suite to fit needed installation
    if (get_var("STANDALONEVT")) {
        loadtest "virtualization/boot.pm";
        loadtest "virtualization/installation.pm";
        loadtest "virtualization/prepare_sle12.pm";
    }
    loadtest "virtualization/yast_virtualization.pm";
    loadtest "virtualization/virt_install.pm";
    loadtest "virtualization/virt_top.pm";
    loadtest "virtualization/virtman_install.pm";
    loadtest "virtualization/virtman_view.pm";
    loadtest "virtualization/virtman_storage.pm";
    loadtest "virtualization/virtman_virtualnet.pm";
    loadtest "virtualization/virtman_networkinterface.pm";
    loadtest "virtualization/virtman_create_guest.pm";
}

sub load_feature_tests() {
    loadtest "console/consoletest_setup.pm";
    loadtest "feature/feature_console/zypper_releasever.pm";
    loadtest "feature/feature_console/suseconnect.pm";
}

sub load_online_migration_tests() {
    # stop packagekit service and more
    loadtest "online_migration/sle12_online_migration/online_migration_setup.pm";
    loadtest "online_migration/sle12_online_migration/register_system.pm";
    # do full update before migration
    # otherwise yast2/zypper migration will patch a minimal update
    loadtest "online_migration/sle12_online_migration/zypper_patch.pm" if (get_var("FULL_UPDATE"));
    loadtest "online_migration/sle12_online_migration/pre_migration.pm";
    loadtest "online_migration/sle12_online_migration/yast2_migration.pm"  if (check_var("MIGRATION_METHOD", 'yast'));
    loadtest "online_migration/sle12_online_migration/zypper_migration.pm" if (check_var("MIGRATION_METHOD", 'zypper'));
    loadtest "online_migration/sle12_online_migration/post_migration.pm";
}

sub load_fips_tests_web() {
    loadtest "console/curl_https.pm";
    loadtest "console/wget_https.pm";
}

sub prepare_target() {
    if (get_var("BOOT_HDD_IMAGE")) {
        loadtest "boot/boot_to_desktop.pm";
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }
}

# load the tests in the right order
if (get_var("REGRESSION")) {
    if (check_var("REGRESSION", "installation")) {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
        loadtest "x11regressions/x11regressions_setup.pm";
        loadtest "console/hostname.pm";
        loadtest "shutdown/grub_set_bootargs.pm";
        loadtest "shutdown/shutdown.pm";
    }
    elsif (check_var("REGRESSION", "firefox")) {
        loadtest "boot/boot_to_desktop.pm";
        load_x11regression_firefox();
    }
    elsif (check_var("REGRESSION", "gnome")) {
        loadtest "boot/boot_to_desktop.pm";
        load_x11regression_gnome();
    }
    elsif (check_var("REGRESSION", "documentation")) {
        loadtest "boot/boot_to_desktop.pm";
        load_x11regression_documentation();
    }
    elsif (check_var("REGRESSION", "message")) {
        loadtest "boot/boot_to_desktop.pm";
        load_x11regression_message();
    }
    elsif (check_var("REGRESSION", "other")) {
        loadtest "boot/boot_to_desktop.pm";
        load_x11regression_other();
    }
}
elsif (get_var("FEATURE")) {
    prepare_target();
    load_feature_tests();
}
elsif (get_var("MEDIACHECK")) {
    loadtest "installation/mediacheck.pm";
}
elsif (get_var("MEMTEST")) {
    if (!get_var("OFW")) {    #no memtest on PPC
        loadtest "installation/memtest.pm";
    }
}
elsif (get_var("RESCUESYSTEM")) {
    loadtest "installation/rescuesystem.pm";
    loadtest "installation/rescuesystem_validate_sle.pm";
}
elsif (get_var("INSTALLCHECK")) {
    loadtest "installation/rescuesystem.pm";
    loadtest "installation/installcheck.pm";
}
elsif (get_var("SUPPORT_SERVER")) {
    loadtest "support_server/boot.pm";
    loadtest "support_server/login.pm";
    loadtest "support_server/setup.pm";
    unless (load_slenkins_tests()) {
        loadtest "support_server/wait.pm";
    }
}
elsif (get_var("FIPS_TS")) {
    if (check_var("FIPS_TS", "setup")) {
        prepare_target();
    }
    elsif (check_var("FIPS_TS", "web")) {
        loadtest "boot/boot_to_desktop.pm";
        load_fips_tests_web;
    }
}
elsif (get_var("HACLUSTER_SUPPORT_SERVER")) {
    for my $clustername (split(/,/, get_var('CLUSTERNAME'))) {    #TODO: replace this ugly stuff with normal barriers
        mutex_create("MUTEX_HA_" . $clustername . "_NODE1_WAIT");
        mutex_lock("MUTEX_HA_" . $clustername . "_NODE1_WAIT");    #mutex will be released after wait_for_children_to_start
        mutex_create("MUTEX_HA_" . $clustername . "_NODE2_WAIT");
        mutex_lock("MUTEX_HA_" . $clustername . "_NODE2_WAIT");    #mutex will be released after wait_for_children_to_start
        mutex_create("MUTEX_HA_" . $clustername . "_FINISHED");    #support server can lock _FINISHED mutex when node1 finishes
        if (get_var("CTS")) {
            mutex_create("MUTEX_CTS_INSTALLED");                   #to be locked by node1 until CTS is installed on all nodes
            mutex_create("MUTEX_CTS_FINISHED");
            mutex_lock("MUTEX_CTS_FINISHED");                      #to be unlocked by support server after CTSLab.py is finished and to be locked by the node1
        }
    }
    for my $mutexname (qw(CLUSTER_INITIALIZED NODE2_JOINED OCFS2_INIT DLM_GROUPS_CREATED DLM_INIT DLM_CHECKED OCFS2_MKFS_DONE OCFS2_GROUP_ALTERED OCFS2_DATA_COPIED OCFS2_MD5_CHECKED BEFORE_FENCING FENCING_DONE LOGS_CHECKED CLVM_INIT CLVM_RESOURCE_CREATED CLVM_PV_VG_LV_CREATED CLVM_VG_RESOURCE_CREATED CLVM_RW_CHECKED CLVM_MD5SUM PACEMAKER_CTS_INSTALLED PACEMAKER_CTS_FINISHED)) {
        mutex_create("MUTEX_${mutexname}_M1");                     #barrier_create mutexes
        mutex_create("MUTEX_${mutexname}_M2");
    }
    if (get_var("CTS")) {
        loadtest "ha/ha_cts_support_server.pm";
    }
    else {
        loadtest "ha/ha_support_server.pm";
    }
}
elsif (get_var("HACLUSTER")) {
    load_hacluster_tests();
}
elsif (get_var("QA_TESTSET")) {
    if (get_var('OS_TEST_REPO')) {
        loadtest "qa_automation/patch_and_reboot.pm";
    }
    loadtest "qa_automation/" . get_var("QA_TESTSET") . ".pm";
}
elsif (get_var("QAM_MINIMAL")) {
    prepare_target();
    loadtest "qam-minimal/install_update.pm";
    loadtest "qam-minimal/update_minimal.pm";
    loadtest "qam-minimal/check_logs.pm";
    if (check_var("QAM_MINIMAL", 'full')) {
        loadtest "qam-minimal/install_patterns.pm";
        load_consoletests();
        load_x11tests();

        # actually we are using textmode until install_patterns.pm installs the gnome pattern
        # save DESKTOP variable here and restore it in install_patterns.pm
        # we do this after scheduling all tests for the original DESKTOP
        set_var('FULL_DESKTOP', get_var('DESKTOP'));
        set_var('DESKTOP',      'textmode');
    }
}
elsif (get_var("EXTRATEST")) {
    prepare_target();
    load_extra_test();
}
elsif (get_var("Y2UITEST")) {
    load_boot_tests();
    loadtest "installation/finish_desktop.pm";
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup.pm";
    # start extra yast console test from here
    loadtest "console/zypper_lr.pm";
    loadtest "console/zypper_ref.pm";
    # back to desktop
    loadtest "console/consoletest_finish.pm";
    load_yast2ui_tests();
}
else {
    if (get_var("AUTOYAST")) {
        load_boot_tests();
        load_autoyast_tests();
        load_reboot_tests();
    }
    elsif (installzdupstep_is_applicable) {
        load_boot_tests();
        load_zdup_tests();
    }
    elsif (get_var("ONLINE_MIGRATION")) {
        load_boot_tests();
        load_online_migration_tests();
    }
    elsif (get_var("BOOT_HDD_IMAGE")) {
        if (get_var("RT_TESTS")) {
            set_var('INSTALLONLY', 1);
            loadtest "rt/boot_rt_kernel.pm";
        }
        else {
            if (get_var("BOOT_TO_SNAPSHOT") && (snapper_is_applicable)) {
                loadtest "boot/grub_test_snapshot.pm";
                if (get_var("UPGRADE")) {
                    loadtest "boot/snapper_rollback.pm";
                }
                if (get_var("MIGRATION_ROLLBACK")) {
                    loadtest "online_migration/sle12_online_migration/snapper_rollback.pm";
                }
            }
            else {
                loadtest "boot/boot_to_desktop.pm";
            }
            if (get_var("ADDONS")) {
                loadtest "installation/addon_products_yast2.pm";
            }
            if (get_var("ISCSI_SERVER")) {
                set_var('INSTALLONLY', 1);
                loadtest "iscsi/iscsi_server.pm";
            }
            if (get_var("ISCSI_CLIENT")) {
                set_var('INSTALLONLY', 1);
                loadtest "iscsi/iscsi_client.pm";
            }
            if (get_var("REMOTE_MASTER")) {
                loadtest "remote/remote_master.pm";
                load_inst_tests();
            }
        }
    }
    elsif (get_var("REMOTE_SLAVE")) {
        load_boot_tests();
        loadtest "remote/remote_slave.pm";
        load_reboot_tests();
    }
    elsif (is_jeos) {
        load_boot_tests();
        loadtest "jeos/firstrun.pm";
        loadtest "jeos/grub2_gfxmode.pm";
        loadtest "jeos/diskusage.pm";
        loadtest "jeos/root_fs_size.pm";
        loadtest "jeos/mount_by_label.pm";
        if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE")) {
            loadtest "jeos/sccreg.pm";
        }
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }
    unless (load_applicationstests() || load_slenkins_tests()) {
        load_rescuecd_tests();
        load_consoletests();
        load_x11tests();
    }
}

if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) {
    if (get_var("INSTALLONLY")) {
        loadtest "console/hostname.pm";
        loadtest "shutdown/grub_set_bootargs.pm";
        loadtest "shutdown/shutdown.pm";
    }
}

if (get_var("TCM") || check_var("ADDONS", "tcm")) {
    loadtest "toolchain/install.pm";
    loadtest "toolchain/gcc5_fortran_compilation.pm";
    loadtest "toolchain/gcc5_C_compilation.pm";
    loadtest "toolchain/gcc5_Cpp_compilation.pm";
}

1;
# vim: set sw=4 et:
