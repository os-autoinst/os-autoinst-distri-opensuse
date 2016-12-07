# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
use strict;
use warnings;
use testapi qw/check_var get_var set_var/;
use lockapi;
use needle;
use File::Find;
use File::Basename;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

sub is_server {
    return is_sles4sap() || get_var('FLAVOR', '') =~ /^Server/;
}

sub is_desktop {
    return get_var('FLAVOR', '') =~ /^Desktop/;
}

sub is_casp() {
    return check_var('DISTRI', 'casp');
}

sub is_sles4sap {
    return get_var('FLAVOR', '') =~ /SAP/;
}

sub is_sles4sap_standard {
    return is_sles4sap && check_var('SLES4SAP_MODE', 'sles');
}

sub is_smt {
    return (get_var("PATTERNS", '') || get_var('HDD_1', '')) =~ /smt/;
}

sub is_kgraft() {
    return get_var('FLAVOR', '') =~ /^KGraft/;
}

sub is_new_installation {
    return !get_var('UPGRADE') && !get_var('ONLINE_MIGRATION') && !get_var('ZDUP') && !get_var('AUTOUPGRADE');
}

sub is_update_test_repo_test {
    return get_var('TEST') !~ /^mru-/ && (get_var('FLAVOR', '') =~ /-Updates$/);
}

sub cleanup_needles {
    remove_common_needles;
    if (get_var('VERSION', '') ne '12') {
        unregister_needle_tags("ENV-VERSION-12");
    }

    if (get_var('VERSION', '') ne '12-SP1') {
        unregister_needle_tags("ENV-VERSION-12-SP1");
    }

    if (get_var('VERSION', '') ne '12-SP2') {
        unregister_needle_tags("ENV-VERSION-12-SP2");
    }

    if (get_var('VERSION', '') ne '12-SP3') {
        unregister_needle_tags("ENV-VERSION-12-SP3");
    }

    my $tounregister = sle_version_at_least('12-SP2') ? '0' : '1';
    unregister_needle_tags("ENV-SP2ORLATER-$tounregister");

    $tounregister = sle_version_at_least('12-SP3') ? '0' : '1';
    unregister_needle_tags("ENV-SP3ORLATER-$tounregister");

    if (!is_server) {
        unregister_needle_tags("ENV-FLAVOR-Server-DVD");
    }

    if (!is_desktop) {
        unregister_needle_tags("ENV-FLAVOR-Desktop-DVD");
    }

    if (!is_jeos) {
        unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    }

    if (!is_casp) {
        unregister_needle_tags('ENV-DISTRI-CASP');
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

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

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

if (sle_version_at_least('12-SP2')) {
    set_var('SP2ORLATER', 1);
}

if (sle_version_at_least('12-SP3')) {
    set_var('SP3ORLATER', 1);
}

if (!get_var('NETBOOT')) {
    set_var('DVD', 1);
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

# Always register at scc and use the test updates if the Flavor is -Updates.
# This way we can reuse existant test suites without having to patch their
# settings
if (is_update_test_repo_test && !get_var('MAINT_TEST_REPO')) {
    my $repos = get_var('OS_TEST_REPO');
    my @addons = split(/,/, get_var('SCC_ADDONS', ''));
    for my $a (split(/,/, get_var('ADDONS', ''))) {
        push(@addons, $a);
    }
    # move ADDONS to SCC_ADDONS for maintenance
    set_var('ADDONS', '');
    for my $a (@addons) {
        if ($a) {
            $repos .= "," . get_var(uc($a) . '_TEST_REPO');
        }
    }
    set_var('SCC_ADDONS', join(',', @addons));
    set_var('MAINT_TEST_REPO', $repos);
    set_var('SCC_REGISTER',    'installation');
}

$needle::cleanuphandler = \&cleanup_needles;

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE NETBOOT USEIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");


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
    return is_server() && get_var("ADDONS", "") =~ /rt/;
}

sub we_is_applicable() {
    return is_server() && (get_var("ADDONS", "") =~ /we/ or get_var("SCC_ADDONS", "") =~ /we/ or get_var("ADDONURL", "") =~ /we/);
}

sub uses_qa_net_hardware() {
    return check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw");
}

sub load_x11regression_firefox() {
    loadtest "x11regressions/firefox/sle12/firefox_smoke";
    loadtest "x11regressions/firefox/sle12/firefox_localfiles";
    loadtest "x11regressions/firefox/sle12/firefox_emaillink";
    loadtest "x11regressions/firefox/sle12/firefox_urlsprotocols";
    loadtest "x11regressions/firefox/sle12/firefox_downloading";
    loadtest "x11regressions/firefox/sle12/firefox_extcontent";
    loadtest "x11regressions/firefox/sle12/firefox_headers";
    loadtest "x11regressions/firefox/sle12/firefox_pdf";
    loadtest "x11regressions/firefox/sle12/firefox_changesaving";
    loadtest "x11regressions/firefox/sle12/firefox_fullscreen";
    loadtest "x11regressions/firefox/sle12/firefox_health";
    loadtest "x11regressions/firefox/sle12/firefox_flashplayer";
    loadtest "x11regressions/firefox/sle12/firefox_java";
    loadtest "x11regressions/firefox/sle12/firefox_pagesaving";
    loadtest "x11regressions/firefox/sle12/firefox_private";
    loadtest "x11regressions/firefox/sle12/firefox_mhtml";
    loadtest "x11regressions/firefox/sle12/firefox_plugins";
    loadtest "x11regressions/firefox/sle12/firefox_extensions";
    loadtest "x11regressions/firefox/sle12/firefox_appearance";
    loadtest "x11regressions/firefox/sle12/firefox_gnomeshell";
    loadtest "x11regressions/firefox/sle12/firefox_passwd";
    loadtest "x11regressions/firefox/sle12/firefox_html5";
    loadtest "x11regressions/firefox/sle12/firefox_developertool";
    loadtest "x11regressions/firefox/sle12/firefox_rss";
    loadtest "x11regressions/firefox/sle12/firefox_ssl";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio";
    }
}

sub load_x11regression_gnome() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/gnomecase/nautilus_cut_file";
        loadtest "x11regressions/gnomecase/nautilus_permission";
        loadtest "x11regressions/gnomecase/nautilus_open_ftp";
        loadtest "x11regressions/gnomecase/application_starts_on_login";
        loadtest "x11regressions/gnomecase/change_password";
        loadtest "x11regressions/gnomecase/login_test";
        loadtest "x11regressions/gnomecase/gnome_classic_switch";
        loadtest "x11regressions/gnomecase/gnome_default_applications";
        loadtest "x11regressions/gnomecase/gnome_window_switcher";
    }
}

sub load_x11regression_documentation() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/gnote/gnote_first_run";
        loadtest "x11regressions/gnote/gnote_link_note";
        loadtest "x11regressions/gnote/gnote_rename_title";
        loadtest "x11regressions/gnote/gnote_undo_redo";
        loadtest "x11regressions/gnote/gnote_edit_format";
        loadtest "x11regressions/gnote/gnote_search_all";
        loadtest "x11regressions/gnote/gnote_search_body";
        loadtest "x11regressions/gnote/gnote_search_title";
        loadtest "x11regressions/evince/evince_open";
        loadtest "x11regressions/evince/evince_view";
        loadtest "x11regressions/evince/evince_rotate_zoom";
        loadtest "x11regressions/evince/evince_find";
        loadtest "x11regressions/gedit/gedit_launch";
        loadtest "x11regressions/gedit/gedit_save";
        if (not get_var("SP2ORLATER")) {
            loadtest "x11regressions/gedit/gedit_about";
        }
        loadtest "x11regressions/libreoffice/libreoffice_mainmenu_favorites";
        loadtest "x11regressions/libreoffice/libreoffice_mainmenu_components";
        loadtest "x11regressions/libreoffice/libreoffice_recent_documents";
        loadtest "x11regressions/libreoffice/libreoffice_default_theme";
        loadtest "x11regressions/libreoffice/libreoffice_pyuno_bridge";
        loadtest "x11regressions/libreoffice/libreoffice_open_specified_file";
        loadtest "x11regressions/libreoffice/libreoffice_double_click_file";
    }
}

sub load_x11regression_message() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/empathy/empathy_aim";
        loadtest "x11regressions/empathy/empathy_irc";
        loadtest "x11regressions/evolution/evolution_smoke";
        loadtest "x11regressions/evolution/evolution_mail_imap";
        loadtest "x11regressions/evolution/evolution_mail_pop";
        loadtest "x11regressions/evolution/evolution_timezone_setup";
        loadtest "x11regressions/evolution/evolution_meeting_imap";
        loadtest "x11regressions/evolution/evolution_meeting_pop";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/pidgin/prep_pidgin";
        loadtest "x11regressions/pidgin/pidgin_IRC";
        loadtest "x11regressions/pidgin/pidgin_aim";
        loadtest "x11regressions/pidgin/clean_pidgin";
    }
}

sub load_x11regression_other() {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/shotwell/shotwell_import";
        loadtest "x11regressions/shotwell/shotwell_edit";
        loadtest "x11regressions/shotwell/shotwell_export";
        loadtest "virtualization/yast_virtualization";
        loadtest "virtualization/virtman_view";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/tracker/prep_tracker";
        loadtest "x11regressions/tracker/tracker_starts";
        loadtest "x11regressions/tracker/tracker_searchall";
        loadtest "x11regressions/tracker/tracker_pref_starts";
        loadtest "x11regressions/tracker/tracker_open_apps";
        loadtest "x11regressions/tracker/tracker_by_command";
        loadtest "x11regressions/tracker/tracker_info";
        loadtest "x11regressions/tracker/tracker_search_in_nautilus";
        loadtest "x11regressions/tracker/tracker_mainmenu";
        loadtest "x11regressions/tracker/clean_tracker";
    }
}

sub load_boot_tests() {
    if (get_var("ISO_MAXSIZE")) {
        loadtest "installation/isosize";
    }
    if (get_var("OFW")) {
        loadtest "installation/bootloader_ofw";
    }
    elsif ((get_var("UEFI") || is_jeos()) && !check_var("BACKEND", "svirt")) {
        loadtest "installation/bootloader_uefi";
    }
    elsif (check_var("BACKEND", "svirt") && !check_var("ARCH", "s390x")) {
        if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
            loadtest "installation/bootloader_hyperv";
        }
        else {
            loadtest "installation/bootloader_svirt";
        }
        # TODO: rename to bootloader_grub2
        # Unless GRUB2 supports framebuffer on Xen PV (bsc#961638), grub2 tests
        # has to be skipped there.
        if (!(check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux'))) {
            if (get_var("UEFI") || is_jeos) {
                loadtest "installation/bootloader_uefi";
            }
            elsif (!get_var('NETBOOT')) {
                loadtest "installation/bootloader";
            }
        }
    }
    elsif (uses_qa_net_hardware()) {
        loadtest "boot/boot_from_pxe";
    }
    elsif (check_var("ARCH", "s390x")) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/bootloader_s390";
        }
        else {
            loadtest "installation/bootloader_zkvm";
        }
    }
    elsif (get_var("PXEBOOT")) {
        mutex_lock('pxe');
        mutex_unlock('pxe');
        loadtest "autoyast/pxe_boot";
    }
    else {
        loadtest "installation/bootloader";
    }
}

sub install_this_version {
    return !check_var('INSTALL_TO_OTHERS', 1);
}

sub load_inst_tests() {
    if (!is_casp) {
        loadtest "installation/welcome";
    }
    if (get_var('DUD_ADDONS')) {
        loadtest "installation/dud_addon";
    }
    if (get_var('IBFT')) {
        loadtest "installation/iscsi_configuration";
    }
    if (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/disk_activation";
        }
        elsif (!sle_version_at_least('12-SP2')) {
            loadtest "installation/skip_disk_activation";
        }
    }
    if (get_var('ENCRYPT_CANCEL_EXISTING') || get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        loadtest "installation/encrypted_volume_activation";
    }
    if (get_var('MULTIPATH')) {
        loadtest "installation/multipath";
    }
    if (get_var('UPGRADE')) {
        loadtest "installation/upgrade_select";
        if (check_var("UPGRADE", "LOW_SPACE")) {
            loadtest "installation/disk_space_fill";
        }
    }
    if (get_var('SCC_REGISTER', '') eq 'installation') {
        loadtest "installation/scc_registration";
    }
    else {
        loadtest "installation/skip_registration";
    }
    if (is_sles4sap) {
        loadtest "installation/sles4sap_product_installation_mode";
    }
    if (get_var('MAINT_TEST_REPO')) {
        loadtest 'installation/add_update_test_repo';
    }
    loadtest "installation/addon_products_sle";
    if (noupdatestep_is_applicable()) {
        if (check_var('ARCH', 'x86_64') && sle_version_at_least('12-SP2') && is_server() && (!is_sles4sap() || is_sles4sap_standard()) && install_this_version()) {
            loadtest "installation/system_role";
        }
        loadtest "installation/partitioning";
        if (defined(get_var("RAIDLEVEL"))) {
            loadtest "installation/partitioning_raid";
        }
        elsif (get_var("LVM")) {
            loadtest "installation/partitioning_lvm";
        }
        if (get_var("FILESYSTEM")) {
            loadtest "installation/partitioning_filesystem";
        }
        if (get_var("TOGGLEHOME")) {
            loadtest "installation/partitioning_togglehome";
            if (get_var('LVM') && get_var('RESIZE_ROOT_VOLUME')) {
                loadtest "installation/partitioning_resize_root";
            }
        }
        if (get_var("ENLARGESWAP") && get_var("QEMURAM", 1024) > 4098) {
            loadtest "installation/installation_enlargeswap";
        }

        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr";
        }
        if (get_var("IBFT")) {
            loadtest "installation/partitioning_iscsi";
        }
        if (uses_qa_net_hardware()) {
            loadtest "installation/partitioning_firstdisk";
        }
        loadtest "installation/partitioning_finish";
    }
    # the VNC gadget is too unreliable to click, but we
    # need to be able to do installations on it. The release notes
    # functionality needs to be covered by other backends
    if (!check_var('BACKEND', 'generalhw')) {
        loadtest "installation/releasenotes";
    }
    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_timezone";
        # the test should run only in scenarios, where installed
        # system is not being tested (e.g. INSTALLONLY etc.)
        if (!consolestep_is_applicable() and !get_var("REMOTE_CONTROLLER") and !check_var('BACKEND', 's390x') and sle_version_at_least('12-SP2')) {
            loadtest "installation/hostname_inst";
        }
        if (!get_var("REMOTE_CONTROLLER")) {
            loadtest "installation/logpackages";
        }
        if (is_sles4sap()) {
            if (check_var("SLES4SAP_MODE", 'sles')) {
                loadtest "installation/user_settings";
            }    # sles4sap wizard installation doesn't have user_settings step
        }
        elsif (get_var('IMPORT_USER_DATA')) {
            loadtest 'installation/user_import';
        }
        else {
            loadtest "installation/user_settings";
        }
        loadtest "installation/user_settings_root";
        if (get_var('PATTERNS')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns";
        }
        elsif (!check_var('DESKTOP', 'gnome')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/change_desktop";
        }
    }
    if (get_var("UEFI") && get_var("SECUREBOOT")) {
        loadtest "installation/secure_boot";
    }
    if (installyaststep_is_applicable()) {
        loadtest "installation/installation_overview";
        if (check_var("UPGRADE", "LOW_SPACE")) {
            loadtest "installation/disk_space_release";
        }
        if (ssh_key_import) {
            loadtest "installation/ssh_key_setup";
        }
        loadtest "installation/start_install";
    }
    loadtest "installation/install_and_reboot";
    if (check_var('BACKEND', 'svirt')) {
        # on svirt we need to redefine the xml-file to boot the installed kernel
        loadtest "installation/redefine_svirt_domain";
    }
    if (is_sles4sap()) {
        if (check_var('SLES4SAP_MODE', 'sles4sap_wizard')) {
            loadtest "installation/sles4sap_wizard";
            if (get_var("TREX")) {
                loadtest "installation/sles4sap_wizard_trex";
            }
            if (get_var("NW")) {
                loadtest "installation/sles4sap_wizard_nw";
            }
            loadtest "installation/sles4sap_wizard_swpm";
        }
    }

}

sub load_reboot_tests() {
    if (check_var("ARCH", "s390x")) {
        loadtest "installation/reconnect_s390";
    }
    if (uses_qa_net_hardware()) {
        loadtest "boot/qa_net_boot_from_hdd";
    }
    if (installyaststep_is_applicable()) {
        # test makes no sense on s390 because grub2 can't be captured
        if (!(check_var("ARCH", "s390x") or (check_var('VIRSH_VMM_FAMILY', 'xen') and check_var('VIRSH_VMM_TYPE', 'linux')))) {
            loadtest "installation/grub_test";
            if ((snapper_is_applicable()) && get_var("BOOT_TO_SNAPSHOT")) {
                loadtest "installation/boot_into_snapshot";
            }
        }
        if (get_var('ENCRYPT')) {
            loadtest "installation/boot_encrypt";
        }
        loadtest "installation/first_boot";
    }
    if (is_reboot_after_installation_necessary()) {
        loadtest "installation/reboot_eject_cd";
        loadtest "installation/reboot_after_install";
    }

    if (get_var("DUALBOOT")) {
        loadtest "installation/reboot_eject_cd";
        loadtest "installation/boot_windows";
    }
}

sub load_consoletests() {
    if (consolestep_is_applicable()) {
        if (get_var("ADDONS", "") =~ /rt/) {
            loadtest "rt/kmp_modules";
        }
        loadtest "console/consoletest_setup";
        loadtest "console/check_console_font";
        loadtest "console/textinfo";
        loadtest "console/hostname";
        if (get_var("SYSTEM_ROLE")) {
            loadtest "console/patterns";
        }
        if (snapper_is_applicable()) {
            if (get_var("UPGRADE")) {
                loadtest "console/upgrade_snapshots";
            }
            elsif (!get_var("ZDUP") and !check_var('VERSION', '12')) {    # zypper and sle12 doesn't do upgrade or installation snapshots
                loadtest "console/installation_snapshots";
            }
            loadtest "console/snapper_undochange";
        }
        if (get_var("DESKTOP") !~ /textmode/ && !check_var("ARCH", "s390x")) {
            loadtest "console/xorg_vt";
        }
        loadtest "console/zypper_lr";
        if (need_clear_repos()) {
            loadtest "update/zypper_clear_repos";
        }
        #have SCC repo for SLE product
        if (have_scc_repos()) {
            loadtest "console/yast_scc";
        }
        elsif (have_addn_repos()) {
            loadtest "console/zypper_ar";
        }
        loadtest "console/zypper_ref";
        loadtest "console/yast2_lan";
        loadtest "console/curl_https";
        if (check_var("ARCH", "x86_64")) {
            loadtest "console/glibc_i686";
        }
        if (check_var('ARCH', 'aarch64')) {
            loadtest "console/acpi";
        }
        if (!gnomestep_is_applicable()) {
            loadtest "update/zypper_up";
        }
        if (is_jeos()) {
            loadtest "console/console_reboot";
        }
        loadtest "console/zypper_in";
        loadtest "console/yast2_i";
        loadtest "console/yast2_bootloader";
        loadtest "console/vim";
        if (!is_staging()) {
            loadtest "console/firewall_enabled";
        }
        if (is_jeos()) {
            loadtest "console/gpt_ptable";
            loadtest "console/kdump_disabled";
            loadtest "console/sshd_running";
        }
        if (rt_is_applicable()) {
            loadtest "console/rt_is_realtime";
            loadtest "console/rt_devel_packages";
            loadtest "console/rt_peak_pci";
            loadtest "console/rt_preempt_test";
        }
        loadtest "console/sshd";
        loadtest "console/ssh_cleanup";
        if (get_var("BIGTEST")) {
            loadtest "console/sntp";
            loadtest "console/curl_ipv6";
            loadtest "console/wget_ipv6";
            loadtest "console/syslinux";
        }
        loadtest "console/mtab";

        if (is_new_installation && sle_version_at_least('12-SP2')) {
            loadtest "console/no_perl_bootloader";
        }
        if (!get_var("NOINSTALL") && !is_desktop && (check_var("DESKTOP", "textmode"))) {
            if (!is_staging() && check_var('BACKEND', 'qemu')) {
                # The NFS test expects the IP to be 10.0.2.15
                loadtest "console/yast2_nfs_server";
            }
            loadtest "console/http_srv";
            loadtest "console/mysql_srv";
            loadtest "console/postgresql94server";
            if (sle_version_at_least('12-SP1')) {    # shibboleth-sp not available on SLES 12 GA
                loadtest "console/shibboleth";
            }
            if (!is_staging()) {
                # Very temporary removal of this test from staging - rbrown 6 Apr 2016
                loadtest "console/dns_srv";
            }
            if (get_var('ADDONS', '') =~ /wsm/ || get_var('SCC_ADDONS', '') =~ /wsm/) {
                loadtest "console/pcre";
                loadtest "console/php5";
                loadtest "console/php5_mysql";
                loadtest "console/php5_postgresql94";
            }
            loadtest "console/apache_ssl";
            loadtest "console/apache_nss";
        }
        if (get_var("MOZILLATEST")) {
            loadtest "console/mozmill_setup";
        }
        if (check_var("DESKTOP", "xfce")) {
            loadtest "console/xfce_gnome_deps";
        }
        if (get_var("CLONE_SYSTEM")) {
            loadtest "console/yast2_clone_system";
        }
        if (check_var('ARCH', 'aarch64') and sle_version_at_least('12-SP2')) {
            loadtest "console/check_gcc48_on_sdk_in_aarch64";
        }
        if (!is_staging() && sle_version_at_least('12-SP2')) {
            loadtest "console/zypper_lifecycle";
        }
        loadtest "console/consoletest_finish";
    }
}

sub load_yast2_gui_tests() {
    return unless (!get_var("INSTALLONLY") && is_desktop_installed() && !get_var("DUALBOOT") && !get_var("RESCUECD") && get_var("Y2UITEST"));

    loadtest "yast2_gui/yast2_control_center";
    loadtest "yast2_gui/yast2_bootloader";
    loadtest "yast2_gui/yast2_datetime";
    loadtest "yast2_gui/yast2_firewall";
    loadtest "yast2_gui/yast2_hostnames";
    loadtest "yast2_gui/yast2_lang";
    loadtest "yast2_gui/yast2_network_settings";
    loadtest "yast2_gui/yast2_snapper";
    loadtest "yast2_gui/yast2_software_management";
    loadtest "yast2_gui/yast2_users";
}

sub load_extra_test () {
    # Put tests that filled the conditions below
    # 1) you don't want to run in stagings below here
    # 2) the application is not rely on desktop environment
    # 3) running based on preinstalled image
    return unless get_var("EXTRATEST");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/check_console_font";
    if (sle_version_at_least('12-SP2')) {
        loadtest "console/openssl_alpn";
    }
    loadtest "console/zypper_lr";
    loadtest "console/zypper_ref";
    loadtest "console/update_alternatives";

    # start extra console tests from here
    if (!get_var("OFW") && !is_jeos()) {
        loadtest "console/aplay";
    }
    if (get_var("SP2ORLATER")) {
        loadtest "console/autoyast_removed";
    }
    if (get_var("FILESYSTEM", "btrfs") eq "btrfs") {
        loadtest "console/btrfs_autocompletion";
        if (get_var("NUMDISKS", 0) > 1) {
            loadtest "console/snapper_cleanup";
            loadtest "console/btrfs_qgroups";
            loadtest "console/btrfs_send_receive";
        }
    }

    loadtest "console/command_not_found";
    loadtest "console/yast2_nis";
    loadtest "console/yast2_http";
    loadtest "console/yast2_ftp";
    loadtest "console/yast2_proxy";
    loadtest "console/yast2_ntpclient";
    loadtest "console/yast2_tftp";
    loadtest "console/yast2_vnc";
    loadtest "console/yast2_samba";
    loadtest "console/yast2_xinetd";
    loadtest "console/yast2_apparmor";
    loadtest "console/openvswitch";
    loadtest "console/git";
    # finished console test and back to desktop
    loadtest "console/consoletest_finish";

    # start extra x11 tests from here
    loadtest "x11/vnc_two_passwords";
    loadtest "x11/yast2_lan_restart";
    loadtest "x11/user_defined_snapshot";
}

sub load_x11tests() {
    return unless (!get_var("INSTALLONLY") && is_desktop_installed() && !get_var("DUALBOOT") && !get_var("RESCUECD") && !get_var("HACLUSTER"));

    if (is_smt()) {
        loadtest "x11/smt";
    }
    if (get_var("XDMUSED")) {
        loadtest "x11/x11_login";
    }
    loadtest "x11/xterm";
    loadtest "x11/sshxterm";
    if (gnomestep_is_applicable()) {
        loadtest "update/updates_packagekit_gpk";
        loadtest "x11/gnome_control_center";
        loadtest "x11/gnome_terminal";
        loadtest "x11/gedit";
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/kate";
    }
    loadtest "x11/firefox";
    if (bigx11step_is_applicable()) {
        loadtest "x11/firefox_stress";
    }
    if (get_var("MOZILLATEST")) {
        loadtest "x11/mozmill_run";
    }
    if (!is_server() || we_is_applicable()) {
        if (gnomestep_is_applicable()) {
            loadtest "x11/eog";
            loadtest "x11/rhythmbox";
            loadtest "x11/ImageMagick";
            loadtest "x11/ghostscript";
        }
        if (get_var('DESKTOP') =~ /kde|gnome/) {
            loadtest "x11/ooffice";
            loadtest "x11/oomath";
            loadtest "x11/oocalc";
        }
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/khelpcenter";
        loadtest "x11/systemsettings";
        loadtest "x11/dolphin";
    }
    if (snapper_is_applicable()) {
        loadtest "x11/yast2_snapper";
    }
    if (gnomestep_is_applicable() && get_var("GNOME2")) {
        loadtest "x11/application_browser";
    }
    if (bigx11step_is_applicable()) {
        loadtest "x11/glxgears";
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/amarok";
        loadtest "x11/kontact";
        loadtest "x11/reboot_kde";
    }
    if (gnomestep_is_applicable()) {
        loadtest "x11/nautilus";
        loadtest "x11/evolution" if (!is_server() || we_is_applicable());
        loadtest "x11/reboot_gnome";
    }
    loadtest "x11/desktop_mainmenu";
    loadtest "x11/shutdown";
}

sub load_applicationstests {
    if (my $val = get_var("APPTESTS")) {
        for my $test (split(/,/, $val)) {
            loadtest "$test";
        }
        return 1;
    }
    return 0;
}

sub load_slenkins_tests {
    if (get_var("SLENKINS_CONTROL")) {
        unless (get_var("SUPPORT_SERVER")) {
            loadtest "slenkins/login";
            loadtest "slenkins/slenkins_control_network";
        }
        loadtest "slenkins/slenkins_control";
        return 1;
    }
    elsif (get_var("SLENKINS_NODE")) {
        loadtest "slenkins/login";
        loadtest "slenkins/slenkins_node";
        return 1;
    }
    return 0;
}

sub load_hacluster_tests() {
    return unless (get_var("HACLUSTER"));
    sleep 10;                                                # wait to make sure that support server created locks
    barrier_wait("BARRIER_HA_" . get_var("CLUSTERNAME"));    #nodes wait here
    loadtest "installation/first_boot";
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    loadtest("ha/firewall_disable");
    loadtest("ha/ntp_client");
    loadtest("ha/iscsi_client");
    loadtest("ha/watchdog");
    if (get_var("HOSTNAME") eq 'host1') {
        loadtest("ha/ha_cluster_init");                      #node1 creates a cluster
    }
    else {
        loadtest("ha/ha_cluster_join");                      #node2 joins the cluster
    }
    if (get_var("CTS")) {
        loadtest("ha/cts");
    }
    else {
        loadtest("ha/dlm");
        loadtest("ha/clvm");
        loadtest("ha/ocfs2");
        loadtest("ha/drbd");
        loadtest("ha/crm_mon");
        loadtest("ha/fencing");
        if (!get_var("HACLUSTERJOIN")) {                     #node1 will be fenced
            loadtest "ha/fencing_boot";
            loadtest "ha/fencing_consoletest_setup";
        }
    }
    loadtest("ha/check_logs");                               #check_logs must be after ha/fencing
    return 1;
}

sub load_virtualization_tests() {
    # standalone suite to fit needed installation
    if (get_var("STANDALONEVT")) {
        loadtest "virtualization/boot";
        loadtest "virtualization/installation";
        loadtest "virtualization/prepare_sle12";
    }
    loadtest "virtualization/yast_virtualization";
    loadtest "virtualization/virt_install";
    loadtest "virtualization/virt_top";
    loadtest "virtualization/virtman_install";
    loadtest "virtualization/virtman_view";
    loadtest "virtualization/virtman_storage";
    loadtest "virtualization/virtman_virtualnet";
    loadtest "virtualization/virtman_networkinterface";
    loadtest "virtualization/virtman_create_guest";
}

sub load_feature_tests() {
    loadtest "console/consoletest_setup";
    loadtest "feature/feature_console/zypper_releasever";
    loadtest "feature/feature_console/suseconnect";
    loadtest "feature/feature_console/zypper_crit_sec_fix_only";
}

sub load_online_migration_tests() {
    # stop packagekit service and more
    loadtest "online_migration/sle12_online_migration/online_migration_setup";
    loadtest "online_migration/sle12_online_migration/register_system";
    loadtest "online_migration/sle12_online_migration/repos_check";
    # do full update before migration
    # otherwise yast2/zypper migration will patch a minimal update
    loadtest "online_migration/sle12_online_migration/zypper_patch" if (get_var("FULL_UPDATE"));
    loadtest "online_migration/sle12_online_migration/pre_migration";
    loadtest "online_migration/sle12_online_migration/yast2_migration"  if (check_var("MIGRATION_METHOD", 'yast'));
    loadtest "online_migration/sle12_online_migration/zypper_migration" if (check_var("MIGRATION_METHOD", 'zypper'));
    loadtest "online_migration/sle12_online_migration/post_migration";
}

sub load_fips_tests_core() {
    loadtest "fips/openssl/openssl_fips_alglist";
    loadtest "fips/openssl/openssl_fips_hash";
    loadtest "fips/openssl/openssl_fips_cipher";
    loadtest "fips/openssl/openssl_pubkey_rsa";
    loadtest "fips/openssl/openssl_pubkey_dsa";
    if (sle_version_at_least('12-SP2')) {
        loadtest "console/openssl_alpn";
    }
    loadtest "console/sshd";
    loadtest "console/ssh_pubkey";
    loadtest "console/ssh_cleanup";
    loadtest "fips/openssh/openssh_fips";
}

sub load_fips_tests_web() {
    loadtest "console/curl_https";
    loadtest "console/wget_https";
    loadtest "console/w3m_https";
    loadtest "console/apache_ssl";
    loadtest "fips/mozilla_nss/apache_nssfips";
    loadtest "console/libmicrohttpd";
    loadtest "console/consoletest_finish";
    loadtest "fips/mozilla_nss/firefox_nss";
}

sub load_fips_tests_misc() {
    loadtest "console/aide_check";
    loadtest "console/journald_fss";
    loadtest "fips/curl_fips_rc4_seed";
    loadtest "console/git";
    loadtest "console/consoletest_finish";
    loadtest "x11/hexchat_ssl";
}

sub load_fips_tests_crypt() {
    loadtest "console/yast2_dm_crypt";
    loadtest "console/cryptsetup";
    loadtest "console/ecryptfs_fips";
}

sub prepare_target() {
    if (get_var("BOOT_HDD_IMAGE")) {
        if (check_var("BACKEND", "svirt")) {
            loadtest "installation/bootloader_svirt";
        }
        loadtest "boot/boot_to_desktop";
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
        loadtest "x11regressions/x11regressions_setup";
        loadtest "console/hostname";
        loadtest "shutdown/grub_set_bootargs";
        loadtest "shutdown/shutdown";
    }
    elsif (check_var("REGRESSION", "firefox")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_firefox();
    }
    elsif (check_var("REGRESSION", "gnome")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_gnome();
    }
    elsif (check_var("REGRESSION", "documentation")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_documentation();
    }
    elsif (check_var("REGRESSION", "message")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_message();
    }
    elsif (check_var("REGRESSION", "other")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_other();
    }
}
elsif (get_var("FEATURE")) {
    prepare_target();
    load_feature_tests();
}
elsif (get_var("MEDIACHECK")) {
    loadtest "installation/mediacheck";
}
elsif (get_var("MEMTEST")) {
    if (!get_var("OFW")) {    #no memtest on PPC
        loadtest "installation/memtest";
    }
}
elsif (get_var("RESCUESYSTEM")) {
    loadtest "installation/rescuesystem";
    loadtest "installation/rescuesystem_validate_sle";
}
elsif (get_var("INSTALLCHECK")) {
    loadtest "installation/rescuesystem";
    loadtest "installation/installcheck";
}
elsif (get_var("SUPPORT_SERVER")) {
    loadtest "support_server/boot";
    loadtest "support_server/login";
    loadtest "support_server/setup";
    unless (load_slenkins_tests()) {
        loadtest "support_server/wait";
    }
}
elsif (get_var("SLEPOS")) {
    load_slepos_tests();
}
elsif (get_var("FIPS_TS")) {
    if (check_var("FIPS_TS", "setup")) {
        prepare_target();
        # Setup system into fips mode
        loadtest "fips/fips_setup";
    }
    else {
        loadtest "boot/boot_to_desktop";
        # Turn off packagekit, setup $serialdev permission and etc
        loadtest "console/consoletest_setup";
        if (check_var("FIPS_TS", "core")) {
            load_fips_tests_core;
        }
        elsif (check_var("FIPS_TS", "web")) {
            load_fips_tests_web;
        }
        elsif (check_var("FIPS_TS", "misc")) {
            load_fips_tests_misc;
        }
        elsif (check_var("FIPS_TS", "crypt")) {
            load_fips_tests_crypt;
        }
    }
}
elsif (get_var("HACLUSTER_SUPPORT_SERVER")) {
    if (get_var("CTS")) {
        loadtest "ha/ha_cts_support_server";
    }
    else {
        loadtest("ha/barrier_init");
        loadtest "ha/ha_support_server";
    }
}
elsif (get_var("HACLUSTER")) {
    load_hacluster_tests();
}
elsif (get_var("QA_TESTSET")) {
    if (get_var('OS_TEST_REPO')) {
        loadtest "qa_automation/patch_and_reboot";
    }
    loadtest "qa_automation/" . get_var("QA_TESTSET");
}
elsif (get_var('INSTALL_LTP')) {
    loadtest 'kernel/install_ltp';
    loadtest 'kernel/boot_ltp';
    loadtest 'kernel/shutdown_ltp';
}
elsif (get_var('LTP_COMMAND_FILE')) {
    loadtest 'kernel/boot_ltp';
    loadtest 'kernel/run_ltp';
}
elsif (get_var('VIRTIO_CONSOLE_TEST')) {
    loadtest 'kernel/virtio_console';
}
elsif (get_var("VIRT_AUTOTEST")) {
    if (get_var("PROXY_MODE")) {
        loadtest "virt_autotest/proxymode_login_proxy";
        loadtest "virt_autotest/proxymode_init_pxe_install";
        loadtest "virt_autotest/proxymode_redirect_serial1";
        loadtest "virt_autotest/install_package";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/setup_console_on_host";
            loadtest "virt_autotest/reboot_and_wait_up_normal1";
            loadtest "virt_autotest/proxymode_redirect_serial2";
        }
        loadtest "virt_autotest/update_package";
        loadtest "virt_autotest/setup_console_on_host1";
        loadtest "virt_autotest/reboot_and_wait_up_normal2";
        loadtest "virt_autotest/proxymode_redirect_serial3";
    }
    else {
        load_boot_tests();
        load_inst_tests();
        loadtest "virt_autotest/login_console";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/setup_console_on_host1";
            loadtest "virt_autotest/reboot_and_wait_up_normal1";
        }
        loadtest "virt_autotest/install_package";
        loadtest "virt_autotest/update_package";
        loadtest "virt_autotest/reboot_and_wait_up_normal2";
    }
    if (get_var("VIRT_PRJ1_GUEST_INSTALL")) {
        loadtest "virt_autotest/guest_installation_run";
    }
    elsif (get_var("VIRT_PRJ2_HOST_UPGRADE")) {
        loadtest "virt_autotest/host_upgrade_generate_run_file";
        loadtest "virt_autotest/host_upgrade_step2_run";
        loadtest "virt_autotest/reboot_and_wait_up_upgrade";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/setup_console_on_host2";
            loadtest "virt_autotest/reboot_and_wait_up_normal3";
        }
        loadtest "virt_autotest/host_upgrade_step3_run";
    }
    elsif (get_var("VIRT_PRJ3_GUEST_MIGRATION_SOURCE")) {
        loadtest "virt_autotest/guest_migration_config_virtualization_env";
        loadtest "virt_autotest/guest_migration_source_nfs_setup";
        loadtest "virt_autotest/guest_migration_source_install_guest";
        loadtest "virt_autotest/guest_migration_source_migrate";
    }
    elsif (get_var("VIRT_PRJ3_GUEST_MIGRATION_TARGET")) {
        loadtest "virt_autotest/guest_migration_config_virtualization_env";
        loadtest "virt_autotest/guest_migration_target_nfs_setup";
    }
    elsif (get_var("VIRT_PRJ4_GUEST_UPGRADE")) {
        loadtest "virt_autotest/guest_upgrade_run";
    }
    elsif (get_var("VIRT_PRJ5_PVUSB")) {
        loadtest "virt_autotest/pvusb_run";
    }
}
elsif (get_var("QAM_MINIMAL")) {
    prepare_target();
    loadtest "qam-minimal/install_update";
    loadtest "qam-minimal/update_minimal";
    loadtest "qam-minimal/check_logs";
    if (check_var("QAM_MINIMAL", 'full')) {
        loadtest "qam-minimal/install_patterns";
        load_consoletests();
        load_x11tests();

        # actually we are using textmode until install_patterns.pm installs the gnome pattern
        # save DESKTOP variable here and restore it in install_patterns.pm
        # we do this after scheduling all tests for the original DESKTOP
        set_var('FULL_DESKTOP', get_var('DESKTOP'));
        set_var('DESKTOP',      'textmode');
    }
}
elsif (is_kgraft) {
    loadtest "qam-kgraft/update_kgraft";
    loadtest "qam-kgraft/regressions_tests";
    loadtest "qam-kgraft/reboot_restore";
}
elsif (get_var("EXTRATEST")) {
    prepare_target();
    load_extra_test();
}
elsif (get_var("Y2UITEST")) {
    load_boot_tests();
    loadtest "installation/finish_desktop";
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    # start extra yast console test from here
    loadtest "console/zypper_lr";
    loadtest "console/zypper_ref";
    # back to desktop
    loadtest "console/consoletest_finish";
    load_yast2_gui_tests();
}
elsif (get_var("WINDOWS")) {
    loadtest "installation/win10_installation";
}
elsif (ssh_key_import) {
    loadtest "boot/boot_to_desktop";
    # setup ssh key, we know what ssh keys we have and can verify if they are imported or not
    loadtest "x11/ssh_key_check";
    # reboot after test specific setup and start installation/update
    loadtest "x11/reboot_and_install";
    load_inst_tests();
    load_reboot_tests();
    # verify previous defined ssh keys
    loadtest "x11/ssh_key_verify";
}
else {
    if (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
        load_boot_tests();
        load_autoyast_tests();
        load_reboot_tests();
    }
    elsif (installzdupstep_is_applicable()) {
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
            loadtest "rt/boot_rt_kernel";
        }
        else {
            if (get_var("BOOT_TO_SNAPSHOT") && (snapper_is_applicable())) {
                loadtest "boot/grub_test_snapshot";
                if (get_var("UPGRADE")) {
                    loadtest "boot/snapper_rollback";
                }
                if (get_var("MIGRATION_ROLLBACK")) {
                    loadtest "online_migration/sle12_online_migration/snapper_rollback";
                }
            }
            else {
                loadtest "boot/boot_to_desktop";
            }
            if (get_var("ADDONS")) {
                loadtest "installation/addon_products_yast2";
            }
            if (get_var("ISCSI_SERVER")) {
                set_var('INSTALLONLY', 1);
                loadtest "iscsi/iscsi_server";
            }
            if (get_var("ISCSI_CLIENT")) {
                set_var('INSTALLONLY', 1);
                loadtest "iscsi/iscsi_client";
            }
            if (get_var("NIS_SERVER")) {
                set_var('INSTALLONLY', 1);
                loadtest "x11/nis_server";
            }
            if (get_var("NIS_CLIENT")) {
                set_var('INSTALLONLY', 1);
                loadtest "x11/nis_client";
            }
            if (get_var("REMOTE_CONTROLLER")) {
                loadtest "remote/remote_controller";
                load_inst_tests();
            }
        }
    }
    elsif (get_var("REMOTE_TARGET")) {
        load_boot_tests();
        loadtest "remote/remote_target";
        load_reboot_tests();
    }
    elsif (is_jeos) {
        load_boot_tests();
        loadtest "jeos/firstrun";
        loadtest "jeos/grub2_gfxmode";
        if (check_var('BACKEND', 'svirt')) {
            loadtest "installation/redefine_svirt_domain";
        }
        loadtest "jeos/diskusage";
        loadtest "jeos/root_fs_size";
        loadtest "jeos/mount_by_label";
        if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE")) {
            loadtest "jeos/sccreg";
        }
    }
    else {
        if (get_var('BOOT_EXISTING_S390')) {
            loadtest 'installation/boot_s390';
            loadtest 'installation/reconnect_s390';
            loadtest 'installation/first_boot';
        }
        else {
            load_boot_tests();
            load_inst_tests();
            load_reboot_tests();
        }
    }
    unless (load_applicationstests() || load_slenkins_tests()) {
        load_rescuecd_tests();
        load_consoletests();
        load_x11tests();
    }
}

if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) {
    if (get_var("INSTALLONLY")) {
        loadtest "console/hostname";
        loadtest "shutdown/grub_set_bootargs";
        loadtest "shutdown/shutdown";
        if (check_var("BACKEND", "svirt")) {
            loadtest "shutdown/svirt_upload_assets";
        }
    }
}

if (get_var("TCM") || check_var("ADDONS", "tcm")) {
    loadtest "toolchain/install";
    loadtest "toolchain/gcc5_fortran_compilation";
    loadtest "toolchain/gcc5_C_compilation";
    loadtest "toolchain/gcc5_Cpp_compilation";
    # kdump is not supported on aarch64, see BSC#990418
    if (!check_var('ARCH', 'aarch64')) {
        loadtest "toolchain/crash";
    }
}

if (check_var("HPC", "basic")) {
    loadtest "hpc/install";
    loadtest "hpc/cpuid";
    loadtest "hpc/rasdaemon";
}

if (check_var("HPC", "master")) {
    loadtest "hpc/masterinstall";
}
1;
# vim: set sw=4 et:
