# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Attempt to merge common parts of sle/main.pm and opensuse/main.pm
# Maintainer: qe-core@suse.de

package main_common;
use base Exporter;
use File::Basename;
use File::Find;
use Exporter;
use testapi qw(check_var get_var get_required_var set_var check_var_array diag);
use autotest;
use utils;
use wicked::TestContext;
use Utils::Architectures;
use version_utils qw(:VERSION :BACKEND :SCENARIO);
use Utils::Backends;
use data_integrity_utils 'verify_checksum';
use bmwqemu ();
use lockapi 'barrier_create';
use Carp 'croak';
use strict;
use warnings;

our @EXPORT = qw(
  any_desktop_is_applicable
  bootencryptstep_is_applicable
  boot_hdd_image
  check_env
  chromestep_is_applicable
  chromiumstep_is_applicable
  consolestep_is_applicable
  default_desktop
  gnomestep_is_applicable
  guiupdates_is_applicable
  have_scc_repos
  init_main
  installyaststep_is_applicable
  installzdupstep_is_applicable
  is_desktop
  is_kernel_test
  is_ltp_test
  is_systemd_test
  is_livesystem
  is_memtest
  is_memtest
  is_repo_replacement_required
  is_server
  is_sles4sap
  is_sles4sap_standard
  is_updates_test_repo
  is_updates_tests
  is_migration_tests
  kdestep_is_applicable
  kdump_is_applicable
  load_autoyast_clone_tests
  load_autoyast_tests
  load_ayinst_tests
  load_bootloader_s390x
  load_boot_tests
  load_common_installation_steps_tests
  load_common_opensuse_sle_tests
  load_common_x11
  load_consoletests
  load_create_hdd_tests
  load_extra_tests
  load_extra_tests_prepare
  load_inst_tests
  load_iso_in_external_tests
  load_jeos_tests
  load_kernel_baremetal_tests
  load_kernel_tests
  load_nfs_tests
  load_nfv_master_tests
  load_nfv_trafficgen_tests
  load_public_cloud_patterns_validation_tests
  load_transactional_role_tests
  load_reboot_tests
  load_rescuecd_tests
  load_rollback_tests
  load_applicationstests
  load_mitigation_tests
  load_vt_perf_tests
  load_security_tests
  load_shutdown_tests
  load_slepos_tests
  load_sles4sap_tests
  load_ha_cluster_tests
  load_ssh_key_import_tests
  load_svirt_boot_tests
  load_svirt_vm_setup_tests
  load_system_update_tests
  loadtest
  load_testdir
  load_virtualization_tests
  load_x11tests
  load_hypervisor_tests
  load_yast2_gui_tests
  load_zdup_tests
  logcurrentenv
  map_incidents_to_repo
  join_incidents_to_repo
  need_clear_repos
  noupdatestep_is_applicable
  opensuse_welcome_applicable
  remove_common_needles
  remove_desktop_needles
  replace_opensuse_repos_tests
  rescuecdstep_is_applicable
  set_defaults_for_username_and_password
  setup_env
  snapper_is_applicable
  ssh_key_import
  unregister_needle_tags
  updates_is_applicable
  we_is_applicable
  load_extra_tests_y2uitest_gui
  load_extra_tests_kernel
  load_wicked_create_hdd
  load_jeos_openstack_tests
  load_upstream_systemd_tests
);

sub init_main {
    set_defaults_for_username_and_password();
    setup_env();
    check_env();
    # We need to check image only for qemu backend, for svirt we validate image
    # after it is copied to the hypervisor host.
    if (is_qemu && data_integrity_is_applicable()) {
        my $errors = verify_checksum();
        set_var('CHECKSUM_FAILED', $errors) if $errors;
    }
}

sub loadtest {
    my ($test, %args) = @_;
    croak "extensions are not allowed here '$test'" if $test =~ /\.pm$/;
    autotest::loadtest("tests/$test.pm", %args);
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
        $testapi::username = "linux";    # LiveCD account
        $testapi::password = "";
    }
}

sub setup_env {
    # Tests currently rely on INSTLANG=en_US, so set it by default
    unless (get_var('INSTLANG')) {
        set_var('INSTLANG', 'en_US');
    }

    set_var('LTP_KNOWN_ISSUES', 'https://raw.githubusercontent.com/openSUSE/kernel-qe/main/ltp_known_issues.yaml') if is_opensuse and !get_var('LTP_KNOWN_ISSUES');

    # By default format DASD devices before installation
    if (is_backend_s390x) {
        # Format DASD before the installation by default
        # Skip format dasd before origin system installation by autoyast in 'Upgrade on zVM'
        # due to channel not activation issue. Need further investigation on it.
        # Also do not format if activate existing partitions
        my $format_dasd = get_var('S390_DISK') || get_var('UPGRADE') || get_var('ENCRYPT_ACTIVATE_EXISTING') ? 'never' : 'pre_install';
        set_var('FORMAT_DASD', get_var('FORMAT_DASD', $format_dasd));
    }
    # This is for 12-sp5 project specific flavor Migration-from-SLE12-SP5-to-SLE15-SPx, this flavor belong 12sp5 test group but the real
    # action is migration from 12-sp5 to 15-sp1, so we need change VERSION to 15-SP1 before the test case start
    if (check_var('FLAVOR', 'Migration-from-SLE12-SP5-to-SLE15-SPx') || check_var('FLAVOR', 'Migration-from-SLE12-SP5-to-SLE15-SPx-Milestone')
        || check_var('FLAVOR', 'Regression-on-SLE15-SPx-migrated-from-SLE12-SP5') || check_var('UPGRADE_TARGET_RELEASED_VERSION', 1)) {
        # Save the original target version, needed for testing upgrade from a beta version to a non-beta
        # SLE12-SP5 to SLE15-SP1 for example
        set_var('ORIGINAL_TARGET_VERSION', get_var('VERSION'));
        set_var('VERSION', get_var('UPGRADE_TARGET_VERSION'));
    }
}

sub data_integrity_is_applicable {
    # Method is used to schedule disk interity check, always perform for xen and hyper-v
    # no need for s390x, as use ftp url there. On qemu use variable to activate
    # validation, set VALIDATE_CHECKSUM variable to true
    return (grep { /^CHECKSUM_/ } keys %bmwqemu::vars) && get_var('VALIDATE_CHECKSUM');
}

sub any_desktop_is_applicable {
    return get_var("DESKTOP") !~ /textmode/;
}

sub opensuse_welcome_applicable {
    # openSUSE-welcome is expected to show up on openSUSE Tumbleweed and Leap 15.2 XFCE only
    # starting with Leap 15.3 opensuse-welcome is enabled on supported DEs not just XFCE
    # since not all DEs honor xdg/autostart, we are filtering based on desktop environments
    # except for ppc64/ppc64le because not built libqt5-qtwebengine sr#323144
    my $desktop = shift // get_var('DESKTOP', '');
    return ((($desktop =~ /gnome|kde|lxde|lxqt|mate|xfce/ && is_tumbleweed) || ($desktop =~ /xfce/ && is_leap("=15.2"))) && (get_var('ARCH') !~ /ppc64/)) || (($desktop =~ /gnome|kde|lxde|lxqt|mate|xfce/ && is_leap(">=15.3")) && (get_var('ARCH') !~ /ppc64|s390/));
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

sub is_gnome_live {
    return get_var('FLAVOR', '') =~ /GNOME-Live/;
}

sub is_kde_live {
    return get_var('FLAVOR', '') =~ /KDE-Live/;
}

sub packagekit_available {
    return !check_var('FLAVOR', 'Rescue-CD');
}

sub is_ltp_test {
    return (get_var('INSTALL_LTP')
          || get_var('LTP_COMMAND_FILE')
          || get_var('LIBC_LIVEPATCH'));
}

sub is_publiccloud_ltp_test {
    return (get_var('LTP_COMMAND_FILE') && get_var('PUBLIC_CLOUD'));
}

sub is_kernel_test {
    # ignore ltp tests in publiccloud
    return if is_publiccloud_ltp_test();
    return is_ltp_test() ||
      (get_var('QA_TEST_KLP_REPO')
        || get_var('INSTALL_KLP_PRODUCT')
        || get_var('INSTALL_KOTD')
        || get_var('VIRTIO_CONSOLE_TEST')
        || get_var('BLKTESTS')
        || get_var('TRINITY')
        || get_var('NUMA_IRQBALANCE')
        || get_var('TUNED'));
}

sub is_systemd_test {
    return get_var('SYSTEMD_TESTSUITE');
}

# Isolate the loading of LTP tests because they often rely on newer features
# not present on all workers. If they are isolated then only the LTP tests
# will fail to load when there is a version mismatch instead of all tests.
{
    local $@;

    eval "use main_ltp 'load_kernel_tests'";
    if ($@) {
        bmwqemu::fctwarn("Failed to load main_ltp.pm:\n$@", 'main_common.pm');
        eval q%{
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
    return if get_var('CLEAR_REPOS');
    loadtest "update/zypper_clear_repos";
    set_var('CLEAR_REPOS', 1);
    loadtest "console/zypper_ar";
    loadtest "console/zypper_ref";
}

sub is_updates_tests {
    my $flavor = get_var('FLAVOR');
    return 0 unless $flavor;
    # Incidents might be also Incidents-Gnome or Incidents-Kernel
    return $flavor =~ /-Updates$/ || $flavor =~ /-Incidents/;
}

sub is_migration_tests {
    my $flavor = get_var('FLAVOR');
    return 0 unless $flavor;
    return $flavor =~ /Migration/;
}

sub is_updates_test_repo {
    # mru stands for Maintenance Released Updates and skips unreleased updates
    return is_updates_tests && get_required_var('FLAVOR') !~ /-Minimal$/;
}

sub is_repo_replacement_required {
    return is_opensuse()    # Is valid scenario only for openSUSE
      && !get_var('KEEP_ONLINE_REPOS')    # Set variable no to replace variables
                                          # Skip if there isn't a repo to use (e.g. Leap live tests)
      && (get_var('SUSEMIRROR') || (is_staging && get_var('ISO_1')))
      && !get_var('ZYPPER_ADD_REPOS')    # Skip if manual repos are specified
      && !get_var('OFFLINE_SUT')    # Do not run if SUT is offine
      && !get_var('ZDUP');    # Do not run on ZDUP as these tests handle repos on their own
}

sub is_memtest {
    return get_var('MEMTEST');
}

sub is_desktop {
    return get_var('FLAVOR', '') =~ /^Desktop/ || check_var('SLE_PRODUCT', 'sled');
}

sub is_desktop_module_selected {
    # desktop applications module is selected if following variables have following values:
    # ha require desktop applications on sle <15, so it's preselected
    # same is true for sles4sap
    return
      get_var('ADDONS', '') =~ /all-packages|desktop|we/
      || get_var('ADDONURL', '') =~ /desktop|we/
      || (!is_sle('15+') && get_var('SCC_ADDONS', '') =~ /desktop|we|productivity|ha/)
      || (is_sle('15+') && get_var('SCC_ADDONS', '') =~ /desktop|we/)
      || is_sles4sap;
}

sub default_desktop {
    return 'textmode' if (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'));
    return if get_var('VERSION', '') lt '12';
    return 'gnome' if get_var('VERSION', '') lt '15';
    return 'gnome' if get_var('VERSION', '') =~ /^Jump/;
    # with SLE 15 LeanOS only the default is textmode
    return 'gnome' if get_var('BASE_VERSION', '') =~ /^12/;
    return 'gnome' if is_desktop_module_selected;
    # default system role for sles and sled
    return 'textmode' if is_server || !get_var('SCC_REGISTER') || !check_var('SCC_REGISTER', 'installation');
    # remaining cases are is_desktop and check_var('SCC_REGISTER', 'installation'), hence gnome
    return 'gnome';
}

sub load_shutdown_tests {
    return if is_openstack;
    # Schedule cleanup before shutdown only in cases the HDD will be published
    loadtest("shutdown/cleanup_before_shutdown") if get_var('PUBLISH_HDD_1');
    loadtest "shutdown/shutdown";
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
    return unless is_svirt;
    set_bridged_networking;
    if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
        # Loading bootloader_hyperv here when UPGRADE is on (i.e. offline migration is underway)
        # means loading it for the second time. Which might be apropriate if we want to reconfigure
        # the VM, but currently we don't want to.
        loadtest "installation/bootloader_hyperv" unless get_var('UPGRADE');
    }
    else {
        loadtest "installation/bootloader_svirt" unless get_var('UPGRADE');
    }
    unless (is_installcheck || is_memtest || is_rescuesystem) {
        load_svirt_boot_tests;
    }
}

sub load_boot_tests {
    if (get_var("ISO_MAXSIZE") && (!is_remote_backend() || is_svirt_except_s390x())) {
        loadtest "installation/isosize";
    }
    if ((get_var("UEFI") || is_jeos()) && !is_svirt) {
        loadtest "installation/data_integrity" if data_integrity_is_applicable;
        loadtest "installation/bootloader_uefi";
    }
    elsif (is_svirt_except_s390x()) {
        load_svirt_vm_setup_tests;
    }
    elsif (uses_qa_net_hardware() || get_var("PXEBOOT")) {
        loadtest "boot/boot_from_pxe";
        set_var("DELAYED_START", get_var("PXEBOOT"));
    }
    else {
        loadtest "installation/data_integrity" if data_integrity_is_applicable;
        loadtest "installation/bootloader" unless load_bootloader_s390x();
    }
}

sub load_reboot_tests {
    return if check_var("IPXE", "1");

    # Special case: our disk and boot config is on the supportserver
    # PXE reboot to be handled by module boot_to_desktop
    if (get_var('USE_SUPPORT_SERVER') && get_var('USE_SUPPORT_SERVER_PXE_CUSTOMKERNEL')) {
        loadtest "boot/boot_to_desktop";
        return;
    }
    # there is encryption passphrase prompt which is handled in installation/boot_encrypt
    if ((is_s390x && !get_var('ENCRYPT')) || uses_qa_net_hardware() || is_pvm) {
        loadtest "boot/reconnect_mgmt_console";
    }
    if (installyaststep_is_applicable()) {
        # test makes no sense on s390 because grub2 can't be captured
        if (!(is_s390x or (check_var('VIRSH_VMM_FAMILY', 'xen') and check_var('VIRSH_VMM_TYPE', 'linux')))) {
            # exclude this scenario for autoyast test with switched keyboard layaout. also exclude on ipmi as installation/first_boot will call wait_grub
            loadtest "installation/grub_test" unless get_var('INSTALL_KEYBOARD_LAYOUT') || get_var('KEEP_GRUB_TIMEOUT') || is_ipmi;
            if ((snapper_is_applicable()) && get_var("BOOT_TO_SNAPSHOT")) {
                loadtest "installation/boot_into_snapshot";
            }
        }
        if (get_var('ENCRYPT')) {
            loadtest "installation/boot_encrypt";
            # reconnect after installation/boot_encrypt
            if (is_s390x) {
                loadtest "boot/reconnect_mgmt_console";
            }
        }
        # exclude this scenario for autoyast test with switched keyboard layaout
        loadtest "installation/first_boot" unless get_var('INSTALL_KEYBOARD_LAYOUT');
        loadtest "installation/opensuse_welcome" if opensuse_welcome_applicable();
        if (is_aarch64 && !get_var('INSTALLONLY') && !get_var('LIVE_INSTALLATION') && !get_var('LIVE_UPGRADE')) {
            loadtest "installation/system_workarounds";
        }
    }
    if (get_var("DUALBOOT")) {
        loadtest "installation/reboot_eject_cd";
        loadtest "wsl/boot_windows";
    }
}

sub load_rescuecd_tests {
    if (rescuecdstep_is_applicable()) {
        loadtest "rescuecd/rescuecd";
    }
}

sub load_autoyast_clone_tests {
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest "console/yast2_clone_system";
    loadtest "console/consoletest_finish";
}

sub load_zdup_tests {
    loadtest 'installation/setup_zdup';
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/lock_package";
    }
    loadtest 'installation/install_service' if !is_desktop;
    loadtest 'installation/zdup';
    loadtest 'installation/post_zdup';
    # Restrict version switch to sle until opensuse adopts it
    loadtest "migration/version_switch_upgrade_target" if is_sle and get_var("UPGRADE_TARGET_VERSION");
    loadtest 'boot/boot_to_desktop';
    loadtest "installation/opensuse_welcome" if opensuse_welcome_applicable();
    loadtest 'console/check_upgraded_service' if !is_desktop;
}

sub load_autoyast_tests {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation");
    #   library function like send_key or reboot will not work, therefore exiting earlier
    return loadtest "locale/keymap_or_locale" if get_var('INSTALL_KEYBOARD_LAYOUT');
    loadtest("autoyast/console");
    loadtest("autoyast/login");
    # Wicked is the default on Leap and SLE < 16 only
    loadtest("autoyast/wicked") if (is_sle("<16") || is_leap("<16.0"));
    loadtest('autoyast/' . get_var("AUTOYAST_VERIFY_MODULE")) if get_var("AUTOYAST_VERIFY_MODULE");
    if (get_var("SUPPORT_SERVER_GENERATOR")) {
        loadtest("support_server/configure");
    }
    else {
        loadtest("autoyast/repos");
        loadtest("autoyast/clone");
        loadtest("autoyast/logs");
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

sub load_system_role_tests {
    # This part is relevant only for openSUSE
    if (is_opensuse) {
        if (installwithaddonrepos_is_applicable() && !get_var("LIVECD")) {
            loadtest "installation/setup_online_repos";
        }
        # Do not run on REMOTE_CONTROLLER, IPMI and on Hyper-V in GUI mode
        if ((!get_var('BACKEND', 'ipmi') || !is_pvm) && !is_hyperv_in_gui && !get_var("LIVECD")) {
            loadtest "installation/logpackages";
        }
    }
    if (is_using_system_role) {
        loadtest "installation/system_role";
    }
    elsif (is_opensuse) {
        loadtest "installation/installer_desktopselection";
    }
}

sub load_jeos_openstack_tests {
    return unless is_openstack;
    my $args = OpenQA::Test::RunArgs->new();
    loadtest 'boot/boot_to_desktop';
    if (get_var('JEOS_OPENSTACK_UPLOAD_IMG')) {
        loadtest "publiccloud/upload_image";
        return;
    } else {
        loadtest "jeos/prepare_openstack", run_args => $args;
    }

    if (get_var('LTP_COMMAND_FILE')) {
        loadtest 'publiccloud/run_ltp';
        return;
    } else {
        loadtest 'publiccloud/ssh_interactive_start', run_args => $args;
    }

    if (get_var('CI_VERIFICATION')) {
        loadtest 'jeos/verify_cloudinit', run_args => $args;
        loadtest("publiccloud/ssh_interactive_end", run_args => $args);
        return;
    }

    loadtest "jeos/image_info";
    loadtest "jeos/record_machine_id";
    loadtest "console/system_prepare" if is_sle;
    loadtest "console/force_scheduled_tasks";
    loadtest "jeos/grub2_gfxmode";
    loadtest "jeos/build_key";
    loadtest "console/prjconf_excluded_rpms";
    unless (get_var('CONTAINER_RUNTIME')) {
        loadtest "console/journal_check";
        loadtest "microos/libzypp_config";
    }

    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    replace_opensuse_repos_tests if is_repo_replacement_required;
    main_containers::load_container_tests();
    loadtest("publiccloud/ssh_interactive_end", run_args => $args);
}

sub load_jeos_tests {
    if ((is_arm || is_aarch64) && is_opensuse()) {
        # Enable jeos-firstboot, due to boo#1020019
        load_boot_tests();
        loadtest "jeos/prepare_firstboot";
    }
    load_boot_tests();
    loadtest "jeos/firstrun";
    #    loadtest "jeos/image_info";
    loadtest "jeos/record_machine_id";
    loadtest "console/force_scheduled_tasks";
    # this test case also disables grub timeout
    loadtest "jeos/grub2_gfxmode";
    unless (get_var('INSTALL_LTP') || get_var('SYSTEMD_TESTSUITE')) {
        loadtest "jeos/diskusage" unless is_openstack;
        loadtest "jeos/build_key";
        loadtest "console/prjconf_excluded_rpms";
    }
    unless (get_var('CONTAINER_RUNTIME')) {
        loadtest "console/journal_check";
        loadtest "microos/libzypp_config";
    }
    if (is_sle) {
        loadtest "console/suseconnect_scc";
        loadtest "jeos/efi_tid" if (get_var('UEFI') && is_sle('=12-sp5'));
    }

    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    replace_opensuse_repos_tests if is_repo_replacement_required;
    loadtest 'console/verify_efi_mok' if get_var 'CHECK_MOK_IMPORT';
    # zypper_ref needs to run on jeos-containers. the is_sle is required otherwise is scheduled twice on o3
    loadtest "console/zypper_ref" if (get_var('CONTAINER_RUNTIME') && is_sle);
}

sub installzdupstep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && get_var("ZDUP");
}

sub snapper_is_applicable {
    # run snapper tests on opensuse only for system_performance testsuite
    return 0 if (is_opensuse && !get_var('SOFTFAIL_BSC1063638'));

    # snapshots are only proposed by the installer if the available space is
    # big enough
    my $snapshots_available = get_var('FILESYSTEM', 'btrfs') =~ /btrfs/ && get_var("HDDSIZEGB", 10) > 10;
    return (!get_var('LIVETEST') && $snapshots_available);
}

sub chromestep_is_applicable {
    return is_opensuse && is_x86_64;
}

sub chromiumstep_is_applicable {
    return chromestep_is_applicable() || (is_opensuse && is_aarch64);
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
    return !(is_aarch64 && is_sle('<15')) && !check_var('VIRSH_VMM_TYPE', 'linux');
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

sub libreoffice_is_applicable {
    # for opensuse libreoffice package has ExclusiveArch:  aarch64 %{ix86} x86_64
    # do not know for SLE (so assume built for all)
    return 1 if (!is_opensuse);
    return (is_x86_64
          || is_i686
          || is_i586
          || is_aarch64);
}

sub need_clear_repos {
    return !get_var('ZDUP')
      && (!get_var('INSTALLONLY') || get_var('PUBLISH_HDD_1'))
      && !get_var('BOOT_TO_SNAPSHOT')
      && !get_var('LIVETEST')
      && !get_var('DUALBOOT')
      && (is_opensuse && !is_updates_tests)
      && !(is_jeos && !is_staging)
      || (is_sle && get_var("FLAVOR", '') =~ m/^Staging2?[\-]DVD$/ && get_var("SUSEMIRROR"));
}

sub have_scc_repos {
    return check_var('SCC_REGISTER', 'console');
}

sub xfcestep_is_applicable {
    return check_var("DESKTOP", "xfce");
}

sub lxdestep_is_applicable {
    return check_var("DESKTOP", "lxde");
}

sub is_smt {
    # Smt is replaced with rmt in SLE 15, see bsc#1061291
    return (check_var('SMT_TEST', '1') && is_sle('<15'));
}

sub is_rmt {
    return (check_var('RMT_TEST', '1') && is_sle('>=15'));
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

    unregister_needle_tags("ENV-VIDEOMODE-text") unless check_var("VIDEOMODE", "text");
    unregister_needle_tags('ENV-ARCH-s390x') unless is_s390x;
    # Only for container tests
    unregister_needle_tags('ENV-UBUNTU-1') unless get_var('HDD_1', '') =~ /ubuntu/;
    if (get_var("INSTLANG") && get_var("INSTLANG") ne "en_US") {
        unregister_needle_tags("ENV-INSTLANG-en_US");
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

sub map_incidents_to_repo {
    my ($incidents, $templates) = @_;
    my @maint_repos;
    for my $i (keys %$incidents) {
        next unless $incidents->{$i};
        for my $j (split(/,/, $incidents->{$i})) {
            if ($j) {
                push @maint_repos, join($j, split('@INCIDENTNR@', $templates->{$i}));
            }
        }
    }

    my $ret = join(',', @maint_repos);
    # do not start with ','
    $ret =~ s/^,//s;
    return $ret;
}

sub join_incidents_to_repo {
    my ($incidents) = @_;
    my @repos;

    for my $k (keys %$incidents) {
        next unless $incidents->{$k};
        for my $i (split(/,/, $incidents->{$k})) {
            if ($i) {
                push @repos, $i;
            }
        }
    }

    return join(',', @repos);
}

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES => [0, 1],
    USEIMAGES => [0, 1],
    DOCRUN => [0, 1],

    #   BTRFS=>[0,1],
    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode serverro)],

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

    my $mirror = get_var('SUSEMIRROR');
    if ($mirror && $mirror =~ s{^(\w+)://}{}) {    # strip & check proto
        set_var('SUSEMIRROR', $mirror);
        die "only http mirror URLs are currently supported but found '$1'." if $1 ne "http";
    }
}

sub unregister_needle_tags {
    my ($tag) = @_;
    my @a = @{needle::tags($tag)};
    for my $n (@a) { $n->unregister($tag); }
}

sub load_bootloader_s390x {
    return 0 unless is_s390x;

    if (is_backend_s390x) {
        loadtest "installation/bootloader_s390";
    }
    else {
        loadtest "installation/bootloader_zkvm";
    }
    return 1;
}

sub boot_hdd_image {
    # On JeOS we don't need to load any test to boot, but to keep main.pm sane just return.
    is_jeos() ? return 1 : get_required_var('BOOT_HDD_IMAGE');
    if (is_svirt) {
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
            loadtest 'installation/bootloader_hyperv';
        }
        else {
            loadtest 'installation/bootloader_svirt' unless load_bootloader_s390x;
        }
    }
    loadtest 'installation/bootloader' if is_pvm;
    loadtest 'boot/boot_to_desktop';
}

sub load_common_installation_steps_tests {
    loadtest 'installation/await_install';
    unless (get_var('REMOTE_CONTROLLER') || is_hyperv_in_gui) {
        loadtest "installation/add_serial_console" if is_vmware;
        loadtest 'installation/logs_from_installation_system';
    }
    loadtest 'installation/reboot_after_installation';
}

sub load_ayinst_tests {
    loadtest("autoyast/installation");
    loadtest("autoyast/console");
    loadtest("autoyast/login");
    loadtest("autoyast/autoyast_reboot");
}

sub load_inst_tests {
    # On SLE 15 dud addon screen is shown before product selection
    if (get_var('DUD_ADDONS') && is_sle('15+')) {
        loadtest "installation/dud_addon";
    }
    loadtest "installation/welcome";
    if (get_var('DUD_ADDONS') && is_sle('<15')) {
        loadtest "installation/dud_addon";
    }
    loadtest 'installation/network_configuration' if get_var('OFFLINE_SUT');
    if (get_var('IBFT')) {
        loadtest "installation/iscsi_configuration";
    }
    # specific case for mru-install-multipath-remote
    if (get_var('WITHISCSI')) {
        loadtest "installation/disk_activation_iscsi";
        loadtest "installation/multipath";
    }
    if (is_s390x) {
        if (is_backend_s390x) {
            loadtest "installation/disk_activation";
        }
        elsif (is_sle('<12-SP2')) {
            loadtest "installation/skip_disk_activation";
        }
    }
    if (get_var('ENCRYPT_CANCEL_EXISTING') || get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        loadtest "installation/encrypted_volume_activation";
    }
    if (!is_sle('15-SP4+') && !get_var('WITHISCSI') && (get_var('MULTIPATH') or get_var('MULTIPATH_CONFIRM'))) {
        loadtest "installation/multipath";
    }
    if (is_opensuse && noupdatestep_is_applicable() && !is_livecd) {
        # See https://github.com/yast/yast-packager/pull/385
        loadtest "installation/online_repos";
        loadtest "installation/installation_mode";
    }
    if (is_upgrade) {
        loadtest "installation/upgrade_select";
        if (check_var("UPGRADE", "LOW_SPACE")) {
            loadtest "installation/disk_space_fill";
        }
        if (is_opensuse) {
            # See https://github.com/yast/yast-packager/pull/385
            loadtest "installation/online_repos";
        }
    }
    if (is_sle) {
        loadtest 'installation/network_configuration' if get_var('NETWORK_CONFIGURATION');
        loadtest "installation/scc_registration";
        if (is_sle('15-SP4+') && !get_var('WITHISCSI') && (get_var('MULTIPATH') or get_var('MULTIPATH_CONFIRM'))) {
            loadtest "installation/multipath";
        }
        if (is_sles4sap and is_sle('<15') and !is_upgrade()) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        if (get_var('MAINT_TEST_REPO') and !get_var("USER_SPACE_TESTSUITES")) {
            loadtest 'installation/add_update_test_repo';
        }
        loadtest "installation/addon_products_sle";
    }
    if (noupdatestep_is_applicable()) {
        # On Leap 15.2/TW Lives and Argon there is no network configuration stage
        if (get_var("LIVECD") && is_leap("<=15.1") && !is_krypton_argon) {
            loadtest "installation/livecd_network_settings";
        }
        # See https://github.com/yast/yast-packager/pull/385
        loadtest "installation/online_repos" if is_opensuse && is_livecd;
        # Run system_role/desktop selection tests if using the new openSUSE installation flow
        if (is_using_system_role_first_flow && requires_role_selection) {
            load_system_role_tests;
        }
        if (is_sles4sap() and is_sle('15+') and check_var('SYSTEM_ROLE', 'default') and !is_upgrade()) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        # MicroOS doesn't have a partitioning step
        unless (is_microos) {
            loadtest "installation/partitioning";
            if (defined(get_var("RAIDLEVEL"))) {
                loadtest "installation/partitioning_raid";
            }
            elsif (get_var('LVM')) {
                load_lvm_tests();
            }
            elsif (check_var('LVM', 0) && get_var('ENCRYPT')) {
                loadtest 'installation/partitioning/encrypt_no_lvm';
            }
            elsif (get_var('FULL_LVM_ENCRYPT')) {
                loadtest 'installation/partitioning_full_lvm';
            }
            elsif (get_var('LVM_THIN_LV')) {
                loadtest "installation/partitioning_lvm_thin_provisioning";
            }
            # For s390x there was no offering of separated home partition until SLE 15 See bsc#1072869
            elsif (!(is_sle('<15') && is_s390x())) {
                if (check_var("SEPARATE_HOME", 1)) {
                    loadtest "installation/partitioning/separate_home";
                }
                elsif (check_var("SEPARATE_HOME", 0)) {
                    loadtest "installation/partitioning/no_separate_home";
                }
            }
            if (get_var("FILESYSTEM")) {
                if (get_var('PARTITIONING_WARNINGS')) {
                    loadtest 'installation/partitioning_warnings';
                }
                loadtest "installation/partitioning_filesystem";
            }
            if (get_var("EXPERTPARTITIONER")) {
                loadtest "installation/partitioning_expert";
            }
            #kernel performance test need install on specific disk
            if (get_var("SPECIFIC_DISK")) {
                loadtest "installation/partitioning_specific_disk";
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
            if ((uses_qa_net_hardware() && !get_var('FILESYSTEM')) && !get_var("SPECIFIC_DISK") || get_var('SELECT_FIRST_DISK') || get_var("ISO_IN_EXTERNAL_DRIVE")) {
                loadtest "installation/partitioning_firstdisk";
            }
            loadtest "installation/partitioning_finish";
        }
    }
    if (is_opensuse && addon_products_is_applicable() && !is_leap('42.3+')) {
        loadtest "installation/addon_products";
    }
    # the VNC gadget is too unreliable to click, but we
    # need to be able to do installations on it. The release notes
    # functionality needs to be covered by other backends
    # Skip release notes test on sle 15 if have addons
    if (get_var('CHECK_RELEASENOTES') &&
        is_sle && !is_generalhw && !is_ipmi &&
        !(is_sle('15+') && get_var('ADDONURL'))) {
        loadtest "installation/releasenotes";
    }

    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_timezone" unless is_microos;
        # the test should run only in scenarios, where installed
        # system is not being tested (e.g. INSTALLONLY etc.)
        # The test also won't work reliably when network is bridged (non-s390x svirt).
        if (!consolestep_is_applicable()
            and !get_var("REMOTE_CONTROLLER")
            and !is_hyperv_in_gui
            and !is_bridged_networking
            and (get_var('BACKEND', '') !~ /ipmi|s390x/)
            and !is_pvm
            and is_sle('12-SP2+'))
        {
            loadtest "installation/hostname_inst";
        }
        # Do not run system_role/desktop selection if using the new openSUSE installation flow
        if (!is_using_system_role_first_flow && requires_role_selection) {
            load_system_role_tests;
        }
        if (is_sles4sap()) {
            if (
                is_sles4sap_standard()    # Schedule module only for SLE15 with non-default role
                || is_updates_test_repo()
                || is_sle('15+') && get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'))
            {
                loadtest "installation/user_settings";
            }    # sles4sap wizard installation doesn't have user_settings step
        }
        elsif (is_microos) {
            loadtest "installation/ntp_config_settings";
        } else {
            loadtest "installation/user_settings" unless check_var('SYSTEM_ROLE', 'hpc-node');
        }
        if (is_sle || get_var("DOCRUN") || get_var("IMPORT_USER_DATA") || get_var("ROOTONLY")) {    # root user
            loadtest "installation/user_settings_root" unless check_var('SYSTEM_ROLE', 'hpc-server');
        }
        if (get_var('PATTERNS') || get_var('PACKAGES')) {
            loadtest "installation/resolve_dependency_issues";
            loadtest "installation/select_patterns" if (get_var('PATTERNS'));
            loadtest "installation/select_packages" if (get_var('PACKAGES'));
        }
        elsif (
            is_sle
            && (!check_var('DESKTOP', default_desktop)
                && (is_sle('<15') || check_var('DESKTOP', 'minimalx'))))
        {
            # With SLE15 we change desktop using role and not by unselecting packages (Use SYSTEM_ROLE variable),
            # If we have minimalx, as there is no such a role, there we use old approach
            loadtest "installation/resolve_dependency_issues";
            loadtest "installation/change_desktop";
        }
    }
    if (get_var("UEFI") && get_var("SECUREBOOT")) {
        loadtest "installation/secure_boot";
    }
    if (installyaststep_is_applicable()) {
        loadtest "installation/resolve_dependency_issues" unless get_var("DEPENDENCY_RESOLVER_FLAG");
        loadtest "installation/installation_overview";
        # On Xen PV we don't have GRUB on VNC
        # SELinux relabel reboots, so grub needs to timeout
        set_var('KEEP_GRUB_TIMEOUT', 1) if check_var('VIRSH_VMM_TYPE', 'linux') || get_var('SELINUX');
        loadtest "installation/disable_grub_timeout" unless get_var('KEEP_GRUB_TIMEOUT');
        if (check_var('VIDEOMODE', 'text') && is_ipmi) {
            loadtest "installation/disable_grub_graphics";
        }
        loadtest "installation/enable_selinux" if get_var('SELINUX');

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

sub load_console_server_tests {
    if (is_qemu && !is_jeos) {
        # The NFS test expects the IP to be 10.0.2.15
        loadtest "console/yast2_nfs_server";
    }
    loadtest "console/rsync";
    loadtest "console/http_srv";
    loadtest "console/apache";
    loadtest "console/dns_srv";
    loadtest "console/postgresql_server" unless (is_leap('<15.0'));
    if (is_sle('12-SP1+')) {    # shibboleth-sp not available on SLES 12 GA
        loadtest "console/shibboleth";
    }
    if (!is_staging && (is_opensuse || get_var('ADDONS', '') =~ /wsm/ || get_var('SCC_ADDONS', '') =~ /wsm/)) {
        # TODO test on SLE https://progress.opensuse.org/issues/31972
        loadtest "console/mariadb_odbc" if is_opensuse;
    }
    # TODO test on openSUSE https://progress.opensuse.org/issues/31972
    loadtest "console/apache_ssl" if is_sle;
    # TODO test on openSUSE https://progress.opensuse.org/issues/31972
    loadtest "console/apache_nss" if is_sle;
}

sub load_consoletests {
    return unless consolestep_is_applicable();
    loadtest 'console/prjconf_excluded_rpms' if is_livesystem;
    loadtest "console/system_prepare" unless is_opensuse;
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests && !get_var('QAM_MINIMAL');
    loadtest "console/check_network";
    loadtest "console/system_state";
    loadtest "console/prepare_test_data";
    loadtest "console/consoletest_setup";
    loadtest 'console/integration_services' if is_hyperv || is_vmware;

    if (get_var('IBM_TESTS')) {
        # prepare tarballs for the testcase
        # the path below should be reworked to be universal for any distribution, now it's for openQA deployed on opensuse
        my $tcs_path = "/var/lib/openqa/share/tests/sle/data/s390x/";

        my $testset = get_var('IBM_TESTSET');    # e.g. "KERNEL or TOOL or MEMORY"
        foreach my $tc (split(',', get_var('IBM_TESTS'))) {
            loadtest "s390x_tests/consoletest_${testset}${tc}";
        }
        return 1;
    }

    loadtest "locale/keymap_or_locale";
    if (is_sle && !get_var('MEDIA_UPGRADE') && !get_var('ZDUP') && is_upgrade && !is_desktop && !get_var('INSTALLONLY')) {
        loadtest "console/check_upgraded_service";
        loadtest "console/supportutils";
        loadtest "console/check_package_version" if check_var('UPGRADE_TARGET_VERSION', '15-SP3');
    }
    loadtest "console/force_scheduled_tasks" unless is_jeos;
    if (get_var("LOCK_PACKAGE")) {
        loadtest "console/check_locked_package";
    }
    loadtest "console/textinfo";
    loadtest "console/rmt" if is_rmt;
    loadtest "console/hostname" unless is_bridged_networking;
    # Add non-oss and debug repos for o3 and remove other by default
    replace_opensuse_repos_tests if is_repo_replacement_required;
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
    if (get_var("DESKTOP") !~ /textmode/ && !is_s390x) {
        loadtest "console/x_vt";
    }
    loadtest "console/zypper_lr";
    # Enable installation repo from the usb, unless we boot from USB, but don't use it
    # for the installation, like in case of LiveCDs and when using http/smb/ftp mirror
    if (check_var('USBBOOT', 1) && !(is_jeos || is_livecd) && !get_var('NETBOOT')) {
        loadtest 'console/enable_usb_repo';
    }

    # Do not clear repos twice if replace repos for openSUSE
    # On staging repos are already removed, using CLEAR_REPOS flag variable
    if (need_clear_repos() && !is_repo_replacement_required() && !get_var('CLEAR_REPOS')) {
        loadtest "update/zypper_clear_repos";
        set_var('CLEAR_REPOS', 1);
    }
    #have SCC repo for SLE product
    if (have_scc_repos()) {
        loadtest "console/yast2_scc";
    }
    # If is_repo_replacement_required returns true, we already have added mirror repo and refreshed repos
    if (!is_repo_replacement_required()) {
        if (have_addn_repos()) {
            loadtest "console/zypper_ar";
        }
        loadtest "console/zypper_ref";
    }
    if (is_jeos) {
        loadtest "jeos/glibc_locale";
        loadtest "jeos/kiwi_templates" unless (is_leap('<15.2') || is_staging);
    }
    loadtest 'console/systemd_wo_udev' if (is_sle('15-sp4+') || is_leap('15.4+') || is_tumbleweed);
    loadtest "console/ncurses" if is_leap;
    loadtest "console/yast2_lan" unless is_bridged_networking;
    # no local certificate store
    if (!is_krypton_argon) {
        loadtest "console/curl_https";
    }
    # puppet does not exist anymore in openSUSE Tumbleweed/Leap
    if (is_sle('<15') && check_var_array('SCC_ADDONS', 'asmm')) {
        loadtest "console/puppet";
    }
    # salt in SLE is only available for SLE12 ASMM or SLES15 and variants of
    # SLES but not SLED. Don't run it on live media, not really useful there.
    if (!get_var("LIVETEST") && is_opensuse || (check_var_array('SCC_ADDONS', 'asmm') || is_sle('15+') && !is_desktop)) {
        loadtest "console/salt";
    }
    if (!is_staging && (is_x86_64
            || is_i686
            || is_i586))
    {
        loadtest "console/glibc_sanity";
    }
    loadtest "console/glibc_tunables";
    load_system_update_tests(console_updates => 1);
    loadtest "console/console_reboot" if is_jeos;
    loadtest "console/zypper_in";
    loadtest "console/zypper_log";
    if (!get_var("LIVETEST")) {
        loadtest "console/yast2_i";
        loadtest "console/yast2_bootloader";
    }
    loadtest "console/vim" if is_opensuse || is_sle('<15') || !get_var('PATTERNS') || check_var_array('PATTERNS', 'enhanced_base');
# textmode install comes without firewall by default atm on openSUSE. For virtualization server xen and kvm is disabled by default: https://fate.suse.com/324207
    if ((is_sle || !check_var("DESKTOP", "textmode")) && !is_krypton_argon && !is_virtualization_server) {
        loadtest "console/firewall_enabled";
    }
    if (is_jeos) {
        loadtest "console/gpt_ptable";
        loadtest "console/kdump_disabled";
        loadtest "console/sshd_running";
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
        loadtest "console/mariadb_srv";
        # disable these tests of server packages for SLED (poo#36436)
        load_console_server_tests() unless is_desktop;
    }
    if (check_var("DESKTOP", "xfce")) {
        loadtest "console/xfce_gnome_deps";
    }
    if (!is_staging() && is_sle('12-SP2+')) {
        loadtest "console/zypper_lifecycle" unless is_hyperv('2012r2');
        if (check_var_array('SCC_ADDONS', 'tcm') && is_sle('<15')) {
            loadtest "console/zypper_lifecycle_toolchain";
        }
    }
    if (check_var_array('SCC_ADDONS', 'tcm') && get_var('PATTERNS') && is_sle('<15') && !get_var("MEDIA_UPGRADE")) {
        loadtest "feature/feature_console/deregister";
    }
    loadtest "console/nginx" if ((is_opensuse && !is_staging) || (is_sle('15+') && !is_desktop));
    # Checking for orphaned packages only really makes sense with the full FTP tree
    unless (is_staging) {
        loadtest 'console/orphaned_packages_check' if is_jeos || get_var('UPGRADE') || get_var('ZDUP') || !is_sle('<12-SP4');
    }
    loadtest "console/zypper_log_packages" unless x11tests_is_applicable();
    loadtest "console/consoletest_finish";
}

sub x11tests_is_applicable {
    return !get_var("INSTALLONLY") && is_desktop_installed() && !get_var("DUALBOOT") && !get_var("RESCUECD") && !get_var("HA_CLUSTER");
}

sub load_x11tests {
    return unless x11tests_is_applicable();
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
    # first module after login or startup to check prerequisites
    loadtest "x11/desktop_runner";
    loadtest "x11/setup";
    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_terminal";
    }
    loadtest "x11/xterm";
    loadtest "locale/keymap_or_locale_x11";
    loadtest "x11/sshxterm" unless get_var("LIVETEST");
    if (gnomestep_is_applicable()) {
        load_system_update_tests();
        loadtest "x11/gnome_control_center";
        # TODO test on SLE https://progress.opensuse.org/issues/31972
        loadtest "x11/gnome_tweak_tool" if is_opensuse;
        loadtest "x11/gnome_terminal";
        loadtest "x11/gedit";
    }
    # Need remove firefox tests in our migration tests from old Leap releases, keep them only in 15.2 and newer.
    loadtest "x11/firefox" unless (is_leap && check_version('<15.2', get_var('ORIGINAL_VERSION'), qr/\d{2,}\.\d/) && is_upgrade());
    if (is_opensuse && !get_var("OFW") && is_qemu && !check_var('FLAVOR', 'Rescue-CD') && !is_kde_live) {
        loadtest "x11/firefox_audio";
    }
    if (chromiumstep_is_applicable() && !(is_staging() || is_livesystem)) {
        loadtest "x11/chromium";
    }
    if (xfcestep_is_applicable()) {
        # Midori got dropped from TW
        loadtest "x11/midori" unless (is_staging || is_livesystem || !is_leap("<16.0"));
        # Tumbleweed and Leap 15.4+ no longer have ristretto on the Rescue CD
        loadtest "x11/ristretto" unless (check_var("FLAVOR", "Rescue-CD") && !is_leap("<=15.3"));
    }
    if (gnomestep_is_applicable()) {
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        if (is_sle) {
            if (!is_server || we_is_applicable) {
                loadtest "x11/eog";
                loadtest(is_sle('<15') ? "x11/rhythmbox" : "x11/gnome_music");
                loadtest "x11/wireshark";
                loadtest "x11/ImageMagick";
                loadtest "x11/remote_desktop/screensharing_available" if is_sle("15-sp4+");
                loadtest "x11/ghostscript";
            }
        }
        else {
            loadtest "x11/graphicsMagick" unless (is_staging || is_livesystem);
        }
    }
    if (libreoffice_is_applicable()) {
        if (get_var("DESKTOP") =~ /kde|gnome/
            && (!is_server || we_is_applicable)
            && !is_kde_live && !is_gnome_live && !is_krypton_argon && !is_gnome_next) {
            loadtest "x11/ooffice";
        }
        if (get_var("DESKTOP") =~ /kde|gnome/
            && !get_var("LIVECD")
            && (!is_server || we_is_applicable)) {
            loadtest "x11/oomath";
            loadtest "x11/oocalc";
        }
    }
    if (kdestep_is_applicable()) {
        if (!get_var('LIVECD')) {
            # Extension got (temporarily) pulled by Mozilla
            # loadtest "x11/plasma_browser_integration";
            loadtest "x11/khelpcenter";
        }
        if (get_var("PLASMA5")) {
            loadtest "x11/systemsettings5";
        }
        else {
            loadtest "x11/systemsettings";
        }
        loadtest "x11/dolphin";
        loadtest "x11/konsole";
    }
    # SLES4SAP default installation does not configure snapshots
    if (snapper_is_applicable() and !is_sles4sap()) {
        loadtest "x11/yast2_snapper";
    }
    loadtest "x11/thunar" if xfcestep_is_applicable();
    loadtest "x11/glxgears" if packagekit_available && !get_var('LIVECD');
    if (gnomestep_is_applicable()) {
        loadtest "x11/nautilus" unless get_var("LIVECD");
        loadtest "x11/gnome_music" if is_opensuse;
        loadtest "x11/evolution" if (!is_server() || we_is_applicable());
        load_testdir('x11/gnomeapps') if is_gnome_next;
    }
    loadtest "x11/desktop_mainmenu";
    load_sles4sap_tests() if (is_sles4sap() and !is_sles4sap_standard());
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
    if (is_opensuse && !is_livesystem) {
        if (!is_staging) {
            loadtest "x11/hexchat";
        }
        loadtest "x11/vlc";
    }
    if (kdestep_is_applicable()) {
        loadtest "x11/kate";
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
    if (gnomestep_is_applicable() && !get_var("USBBOOT") && !is_livesystem) {
        loadtest "x11/reboot_gnome";
    }
    if (xfcestep_is_applicable()) {
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_xfce";
        }
    }
    if (lxdestep_is_applicable()) {
        if (!get_var("USBBOOT") && !is_livesystem) {
            loadtest "x11/reboot_lxde";
        }
    }
    loadtest "console/zypper_log_packages";
    # Need to skip shutdown to keep backend alive if running rollback tests after migration
    unless (get_var('ROLLBACK_AFTER_MIGRATION')) {
        load_shutdown_tests;
    }
}

sub load_extra_tests_y2uitest_ncurses {
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
    loadtest "console/yast2_rmt" unless (is_sle('<15-sp1') || is_leap('<15.0') || is_i586);
    loadtest "console/yast2_ntpclient";
    loadtest "console/yast2_tftp";
    # We don't schedule some tests on s390x as they are unstable, see poo#42692
    unless (is_s390x) {
        loadtest "console/yast2_proxy";
        loadtest "console/yast2_vnc";
        # internal nis server in suse network is used, but this is not possible for
        # openqa.opensuse.org
        loadtest "console/yast2_nis" if is_sle;
        loadtest "console/yast2_http";
        loadtest "console/yast2_ftp";
        loadtest "console/yast2_apparmor";
        loadtest "console/yast2_lan";
        loadtest "console/yast2_lan_device_settings";
    }
    # TODO https://progress.opensuse.org/issues/20200
    # softfail record #bsc1049433 for samba and xinetd

    loadtest "console/yast2_xinetd" if is_sle('<15') || is_leap('<15.0');
    loadtest "console/yast2_lan_hostname";
    # yast-lan related tests do not work when using networkmanager.
    # (Livesystem and laptops do use networkmanager)
    if (!get_var("LIVETEST") && !get_var("LAPTOP")) {
        loadtest "console/yast2_dns_server";
        loadtest "console/yast2_nfs_client";
    }
    loadtest "console/yast2_snapper_ncurses";
}

sub load_extra_tests_y2uitest_gui {
    return
      unless (!get_var("INSTALLONLY")
        && is_desktop_installed()
        && !get_var("DUALBOOT")
        && !get_var("RESCUECD"));
    # YaST2 ui tests currently run only for openSUSE >= 15.1.
    # We (QAM) need to validate whether those tests work also
    # on older SLE versions and, if so, add them here.
    # On openSUSE, the scheduling happens in schedule/yast2_gui.yaml
    if (get_var("QAM_YAST2UI")) {
        loadtest "yast2_gui/yast2_bootloader" if is_sle("12-SP2+");
        loadtest "yast2_gui/yast2_security" if is_sle("12-SP2+");
        loadtest "yast2_gui/yast2_keyboard" if is_sle("12-SP2+");
        loadtest "yast2_gui/yast2_instserver" unless (is_sle('<12-SP3') || is_leap('<15.0'));
        loadtest "yast2_gui/yast2_storage_ng" if is_sle("15+") || is_leap("15.0+") || is_tumbleweed;
    }
}

sub load_extra_tests_y2uitest_cmd {
    loadtest 'yast2_cmd/yast_lan';
    loadtest 'yast2_cmd/yast_timezone';
    loadtest 'yast2_cmd/yast_tftp_server';
    loadtest 'yast2_cmd/yast_ftp_server';
    loadtest 'yast2_cmd/yast_rdp' if is_sle('15+');
    loadtest 'yast2_cmd/yast_users';
    loadtest 'yast2_cmd/yast_sysconfig';
    loadtest 'yast2_cmd/yast_keyboard' unless is_sle('=12-SP2');    #see progress ticket #99375
    loadtest 'yast2_cmd/yast_nfs_server';
    loadtest 'yast2_cmd/yast_nfs_client';
    loadtest 'yast2_cmd/yast_dns_server';
    loadtest 'yast2_cmd/yast_lang';
    loadtest 'yast2_cmd/yast_storage' if is_sle('<15');

    #temporary runs for QAM while tests under y2uitest_ncurses are being ported
    loadtest "console/yast2_apparmor";
    loadtest "console/yast2_http";
    loadtest "console/yast2_nis" if is_sle;
    loadtest "console/yast2_ftp";
    loadtest "console/yast2_tftp";
    # We cannot change network device settings as rely on ssh/vnc connection to the machine
    loadtest "console/yast2_lan_device_settings" unless (is_s390x() || get_var('PUBLIC_CLOUD'));
}

sub load_extra_tests_texlive {
    loadtest 'texlive/latexdiff' if is_sle('15+') || is_opensuse;
}

sub load_extra_tests_openqa_bootstrap {
    loadtest 'x11/disable_screensaver';
    if (get_var 'BOOTSTRAP_CONTAINER') {
        loadtest 'openqa/install/openqa_bootstrap_container';
    }
    else {
        loadtest 'openqa/install/openqa_bootstrap';
        loadtest 'openqa/osautoinst/start_test';
        loadtest 'openqa/osautoinst/test_running';
    }
    loadtest 'openqa/webui/dashboard';
    loadtest 'openqa/webui/login';
    unless (get_var 'BOOTSTRAP_CONTAINER') {
        loadtest 'openqa/webui/test_results';
    }
}

sub load_extra_tests_desktop {
    return unless any_desktop_is_applicable;
    if (check_var('DISTRI', 'sle')) {
        loadtest 'x11/disable_screensaver';
        # start extra x11 tests from here
        loadtest 'x11/vnc_two_passwords' unless is_sle("<=12-SP2");
        # TODO: check why this is not called on opensuse
        # poo#35574 - Excluded for Xen PV as it was never passed due to the fail while interacting with grub.
        loadtest 'x11/user_defined_snapshot' unless is_s390x || (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux'));
    }
    elsif (check_var('DISTRI', 'opensuse')) {
        if (gnomestep_is_applicable()) {
            # Setup env for x11 regression tests
            loadtest "x11/x11_setup";
            loadtest "x11/exiv2";
            if (check_var('VERSION', '42.2')) {
                # 42.2 feature - not even on Tumbleweed
                loadtest "x11/gdm_session_switch";
            }
            loadtest 'x11/vnc_two_passwords';
            loadtest "x11/seahorse";
            # only scheduled on gnome and was developed only for gnome but no
            # special reason should prevent it to be scheduled in another DE.
            loadtest 'x11/steam' if is_x86_64;
        }

        if (chromestep_is_applicable()) {
            loadtest "x11/chrome";
        }
        if (!get_var("NOAUTOLOGIN")) {
            loadtest "x11/multi_users_dm";
            if (check_var('DESKTOP', 'gnome')) {
                loadtest "x11/keyboard_layout_gdm";
            }
        }
        # wine is only in openSUSE for various reasons, including legal ones
        loadtest 'x11/wine' if get_var('ARCH', '') =~ /x86_64|i586/;
        loadtest "x11/gnucash";

    }
    if (gnomestep_is_applicable()) {
        loadtest "x11/remote_desktop/screensharing_available";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11/libqt5_qtbase" if (is_sle("12-SP3+") || is_opensuse);
    }
    # the following tests care about network and need some DE specific
    # needles. For now we only have them for gnome and do not want to
    # support more than just this DE. Probably for later at least the wifi
    # test, checking the wifi applet, would make sense in other DEs as
    # well
    if (check_var('DESKTOP', 'gnome')) {
        loadtest "x11/rrdtool_x11";
        loadtest 'x11/yast2_lan_restart';
        # we only have the test dependencies, e.g. hostapd available in
        # openSUSE
        if (check_var('DISTRI', 'opensuse')) {
            loadtest 'x11/network/hwsim_wpa2_enterprise_setup';
            loadtest 'x11/network/yast2_network_use_nm';
            loadtest 'x11/network/NM_wpa2_enterprise';
        }
        # We cannot change network device settings as rely on ssh/vnc connection to the machine
        loadtest "console/yast2_lan_device_settings" unless is_s390x();
    }
}

sub load_extra_tests_zypper {
    # Add non-oss and debug repos for o3 and remove other by default (skipped, if already done)
    replace_opensuse_repos_tests if is_repo_replacement_required;
    loadtest "console/zypper_lr_validate" unless is_sle '15+';
    loadtest "console/zypper_ref";
    unless (is_jeos) {
        loadtest "console/zypper_info";
    }
    loadtest "console/check_interactive_flag";
    # Check for availability of packages and the corresponding repository, as of now only makes sense for SLE
    loadtest 'console/validate_packages_and_patterns' if is_sle '12-sp2+';
    loadtest 'console/zypper_extend';
}

sub load_extra_tests_perl_bootloader {
    loadtest "console/perl_bootloader";
}

sub load_extra_tests_kdump {
    return unless kdump_is_applicable;
    loadtest "console/kdump_and_crash";
}

sub load_extra_tests_opensuse {
    return unless is_opensuse;
    loadtest "console/rabbitmq";
    loadtest "console/openqa_review";
    loadtest "console/zbar";
    loadtest "console/a2ps";    # a2ps is not a ring package and thus not available in staging
    loadtest "console/znc";
    loadtest "console/weechat";
    loadtest "console/nano";
    loadtest "console/steamcmd" if (is_i586 || is_x86_64);
    loadtest "console/libqca2";
}

sub load_extra_tests_geo_console {
    loadtest "appgeo/gdal" if is_tumbleweed;
}

sub load_extra_tests_geo_desktop {
    loadtest "appgeo/qgis" if is_tumbleweed;
}

sub load_extra_tests_console {
    loadtest "console/ping";
    loadtest "console/check_os_release";
    loadtest "console/orphaned_packages_check";
    loadtest "console/cleanup_qam_testrepos" if has_test_issues;
    # JeOS kernel is missing 'openvswitch' kernel module
    loadtest "console/openvswitch" unless is_jeos;
    loadtest "console/pam" unless is_leap;
    loadtest "console/shar";
    # dependency of git test
    loadtest "console/sshd";
    loadtest "console/update_alternatives";
    loadtest 'console/rpm';
    loadtest 'console/slp';
    loadtest 'console/pkcon';
    # Audio device is not supported on ppc64le, s390x, JeOS, Public Cloud and Xen PV
    if (!get_var('PUBLIC_CLOUD') && !get_var("OFW") && !is_jeos && !check_var('VIRSH_VMM_FAMILY', 'xen') && !is_s390x) {
        loadtest "console/aplay";
        loadtest "console/soundtouch" if is_opensuse || (is_sle('12-sp4+') && is_sle('<15'));
        # wavpack is available only sle12sp4 onwards
        if (is_opensuse || is_sle '12-sp4+') {
            loadtest "console/wavpack";
        }
    }
    loadtest "console/libvorbis";
    loadtest "console/command_not_found";
    if (is_sle('12-sp2+')) {
        loadtest 'console/openssl_alpn';
        loadtest 'console/autoyast_removed';
    }
    loadtest "console/cron" unless is_jeos;
    loadtest "console/syslog";
    loadtest "console/ntp_client" if (!is_sle || is_jeos);
    loadtest "console/mta" unless is_jeos;
    # part of load_extra_tests_y2uitest_ncurses & load_extra_tests_y2uitest_cmd except jeos
    loadtest "console/yast2_lan_device_settings" if is_jeos;
    loadtest "console/check_default_network_manager";
    loadtest "console/ipsec_tools_h2h" if get_var("IPSEC");
    loadtest "console/git";
    loadtest "console/cups";
    loadtest "console/java";
    loadtest "console/sqlite3";
    loadtest "console/ant" if is_sle('<15-sp1');
    loadtest "console/gdb";
    loadtest "console/perf" unless is_sle;
    loadtest "console/sysctl";
    loadtest "console/sysstat";
    loadtest "console/curl_ipv6" unless get_var('PUBLIC_CLOUD');
    loadtest "console/wget_ipv6";
    loadtest "console/ca_certificates_mozilla";
    loadtest "console/unzip";
    loadtest "console/salt" if (is_jeos || is_opensuse);
    loadtest "console/gpg";
    loadtest "console/rsync";
    loadtest "console/clamav";
    loadtest "console/shells";
    loadtest 'console/sudo';
    # dstat is not in sle12sp1
    loadtest "console/dstat" if is_sle('12-SP2+') || is_opensuse;
    # MyODBC-unixODBC not available on < SP2 and sle 15 and only in SDK
    if (is_sle('12-SP2+') && !(is_sle('15+'))) {
        loadtest "console/mariadb_odbc" if check_var_array('ADDONS', 'sdk') || check_var_array('SCC_ADDONS', 'sdk');
    }
    # bind need source package and legacy and development module on SLE15+
    loadtest 'console/bind' if get_var('MAINT_TEST_REPO');
    unless (is_sle('<12-SP3')) {
        loadtest 'x11/evolution/evolution_prepare_servers';
        loadtest 'console/mutt';
    }
    loadtest 'console/supportutils' if (is_sle && !is_jeos);
    loadtest 'console/mdadm' unless (is_jeos || get_var('PUBLIC_CLOUD'));
    loadtest 'console/journalctl';
    loadtest 'console/quota' unless (is_jeos);
    loadtest 'console/vhostmd' unless get_var('PUBLIC_CLOUD');
    loadtest 'console/rpcbind' unless is_jeos;
    # sysauth test scenarios run in the console
    loadtest "sysauth/sssd" if (get_var('SYSAUTHTEST') || is_sle('12-SP5+'));
    loadtest 'console/timezone';
    loadtest 'console/ntp' if is_sle('<15');
    loadtest 'console/procps';
    loadtest "console/lshw" if ((is_sle('15+') && (is_ppc64le || is_x86_64)) || is_opensuse);
    loadtest 'console/kmod';
    loadtest 'console/suse_module_tools';
    loadtest 'console/zziplib' if (is_sle('12-SP4+') && !is_jeos);
    loadtest 'console/firewalld' if is_sle('15+') || is_leap('15.0+') || is_tumbleweed;
    loadtest 'console/aaa_base' unless is_jeos;
    loadtest 'console/libgpiod' if (is_leap('15.1+') || is_tumbleweed) && !(is_jeos && is_x86_64);
    loadtest 'console/osinfo_db' if (is_sle('12-SP3+') && !is_jeos);
    loadtest 'console/libgcrypt' if ((is_sle(">=12-SP4") && (check_var_array('ADDONS', 'sdk') || check_var_array('SCC_ADDONS', 'sdk'))) || is_opensuse);
    loadtest "console/gd";
    loadtest 'console/gcc' unless is_sle('<=12-SP3');
    loadtest 'console/valgrind' unless is_sle('<=12-SP3');
    loadtest 'console/sssd_samba' unless (is_sle("<15") || is_sle(">=15-sp2") || is_leap('>=15.2') || is_tumbleweed);
    loadtest 'console/wpa_supplicant' unless (!is_x86_64 || is_sle('<15') || is_leap('<15.1') || is_jeos || is_public_cloud);
    loadtest 'console/python_scientific' unless (is_sle("<15"));
    loadtest "console/parsec" if is_tumbleweed;
}

sub load_extra_tests_sdk {
    loadtest 'console/gdb';
}

sub load_extra_tests_prepare {
    # setup $serialdev permission and so on
    loadtest "console/system_prepare";
    loadtest "console/prepare_test_data";
    loadtest "console/consoletest_setup";
    loadtest 'console/integration_services' if is_hyperv || is_vmware;
}

sub load_extra_tests {
    # Put tests that filled the conditions below
    # 1) you don't want to run in stagings below here
    # 2) the application is not rely on desktop environment
    # 3) running based on preinstalled image
    return unless get_var('EXTRATEST');
    # pre-conditions for extra tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # Extra tests are too long, split the test into subtest according to the
    # EXTRATEST variable; old EXTRATEST=1 settings is equivalent to
    # EXTRATEST=zypper,console,opensuse,kdump in textmode or
    # EXTRATEST=desktop in dektop tests
    foreach my $test_name (split(/,/, get_var('EXTRATEST'))) {
        if (my $test_to_run = main_common->can("load_extra_tests_$test_name")) {
            $test_to_run->();
        }
        else {
            diag "unknown scenario for EXTRATEST value $test_name";
        }
    }
    return 1;
}

sub load_rollback_tests {
    return if is_s390x;
    # On Xen PV we don't have GRUB.
    # For continuous migration test from SLE11SP4, the filesystem is 'ext3' and btrfs snapshot is not supported.
    # For HPC migration test with 'management server' role, the filesystem is 'xfs', btrfs snapshot is not supported.
    loadtest "boot/grub_test_snapshot" unless check_var('VIRSH_VMM_TYPE', 'linux') || get_var('FILESYSTEM') =~ /ext3|xfs/;
    # Skip load version switch for online migration and opensuse perfomance test
    loadtest "migration/version_switch_origin_system" if (!get_var("ONLINE_MIGRATION") && !(is_opensuse && get_var('SOFTFAIL_BSC1063638') && get_var('ROLLBACK_AFTER_MIGRATION')));
    if (get_var('UPGRADE') || get_var('ZDUP') || (is_opensuse && get_var('SOFTFAIL_BSC1063638') && get_var('ROLLBACK_AFTER_MIGRATION'))) {
        loadtest "boot/snapper_rollback";
    }
    if (get_var('MIGRATION_ROLLBACK')) {
        loadtest "migration/online_migration/snapper_rollback";
    }
}

sub load_extra_tests_filesystem {
    loadtest "console/lsof";
    loadtest "console/autofs";
    loadtest 'console/lvm';
    if (get_var("FILESYSTEM", "btrfs") eq "btrfs") {
        loadtest 'console/snapper_undochange';
        loadtest 'console/snapper_create';
        loadtest "console/snapper_jeos_cli" if is_jeos;
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
        loadtest "console/btrfsmaintenance";
    }
    if (get_var('NUMDISKS', 0) > 1 && (is_sle('12-sp3+') || is_leap('42.3+') || is_tumbleweed)) {
        # On JeOS we use kernel-defaul-base and it does not have 'dm-thin-pool'
        # kernel module required by thin-LVM
        loadtest 'console/snapper_thin_lvm' unless is_jeos;
    }
    loadtest 'console/snapper_used_space' if (is_sle('15-SP1+') || (is_opensuse && !is_leap('<15.1')));
    loadtest "console/udisks2" unless (is_sle('<=15-SP2') || get_var('VIRSH_VMM_FAMILY') =~ /xen/);
    loadtest "network/cifs" if (is_sle('>=15-sp3') || is_opensuse);
    loadtest "network/samba/server" if (is_sle('>=15-sp3') || is_opensuse);
    # Note: Until the snapshot restoration has been fixed (poo#109929), zfs should be the last test run
    loadtest "console/zfs" if (is_leap(">=15.1") && is_x86_64 && !is_jeos);
}

sub get_wicked_tests {
    my (%args) = @_;
    my $basedir = $bmwqemu::vars{CASEDIR} . '/tests/';
    my $suite = get_required_var('WICKED');
    my $exclude = get_var('WICKED_EXCLUDE', '$a');
    my $suite_dir = $basedir . 'wicked/' . $suite . '/';
    my $tests_dir = $suite_dir . 'sut/';
    my @tests;
    $args{only_names} //= 0;

    die "Unsupported WICKED suite: $suite" unless (-d $suite_dir);

    find({wanted => sub {
                return unless -f $_;
                return unless $_ =~ /\.pm$/;
                my $name = substr($_, length($basedir), -3);
                return if (basename($name) =~ $exclude);
                push(@tests, $name);
    }, no_chdir => 1}, $tests_dir);
    @tests = sort(@tests);

    unshift(@tests, 'wicked/before_test');
    if ($args{only_names}) {
        @tests = map(basename($_), @tests);
    }
    return @tests;
}

sub wicked_init_locks {
    my $args = OpenQA::Test::RunArgs->new();
    my @wicked_tests = get_wicked_tests(only_names => 1);
    $args->{wicked_tests} = \@wicked_tests;
    loadtest('wicked/locks_init', run_args => $args);
}

sub load_extra_tests_wicked {
    wicked_init_locks();
    my $ctx = wicked::TestContext->new();
    my @tests = get_wicked_tests();
    for my $test (@tests) {
        $test =~ s/\/sut\//\/ref\// if (get_var('IS_WICKED_REF'));
        my $full_path = $bmwqemu::vars{CASEDIR} . '/tests/' . $test . '.pm';
        if (-e $full_path) {
            loadtest($test, run_args => $ctx);
        }
        else {    # in case file not exists this mean that we don't need something specific from ref machine
                  # so we will load dummy replacement
            die "Not expected template load for SUT" unless get_var('IS_WICKED_REF');
            loadtest('wicked/ref_template', run_args => $ctx, name => basename($test));
        }
    }
}

sub load_wicked_create_hdd {
    if (get_var('WICKED_CHECK_HDD') &&
        (
            -e $bmwqemu::vars{ASSETDIR} . '/hdd/' . get_required_var('PUBLISH_HDD_1') ||
            -e $bmwqemu::vars{ASSETDIR} . '/hdd/fixed/' . get_required_var('PUBLISH_HDD_1')
        )) {
        delete($bmwqemu::vars{$_}) foreach (qw(PUBLISH_PFLASH_VARS PUBLISH_HDD_1));
        bmwqemu::save_vars();
        loadtest('wicked/nop');
    } else {
        loadtest('autoyast/prepare_profile');
        loadtest('installation/bootloader_start');
        loadtest('autoyast/installation');
        loadtest('shutdown/cleanup_before_shutdown');
        loadtest('shutdown/shutdown');
    }
    return 1;
}

sub load_extra_tests_udev {
    loadtest "kernel/udev_no_symlink";
}

sub load_nfv_master_tests {
    loadtest "nfv/prepare_env";
    loadtest "nfv/run_performance_tests";
    loadtest "nfv/run_integration_tests" if (is_qemu);
}

sub load_nfv_trafficgen_tests {
    loadtest "nfv/trex_installation";
    loadtest "nfv/trex_runner";
}

sub load_iso_in_external_tests {
    # Switch to the version of the booted HDD if different
    if (get_var("ORIGIN_SYSTEM_VERSION")) {
        set_var("UPGRADE_TARGET_VERSION", get_var("VERSION"));
        loadtest "migration/version_switch_origin_system";
    }
    loadtest "boot/boot_to_desktop";
    loadtest "console/copy_iso_to_external_drive";
    loadtest "x11/reboot_and_install";
    loadtest "migration/version_switch_upgrade_target" if get_var("UPGRADE_TARGET_VERSION");
}

sub load_x11_installation {
    set_var('NOAUTOLOGIN', 1) if is_opensuse;
    load_boot_tests();
    load_inst_tests();
    load_reboot_tests();
    loadtest "x11/x11_setup";
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests;
    loadtest "console/system_prepare";
    loadtest "console/hostname" unless is_bridged_networking;
    loadtest "console/force_scheduled_tasks" unless is_jeos;
    loadtest "shutdown/grub_set_bootargs";
    load_shutdown_tests;
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
    if (is_sle('>=15')) {
        loadtest "x11/libreoffice/libreoffice_mainmenu_favorites";
        loadtest "x11/libreoffice/libreoffice_pyuno_bridge_no_evolution_dep";
    }
    elsif (is_sle('>=12-SP1')) {
        loadtest "x11/libreoffice/libreoffice_mainmenu_favorites";
        loadtest "x11/evolution/evolution_prepare_servers";
        loadtest "x11/libreoffice/libreoffice_pyuno_bridge";
    }
    loadtest "x11/libreoffice/libreoffice_open_specified_file";
}

sub load_x11_gnome {
    return unless check_var('DESKTOP', 'gnome');
    if (is_sle('12-SP2+')) {
        loadtest "x11/gdm_session_switch";
    }
    loadtest "x11/gnomecase/nautilus_cut_file";
    loadtest "x11/gnomecase/nautilus_permission";
    loadtest "x11/gnomecase/nautilus_open_ftp";
    loadtest "x11/gnomecase/application_starts_on_login";
    loadtest "x11/gnomecase/login_test";
    if (is_sle '12-SP1+') {
        loadtest "x11/gnomecase/gnome_classic_switch";
    }
    loadtest "x11/gnomecase/gnome_default_applications";
    loadtest "x11/gnomecase/gnome_window_switcher";
    loadtest "x11/gnomecase/change_password";
}

sub load_x11_other {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11/brasero/brasero_launch";
        loadtest "x11/gnome_documents" if (is_sle('<16') || is_leap('<16.0'));
        loadtest "x11/totem/totem_launch";
        if (is_sle '15+') {
            loadtest "x11/xterm";
            loadtest "x11/sshxterm";
            loadtest "x11/gnome_control_center";
            loadtest "x11/gnome_tweak_tool";
            loadtest "x11/seahorse";
            loadtest "x11/gnome_music";
        }
        loadtest 'x11/flatpak' if (is_opensuse);
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
        if (is_sle('<15')) {
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

sub load_x11_webbrowser {
    loadtest "x11/firefox/firefox_smoke";
    loadtest "x11/firefox/firefox_urlsprotocols";
    loadtest "x11/firefox/firefox_downloading";
    loadtest "x11/firefox/firefox_changesaving";
    loadtest "x11/firefox/firefox_fullscreen";
    loadtest "x11/firefox/firefox_localfiles";
    loadtest "x11/firefox/firefox_headers";
    loadtest "x11/firefox/firefox_pdf";
    loadtest "x11/firefox/firefox_pagesaving";
    loadtest "x11/firefox/firefox_private";
    loadtest "x11/firefox/firefox_extensions";
    loadtest "x11/firefox/firefox_appearance";
    loadtest "x11/firefox/firefox_passwd";
    loadtest "x11/firefox/firefox_html5";
    loadtest "x11/firefox/firefox_developertool";
    loadtest "x11/firefox/firefox_ssl";
    loadtest "x11/firefox/firefox_emaillink";
    loadtest "x11/firefox/firefox_plugins";
    loadtest "x11/firefox/firefox_extcontent";
    if (!get_var("OFW") && is_qemu) {
        loadtest "x11/firefox_audio";
    }
}


sub load_x11_remote {
    # load onetime vncsession testing
    if (check_var('REMOTE_DESKTOP_TYPE', 'one_time_vnc')) {
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_tigervnc';
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_remmina' if is_sle('>=15');
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_java' if is_sle('<12-sp4');
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
    # load xrdp testing
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'win_client')) {
        loadtest 'x11/remote_desktop/windows_network_setup';
        loadtest 'x11/remote_desktop/windows_client_remotelogin';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'xrdp_server')) {
        loadtest 'x11/remote_desktop/xrdp_server';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'xrdp_client')) {
        loadtest 'x11/remote_desktop/xrdp_client';
    }
    elsif (check_var('REMOTE_DESKTOP_TYPE', 'win_server')) {
        loadtest 'x11/remote_desktop/windows_network_setup';
        loadtest 'x11/remote_desktop/windows_server_setup';
    }
}


sub load_common_x11 {
    # Used by QAM testing
    if (check_var("REGRESSION", "installation")) {
        load_x11_installation;
    }
    elsif (check_var("REGRESSION", "gnome")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        load_x11_gnome();
    }
    elsif (check_var("REGRESSION", "documentation")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        load_x11_documentation();
    }
    elsif (check_var("REGRESSION", "other")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        loadtest "console/consoletest_setup";
        load_x11_other();
    }
    elsif (check_var("REGRESSION", "firefox")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        loadtest 'x11/disable_screensaver';
        load_x11_webbrowser();
    }
    elsif (check_var('REGRESSION', 'remote')) {
        if (check_var("REMOTE_DESKTOP_TYPE", "win_client") || check_var('REMOTE_DESKTOP_TYPE', "win_server")) {
            loadtest "x11/remote_desktop/windows_client_boot";
        }
        else {
            loadtest 'boot/boot_to_desktop';
            loadtest "x11/window_system";
        }
        load_x11_remote();
    }
    elsif (check_var("REGRESSION", "piglit")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        loadtest "x11/disable_screensaver";
        loadtest "x11/piglit/piglit";
    }
    # Used by ibus tests
    elsif (check_var("REGRESSION", "ibus")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/ibus/ibus_installation";
        loadtest "x11/ibus/ibus_test_cn";
        loadtest "x11/ibus/ibus_test_jp";
        loadtest "x11/ibus/ibus_test_kr";
        loadtest "x11/ibus/ibus_clean";
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

sub load_security_console_prepare {
    loadtest "console/consoletest_setup";
    # Add this setup only in product testing
    loadtest "security/test_repo_setup" if (get_var("SECURITY_TEST") =~ /^crypt_/ && !is_opensuse && (get_var("BETA") || check_var("FLAVOR", "Online-QR")));
    loadtest "fips/fips_setup" if (get_var("FIPS_ENABLED"));
    loadtest "console/openssl_alpn" if (get_var("FIPS_ENABLED") && get_var("JEOS"));
    loadtest "console/yast2_vnc" if (get_var("FIPS_ENABLED") && is_pvm);
}

# The function name load_security_tests_crypt_* is to avoid confusing
# since openSUSE does NOT have FIPS mode
# Some tests are valid only for FIPS Regression testing. Use
# "FIPS_ENABLED" to control whether to run these "FIPS only" cases
sub load_security_tests_crypt_core {
    load_security_console_prepare;

    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/openssl/openssl_fips_alglist";
        loadtest "fips/openssl/openssl_fips_hash";
        loadtest "fips/openssl/openssl_fips_cipher";
        loadtest "fips/openssl/dirmngr_setup";
        loadtest "fips/openssl/dirmngr_daemon";    # dirmngr_daemon needs to be tested after dirmngr_setup
        loadtest "fips/gnutls/gnutls_base_check";
        loadtest "fips/gnutls/gnutls_server";
        loadtest "fips/gnutls/gnutls_client";
    }
    loadtest "fips/openssl/openssl_tlsv1_3";
    loadtest "fips/openssl/openssl_pubkey_rsa";
    loadtest "fips/openssl/openssl_pubkey_dsa";
    loadtest "fips/openssh/openssh_fips" if get_var("FIPS_ENABLED");
    loadtest "console/sshd";
    loadtest "console/ssh_cleanup";
}


sub load_security_tests_crypt_web {
    load_security_console_prepare;

    loadtest "console/curl_https";
    loadtest "console/wget_https";
    loadtest "console/w3m_https";
    if (is_sle('15+') || is_tumbleweed) {
        loadtest "console/links_https";
        loadtest "console/lynx_https";
    }
    loadtest "console/apache_ssl";
    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/mozilla_nss/apache_nssfips";
        loadtest "console/libmicrohttpd" if is_sle('<15');
    }
}

sub load_security_tests_crypt_kernel {
    load_security_console_prepare;

    loadtest "console/cryptsetup";
    loadtest "security/dm_crypt";
}

sub load_security_tests_crypt_x11 {
    set_var('SECTEST_REQUIRE_WE', 1);
    load_security_console_prepare;

    # In SLE, hexchat and seahorse are provided only in WE addon which is for
    # x86_64 platform only.
    if (is_x86_64) {
        loadtest "x11/seahorse_sshkey";
        loadtest "x11/hexchat_ssl";
    }
    loadtest "x11/x3270_ssl";
}

sub load_security_tests_crypt_firefox {
    load_security_console_prepare;

    loadtest "fips/mozilla_nss/firefox_nss" if get_var('FIPS_ENABLED');
}

sub load_security_tests_crypt_openjdk {
    load_security_console_prepare;

    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/openjdk/openjdk_fips";
        loadtest "fips/openjdk/openjdk_ssh";
    }
}

sub load_security_tests_crypt_tool {
    load_security_console_prepare;

    if (get_var('FIPS_ENABLED')) {
        loadtest "fips/curl_fips_rc4_seed";
        loadtest "console/aide_check";
    }
    loadtest "console/gpg";
    loadtest "console/journald_fss";
    loadtest "console/git";
    loadtest "console/clamav";
    loadtest "console/openvswitch_ssl";
    loadtest "console/ntp_client";
    loadtest "console/cups";
    loadtest "console/syslog";
    loadtest "x11/evolution/evolution_prepare_servers";
    loadtest "console/mutt";
}

sub load_security_tests_crypt_libtool {
    load_security_console_prepare;

    loadtest "fips/libtool/liboauth";
}

sub load_security_tests_fips_setup {
    # Setup system into fips mode
    loadtest "fips/fips_setup";
}

sub load_security_tests_ipsec {
    load_security_console_prepare;

    loadtest "console/ipsec_tools_h2h";
}

sub load_security_tests_mmtest {
    load_security_console_prepare;

    # Load client tests by APPTESTS variable
    load_applicationstests;
}

sub load_security_tests_apparmor {
    load_security_console_prepare;

    if (check_var('TEST', 'mau-apparmor') || is_jeos) {
        loadtest "security/apparmor/aa_prepare";
    }
    loadtest "security/apparmor/aa_status";
    loadtest "security/apparmor/aa_enforce";
    loadtest "security/apparmor/aa_complain";
    loadtest "security/apparmor/aa_genprof";
    loadtest "security/apparmor/aa_autodep";
    loadtest "security/apparmor/aa_logprof";
    loadtest "security/apparmor/aa_easyprof";
    loadtest "security/apparmor/aa_notify";
    loadtest "security/apparmor/aa_disable";
}

sub load_security_tests_apparmor_profile {
    if (check_var('TEST', 'mau-apparmor_profile')) {
        load_security_console_prepare;
        loadtest "security/apparmor/aa_prepare";
    }
    else {
        load_security_console_prepare;
    }
    loadtest "security/apparmor_profile/usr_sbin_smbd";
    loadtest "security/apparmor_profile/apache2_changehat";
    loadtest "security/apparmor_profile/usr_sbin_dovecot";
    loadtest "security/apparmor_profile/usr_sbin_traceroute";
    loadtest "security/apparmor_profile/usr_sbin_nscd";
    # ALWAYS run ".*usr_lib_dovecot_*" after "mailserver_setup" for the dependencies
    loadtest "security/apparmor_profile/mailserver_setup";
    loadtest "security/apparmor_profile/usr_lib_dovecot_pop3";
    loadtest "security/apparmor_profile/usr_lib_dovecot_imap";
}

sub load_security_tests_yast2_apparmor {
    load_security_console_prepare;

    loadtest "security/yast2_apparmor/settings_disable_enable_apparmor";
    loadtest "security/yast2_apparmor/settings_toggle_profile_mode";
    loadtest "security/yast2_apparmor/scan_audit_logs_ncurses";
    loadtest "security/yast2_apparmor/manually_add_profile_ncurses";
}

sub load_security_tests_yast2_users {
    load_security_console_prepare;

    loadtest "security/yast2_users/add_users";
}

sub load_security_tests_lynis {
    load_security_console_prepare;

    loadtest "security/lynis/lynis_setup";
    loadtest "security/lynis/lynis_perform_system_audit";
    loadtest "security/lynis/lynis_analyze_system_audit";
    loadtest "security/lynis/lynis_harden_index";
}

sub load_security_tests_openscap {
    # ALWAYS run following tests in sequence because of the dependencies

    load_security_console_prepare;

    # Setup - download test files and install necessary packages
    loadtest "security/openscap/oscap_setup";

    loadtest "security/openscap/oscap_info";
    loadtest "security/openscap/oscap_oval_scanning";
    loadtest "security/openscap/oscap_xccdf_scanning";
    loadtest "security/openscap/oscap_source_datastream";
    loadtest "security/openscap/oscap_result_datastream";
    loadtest "security/openscap/oscap_remediating_online";
    loadtest "security/openscap/oscap_remediating_offline";
    loadtest "security/openscap/oscap_generating_report";
    loadtest "security/openscap/oscap_generating_fix";
    loadtest "security/openscap/oscap_validating";
}

sub load_security_tests_cc_audit_test {
    # Setup environment for cc testing: 'audit-test' test suite setup
    # Such as: download code branch; install needed packages
    loadtest 'security/cc/cc_audit_test_setup';

    # For s390x, we enable root ssh when installing system, so we need to
    # disable root ssh login, because this is a requirement for cc testing.
    loadtest 'security/cc/disable_root_ssh' if (is_s390x);

    # Run test cases of 'audit-test' test suite which do NOT need SELinux env
    loadtest 'security/cc/audit_tools';
    loadtest 'security/cc/fail_safe';
    loadtest 'security/cc/ip_eb_tables';
    loadtest 'security/cc/kvm_svirt_apparmor';
    loadtest 'security/cc/extended_apparmor_interface_trace_test';
    loadtest 'security/cc/apparmor_negative_test';

    # For s390x, we should enable root ssh before rebooting, otherwise, the automation test
    # will fail on can't login the system.
    if (is_s390x) {
        my $root_ssh_switch = OpenQA::Test::RunArgs->new();
        $root_ssh_switch->{option} = 'yes';
        loadtest('security/cc/disable_root_ssh', name => 'enable_root_ssh', run_args => $root_ssh_switch);
    }
    # Some audit tests must be run in selinux enabled mode. so load selinux setup here
    # Setup environment for cc testing: SELinux setup
    # Such as: set up SELinux with permissive mode and specific policy type
    loadtest 'security/selinux/selinux_setup';
    loadtest 'security/cc/cc_selinux_setup';

    # When system reboot, we need to disable root ssh for following tests
    loadtest 'security/cc/disable_root_ssh' if (is_s390x);

    # Run test cases of 'audit-test' test suite which do need SELinux env
    # Please add these test cases here: poo#93441
    loadtest 'security/cc/crypto';
    loadtest 'security/cc/misc';
}

sub load_security_tests_cc_audit_remote_libvirt {
    # Setup environment for cc testing: 'audit-test' test suite setup
    # Such as: download code branch; install needed packages
    loadtest 'security/cc/cc_audit_test_setup';

    # Run test cases of 'audit-test' test suite which do NOT need SELinux env
    loadtest 'security/cc/audit_remote_libvirt';
}

sub load_security_tests_mok_enroll {
    loadtest "security/mokutil_sign";
}

sub load_security_tests_check_kernel_config {
    load_security_console_prepare;

    loadtest "security/check_kernel_config/CC_STACKPROTECTOR_STRONG" if (is_sle);
    loadtest "security/check_kernel_config/CONFIG_FORTIFY_SOURCE";
    loadtest "security/check_kernel_config/dm_crypt";
}

sub load_security_tests_pam {
    load_security_console_prepare;

    loadtest "security/pam/pam_basic_function";
    loadtest "security/pam/pam_login";
    loadtest "security/pam/pam_su";
    loadtest "security/pam/pam_config";
    loadtest "security/pam/pam_mount";
    loadtest "security/pam/pam_faillock";
    loadtest "security/pam/pam_u2f";
}

sub load_security_tests_create_swtpm_hdd {
    load_security_console_prepare;

    loadtest "security/create_swtpm_hdd/build_hdd";
}

sub load_security_tests_swtpm {
    load_security_console_prepare;

    loadtest "security/swtpm/swtpm_env_setup";
    loadtest "security/swtpm/swtpm_verify";
}

sub load_security_tests_grub_auth {
    load_security_console_prepare;

    loadtest "security/grub_auth/grub_authorization";
}

sub load_security_tests_tpm2 {
    if (is_sle('>=15-SP2')) {
        load_security_console_prepare;

        loadtest "security/tpm2/tpm2_env_setup";
        loadtest "security/tpm2/tpm2_engine/tpm2_engine_info";
        loadtest "security/tpm2/tpm2_engine/tpm2_engine_random_data";
        loadtest "security/tpm2/tpm2_engine/tpm2_engine_rsa_operation";
        loadtest "security/tpm2/tpm2_engine/tpm2_engine_ecdsa_operation";
        loadtest "security/tpm2/tpm2_engine/tpm2_engine_self_sign";
        loadtest "security/tpm2/tpm2_tools/tpm2_tools_self_contain_tool";
        loadtest "security/tpm2/tpm2_tools/tpm2_tools_encrypt";
        loadtest "security/tpm2/tpm2_tools/tpm2_tools_sign_verify";
        loadtest "security/tpm2/tpm2_tools/tpm2_tools_auth";
    }
}

sub load_vt_perf_tests {
    loadtest "virt_autotest/login_console";
    if (get_var('VT_PERF_BAREMETAL')) {
        loadtest 'vt_perf/baremetal';
    }
    elsif (get_var('VT_PERF_KVM_GUEST')) {
        loadtest 'vt_perf/kvm_guest';
    }
    elsif (get_var('VT_PERF_XEN_GUEST')) {
        loadtest 'vt_perf/xen_guest';
    }
}
sub load_mitigation_tests {
    if (is_ipmi) {
        loadtest "virt_autotest/login_console";
    }
    elsif (is_qemu) {
        boot_hdd_image;
        loadtest "console/system_prepare";
        loadtest "console/consoletest_setup";
        loadtest "console/hostname";
        if (get_var('PREPARE_REPO')) {
            loadtest "cpu_bugs/add_repos_qemu";
        }
    }
    if (get_var('IPMI_TO_QEMU')) {
        loadtest "cpu_bugs/ipmi_to_qemu";
    }
    if (get_var('IPMI_FAKE_SERVER')) {
        loadtest "cpu_bugs/ipmi_fake_server";
    }
    if (get_var('XEN_GRUB_SETUP')) {
        loadtest "cpu_bugs/xen_grub_setup";
    }
    if (get_var('MITIGATION_ENV_SETUP')) {
        loadtest "cpu_bugs/mitigation_env_setup";
    }
    if (get_var('MELTDOWN')) {
        loadtest "cpu_bugs/meltdown";
    }
    if (get_var('SPECTRE_V2')) {
        loadtest "cpu_bugs/spectre_v2";
    }
    if (get_var('SPECTRE_V2_USER')) {
        loadtest "cpu_bugs/spectre_v2_user";
    }
    if (get_var('SPECTRE_V4')) {
        loadtest "cpu_bugs/spectre_v4";
    }
    if (get_var('MDS')) {
        loadtest "cpu_bugs/mds";
    }
    if (get_var('L1TF')) {
        loadtest "cpu_bugs/l1tf";
    }
    if (get_var('MITIGATIONS')) {
        loadtest "cpu_bugs/mitigations";
    }
    if (get_var('KVM_GUEST_INST')) {
        loadtest "autoyast/prepare_profile";
        loadtest "cpu_bugs/kvm_guest_install";
    }
    if (get_var('KVM_GUEST_MIGRATION')) {
        loadtest "cpu_bugs/kvm_guest_migration";
    }
    if (get_var('XEN_MITIGATIONS')) {
        loadtest "cpu_bugs/xen_mitigations";
    }
    if (get_var('SPECTRE_V1')) {
        loadtest "cpu_bugs/spectre_v1";
    }
    if (get_var('TAA')) {
        loadtest "cpu_bugs/taa";
    }
    if (get_var('MDS_TAA')) {
        loadtest "cpu_bugs/mds_taa";
    }
    if (get_var('ITLB')) {
        loadtest "cpu_bugs/itlb";
    }
    if (get_var('XEN_PV') or get_var('XEN_HVM')) {
        loadtest "cpu_bugs/xen_domu_mitigation_test";
    }
    if (get_var('MITIGATION_PERF')) {
        loadtest "cpu_bugs/mitigation_perf";
    }
}

sub load_security_tests {
    my @security_tests = qw(
      fips_setup crypt_core crypt_web crypt_kernel crypt_x11 crypt_firefox crypt_tool crypt_openjdk
      crypt_libtool
      ipsec mmtest
      apparmor apparmor_profile yast2_apparmor yast2_users
      openscap
      mok_enroll
      check_kernel_config
      tpm2
      pam
      create_swtpm_hdd
      swtpm
      grub_auth
      lynis
      cc_audit_test
      cc_audit_remote_libvirt
    );

    # Check SECURITY_TEST and call the load functions iteratively.
    # The value of "SECURITY_TEST" should be same with the last part of the
    # function name by this way.
    foreach my $test_name (@security_tests) {
        next unless (check_var("SECURITY_TEST", $test_name));
        if (my $test_to_run = main_common->can("load_security_tests_$test_name")) {
            $test_to_run->();
        }
        else {
            diag "unknown scenario for SECURITY_TEST value $test_name";
        }
    }
}

sub load_system_prepare_tests {
    loadtest 'console/system_prepare' unless is_opensuse;
    loadtest 'ses/install_ses' if check_var_array('ADDONS', 'ses') || check_var_array('SCC_ADDONS', 'ses');
    if (is_updates_tests and !get_var("USER_SPACE_TESTSUITES")) {
        if (is_transactional) {
            loadtest 'transactional/install_updates';
        } else {
            loadtest 'qa_automation/patch_and_reboot';
        }
    }
    loadtest 'console/integration_services' if is_hyperv || is_vmware;
    loadtest 'console/hostname' unless is_bridged_networking;
    loadtest 'console/install_rt_kernel' if check_var('SLE_PRODUCT', 'SLERT');
    loadtest 'console/force_scheduled_tasks' unless is_jeos;
    loadtest 'console/check_selinux_fails' if get_var('SELINUX');
    loadtest 'security/cc/ensure_crypto_checks_enabled' if check_var('SYSTEM_ROLE', 'Common_Criteria');
    # Remove repos pointing to download.opensuse.org and add snaphot repo from o3
    replace_opensuse_repos_tests if is_repo_replacement_required;
    loadtest 'console/scc_deregistration' if get_var('SCC_DEREGISTER');
    loadtest 'shutdown/grub_set_bootargs';
}

sub load_create_hdd_tests {
    return unless get_var('INSTALLONLY');
    # install SES packages and deepsea testsuites
    load_system_prepare_tests;
    load_shutdown_tests;
    if (is_svirt) {
        if (is_hyperv) {
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

sub load_hypervisor_tests {
    return unless (get_var('HOST_HYPERVISOR') =~ /xen|kvm|qemu/);
    return unless get_var('VIRT_PART');
    my $windows = check_var('VIRT_PART', 'windows');

    # Install hypervisor via autoyast or manually
    loadtest "autoyast/prepare_profile" if get_var "AUTOYAST_PREPARE_PROFILE";
    load_boot_tests if check_var('VIRT_PART', 'install');

    if (get_var("AUTOYAST")) {
        loadtest "autoyast/installation";
        loadtest "virt_autotest/reboot_and_wait_up_normal";
    }
    else {
        load_inst_tests if check_var('VIRT_PART', 'install');
    }

    loadtest "virt_autotest/login_console";

    if (check_var('VIRT_PART', 'install')) {
        loadtest 'virtualization/universal/prepare_guests';    # Prepare libvirt and install guests
        loadtest 'virtualization/universal/ssh_hypervisor_init';    # Configure SSH for hypervisor
        loadtest 'virtualization/universal/waitfor_guests';    # Wait for guests to be installed

        loadtest 'virtualization/universal/ssh_guests_init';    # Fetch SSH key from guests and connect
        loadtest 'virtualization/universal/register_guests';    # Register guests against the SMT server
        loadtest 'virtualization/universal/upgrade_guests';    # Upgrade all guests
        loadtest 'virtualization/universal/patch_guests';    # Apply patches to all compatible guests
        loadtest 'virtualization/universal/patch_and_reboot';    # Apply updates and reboot

        loadtest "virt_autotest/login_console";
    }

    loadtest "virtualization/universal/list_guests" unless ($windows);    # List all guests and ensure they are running

    if (check_var('VIRT_PART', 'install')) {
        loadtest "virtualization/universal/kernel";    # Virtualization kernel functions
    }

    if (check_var('VIRT_PART', 'virtmanager')) {
        loadtest 'virtualization/universal/virtmanager_init';    # Connect to the Xen hypervisor using virt-manager
        loadtest 'virtualization/universal/virtmanager_offon';    # Turn all VMs off and then on again

        if (is_sle('12-SP3+')) {
            loadtest 'virtualization/universal/virtmanager_add_devices';    # Add some aditional HV to all VMs
            loadtest 'virtualization/universal/virtmanager_rm_devices';    # Remove the aditional HV from all VMs
        }
    }


    if (check_var('VIRT_PART', 'save_and_restore')) {
        loadtest 'virtualization/universal/save_and_restore';    # Try to save and restore the state of the guest
    }

    if (check_var('VIRT_PART', 'guest_management')) {
        loadtest 'virtualization/universal/guest_management';    # Try to shutdown, start, suspend and resume the guest
    }

    if (check_var('VIRT_PART', 'dom_metrics')) {
        loadtest 'virtualization/universal/virsh_stop';    # Stop libvirt guests
        loadtest 'virtualization/universal/xl_create';    # Clone guests using the xl Xen tool
        loadtest 'virtualization/universal/dom_install';    # Install vhostmd and vm-dump-metrics
        loadtest 'virtualization/universal/dom_metrics';    # Collect some sample metrics
        loadtest 'virtualization/universal/xl_stop';    # Stop guests created by the xl Xen tool
        loadtest 'virtualization/universal/virsh_start';    # Start virsh guests again
    }

    if (check_var('VIRT_PART', 'hotplugging')) {
        loadtest 'virtualization/universal/hotplugging_guest_preparation';    # Prepare guests
        loadtest 'virtualization/universal/hotplugging_network_interfaces';    # Virtual network hotplugging
        loadtest 'virtualization/universal/hotplugging_HDD';    # Virtual block device hotplugging
        loadtest 'virtualization/universal/hotplugging_vCPUs';    # Add and remove guests vCPU
        loadtest 'virtualization/universal/hotplugging_memory';    # Live memory change of guests
        loadtest 'virtualization/universal/hotplugging_cleanup';    # Restore guests properties
    }

    if (check_var('VIRT_PART', 'networking')) {
        loadtest "virt_autotest/libvirt_host_bridge_virtual_network";
        loadtest "virt_autotest/libvirt_nated_virtual_network";
        loadtest "virt_autotest/libvirt_isolated_virtual_network";
    }

    if (check_var('VIRT_PART', 'irqbalance')) {
        loadtest "virt_autotest/xen_guest_irqbalance";
    }

    if (check_var('VIRT_PART', 'snapshots')) {
        loadtest "virt_autotest/virsh_internal_snapshot";
        loadtest "virt_autotest/virsh_external_snapshot";

    }

    if (check_var('VIRT_PART', 'storage')) {
        loadtest 'virtualization/universal/storage';    # Storage pool / volume test
    }

    if (check_var('VIRT_PART', 'final')) {
        loadtest 'virtualization/universal/ssh_final';    # Check that every guest is reachable over SSH
        loadtest 'virtualization/universal/virtmanager_final';    # Check that every guest shows the login screen
        loadtest "virtualization/universal/smoketest";    # Virtualization smoke test for hypervisor
        loadtest "virtualization/universal/stresstest";    # Perform stress tests on the guests
        loadtest "console/perf";
        loadtest "console/oprofile" unless (get_var("REGRESSION", '') =~ /xen/);
    }

    if ($windows) {
        loadtest "virtualization/universal/download_image";    # Download Windows disk image(s)
        loadtest "virtualization/universal/windows";    # Import and test Windows
    }

    loadtest "virtualization/universal/finish";    # Collect logs
}

sub load_extra_tests_syscontainer {
    return unless get_var('SYSCONTAINER_IMAGE_TEST');
    # pre-conditions for system container tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/system_prepare";
    loadtest "console/check_network";
    loadtest "console/system_state";
    loadtest "console/prepare_test_data";
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

sub load_extra_tests_kernel {
    loadtest "kernel/module_build";
    loadtest "kernel/tuned";
    loadtest "kernel/fwupd" if is_sle('15+');
}

# Scheduling set for validation of specific installation
sub load_installation_validation_tests {
    load_system_prepare_tests;
    # See description of INSTALLATION_VALIDATION in variables.md
    # Possible values:
    # - console/lvm_thin_check: validate thin LVM installation
    # - autoyast/verify_disk_as_pv validates: installation using autoyast_disk_as_pv.xml profile
    # - autoyast/verify_disk_as_pv_clone: validates generated profile when cloning system
    #                                      installed using autoyast_disk_as_pv.xml profile
    # - autoyast/verify_btrfs: validates installation using autoyast_btrfs.xml profile
    # - autoyast/verify_btrfs_clone: validates enerated profile when cloning system
    #                                      installed using autoyast_btrfs.xml profile
    # - autoyast/verify_ext4: validate installation using autoyast_ext4 profile
    # - console/verify_no_separate_home.pm: validate if separate /home partition disabled
    # - console/verify_separate_home.pm: validate if separate /home partition enabled
    # - console/validate_lvm_: validate lvm partitioning
    # - console/validate_encrypt: validate encrypted paritioning
    # - console/autoyast_smoke: validate autoyast installation
    # - installation/validation/ibft: validate autoyast installation
    # - console/validate_raid: validate raid layout partitioning
    for my $module (split(',', get_var('INSTALLATION_VALIDATION'))) {
        loadtest $module;
    }
}

sub load_transactional_role_tests {
    replace_opensuse_repos_tests if is_repo_replacement_required;
    loadtest 'transactional/filesystem_ro';
    loadtest 'transactional/transactional_update';
    loadtest 'transactional/rebootmgr';
    loadtest 'transactional/health_check';
}

sub load_common_opensuse_sle_tests {
    load_autoyast_clone_tests if get_var("CLONE_SYSTEM");
    loadtest "terraform/create_image" if get_var('TERRAFORM');
    load_create_hdd_tests if (get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1")) && !get_var('PUBLIC_CLOUD');
    loadtest 'console/network_hostname' if get_var('NETWORK_CONFIGURATION');
    load_installation_validation_tests if get_var('INSTALLATION_VALIDATION');
    load_transactional_role_tests if is_transactional && (get_var('ARCH') !~ /ppc64|s390/) && !get_var('INSTALLONLY');
}

sub load_ssh_key_import_tests {
    # Switch to the version of the booted HDD if different
    if (get_var("ORIGIN_SYSTEM_VERSION")) {
        set_var("UPGRADE_TARGET_VERSION", get_var("VERSION"));
        loadtest "migration/version_switch_origin_system";
    }
    loadtest "boot/boot_to_desktop";
    # setup ssh key, we know what ssh keys we have and can verify if they are imported or not
    loadtest "x11/ssh_key_check";
    # reboot after test specific setup and start installation/update
    loadtest "x11/reboot_and_install";
    loadtest "migration/version_switch_upgrade_target" if get_var("UPGRADE_TARGET_VERSION");
    load_inst_tests();
    load_reboot_tests();
    # verify previous defined ssh keys
    loadtest "x11/ssh_key_verify";
}

sub load_sles4sap_tests {
    return if get_var('INSTALLONLY');
    loadtest "console/check_os_release";
    loadtest "sles4sap/desktop_icons" if (is_desktop_installed());
    loadtest "sles4sap/patterns";
    loadtest "sles4sap/sapconf";
    loadtest "sles4sap/saptune";
    loadtest "sles4sap/saptune/mr_test" if (get_var('MR_TEST'));
    if (get_var('NW')) {
        loadtest "sles4sap/netweaver_install" if (get_var('SLES4SAP_MODE') !~ /wizard/);
        loadtest "sles4sap/netweaver_test_instance";
    } elsif (get_var('HANA')) {
        loadtest "sles4sap/hana_install" if (get_var('SLES4SAP_MODE') !~ /wizard/);
        loadtest "sles4sap/hana_test";
    }
}

sub load_ha_cluster_tests {
    return unless get_var('HA_CLUSTER');

    # When not using a support server, node 1 setups barriers and mutex
    loadtest 'ha/barrier_init' if (get_var('HOSTNAME') =~ /node01$/ and !get_var('USE_SUPPORT_SERVER'));

    # Standard boot
    boot_hdd_image;

    # Only SLE-15+ has support for lvmlockd
    set_var('USE_LVMLOCKD', 0) if (get_var('USE_LVMLOCKD') and is_sle('<15'));

    # Wait for barriers to be initialized except when testing with a client
    # HAWK, Pacemaker CTS regression tests or CTDB
    loadtest 'ha/wait_barriers' unless (check_var('HAWKGUI_TEST_ROLE', 'client') or
        (get_var('PACEMAKER_CTS_REG')) or (check_var('PACEMAKER_CTS_TEST_ROLE', 'client')) or
        (check_var('CTDB_TEST_ROLE', 'client')));

    # Test HA after an upgrade, so no need to configure the HA stack
    if (get_var('HDDVERSION')) {
        loadtest 'ha/setup_hosts_and_luns' unless get_var('USE_SUPPORT_SERVER');
        loadtest 'ha/upgrade_from_sle11sp4_workarounds' if check_var('HDDVERSION', '11-SP4');
        loadtest 'ha/migrate_clvmd_to_lvmlockd' if (is_sle('15-SP2+') and get_var('HDDVERSION') =~ /1[12]-SP/);
        loadtest 'ha/check_after_reboot';
        loadtest 'ha/check_hawk';
        return 1;
    }

    loadtest "console/system_prepare";
    loadtest 'console/consoletest_setup';
    loadtest 'console/check_os_release';
    loadtest 'console/hostname';

    # If HAWKGUI_TEST_ROLE is set to client, only load client side test
    if (check_var('HAWKGUI_TEST_ROLE', 'client')) {
        loadtest 'ha/hawk_gui';
        return 1;
    }

    # If CTDB_TEST_ROLE is set to client, only load client side test
    if (check_var('CTDB_TEST_ROLE', 'client')) {
        loadtest 'ha/ctdb';
        return 1;
    }

    # If PACEMAKER_CTS_TEST_ROLE is set to client, only load client side test
    if (check_var('PACEMAKER_CTS_TEST_ROLE', 'client')) {
        loadtest 'ha/pacemaker_cts_cluster_exerciser';
        return 1;
    }

    # Only do pacemaker-cts regression tests if PACEMAKER_CTS_REG is set
    if (get_var('PACEMAKER_CTS_REG')) {
        loadtest 'ha/pacemaker_cts_regression';
        return 1;
    }

    # NTP is already configured with 'HA node' and 'HA GEO node' System Roles
    # 'default' System Role is 'HA node' if HA Product is selected
    # NTP is also already configured in SLES4SAP
    loadtest 'console/yast2_ntpclient' unless (get_var('SYSTEM_ROLE', '') =~ /default|ha/ || is_sles4sap);

    # Update the image if needed
    if (get_var('FULL_UPDATE')) {
        loadtest 'update/zypper_up';
        loadtest 'console/console_reboot';
    }

    # SLE15 workarounds
    loadtest 'ha/ha_sle15_workarounds' if is_sle('15+');

    # Basic configuration
    loadtest 'ha/firewall_disable';
    loadtest 'ha/iscsi_client';
    loadtest 'ha/setup_hosts_and_luns' unless get_var('USE_SUPPORT_SERVER');
    loadtest 'ha/watchdog';

    # Some patterns/packages may be needed for SLES4SAP
    loadtest 'sles4sap/patterns' if is_sles4sap;

    # Cluster initialisation
    if (get_var('USE_YAST_CLUSTER')) {
        check_var('HA_CLUSTER_INIT', 'yes') ? loadtest 'ha/yast_cluster_init' : loadtest 'ha/yast_cluster_join';
        loadtest 'ha/sbd';
    }
    else {
        check_var('HA_CLUSTER_INIT', 'yes') ? loadtest 'ha/ha_cluster_init' : loadtest 'ha/ha_cluster_join';
    }

    # Cluster tests are different if we use SLES4SAP
    if (is_sles4sap) {
        # Test NetWeaver cluster
        if (get_var('NW')) {
            loadtest 'sles4sap/netweaver_network';
            loadtest 'sles4sap/netweaver_filesystems';
            loadtest 'sles4sap/netweaver_install';
            loadtest 'sles4sap/netweaver_cluster';
        } elsif (get_var('HANA')) {
            loadtest 'sles4sap/hana_install';
            loadtest 'sles4sap/hana_cluster';
        }
        loadtest 'sles4sap/sap_suse_cluster_connector' if (check_var('HA_CLUSTER_INIT', 'yes'));
    }
    else {
        # Test Hawk Web interface
        loadtest 'ha/check_hawk';

        if (get_var('PACEMAKER_CTS_TEST_ROLE')) {
            loadtest 'ha/pacemaker_cts_cluster_exerciser';
            return 1;
        }

        # If testing HAWK's GUI or HAPROXY, skip the rest of the cluster
        # setup tests and only check logs
        if (get_var('HAWKGUI_TEST_ROLE') or get_var('HA_CLUSTER_HAPROXY')) {
            if (get_var('HAWKGUI_TEST_ROLE')) {
                # Node1 will be fenced
                boot_hdd_image if check_var('HA_CLUSTER_INIT', 'yes');
                loadtest 'ha/check_after_reboot';
            }
            # Test Haproxy
            loadtest 'ha/haproxy' if (get_var('HA_CLUSTER_HAPROXY'));
            loadtest 'ha/check_logs' if !get_var('INSTALLONLY');
            return 1;
        }

        # Lock manager configuration
        loadtest 'ha/dlm';
        loadtest 'ha/clvmd_lvmlockd';

        # Test cluster-md feature
        loadtest 'ha/cluster_md';
        loadtest 'ha/vg';
        loadtest 'ha/filesystem';

        # Test ctdb feature
        if (check_var('CTDB_TEST_ROLE', 'server')) {
            loadtest 'ha/ctdb';
        }

        # Test DRBD feature
        if (get_var('HA_CLUSTER_DRBD')) {
            loadtest 'ha/drbd_passive';
            loadtest 'ha/filesystem';
        }
    }

    # Show HA cluster status *before* fencing test and execute fencing test
    loadtest 'ha/fencing';

    # Node1 will be fenced, so we have to wait for it to boot. On svirt load only boot_to_desktop
    is_svirt ? loadtest 'boot/boot_to_desktop' : boot_hdd_image if !get_var('HA_CLUSTER_JOIN');

    # Show HA cluster status *after* fencing test
    loadtest 'ha/check_after_reboot';

    # Remove all the resources except stonith/sbd
    loadtest 'ha/remove_rsc' if get_var('HA_REMOVE_RSC');

    # Remove a node both by its hostname and ip address
    # This test doesn't work before SLES12SP3 version
    loadtest 'ha/remove_node' if get_var('HA_REMOVE_NODE');

    # Check logs to find error and upload all needed logs if we are not
    # in installation/publishing mode
    loadtest 'ha/check_logs' if !get_var('INSTALLONLY');

    # If needed, do some actions prior to the shutdown
    loadtest 'ha/prepare_shutdown' if get_var('INSTALLONLY');

    return 1;
}

sub updates_is_applicable {
    # We don't want live systems to run out of memory or virtual disk space.
    # Applying updates on a live system would not be persistent anyway.
    return 0 if is_livesystem;
    # Applying updates on BOOT_TO_SNAPSHOT is useless.
    # Also, updates on INSTALLONLY do not match the meaning
    return 0 if get_var('INSTALLONLY') || get_var('BOOT_TO_SNAPSHOT') || get_var('DUALBOOT');
    # After upgrading using only the DVD, packages not on the DVD can be
    # updated in the installed system with online repos.
    return 0 if get_var('UPGRADE') && !(check_var('FLAVOR', 'DVD') || check_var('FLAVOR', 'DVD-Updates'));

    return 1;
}

sub guiupdates_is_applicable {
    return get_var("DESKTOP") =~ /gnome|kde|xfce|lxde/ && !check_var("FLAVOR", "Rescue-CD");
}

sub load_system_update_tests {
    my (%args) = @_;
    my $console_updates = $args{console_updates} // 0;
    # Do not run if system is updated already
    return if get_var('SYSTEM_UPDATED');

    if (is_sle) {
        # Do not run on sle staging, as doesn't make sense there
        return if is_staging;
        # On SLE we schedule console and x11 tests together
        # Do the update using x11 tools then and do not schedule zypper_up
        return if $console_updates && gnomestep_is_applicable;
    }
    # Handle replacing official mirrors with snapshot version of the repos
    if (need_clear_repos() && !get_var('CLEAR_REPOS')) {
        if (is_repo_replacement_required()) {
            replace_opensuse_repos_tests;
        }
        else {
            loadtest "update/zypper_clear_repos";
            set_var('CLEAR_REPOS', 1);
        }
    }
    loadtest "console/zypper_add_repos" if get_var('ZYPPER_ADD_REPOS');
    return unless updates_is_applicable();

    if (guiupdates_is_applicable() && !$console_updates) {
        # If we run both console and x11, this method is trigered twice
        # So we don't schedule it for the first time
        if (x11tests_is_applicable()) {
            loadtest "update/prepare_system_for_update_tests";
            if (check_var("DESKTOP", "kde")) {
                loadtest "update/updates_packagekit_kde";
                set_var('SYSTEM_UPDATED', 1);
            } else {
                loadtest "update/updates_packagekit_gpk";
                set_var('SYSTEM_UPDATED', 1);
            }
            loadtest "update/check_system_is_updated";
        }
    }
    else {
        loadtest "update/zypper_up";
        set_var('SYSTEM_UPDATED', 1);
    }
}

# Tests to validate standalone installation of PCM module
sub load_public_cloud_patterns_validation_tests {
    boot_hdd_image;
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest 'console/validate_pcm_azure' if check_var('VALIDATE_PCM_PATTERN', 'azure');
    loadtest 'console/validate_pcm_aws' if check_var('VALIDATE_PCM_PATTERN', 'aws');
    loadtest "console/consoletest_finish";
}

# Tests to validate partitioning with LVM, both encrypted and not encrypted.
# Also covered a case while installing on a system with a cryptlvm volume
# present (e.g. previous clean installation using cryptlvm).
sub load_lvm_tests {
    if (get_var("ENCRYPT")) {
        # In case if encryption should be explicitly made on the system with
        # already encrypted partition, the test ignores the existing
        # partitioning settings and configures them again.
        if (get_var('ENCRYPT_FORCE_RECOMPUTE') || get_var('ENCRYPT_CANCEL_EXISTING')) {
            loadtest 'installation/partitioning/encrypt_lvm_ignore_existing';
        }
        elsif (get_var('ENCRYPT_ACTIVATE_EXISTING')) {
            loadtest 'installation/partitioning/encrypt_lvm_reuse_existing';
        }
        else {
            loadtest 'installation/partitioning/encrypt_lvm';
        }
    }
    else {
        if (get_var('ENCRYPT_CANCEL_EXISTING')) {
            loadtest 'installation/partitioning/lvm_ignore_existing';
        }
        elsif (check_var('SEPARATE_HOME', 0)) {
            loadtest 'installation/partitioning/lvm_no_separate_home';
            if (get_var('RESIZE_ROOT_VOLUME')) {
                loadtest "installation/partitioning_resize_root";
            }
        }
        else {
            loadtest 'installation/partitioning/lvm';
        }
    }
}

sub load_kernel_baremetal_tests {
    set_var('ADDONURL', 'sdk') if (is_sle('>=12') && is_sle('<15')) && !is_released;
    loadtest "kernel/ibtests_barriers" if get_var("IBTESTS");
    loadtest "autoyast/prepare_profile" if get_var("AUTOYAST_PREPARE_PROFILE");
    if (get_var('IPXE')) {
        loadtest "installation/ipxe_install";
        loadtest "console/suseconnect_scc";
    } else {
        load_boot_tests();
        get_var("AUTOYAST") ? load_ayinst_tests() : load_inst_tests();
        load_reboot_tests();
    }
    # make sure we always have the toolchain installed
    loadtest "toolchain/install";
    # some tests want to build and run a custom kernel
    loadtest "kernel/build_git_kernel" if get_var('KERNEL_GIT_TREE');
}

sub load_nfs_tests {
    loadtest "nfs/install";
    loadtest "nfs/run";
    loadtest "nfs/generate_report";
}

sub load_upstream_systemd_tests {
    loadtest 'systemd_testsuite/prepare_systemd_and_testsuite';
}

1;
