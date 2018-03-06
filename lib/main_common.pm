# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Attempt to merge common parts of sle/main.pm and opensuse/main.pm
# Maintainer: Anton Smorodskyi<asmorodskyi@suse.com>

package main_common;
use base Exporter;
use File::Basename;
use Exporter;
use testapi qw(check_var get_var get_required_var set_var check_var_array diag);
use autotest;
use utils;
use version_utils qw(
  is_hyperv_in_gui is_jeos is_gnome_next is_krypton_argon is_leap is_opensuse is_sle is_sles4sap is_sles4sap_standard leap_version_at_least sle_version_at_least is_desktop_installed is_installcheck is_rescuesystem is_staging is_tumbleweed
);
use bmwqemu ();
use strict;
use warnings;

our @EXPORT = qw(
  init_main
  loadtest
  load_testdir
  set_defaults_for_username_and_password
  setup_env
  logcurrentenv
  default_desktop
  is_desktop
  is_livesystem
  is_memtest
  is_mediacheck
  is_server
  is_sles4sap
  is_sles4sap_standard
  need_clear_repos
  have_scc_repos
  load_svirt_vm_setup_tests
  load_inst_tests
  load_svirt_boot_tests
  load_boot_tests
  load_reboot_tests
  load_rescuecd_tests
  load_zdup_tests
  load_autoyast_tests
  load_autoyast_clone_tests
  load_slepos_tests
  load_docker_tests
  load_sles4sap_tests
  installzdupstep_is_applicable
  snapper_is_applicable
  chromestep_is_applicable
  chromiumstep_is_applicable
  gnomestep_is_applicable
  installyaststep_is_applicable
  noupdatestep_is_applicable
  kdestep_is_applicable
  kdump_is_applicable
  consolestep_is_applicable
  rescuecdstep_is_applicable
  bootencryptstep_is_applicable
  we_is_applicable
  remove_common_needles
  remove_desktop_needles
  check_env
  ssh_key_import
  unregister_needle_tags
  any_desktop_is_applicable
  console_is_applicable
  boot_hdd_image
  is_kernel_test
  load_kernel_tests
  load_bootloader_s390x
  load_consoletests
  load_x11tests
  load_yast2_ncurses_tests
  load_yast2_gui_tests
  load_extra_tests
  load_rollback_tests
  load_filesystem_tests
  load_wicked_tests
  load_networkd_tests
  load_nfv_master_tests
  load_nfv_trafficgen_tests
  load_common_installation_steps_tests
  load_iso_in_external_tests
  load_x11_documentation
  load_x11_gnome
  load_x11_other
  load_common_x11
  load_security_tests_core
  load_security_tests_web
  load_security_tests_misc
  load_security_tests_crypt
  load_systemd_patches_tests
  load_create_hdd_tests
  load_virtualization_tests
  is_memtest
  is_mediacheck
  load_syscontainer_tests
  load_toolchain_tests
  load_common_opensuse_sle_tests
  replace_opensuse_repos_tests
  load_ssh_key_import_tests
);

sub init_main {
    set_defaults_for_username_and_password();
    setup_env();
    check_env();
}

sub loadtest {
    my ($test) = @_;
    autotest::loadtest("tests/$test.pm");
}

sub load_testdir {
    my ($testsuite) = @_;
    my $testdir = testapi::get_required_var('CASEDIR') . "/tests/$testsuite";
    map { loadtest "$testsuite/" . basename($_, '.pm') } glob("$testdir/*.pm");
}

sub set_defaults_for_username_and_password {
    if (get_var("LIVETEST")) {
        $testapi::username = "root";
        $testapi::password = '';
    }
    else {
        if (get_var('FLAVOR', '') =~ /SAP/ or get_var('SLE_PRODUCT', '') =~ /sles4sap/) {
            $testapi::username = "root";    #in sles4sap only root user created
        }
        else {
            $testapi::username = "bernhard";
        }
        $testapi::password = "nots3cr3t";
    }

    $testapi::username = get_var("USERNAME") if get_var("USERNAME");
    $testapi::password = get_var("PASSWORD") if defined get_var("PASSWORD");

    if (get_var("LIVETEST") && (get_var("LIVECD") || get_var("PROMO"))) {
        $testapi::username = "linux";       # LiveCD account
        $testapi::password = "";
    }
}

sub setup_env {
    # Tests currently rely on INSTLANG=en_US, so set it by default
    unless (get_var('INSTLANG')) {
        set_var('INSTLANG', 'en_US');
    }

    if (get_var('UEFI') && !check_var('ARCH', 'aarch64')) {
        # avoid having to update all job templates, but newer qemu
        # BIOS wants to have the bios passed differently
        # https://github.com/os-autoinst/os-autoinst/pull/377
        # Does _not_ work on aarch64
        set_var('UEFI_PFLASH', 1);
    }
}

sub any_desktop_is_applicable {
    return get_var("DESKTOP") !~ /textmode/;
}

sub console_is_applicable {
    return !any_desktop_is_applicable();
}

sub logcurrentenv {
    for my $k (@_) {
        my $e = get_var("$k");
        next unless defined $e;
        diag("usingenv $k=$e");
    }
}

sub have_addn_repos {
    return
         !get_var("NET")
      && !get_var("EVERGREEN")
      && get_var("SUSEMIRROR")
      && !get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/;
}

sub is_livesystem {
    return (check_var("FLAVOR", 'Rescue-CD') || get_var("LIVETEST"));
}

sub is_kde_live {
    return get_var('FLAVOR', '') =~ /KDE-Live/;
}

sub packagekit_available {
    return !check_var('FLAVOR', 'Rescue-CD');
}

sub is_kernel_test {
    return ( get_var('INSTALL_LTP')
          || get_var('LTP_SETUP_NETWORKING')
          || get_var('LTP_COMMAND_FILE')
          || get_var('INSTALL_KOTD')
          || get_var('QA_TEST_KLP_REPO')
          || get_var('INSTALL_KOTD')
          || get_var('VIRTIO_CONSOLE_TEST'));
}

# Isolate the loading of LTP tests because they often rely on newer features
# not present on all workers. If they are isolated then only the LTP tests
# will fail to load when there is a version mismatch instead of all tests.
{
    local $@;

    eval 'use main_ltp;';
    if ($@) {
        bmwqemu::fctwarn("Failed to load main_ltp.pm:\n$@", 'main_common.pm');
        eval q%
            sub load_kernel_tests {
                if (is_kernel_test())
                {
                    die "Can not run kernel tests because evaluating main_ltp.pm failed";
                }
                return 0;
            }
        %;
    }
}

sub replace_opensuse_repos_tests {
    loadtest "update/zypper_clear_repos";
    loadtest "console/zypper_ar";
}

sub is_memtest {
    return get_var('MEMTEST');
}

sub is_mediacheck {
    return get_var('MEDIACHECK');
}

sub is_server {
    return 1 if is_sles4sap();
    return 1 if get_var('FLAVOR', '') =~ /^Server/;
    return 0 unless is_leanos();
    return check_var('SLE_PRODUCT', 'sles');
}

sub is_desktop {
    return get_var('FLAVOR', '') =~ /^Desktop/ || check_var('SLE_PRODUCT', 'sled');
}

sub is_leanos {
    return 1 if get_var('FLAVOR', '') =~ /^Leanos/;
    return 1 if get_var('FLAVOR', '') =~ /^Installer-/;
    return 0;
}

sub is_desktop_module_selected {
    # desktop applications module is selected if following variables have following values:
    # productivity and ha require desktop applications, so it's preselected
    # same is true for sles4sap
    return
         get_var('ADDONS', '') =~ /all-packages|desktop|we/
      || get_var('WORKAROUND_MODULES', '') =~ /desktop|we/
      || get_var('ADDONURL',           '') =~ /desktop|we/
      || get_var('SCC_ADDONS',         '') =~ /desktop|we|productivity|ha/
      || is_sles4sap;
}

sub default_desktop {
    return undef   if get_var('VERSION', '') lt '12';
    return 'gnome' if get_var('VERSION', '') lt '15';
    # with SLE 15 LeanOS only the default is textmode
    return 'gnome' if get_var('BASE_VERSION', '') =~ /^12/;
    return 'textmode' if (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'));
    return 'gnome' if is_desktop_module_selected;
    # default system role for sles and sled
    return 'textmode' if is_server || !get_var('SCC_REGISTER') || !check_var('SCC_REGISTER', 'installation');
    # remaining cases are is_desktop and check_var('SCC_REGISTER', 'installation'), hence gnome
    return 'gnome';
}

sub uses_qa_net_hardware {
    return check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw");
}

sub load_svirt_boot_tests {
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

sub load_svirt_vm_setup_tests {
    return unless check_var('BACKEND', 'svirt');
    if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
        loadtest "installation/bootloader_hyperv";
    }
    else {
        loadtest "installation/bootloader_svirt";
    }
    unless (is_installcheck || is_memtest || is_rescuesystem || is_mediacheck) {
        load_svirt_boot_tests;
    }
}

sub load_boot_tests {
    # s390x uses only remote repos
    if (get_var("ISO_MAXSIZE") && !check_var('ARCH', 's390x')) {
        loadtest "installation/isosize";
    }
    if ((get_var("UEFI") || is_jeos()) && !check_var("BACKEND", "svirt")) {
        loadtest "installation/bootloader_uefi";
    }
    elsif (check_var("BACKEND", "svirt") && !check_var("ARCH", "s390x")) {
        load_svirt_vm_setup_tests;
    }
    elsif (uses_qa_net_hardware()) {
        loadtest "boot/boot_from_pxe";
    }
    elsif (get_var("PXEBOOT")) {
        set_var("DELAYED_START", "1");
        loadtest "autoyast/pxe_boot";
    }
    else {
        loadtest "installation/bootloader" unless load_bootloader_s390x();
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

sub load_rescuecd_tests {
    if (rescuecdstep_is_applicable()) {
        loadtest "rescuecd/rescuecd";
    }
}

sub load_autoyast_clone_tests {
    loadtest "console/consoletest_setup";
    # Remove repos pointing to download.opensuse.org and add snaphot repo from o3
    if (check_var('DISTRI', 'opensuse')) {
        replace_opensuse_repos_tests;
    }
    loadtest "console/yast2_clone_system";
    loadtest "console/consoletest_finish";
}

sub load_zdup_tests {
    loadtest 'installation/setup_zdup';
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/lock_package";
    }
    loadtest 'installation/zdup';
    loadtest 'installation/post_zdup';
    # Restrict version switch to sle until opensuse adopts it
    loadtest "migration/version_switch_upgrade_target" if is_sle and get_var("UPGRADE_TARGET_VERSION");
    loadtest 'boot/boot_to_desktop';
}

sub load_autoyast_tests {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation");
    loadtest("autoyast/console");
    loadtest("autoyast/login");
    loadtest("autoyast/wicked");
    loadtest("autoyast/autoyast_verify") if get_var("AUTOYAST_VERIFY");
    loadtest('autoyast/' . get_var("AUTOYAST_VERIFY_MODULE")) if get_var("AUTOYAST_VERIFY_MODULE");
    if (get_var("SUPPORT_SERVER_GENERATOR")) {
        loadtest("support_server/configure");
    }
    else {
        loadtest("autoyast/repos");
        loadtest("autoyast/clone");
        if (get_var('SP3ORLATER') && check_var('FILESYSTEM', 'btrfs')) {
            loadtest "autoyast/verify_autoinst_btrfs";
        }
        loadtest("autoyast/logs");
    }
    if (get_var('SP3ORLATER') && check_var('FILESYSTEM', 'btrfs')) {
        loadtest "autoyast/verify_btrfs";
    }
    loadtest("autoyast/autoyast_reboot");
    #    next boot in load_reboot_tests
}

sub load_slepos_tests {
    if (get_var("SLEPOS") =~ /^adminserver/) {
        loadtest("boot/boot_to_desktop");
        loadtest "slepos/prepare";
        loadtest "slepos/zypper_add_repo";
        loadtest "slepos/zypper_install_adminserver";
        loadtest "slepos/run_posInitAdminserver";
        loadtest "slepos/zypper_install_imageserver";
        loadtest "slepos/use_smt_for_kiwi";
        loadtest "slepos/build_images_kiwi";
        loadtest "slepos/register_images";
        loadtest "slepos/build_offline_image_kiwi";
        loadtest "slepos/wait";
    }
    elsif (get_var("SLEPOS") =~ /^branchserver/) {
        loadtest("boot/boot_to_desktop");
        loadtest "slepos/prepare";
        loadtest "slepos/zypper_add_repo";
        loadtest "slepos/zypper_install_branchserver";
        loadtest "slepos/run_posInitBranchserver";
        loadtest "slepos/run_possyncimages";
        loadtest "slepos/wait";
    }
    elsif (get_var("SLEPOS") =~ /^imageserver/) {
        loadtest("boot/boot_to_desktop");
        loadtest "slepos/prepare";
        loadtest "slepos/zypper_add_repo";
        loadtest "slepos/zypper_install_imageserver";
        loadtest "slepos/use_smt_for_kiwi";
        loadtest "slepos/build_images_kiwi";
    }
    elsif (get_var("SLEPOS") =~ /^terminal-online/) {
        set_var("DELAYED_START", "1");
        loadtest "slepos/boot_image";
    }
    elsif (get_var("SLEPOS") =~ /^terminal-offline/) {
        loadtest "slepos/boot_image";
    }
}

sub load_docker_tests {
    loadtest "console/docker";
    loadtest "console/docker_runc";
    # No package 'docker-compose' in SLE
    if (!is_sle) {
        loadtest "console/docker_compose";
    }
    if (is_sle('<15')) {
        loadtest "console/sle2docker";
    }
}

sub installzdupstep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && get_var("ZDUP");
}

sub snapper_is_applicable {
    my $fs = get_var("FILESYSTEM", 'btrfs');
    return ($fs eq "btrfs" && get_var("HDDSIZEGB", 10) > 10);
}

sub chromestep_is_applicable {
    return is_opensuse && (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'));
}

sub chromiumstep_is_applicable {
    return chromestep_is_applicable();
}

sub gnomestep_is_applicable {
    return check_var("DESKTOP", "gnome");
}

sub installyaststep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && !get_var("ZDUP");
}

sub kdestep_is_applicable {
    return check_var("DESKTOP", "kde");
}

# kdump is not supported on aarch64 (bsc#990418), and Xen PV (feature not implemented)
sub kdump_is_applicable {
    return !check_var('ARCH', 'aarch64') && !check_var('VIRSH_VMM_TYPE', 'linux');
}

sub consolestep_is_applicable {
    return !get_var("INSTALLONLY") && !get_var("DUALBOOT") && !get_var("RESCUECD") && !is_gnome_next && !is_krypton_argon;
}

sub rescuecdstep_is_applicable {
    return get_var("RESCUECD");
}

sub ssh_key_import {
    return get_var("SSH_KEY_IMPORT") || get_var("SSH_KEY_DO_NOT_IMPORT");
}

sub we_is_applicable {
    return
         is_server()
      && (get_var("ADDONS", "") =~ /we/ or get_var("SCC_ADDONS", "") =~ /we/ or get_var("ADDONURL", "") =~ /we/)
      && get_var('MIGRATION_REMOVE_ADDONS', '') !~ /we/;
}

sub installwithaddonrepos_is_applicable {
    return get_var("HAVE_ADDON_REPOS") && !get_var("UPGRADE") && !get_var("NET");
}

sub need_clear_repos {
    return (is_opensuse && is_staging()) || (is_sle && get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ && get_var("SUSEMIRROR"));
}

sub have_scc_repos {
    return check_var('SCC_REGISTER', 'console');
}

sub rt_is_applicable {
    return is_server() && get_var("ADDONS", "") =~ /rt/;
}

sub xfcestep_is_applicable {
    return check_var("DESKTOP", "xfce");
}

sub lxdestep_is_applicable {
    return check_var("DESKTOP", "lxde");
}

sub is_smt {
    # Smt is replaced with rmt in SLE 15, see bsc#1061291
    return ((get_var("PATTERNS", '') || get_var('HDD_1', '')) =~ /smt/) && !sle_version_at_least('15');
}

sub remove_common_needles {
    my $no_skipto = get_var('SKIPTO') ? 0 : 1;
    unregister_needle_tags("ENV-SKIPTO-$no_skipto");
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
    if (!check_var('ARCH', 's390x')) {
        unregister_needle_tags('ENV-ARCH-s390x');
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }
}

sub remove_desktop_needles {
    my $desktop = shift;
    if (!check_var("DESKTOP", $desktop) && !check_var("FULL_DESKTOP", $desktop)) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES  => [0, 1],
    USEIMAGES => [0, 1],
    DOCRUN    => [0, 1],

    #   BTRFS=>[0,1],
    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode)],

    #   ROOTFS=>[qw(ext3 xfs jfs btrfs reiserfs)],
    VIDEOMODE => ["", "text", "ssh-x"],
);

sub check_env {
    for my $k (keys %valueranges) {
        next unless get_var($k);
        unless (grep { get_var($k) eq $_ } @{$valueranges{$k}}) {
            die sprintf("%s must be one of %s\n", $k, join(',', @{$valueranges{$k}}));
        }
    }
}

sub unregister_needle_tags {
    my ($tag) = @_;
    my @a = @{needle::tags($tag)};
    for my $n (@a) { $n->unregister($tag); }
}

sub install_this_version {
    return !check_var('INSTALL_TO_OTHERS', 1);
}

sub load_bootloader_s390x {
    return 0 unless check_var("ARCH", "s390x");

    if (check_var("BACKEND", "s390x")) {
        loadtest "installation/bootloader_s390";
    }
    else {
        loadtest "installation/bootloader_zkvm";
    }
    return 1;
}

sub boot_hdd_image {
    get_required_var('BOOT_HDD_IMAGE');
    if (check_var("BACKEND", "svirt")) {
        loadtest "installation/bootloader_svirt" unless load_bootloader_s390x();
    }
    if (get_var('UEFI') && (get_var('BOOTFROM') || get_var('BOOT_HDD_IMAGE'))) {
        loadtest "boot/uefi_bootmenu";
    }
    loadtest "support_server/wait_support_server" if get_var('USE_SUPPORT_SERVER');
    loadtest "boot/boot_to_desktop";
}

sub load_common_installation_steps_tests {
    loadtest 'installation/await_install';
    loadtest 'installation/logs_from_installation_system';
    loadtest 'installation/reboot_after_installation';
}

sub load_inst_tests {
    loadtest "installation/welcome";
    loadtest "installation/keyboard_selection";
    if (get_var('DUD_ADDONS')) {
        loadtest "installation/dud_addon";
    }
    if (is_sle '15+') {
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
    if (is_opensuse && noupdatestep_is_applicable() && !get_var("LIVECD")) {
        loadtest "installation/installation_mode";
    }
    if (!get_var("LIVECD") && get_var("UPGRADE")) {
        loadtest "installation/upgrade_select";
        if (check_var("UPGRADE", "LOW_SPACE")) {
            loadtest "installation/disk_space_fill";
        }
        loadtest "installation/upgrade_select_opensuse" if is_opensuse;
    }
    if (is_sle) {
        loadtest 'installation/network_configuration' if get_var('NETWORK_CONFIGURATION');
        # SCC registration is not required in media based upgrade since SLE15
        unless (sle_version_at_least('15') && get_var('MEDIA_UPGRADE')) {
            if (check_var('SCC_REGISTER', 'installation')) {
                loadtest "installation/scc_registration";
            }
            else {
                loadtest "installation/skip_registration" unless check_var('SLE_PRODUCT', 'leanos');
            }
        }
        if (is_sles4sap and !sle_version_at_least('15')) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        if (get_var('MAINT_TEST_REPO')) {
            loadtest 'installation/add_update_test_repo';
        }
        loadtest "installation/addon_products_sle";
    }
    if (noupdatestep_is_applicable()) {
        # Krypton/Argon disable the network configuration stage
        if (get_var("LIVECD") && !is_krypton_argon) {
            loadtest "installation/livecd_network_settings";
        }
        #system_role selection during installation was added as a new feature since sles12sp2
        #so system_role.pm should be loaded for all tests that actually install to versions over sles12sp2
        #no matter with or without INSTALL_TO_OTHERS tag
        if (
            is_sle
            && (   check_var('ARCH', 'x86_64')
                && sle_version_at_least('12-SP2')
                && is_server()
                && (!is_sles4sap() || is_sles4sap_standard())
                && (install_this_version() || install_to_other_at_least('12-SP2'))
                || sle_version_at_least('15')))
        {
            loadtest "installation/system_role";
        }
        if (is_sles4sap() and sle_version_at_least('15') and check_var('SYSTEM_ROLE', 'default')) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        loadtest "installation/partitioning";
        if (defined(get_var("RAIDLEVEL"))) {
            loadtest "installation/partitioning_raid";
        }
        elsif (check_var('LVM', 0) && get_var('ENCRYPT')) {
            loadtest 'installation/partitioning_crypt_no_lvm';
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
        if (get_var("EXPERTPARTITIONER")) {
            loadtest "installation/partitioning_expert";
        }
        if (get_var("ENLARGESWAP") && get_var("QEMURAM", 1024) > 4098) {
            loadtest "installation/installation_enlargeswap";
        }

        if (get_var("SPLITUSR")) {
            loadtest "installation/partitioning_splitusr";
        }
        if (get_var("DELETEWINDOWS")) {
            loadtest "installation/partitioning_guided";
        }
        if (get_var("IBFT")) {
            loadtest "installation/partitioning_iscsi";
        }
        if (uses_qa_net_hardware() || get_var('SELECT_FIRST_DISK') || get_var("ISO_IN_EXTERNAL_DRIVE")) {
            loadtest "installation/partitioning_firstdisk";
        }
        loadtest "installation/partitioning_finish";
    }
    if (is_opensuse && addon_products_is_applicable() && !leap_version_at_least('42.3')) {
        loadtest "installation/addon_products";
    }
    # the VNC gadget is too unreliable to click, but we
    # need to be able to do installations on it. The release notes
    # functionality needs to be covered by other backends
    # Skip release notes test on sle 15 if have addons
    if (is_sle && !check_var('BACKEND', 'generalhw') && !check_var('BACKEND', 'ipmi') && !(sle_version_at_least('15') && get_var('ADDONURL'))) {
        loadtest "installation/releasenotes";
    }

    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_timezone";
        if (installwithaddonrepos_is_applicable() && !get_var("LIVECD")) {
            loadtest "installation/setup_online_repos";
        }
        # the test should run only in scenarios, where installed
        # system is not being tested (e.g. INSTALLONLY etc.)
        # The test also won't work reliably when network is bridged (non-s390x svirt).
        if (    !consolestep_is_applicable()
            and !get_var("REMOTE_CONTROLLER")
            and !is_hyperv_in_gui
            and !is_bridged_networking
            and !check_var('BACKEND', 's390x')
            and is_sle('12-SP2+'))
        {
            loadtest "installation/hostname_inst";
        }
        # Do not run on REMOTE_CONTROLLER, IPMI and on Hyper-V in GUI mode
        if (!get_var("REMOTE_CONTROLLER") && !check_var('BACKEND', 'ipmi') && !is_hyperv_in_gui && !get_var("LIVECD")) {
            loadtest "installation/logpackages";
        }
        loadtest "installation/disable_online_repos" if get_var('DISABLE_ONLINE_REPOS');
        loadtest "installation/installer_desktopselection" if is_opensuse;
        if (is_sles4sap()) {
            if (
                is_sles4sap_standard()    # Schedule module only for SLE15 with non-default role
                || sle_version_at_least('15') && get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'))
            {
                loadtest "installation/user_settings";
            }    # sles4sap wizard installation doesn't have user_settings step
        }
        elsif (get_var('IMPORT_USER_DATA')) {
            loadtest 'installation/user_import';
        }
        else {
            loadtest "installation/user_settings";
        }
        if (is_sle || get_var("DOCRUN") || get_var("IMPORT_USER_DATA") || get_var("ROOTONLY")) {    # root user
            loadtest "installation/user_settings_root";
        }
        if (get_var('PATTERNS') || get_var('PACKAGES')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns_and_packages";
        }
        elsif (
            is_sle
            && (!check_var('DESKTOP', default_desktop)
                && (!sle_version_at_least('15') || check_var('DESKTOP', 'minimalx'))))
        {
            # With SLE15 we change desktop using role and not by unselecting packages (Use SYSTEM_ROLE variable),
            # If we have minimalx, as there is no such a role, there we use old approach
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
        # On Xen PV we don't have GRUB on VNC
        loadtest "installation/disable_grub_timeout" unless check_var('VIRSH_VMM_TYPE', 'linux');
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
    load_common_installation_steps_tests;
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
    replace_opensuse_repos_tests if get_var('DISABLE_ONLINE_REPOS');
    if (get_var('SYSTEM_ROLE', '') =~ /kvm|xen/) {
        loadtest "console/patterns";
    }
    if (snapper_is_applicable()) {
        if (get_var("UPGRADE")) {
            loadtest "console/upgrade_snapshots";
        }
        # zypper and sle12 doesn't do upgrade or installation snapshots
        # SLES4SAP default installation flow does not configure snapshots
        elsif (!get_var("ZDUP") and !check_var('VERSION', '12') and !is_sles4sap()) {
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
    # If DISABLE_ONLINE_REPOS, mirror repo is already added
    if (have_addn_repos && !get_var('DISABLE_ONLINE_REPOS')) {
        loadtest "console/zypper_ar";
    }
    loadtest "console/zypper_ref";
    loadtest "console/ncurses";
    loadtest "console/yast2_lan" unless is_bridged_networking;
    # no local certificate store
    if (!is_krypton_argon) {
        loadtest "console/curl_https";
    }
    if (is_sle && (check_var_array('SCC_ADDONS', 'asmm') && !sle_version_at_least('15'))
        || (check_var_array('SCC_ADDONS', 'phub') && sle_version_at_least('15')))
    {
        loadtest "console/puppet";
    }
    # salt in SLE is only available for SLE12 ASMM or SLES15 and variants of
    # SLES but not SLED
    if (!is_staging && (is_opensuse || (check_var_array('SCC_ADDONS', 'asmm') || (sle_version_at_least('15') && !is_desktop)))) {
        loadtest "console/salt";
    }
    if (   check_var('ARCH', 'x86_64')
        || check_var('ARCH', 'i686')
        || check_var('ARCH', 'i586'))
    {
        loadtest "console/glibc_sanity";
    }
    # openSUSE has "load_system_update_tests" for that,
    # https://progress.opensuse.org/issues/31954 to improve
    if (is_sle && !gnomestep_is_applicable()) {
        loadtest "update/zypper_up";
    }
    loadtest "console/console_reboot" if is_jeos;
    loadtest "console/zypper_in";
    loadtest "console/yast2_i";
    if (!get_var("LIVETEST")) {
        loadtest "console/yast2_bootloader";
    }
    loadtest "console/vim" if is_opensuse || !sle_version_at_least('15') || !get_var('PATTERNS') || check_var_array('PATTERNS', 'enhanced_base');
    # textmode install comes without firewall by default atm on openSUSE
    if ((is_sle || !check_var("DESKTOP", "textmode")) && !is_staging() && !is_krypton_argon) {
        loadtest "console/firewall_enabled";
    }
    if (is_jeos) {
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
    if (is_opensuse && !get_var("LIVETEST") && !is_staging() && !is_jeos) {
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
        # TODO test on openSUSE -> https://progress.opensuse.org/issues/27014
        loadtest "console/postgresql_server" if is_sle;
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        if (is_sle && sle_version_at_least('12-SP1')) {    # shibboleth-sp not available on SLES 12 GA
            loadtest "console/shibboleth";
        }
        if (!is_staging && (is_opensuse || get_var('ADDONS', '') =~ /wsm/ || get_var('SCC_ADDONS', '') =~ /wsm/)) {
            # TODO test on openSUSE https://progress.opensuse.org/issues/31972
            loadtest "console/pcre" if is_sle;
            # TODO test on SLE https://progress.opensuse.org/issues/31972
            loadtest "console/mysql_odbc" if is_opensuse;
            if ((is_leap && !leap_version_at_least('15.0')) || (is_sle && !sle_version_at_least('15'))) {
                loadtest "console/php5";
                loadtest "console/php5_mysql";
                loadtest "console/php5_postgresql96";
            }
            loadtest "console/php7";
            loadtest "console/php7_mysql";
            loadtest "console/php7_postgresql96";
        }
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        loadtest "console/apache_ssl" if is_sle;
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        loadtest "console/apache_nss" if is_sle;
    }
    if (check_var("DESKTOP", "xfce")) {
        loadtest "console/xfce_gnome_deps";
    }
    if (!is_staging() && is_sle && sle_version_at_least('12-SP2')) {
        # This test uses serial console too much to be reliable on Hyper-V
        # (poo#30613)
        loadtest "console/zypper_lifecycle" unless check_var('VIRSH_VMM_FAMILY', 'hyperv');
        if (check_var_array('SCC_ADDONS', 'tcm') && !sle_version_at_least('15')) {
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
    loadtest "x11/user_gui_login" if is_opensuse && !get_var("LIVETEST") && !get_var("NOAUTOLOGIN");
    if (get_var("XDMUSED")) {
        loadtest "x11/x11_login";
    }
    if (kdestep_is_applicable() && get_var("WAYLAND")) {
        loadtest "x11/start_wayland_plasma5";
    }
    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_terminal";
    }
    loadtest "x11/xterm";
    loadtest "x11/sshxterm" unless get_var("LIVETEST");
    if (gnomestep_is_applicable()) {
        # openSUSE has an explicit update check elsewhere
        loadtest "update/updates_packagekit_gpk" if is_sle && !is_staging;
        loadtest "x11/gnome_control_center";
        # TODO test on SLE https://progress.opensuse.org/issues/31972
        loadtest "x11/gnome_tweak_tool" if is_opensuse;
        loadtest "x11/gnome_terminal";
        loadtest "x11/gedit";
    }
    if (kdestep_is_applicable() && !is_kde_live) {
        loadtest "x11/kate";
    }
    loadtest "x11/firefox";
    if (is_opensuse && !get_var("OFW") && check_var('BACKEND', 'qemu') && !check_var('FLAVOR', 'Rescue-CD') && !is_kde_live) {
        loadtest "x11/firefox_audio";
    }
    if (gnomestep_is_applicable() && !(get_var("LIVECD") || is_sle)) {
        loadtest "x11/thunderbird";
    }
    if (chromiumstep_is_applicable() && !(is_staging() || is_livesystem)) {
        loadtest "x11/chromium";
    }
    if (xfcestep_is_applicable()) {
        loadtest "x11/midori" unless (is_staging || is_livesystem);
        loadtest "x11/ristretto";
    }
    if (gnomestep_is_applicable()) {
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        if (is_sle && (!is_server || we_is_applicable)) {
            loadtest "x11/eog";
            loadtest "x11/rhythmbox";
            loadtest "x11/wireshark";
            loadtest "x11/ImageMagick";
            loadtest "x11/ghostscript";
        }
    }
    if (get_var("DESKTOP") =~ /kde|gnome/ && (!is_server || we_is_applicable) && !is_kde_live && !is_krypton_argon && !is_gnome_next) {
        loadtest "x11/ooffice";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/ && !get_var("LIVECD") && (!is_server || we_is_applicable)) {
        loadtest "x11/oomath";
        loadtest "x11/oocalc";
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
    # SLES4SAP default installation does not configure snapshots
    if (snapper_is_applicable() and !is_sles4sap()) {
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
    loadtest "x11/glxgears" if packagekit_available && !get_var('LIVECD');
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
        loadtest "x11/gnome_music" if is_opensuse;
        loadtest "x11/evolution" if (!is_server() || we_is_applicable());
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_gnome";
        }
        load_testdir('x11/gnomeapps') if is_gnome_next;
    }
    loadtest "x11/desktop_mainmenu";
    if (is_sles4sap() and !is_sles4sap_standard()) {
        load_sles4sap_tests();
    }

    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_appfinder";
        if (!(get_var("FLAVOR") eq 'Rescue-CD')) {
            loadtest "x11/xfce_lightdm_logout_login";
        }
    }

    if (is_opensuse && !get_var("LIVECD")) {
        loadtest "x11/inkscape";
        loadtest "x11/gimp";
    }
    if (is_opensuse && !is_staging && !is_livesystem) {
        loadtest "x11/gnucash";
        loadtest "x11/hexchat";
        loadtest "x11/vlc";
    }
    # Need to skip shutdown to keep backend alive if running rollback tests after migration
    unless (get_var('ROLLBACK_AFTER_MIGRATION')) {
        loadtest "x11/shutdown";
    }
}

sub load_yast2_ncurses_tests {
    boot_hdd_image;
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    loadtest "console/zypper_lr";
    loadtest "console/zypper_ref";
    # split YaST2 UI tests relying on external development controlled test
    # suites and self-contained ones
    if (get_var('Y2UITEST_DEVEL')) {
        # (Livesystem and laptops do use networkmanager)
        if (!get_var("LIVETEST") && !get_var("LAPTOP")) {
            loadtest 'console/yast2_cmdline';
        }
        return;
    }
    # start extra yast console tests (self-contained only) from here
    loadtest "console/yast2_proxy";
    loadtest "console/yast2_ntpclient";
    loadtest "console/yast2_tftp";
    loadtest "console/yast2_vnc";
    # TODO https://progress.opensuse.org/issues/20200
    # softfail record #bsc1049433 for samba and xinetd
    loadtest "console/yast2_samba";
    loadtest "console/yast2_xinetd";
    loadtest "console/yast2_apparmor";
    loadtest "console/yast2_lan_hostname";
    # internal nis server in suse network is used, but this is not possible for
    # openqa.opensuse.org
    if (check_var('DISTRI', 'sle')) {
        loadtest "console/yast2_nis";
    }
    # yast-lan related tests do not work when using networkmanager.
    # (Livesystem and laptops do use networkmanager)
    if (!get_var("LIVETEST") && !get_var("LAPTOP")) {
        loadtest "console/yast2_dns_server";
        loadtest "console/yast2_nfs_client";
    }
    loadtest "console/yast2_http";
    loadtest "console/yast2_ftp";
    loadtest "console/yast2_snapper_ncurses";
    # back to desktop
    loadtest "console/consoletest_finish";
}

sub load_yast2_gui_tests {
    return
      unless (!get_var("INSTALLONLY")
        && is_desktop_installed()
        && !get_var("DUALBOOT")
        && !get_var("RESCUECD"));
    boot_hdd_image;
    loadtest 'yast2_gui/yast2_control_center';
    loadtest "yast2_gui/yast2_bootloader";
    loadtest "yast2_gui/yast2_datetime";
    loadtest "yast2_gui/yast2_firewall";
    loadtest "yast2_gui/yast2_hostnames";
    loadtest "yast2_gui/yast2_lang";
    loadtest "yast2_gui/yast2_network_settings";
    loadtest "yast2_gui/yast2_software_management";
    loadtest "yast2_gui/yast2_users";
}

sub load_extra_tests {
    # Put tests that filled the conditions below
    # 1) you don't want to run in stagings below here
    # 2) the application is not rely on desktop environment
    # 3) running based on preinstalled image
    return unless get_var('EXTRATEST');
    # pre-conditions for extra tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    if (any_desktop_is_applicable()) {
        if (check_var('DISTRI', 'sle')) {
            # start extra x11 tests from here
            loadtest 'x11/vnc_two_passwords';
            # TODO: check why this is not called on opensuse
            loadtest 'x11/user_defined_snapshot';
        }
        elsif (check_var('DISTRI', 'opensuse')) {
            if (gnomestep_is_applicable()) {
                # Setup env for x11 regression tests
                loadtest "x11/x11_setup";
                # poo#18850 java test support for firefox, run firefox before chrome
                # as otherwise have wizard on first run to import settings from it
                loadtest "x11/firefox/firefox_java";
                if (check_var('VERSION', '42.2')) {
                    # 42.2 feature - not even on Tumbleweed
                    loadtest "x11/gdm_session_switch";
                }
                loadtest "x11/seahorse";
            }

            if (chromestep_is_applicable()) {
                loadtest "x11/chrome";
            }
            if (!get_var("NOAUTOLOGIN")) {
                loadtest "x11/multi_users_dm";
            }

        }
        # the following tests care about network and need some DE specific
        # needles. For now we only have them for gnome and do not want to
        # support more than just this DE. Probably for later at least the wifi
        # test, checking the wifi applet, would make sense in other DEs as
        # well
        if (check_var('DESKTOP', 'gnome')) {
            loadtest 'x11/yast2_lan_restart';
            loadtest 'x11/yast2_lan_restart_devices';
            # we only have the test dependencies, e.g. hostapd available in
            # openSUSE
            if (check_var('DISTRI', 'opensuse')) {
                loadtest 'x11/network/hwsim_wpa2_enterprise_setup';
                loadtest 'x11/network/yast2_network_setup';
                loadtest 'x11/network/NM_wpa2_enterprise';
            }
        }
    }
    else {
        # Run zypper info before as tests source repo
        loadtest "console/zypper_info";
        # Remove repos pointing to download.opensuse.org and add snaphot repo from o3
        if (check_var('DISTRI', 'opensuse')) {
            replace_opensuse_repos_tests;
        }
        loadtest "console/zypper_lr_validate";
        loadtest "console/openvswitch";
        # dependency of git test
        loadtest "console/sshd";
        loadtest "console/zypper_ref";
        loadtest "console/update_alternatives";
        # start extra console tests from here
        # Audio device is not supported on ppc64le, s390x, JeOS, and Xen PV
        if (!get_var("OFW") && !is_jeos && !check_var('VIRSH_VMM_FAMILY', 'xen') && !check_var('ARCH', 's390x')) {
            loadtest "console/aplay";
        }
        loadtest "console/command_not_found";
        if (is_sle '12-sp2+') {
            # Check for availability of packages and the corresponding repository, only makes sense for SLE
            loadtest 'console/repo_package_install';
            loadtest 'console/openssl_alpn';
            loadtest 'console/autoyast_removed';
        }
        elsif (check_var('DISTRI', 'opensuse')) {
            loadtest "console/rabbitmq";
            loadtest "console/salt";
            loadtest "console/rails";
            loadtest "console/machinery";
            loadtest "console/pcre";
            loadtest "console/openqa_review";
            loadtest "console/zbar";
            loadtest "console/a2ps";    # a2ps is not a ring package and thus not available in staging
            loadtest "console/weechat";
            loadtest "console/nano";
        }
        if (get_var("IPSEC")) {
            loadtest "console/ipsec_tools_h2h";
        }
        loadtest "console/git";
        loadtest "console/java";
        loadtest "console/sysctl";
        loadtest "console/curl_ipv6";
        loadtest "console/wget_ipv6";
        loadtest "console/unzip";
        loadtest "console/gpg";
        loadtest "console/shells";
        # MyODBC-unixODBC not available on < SP2 and sle 15 and only in SDK
        if (sle_version_at_least('12-SP2') && !(sle_version_at_least('15'))) {
            loadtest "console/mysql_odbc" if check_var_array('ADDONS', 'sdk') || check_var_array('SCC_ADDONS', 'sdk');
        }
        if (get_var("SYSAUTHTEST")) {
            # sysauth test scenarios run in the console
            loadtest "sysauth/sssd";
        }
        # schedule the docker tests later as it needs the containers module on
        # SLE>=15 and therefore would potentially pollute other test modules
        load_docker_tests if (check_var('ARCH', 'x86_64') && (sle_version_at_least('12-SP2') || !is_sle));
        loadtest "console/kdump_and_crash" if kdump_is_applicable;
        loadtest "console/consoletest_finish";
    }
    return 1;
}

sub load_rollback_tests {
    loadtest "boot/grub_test_snapshot";
    loadtest "migration/version_switch_origin_system";
    if (get_var('UPGRADE') || get_var('ZDUP')) {
        loadtest "boot/snapper_rollback";
    }
    if (get_var('MIGRATION_ROLLBACK')) {
        loadtest "migration/sle12_online_migration/snapper_rollback";
    }
}

sub load_filesystem_tests {
    return unless get_var('FILESYSTEM_TEST');
    # pre-conditions for filesystem tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    if (get_var("FILESYSTEM", "btrfs") eq "btrfs") {
        loadtest "console/btrfs_autocompletion";
        if (get_var("NUMDISKS", 0) > 1) {
            loadtest "console/btrfs_qgroups";
            if (check_var('DISTRI', 'opensuse') || is_sle('12-sp2+')) {
                loadtest 'console/snapper_cleanup';
            }
            if (is_sle '12-sp2+') {
                loadtest "console/btrfs_send_receive";
            }
        }
    }
    loadtest 'console/snapper_undochange';
    loadtest 'console/snapper_create';
    if (is_sle('12-sp3+') || leap_version_at_least('42.3') || is_tumbleweed) {
        loadtest 'console/snapper_thin_lvm';
    }
}

sub load_wicked_tests {
    loadtest 'wicked/before_test';
    if (check_var('WICKED', 'basic')) {
        loadtest 'wicked/basic';
        loadtest 'wicked/config_files';
    }
    elsif (check_var('WICKED', 'risky')) {
        loadtest 'wicked/risky';
    }
}

sub load_networkd_tests {
    loadtest "console/consoletest_setup";
    loadtest 'networkd/networkd_init';
    loadtest 'networkd/networkd_dhcp';
    loadtest 'networkd/networkd_vlan';
    loadtest 'networkd/networkd_bridge';
}

sub load_nfv_master_tests {
    boot_hdd_image();
    loadtest "nfv/prepare_env";
    loadtest "nfv/run_integration_tests";
}

sub load_nfv_trafficgen_tests {
    boot_hdd_image();
    loadtest "nfv/trex_installation";
}

sub load_iso_in_external_tests {
    loadtest "boot/boot_to_desktop";
    loadtest "console/copy_iso_to_external_drive";
    loadtest "x11/reboot_and_install";
}

sub load_x11_installation {
    set_var('NOAUTOLOGIN', 1) if is_opensuse;
    load_boot_tests();
    load_inst_tests();
    load_reboot_tests();
    loadtest "x11/x11_setup";
    # temporary adding test modules which applies hacks for missing parts in sle15
    loadtest "console/sle15_workarounds" if is_sle and sle_version_at_least('15');
    loadtest "console/hostname"       unless is_bridged_networking;
    loadtest "console/force_cron_run" unless is_jeos;
    loadtest "shutdown/grub_set_bootargs";
    loadtest "shutdown/shutdown";
}

sub load_x11_documentation {
    return unless check_var('DESKTOP', 'gnome');
    loadtest "x11/gnote/gnote_first_run";
    loadtest "x11/gnote/gnote_link_note";
    loadtest "x11/gnote/gnote_rename_title";
    loadtest "x11/gnote/gnote_undo_redo";
    loadtest "x11/gnote/gnote_edit_format";
    loadtest "x11/gnote/gnote_search_all";
    loadtest "x11/gnote/gnote_search_body";
    loadtest "x11/gnote/gnote_search_title";
    loadtest "x11/evince/evince_open";
    loadtest "x11/evince/evince_view";
    loadtest "x11/evince/evince_rotate_zoom";
    loadtest "x11/evince/evince_find";
    loadtest "x11/gedit/gedit_launch";
    loadtest "x11/gedit/gedit_save";
    loadtest "x11/gedit/gedit_about";
    loadtest "x11/libreoffice/libreoffice_mainmenu_components";
    loadtest "x11/libreoffice/libreoffice_recent_documents";
    loadtest "x11/libreoffice/libreoffice_default_theme";
    loadtest "x11/libreoffice/libreoffice_double_click_file";
    if (sle_version_at_least('12-SP1')) {
        loadtest "x11/libreoffice/libreoffice_mainmenu_favorites";
        loadtest "x11/evolution/evolution_prepare_servers";
        loadtest "x11/libreoffice/libreoffice_pyuno_bridge";
    }
    loadtest "x11/libreoffice/libreoffice_open_specified_file";
}

sub load_x11_gnome {
    return unless check_var('DESKTOP', 'gnome');
    loadtest "x11/gnomecase/nautilus_cut_file";
    loadtest "x11/gnomecase/nautilus_permission";
    loadtest "x11/gnomecase/nautilus_open_ftp";
    loadtest "x11/gnomecase/application_starts_on_login";
    loadtest "x11/gnomecase/change_password";
    loadtest "x11/gnomecase/login_test";
    if (is_sle '12-SP1+') {
        loadtest "x11/gnomecase/gnome_classic_switch";
    }
    loadtest "x11/gnomecase/gnome_default_applications";
    loadtest "x11/gnomecase/gnome_window_switcher";
}

sub load_x11_other {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11/brasero/brasero_launch";
        loadtest "x11/gnomeapps/gnome_documents";
        loadtest "x11/totem/totem_launch";
        if (is_sle '15+') {
            loadtest "x11/xterm";
            loadtest "x11/sshxterm";
            loadtest "x11/gnome_control_center";
            loadtest "x11/gnome_tweak_tool";
            loadtest "x11/seahorse";
        }
    }
    # shotwell was replaced by gnome-photos in SLE15 & yast_virtualization isn't in SLE15
    if (is_sle('>=12-sp2') && is_sle('<15')) {
        loadtest "x11/shotwell/shotwell_import";
        loadtest "x11/shotwell/shotwell_edit";
        loadtest "x11/shotwell/shotwell_export";
        loadtest "virtualization/yast_virtualization";
        loadtest "virtualization/virtman_view";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11/tracker/prep_tracker";
        # tracker-gui/tracker-needle was dropped since version 1.99.0
        if (!sle_version_at_least('15')) {
            loadtest "x11/tracker/tracker_starts";
            loadtest "x11/tracker/tracker_searchall";
            loadtest "x11/tracker/tracker_pref_starts";
            loadtest "x11/tracker/tracker_open_apps";
            loadtest "x11/tracker/tracker_mainmenu";
        }
        loadtest "x11/tracker/tracker_by_command";
        loadtest "x11/tracker/tracker_info";
        loadtest "x11/tracker/tracker_search_in_nautilus";
        loadtest "x11/tracker/clean_tracker";
    }
}

sub load_common_x11 {
    if (check_var("REGRESSION", "installation")) {
        load_x11_installation;
    }
    elsif (check_var("REGRESSION", "gnome")) {
        loadtest "boot/boot_to_desktop";
        load_x11_gnome();
    }
    elsif (check_var("REGRESSION", "documentation")) {
        loadtest "boot/boot_to_desktop";
        load_x11_documentation();
    }
    elsif (check_var("REGRESSION", "other")) {
        loadtest "boot/boot_to_desktop";
        load_x11_other();
    }
}

# Move fips testsuites to main_common to apply to SLE_FIPS + openSUSE
# Rename load_fips_tests_* to load_security_tests_* to avoid confusedness since
# openSUSE does NOT have FIPS mode
# Some tests are only valid for SLE FIPS and loaded if defined variables set
sub load_security_tests_core {
    if (check_var('DISTRI', 'sle') && get_var('FIPS_TS')) {
        loadtest "fips/openssl/openssl_fips_alglist";
        loadtest "fips/openssl/openssl_fips_hash";
        loadtest "fips/openssl/openssl_fips_cipher";
        loadtest "fips/openssh/openssh_fips";
    }
    loadtest "fips/openssl/openssl_pubkey_rsa";
    loadtest "fips/openssl/openssl_pubkey_dsa";
    if (is_sle('12-SP2+') || is_tumbleweed) {
        loadtest "console/openssl_alpn";
    }
    loadtest "console/sshd";
    loadtest "console/ssh_pubkey";
    loadtest "console/ssh_cleanup";
    loadtest "console/openvswitch_ssl";
    loadtest "console/consoletest_finish";
}

sub load_security_tests_web {
    loadtest "console/curl_https";
    loadtest "console/wget_https";
    loadtest "console/w3m_https";
    loadtest "console/apache_ssl";
    if (check_var('DISTRI', 'sle') && get_var('FIPS_TS')) {
        loadtest "fips/mozilla_nss/apache_nssfips";
        loadtest "console/libmicrohttpd";
    }
    loadtest "console/consoletest_finish";
    if (check_var('DISTRI', 'sle') && get_var('FIPS_TS')) {
        loadtest "fips/mozilla_nss/firefox_nss";
    }
}

sub load_security_tests_misc {
    if (check_var('DISTRI', 'sle') && get_var('FIPS_TS')) {
        loadtest "fips/curl_fips_rc4_seed";
        loadtest "console/aide_check";
    }
    loadtest "console/journald_fss";
    loadtest "console/git";
    loadtest "console/clamav";
    loadtest "console/consoletest_finish";
    # In SLE, the hexchat package is provided only in WE addon which is
    # only for x86_64 platform. Then hexchat is x86_64 specific and not
    # appropriate for other arches.
    loadtest "x11/hexchat_ssl" if (check_var('ARCH', 'x86_64'));
    loadtest "x11/x3270_ssl";
    loadtest "x11/seahorse_sshkey";
    loadtest "x11/libcamgm";
}

sub load_security_tests_crypt {
    if (check_var('DISTRI', 'sle') && get_var('FIPS_TS')) {
        loadtest "fips/ecryptfs_fips";
    }
    loadtest "console/gpg";
    loadtest "console/yast2_dm_crypt";
    loadtest "console/cryptsetup";
    loadtest "console/consoletest_finish";
}

sub load_systemd_patches_tests {
    boot_hdd_image;
    loadtest 'console/systemd_testsuite';
}

sub load_create_hdd_tests {
    return unless get_var('INSTALLONLY');
    # temporary adding test modules which applies hacks for missing parts in sle15
    loadtest 'console/sle15_workarounds' if is_sle('15+');
    loadtest 'console/hostname'       unless is_bridged_networking;
    loadtest 'console/force_cron_run' unless is_jeos;
    loadtest 'console/scc_deregistration' if get_var('SCC_DEREGISTER');
    loadtest 'shutdown/grub_set_bootargs';
    loadtest 'shutdown/shutdown';
    if (check_var('BACKEND', 'svirt')) {
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
            loadtest 'shutdown/hyperv_upload_assets';
        }
        else {
            loadtest 'shutdown/svirt_upload_assets';
        }
    }
}

sub load_virtualization_tests {
    return unless get_var('VIRTUALIZATION');
    # standalone suite to fit needed installation
    if (get_var("STANDALONEVT")) {
        loadtest "virtualization/prepare";
    }
    loadtest "virtualization/yast_virtualization";
    loadtest "virtualization/virt_install";
    loadtest "virtualization/virt_top";
    loadtest "virtualization/virtman_install";
    loadtest "virtualization/virtman_view";
    return 1;
}

sub load_syscontainer_tests() {
    return unless get_var('SYSCONTAINER_IMAGE_TEST');
    # pre-conditions for system container tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";

    # Install needed pieces
    loadtest 'virtualization/libvirtlxc_setup';

    # Register if possible
    if (check_var('DISTRI', 'sle')) {
        loadtest "console/suseconnect_scc";
    }

    # Run the actual test
    loadtest 'virtualization/syscontainer_image_test';
}

sub load_toolchain_tests {
    loadtest "console/force_cron_run";
    loadtest "toolchain/install";
    loadtest "toolchain/gcc_fortran_compilation";
    loadtest "toolchain/gcc_compilation";
    loadtest "console/kdump_and_crash" if is_sle && kdump_is_applicable;
}

sub load_common_opensuse_sle_tests {
    load_autoyast_clone_tests           if get_var("CLONE_SYSTEM");
    load_create_hdd_tests               if get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1");
    load_toolchain_tests                if get_var("TCM") || check_var("ADDONS", "tcm");
    loadtest 'console/network_hostname' if get_var('NETWORK_CONFIGURATION');
}

sub load_ssh_key_import_tests {
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

sub load_sles4sap_tests {
    return if get_var('INSTALLONLY');
    loadtest "sles4sap/desktop_icons" if (is_desktop_installed());
    loadtest "sles4sap/patterns";
    loadtest "sles4sap/sapconf";
    loadtest "sles4sap/saptune";
    if (get_var('NW')) {
        loadtest "sles4sap/netweaver_ascs_install" if (get_var('SLES4SAP_MODE') !~ /wizard/);
        loadtest "sles4sap/netweaver_ascs";
    }
}

1;
