# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2017 SUSE LLC
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
use utils qw(is_hyperv_in_gui sle_version_at_least);
use File::Find;
use File::Basename;
use LWP::Simple 'head';

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

sub is_leanos {
    return get_var('FLAVOR', '') =~ /^Leanos/;
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

sub is_kgraft {
    return get_var('FLAVOR', '') =~ /^KGraft/;
}

sub is_updates_tests {
    my $flavor = get_required_var('FLAVOR');
    # Incidents might be also Incidents-Gnome or Incidents-Kernel
    return $flavor =~ /-Updates$/ || $flavor =~ /-Incidents/;
}

sub is_new_installation {
    return !get_var('UPGRADE') && !get_var('ONLINE_MIGRATION') && !get_var('ZDUP') && !get_var('AUTOUPGRADE');
}

sub is_update_test_repo_test {
    return get_var('TEST') !~ /^mru-/ && is_updates_tests;
}

sub is_bridged_networking {
    my $ret = 0;
    if (check_var('BACKEND', 'svirt') and !check_var('ARCH', 's390x')) {
        my $vmm_family = get_required_var('VIRSH_VMM_FAMILY');
        $ret = ($vmm_family =~ /xen|vmware|hyperv/);
    }
    # Some needles match hostname which we can't set permanently with bridge.
    set_var('BRIDGED_NETWORKING', 1) if $ret;
    return $ret;
}

sub default_desktop {
    return undef   if get_var('VERSION', '') lt '12';
    return 'gnome' if get_var('VERSION', '') lt '15';
    # with SLE 15 LeanOS only the default is textmode
    return 'gnome' if get_var('BASE_VERSION', '') =~ /^12/;
    # In sle15 we add repos manually to make a workaround of missing SCC, gnome will be installed as default system.
    return 'gnome' if get_var('ADDONURL', '') =~ /(desktop|server)/;
    return (get_var('SCC_REGISTER') && !check_var('SCC_REGISTER', 'installation')) ? 'textmode' : 'gnome';
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

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

diag('default desktop: ' . default_desktop);

# SLE specific variables
set_var('NOAUTOLOGIN', 1);
set_var('HASLICENSE',  1);
set_var('SLE_PRODUCT', get_var('SLE_PRODUCT', 'sles'));
set_var('DESKTOP',     get_var('DESKTOP', default_desktop));
# Always register against SCC if SLE 15
if (sle_version_at_least('15')) {
    set_var('SCC_REGISTER', get_var('SCC_REGISTER', 'installation'));
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
# TODO: remove when not used anymore
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
        # We already have needles with names which are different we would use here
        # As it's only workaround, better not to create another set of needles.
        my %modules = (
            base      => 'Basesystem',
            sdk       => 'Development-Tools',
            desktop   => 'Desktop-Applications',
            legacy    => 'Legacy',
            script    => 'Scripting',
            serverapp => 'Server-Applications'
        );
        my $addonurl;

        for my $short_name (@modules) {
            my $full_name = $modules{$short_name};
            my $repo_name = uc $full_name;
            # Replace dashes with underscore symbols
            $repo_name =~ s/-/_/;
            my $prefix = "SLE-$version";
            # Add staging prefix
            if (is_staging()) {
                $prefix .= "-Staging:" . get_var("STAGING");
            }
            my $module_repo_name = get_var("REPO_SLE${version}_MODULE_${repo_name}", "$prefix-Module-$full_name-POOL-$arch-Build$build-Media1");
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
if (is_update_test_repo_test && !get_var('MAINT_TEST_REPO')) {
    my %incidents;
    my %u_url;
    $incidents{OS} = get_var('OS_TEST_ISSUES',   '');
    $u_url{OS}     = get_var('OS_TEST_TEMPLATE', '');

    my @maint_repos;
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

    for my $a (keys %incidents) {
        for my $b (split(/,/, $incidents{$a})) {
            if ($b) {
                push @maint_repos, join($b, split('%INCIDENTNR%', $u_url{$a}));
            }
        }
    }

    my $repos = join(',', @maint_repos);
    # MAINT_TEST_REPO cannot start with ','
    $repos =~ s/^,//s;

    set_var('MAINT_TEST_REPO', $repos);
    set_var('SCC_REGISTER',    'installation');

    # slenkins test needs FOREIGN_REPOS
    if (get_var('TEST', '') =~ /^slenkins/) {
        set_var('FOREIGN_REPOS', $repos);
    }
}

if (get_var('ENABLE_ALL_SCC_MODULES') && !get_var('SCC_MODULES')) {
    if (sle_version_at_least('15')) {
        # Add only modules which are not pre-selected
        my $addons = (get_var('SCC_ADDONS') ? get_var('SCC_ADDONS') . ',' : '') . 'legacy,sdk';
        set_var('SCC_ADDONS', $addons);
        set_var('PATTERNS',   'default,asmm,pcm');
    }
    else {
        if (check_var('ARCH', 'aarch64')) {
            set_var('SCC_ADDONS', 'pcm,tcm');
            set_var('PATTERNS',   'default,pcm');
        }
        else {
            set_var('SCC_ADDONS', 'phub,asmm,contm,lgm,pcm,tcm,wsm');
            set_var('PATTERNS',   'default,asmm,pcm');
        }
    }
}

$needle::cleanuphandler = \&cleanup_needles;

# dump other important ENV:
logcurrentenv(
    qw(ADDONURL BTRFS DESKTOP LVM MOZILLATEST
      NOINSTALL UPGRADE USBBOOT ZDUP ZDUPREPOS TEXTMODE
      DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG
      QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE NETBOOT USEIMAGES
      SLE_PRODUCT SPLITUSR VIDEOMODE)
);


sub need_clear_repos {
    return get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ && get_var("SUSEMIRROR");
}

sub have_scc_repos {
    return check_var('SCC_REGISTER', 'console');
}

sub have_addn_repos {
    return
         !get_var("NET")
      && !get_var("EVERGREEN")
      && get_var("SUSEMIRROR")
      && !get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub rt_is_applicable {
    return is_server() && get_var("ADDONS", "") =~ /rt/;
}

sub we_is_applicable {
    return
         is_server()
      && (get_var("ADDONS", "") =~ /we/ or get_var("SCC_ADDONS", "") =~ /we/ or get_var("ADDONURL", "") =~ /we/)
      && get_var('MIGRATION_REMOVE_ADDONS', '') !~ /we/;
}

sub uses_qa_net_hardware {
    return check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw");
}

sub load_x11regression_firefox {
    loadtest "x11regressions/firefox/firefox_smoke";
    loadtest "x11regressions/firefox/firefox_localfiles";
    loadtest "x11regressions/firefox/firefox_emaillink";
    loadtest "x11regressions/firefox/firefox_urlsprotocols";
    loadtest "x11regressions/firefox/firefox_downloading";
    loadtest "x11regressions/firefox/firefox_extcontent";
    loadtest "x11regressions/firefox/firefox_headers";
    loadtest "x11regressions/firefox/firefox_pdf";
    loadtest "x11regressions/firefox/firefox_changesaving";
    loadtest "x11regressions/firefox/firefox_fullscreen";
    loadtest "x11regressions/firefox/firefox_health";
    loadtest "x11regressions/firefox/firefox_flashplayer";
    loadtest "x11regressions/firefox/firefox_java";
    loadtest "x11regressions/firefox/firefox_pagesaving";
    loadtest "x11regressions/firefox/firefox_private";
    loadtest "x11regressions/firefox/firefox_mhtml";
    loadtest "x11regressions/firefox/firefox_plugins";
    loadtest "x11regressions/firefox/firefox_extensions";
    loadtest "x11regressions/firefox/firefox_appearance";
    loadtest "x11regressions/firefox/firefox_gnomeshell";
    loadtest "x11regressions/firefox/firefox_passwd";
    loadtest "x11regressions/firefox/firefox_html5";
    loadtest "x11regressions/firefox/firefox_developertool";
    loadtest "x11regressions/firefox/firefox_rss";
    loadtest "x11regressions/firefox/firefox_ssl";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio";
    }
}

sub load_x11regression_message {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/empathy/empathy_aim";
        loadtest "x11regressions/empathy/empathy_irc";
        loadtest "x11regressions/evolution/evolution_smoke";
        loadtest "x11regressions/evolution/evolution_prepare_servers";
        loadtest "x11regressions/evolution/evolution_mail_imap";
        loadtest "x11regressions/evolution/evolution_mail_pop";
        loadtest "x11regressions/evolution/evolution_timezone_setup";
        loadtest "x11regressions/evolution/evolution_meeting_imap";
        loadtest "x11regressions/evolution/evolution_meeting_pop";
        loadtest "x11regressions/groupwise/groupwise";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/pidgin/prep_pidgin";
        loadtest "x11regressions/pidgin/pidgin_IRC";
        loadtest "x11regressions/pidgin/pidgin_aim";
        loadtest "x11regressions/pidgin/clean_pidgin";
    }
}

sub load_x11regression_remote {
    # load onetime vncsession testing
    if (check_var('REMOTE_DESKTOP_TYPE', 'one_time_vnc')) {
        loadtest 'x11regressions/remote_desktop/onetime_vncsession_xvnc_tigervnc';
        loadtest 'x11regressions/remote_desktop/onetime_vncsession_xvnc_java';
        loadtest 'x11regressions/remote_desktop/onetime_vncsession_multilogin_failed';
    }
    # load persistemt vncsession, x11 forwarding, xdmcp with gdm testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'persistent_vnc')) {
        loadtest 'x11regressions/remote_desktop/persistent_vncsession_xvnc';
        loadtest 'x11regressions/remote_desktop/x11_forwarding_openssh';
        loadtest 'x11regressions/remote_desktop/xdmcp_gdm';
    }
    # load xdmcp with xdm testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'xdmcp_xdm')) {
        loadtest 'x11regressions/remote_desktop/xdmcp_xdm';
    }
    # load vino testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'vino_server')) {
        loadtest 'x11regressions/remote_desktop/vino_server';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'vino_client')) {
        loadtest 'x11regressions/remote_desktop/vino_client';
    }
}

sub load_boot_tests {
    if (get_var("ISO_MAXSIZE")) {
        loadtest "installation/isosize";
    }
    if ((get_var("UEFI") || is_jeos()) && !check_var("BACKEND", "svirt")) {
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
        set_var("DELAYED_START", "1");
        loadtest "autoyast/pxe_boot";
    }
    else {
        loadtest "installation/bootloader";
    }
}

sub install_this_version {
    return !check_var('INSTALL_TO_OTHERS', 1);
}

sub load_inst_tests {
    loadtest "installation/welcome";
    if (get_var('DUD_ADDONS')) {
        loadtest "installation/dud_addon";
    }
    if (sle_version_at_least('15')) {
        loadtest "installation/accept_license" if get_var('HASLICENSE');
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
    if (check_var('SCC_REGISTER', 'installation')) {
        loadtest "installation/scc_registration";
    }
    else {
        loadtest "installation/skip_registration" unless check_var('SLE_PRODUCT', 'leanos');
    }
    if (is_sles4sap) {
        loadtest "installation/sles4sap_product_installation_mode";
    }
    if (get_var('MAINT_TEST_REPO')) {
        loadtest 'installation/add_update_test_repo';
    }
    loadtest "installation/addon_products_sle";
    if (noupdatestep_is_applicable()) {
        #system_role selection during installation was added as a new feature since sles12sp2
        #so system_role.pm should be loaded for all tests that actually install to versions over sles12sp2
        #no matter with or without INSTALL_TO_OTHERS tag
        if (   check_var('ARCH', 'x86_64')
            && sle_version_at_least('12-SP2')
            && is_server()
            && (!is_sles4sap() || is_sles4sap_standard())
            && (install_this_version() || install_to_other_at_least('12-SP2'))
            || sle_version_at_least('15') && !check_var('SLE_PRODUCT', 'leanos'))
        {
            loadtest "installation/system_role";
        }
        loadtest "installation/partitioning";
        if (defined(get_var("RAIDLEVEL"))) {
            loadtest "installation/partitioning_raid";
        }
        elsif (get_var("LVM")) {
            loadtest "installation/partitioning_lvm";
        }
        elsif (get_var('FULL_LVM_ENCRYPT')) {
            loadtest 'installation/partitioning_full_lvm';
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
        if (get_var("ENLARGESWAP") && get_var("QEMURAM", 1024) > 4098) {
            loadtest "installation/installation_enlargeswap";
        }

        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr";
        }
        if (get_var("IBFT")) {
            loadtest "installation/partitioning_iscsi";
        }
        if (uses_qa_net_hardware() || get_var('SELECT_FIRST_DISK') || get_var("ISO_IN_EXTERNAL_DRIVE")) {
            loadtest "installation/partitioning_firstdisk";
        }
        loadtest "installation/partitioning_finish";
    }
    # the VNC gadget is too unreliable to click, but we
    # need to be able to do installations on it. The release notes
    # functionality needs to be covered by other backends
    # Skip release notes test on sle 15 if have addons
    if (!check_var('BACKEND', 'generalhw') && !(sle_version_at_least('15') && get_var('ADDONURL'))) {
        loadtest "installation/releasenotes";
    }
    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_timezone";
        # the test should run only in scenarios, where installed
        # system is not being tested (e.g. INSTALLONLY etc.)
        if (    !consolestep_is_applicable()
            and !get_var("REMOTE_CONTROLLER")
            and !is_hyperv_in_gui
            and !check_var('BACKEND', 's390x')
            and sle_version_at_least('12-SP2'))
        {
            loadtest "installation/hostname_inst";
        }
        # Do not run on REMOTE_CONTROLLER, IPMI and on Hyper-V in GUI mode
        if (!get_var("REMOTE_CONTROLLER") && !check_var('BACKEND', 'ipmi') && !is_hyperv_in_gui) {
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
        if (get_var('PATTERNS') || get_var('PACKAGES')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns_and_packages";
        }
        elsif (!check_var('DESKTOP', default_desktop)) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/change_desktop";
        }
    }
    if (get_var("UEFI") && get_var("SECUREBOOT")) {
        loadtest "installation/secure_boot";
    }
    # for upgrades on s390 zKVM we need to change the static ip adress of the image to reboot properly
    if (check_var('BACKEND', 'svirt') && check_var('ARCH', 's390x') && get_var('UPGRADE')) {
        loadtest "installation/set_static_ip";
    }
    if (installyaststep_is_applicable()) {
        loadtest "installation/installation_overview";
        if (check_var('VIDEOMODE', 'text') && check_var('BACKEND', 'ipmi')) {
            loadtest "installation/disable_grub_graphics";
        }
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
    if (check_var('BACKEND', 'svirt') and check_var('ARCH', 's390x')) {
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

sub load_reboot_tests {
    # there is encryption passphrase prompt which is handled in installation/boot_encrypt
    if (check_var("ARCH", "s390x") && !(get_var('ENCRYPT') && check_var('BACKEND', 'svirt'))) {
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
            # reconnect after installation/boot_encrypt
            if (check_var('BACKEND', 'svirt') && check_var('ARCH', 's390x')) {
                loadtest "installation/reconnect_s390";
            }
        }
        loadtest "installation/first_boot";
    }
    if (get_var("DUALBOOT")) {
        loadtest "installation/reboot_eject_cd";
        loadtest "installation/boot_windows";
    }
}

sub load_consoletests {
    return unless consolestep_is_applicable();
    if (get_var("ADDONS", "") =~ /rt/) {
        loadtest "rt/kmp_modules";
    }
    loadtest "console/consoletest_setup";
    loadtest "console/force_cron_run" unless is_jeos;
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/check_locked_package";
    }
    loadtest "console/textinfo";
    loadtest "console/hostname" unless is_bridged_networking;
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
    }
    if (get_var("DESKTOP") !~ /textmode/ && !check_var("ARCH", "s390x")) {
        loadtest "console/xorg_vt";
    }
    loadtest "console/zypper_lr";
    loadtest 'console/enable_usb_repo' if check_var('USBBOOT', 1);
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
    loadtest "console/ncurses";
    loadtest "console/yast2_lan" unless is_bridged_networking;
    loadtest "console/curl_https";
    if (check_var_array('SCC_ADDONS', 'asmm')) {
        loadtest "console/puppet";
        loadtest "console/salt";
    }
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
    loadtest "console/mtab";

    if (is_new_installation && sle_version_at_least('12-SP2')) {
        loadtest "console/no_perl_bootloader";
    }
    if (!get_var("NOINSTALL") && !is_desktop && (check_var("DESKTOP", "textmode"))) {
        if (!is_staging() && check_var('BACKEND', 'qemu') && !is_jeos) {
            # The NFS test expects the IP to be 10.0.2.15
            loadtest "console/yast2_nfs_server";
        }
        loadtest "console/http_srv";
        loadtest "console/mysql_srv";
        loadtest "console/dns_srv";
        loadtest "console/postgresql96server";
        if (sle_version_at_least('12-SP1')) {    # shibboleth-sp not available on SLES 12 GA
            loadtest "console/shibboleth";
        }
        if (get_var('ADDONS', '') =~ /wsm/ || get_var('SCC_ADDONS', '') =~ /wsm/) {
            loadtest "console/pcre";
            if (!sle_version_at_least('15')) {
                loadtest "console/php5";
                loadtest "console/php5_mysql";
                loadtest "console/php5_postgresql96";
            }
            loadtest "console/php7";
            loadtest "console/php7_mysql";
            loadtest "console/php7_postgresql96";
        }
        loadtest "console/apache_ssl";
        loadtest "console/apache_nss";
    }
    if (check_var("DESKTOP", "xfce")) {
        loadtest "console/xfce_gnome_deps";
    }
    if (!is_staging() && sle_version_at_least('12-SP2')) {
        loadtest "console/zypper_lifecycle";
        if (check_var_array('SCC_ADDONS', 'tcm')) {
            loadtest "console/zypper_lifecycle_toolchain";
        }
    }
    loadtest 'console/install_all_from_repository' if get_var('INSTALL_ALL_REPO');
    if (check_var_array('SCC_ADDONS', 'tcm') && get_var('PATTERNS') && sle_version_at_least('12-SP3')) {
        loadtest "feature/feature_console/deregister";
    }
    loadtest "console/consoletest_finish";
}

sub load_x11tests {
    return
      unless (!get_var("INSTALLONLY")
        && is_desktop_installed()
        && !get_var("DUALBOOT")
        && !get_var("RESCUECD")
        && !get_var("HA_CLUSTER"));

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
    if (!is_server() || we_is_applicable()) {
        if (gnomestep_is_applicable()) {
            loadtest "x11/eog";
            loadtest "x11/rhythmbox";
            loadtest "x11/wireshark";
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
    loadtest "x11/glxgears";
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
    # Need to skip shutdown to keep backend alive if running rollback tests after migration
    unless (get_var('ROLLBACK_AFTER_MIGRATION')) {
        loadtest "x11/shutdown";
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
    return unless (get_var("HA_CLUSTER"));
    loadtest "ha/wait_support_server";
    loadtest "installation/first_boot";
    loadtest "console/consoletest_setup";
    loadtest "console/hostname" unless is_bridged_networking;
    loadtest "ha/firewall_disable";
    loadtest "ha/ntp_client";
    loadtest "ha/iscsi_client";
    loadtest "ha/watchdog";
    if (get_var("HA_CLUSTER_INIT")) {
        loadtest "ha/ha_cluster_init";    # Node1 creates a cluster
    }
    else {
        loadtest "ha/ha_cluster_join";    # Node2 joins the cluster
    }
    loadtest "ha/dlm";
    loadtest "ha/clvm";
    loadtest "ha/ocfs2";
    loadtest "ha/drbd";
    loadtest "ha/crm_mon";
    loadtest "ha/fencing";
    if (!get_var("HA_CLUSTER_JOIN")) {
        # Node1 will be fenced
        loadtest "ha/fencing_boot";
        loadtest "ha/fencing_consoletest_setup";
    }
    # Check_logs must be after ha/fencing
    loadtest "ha/check_logs";

    return 1;
}

sub load_virtualization_tests {
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

sub load_feature_tests {
    loadtest "console/consoletest_setup";
    loadtest "feature/feature_console/zypper_releasever";
    loadtest "feature/feature_console/suseconnect";
    loadtest "feature/feature_console/zypper_crit_sec_fix_only";
}

sub load_online_migration_tests {
    # stop packagekit service and more
    loadtest "online_migration/sle12_online_migration/online_migration_setup";
    loadtest "online_migration/sle12_online_migration/register_system";
    # do full/minimal update before migration
    if (get_var("FULL_UPDATE")) {
        loadtest "online_migration/sle12_online_migration/zypper_patch";
    }
    if (get_var("MINIMAL_UPDATE")) {
        loadtest "online_migration/sle12_online_migration/minimal_patch";
    }
    if (get_var('SCC_ADDONS', '') =~ /ltss/) {
        loadtest "online_migration/sle12_online_migration/register_without_ltss";
    }
    loadtest "online_migration/sle12_online_migration/pre_migration";
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/lock_package";
    }
    if (check_var("MIGRATION_METHOD", 'yast')) {
        loadtest "online_migration/sle12_online_migration/yast2_migration";
    }
    if (check_var("MIGRATION_METHOD", 'zypper')) {
        loadtest "online_migration/sle12_online_migration/zypper_migration";
    }
    loadtest "online_migration/sle12_online_migration/orphaned_packages_check";
    loadtest "online_migration/sle12_online_migration/post_migration";
}

sub load_patching_tests {
    if (check_var("ARCH", "s390x")) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/bootloader_s390";
        }
        else {
            loadtest "installation/bootloader_zkvm";
        }
    }
    loadtest 'boot/boot_to_desktop_sym';
    loadtest 'update/patch_before_migration';
    # Lock package for offline migration by Yast installer
    if (get_var('LOCK_PACKAGE') && !installzdupstep_is_applicable) {
        loadtest 'console/lock_package';
    }
    loadtest 'console/consoletest_finish_sym';
    loadtest 'x11/reboot_and_install';
    loadtest 'installation/bootloader_zkvm_sym' if get_var('S390_ZKVM');
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

# load the tests in the right order
if (maybe_load_kernel_tests()) {
}
elsif (get_var("WICKED")) {
    boot_hdd_image();
    load_wicked_tests();
}
elsif (get_var("REGRESSION")) {
    if (check_var("REGRESSION", "installation")) {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
        loadtest "x11regressions/x11regressions_setup";
        loadtest "console/hostname" unless is_bridged_networking;
        loadtest "console/force_cron_run" unless is_jeos;
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
    elsif (check_var('REGRESSION', 'remote')) {
        loadtest 'boot/boot_to_desktop';
        load_x11regression_remote();
    }
    elsif (check_var("REGRESSION", "piglit")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11regressions/piglit/piglit";
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
    loadtest "support_server/login";
    loadtest "support_server/setup";
    loadtest "ha/barrier_init" if get_var("HA_CLUSTER_SUPPORT_SERVER");
    unless (load_slenkins_tests()) {
        loadtest "support_server/wait";
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
elsif (get_var("HA_CLUSTER")) {
    load_ha_cluster_tests();
}
elsif (get_var("QA_TESTSET")) {
    if (get_var('INSTALL_KOTD')) {
        loadtest 'kernel/install_kotd';
    }
    if (get_var('MAINT_TEST_REPO')) {
        loadtest "qa_automation/patch_and_reboot";
    }
    loadtest "qa_automation/" . get_var("QA_TESTSET");
}
elsif (get_var("XFSTESTS")) {
    loadtest "qa_automation/xfstests_prepare_boot";
    loadtest "qa_automation/xfstests_prepare_testsuite";
    if (get_var("XFSTESTS_KNOWN_ISSUE")) {
        loadtest "qa_automation/xfstests_prepare_issue_case";
    }
    loadtest "qa_automation/xfstests_prepare_env";
    loadtest "qa_automation/xfstests_run_generic";
    loadtest "qa_automation/xfstests_run_shared";
    if (check_var("TEST_FS_TYPE", "xfs")) {
        loadtest "qa_automation/xfstests_run_xfs";
    }
    elsif (check_var("TEST_FS_TYPE", "btrfs")) {
        loadtest "qa_automation/xfstests_run_btrfs";
    }
    elsif (check_var("TEST_FS_TYPE", "ext4")) {
        loadtest "qa_automation/xfstests_run_ext4";
    }
    if (get_var("XFSTESTS_KNOWN_ISSUE")) {
        loadtest "qa_automation/xfstests_run_issue_case";
    }
}
elsif (get_var("VIRT_AUTOTEST")) {
    if (get_var("PROXY_MODE")) {
        loadtest "virt_autotest/proxymode_login_proxy";
        loadtest "virt_autotest/proxymode_init_pxe_install";
        loadtest "virt_autotest/proxymode_redirect_serial1";
        loadtest "virt_autotest/install_package";
        if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
            loadtest "virt_autotest/reboot_and_wait_up_normal1";
        }
        loadtest "virt_autotest/update_package";
        loadtest "virt_autotest/reboot_and_wait_up_normal2";
    }
    else {
        load_boot_tests();
        if (get_var("AUTOYAST")) {
            loadtest "autoyast/installation";
            loadtest "virt_autotest/reboot_and_wait_up_normal4";
        }
        else {
            load_inst_tests();
            loadtest "virt_autotest/login_console";
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
            loadtest "virt_autotest/setup_xen_serial_console";
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
elsif (is_kgraft) {
    loadtest "qam-kgraft/update_kgraft";
    loadtest "qam-kgraft/regressions_tests";
    loadtest "qam-kgraft/reboot_restore";
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
elsif (get_var('ISO_IN_EXTERNAL_DRIVE')) {
    load_iso_in_external_tests();
    load_inst_tests();
    load_reboot_tests();
}
elsif (get_var('HPC')) {
    if (check_var('HPC', 'install')) {
        load_boot_tests();
        load_inst_tests();
        load_reboot_tests();
    }
    else {
        loadtest 'boot/boot_to_desktop';
        if (check_var('HPC', 'enable')) {
            loadtest 'hpc/enable_in_zypper';
        }
        elsif (check_var('HPC', 'conman')) {
            loadtest 'hpc/conman';
        }
        elsif (check_var('HPC', 'powerman')) {
            loadtest 'console/hostname';
            loadtest 'hpc/powerman';
        }
        elsif (check_var('HPC', 'hwloc') && sle_version_at_least('12-SP2')) {
            loadtest 'console/hwloc_testsuite';
        }
        else {
            loadtest 'console/install_all_from_repository' if (get_var('INSTALL_ALL_REPO'));
            loadtest 'console/install_single_package'      if (get_var('PACKAGETOINSTALL'));

            # load hpc multimachine scenario based on value of HPC variable
            # e.g 'hpc/$testsuite_[master|slave].pm'
            my $hpc_mm_scenario = get_var('HPC');
            loadtest "hpc/$hpc_mm_scenario" if $hpc_mm_scenario ne '1';
        }
    }
}
else {
    if (get_var("AUTOYAST") || get_var("AUTOUPGRADE")) {
        if (get_var('PATCH')) {
            load_patching_tests();
        }
        else {
            load_boot_tests();
        }
        load_autoyast_tests();
        load_reboot_tests();
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
    elsif (get_var("PATCH")) {
        load_patching_tests();
        load_inst_tests();
        load_reboot_tests();
    }
    elsif (get_var("BOOT_HDD_IMAGE")) {
        if (get_var("RT_TESTS")) {
            set_var('INSTALLONLY', 1);
            loadtest "rt/boot_rt_kernel";
        }
        else {
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
            if (get_var("REMOTE_CONTROLLER")) {
                loadtest "remote/remote_controller";
                load_inst_tests();
            }
        }
    }
    elsif (get_var("REMOTE_TARGET")) {
        load_boot_tests();
        loadtest "remote/remote_target";
        loadtest "installation/first_boot";
    }
    elsif (is_jeos) {
        load_boot_tests();
        loadtest "jeos/firstrun";
        loadtest "console/force_cron_run";
        loadtest "jeos/grub2_gfxmode";
        loadtest 'jeos/revive_xen_domain' if check_var('VIRSH_VMM_FAMILY', 'xen');
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
            return 1 if get_var('EXIT_AFTER_START_INSTALL');
            load_reboot_tests();
        }
    }
    unless (load_applicationstests() || load_slenkins_tests()) {
        load_rescuecd_tests();
        load_consoletests();
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
        # temporary adding test modules which applies hacks for missing parts in sle15
        loadtest "console/sle15_workarounds" if sle_version_at_least('15');
        loadtest "console/hostname" unless is_bridged_networking;
        loadtest "console/force_cron_run" unless is_jeos;
        loadtest "shutdown/grub_set_bootargs";
        loadtest "shutdown/shutdown";
        if (check_var("BACKEND", "svirt")) {
            loadtest "shutdown/svirt_upload_assets";
        }
    }
}

if (get_var("TCM") || check_var("ADDONS", "tcm")) {
    loadtest "console/force_cron_run";
    loadtest "toolchain/install";
    loadtest "toolchain/gcc5_fortran_compilation";
    loadtest "toolchain/gcc_compilation";
    loadtest "console/kdump_and_crash" if kdump_is_applicable;
}

1;
# vim: set sw=4 et:
