# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2019 SUSE LLC
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
use mmapi 'get_parents';
use version_utils
  qw(is_vmware is_hyperv is_hyperv_in_gui is_caasp is_installcheck is_rescuesystem is_desktop_installed is_jeos is_sle is_staging is_upgrade);
use File::Find;
use File::Basename;
use LWP::Simple 'head';
use scheduler 'load_yaml_schedule';
use Utils::Backends qw(is_hyperv is_hyperv_in_gui);
use DistributionProvider;

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use main_common;
use known_bugs;

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

    my $tounregister = is_sle('12+') ? '0' : '1';
    unregister_needle_tags("ENV-12ORLATER-$tounregister");

    $tounregister = is_sle('12-SP2+') ? '0' : '1';
    unregister_needle_tags("ENV-SP2ORLATER-$tounregister");

    $tounregister = is_sle('12-SP3+') ? '0' : '1';
    unregister_needle_tags("ENV-SP3ORLATER-$tounregister");

    $tounregister = is_sle('15+') ? '0' : '1';
    unregister_needle_tags("ENV-15ORLATER-$tounregister");

    $tounregister = is_sle('15-SP1+') ? '0' : '1';
    unregister_needle_tags("ENV-15SP1ORLATER-$tounregister");

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
if (is_sle('15+')) {
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
elsif (is_sle('=12-SP5') && check_var('ARCH', 'x86_64')) {
    # System Role dialog is displayed only for x86_64 in SLE-12-SP5 due to it has more than one role available,
    # for the moment we are not handling available roles, so this make the trick for using new scheduling.
    set_var('SYSTEM_ROLE', 'default');
}
diag('default desktop: ' . default_desktop);
set_var('DESKTOP', get_var('DESKTOP', default_desktop));
if (is_sle('15+')) {
    if (check_var('ARCH', 's390x') and get_var('DESKTOP', '') =~ /gnome|minimalx/) {
        diag 'BUG: bsc#1058071 - No VNC server available in SUT, disabling X11 tests. Re-enable after bug is fixed';
        set_var('DESKTOP', 'textmode');
    }
}

# don't want updates, as we don't test it or rely on it in any tests, if is executed during installation
# For released products we want install updates during installation, only in minimal workflow disable
set_var('DISABLE_SLE_UPDATES', get_var('DISABLE_SLE_UPDATES', get_var('QAM_MINIMAL')));

# set remote connection variable for s390x, svirt and ipmi
set_var('REMOTE_CONNECTION', 'vnc') if get_var('BACKEND', '') =~ /s390x|svirt|ipmi/;

# Set serial console for Xen PV
if (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux')) {
    if (is_sle('12-SP2+')) {
        set_var('SERIALDEV', 'hvc0');
    }
    else {
        set_var('SERIALDEV', 'xvc0');
    }
}

if (is_sle('12-SP2+')) {
    set_var('SP2ORLATER', 1);
}

if (is_sle('12-SP3+')) {
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
    if (is_sle('15+')) {
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

#This setting is used to enable all extensions/modules for upgrading tests, generate corresponding extensions/modules list for all addons, all extensions, all modules cases.
if (check_var('SCC_REGISTER', 'installation') && get_var('ALL_ADDONS') && !get_var('SCC_ADDONS')) {
    my $version = get_required_var("HDDVERSION");
    #Below $common* store the extensions/modules list in common.
    my %common_addons = (
        '12-SP3' => 'sdk,pcm,tcm,wsm',
        '11-SP4' => 'ha,geo,sdk'
    );
    my %common_extensions = ('12-SP3' => 'sdk');
    my %common_modules    = ('12-SP3' => 'pcm,tcm,wsm');
    #Below $external* store external extensions/modules list on each ARCH.
    my %external_addons_12SP3 = (
        'x86_64' => 'ha,geo,we,live,asmm,contm,lgm,hpcm',
        ppc64le  => 'ha,live,asmm,contm,lgm',
        s390x    => 'ha,geo,asmm,contm,lgm',
        aarch64  => 'hpcm'
    );
    my %external_modules_12SP3 = (
        'x86_64' => 'asmm,contm,lgm,hpcm',
        ppc64le  => 'asmm,contm,lgm',
        s390x    => 'asmm,contm,lgm',
        aarch64  => 'hpcm'
    );
    my %external_extensions_12SP3 = (
        'x86_64' => 'ha,geo,we,live',
        ppc64le  => 'ha,live',
        s390x    => 'ha,geo',
        aarch64  => ''
    );
    # ALL_ADDONS = 'addons' : all addons, 'extensions' : all extensions, 'modules' : all modules.
    if (is_sle('12-SP3+')) {
        set_var('SCC_ADDONS', join(',', $common_addons{$version},     $external_addons_12SP3{get_var('ARCH')}))     if (check_var('ALL_ADDONS', 'addons'));
        set_var('SCC_ADDONS', join(',', $common_extensions{$version}, $external_extensions_12SP3{get_var('ARCH')})) if (check_var('ALL_ADDONS', 'extensions'));
        set_var('SCC_ADDONS', join(',', $common_modules{$version},    $external_modules_12SP3{get_var('ARCH')}))    if (check_var('ALL_ADDONS', 'modules'));
    }
    elsif (is_sle('11-SP4+')) {
        set_var('SCC_ADDONS', $common_addons{$version});
    }
    else {
        die 'No addons defined for this version!';
    }
}

# This is workaround setting which will be removed once SCC add repos and allows adding modules
# TODO: place it somewhere else since test module suseconnect_scc will use it
if (is_sle('15+') && !check_var('SCC_REGISTER', 'installation')) {
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
              "REPO_SLE_MODULE_${repo_name}"
              : "REPO_SLE_PRODUCT_${repo_name}";
            # Replace dashes with underscore symbols, as not used in the variable name
            $repo_variable_name =~ s/-/_/;
            my $default_repo_name
              = is_module($short_name) ?
              "$prefix-Module-$full_name-POOL-$arch-Build$build-Media1"
              : "$prefix-Product-$full_name-POOL-$arch-Build$build-Media1";
            my $module_repo_name = get_var($repo_variable_name, $default_repo_name);
            my $url              = "$utils::OPENQA_FTP_URL/$module_repo_name";
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

    for my $i (split(/,/, get_var('ADDONS', '')), split(/,/, get_var('ADDONURL', ''))) {
        push(@addons, $i);
    }

    # set SCC_ADDONS before push to slenkins
    set_var('SCC_ADDONS', join(',', @addons));

    # SLES4SAP does not have addon on SLE12SP3
    push(@addons, 'sles4sap') if is_sle('<15') && check_var('FLAVOR', 'Server-DVD-SLES4SAP-Updates');

    # push sdk addon to slenkins tests
    if (get_var('TEST', '') =~ /^slenkins/) {
        push(@addons, 'sdk');
    }
    # move ADDONS to SCC_ADDONS for maintenance
    set_var('ADDONS', '');
    # move ADDONURL to SCC_ADDONS and remove ADDONURL_SDK
    set_var('ADDONURL',     '');
    set_var('ADDONURL_SDK', '');

    for my $i (@addons) {
        if ($i) {
            $incidents{uc($i)} = get_var(uc($i) . '_TEST_ISSUES');
            $u_url{uc($i)}     = get_var(uc($i) . '_TEST_TEMPLATE');
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
    if (is_sle('15+')) {
        # Add only modules which are not pre-selected
        # 'pcm' should be treated special as it is only applicable to cloud
        # installations
        my $addons = 'legacy,sdk,wsm,phub';
        # Container module is missing for aarch64. Not a bug. fate#323788
        $addons .= ',contm' unless (check_var('ARCH', 'aarch64'));
        set_var('SCC_ADDONS', $addons);
        set_var('PATTERNS', 'default,asmm') if !get_var('PATTERNS');
    }
    else {
        if (check_var('ARCH', 'aarch64')) {
            set_var('SCC_ADDONS', 'tcm');
            set_var('PATTERNS', 'default') if !get_var('PATTERNS');
        }
        else {
            set_var('SCC_ADDONS', 'phub,asmm,contm,lgm,tcm,wsm');
            set_var('PATTERNS', 'default,asmm') if !get_var('PATTERNS');
        }
    }
}

# define aytests repo for support server (do not override defined value)
if (get_var('SUPPORT_SERVER_ROLES', '') =~ /aytest/ && !get_var('AYTESTS_REPO_BRANCH')) {
    if (is_sle('<15')) {
        set_var('AYTESTS_REPO_BRANCH', 'SLE-12-SP3');
    }
    else {
        set_var('AYTESTS_REPO_BRANCH', 'master');
    }
}

# Workaround to be able to use create_hdd_hpc_textmode simultaneously in SLE15 and SLE12 SP*
# and exlude maintenance tests
if (check_var('SLE_PRODUCT', 'hpc') && check_var('INSTALLONLY', '1') && is_sle('<15') && !is_updates_tests) {
    set_var('SCC_ADDONS',   'hpcm,wsm');
    set_var('SCC_REGISTER', 'installation');
}
# We have different dud files for SLE 12 and SLE 15
if (check_var('DUD_ADDONS', 'sdk') && !get_var('DUD')) {
    set_var('DUD', is_sle('15+') ? 'dev_tools.dud' : 'sdk.dud');
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

sub load_slenkins_tests {
    if (get_var("SLENKINS_CONTROL")) {
        my $parents = get_parents;
        barrier_create 'HOSTNAMES_CONFIGURED', 1 + @$parents;

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

sub load_feature_tests {
    loadtest "console/system_prepare";
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
    loadtest 'installation/install_service' if (is_sle && !is_desktop && !get_var('INSTALLONLY'));
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/lock_package";
    }
    if (check_var("MIGRATION_METHOD", 'yast')) {
        loadtest "migration/sle12_online_migration/yast2_migration";
    }
    if (check_var("MIGRATION_METHOD", 'zypper')) {
        loadtest "migration/sle12_online_migration/zypper_migration";
    }
    loadtest 'console/orphaned_packages_check';
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
        loadtest "migration/version_switch_origin_system" if (!get_var('ONLINE_MIGRATION'));
    }
    set_var('BOOT_HDD_IMAGE', 1);
    boot_hdd_image;
    loadtest 'update/patch_sle';
    if (is_upgrade) {
        # Lock package for offline migration by Yast installer
        if (get_var('LOCK_PACKAGE') && !installzdupstep_is_applicable) {
            loadtest 'console/lock_package';
        }
        loadtest 'migration/record_disk_info';
        # Install service for offline migration by zypper
        loadtest 'installation/install_service' if (is_sle && !is_desktop && !get_var('MEDIA_UPGRADE') && !get_var('ZDUP') && !get_var('INSTALLONLY'));
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
    elsif (check_var('IPXE', '1')) {
        return;
    }
    else {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }
}

sub mellanox_config {
    loadtest "kernel/mellanox_config";
    load_reboot_tests() if (check_var('BACKEND', 'ipmi'));
}

sub load_baremetal_tests {
    loadtest "autoyast/prepare_profile" if get_var "AUTOYAST_PREPARE_PROFILE";
    if (get_var('IPXE')) {
        loadtest 'installation/ipxe_install';
        loadtest "console/suseconnect_scc";
    } else {
        load_boot_tests();
        get_var("AUTOYAST") ? load_ayinst_tests() : load_inst_tests();
        load_reboot_tests();
    }
}

sub load_infiniband_tests {
    # The barriers below must be created
    # here to ensure they are a) only created once and b) early enough
    # to be available when needed.
    if (get_var('IBTEST_ROLE') eq 'IBTEST_MASTER') {
        barrier_create('IBTEST_SETUP', 2);
        barrier_create('IBTEST_BEGIN', 2);
        barrier_create('IBTEST_DONE',  2);
    }
    mellanox_config();
    loadtest "kernel/ib_tests";
}

sub load_nfv_tests {
    loadtest "nfv/hugepages_config" if get_var('HUGEPAGES');
    mellanox_config();
    loadtest "kernel/mellanox_ofed" if get_var('OFED_URL');
    if (check_var("NFV", "master")) {
        load_nfv_master_tests();
    }
    elsif (check_var("NFV", "trafficgen")) {
        load_nfv_trafficgen_tests();
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

sub load_suseconnect_tests {
    prepare_target;
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest "console/suseconnect";
}

sub load_yast2_registration_tests {
    prepare_target;
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest "console/yast2_registration";
}

testapi::set_distribution(DistributionProvider->provide());

# set serial failures
$testapi::distri->set_expected_serial_failures(create_list_of_serial_failures());

return 1 if load_yaml_schedule;

if (is_jeos) {
    load_jeos_tests();
}

# load the tests in the right order
if (is_kernel_test()) {
    if (get_var('LTP_BAREMETAL') && get_var('INSTALL_LTP')) {
        load_baremetal_tests();
    }
    load_kernel_tests();
}
elsif (get_var('IBTESTS')) {
    load_baremetal_tests();
    load_infiniband_tests();
}
elsif (get_var("NFV")) {
    load_baremetal_tests();
    load_nfv_tests();
}
elsif (get_var("REGRESSION")) {
    load_common_x11;
    load_hypervisor_tests if (check_var("REGRESSION", "xen-hypervisor") || check_var("REGRESSION", "qemu-hypervisor"));
    load_suseconnect_tests        if check_var("REGRESSION", "suseconnect");
    load_yast2_registration_tests if check_var("REGRESSION", "yast2_registration");
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
elsif (get_var("SECURITY_TEST")) {
    prepare_target();
    load_security_tests;
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
    if (check_var('QA_TESTSET', 'kernel_kexec')) {
        loadtest 'kernel/kernel_kexec';
    }
    elsif (check_var('QA_TESTSET', 'kernel_multipath')) {
        loadtest 'qa_automation/kernel_multipath';
    }
    else {
        loadtest 'qa_automation/qa_run', name => get_required_var('QA_TESTSET');
    }
}
elsif (get_var("QA_TESTSUITE")) {
    boot_hdd_image;
    loadtest "qa_automation/prepare_qa_repo";
    loadtest "qa_automation/install_test_suite";
    loadtest "qa_automation/execute_test_run";
}
elsif (get_var("XFSTESTS")) {
    #Workaround bsc#1101787
    if (check_var('ARCH', 'aarch64') && check_var('VERSION', '12-SP4')) {
        set_var('NO_KDUMP', 1);
    }
    prepare_target;
    unless (get_var('NO_KDUMP')) {
        loadtest "xfstests/enable_kdump";
    }
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
        if (!check_var('ARCH', 's390x')) {
            load_boot_tests();
            if (get_var("AUTOYAST")) {
                loadtest "autoyast/installation";
                loadtest "virt_autotest/reboot_and_wait_up_normal";
            }
            else {
                load_inst_tests();
                loadtest "virt_autotest/login_console";
            }
        }
        elsif (check_var('ARCH', 's390x')) {
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
        }
        else {
            loadtest "virt_autotest/setup_kvm_serial_console";
        }
        loadtest "virt_autotest/reboot_and_wait_up_normal";
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
elsif (get_var("PERF_KERNEL")) {
    if (get_var("PERF_INSTALL")) {
        load_boot_tests();
        load_inst_tests();
    }
    elsif (get_var("PERF_SETUP")) {
        loadtest "virt_autotest/login_console";
        loadtest "kernel_performance/install_qatestset";
    }
    elsif (get_var("PERF_RUNCASE")) {
        loadtest "virt_autotest/login_console";
        loadtest "kernel_performance/run_perf_case";
    }
    elsif (get_var("PERF_FULLRUN")) {
        loadtest "virt_autotest/login_console";
        loadtest "kernel_performance/full_run";
    }
}
elsif (get_var("QAM_MINIMAL")) {
    prepare_target();
    loadtest "qam-minimal/install_update";
    loadtest "qam-minimal/update_minimal";
    loadtest "qam-minimal/check_logs";
    loadtest 'qam-minimal/s390tools' if check_var('BACKEND', 's390x');
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
elsif (get_var("INSTALLTEST")) {
    boot_hdd_image;
    loadtest "qam-updinstall/update_install";
}
elsif (get_var('LIBSOLV_INSTALLCHECK')) {
    boot_hdd_image;
    loadtest 'console/libsolv_installcheck';
}
elsif (get_var("EXTRATEST")) {
    boot_hdd_image;
    # update system with agregate repositories
    if (is_updates_tests) {
        loadtest "qa_automation/patch_and_reboot";
    }
    load_extra_tests();
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
        loadtest "console/yast2_scc";
    }
}
elsif (get_var('HPC')) {
    boot_hdd_image;
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    loadtest 'hpc/before_test';
    loadtest 'console/install_single_package' if (get_var('PACKAGETOINSTALL'));

    # load hpc multimachine scenario based on value of HPC variable
    # e.g 'hpc/$testsuite_[master|slave].pm'
    my $hpc_mm_scenario = get_var('HPC');
    loadtest "hpc/$hpc_mm_scenario" if $hpc_mm_scenario ne '1';
}
elsif (get_var('SYSTEMD_TESTSUITE')) {
    load_systemd_patches_tests;
}
elsif (get_var('VALIDATE_PCM_PATTERN')) {
    load_public_cloud_patterns_validation_tests;
}
else {
    if (get_var("SES_NODE")) {
        boot_hdd_image;
        if (get_var("DEEPSEA_TESTSUITE")) {
            loadtest "ses/nodes_preparation";
            loadtest "ses/deepsea_testsuite";
        }
        else {
            loadtest "console/hostname";
            loadtest "ses/nodes_preparation";
            loadtest "ses/deepsea_cluster_deploy";
            # OpenATTIC is only for <SES6
            loadtest "ses/openattic" if is_sle('<15');
        }
        return 1;
    }
    elsif (get_var('TEUTHOLOGY')) {
        boot_hdd_image;
        loadtest 'console/teuthology';
        loadtest 'console/pulpito';
        return 1;
    }
    elsif (get_var('GRUB2')) {
        boot_hdd_image;
        loadtest 'qa_automation/patch_and_reboot';
        loadtest 'boot/grub2_test';
        return 1;
    }
    elsif (get_var('AVOCADO') && check_var('BACKEND', 'ipmi')) {
        load_boot_tests;
        load_inst_tests;
        loadtest 'virt_autotest/login_console';
        loadtest 'console/avocado_prepare';
        my @test_groups = ('block_device_hotplug', 'cpu', 'disk_image', 'memory_hotplug', 'nic_hotplug', 'qmp', 'usb');
        for my $test_group (@test_groups) {
            loadtest 'console/avocado_run', name => "$test_group";
        }
        return 1;
    }
    elsif (check_var('BACKEND', 'ipmi') && get_var('MICROCODE_UPDATE')) {
        loadtest 'boot/boot_from_pxe';
        loadtest 'console/microcode_update';
        return 1;
    }
    elsif (get_var("QAM_OPENVPN")) {
        set_var('INSTALLONLY', 1);
        if (check_var('HOSTNAME', 'server')) {
            barrier_create('OPENVPN_STATIC_START',    2);
            barrier_create('OPENVPN_STATIC_STARTED',  2);
            barrier_create('OPENVPN_STATIC_FINISHED', 2);
            barrier_create('OPENVPN_CA_START',        2);
            barrier_create('OPENVPN_CA_STARTED',      2);
            barrier_create('OPENVPN_CA_FINISHED',     2);
        }
        boot_hdd_image;
        loadtest 'network/setup_multimachine';
        loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
        if (check_var('HOSTNAME', 'server')) {
            loadtest "network/openvpn_server";
        }
        else {
            loadtest "network/openvpn_client";
        }
    }
    elsif (get_var("QAM_SALT")) {
        set_var('INSTALLONLY', 1);
        if (check_var('HOSTNAME', 'master')) {
            barrier_create('SALT_MINIONS_READY', 2);
            barrier_create('SALT_FINISHED',      2);
        }
        boot_hdd_image;
        loadtest 'network/setup_multimachine';
        loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
        if (check_var('HOSTNAME', 'master')) {
            loadtest "network/salt_master";
        }
        else {
            loadtest "network/salt_minion";
        }
    }
    elsif (get_var("NFSSERVER") or get_var("NFSCLIENT")) {
        set_var('INSTALLONLY', 1);
        boot_hdd_image;
        #loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
        if (get_var("NFSSERVER")) {
            loadtest "console/yast2_nfs_server";
        }
        else {
            loadtest "console/yast2_nfs_client";
        }
    }
    elsif (get_var('QAM_VSFTPD')) {
        set_var('INSTALLONLY', 1);
        if (check_var('HOSTNAME', 'server')) {
            barrier_create('VSFTPD_SUITE_READY', 2);
            barrier_create('VSFTPD_FINISHED',    2);
        }
        boot_hdd_image;
        loadtest 'network/setup_multimachine';
        loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
        loadtest 'network/vsftpd';
    }
    elsif (get_var('AUTOFS')) {
        load_mm_autofs_tests;
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
            loadtest "console/system_prepare";
            loadtest "console/consoletest_setup";
            loadtest 'console/integration_services' if is_hyperv || is_vmware;
            loadtest "console/zypper_lr";
        }
    }
    elsif (get_var("BOOT_HDD_IMAGE") && !is_jeos) {
        load_bootloader_s390x();
        loadtest "boot/boot_to_desktop";
        if (get_var("ADDONS")) {
            loadtest "installation/addon_products_yast2";
        }
        if (get_var('SCC_ADDONS') && !get_var('SLENKINS_NODE')) {
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
    elsif (get_var("REMOTE_TARGET")) {
        load_boot_tests();
        loadtest "remote/remote_target";
    }
    elsif (get_var("KIWI_IMAGE_TESTS")) {
        loadtest "kiwi_images_test/kiwi_boot";
        loadtest "kiwi_images_test/login_reboot";
        loadtest "kiwi_images_test/validate_build";
    }
    elsif (get_var("FADUMP")) {
        prepare_target();
        loadtest "console/kdump_and_crash";
    }
    else {
        if (get_var('BOOT_EXISTING_S390')) {
            loadtest 'installation/boot_s390';
            loadtest 'boot/reconnect_mgmt_console';
            loadtest 'installation/first_boot';
        }
        elsif (!is_jeos) {
            return 1 if load_default_tests;
        }
    }
    # For virtualization testing we wan't to test some functionality, but not all of it
    if (check_var('VIRTUALIZATION_TESTING', 'short')) {
        load_consoletests;
        return 1;
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
