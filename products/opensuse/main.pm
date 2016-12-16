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
use testapi qw(check_var get_var set_var);
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

sub is_tumbleweed {
    # Tumbleweed and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if check_var('VERSION', 'Tumbleweed');
    return get_var('VERSION') =~ /^Staging:/;
}

sub is_leap {
    # Leap and its stagings
    return 0 unless check_var('DISTRI', 'opensuse');
    return 1 if get_var('VERSION', '') =~ /(?:[4-9][0-9]|[0-9]{3,})\.[0-9]/;
    return get_var('VERSION') =~ /^42:S/;
}

sub is_krypton_argon {
    return get_var('FLAVOR') =~ /(Krypton|Argon)/;
}

sub cleanup_needles() {
    remove_common_needles;
    if (!get_var("LIVECD")) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if (!check_var("DE_PATTERN", "mate")) {
        remove_desktop_needles("mate");
    }
    if (!check_var("DE_PATTERN", "lxqt")) {
        remove_desktop_needles("lxqt");
    }
    if (!check_var("DE_PATTERN", "enlightenment")) {
        remove_desktop_needles("enlightenment");
    }
    if (!check_var("DE_PATTERN", "awesome")) {
        remove_desktop_needles("awesome");
    }
    if (!is_jeos) {
        unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
    }
    if (!is_leap) {
        unregister_needle_tags('ENV-LEAP-1');
    }
    if (!is_tumbleweed) {
        unregister_needle_tags('ENV-VERSION-Tumbleweed');
    }
    for my $flavor (qw(Krypton-Live Argon-Live)) {
        if (!check_var('FLAVOR', $flavor)) {
            unregister_needle_tags("ENV-FLAVOR-$flavor");
        }
    }
    # unregister christmas needles unless it is December where they should
    # appear. Unused needles should be disregarded by admin delete then
    unregister_needle_tags('CHRISTMAS') unless get_var('WINTER_IS_THERE');
}

# we need some special handling for the openSUSE winter needles
my @time = localtime();
set_var('WINTER_IS_THERE', 1) if ($time[4] == 11 || $time[4] == 0);

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

unless (get_var("DESKTOP")) {
    if (check_var("VIDEOMODE", "text")) {
        set_var("DESKTOP", "textmode");
    }
    else {
        set_var("DESKTOP", "kde");
    }
}

if (check_var('DESKTOP', 'minimalx')) {
    set_var("NOAUTOLOGIN", 1);
    set_var("XDMUSED",     1);
}

# openSUSE specific variables
set_var('LEAP', '1') if is_leap;
set_var("PACKAGETOINSTALL", 'xdelta');
set_var("WALLPAPER",        '/usr/share/wallpapers/openSUSEdefault/contents/images/1280x1024.jpg');

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# for GNOME pressing enter is enough to login bernhard
if (check_var('DESKTOP', 'minimalx')) {
    set_var('DM_NEEDS_USERNAME', 1);
}

# now Plasma 5 is default KDE desktop
# openSUSE version less than or equal to 13.2 have to set KDE4 variable as 1
if (check_var('DESKTOP', 'kde') && !get_var('KDE4')) {
    set_var("PLASMA5", 1);
}

# ZDUP_IN_X imply ZDUP
if (get_var('ZDUP_IN_X')) {
    set_var('ZDUP', 1);
}

if (   get_var("WITH_UPDATE_REPO")
    || get_var("WITH_MAIN_REPO")
    || get_var("WITH_DEBUG_REPO")
    || get_var("WITH_SOURCE_REPO")
    || get_var("WITH_UNTESTED_REPO"))
{
    set_var('HAVE_ADDON_REPOS', 1);
}

$needle::cleanuphandler = \&cleanup_needles;

# dump other important ENV:
logcurrentenv(
    qw(ADDONURL BTRFS DESKTOP HW HWSLOT LIVETEST LVM
      MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT ZDUP
      ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL
      ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE
      LIVECD NETBOOT NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE)
);

sub is_server() {
    return (check_var('ARCH', 'aarch64') || get_var("OFW") || check_var("FLAVOR", "Server-DVD"));
}

sub is_livesystem() {
    return (check_var("FLAVOR", 'Rescue-CD') || get_var("LIVETEST"));
}

sub xfcestep_is_applicable() {
    return check_var("DESKTOP", "xfce");
}

sub installwithaddonrepos_is_applicable() {
    return get_var("HAVE_ADDON_REPOS") && !get_var("UPGRADE") && !get_var("NET");
}

sub guiupdates_is_applicable() {
    return get_var("DESKTOP") =~ /gnome|kde|xfce|lxde/ && !check_var("FLAVOR", "Rescue-CD");
}

sub lxdestep_is_applicable() {
    return check_var("DESKTOP", "lxde");
}

sub any_desktop_is_applicable() {
    return get_var("DESKTOP") !~ /textmode/;
}

sub console_is_applicable() {
    return !any_desktop_is_applicable();
}

sub need_clear_repos() {
    return is_staging();
}

sub have_addn_repos() {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !is_staging();
}

sub load_x11regresion_tests() {
    if ((check_var("DESKTOP", "gnome"))) {
        loadtest "x11regressions/tomboy/tomboy_Hotkeys";
        loadtest "x11regressions/tomboy/tomboy_AlreadyRunning";
        loadtest "x11regressions/tomboy/tomboy_TestFindFunctionalityInSearchAllNotes";
        loadtest "x11regressions/tomboy/tomboy_TestUndoRedoFeature";
        loadtest "x11regressions/tomboy/tomboy_firstrun";
        loadtest "x11regressions/tomboy/tomboy_StartNoteCannotBeDeleted";
        loadtest "x11regressions/tomboy/tomboy_Open";
        loadtest "x11regressions/tomboy/tomboy_Print";
        loadtest "x11regressions/tomboy/tomboy_checkinstall";
        loadtest "x11regressions/gnomecase/Gnomecutfile";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/pidgin/pidgin_IRC";
        loadtest "x11regressions/pidgin/pidgin_googletalk";
        loadtest "x11regressions/pidgin/pidgin_aim";
        loadtest "x11regressions/pidgin/prep_pidgin";
        loadtest "x11regressions/pidgin/pidgin_msn";
        loadtest "x11regressions/pidgin/clean_pidgin";
        loadtest "x11regressions/tracker/prep_tracker";
        loadtest "x11regressions/tracker/tracker_starts";
        loadtest "x11regressions/tracker/tracker_searchall";
        loadtest "x11regressions/tracker/tracker_pref_starts";
        loadtest "x11regressions/tracker/tracker_open_apps";
        loadtest "x11regressions/tracker/tracker_by_command";
        loadtest "x11regressions/tracker/tracker_search_in_nautilus";
        loadtest "x11regressions/tracker/clean_tracker";
        loadtest "x11regressions/tracker/tracker_info";
    }
}

sub load_boot_tests() {
    if (get_var("ISO_MAXSIZE")) {
        loadtest "installation/isosize";
    }
    if (get_var("OFW")) {
        loadtest "installation/bootloader_ofw";
    }
    elsif (get_var("UEFI") || is_jeos) {
        # TODO: rename to bootloader_grub2
        loadtest "installation/bootloader_uefi";
    }
    elsif (get_var("IPMI_HOSTNAME")) {    # abuse of variable for now
        loadtest "installation/qa_net";
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

sub load_inst_tests() {
    loadtest "installation/welcome";
    if (get_var("MULTIPATH")) {
        loadtest "installation/multipath";
    }
    loadtest "installation/good_buttons";
    if (get_var('ENCRYPT_CANCEL_EXISTING') || get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        loadtest "installation/encrypted_volume_activation";
    }
    if (noupdatestep_is_applicable() && !get_var("LIVECD")) {
        loadtest "installation/installation_mode";
    }
    if (!get_var("LIVECD") && get_var("UPGRADE")) {
        loadtest "installation/upgrade_select";
        if (check_var("UPGRADE", "LOW_SPACE")) {
            loadtest "installation/disk_space_fill";
        }
        loadtest "installation/upgrade_select_opensuse";
    }
    if (noupdatestep_is_applicable() && get_var("LIVECD")) {
        loadtest "installation/livecd_network_settings";
    }
    if (noupdatestep_is_applicable()) {
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
        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr";
        }
        loadtest "installation/partitioning_finish";
        loadtest "installation/installer_timezone";
    }
    if (installwithaddonrepos_is_applicable() && !get_var("LIVECD")) {
        loadtest "installation/setup_online_repos";
    }
    if (!get_var("LIVECD") && get_var("ADDONURL")) {
        loadtest "installation/addon_products";
    }
    if (noupdatestep_is_applicable() && !get_var("LIVECD") && !get_var("REMOTE_CONTROLLER")) {
        loadtest "installation/logpackages";
    }
    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_desktopselection";
        if (get_var('IMPORT_USER_DATA')) {
            loadtest 'installation/user_import';
        }
        else {
            loadtest "installation/user_settings";
        }
        if (get_var("DOCRUN") || get_var("IMPORT_USER_DATA")) {    # root user
            loadtest "installation/user_settings_root";
        }
    }
    if (noupdatestep_is_applicable()) {
        if (get_var('PATTERNS')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns";
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
}

sub load_reboot_tests() {
    if (installyaststep_is_applicable()) {
        loadtest "installation/grub_test";
        if (get_var('ENCRYPT')) {
            loadtest "installation/boot_encrypt";
        }
        if ((snapper_is_applicable()) && get_var("BOOT_TO_SNAPSHOT")) {
            loadtest "installation/boot_into_snapshot";
            if (get_var("UPGRADE")) {
                loadtest "installation/snapper_rollback";
            }
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

sub load_fixup_network() {
    # openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
    # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks with virtio-net
    # At this point, the system has been updated, but our network interface changed name (thus we lost network connection)
    my @old_hdds = qw(openSUSE-12.1 openSUSE-12.2 openSUSE-12.3 openSUSE-13.1-gnome openSUSE-13.2);
    return unless grep { check_var('HDDVERSION', $_) } @old_hdds;

    loadtest "fixup/network_configuration";

}

sub load_fixup_firewall() {
    # The openSUSE 13.1 GNOME disk image has the firewall disabled
    # Upon upgrading to a new system the service state is supposed to remain as pre-configured
    # If the service is disabled here, we enable it here
    return unless check_var('HDDVERSION', 'openSUSE-13.1-gnome');
    loadtest 'fixup/enable_firewall';
}

sub load_consoletests() {
    if (consolestep_is_applicable()) {
        loadtest "console/consoletest_setup";
        loadtest "console/check_console_font";
        loadtest "console/textinfo";
        loadtest "console/hostname";
        if (snapper_is_applicable()) {
            if (get_var("UPGRADE")) {
                loadtest "console/upgrade_snapshots";
            }
            else {
                loadtest "console/installation_snapshots";
            }
        }
        if (get_var("DESKTOP") !~ /textmode/) {
            loadtest "console/xorg_vt";
        }
        loadtest "console/zypper_lr";
        if (have_addn_repos) {
            loadtest "console/zypper_ar";
        }
        loadtest "console/zypper_ref";
        loadtest "console/yast2_lan";
        # no local certificate store
        if (!is_krypton_argon) {
            loadtest "console/curl_https";
        }
        if (   check_var('ARCH', 'x86_64')
            || check_var('ARCH', 'i686')
            || check_var('ARCH', 'i586'))
        {
            loadtest "console/glibc_i686";
        }
        loadtest "console/zypper_in";
        loadtest "console/yast2_i";
        if (!get_var("LIVETEST")) {
            loadtest "console/yast2_bootloader";
        }
        loadtest "console/vim";
        # textmode install comes without firewall by default atm
        if (!check_var("DESKTOP", "textmode") && !is_staging() && !is_krypton_argon) {
            loadtest "console/firewall_enabled";
        }
        if (is_jeos) {
            loadtest "console/gpt_ptable";
            loadtest "console/kdump_disabled";
            loadtest "console/sshd_running";
        }
        loadtest "console/sshd";
        loadtest "console/ssh_cleanup";
        if (!get_var("LIVETEST") && !is_staging()) {
            # in live we don't have a password for root so ssh doesn't
            # work anyways, and except staging_core image, the rest of
            # staging_* images don't need run this test case
            loadtest "console/sshfs";
        }
        loadtest "console/mtab";
        if (!get_var("NOINSTALL") && !get_var("LIVETEST") && (check_var("DESKTOP", "textmode"))) {
            if (check_var('BACKEND', 'qemu')) {
                # The NFS test expects the IP to be 10.0.2.15
                loadtest "console/yast2_nfs_server";
            }
            loadtest "console/http_srv";
            loadtest "console/mysql_srv";
            loadtest "console/dns_srv";
            if (check_var('ARCH', 'x86_64')) {
                loadtest "console/docker";
            }
        }
        if (get_var("MOZILLATEST")) {
            loadtest "console/mozmill_setup";
        }
        if (check_var("DESKTOP", "xfce")) {
            loadtest "console/xfce_gnome_deps";
        }
        loadtest "console/consoletest_finish";
    }
    elsif (is_staging() && get_var('UEFI')) {
        # Stagings should test yast2-bootloader in miniuefi at least but not all
        loadtest "console/consoletest_setup";
        loadtest "console/check_console_font";
        loadtest "console/textinfo";
        loadtest "console/hostname";
        if (!get_var("LIVETEST")) {
            loadtest "console/yast2_bootloader";
        }
        loadtest "console/consoletest_finish";
    }

}

sub load_yast2_gui_tests() {
    loadtest "yast2_gui/yast2_control_center";
    loadtest "yast2_gui/yast2_bootloader";
    loadtest "yast2_gui/yast2_datetime";
    loadtest "yast2_gui/yast2_firewall";
    loadtest "yast2_gui/yast2_hostnames";
    loadtest "yast2_gui/yast2_lang";
    loadtest "yast2_gui/yast2_network_settings";
    if (snapper_is_applicable()) {
        loadtest "yast2_gui/yast2_snapper";
    }
    loadtest "yast2_gui/yast2_software_management";
    loadtest "yast2_gui/yast2_users";
}

sub load_extra_tests() {

    return unless get_var('EXTRATEST') || get_var('Y2UITEST');
    # pre-conditions for extra tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";

    if (console_is_applicable() && get_var("EXTRATEST")) {
        # Put tests that filled the conditions below
        # 1) you don't want to run in stagings below here
        # 2) the application is not rely on desktop environment
        # 3) running based on preinstalled image

        loadtest "console/check_console_font";
        loadtest "console/zypper_lr";
        loadtest "console/zypper_ar";
        loadtest "console/zypper_ref";
        loadtest "console/update_alternatives";
        loadtest "console/zbar";
        # start extra console tests from here
        if (!get_var("OFW") && !is_jeos) {
            loadtest "console/aplay";
        }
        if (get_var("FILESYSTEM", "btrfs") eq "btrfs") {
            loadtest "console/btrfs_autocompletion";
            if (get_var("NUMDISKS", 0) > 1) {
                loadtest "console/btrfs_qgroups";
                loadtest "console/btrfs_send_receive";
            }
        }
        loadtest "console/a2ps";    # a2ps is not a ring package and thus not available in staging

        if (get_var("SYSAUTHTEST")) {
            # sysauth test scenarios run in the console
            loadtest "sysauth/sssd";
        }
        loadtest "console/command_not_found";
        loadtest "console/openvswitch";
        loadtest "console/rabbitmq";
        loadtest "console/salt";
        loadtest "console/rails";
        loadtest "console/machinery";
        loadtest "console/pcre";
        # dependency of git test
        loadtest "console/sshd";
        loadtest "console/git";
        loadtest "console/java";
        loadtest "console/curl_ipv6";
        loadtest "console/wget_ipv6";

        # finished console test and back to desktop
        loadtest "console/consoletest_finish";

        # kdump is not supported on aarch64, see BSC#990418
        if (!check_var('ARCH', 'aarch64')) {
            loadtest "toolchain/crash";
        }

        return 1;
    }
    elsif (any_desktop_is_applicable() && get_var("Y2UITEST")) {
        loadtest "console/zypper_lr";
        loadtest "console/zypper_ref";
        # start extra yast console test from here
        loadtest "console/yast2_proxy";
        loadtest "console/yast2_ntpclient";
        loadtest "console/yast2_tftp";
        loadtest "console/yast2_vnc";
        loadtest "console/yast2_samba";
        loadtest "console/yast2_xinetd";
        loadtest "console/yast2_apparmor";
        loadtest "console/yast2_http";
        loadtest "console/yast2_ftp";
        # yast-lan related tests do not work when using networkmanager.
        # (Livesystem and laptops do use networkmanager)
        if (!get_var("LIVETEST") && !get_var("LAPTOP")) {
            loadtest "console/yast2_cmdline";
            loadtest "console/yast2_dns_server";
            loadtest "console/yast2_nfs_client";
        }
        # back to desktop
        loadtest "console/consoletest_finish";
        load_yast2_gui_tests();

        return 1;
    }
    elsif (any_desktop_is_applicable() && get_var("EXTRATEST")) {
        if (!get_var("NOAUTOLOGIN")) {
            loadtest "x11/multi_users_dm";
        }
        if (gnomestep_is_applicable() && check_var('VERSION', '42.2')) {
            # 42.2 feature - not even on Tumbleweed
            loadtest "x11/gdm_session_switch";
        }
        if (gnomestep_is_applicable()) {
            loadtest "x11/seahorse";
        }
        return 1;
    }


    return 0;
}

sub load_otherDE_tests() {
    if (get_var("DE_PATTERN")) {
        my $de = get_var("DE_PATTERN");
        loadtest "console/consoletest_setup";
        loadtest "console/hostname";
        loadtest "update/zypper_clear_repos";
        loadtest "console/install_otherDE_pattern";
        loadtest "console/consoletest_finish";
        loadtest "x11/${de}_reconfigure_openqa";
        loadtest "x11/reboot_icewm";
        # here comes the actual desktop specific test
        if ($de =~ /^awesome$/)       { load_awesome_tests(); }
        if ($de =~ /^enlightenment$/) { load_enlightenment_tests(); }
        if ($de =~ /^mate$/)          { load_mate_tests(); }
        if ($de =~ /^lxqt$/)          { load_lxqt_tests(); }
        loadtest "x11/shutdown";
        return 1;
    }
    return 0;
}

sub load_awesome_tests() {
    loadtest "x11/awesome_menu";
    loadtest "x11/awesome_xterm";
}

sub load_enlightenment_tests() {
    loadtest "x11/enlightenment_first_start";
    loadtest "x11/terminology";
}

sub load_lxqt_tests() {
}

sub load_mate_tests() {
    loadtest "x11/mate_terminal";
}

sub load_x11tests() {
    return unless (!get_var("INSTALLONLY") && is_desktop_installed() && !get_var("DUALBOOT") && !get_var("RESCUECD"));

    if (get_var("XDMUSED")) {
        loadtest "x11/x11_login";
    }
    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_terminal";
    }
    loadtest "x11/xterm";
    loadtest "x11/sshxterm" unless get_var("LIVETEST");
    if (gnomestep_is_applicable()) {
        loadtest "x11/gnome_control_center";
        loadtest "x11/gnome_tweak_tool";
        loadtest "x11/gnome_terminal";
        loadtest "x11/gedit";
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/kate";
    }
    loadtest "x11/firefox";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio";
    }
    if (gnomestep_is_applicable() && !(get_var("LIVECD") || is_server)) {
        loadtest "x11/thunderbird";
    }
    if (get_var("MOZILLATEST")) {
        loadtest "x11/mozmill_run";
    }
    if (chromiumstep_is_applicable() && !(is_staging() || is_livesystem)) {
        loadtest "x11/chromium";
    }
    if (xfcestep_is_applicable()) {
        loadtest "x11/ristretto";
    }
    if (gnomestep_is_applicable()) {
        loadtest "x11/eog";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/ && !get_var("LIVECD") && !is_server) {
        loadtest "x11/oomath";
        loadtest "x11/oocalc";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/ && !is_server && !is_krypton_argon) {
        loadtest "x11/ooffice";
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/khelpcenter";
        if (get_var("PLASMA5")) {
            loadtest "x11/systemsettings5";
        }
        else {
            loadtest "x11/systemsettings";
        }
        loadtest "x11/dolphin";
    }
    if (snapper_is_applicable()) {
        loadtest "x11/yast2_snapper";
    }
    if (gnomestep_is_applicable() && get_var("GNOME2")) {
        loadtest "x11/application_browser";
    }
    if (xfcestep_is_applicable()) {
        loadtest "x11/thunar";
        if (!get_var("USBBOOT")) {
            loadtest "x11/reboot_xfce";
        }
    }
    if (lxdestep_is_applicable()) {
        if (!get_var("USBBOOT")) {
            loadtest "x11/reboot_lxde";
        }
    }
    loadtest "x11/glxgears" unless is_staging();
    if (kdestep_is_applicable()) {
        if (!is_krypton_argon) {
            loadtest "x11/amarok";
        }
        loadtest "x11/kontact";
        if (!get_var("USBBOOT")) {
            if (get_var("PLASMA5")) {
                loadtest "x11/reboot_plasma5";
            }
            else {
                loadtest "x11/reboot_kde";
            }
        }
    }
    if (gnomestep_is_applicable()) {
        loadtest "x11/nautilus" unless get_var("LIVECD");
        loadtest "x11/gnome_music";
        loadtest "x11/evolution" unless is_server;
        if (!get_var("USBBOOT")) {
            loadtest "x11/reboot_gnome";
        }
    }
    loadtest "x11/desktop_mainmenu";

    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_appfinder";
        if (!(get_var("FLAVOR") eq 'Rescue-CD')) {
            loadtest "x11/xfce_lightdm_logout_login";
        }
    }

    unless (get_var("LIVECD")) {
        loadtest "x11/inkscape";
        loadtest "x11/gimp";
    }
    if (   !is_staging()
        && !is_livesystem)
    {
        loadtest "x11/gnucash";
        loadtest "x11/hexchat";
        loadtest "x11/vlc";
        # chrome pulls in lsb which creates /media (bug#915562),
        # which in turn breaks the thunar test as then suddenly the
        # content of / looks different depending on whether the
        # chrome test succeeded or not. So let's put that kind of
        # tests at the end.
        if (chromestep_is_applicable()) {
            loadtest "x11/chrome";
        }
    }

    loadtest "x11/shutdown";
}

sub install_online_updates {
    return 0 unless get_var('INSTALL_ONLINE_UPDATES');

    my @tests = qw(
      console/zypper_disable_deltarpm
      console/zypper_add_repos
      update/zypper_up
      console/console_reboot
      console/console_shutdown
    );

    for my $test (@tests) {
        loadtest "$test";
    }

    return 1;
}

sub load_system_update_tests {
    # we don't want live systems to run out of memory or virtual disk space.
    # Applying updates on a live system would not be persistent anyway
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("UPGRADE") || is_livesystem;

    if (need_clear_repos) {
        loadtest "update/zypper_clear_repos";
    }

    if (guiupdates_is_applicable()) {
        loadtest "update/prepare_system_for_update_tests";
        if (check_var("DESKTOP", "kde")) {
            loadtest "update/updates_packagekit_kde";
        }
        else {
            loadtest "update/updates_packagekit_gpk";
        }
        loadtest "update/check_system_is_updated";
    }
    else {
        loadtest "update/zypper_up";
    }
}

sub load_applicationstests {
    return 0 unless get_var("APPTESTS");

    my @tests;

    my %testsuites = (
        chromium           => ['x11/chromium'],
        evolution          => ['x11/evolution'],
        gimp               => ['x11/gimp'],
        hexchat            => ['x11/hexchat'],
        libzypp            => ['console/zypper_in', 'console/yast2_i'],
        MozillaFirefox     => [qw(x11/firefox x11/firefox_audio)],
        MozillaThunderbird => ['x11/thunderbird'],
        vlc                => ['x11/vlc'],
        xchat              => ['x11/xchat'],
        xterm              => ['x11/xterm'],
    );

    # adjust $pos below if you modify the position of
    # consoletest_finish!
    if (get_var('BOOT_HDD_IMAGE')) {
        @tests = (
            'console/consoletest_setup',
            'console/check_console_font',
            'console/import_gpg_keys',
            'update/zypper_up',
            'console/install_packages',
            'console/zypper_add_repos',
            'console/qam_zypper_patch',
            'console/qam_verify_package_install',
            'console/console_reboot',
            # position -2
            'console/consoletest_finish',
            # position -1
            'x11/shutdown'
        );
    }
    else {
        @tests = (
            'console/consoletest_setup',
            'update/zypper_up',
            'console/qam_verify_package_install',
            # position -2
            'console/consoletest_finish',
            # position -1
            'x11/shutdown'
        );
    }

    if (my $val = get_var("INSTALL_PACKAGES", '')) {
        for my $pkg (split(/ /, $val)) {
            next unless exists $testsuites{$pkg};
            # yeah, pretty crappy method. insert
            # consoletests before consoletest_finish and x11
            # tests before shutdown
            for my $t (@{$testsuites{$pkg}}) {
                my $pos = -1;
                $pos = -2 if ($t =~ /^console\//);
                splice @tests, $pos, 0, $t;
            }
        }
    }

    for my $test (@tests) {
        loadtest "$test";
    }

    return 1;
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
    loadtest "installation/mediacheck";
}
elsif (get_var("MEMTEST")) {
    loadtest "installation/memtest";
}
elsif (get_var("RESCUESYSTEM")) {
    loadtest "installation/rescuesystem";
    loadtest "installation/rescuesystem_validate_131";
}
elsif (get_var("LINUXRC")) {
    loadtest "linuxrc/system_boot";
}
elsif (get_var("SUPPORT_SERVER")) {
    loadtest "support_server/boot";
    loadtest "support_server/login";
    loadtest "support_server/setup";
    unless (load_slenkins_tests()) {    # either run the slenkins control node or just wait for connections
        loadtest "support_server/wait";
    }
}
elsif (get_var("WINDOWS")) {
    loadtest "installation/win10_installation";
    loadtest "installation/win10_firstboot";
    loadtest "installation/win10_reboot";
    loadtest "installation/win10_shutdown";
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
elsif (get_var('INSTALL_LTP')) {
    loadtest 'kernel/install_ltp';
    loadtest 'kernel/boot_ltp';
    loadtest 'kernel/shutdown_ltp';
}
elsif (get_var('LTP_SETUP_NETWORKING')) {
    loadtest 'kernel/boot_ltp';
    loadtest 'kernel/ltp_setup_networking';
    loadtest 'kernel/shutdown_ltp';
}
elsif (get_var('LTP_COMMAND_FILE')) {
    loadtest 'kernel/boot_ltp';
    if (get_var('LTP_COMMAND_FILE') =~ m/ltp-aiodio.part[134]/) {
        loadtest 'kernel/create_junkfile_ltp';
    }
    loadtest 'kernel/run_ltp';
}
elsif (get_var('VIRTIO_CONSOLE_TEST')) {
    loadtest 'kernel/virtio_console';
}
else {
    if (get_var("LIVETEST") || get_var('LIVE_INSTALLATION')) {
        load_boot_tests();
        loadtest "installation/finish_desktop";
        if (get_var('LIVE_INSTALLATION')) {
            loadtest "installation/live_installation";
            load_inst_tests();
            load_reboot_tests();
            return 1;
        }
    }
    elsif (get_var("AUTOYAST")) {
        load_boot_tests();
        load_autoyast_tests();
        load_reboot_tests();
    }
    elsif (installzdupstep_is_applicable()) {
        load_boot_tests();
        load_zdup_tests();
    }
    elsif (get_var("BOOT_HDD_IMAGE")) {
        if (get_var('UEFI') && get_var('BOOTFROM')) {
            loadtest "boot/uefi_bootmenu";
        }
        loadtest "boot/boot_to_desktop";
        if (get_var("ISCSI_SERVER")) {
            set_var('INSTALLONLY', 1);
            loadtest "iscsi/iscsi_server";
        }
        if (get_var("ISCSI_CLIENT")) {
            set_var('INSTALLONLY', 1);
            loadtest "iscsi/iscsi_client";
        }
        if (get_var("REMOTE_CONTROLLER")) {
            loadtest "remote/remote_controller";
            load_inst_tests();
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
        loadtest "jeos/diskusage";
        loadtest "jeos/root_fs_size";
        loadtest "jeos/mount_by_label";
        if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE")) {
            loadtest "jeos/sccreg";
        }
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }

    unless (install_online_updates()
        || load_applicationstests()
        || load_extra_tests()
        || load_otherDE_tests()
        || load_slenkins_tests())
    {
        load_fixup_network();
        load_fixup_firewall();
        load_system_update_tests();
        load_rescuecd_tests();
        load_consoletests();
        load_x11tests();
    }
}

if (get_var("CLONE_SYSTEM")) {
    load_autoyast_clone_tests;
}

if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) {
    if (get_var("INSTALLONLY")) {
        loadtest "shutdown/grub_set_bootargs";
        loadtest "shutdown/shutdown";
    }
}

1;
# vim: set sw=4 et:
