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
use File::Find;
use Exporter;
use testapi qw(check_var get_var get_required_var set_var check_var_array diag);
use autotest;
use utils;
use version_utils qw(:VERSION :BACKEND :SCENARIO);
use bmwqemu ();
use strict;
use warnings;

our @EXPORT = qw(
  any_desktop_is_applicable
  bootencryptstep_is_applicable
  boot_hdd_image
  check_env
  chromestep_is_applicable
  chromiumstep_is_applicable
  console_is_applicable
  consolestep_is_applicable
  default_desktop
  get_ltp_tag
  gnomestep_is_applicable
  guiupdates_is_applicable
  have_scc_repos
  init_main
  installyaststep_is_applicable
  installzdupstep_is_applicable
  is_desktop
  is_kernel_test
  is_ltp_test
  is_livesystem
  is_mediacheck
  is_mediacheck
  is_memtest
  is_memtest
  is_server
  is_sles4sap
  is_sles4sap_standard
  is_updates_test_repo
  is_updates_tests
  kdestep_is_applicable
  kdump_is_applicable
  load_autoyast_clone_tests
  load_autoyast_tests
  load_bootloader_s390x
  load_boot_tests
  load_common_installation_steps_tests
  load_common_opensuse_sle_tests
  load_common_x11
  load_consoletests
  load_create_hdd_tests
  load_extra_tests
  load_extra_tests_docker
  load_filesystem_tests
  load_inst_tests
  load_iso_in_external_tests
  load_jeos_tests
  load_kernel_tests
  load_networkd_tests
  load_nfv_master_tests
  load_nfv_trafficgen_tests
  load_public_cloud_patterns_validation_tests
  load_reboot_tests
  load_rescuecd_tests
  load_rollback_tests
  load_security_tests_apparmor
  load_security_tests_core
  load_security_tests_crypt
  load_security_tests_misc
  load_security_tests_openscap
  load_security_tests_selinux
  load_security_tests_web
  load_shutdown_tests
  load_slepos_tests
  load_sles4sap_tests
  load_ssh_key_import_tests
  load_svirt_boot_tests
  load_svirt_vm_setup_tests
  load_syscontainer_tests
  load_systemd_patches_tests
  load_system_update_tests
  loadtest
  load_testdir
  load_toolchain_tests
  load_virtualization_tests
  load_wicked_tests
  load_x11tests
  load_xen_tests
  load_yast2_gui_tests
  load_yast2_ncurses_tests
  load_zdup_tests
  logcurrentenv
  map_incidents_to_repo
  need_clear_repos
  noupdatestep_is_applicable
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
);

sub init_main {
    set_defaults_for_username_and_password();
    setup_env();
    check_env();
}

sub loadtest {
    my ($test, %args) = @_;
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
    # By default format DASD devices before installation
    if (check_var('BACKEND', 's390x')) {
        # Format DASD before the installation by default
        # Skip format dasd before origin system installation by autoyast in 'Upgrade on zVM'
        # due to channel not activation issue. Need further investigation on it.
        # Also do not format if activate existing partitions
        my $format_dasd = get_var('S390_DISK') || get_var('UPGRADE') || get_var('ENCRYPT_ACTIVATE_EXISTING') ? 'never' : 'pre_install';
        set_var('FORMAT_DASD', get_var('FORMAT_DASD', $format_dasd));
    }
}

sub data_integrity_is_applicable {
    # Other backends than qemu, i.e.Xen, zKVM or Hyper-V will check it later after the image is downloaded
    return check_var('BACKEND', 'qemu') &&
      grep { /^CHECKSUM_/ } keys %bmwqemu::vars;
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

sub is_ltp_test {
    return (get_var('INSTALL_LTP')
          || get_var('LTP_COMMAND_FILE'));
}

sub is_kernel_test {
    return is_ltp_test() ||
      (get_var('QA_TEST_KLP_REPO')
        || get_var('INSTALL_KOTD')
        || get_var('VIRTIO_CONSOLE_TEST')
        || get_var('NVMFTESTS')
        || get_var('TRINITY'));
}

sub get_ltp_tag {
    my $tag = get_var('LTP_RUNTEST_TAG');
    if (!defined $tag && defined get_var('HDD_1')) {
        $tag = get_var('PUBLISH_HDD_1');
        $tag = get_var('HDD_1') if (!defined $tag);
        $tag = basename($tag);
    } else {
        $tag = get_var('DISTRI') . '-' . get_var('VERSION') . '-' . get_var('ARCH') . '-' . get_var('BUILD') . '-' . get_var('FLAVOR') . '@' . get_var('MACHINE');
    }
    return $tag . '.txt';
}

# Isolate the loading of LTP tests because they often rely on newer features
# not present on all workers. If they are isolated then only the LTP tests
# will fail to load when there is a version mismatch instead of all tests.
{
    local $@;

    eval 'use main_ltp';
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
    my $flavor = get_required_var('FLAVOR');
    # Incidents might be also Incidents-Gnome or Incidents-Kernel
    return $flavor =~ /-Updates$/ || $flavor =~ /-Incidents/;
}

sub is_updates_test_repo {
    # mru stands for Maintenance Released Updates and skips unreleased updates
    return get_var('TEST') !~ /^mru-/ && is_updates_tests && get_required_var('FLAVOR') !~ /-Minimal$/;
}

sub is_repo_replacement_required {
    return is_opensuse()                  # Is valid scenario onlu for openSUSE
      && !is_staging()                    # Do not have mirrored repos on staging
      && !get_var('KEEP_ONLINE_REPOS')    # Set variable no to replace variables
      && get_var('SUSEMIRROR')            # Skip if required variable is not set (leap live tests)
      && !get_var('ZYPPER_ADD_REPOS')     # Skip if manual repos are specified
      && !get_var('OFFLINE_SUT')          # Do not run if SUT is offine
      && !get_var('ZDUP');                # Do not run on ZDUP as these tests handle repos on their own
}

sub is_memtest {
    return get_var('MEMTEST');
}

sub is_mediacheck {
    return get_var('MEDIACHECK');
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
      || get_var('WORKAROUND_MODULES', '') =~ /desktop|we/
      || get_var('ADDONURL',           '') =~ /desktop|we/
      || (!is_sle('15+') && get_var('SCC_ADDONS', '') =~ /desktop|we|productivity|ha/)
      || (is_sle('15+')  && get_var('SCC_ADDONS', '') =~ /desktop|we/)
      || is_sles4sap;
}

sub default_desktop {
    return 'textmode' if (get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'));
    return         if get_var('VERSION', '') lt '12';
    return 'gnome' if get_var('VERSION', '') lt '15';
    # with SLE 15 LeanOS only the default is textmode
    return 'gnome' if get_var('BASE_VERSION', '') =~ /^12/;
    return 'gnome' if is_desktop_module_selected;
    # default system role for sles and sled
    return 'textmode' if is_server || !get_var('SCC_REGISTER') || !check_var('SCC_REGISTER', 'installation');
    # remaining cases are is_desktop and check_var('SCC_REGISTER', 'installation'), hence gnome
    return 'gnome';
}

sub uses_qa_net_hardware {
    return check_var("BACKEND", "ipmi") || check_var("BACKEND", "generalhw");
}

sub load_shutdown_tests {
    loadtest("shutdown/cleanup_before_shutdown");
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
    return unless check_var('BACKEND', 'svirt');
    set_bridged_networking;
    if (check_var("VIRSH_VMM_FAMILY", "hyperv")) {
        # Loading bootloader_hyperv here when UPGRADE is on (i.e. offline migration is underway)
        # means loading it for the second time. Which might be apropriate if we want to reconfigure
        # the VM, but currently we don't want to.
        loadtest "installation/bootloader_hyperv" unless get_var('UPGRADE');
    }
    else {
        loadtest "installation/bootloader_svirt";
    }
    unless (is_installcheck || is_memtest || is_rescuesystem || is_mediacheck) {
        load_svirt_boot_tests;
    }
}

sub load_boot_tests {
    if (get_var("ISO_MAXSIZE") && (!is_remote_backend() || is_svirt_except_s390x())) {
        loadtest "installation/isosize";
    }
    if ((get_var("UEFI") || is_jeos()) && !check_var("BACKEND", "svirt")) {
        loadtest "installation/bootloader_uefi";
    }
    elsif (is_svirt_except_s390x()) {
        load_svirt_vm_setup_tests;
    }
    elsif (uses_qa_net_hardware() || get_var("PXEBOOT")) {
        loadtest "boot/boot_from_pxe";
        set_var("DELAYED_START", get_var("PXEBOOT"));
    }
    elsif (check_var('BACKEND', 'spvm')) {
        loadtest "installation/bootloader_spvm";
    }
    else {
        loadtest "installation/bootloader" unless load_bootloader_s390x();
    }
}

sub load_reboot_tests {
    # there is encryption passphrase prompt which is handled in installation/boot_encrypt
    if (check_var("ARCH", "s390x") && !get_var('ENCRYPT')) {
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
            if (check_var('ARCH', 's390x')) {
                loadtest "installation/reconnect_s390";
            }
        }
        loadtest "installation/first_boot";
        loadtest "installation/system_workarounds" if check_var('ARCH', 'aarch64');
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
        if (!check_var('BACKEND', 'ipmi') && !is_hyperv_in_gui && !get_var("LIVECD") && !check_var('BACKEND', 'spvm')) {
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
sub load_jeos_tests {
    if (get_var('PREPARE_RPI')) {
        loadtest "boot/boot_to_desktop";
        loadtest "jeos/prepare_rpi_image";
        loadtest "shutdown/shutdown";
        return;
    }
    unless (get_var('LTP_COMMAND_FILE')) {
        load_boot_tests();
        loadtest "jeos/firstrun";
        loadtest "jeos/record_machine_id";
        unless (get_var('INSTALL_LTP')) {
            loadtest "console/force_scheduled_tasks";
            loadtest "jeos/grub2_gfxmode";
            loadtest 'jeos/revive_xen_domain' if check_var('VIRSH_VMM_FAMILY', 'xen');
            loadtest "jeos/diskusage";
            loadtest "jeos/root_fs_size";
            loadtest "jeos/mount_by_label";
        }
        if (is_sle) {
            loadtest "console/suseconnect_scc";
        }
    }
    loadtest "jeos/glibc_locale" if is_sle('15+') && get_var('JEOSINSTLANG');
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
    return ((get_var("PATTERNS", '') || get_var('HDD_1', '')) =~ /smt/) && is_sle('<15');
}

sub is_rmt {
    return ((get_var("PATTERNS", '') || get_var('HDD_1', '')) =~ /rmt/) && is_sle('>=15');
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

sub map_incidents_to_repo {
    my ($incidents, $templates) = @_;
    my @maint_repos;
    for my $a (keys %$incidents) {
        for my $b (split(/,/, $incidents->{$a})) {
            if ($b) {
                push @maint_repos, join($b, split('%INCIDENTNR%', $templates->{$a}));
            }
        }
    }

    my $ret = join(',', @maint_repos);
    # do not start with ','
    $ret =~ s/^,//s;
    return $ret;
}

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES  => [0, 1],
    USEIMAGES => [0, 1],
    DOCRUN    => [0, 1],

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
}

sub unregister_needle_tags {
    my ($tag) = @_;
    my @a = @{needle::tags($tag)};
    for my $n (@a) { $n->unregister($tag); }
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
    # On JeOS we don't need to load any test to boot, but to keep main.pm sane just return.
    is_jeos() ? return 1 : get_required_var('BOOT_HDD_IMAGE');
    if (check_var('BACKEND', 'svirt')) {
        if (check_var('VIRSH_VMM_FAMILY', 'hyperv')) {
            loadtest 'installation/bootloader_hyperv';
        }
        else {
            loadtest 'installation/bootloader_svirt' unless load_bootloader_s390x;
        }
    }
    if (get_var('UEFI') && (get_var('BOOTFROM') || get_var('BOOT_HDD_IMAGE'))) {
        loadtest 'boot/uefi_bootmenu';
    }
    loadtest 'boot/boot_to_desktop';
}

sub load_common_installation_steps_tests {
    loadtest 'installation/await_install';
    unless (get_var('REMOTE_CONTROLLER') || is_caasp || is_hyperv_in_gui) {
        loadtest 'installation/logs_from_installation_system';
    }
    loadtest 'installation/reboot_after_installation';
}

sub load_inst_tests {
    # On SLE 15 dud addon screen is shown before product selection
    if (get_var('DUD_ADDONS') && is_sle('15+')) {
        loadtest "installation/dud_addon";
    }
    loadtest "installation/welcome";
    loadtest "installation/keyboard_selection" if get_var('INSTALL_KEYBOARD_LAYOUT');
    if (get_var('DUD_ADDONS') && is_sle('<15')) {
        loadtest "installation/dud_addon";
    }
    loadtest 'installation/accept_license' if has_product_selection;
    loadtest 'installation/network_configuration' if get_var('OFFLINE_SUT');
    if (get_var('IBFT')) {
        loadtest "installation/iscsi_configuration";
    }
    if (check_var('ARCH', 's390x')) {
        if (check_var('BACKEND', 's390x')) {
            loadtest "installation/disk_activation";
        }
        elsif (is_sle('<12-SP2')) {
            loadtest "installation/skip_disk_activation";
        }
    }
    if (get_var('ENCRYPT_CANCEL_EXISTING') || get_var('ENCRYPT_ACTIVATE_EXISTING')) {
        loadtest "installation/encrypted_volume_activation";
    }
    if (get_var('MULTIPATH')) {
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
            loadtest "installation/upgrade_select_opensuse";
        }
    }
    if (is_sle) {
        loadtest 'installation/network_configuration' if get_var('NETWORK_CONFIGURATION');
        # SCC registration is not required in media based upgrade since SLE15
        unless (is_sle('15+') && get_var('MEDIA_UPGRADE')) {
            if (check_var('SCC_REGISTER', 'installation')) {
                loadtest "installation/scc_registration";
            }
            else {
                loadtest "installation/skip_registration" unless check_var('SLE_PRODUCT', 'leanos');
            }
        }
        if (is_sles4sap and is_sle('<15') and !is_upgrade()) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        if (get_var('MAINT_TEST_REPO')) {
            loadtest 'installation/add_update_test_repo';
        }
        loadtest "installation/addon_products_sle";
        loadtest 'installation/releasenotes_origin' if get_var('CHECK_RELEASENOTES_ORIGIN');
    }
    if (noupdatestep_is_applicable()) {
        # Krypton/Argon disable the network configuration stage
        if (get_var("LIVECD") && !is_krypton_argon) {
            loadtest "installation/livecd_network_settings";
        }
        # Run system_role/desktop selection tests if using the new openSUSE installation flow
        if (is_using_system_role_first_flow) {
            load_system_role_tests;
        }
        if (is_sles4sap() and is_sle('15+') and check_var('SYSTEM_ROLE', 'default') and !is_upgrade()) {
            loadtest "installation/sles4sap_product_installation_mode";
        }
        # Kubic doesn't have a partitioning step
        unless (is_caasp) {
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
            elsif (get_var('LVM_THIN_LV')) {
                loadtest "installation/partitioning_lvm_thin_provisioning";
            }
            if (get_var("FILESYSTEM")) {
                if (get_var('PARTITIONING_WARNINGS')) {
                    loadtest 'installation/partitioning_warnings';
                }
                loadtest "installation/partitioning_filesystem";
            }
            # boo#1093372 Leap 15.0 proposes a separate home even on small disks
            # making the root partition likely to small so we should switch the
            # defaults here unless we reconfigure using the guided proposal or
            # expert partitioner anyway
            if (get_var("TOGGLEHOME")
                || (is_leap('15.0+') && get_var('HDDSIZEGB', 0) <= 20 && !defined get_var('RAIDLEVEL') && !get_var('LVM') && !get_var('FILESYSTEM')))
            {
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
            if ((uses_qa_net_hardware() && !get_var('FILESYSTEM')) || get_var('SELECT_FIRST_DISK') || get_var("ISO_IN_EXTERNAL_DRIVE")) {
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
    if (is_sle && !check_var('BACKEND', 'generalhw') && !check_var('BACKEND', 'ipmi') && !(is_sle('15+') && get_var('ADDONURL'))) {
        loadtest "installation/releasenotes";
    }

    if (noupdatestep_is_applicable()) {
        loadtest "installation/installer_timezone" unless is_caasp;
        # the test should run only in scenarios, where installed
        # system is not being tested (e.g. INSTALLONLY etc.)
        # The test also won't work reliably when network is bridged (non-s390x svirt).
        if (!consolestep_is_applicable()
            and !get_var("REMOTE_CONTROLLER")
            and !is_hyperv_in_gui
            and !is_bridged_networking
            and !check_var('BACKEND', 's390x')
            and !check_var('BACKEND', 'ipmi')
            and !check_var('BACKEND', 'spvm')
            and is_sle('12-SP2+'))
        {
            loadtest "installation/hostname_inst";
        }
        # Do not run system_role/desktop selection if using the new openSUSE installation flow
        if (!is_using_system_role_first_flow) {
            load_system_role_tests;
        }
        if (is_sles4sap()) {
            if (
                is_sles4sap_standard()    # Schedule module only for SLE15 with non-default role
                || is_sle('15+') && get_var('SYSTEM_ROLE') && !check_var('SYSTEM_ROLE', 'default'))
            {
                loadtest "installation/user_settings";
            }    # sles4sap wizard installation doesn't have user_settings step
        }
        elsif (get_var('IMPORT_USER_DATA')) {
            loadtest 'installation/user_import';
        }
        elsif (is_caasp 'kubic') {
            loadtest "installation/kubeadm_settings" if check_var('SYSTEM_ROLE', 'kubeadm');
        } else {
            loadtest "installation/user_settings";
        }
        if (is_sle || get_var("DOCRUN") || get_var("IMPORT_USER_DATA") || get_var("ROOTONLY")) {    # root user
            loadtest "installation/user_settings_root" unless check_var('SYSTEM_ROLE', 'hpc-node') || check_var('SYSTEM_ROLE', 'hpc-server');
        }
        if (get_var('PATTERNS') || get_var('PACKAGES')) {
            loadtest "installation/installation_overview_before";
            loadtest "installation/select_patterns_and_packages";
        }
        elsif (
            is_sle
            && (!check_var('DESKTOP', default_desktop)
                && (is_sle('<15') || check_var('DESKTOP', 'minimalx'))))
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
    if (installyaststep_is_applicable()) {
        loadtest "installation/installation_overview";
        # On Xen PV we don't have GRUB on VNC
        set_var('KEEP_GRUB_TIMEOUT', 1) if check_var('VIRSH_VMM_TYPE', 'linux');
        loadtest "installation/disable_grub_timeout" unless get_var('KEEP_GRUB_TIMEOUT');
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
    if (check_var('BACKEND', 'qemu') && !is_jeos) {
        # The NFS test expects the IP to be 10.0.2.15
        loadtest "console/yast2_nfs_server";
    }
    loadtest "console/rsync";
    loadtest "console/http_srv";
    loadtest "console/dns_srv";
    loadtest "console/postgresql_server" unless (is_leap('<15.0'));
    # TODO test on openSUSE https://progress.opensuse.org/issues/31972
    if (is_sle('12-SP1+')) {    # shibboleth-sp not available on SLES 12 GA
        loadtest "console/shibboleth";
    }
    if (!is_staging && (is_opensuse || get_var('ADDONS', '') =~ /wsm/ || get_var('SCC_ADDONS', '') =~ /wsm/)) {
        # TODO test on openSUSE https://progress.opensuse.org/issues/31972
        loadtest "console/pcre" if is_sle;
        # TODO test on SLE https://progress.opensuse.org/issues/31972
        loadtest "console/mysql_odbc" if is_opensuse;
        loadtest "console/php7";
        loadtest "console/php7_mysql";
        loadtest "console/php7_postgresql";
    }
    # TODO test on openSUSE https://progress.opensuse.org/issues/31972
    loadtest "console/apache_ssl" if is_sle;
    # TODO test on openSUSE https://progress.opensuse.org/issues/31972
    loadtest "console/apache_nss" if is_sle;
}

sub load_consoletests {
    return unless consolestep_is_applicable();
    if (get_var("ADDONS", "") =~ /rt/) {
        loadtest "rt/kmp_modules";
    }
    loadtest 'qa_automation/patch_and_reboot' if is_updates_tests && !get_var('QAM_MINIMAL');
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest 'console/integration_services' if is_hyperv;
    loadtest "locale/keymap_or_locale";
    loadtest "console/repo_orphaned_packages_check" if is_jeos;
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
    if (get_var("DESKTOP") !~ /textmode/ && !check_var("ARCH", "s390x")) {
        loadtest "console/xorg_vt";
    }
    loadtest "console/zypper_lr";
    loadtest 'console/enable_usb_repo' if check_var('USBBOOT', 1);

    # Do not clear repos twice if replace repos for openSUSE
    # On staging repos are already removed, using CLEAR_REPOS flag variable
    if (need_clear_repos() && !is_repo_replacement_required() && !get_var('CLEAR_REPOS')) {
        loadtest "update/zypper_clear_repos";
        set_var('CLEAR_REPOS', 1);
    }
    #have SCC repo for SLE product
    if (have_scc_repos()) {
        loadtest "console/yast_scc";
    }
    # If is_repo_replacement_required returns true, we already have added mirror repo and refreshed repos
    if (!is_repo_replacement_required()) {
        if (have_addn_repos()) {
            loadtest "console/zypper_ar";
        }
        loadtest "console/zypper_ref";
    }
    loadtest "console/ncurses";
    loadtest "console/yast2_lan" unless is_bridged_networking;
    # no local certificate store
    if (!is_krypton_argon) {
        loadtest "console/curl_https";
    }
    # puppet does not exist anymore in openSUSE Tumbleweed/Leap
    my $puppet_addon = is_sle('15+') ? 'phub' : 'asmm';
    if (is_sle && check_var_array('SCC_ADDONS', $puppet_addon)) {
        loadtest "console/puppet";
    }
    # salt in SLE is only available for SLE12 ASMM or SLES15 and variants of
    # SLES but not SLED
    if (is_opensuse || !is_staging && (check_var_array('SCC_ADDONS', 'asmm') || is_sle('15+') && !is_desktop)) {
        loadtest "console/salt";
    }
    if (check_var('ARCH', 'x86_64')
        || check_var('ARCH', 'i686')
        || check_var('ARCH', 'i586'))
    {
        loadtest "console/glibc_sanity";
    }
    load_system_update_tests(console_updates => 1);
    loadtest "console/console_reboot" if is_jeos;
    loadtest "console/zypper_in";
    loadtest "console/yast2_i";
    if (!get_var("LIVETEST")) {
        loadtest "console/yast2_bootloader";
    }
    loadtest "console/vim" if is_opensuse || is_sle('<15') || !get_var('PATTERNS') || check_var_array('PATTERNS', 'enhanced_base');
# textmode install comes without firewall by default atm on openSUSE. For virtualizatoin server xen and kvm is disabled by default: https://fate.suse.com/324207
    if ((is_sle || !check_var("DESKTOP", "textmode")) && !is_staging() && !is_krypton_argon && !is_virtualization_server) {
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
        loadtest "console/mysql_srv";
        # disable these tests of server packages for SLED (poo#36436)
        load_console_server_tests() unless is_desktop;
    }
    if (check_var("DESKTOP", "xfce")) {
        loadtest "console/xfce_gnome_deps";
    }
    if (!is_staging() && is_sle('12-SP2+')) {
        loadtest "console/zypper_lifecycle";
        if (check_var_array('SCC_ADDONS', 'tcm') && is_sle('<15')) {
            loadtest "console/zypper_lifecycle_toolchain";
        }
    }
    if (check_var_array('SCC_ADDONS', 'tcm') && get_var('PATTERNS') && is_sle('<15') && !get_var("MEDIA_UPGRADE")) {
        loadtest "feature/feature_console/deregister";
    }
    loadtest 'console/orphaned_packages_check' if get_var('UPGRADE');
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
    if (xfcestep_is_applicable()) {
        loadtest "x11/xfce4_terminal";
    }
    loadtest "x11/xterm";
    loadtest "x11/sshxterm" unless get_var("LIVETEST");
    if (gnomestep_is_applicable()) {
        load_system_update_tests();
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
            loadtest(is_sle('<15') ? "x11/rhythmbox" : "x11/gnome_music");
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
    loadtest "x11/thunar" if xfcestep_is_applicable();
    loadtest "x11/glxgears" if packagekit_available && !get_var('LIVECD');
    if (gnomestep_is_applicable()) {
        loadtest "x11/nautilus" unless get_var("LIVECD");
        loadtest "x11/gnome_music"    if is_opensuse;
        loadtest "x11/evolution"      if (!is_server() || we_is_applicable());
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
    # https://progress.opensuse.org/issues/37342
    if (is_sle() && gnomestep_is_applicable() && !is_staging()) {
        loadtest "x11/remote_desktop/vino_screensharing_available";
    }
    if (kdestep_is_applicable()) {
        if (!is_krypton_argon && !is_kde_live) {
            loadtest "x11/amarok";
        }
        loadtest "x11/kontact" unless is_kde_live;
    }
    if (kdestep_is_applicable()) {
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
    # Need to skip shutdown to keep backend alive if running rollback tests after migration
    unless (get_var('ROLLBACK_AFTER_MIGRATION')) {
        load_shutdown_tests;
    }
}

sub load_yast2_ncurses_tests {
    boot_hdd_image;
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest 'console/integration_services' if is_hyperv;
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
    loadtest "console/yast2_ntpclient";
    loadtest "console/yast2_tftp";
    # We don't schedule some tests on s390x as they are unstable, see poo#42692
    unless (is_s390x) {
        loadtest "console/yast2_proxy";
        loadtest "console/yast2_vnc";
        loadtest "console/yast2_samba";
        # internal nis server in suse network is used, but this is not possible for
        # openqa.opensuse.org
        loadtest "console/yast2_nis" if is_sle;
        loadtest "console/yast2_http";
        loadtest "console/yast2_ftp";
        loadtest "console/yast2_apparmor";
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

sub load_extra_tests_desktop {
    if (check_var('DISTRI', 'sle')) {
        # start extra x11 tests from here
        loadtest 'x11/vnc_two_passwords';
        # TODO: check why this is not called on opensuse
        # poo#35574 - Excluded for Xen PV as it was never passed due to the fail while interacting with grub.
        loadtest 'x11/user_defined_snapshot' unless (check_var('VIRSH_VMM_FAMILY', 'xen') && check_var('VIRSH_VMM_TYPE', 'linux'));
    }
    elsif (check_var('DISTRI', 'opensuse')) {
        if (gnomestep_is_applicable()) {
            # Setup env for x11 regression tests
            loadtest "x11/x11_setup";
            if (check_var('VERSION', '42.2')) {
                # 42.2 feature - not even on Tumbleweed
                loadtest "x11/gdm_session_switch";
            }
            loadtest "x11/seahorse";
            # only scheduled on gnome and was developed only for gnome but no
            # special reason should prevent it to be scheduled in another DE.
            loadtest 'x11/steam' if check_var('ARCH', 'x86_64');
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
    # the following tests care about network and need some DE specific
    # needles. For now we only have them for gnome and do not want to
    # support more than just this DE. Probably for later at least the wifi
    # test, checking the wifi applet, would make sense in other DEs as
    # well
    if (check_var('DESKTOP', 'gnome')) {
        loadtest 'x11/yast2_lan_restart';
        loadtest 'x11/yast2_lan_restart_devices' if (!is_opensuse || is_leap('<=15.0'));
        # we only have the test dependencies, e.g. hostapd available in
        # openSUSE
        if (check_var('DISTRI', 'opensuse')) {
            loadtest 'x11/network/hwsim_wpa2_enterprise_setup';
            loadtest 'x11/network/yast2_network_use_nm';
            loadtest 'x11/network/NM_wpa2_enterprise';
        }
        loadtest "console/check_default_network_manager";
    }
}

sub load_extra_tests_zypper {
    loadtest "console/zypper_lr_validate";
    loadtest "console/zypper_ref";
    unless (is_jeos) {
        loadtest "console/zypper_info";
    }
    # Check for availability of packages and the corresponding repository, as of now only makes sense for SLE
    loadtest 'console/validate_packages_and_patterns' if is_sle '12-sp2+';
}

sub load_extra_tests_kdump {
    return unless kdump_is_applicable;
    loadtest "console/kdump_and_crash";
}

sub load_extra_tests_opensuse {
    return unless is_opensuse;
    loadtest "console/rabbitmq";
    loadtest "console/salt";
    loadtest "console/rails";
    loadtest "console/machinery";
    loadtest "console/pcre";
    loadtest "console/openqa_review";
    loadtest "console/zbar";
    loadtest "console/a2ps";    # a2ps is not a ring package and thus not available in staging
    loadtest "console/znc";
    loadtest "console/weechat";
    loadtest "console/nano";
    loadtest "console/steamcmd" if (check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64'));
}

sub load_extra_tests_console {
    # JeOS kernel is missing 'openvswitch' kernel module
    loadtest "console/openvswitch" unless is_jeos;
    # dependency of git test
    loadtest "console/sshd";
    # start extra console tests from here
    loadtest "console/update_alternatives";
    # Audio device is not supported on ppc64le, s390x, JeOS, and Xen PV
    if (!get_var("OFW") && !is_jeos && !check_var('VIRSH_VMM_FAMILY', 'xen') && !check_var('ARCH', 's390x')) {
        loadtest "console/aplay";
    }
    loadtest "console/command_not_found";
    if (is_sle '12-sp2+') {
        loadtest 'console/openssl_alpn';
        loadtest 'console/autoyast_removed';
    }
    loadtest "console/cron";
    loadtest "console/syslog";
    loadtest "console/ntp_client" if (!is_sle && !is_jeos);
    loadtest "console/mta" unless is_jeos;
    loadtest "console/check_default_network_manager";
    loadtest "console/ipsec_tools_h2h" if get_var("IPSEC");
    loadtest "console/git";
    loadtest "console/java";
    loadtest "console/ant" if is_sle('<15-sp1');
    loadtest "console/sysctl";
    loadtest "console/sysstat";
    loadtest "console/curl_ipv6";
    loadtest "console/wget_ipv6";
    loadtest "console/unzip";
    loadtest "console/salt" if is_jeos;
    loadtest "console/gpg";
    loadtest "console/rsync";
    loadtest "console/shells";
    # dstat is not in sle12sp1
    loadtest "console/dstat" if is_sle('12-SP2+') || is_opensuse;
    # MyODBC-unixODBC not available on < SP2 and sle 15 and only in SDK
    if (is_sle('12-SP2+') && !(is_sle('15+'))) {
        loadtest "console/mysql_odbc" if check_var_array('ADDONS', 'sdk') || check_var_array('SCC_ADDONS', 'sdk');
    }
    # bind need source package and legacy and development module on SLE15+
    loadtest 'console/bind' if get_var('MAINT_TEST_REPO');
    loadtest 'console/systemd_testsuite' if is_sle('15+') && get_var('QA_HEAD_REPO');
    loadtest 'console/mdadm' unless is_jeos;
    loadtest 'console/journalctl';
    # sysauth test scenarios run in the console
    loadtest "sysauth/sssd" if get_var('SYSAUTHTEST');
}

sub load_extra_tests_docker {
    return unless check_var('ARCH', 'x86_64');
    return unless is_sle('12-SP3+') || !is_sle;
    loadtest "console/docker";
    loadtest "console/docker_runc";
    if (is_sle('=12-SP3')) {
        loadtest "console/sle2docker";
        loadtest "console/docker_image";
    }
    elsif (is_sle('=15')) {
        loadtest "console/docker_image";
    }
    if (is_tumbleweed) {
        loadtest "console/docker_image_rpm";
        loadtest "console/docker_compose";
    }
    elsif (is_opensuse && !is_tumbleweed) {
        loadtest "console/docker_compose";
    }
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
    loadtest 'console/integration_services' if is_hyperv;
    loadtest "console/hostname";
    # Extra tests are too long, split the test into subtest according to the
    # EXTRATEST variable; to maintain compatibility, run all tests if the
    # variable is equal 1
    if (check_var('EXTRATEST', 1) && any_desktop_is_applicable()) {
        load_extra_tests_desktop;
    }
    elsif (check_var('EXTRATEST', 1)) {
        load_extra_tests_zypper;
        load_extra_tests_console;
        load_extra_tests_opensuse;
        # schedule the docker tests later as it needs the containers module on
        # SLE>=15 and therefore would potentially pollute other test modules.
        # Currently for our SLE12 validation tests we are not using a
        # registered SLE installation so we should not schedule the test
        # modules.
        load_extra_tests_docker;
        load_extra_tests_kdump;
    }
    else {
        loadtest "console/zypper_ref" unless get_var('EXTRATEST') =~ /zypper/;
        foreach my $test_name (split(/,/, get_var('EXTRATEST'))) {
            if (my $test_to_run = main_common->can("load_extra_tests_$test_name")) {
                $test_to_run->();
            }
            else {
                diag "unknown scenario for EXTRATEST value $test_name";
            }
        }
        loadtest "console/consoletest_finish";
    }
    return 1;
}

sub load_extra_tests_toolkits {
    loadtest "x11/toolkits/prepare";
    loadtest "x11/toolkits/x11";
    loadtest "x11/toolkits/tk";
    loadtest "x11/toolkits/fltk";
    loadtest "x11/toolkits/motif";
    loadtest "x11/toolkits/gtk2";
    loadtest "x11/toolkits/gtk3";
    loadtest "x11/toolkits/qt4" if is_opensuse;
    loadtest "x11/toolkits/qt5";
    loadtest "x11/toolkits/swing";
    return 1;
}

sub load_rollback_tests {
    return if check_var('ARCH', 's390x');
    # On Xen PV we don't have GRUB
    loadtest "boot/grub_test_snapshot" unless check_var('VIRSH_VMM_TYPE', 'linux');
    # Skip load version switch for online migration
    loadtest "migration/version_switch_origin_system" if (!get_var("ONLINE_MIGRATION"));
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
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest 'console/integration_services' if is_hyperv;
    loadtest "console/hostname";
    if (get_var("FILESYSTEM", "btrfs") eq "btrfs") {
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
    }
    loadtest 'console/snapper_undochange';
    loadtest 'console/snapper_create';
    if (get_var('NUMDISKS', 0) > 1 && (is_sle('12-sp3+') || is_leap('42.3+') || is_tumbleweed)) {
        # On JeOS we use kernel-defaul-base and it does not have 'dm-thin-pool'
        # kernel module required by thin-LVM
        loadtest 'console/snapper_thin_lvm' unless is_jeos;
    }
    loadtest 'console/snapper_used_space' if (is_sle('15-SP1+') || (is_opensuse && !is_leap('<15.1')));
}

sub get_wicked_tests {
    my (%args)     = @_;
    my $basedir    = $bmwqemu::vars{CASEDIR} . '/tests/';
    my $wicked_dir = $basedir . 'wicked/';
    my $suite      = get_required_var('WICKED');
    my $type = get_required_var('IS_WICKED_REF') ? 'ref' : 'sut';
    my $exclude   = get_var('WICKED_EXCLUDE', '$a');
    my $suite_dir = $wicked_dir . $suite . '/';
    my $tests_dir = $suite_dir . $type . '/';
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

sub load_wicked_tests {
    wicked_init_locks();
    for my $test (get_wicked_tests()) {
        loadtest $test;
    }
}

sub load_networkd_tests {
    loadtest 'networkd/networkd_init';
    loadtest 'networkd/networkd_dhcp';
    loadtest 'networkd/networkd_vlan';
    loadtest 'networkd/networkd_bridge';
}

sub load_nfv_master_tests {
    loadtest "nfv/prepare_env";
    loadtest "nfv/run_performance_tests";
    loadtest "nfv/run_integration_tests" if (check_var('BACKEND', 'qemu'));
}

sub load_nfv_trafficgen_tests {
    loadtest "nfv/trex_installation";
    loadtest "nfv/trex_runner";
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
    loadtest "console/sle15_workarounds" if is_sle('15+');
    loadtest "console/hostname"              unless is_bridged_networking;
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
    loadtest "x11/firefox/firefox_pagesaving";
    loadtest "x11/firefox/firefox_private";
    # could not find UnMHT addon, home page is dead http://www.unmht.org/unmht/en_index.html
    loadtest "x11/firefox/firefox_mhtml" if is_sle('=12-sp4');
    loadtest "x11/firefox/firefox_extensions";
    loadtest "x11/firefox/firefox_appearance";
    loadtest "x11/firefox/firefox_passwd";
    loadtest "x11/firefox/firefox_html5";
    loadtest "x11/firefox/firefox_developertool";
    loadtest "x11/firefox/firefox_rss";
    loadtest "x11/firefox/firefox_ssl";
    loadtest "x11/firefox/firefox_emaillink";
    loadtest "x11/firefox/firefox_plugins";
    loadtest "x11/firefox/firefox_extcontent";
    loadtest "x11/firefox/firefox_gnomeshell";
    if (!get_var("OFW") && check_var('BACKEND', 'qemu')) {
        loadtest "x11/firefox_audio";
    }
}

sub load_x11_message {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11/empathy/empathy_irc" if is_sle("<15");
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
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_remmina' if is_sle('>=15');
        loadtest 'x11/remote_desktop/onetime_vncsession_xvnc_java'    if is_sle('<12-sp4');
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
        load_x11_other();
    }
    elsif (check_var("REGRESSION", "firefox")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        load_x11_webbrowser_core();
        load_x11_webbrowser_extra();
    }
    elsif (check_var("REGRESSION", "message")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        load_x11_message();
    }
    elsif (check_var('REGRESSION', 'remote')) {
        loadtest 'boot/boot_to_desktop';
        loadtest "x11/window_system";
        load_x11_remote();
    }
    elsif (check_var("REGRESSION", "piglit")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/window_system";
        loadtest "x11/piglit/piglit";
    }
    # Used by Desktop Applications Group
    elsif (check_var("REGRESSION", "webbrowser_core")) {
        loadtest "boot/boot_to_desktop";
        load_x11_webbrowser_core();
    }
    elsif (check_var("REGRESSION", "webbrowser_extra")) {
        loadtest "boot/boot_to_desktop";
        load_x11_webbrowser_extra();
    }
    # Used by ibus tests
    elsif (check_var("REGRESSION", "ibus")) {
        loadtest "boot/boot_to_desktop";
        loadtest "x11/ibus/ibus_installation";
        loadtest "x11/ibus/ibus_test_ch";
        loadtest "x11/ibus/ibus_test_jp";
        loadtest "x11/ibus/ibus_test_kr";
        loadtest "x11/ibus/ibus_clean";
    }
}

# The function name load_security_tests_* is to avoid confusing since
# openSUSE does NOT have FIPS mode
# Some tests are valid only for FIPS Regression testing. Use
# "FIPS_ENABLED" to control whether to run these "FIPS only" cases
sub load_security_tests_core {
    if (check_var('DISTRI', 'sle') && get_var('FIPS_ENABLED')) {
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
    if (check_var('DISTRI', 'sle') && get_var('FIPS_ENABLED')) {
        loadtest "fips/mozilla_nss/apache_nssfips";
        loadtest "console/libmicrohttpd";
    }
    loadtest "console/consoletest_finish";
    if (check_var('DISTRI', 'sle') && get_var('FIPS_ENABLED')) {
        loadtest "fips/mozilla_nss/firefox_nss";
    }
}

sub load_security_tests_misc {
    if (check_var('DISTRI', 'sle') && get_var('FIPS_ENABLED')) {
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
    if (check_var('DISTRI', 'sle') && get_var('FIPS_ENABLED')) {
        loadtest "fips/ecryptfs_fips";
    }
    loadtest "console/gpg";
    loadtest "console/yast2_dm_crypt";
    loadtest "console/cryptsetup";
    loadtest "console/consoletest_finish";
}

# Other security tests other than FIPS
sub load_security_tests_apparmor {
    loadtest "security/apparmor/aa_status";
    loadtest "security/apparmor/aa_enforce";
    loadtest "security/apparmor/aa_complain";
    loadtest "security/apparmor/aa_genprof";
    loadtest "security/apparmor/aa_autodep";
    loadtest "security/apparmor/aa_logprof";
    loadtest "security/apparmor/aa_easyprof";
    loadtest "security/apparmor/aa_notify";
}

sub load_security_tests_openscap {
    # ALWAYS run following tests in sequence because of the dependencies

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

sub load_security_tests_selinux {
    # ALWAYS run following tests in sequence because of the dependencies
    # Setup - install SELinux necessary packages
    loadtest "security/selinux/selinux_setup";

    loadtest "security/selinux/sestatus";
    loadtest "security/selinux/selinux_smoke";
}

sub load_systemd_patches_tests {
    boot_hdd_image;
    loadtest 'console/systemd_testsuite';
}

sub load_system_prepare_tests {
    loadtest 'ses/install_ses' if check_var_array('ADDONS', 'ses') || check_var_array('SCC_ADDONS', 'ses');
    # temporary adding test modules which applies hacks for missing parts in sle15
    loadtest 'console/sle15_workarounds' if is_sle('15+');
    loadtest 'console/integration_services' if is_hyperv;
    loadtest 'console/hostname' unless is_bridged_networking;
    loadtest 'console/system_prepare';
    loadtest 'console/force_scheduled_tasks' unless is_jeos;
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
    if (check_var('BACKEND', 'svirt')) {
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

sub load_xen_tests {
    return unless check_var('HOST_HYPERVISOR', 'xen');
    # Install hypervisor via autoyast or manually
    loadtest "autoyast/prepare_profile" if get_var "AUTOYAST_PREPARE_PROFILE";
    load_boot_tests;
    if (get_var("AUTOYAST")) {
        loadtest "autoyast/installation";
        loadtest "virt_autotest/reboot_and_wait_up_normal";
    }
    else {
        load_inst_tests;
        loadtest "virt_autotest/login_console";
    }
    # Load guest installation tests
    loadtest 'virtualization/xen/prepare_guests';
    # Apply updates
    loadtest 'virtualization/xen/patch_and_reboot';
    # Load real tests
    loadtest 'virtualization/xen/hotplugging';
    loadtest 'virtualization/xen/save_and_restore';
    loadtest 'virtualization/xen/dom_metrics';
    loadtest 'virtualization/xen/guest_management';
}

sub load_syscontainer_tests() {
    return unless get_var('SYSCONTAINER_IMAGE_TEST');
    # pre-conditions for system container tests ie. the tests are running based on preinstalled image
    return if get_var("INSTALLONLY") || get_var("DUALBOOT") || get_var("RESCUECD");

    # setup $serialdev permission and so on
    loadtest "console/system_prepare";
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
    loadtest "console/force_scheduled_tasks";
    loadtest "toolchain/install";
    loadtest "toolchain/gcc_fortran_compilation";
    loadtest "toolchain/gcc_compilation";
    loadtest "console/kdump_and_crash" if is_sle && kdump_is_applicable;
}

sub load_publiccloud_tests {
    if (get_var('PUBLIC_CLOUD_PREPARE_TOOLS')) {
        loadtest "publiccloud/prepare_tools";
    }
    elsif (get_var('PUBLIC_CLOUD_IPA_TESTS')) {
        loadtest "publiccloud/ipa";
    }
    elsif (get_var('PUBLIC_CLOUD_LTP')) {
        loadtest 'publiccloud/run_ltp';
    }
    elsif (get_var('PUBLIC_CLOUD_ACCNET')) {
        loadtest 'publiccloud/az_accelerated_net';
    }
    elsif (get_var('PUBLIC_CLOUD_IMAGE_LOCATION')) {
        loadtest "publiccloud/upload_image";
    }
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
    for my $module (split(',', get_var('INSTALLATION_VALIDATION'))) {
        loadtest $module;
    }
}

sub load_common_opensuse_sle_tests {
    load_autoyast_clone_tests           if get_var("CLONE_SYSTEM");
    load_publiccloud_tests              if get_var('PUBLIC_CLOUD');
    load_create_hdd_tests               if get_var("STORE_HDD_1") || get_var("PUBLISH_HDD_1");
    load_toolchain_tests                if get_var("TCM") || check_var("ADDONS", "tcm");
    loadtest 'console/network_hostname' if get_var('NETWORK_CONFIGURATION');
    load_installation_validation_tests  if get_var('INSTALLATION_VALIDATION');
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
    loadtest 'console/validate_pcm_aws'   if check_var('VALIDATE_PCM_PATTERN', 'aws');
    loadtest "console/consoletest_finish";
}

1;
