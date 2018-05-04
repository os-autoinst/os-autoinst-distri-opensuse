# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use strict;
use warnings;
use testapi qw(check_var get_var get_required_var set_var check_var_array diag);
use lockapi;
use needle;
use registration;
use utils;
use version_utils qw(is_hyperv_in_gui is_caasp is_installcheck is_rescuesystem sle_version_at_least is_desktop_installed is_jeos is_sle is_staging is_upgrade);
use File::Find;
use File::Basename;
use LWP::Simple 'head';

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;

init_main();

sub is_new_installation {
    return !get_var('UPGRADE') && !get_var('ONLINE_MIGRATION') && !get_var('ZDUP') && !get_var('AUTOUPGRADE');
}

sub cleanup_needles {
    remove_common_needles;
    if ((get_var('VERSION', '') ne '15') && (get_var('BASE_VERSION', '') ne '15')) {
        unregister_needle_tags("ENV-VERSION-15");
    }

    if ((get_var('VERSION', '') ne '12') && (get_var('BASE_VERSION', '') ne '12')) {
        unregister_needle_tags("ENV-VERSION-12");
    }

    if ((get_var('VERSION', '') ne '12-SP1') && (get_var('BASE_VERSION', '') ne '12-SP1')) {
        unregister_needle_tags("ENV-VERSION-12-SP1");
    }

    if ((get_var('VERSION', '') ne '12-SP2') && (get_var('BASE_VERSION', '') ne '12-SP2')) {
        unregister_needle_tags("ENV-VERSION-12-SP2");
    }

    if ((get_var('VERSION', '') ne '12-SP3') && (get_var('BASE_VERSION', '') ne '12-SP3')) {
        unregister_needle_tags("ENV-VERSION-12-SP3");
    }
    if ((get_var('VERSION', '') ne '11-SP4') && (get_var('BASE_VERSION', '') ne '11-SP4')) {
        unregister_needle_tags("ENV-VERSION-11-SP4");
    }

    my $tounregister = sle_version_at_least('12-SP2') ? '0' : '1';
    unregister_needle_tags("ENV-SP2ORLATER-$tounregister");

    $tounregister = sle_version_at_least('12-SP3') ? '0' : '1';
    unregister_needle_tags("ENV-SP3ORLATER-$tounregister");

    $tounregister = sle_version_at_least('15') ? '0' : '1';
    unregister_needle_tags("ENV-15ORLATER-$tounregister");

    if (!is_server) {
        unregister_needle_tags("ENV-FLAVOR-Server-DVD");
    }

    if (!is_desktop) {
        unregister_needle_tags("ENV-FLAVOR-Desktop-DVD");
    }

    if (!is_sles4sap) {
        unregister_needle_tags("ENV-FLAVOR-SAP-DVD");
    }

    if (!is_jeos) {
        unregister_needle_tags('ENV-FLAVOR-JeOS-for-kvm');
        unregister_needle_tags('ENV-JEOS-1');
    }

    if (!is_caasp) {
        unregister_needle_tags('ENV-DISTRI-CASP');
    }

    if (get_var('OFW')) {
        unregister_needle_tags('ENV-OFW-0');
    }
    else {
        unregister_needle_tags('ENV-OFW-1');
    }

    if (get_var('PXEBOOT')) {
        unregister_needle_tags('ENV-PXEBOOT-0');
    }
    else {
        unregister_needle_tags('ENV-PXEBOOT-1');
    }
}

sub is_desktop_module_available {
    return check_var('SCC_REGISTER', 'installation') || check_var_array('ADDONS', 'all-packages') || check_var_array('WORKAROUND_MODULES', 'desktop');
}

# SLE specific variables
set_var('NOAUTOLOGIN', 1);
set_var('HASLICENSE',  1);
set_var('SLE_PRODUCT', get_var('SLE_PRODUCT', 'sles'));
# Always register against SCC if SLE 15
if (sle_version_at_least('15')) {
    set_var('SCC_REGISTER', get_var('SCC_REGISTER', 'installation'));
    # depending on registration only limited system roles are available
    set_var('SYSTEM_ROLE', get_var('SYSTEM_ROLE', is_desktop_module_available() ? 'default' : 'minimal'));
    # set SYSTEM_ROLE to textmode for SLE4SAP on SLE15 instead of triggering change_desktop (see poo#29589)
    if (is_sles4sap && check_var('SYSTEM_ROLE', 'default') && check_var('DESKTOP', 'textmode')) {
        set_var('SYSTEM_ROLE', 'textmode');
    }
    # in the 'minimal' system role we can not execute many test modules
    set_var('INSTALLONLY', get_var('INSTALLONLY', check_var('SYSTEM_ROLE', 'minimal')));
}
diag('default desktop: ' . default_desktop);
set_var('DESKTOP', get_var('DESKTOP', default_desktop));
if (sle_version_at_least('15')) {
    if (check_var('ARCH', 's390x') and get_var('DESKTOP', '') =~ /gnome|minimalx/) {
        diag 'BUG: bsc#1058071 - No VNC server available in SUT, disabling X11 tests. Re-enable after bug is fixed';
        set_var('DESKTOP', 'textmode');
    }
}

# Set serial console for Xen PV
if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
    if (sle_version_at_least('12-SP2')) {
        set_var('SERIALDEV', 'hvc0');
    }
    else {
        set_var('SERIALDEV', 'xvc0');
    }
}

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

# This setting is used to set veriables properly when SDK or Development-Tools are required.
# For SLE 15 we add Development-Tools during using SCC, and using ftp url in case of other versions.
if (get_var('DEV_IMAGE')) {
    if (sle_version_at_least('15')) {
        # On SLE 15 activate Development-Tools module with SCC
        my $addons = (get_var('SCC_ADDONS') ? get_var('SCC_ADDONS') . ',' : '') . 'sdk';
        set_var('SCC_ADDONS', $addons);
    }
    else {
        my $arch      = get_required_var("ARCH");
        my $build     = get_required_var("BUILD");
        my $version   = get_required_var("VERSION");
        my $build_sdk = get_var("BUILD_SDK");
        # Set SDK URL unless already set, then don't override
        set_var('ADDONURL_SDK', "$utils::OPENQA_FTP_URL/SLE-$version-SDK-POOL-$arch-Build$build_sdk-Media1/") unless get_var('ADDONURL_SDK');
        my $addons = (get_var('ADDONURL') ? get_var('ADDONURL') . ',' : '') . 'sdk';
        set_var("ADDONURL", "sdk");
    }
}

# This is workaround setting which will be removed once SCC add repos and allows adding modules
# TODO: place it somewhere else since test module suseconnect_scc will use it
if (sle_version_at_least('15') && !check_var('SCC_REGISTER', 'installation')) {
    my @modules;
    if (get_var('ALL_MODULES')) {
        # By default add all modules
        @modules = qw(base sdk desktop legacy script serverapp);
    }
    # If WORKAROUND_MODULES contains a list of modules, add only them
    if (get_var('WORKAROUND_MODULES')) {
        @modules = split(/,/, get_var('WORKAROUND_MODULES'));
    }
    if (@modules) {
        my $arch    = get_required_var("ARCH");
        my $build   = get_required_var("BUILD");
        my $version = get_required_var("VERSION");
        my $addonurl;

        for my $short_name (@modules) {
            # Map the module's full name from its short name.
            # If it's not defined in $registration::SLE15_MODULES, then assume it's a Product/Extension and treat accordingly
            my $full_name = is_module($short_name) ? $registration::SLE15_MODULES{$short_name} : uc $short_name;
            my $repo_name = uc $full_name;
            # Replace dashes with underscore symbols
            $repo_name =~ s/-/_/;
            my $prefix = "SLE-$version";
            # Add staging prefix
            if (is_staging()) {
                $prefix .= "-Staging:" . get_var("STAGING");
            }
            # REPO_SLE* settings and repo names are different for products and modules
            # Assign the proper repo name if current $short_name references a module or a product/extension.
            my $repo_variable_name
              = is_module($short_name) ?
              "REPO_SLE${version}_MODULE_${repo_name}"
              : "REPO_SLE${version}_PRODUCT_${repo_name}";
            my $default_repo_name
              = is_module($short_name) ?
              "$prefix-Module-$full_name-POOL-$arch-Build$build-Media1"
              : "$prefix-Product-$full_name-POOL-$arch-Build$build-Media1";
            my $module_repo_name = get_var($repo_variable_name, $default_repo_name);
            my $url = "$utils::OPENQA_FTP_URL/$module_repo_name";
            # Verify if url exists before adding
            if (head($url)) {
                set_var('ADDONURL_' . uc $short_name, "$utils::OPENQA_FTP_URL/$module_repo_name");
                $addonurl .= "$short_name,";
            }
        }
        #remove last comma from ADDONURL setting value
        $addonurl =~ s/,$//;
        set_var("ADDONURL", $addonurl);
    }
}

# Always register at scc and use the test updates if the Flavor is -Updates.
# This way we can reuse existant test suites without having to patch their
# settings
if (is_updates_test_repo && !get_var('MAINT_TEST_REPO')) {
    my %incidents;
    my %u_url;
    $incidents{OS} = get_var('OS_TEST_ISSUES',   '');
    $u_url{OS}     = get_var('OS_TEST_TEMPLATE', '');

    my @inclist;

    my @addons = split(/,/, get_var('SCC_ADDONS', ''));

    for my $a (split(/,/, get_var('ADDONS', '')), split(/,/, get_var('ADDONURL', ''))) {
        push(@addons, $a);
    }

    # set SCC_ADDONS before push to slenkins
    set_var('SCC_ADDONS', join(',', @addons));

    # push sdk addon to slenkins tests
    if (get_var('TEST', '') =~ /^slenkins/) {
        push(@addons, 'sdk');
    }
    # move ADDONS to SCC_ADDONS for maintenance
    set_var('ADDONS', '');
    # move ADDONURL to SCC_ADDONS and remove ADDONURL_SDK
    set_var('ADDONURL',     '');
    set_var('ADDONURL_SDK', '');

    for my $a (@addons) {
        if ($a) {
            $incidents{uc($a)} = get_var(uc($a) . '_TEST_ISSUES');
            $u_url{uc($a)}     = get_var(uc($a) . '_TEST_TEMPLATE');
        }
    }

    my $repos = map_incidents_to_repo(\%incidents, \%u_url);

    set_var('MAINT_TEST_REPO', $repos);
    set_var('SCC_REGISTER',    'installation');

    # slenkins test needs FOREIGN_REPOS
    if (get_var('TEST', '') =~ /^slenkins/) {
        set_var('FOREIGN_REPOS', $repos);
    }
}

if (get_var('ENABLE_ALL_SCC_MODULES') && !get_var('SCC_ADDONS')) {
    if (sle_version_at_least('15')) {
        # Add only modules which are not pre-selected
        my $addons = 'legacy,sdk,pcm,wsm';
        # Container module is missing for aarch64. Not a bug. fate#323788
        $addons .= ',contm' unless (check_var('ARCH', 'aarch64'));
        set_var('SCC_ADDONS', $addons);
        set_var('PATTERNS', 'default,asmm,pcm') if !get_var('PATTERNS');
    }
    else {
        if (check_var('ARCH', 'aarch64')) {
            set_var('SCC_ADDONS', 'pcm,tcm');
            set_var('PATTERNS', 'default,pcm') if !get_var('PATTERNS');
        }
        else {
            set_var('SCC_ADDONS', 'phub,asmm,contm,lgm,pcm,tcm,wsm');
            set_var('PATTERNS', 'default,asmm,pcm') if !get_var('PATTERNS');
        }
    }
}

# define aytests repo for support server (do not override defined value)
if (get_var('SUPPORT_SERVER_ROLES', '') =~ /aytest/ && !get_var('AYTESTS_REPO')) {
    if (sle_version_at_least('15')) {
        set_var('AYTESTS_REPO', 'http://download.suse.de/ibs/Devel:/YaST:/Head/SUSE_SLE-15_GA/');
    }
    else {
        set_var('AYTESTS_REPO', 'http://download.suse.de/ibs/Devel:/YaST:/SLE-12-SP3/SLE_12_SP3/');
    }
}

$needle::cleanuphandler = \&cleanup_needles;

# dump other important ENV:
logcurrentenv(
    qw(ADDONURL BTRFS DESKTOP LVM MOZILLATEST
      NOINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE
      DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG
      QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE NETBOOT USEIMAGES
      SYSTEM_ROLE SCC_REGISTER
      SLE_PRODUCT SPLITUSR VIDEOMODE)
);

sub load_x11_webbrowser_core {
    loadtest "x11/firefox/firefox_smoke";
    loadtest "x11/firefox/firefox_urlsprotocols";
    loadtest "x11/firefox/firefox_downloading";
    loadtest "x11/firefox/firefox_changesaving";
    loadtest "x11/firefox/firefox_fullscreen";
    loadtest "x11/firefox/firefox_flashplayer";
}

sub load_x11_webbrowser_extra {
    loadtest "x11/firefox/firefox_localfiles";
    loadtest "x11/firefox/firefox_headers";
    loadtest "x11/firefox/firefox_pdf";
    loadtest "x11/firefox/firefox_health";
    loadtest "x11/firefox/firefox_pagesaving";
    loadtest "x11/firefox/firefox_private";
    loadtest "x11/firefox/firefox_mhtml";
    loadtest "x11/firefox/firefox_extensions";
    loadtest "x11/firefox/firefox_appearance";
    loadtest "x11/firefox/firefox_passwd";
    loadtest "x11/firefox/firefox_html5";
    loadtest "x11/firefox/firefox_developertool";
    loadtest "x11/firefox/firefox_rss";
    loadtest "x11/firefox/firefox_ssl";
    loadtest "x11/firefox/firefox_emaillink";
    loadtest "x11/firefox/firefox_plugins";
    loadtest "x11/firefox/firefox_java";
    loadtest "x11/firefox/firefox_extcontent";
    loadtest "x11/firefox/firefox_gnomeshell";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio";
    }
}

sub load_x11_message {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11/empathy/empathy_irc";
        loadtest "x11/evolution/evolution_smoke";
        loadtest "x11/evolution/evolution_prepare_servers";
        loadtest "x11/evolution/evolution_mail_imap";
        loadtest "x11/evolution/evolution_mail_pop";
        loadtest "x11/evolution/evolution_timezone_setup";
        loadtest "x11/evolution/evolution_meeting_imap";
        loadtest "x11/evolution/evolution_meeting_pop";
        loadtest "x11/groupwise/groupwise";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11/pidgin/prep_pidgin";
        loadtest "x11/pidgin/pidgin_IRC";
        loadtest "x11/pidgin/clean_pidgin";
    }
}

sub load_x11_remote {
    # load onetime vncsession testing
    if (check_var('REMOTE_DESKTOP_TYPE', 'one_time_vnc')) {
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_tigervnc';
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_remmina';
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_java' if is_sle('<15');
        loadtest 'x11/remote_desktop/onetime_vncsession_multilogin_failed';
    }
    # load persistemt vncsession, x11 forwarding, xdmcp with gdm testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc')) {
        loadtest 'x11/remote_desktop/persistent_vncsession_xvnc';
        loadtest 'x11/remote_desktop/x11_forwarding_openssh';
        loadtest 'x11/remote_desktop/xdmcp_gdm';
    }
    # load xdmcp with xdm testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'xdmcp_xdm')) {
        loadtest 'x11/remote_desktop/xdmcp_xdm';
    }
    # load vino testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'vino_server')) {
        loadtest 'x11/remote_desktop/vino_server';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'vino_client')) {
        loadtest 'x11/remote_desktop/vino_client';
    }
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

sub load_ha_cluster_tests {
    return unless (get_var('HA_CLUSTER'));

    # Standard boot and configuration
    boot_hdd_image;
    loadtest 'ha/wait_barriers';
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    loadtest 'console/consoletest_setup';
    loadtest 'console/hostname';

    # NTP is already configured with 'HA node' and 'HA GEO node' System Roles
    # 'default' System Role is 'HA node' if HA Product i selected
    loadtest "console/yast2_ntpclient" unless (get_var('SYSTEM_ROLE', '') =~ /default|ha/);

    # Update the image if needed
    if (get_var('FULL_UPDATE')) {
        loadtest 'update/zypper_up';
        loadtest 'console/console_reboot';
    }

    # SLE15 workarounds
    loadtest 'ha/sle15_workarounds' if is_sle('15+');

    # Basic configuration
    loadtest 'ha/firewall_disable';
    loadtest 'ha/iscsi_client';
    loadtest 'ha/watchdog';

    # Cluster initilisation
    if (get_var('HA_CLUSTER_INIT')) {
        # Node1 creates a cluster
        loadtest 'ha/ha_cluster_init';
    }
    else {
        # Node2 joins the cluster
        loadtest 'ha/ha_cluster_join';
    }

    # Test Hawk Web interface
    loadtest 'ha/check_hawk';

    # Lock manager configuration
    loadtest 'ha/dlm';
    loadtest 'ha/clvmd_lvmlockd';

    # Test cluster-md feature
    loadtest 'ha/cluster_md';
    loadtest 'ha/vg';
    loadtest 'ha/filesystem';

    # Test DRBD feature
    if (get_var('HA_CLUSTER_DRBD')) {
        loadtest 'ha/drbd_passive';
        loadtest 'ha/filesystem';
    }

    # Show HA cluster status *before* fencing test and execute fencing test
    loadtest 'ha/fencing';

    # Node1 will be fenced, so we have to wait for it to boot
    boot_hdd_image if (!get_var('HA_CLUSTER_JOIN'));

    # Show HA cluster status *after* fencing test
    loadtest 'ha/check_after_fencing';

    # Check logs to find error and upload all needed logs
    loadtest 'ha/check_logs';

    return 1;
}

sub load_feature_tests {
    loadtest "console/consoletest_setup";
    loadtest "feature/feature_console/zypper_releasever";
    loadtest "feature/feature_console/suseconnect";
    loadtest "feature/feature_console/zypper_crit_sec_fix_only";
}

sub load_online_migration_tests {
    # stop packagekit service and more
    loadtest "migration/sle12_online_migration/online_migration_setup";
    loadtest "migration/sle12_online_migration/register_system";
    # do full/minimal update before migration
    if (get_var("FULL_UPDATE")) {
        loadtest "migration/sle12_online_migration/zypper_patch";
    }
    if (get_var("MINIMAL_UPDATE")) {
        loadtest "migration/sle12_online_migration/minimal_patch";
    }
    if (get_var('SCC_ADDONS', '') =~ /ltss/) {
        loadtest "migration/sle12_online_migration/register_without_ltss";
    }
    loadtest "migration/sle12_online_migration/pre_migration";
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/lock_package";
    }
    if (check_var("MIGRATION_METHOD", 'yast')) {
        loadtest "migration/sle12_online_migration/yast2_migration";
    }
    if (check_var("MIGRATION_METHOD", 'zypper')) {
        loadtest "migration/sle12_online_migration/zypper_migration";
    }
    loadtest "migration/sle12_online_migration/orphaned_packages_check";
    loadtest "migration/sle12_online_migration/post_migration";
}

sub load_patching_tests {
    # Switch to orginal system version for upgrade tests
    if (is_upgrade) {
        # Save HDDVERSION to ORIGIN_SYSTEM_VERSION
        set_var('ORIGIN_SYSTEM_VERSION', get_var('HDDVERSION'));
        # Save VERSION to UPGRADE_TARGET_VERSION
        set_var('UPGRADE_TARGET_VERSION', get_var('VERSION'));
        # Always boot from installer DVD in upgrade test
        set_var('BOOTFROM', 'd');
        loadtest "migration/version_switch_origin_system";
    }
    set_var('BOOT_HDD_IMAGE', 1);
    boot_hdd_image;
    loadtest 'update/patch_sle';
    if (is_upgrade) {
        # Lock package for offline migration by Yast installer
        if (get_var('LOCK_PACKAGE') && !installzdupstep_is_applicable) {
            loadtest 'console/lock_package';
        }
        loadtest 'migration/remove_ltss';
        loadtest 'migration/record_disk_info';
        # Reboot from DVD and perform upgrade
        loadtest "migration/reboot_to_upgrade";
        # After original system patched, switch to UPGRADE_TARGET_VERSION
        # For ZDUP upgrade, version switch back later
        if (get_var('UPGRADE') || get_var('AUTOUPGRADE')) {
            loadtest "migration/version_switch_upgrade_target";
        }
    }
}

sub prepare_target {
    if (get_var("BOOT_HDD_IMAGE")) {
        boot_hdd_image;
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }
}

sub load_default_tests {
    load_boot_tests();
    load_inst_tests();
    return 1 if get_var('EXIT_AFTER_START_INSTALL');
    load_reboot_tests();
}

sub load_default_autoyast_tests {
    loadtest "autoyast/prepare_profile" if get_var "AUTOYAST_PREPARE_PROFILE";
    load_patching_tests if get_var('PATCH');
    load_boot_tests;
    load_autoyast_tests;
    load_reboot_tests;
}

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

if (is_jeos) {
    load_boot_tests();
    loadtest "jeos/firstrun";
    loadtest "console/force_cron_run";
    loadtest "jeos/grub2_gfxmode";
    loadtest 'jeos/revive_xen_domain' if check_var('VIRSH_VMM_FAMILY', 'xen');
    loadtest "jeos/diskusage";
    loadtest "jeos/root_fs_size";
    loadtest "jeos/mount_by_label";
    loadtest "console/suseconnect_scc";
}

# load the tests in the right order
if (is_kernel_test()) {
    load_kernel_tests();
}
elsif (get_var("WICKED")) {
    boot_hdd_image();
    load_wicked_tests();
}
elsif (get_var('NFV')) {
    if (check_var("NFV", "master")) {
        load_nfv_master_tests();
    }
    elsif (check_var("NFV", "trafficgen")) {
        load_nfv_trafficgen_tests();
    }
}
elsif (get_var("REGRESSION")) {
    load_common_x11;
    # Used by QAM testing
    if (check_var("REGRESSION", "firefox")) {
        loadtest "boot/boot_to_desktop";
        load_x11_webbrowser_core();
        load_x11_webbrowser_extra();
    }
    # Used by Desktop Applications Group
    elsif (check_var("REGRESSION", "webbrowser_core")) {
        loadtest "boot/boot_to_desktop";
        load_x11_webbrowser_core();
    }
    # Used by Desktop Applications Group
    elsif (check_var("REGRESSION", "webbrowser_extra")) {
        loadtest "boot/boot_to_desktop";
        load_x11_webbrowser_extra();
    }
    elsif (check_var("REGRESSION", "message")) {
        loadtest "boot/boot_to_desktop";
        load_x11_message();
    }
    elsif (check_var('REGRESSION', 'remote')) {
        loadtest 'boot/boot_to_desktop';
        load_x11_remote();
    }
    elsif (check_var("REGRESSION", "piglit")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/piglit/piglit";
    }
}
elsif (get_var("FEATURE")) {
    prepare_target();
    load_feature_tests();
}
elsif (is_mediacheck) {
    load_svirt_vm_setup_tests;
    loadtest "installation/mediacheck";
}
elsif (is_memtest) {
    if (!get_var("OFW")) {    #no memtest on PPC
        load_svirt_vm_setup_tests;
        loadtest "installation/memtest";
    }
}
elsif (is_rescuesystem) {
    load_svirt_vm_setup_tests;
    loadtest "installation/rescuesystem";
    loadtest "installation/rescuesystem_validate_sle";
}
elsif (is_installcheck) {
    load_svirt_vm_setup_tests;
    loadtest "installation/rescuesystem";
    loadtest "installation/installcheck";
}
elsif (get_var("SUPPORT_SERVER")) {
    loadtest "support_server/login";
    loadtest "support_server/setup";
    if (get_var("REMOTE_CONTROLLER")) {
        loadtest "remote/remote_controller";
        load_inst_tests();
    }
    loadtest "ha/barrier_init"  if get_var("HA_CLUSTER");
    loadtest "hpc/barrier_init" if get_var("HPC");
    unless (load_slenkins_tests()) {
        loadtest "support_server/wait_children";
    }
}
elsif (get_var("SLEPOS")) {
    load_slepos_tests();
}
elsif (get_var("FIPS_TS")) {
    prepare_target();
    if (get_var('BOOT_HDD_IMAGE')) {
        loadtest "console/consoletest_setup";
    }
    if (check_var("FIPS_TS", "setup")) {
        # Setup system into fips mode
        loadtest "fips/fips_setup";
    }
    elsif (check_var("FIPS_TS", "fipsenv")) {
        loadtest "fips/openssl/openssl_fips_env";
    }
    elsif (check_var("FIPS_TS", "core")) {
        load_security_tests_core;
    }
    elsif (check_var("FIPS_TS", "web")) {
        load_security_tests_web;
    }
    elsif (check_var("FIPS_TS", "misc")) {
        load_security_tests_misc;
    }
    elsif (check_var("FIPS_TS", "crypt")) {
        load_security_tests_crypt;
    }
    elsif (check_var("FIPS_TS", "ipsec")) {
        loadtest "console/ipsec_tools_h2h";
    }
    elsif (check_var("FIPS_TS", "mmtest")) {
        # Load client tests by APPTESTS variable
        load_applicationstests;
    }
}
elsif (get_var('SMT')) {
    prepare_target();
    loadtest "x11/smt_disconnect_prepare";
    if (check_var('SMT', 'external')) {
        loadtest "x11/smt_disconnect_external";
    }
    elsif (check_var('SMT', 'internal')) {
        loadtest "x11/smt_disconnect_internal";
    }
}
elsif (get_var("HA_CLUSTER")) {
    load_ha_cluster_tests();
}
elsif (get_var("QA_TESTSET")) {
    boot_hdd_image;
    if (get_var('INSTALL_KOTD')) {
        loadtest 'kernel/install_kotd';
    }
    if (get_var('MAINT_TEST_REPO')) {
        loadtest "qa_automation/patch_and_reboot";
    }
    loadtest "qa_automation/" . get_var("QA_TESTSET");
}
elsif (get_var("QA_TESTSUITE")) {
    boot_hdd_image;
    loadtest "qa_automation/prepare_qa_repo";
    loadtest "qa_automation/install_test_suite";
    loadtest "qa_automation/execute_test_run";
}
elsif (get_var("XFSTESTS")) {
    loadtest "boot/boot_to_desktop";
    loadtest "xfstests/enable_kdump";
    loadtest "xfstests/install";
    loadtest "xfstests/partition";
    loadtest "xfstests/run";
    loadtest "xfstests/generate_report";
}
elsif (get_var("VIRT_AUTOTEST")) {
    if (get_var('REPO_0_TO_INSTALL', '')) {
        #Before host installation starts, swtich to version REPO_0_TO_INSTALL if it is set
        #Save VERSION TO TARGET_DEVELOPING_VERSION
        set_var('TARGET_DEVELOPING_VERSION', get_var('VERSION'));
        #Switch to VERSION_TO_INSTALL
        set_var('VERSION', get_var('VERSION_TO_INSTALL'));
    }
    if (get_var("PROXY_MODE")) {
        loadtest "virt_autotest/proxymode_login_proxy";
        loadtest "virt_autotest/proxymode_init_pxe_install";
        loadtest "virt_autotest/proxymode_redirect_serial";
        loadtest "virt_autotest/install_package";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/reboot_and_wait_up_normal";
        }
        loadtest "virt_autotest/update_package";
        loadtest "virt_autotest/reboot_and_wait_up_normal";
    }
    else {
        load_boot_tests();
        if (get_var("AUTOYAST")) {
            loadtest "autoyast/installation";
            loadtest "virt_autotest/reboot_and_wait_up_normal";
        }
        else {
            load_inst_tests();
            loadtest "virt_autotest/login_console";
        }
        loadtest "virt_autotest/install_package";
        loadtest "virt_autotest/update_package";
        loadtest "virt_autotest/reboot_and_wait_up_normal";
    }
    if (get_var("VIRT_PRJ1_GUEST_INSTALL")) {
        loadtest "virt_autotest/guest_installation_run";
    }
    elsif (get_var("VIRT_PRJ2_HOST_UPGRADE")) {
        loadtest "virt_autotest/host_upgrade_generate_run_file";
        loadtest "virt_autotest/host_upgrade_step2_run";
        if (get_var('REPO_0_TO_INSTALL', '')) {
            #After host upgrade, switch to version TARGET_DEVELOPING_VERSION and reload needles
            loadtest "virt_autotest/switch_version_and_reload_needle";
        }
        loadtest "virt_autotest/reboot_and_wait_up_upgrade";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/setup_xen_serial_console";
            loadtest "virt_autotest/reboot_and_wait_up_normal";
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
    elsif (get_var("VIRT_PRJ6_VIRT_V2V_SRC")) {
        loadtest "virt_autotest/virt_v2v_src";
    }
    elsif (get_var("VIRT_PRJ6_VIRT_V2V_DST")) {
        loadtest "virt_autotest/virt_v2v_dst";
    }
    elsif (get_var("VIRT_NEW_GUEST_MIGRATION_SOURCE")) {
        loadtest "virt_autotest/guest_migration_src";
    }
    elsif (get_var("VIRT_NEW_GUEST_MIGRATION_DESTINATION")) {
        loadtest "virt_autotest/guest_migration_dst";
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
elsif (get_var("EXTRATEST")) {
    boot_hdd_image;
    # update system with agregate repositories
    if (is_updates_tests) {
        loadtest "qa_automation/patch_and_reboot";
    }
    load_extra_tests();
}
elsif (get_var("FILESYSTEM_TEST")) {
    boot_hdd_image;
    if (is_updates_tests) {
        loadtest "qa_automation/patch_and_reboot";
    }
    load_filesystem_tests();
}
elsif (get_var('Y2UITEST_NCURSES')) {
    load_yast2_ncurses_tests;
}
elsif (get_var('Y2UITEST_GUI')) {
    load_yast2_gui_tests;
}
elsif (get_var("SYSCONTAINER_IMAGE_TEST")) {
    boot_hdd_image;
    load_syscontainer_tests();
}
elsif (get_var("WINDOWS")) {
    loadtest "installation/win10_installation";
}
elsif (ssh_key_import) {
    load_ssh_key_import_tests;
}
elsif (get_var('ISO_IN_EXTERNAL_DRIVE')) {
    load_iso_in_external_tests();
    load_inst_tests();
    load_reboot_tests();
}
# post registration testsuites using suseconnect or yast
elsif (have_scc_repos()) {
    load_bootloader_s390x();    # schedule svirt/s390x bootloader if required
    loadtest "boot/boot_to_desktop";
    if (get_var('USE_SUSECONNECT')) {
        loadtest "console/suseconnect_scc";
    }
    else {
        loadtest "console/yast_scc";
    }
}
elsif (get_var('HPC')) {
    boot_hdd_image;
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    loadtest 'hpc/before_test';
    loadtest 'console/install_all_from_repository' if (get_var('INSTALL_ALL_REPO'));
    loadtest 'console/install_single_package'      if (get_var('PACKAGETOINSTALL'));

    # load hpc multimachine scenario based on value of HPC variable
    # e.g 'hpc/$testsuite_[master|slave].pm'
    my $hpc_mm_scenario = get_var('HPC');
    loadtest "hpc/$hpc_mm_scenario" if $hpc_mm_scenario ne '1';
}
elsif (get_var('SYSTEMD_TESTSUITE')) {
    load_systemd_patches_tests;
}
else {
    if (get_var("SES5_DEPLOY")) {
        loadtest "boot/boot_from_pxe";
        loadtest "autoyast/installation";
        loadtest "installation/first_boot";
    }
    elsif (get_var("SES_NODE")) {
        boot_hdd_image;
        if (get_var("DEEPSEA_TESTSUITE")) {
            loadtest "ses/nodes_preparation";
            loadtest "ses/deepsea_testsuite";
        }
        else {
            loadtest "console/hostname";
            loadtest "ses/nodes_preparation";
            loadtest "ses/deepsea_cluster_deploy";
            loadtest "ses/openattic";
        }
        return 1;
    }
    elsif (get_var('UPGRADE_ON_ZVM')) {
        # Set 'DESKTOP' for origin system to avoid SLE15 s390x bug: bsc#1058071 - No VNC server available in SUT
        # Set origin and target version
        set_var('DESKTOP',                'gnome');
        set_var('ORIGIN_SYSTEM_VERSION',  get_var('BASE_VERSION'));
        set_var('UPGRADE_TARGET_VERSION', get_var('VERSION'));
        loadtest "migration/version_switch_origin_system";
        # Use autoyast to perform origin system installation
        load_default_autoyast_tests;
        # Load this to perform some other actions before upgrade even though registration and patching is controlled by autoyast
        loadtest 'update/patch_sle';
        loadtest 'migration/remove_ltss';
        loadtest 'migration/record_disk_info';
        loadtest "migration/version_switch_upgrade_target";
        load_default_tests;
        loadtest "migration/post_upgrade";
    }
    elsif (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
        load_default_autoyast_tests;
    }
    elsif (installzdupstep_is_applicable()) {
        # Staging cannot be registered, so Staging cannot be patched before testing upgrades in staging
        if (!is_staging) {
            load_patching_tests();
        }
        load_zdup_tests();
    }
    elsif (get_var("ONLINE_MIGRATION")) {
        load_boot_tests();
        load_online_migration_tests();
    }
    elsif (get_var("UPGRADE")) {
        load_patching_tests() if get_var('PATCH');
        load_boot_tests();
        load_inst_tests();
        return 1 if get_var('EXIT_AFTER_START_INSTALL');
        load_reboot_tests();
        loadtest "migration/post_upgrade";
        # Always load zypper_lr test for migration case and get repo information for investigation
        if (get_var("INSTALLONLY")) {
            loadtest "console/consoletest_setup";
            loadtest "console/zypper_lr";
        }
    }
    elsif (get_var("BOOT_HDD_IMAGE") && !is_jeos) {
        if (get_var("RT_TESTS")) {
            set_var('INSTALLONLY', 1);
            loadtest "rt/boot_rt_kernel";
        }
        else {
            load_bootloader_s390x();
            loadtest "boot/boot_to_desktop";
            if (get_var("ADDONS")) {
                loadtest "installation/addon_products_yast2";
            }
            if (get_var('SCC_ADDONS')) {
                loadtest "installation/addon_products_via_SCC_yast2";
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
        }
    }
    elsif (get_var("REMOTE_TARGET")) {
        load_boot_tests();
        loadtest "remote/remote_target";
    }
    else {
        if (get_var('BOOT_EXISTING_S390')) {
            loadtest 'installation/boot_s390';
            loadtest 'installation/reconnect_s390';
            loadtest 'installation/first_boot';
        }
        elsif (!is_jeos) {
            return 1 if load_default_tests;
        }
    }
    unless (load_applicationstests() || load_slenkins_tests()) {
        load_rescuecd_tests();
        load_consoletests();
        load_x11tests();
        if (is_sles4sap() and !is_sles4sap_standard() and !is_desktop_installed()) {
            load_sles4sap_tests();
        }
        if (get_var('ROLLBACK_AFTER_MIGRATION') && (snapper_is_applicable())) {
            load_rollback_tests();
        }
    }
}

load_common_opensuse_sle_tests;

1;
# vim: set sw=4 et:
