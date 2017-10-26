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
use testapi qw(check_var get_var get_required_var set_var);
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

sub cleanup_needles {
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

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
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
set_var("WALLPAPER", '/usr/share/wallpapers/openSUSEdefault/contents/images/1280x1024.jpg');

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
    qw(ADDONURL BTRFS DESKTOP LIVETEST LVM
      MOZILLATEST NOINSTALL UPGRADE USBBOOT ZDUP
      ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL
      ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE
      LIVECD NETBOOT NOIMAGES QEMUVGA SPLITUSR VIDEOMODE)
);

sub is_server {
    return (check_var('ARCH', 'aarch64') || get_var("OFW") || check_var("FLAVOR", "Server-DVD"));
}

sub is_livesystem {
    return (check_var("FLAVOR", 'Rescue-CD') || get_var("LIVETEST"));
}

sub xfcestep_is_applicable {
    return check_var("DESKTOP", "xfce");
}

sub installwithaddonrepos_is_applicable {
    return get_var("HAVE_ADDON_REPOS") && !get_var("UPGRADE") && !get_var("NET");
}

sub updates_is_applicable {
    # we don't want live systems to run out of memory or virtual disk space.
    # Applying updates on a live system would not be persistent anyway.
    # Also, applying updates on BOOT_TO_SNAPSHOT is useless.
    # Also, updates on INSTALLONLY do not match the meaning
    return !get_var('INSTALLONLY') && !get_var('BOOT_TO_SNAPSHOT') && !get_var('DUALBOOT') && !get_var('UPGRADE') && !is_livesystem;
}

sub guiupdates_is_applicable {
    return get_var("DESKTOP") =~ /gnome|kde|xfce|lxde/ && !check_var("FLAVOR", "Rescue-CD");
}

sub packagekit_available {
    return !check_var('FLAVOR', 'Rescue-CD') && !is_staging;
}

sub lxdestep_is_applicable {
    return check_var("DESKTOP", "lxde");
}

sub need_clear_repos {
    return is_staging();
}

sub have_addn_repos {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !is_staging();
}

sub load_boot_tests {
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
        set_var("DELAYED_START", "1");
        loadtest "autoyast/pxe_boot";
    }
    elsif (check_var('ARCH', 's390x')) {
        loadtest "installation/bootloader_s390";
    }
    else {
        loadtest "installation/bootloader";
    }
}

sub load_inst_tests {
    loadtest "installation/welcome";
    if (check_var('ARCH', 's390x')) {
        loadtest "installation/disk_activation";
    }
    if (get_var("MULTIPATH")) {
        loadtest "installation/multipath";
    }
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
    if (noupdatestep_is_applicable()) {
        # Krypton/Argon disable the network configuration stage
        if (get_var("LIVECD") && !is_krypton_argon) {
            loadtest "installation/livecd_network_settings";
        }
        loadtest "installation/partitioning";
        if (get_var("ISO_IN_EXTERNAL_DRIVE")) {
            loadtest "installation/partitioning_firstdisk";
        }
        if (defined(get_var("RAIDLEVEL"))) {
            loadtest "installation/partitioning_raid";
        }
        elsif (get_var("LVM")) {
            loadtest "installation/partitioning_lvm";
        }
        if (get_var("FILESYSTEM")) {
            if (get_var('PARTITIONING_WARNINGS')) {
                loadtest 'installation/partitioning_warnings';
            }
            loadtest "installation/partitioning_filesystem";
        }
        if (get_var("TOGGLEHOME")) {
            loadtest "installation/partitioning_togglehome";
            if (get_var('LVM') && get_var('RESIZE_ROOT_VOLUME')) {
                loadtest "installation/partitioning_resize_root";
            }
        }
        if (get_var("EXPERTPARTITIONER")) {
            loadtest "installation/partitioning_expert";
        }
        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr";
        }
        if (get_var("DELETEWINDOWS")) {
            loadtest "installation/partitioning_guided";
        }
        loadtest "installation/partitioning_finish";
        loadtest "installation/installer_timezone";
    }
    if (installwithaddonrepos_is_applicable() && !get_var("LIVECD")) {
        loadtest "installation/setup_online_repos";
    }
    if (addon_products_is_applicable() && !leap_version_at_least('42.3')) {
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
        if (get_var("DOCRUN") || get_var("IMPORT_USER_DATA") || get_var("ROOTONLY")) {    # root user
            loadtest "installation/user_settings_root";
        }
    }
    if (noupdatestep_is_applicable()) {
        if (get_var('PATTERNS') || get_var('PACKAGES')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns_and_packages";
        }
        # breaks leap 15 https://progress.opensuse.org/issues/26936
        #loadtest "installation/disable_grub_timeout";
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
    return 1 if get_var('EXIT_AFTER_START_INSTALL');
    loadtest "installation/install_and_reboot";
}

sub load_reboot_tests {
    if (check_var('ARCH', 's390x')) {
        loadtest "installation/reconnect_s390";
    }
    if (installyaststep_is_applicable()) {
        # s390 has no 'grub' that can be easily checked
        if (!check_var('ARCH', 's390x')) {
            loadtest "installation/grub_test";
        }
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

    if (get_var("DUALBOOT")) {
        loadtest "installation/reboot_eject_cd";
        loadtest "installation/boot_windows";
    }
}

sub load_fixup_network {
    # openSUSE 13.2's (and earlier) systemd has broken rules for virtio-net, not applying predictable names (despite being configured)
    # A maintenance update breaking networking names sounds worse than just accepting that 13.2 -> TW breaks with virtio-net
    # At this point, the system has been updated, but our network interface changed name (thus we lost network connection)
    my @old_hdds = qw(openSUSE-12.1 openSUSE-12.2 openSUSE-12.3 openSUSE-13.1-gnome openSUSE-13.2);
    return unless grep { check_var('HDDVERSION', $_) } @old_hdds;

    loadtest "fixup/network_configuration";

}

sub load_fixup_firewall {
    # The openSUSE 13.1 GNOME disk image has the firewall disabled
    # Upon upgrading to a new system the service state is supposed to remain as pre-configured
    # If the service is disabled here, we enable it here
    # For the older openSUSE base images we also see a problem with the
    # firewall being disabled since
    # https://build.opensuse.org/request/show/483163
    # which seems to be in openSUSE Tumbleweed since 20170413
    return unless get_var('HDDVERSION', '') =~ /openSUSE-(12.1|12.2|13.1-gnome)/;
    loadtest 'fixup/enable_firewall';
}

sub load_consoletests_minimal {
    return unless (is_staging() && get_var('UEFI') || is_gnome_next || is_krypton_argon);
    # Stagings should test yast2-bootloader in miniuefi at least but not all
    loadtest "console/consoletest_setup";
    loadtest "console/textinfo";
    loadtest "console/hostname";
    if (!get_var("LIVETEST")) {
        loadtest "console/yast2_bootloader";
    }
    loadtest "console/consoletest_finish";
}

sub load_consoletests {
    return unless consolestep_is_applicable();
    loadtest "console/consoletest_setup";
    loadtest "console/force_cron_run" if !is_jeos;
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/check_locked_package";
    }
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
    loadtest 'console/enable_usb_repo' if check_var('USBBOOT', 1);
    if (have_addn_repos) {
        loadtest "console/zypper_ar";
    }
    loadtest "console/zypper_ref";
    loadtest "console/ncurses";
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
    if (!get_var("LIVETEST") && !is_staging() && !is_jeos) {
        # in live we don't have a password for root so ssh doesn't
        # work anyways, and except staging_core image, the rest of
        # staging_* images don't need run this test case
        #
        # On JeOS we don't have fuse.ko in kernel-default-base package.
        loadtest "console/sshfs";
    }
    loadtest "console/mtab";
    if (!get_var("NOINSTALL") && !get_var("LIVETEST") && (check_var("DESKTOP", "textmode"))) {
        if (check_var('BACKEND', 'qemu') && !is_jeos) {
            # The NFS test expects the IP to be 10.0.2.15
            loadtest "console/yast2_nfs_server";
        }
        loadtest "console/http_srv";
        loadtest "console/mysql_srv";
        loadtest "console/dns_srv";
        if (!is_staging) {
            if (is_leap && !leap_version_at_least('15')) {
                loadtest "console/php5";
                loadtest "console/php5_mysql";
                loadtest "console/php5_postgresql96";
            }
        }
        loadtest "console/php7";
        loadtest "console/php7_mysql";
        loadtest "console/php7_postgresql96";
    }
    if (check_var("DESKTOP", "xfce")) {
        loadtest "console/xfce_gnome_deps";
    }
    loadtest "console/consoletest_finish";
}

sub load_otherDE_tests {
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

sub load_awesome_tests {
    loadtest "x11/awesome_menu";
    loadtest "x11/awesome_xterm";
}

sub load_enlightenment_tests {
    loadtest "x11/enlightenment_first_start";
    loadtest "x11/terminology";
}

sub load_lxqt_tests {
}

sub load_mate_tests {
    loadtest "x11/mate_terminal";
}

sub load_x11tests {
    return unless (!get_var("INSTALLONLY") && is_desktop_installed() && !get_var("DUALBOOT") && !get_var("RESCUECD"));

    loadtest "x11/user_gui_login" unless get_var("LIVETEST") || get_var("NOAUTOLOGIN");
    if (get_var("XDMUSED")) {
        loadtest "x11/x11_login";
    }
    if (kdestep_is_applicable() && get_var("WAYLAND")) {
        loadtest "x11/plasma5_force_96dpi";
        loadtest "x11/start_wayland_plasma5";
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
    if (kdestep_is_applicable() && !is_kde_live) {
        loadtest "x11/kate";
    }
    # no firefox on KDE-Live # boo#1022499
    loadtest "x11/firefox" unless is_kde_live;
    if (!get_var("OFW") && check_var('BACKEND', 'qemu') && !check_var('FLAVOR', 'Rescue-CD') && !is_kde_live) {
        loadtest "x11/firefox_audio";
    }
    if (gnomestep_is_applicable() && !(get_var("LIVECD") || is_server)) {
        loadtest "x11/thunderbird";
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
    if (get_var("DESKTOP") =~ /kde|gnome/ && !is_server && !is_kde_live && !is_krypton_argon && !is_gnome_next) {
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
    if (xfcestep_is_applicable()) {
        loadtest "x11/thunar";
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_xfce";
        }
    }
    if (lxdestep_is_applicable()) {
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_lxde";
        }
    }
    loadtest "x11/glxgears" if (packagekit_available && !get_var('LIVECD'));
    if (kdestep_is_applicable()) {
        if (!is_krypton_argon && !is_kde_live) {
            loadtest "x11/amarok";
        }
        loadtest "x11/kontact" unless is_kde_live;
        if (!get_var("USBBOOT") && !is_livesystem) {
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
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_gnome";
        }
        load_testdir('x11/gnomeapps') if is_gnome_next;
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
    }
    # Need to skip shutdown to keep backend alive if running rollback tests after migration
    unless (get_var('ROLLBACK_AFTER_MIGRATION')) {
        loadtest "x11/shutdown";
    }
}

sub install_online_updates {
    return 0 unless get_var('INSTALL_ONLINE_UPDATES');

    my @tests = qw(
      console/zypper_disable_deltarpm
      console/zypper_add_repos
      update/zypper_up
      console/console_reboot
      shutdown/shutdown
    );

    for my $test (@tests) {
        loadtest "$test";
    }

    return 1;
}

sub load_system_update_tests {
    return unless updates_is_applicable;
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
        if (get_var('MM_CLIENT')) {
            @tests = split(/,/, get_var('APPTESTS'));
        }
        else {
            @tests = (
                'console/consoletest_setup',
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
if (maybe_load_kernel_tests()) {
}
elsif (get_var("WICKED")) {
    boot_hdd_image();
    load_wicked_tests();
}
elsif (get_var("REGRESSION")) {
    if (check_var("REGRESSION", "installation")) {
        set_var('NOAUTOLOGIN', 1);
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
        loadtest "x11regressions/x11regressions_setup";
        loadtest "console/hostname";
        loadtest "console/force_cron_run";
        loadtest "shutdown/grub_set_bootargs";
        loadtest "shutdown/shutdown";
    }
    elsif (check_var("REGRESSION", "documentation")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_documentation();
    }
    elsif (check_var("REGRESSION", "gnome")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_gnome();
    }
    elsif (check_var("REGRESSION", "other")) {
        loadtest "boot/boot_to_desktop";
        load_x11regression_other();
    }
}
elsif (get_var("MEDIACHECK")) {
    loadtest "installation/mediacheck";
}
elsif (get_var("MEMTEST")) {
    loadtest "installation/memtest";
}
elsif (get_var("FILESYSTEM_TEST")) {
    boot_hdd_image;
    load_filesystem_tests();
}
elsif (get_var('GNUHEALTH')) {
    boot_hdd_image;
    loadtest 'gnuhealth/gnuhealth_install';
    loadtest 'gnuhealth/gnuhealth_setup';
    loadtest 'gnuhealth/tryton_install';
    loadtest 'gnuhealth/tryton_preconfigure';
    loadtest 'gnuhealth/tryton_first_time';
}

elsif (get_var("RESCUESYSTEM")) {
    loadtest "installation/rescuesystem";
    loadtest "installation/rescuesystem_validate_131";
}
elsif (get_var("LINUXRC")) {
    loadtest "linuxrc/system_boot";
}
elsif (get_var('Y2UITEST_NCURSES')) {
    load_yast2_ncurses_tests;
}
elsif (get_var('Y2UITEST_GUI')) {
    load_yast2_gui_tests;
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
elsif (get_var("ISO_IN_EXTERNAL_DRIVE")) {
    load_iso_in_external_tests();
    load_inst_tests();
    load_reboot_tests();
}
elsif (get_var('MM_CLIENT')) {
    boot_hdd_image;
    load_applicationstests;
}
elsif (get_var('SECURITYTEST')) {
    boot_hdd_image;
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    if (check_var('SECURITYTEST', 'core')) {
        load_security_tests_core;
    }
    elsif (check_var('SECURITYTEST', 'web')) {
        load_security_tests_web;
    }
    elsif (check_var('SECURITYTEST', 'misc')) {
        load_security_tests_misc;
    }
    elsif (check_var('SECURITYTEST', 'crypt')) {
        load_security_tests_crypt;
    }
}
elsif (get_var('SYSTEMD_TESTSUITE')) {
    load_systemd_patches_tests;
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
        boot_hdd_image;
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
        loadtest "console/force_cron_run";
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
        return 1 if get_var('EXIT_AFTER_START_INSTALL');
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
        if (consolestep_is_applicable) {
            load_consoletests();
        }
        elsif (is_staging() && get_var('UEFI') || is_gnome_next || is_krypton_argon) {
            load_consoletests_minimal();
        }
        load_x11tests();
        if (get_var('ROLLBACK_AFTER_MIGRATION') && (snapper_is_applicable())) {
            load_rollback_tests();
        }
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
