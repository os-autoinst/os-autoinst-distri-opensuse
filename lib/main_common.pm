package main_common;
use base Exporter;
use File::Basename;
use Exporter;
use testapi qw(check_var get_var get_required_var set_var diag);
use autotest;
use utils;
use version_utils qw(is_jeos is_gnome_next is_krypton_argon is_sle leap_version_at_least sle_version_at_least is_desktop_installed);
use strict;
use warnings;
use main_ltp;

our @EXPORT = qw(
  init_main
  loadtest
  load_testdir
  set_defaults_for_username_and_password
  setup_env
  logcurrentenv
  is_staging
  is_bridged_networking
  load_rescuecd_tests
  load_zdup_tests
  load_autoyast_tests
  load_autoyast_clone_tests
  load_slepos_tests
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
  addon_products_is_applicable
  remove_common_needles
  remove_desktop_needles
  check_env
  ssh_key_import
  unregister_needle_tags
  any_desktop_is_applicable
  console_is_applicable
  boot_hdd_image
  maybe_load_kernel_tests
  load_yast2_ncurses_tests
  load_yast2_gui_tests
  load_extra_tests
  load_rollback_tests
  load_filesystem_tests
  load_wicked_tests
  load_nfv_tests
  load_iso_in_external_tests
  load_x11regression_documentation
  load_x11regression_gnome
  load_x11regression_other
  load_security_tests_core
  load_security_tests_web
  load_security_tests_misc
  load_security_tests_crypt
  load_systemd_patches_tests
  load_create_hdd_tests
  is_memtest
  is_mediacheck
  load_syscontainer_tests
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
        if (get_var('FLAVOR', '') =~ /SAP/) {
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

sub is_staging {
    return get_var('STAGING');
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

sub load_rescuecd_tests {
    if (rescuecdstep_is_applicable()) {
        loadtest "rescuecd/rescuecd";
    }
}

sub load_autoyast_clone_tests {
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
    loadtest 'boot/boot_to_desktop';
}

sub load_autoyast_tests {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation");
    loadtest("autoyast/console");
    loadtest("autoyast/login");
    loadtest("autoyast/wicked");
    loadtest("autoyast/autoyast_verify") if get_var("AUTOYAST_VERIFY");
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


sub installzdupstep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && get_var("ZDUP");
}

sub snapper_is_applicable {
    my $fs = get_var("FILESYSTEM", 'btrfs');
    return ($fs eq "btrfs" && get_var("HDDSIZEGB", 10) > 10);
}

sub chromestep_is_applicable {
    return check_var('ARCH', 'i586') || check_var('ARCH', 'x86_64');
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

sub noupdatestep_is_applicable {
    return !get_var("UPGRADE");
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

sub addon_products_is_applicable {
    return !get_var("LIVECD") && get_var("ADDONURL");
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

sub boot_hdd_image {
    get_required_var('BOOT_HDD_IMAGE');
    if (check_var("BACKEND", "svirt")) {
        if (check_var("ARCH", "s390x")) {
            loadtest "installation/bootloader_zkvm";
        }
        else {
            loadtest "installation/bootloader_svirt";
        }
    }
    if (get_var('UEFI') && (get_var('BOOTFROM') || get_var('BOOT_HDD_IMAGE'))) {
        loadtest "boot/uefi_bootmenu";
    }
    loadtest "boot/boot_to_desktop";
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
                loadtest "x11regressions/x11regressions_setup";
                # poo#18850 java test support for firefox, run firefox before chrome
                # as otherwise have wizard on first run to import settings from it
                loadtest "x11regressions/firefox/firefox_java";
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
            loadtest 'x11/network/hwsim_wpa2_enterprise_setup';
            loadtest 'x11/network/yast2_network_setup';
            loadtest 'x11/network/NM_wpa2_enterprise';
        }
    }
    else {
        loadtest "console/zypper_lr_validate";
        loadtest "console/openvswitch";
        # dependency of git test
        loadtest "console/sshd";
        loadtest "console/zypper_ref";
        loadtest "console/zypper_info";
        loadtest "console/update_alternatives";
        # start extra console tests from here
        # Audio device is not supported on ppc64le, s390x, JeOS, and Xen PV
        if (!get_var("OFW") && !is_jeos && !check_var('VIRSH_VMM_FAMILY', 'xen') && !check_var('ARCH', 's390x')) {
            loadtest "console/aplay";
        }
        loadtest "console/command_not_found";
        if (check_var('DISTRI', 'sle') && sle_version_at_least('12-SP2')) {
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
            loadtest "console/zypper_ar";
            loadtest "console/a2ps";    # a2ps is not a ring package and thus not available in staging
            loadtest "console/weechat";
            loadtest "console/nano";
        }
        if (get_var("IPSEC")) {
            loadtest "console/ipsec_tools_h2h";
        }
        if (check_var('ARCH', 'x86_64')) {
            loadtest "console/docker";
            loadtest "console/runc";
            # No package 'docker-compose' in SLE
            if (check_var('DISTRI', 'opensuse')) {
                loadtest "console/docker_compose";
            }
            if (check_var('DISTRI', 'sle') && !(sle_version_at_least('15'))) {
                loadtest "console/sle2docker";
            }
        }
        loadtest "console/git";
        loadtest "console/java";
        loadtest "console/curl_ipv6";
        loadtest "console/wget_ipv6";
        loadtest "console/unzip";
        loadtest "console/zypper_moo";
        loadtest "console/gpg";
        loadtest "console/shells";
        # MyODBC-unixODBC not available on < SP2 and sle 15
        if (sle_version_at_least('12-SP2') && !(sle_version_at_least('15'))) {
            loadtest "console/mysql_odbc";
        }
        if (get_var("SYSAUTHTEST")) {
            # sysauth test scenarios run in the console
            loadtest "sysauth/sssd";
        }
        loadtest "console/kdump_and_crash" if kdump_is_applicable;
        loadtest "console/consoletest_finish";
    }
    return 1;
}

sub load_rollback_tests {
    loadtest "boot/grub_test_snapshot";
    if (get_var('UPGRADE') || get_var('ZDUP')) {
        loadtest "boot/snapper_rollback";
    }
    if (get_var('MIGRATION_ROLLBACK')) {
        loadtest "online_migration/sle12_online_migration/snapper_rollback";
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
            if (check_var('DISTRI', 'opensuse') || (check_var('DISTRI', 'sle') && sle_version_at_least('12-SP2'))) {
                loadtest 'console/snapper_cleanup';
            }
            if (check_var('DISTRI', 'sle') && sle_version_at_least('12-SP2')) {
                loadtest "console/btrfs_send_receive";
            }
        }
    }
    loadtest 'console/snapper_undochange';
    loadtest 'console/snapper_create';
    if (   (check_var('DISTRI', 'sle') && sle_version_at_least('12-SP3'))
        || (check_var('DISTRI', 'opensuse') && (leap_version_at_least('42.3') || check_var('VERSION', 'Tumbleweed'))))
    {
        loadtest 'console/snapper_thin_lvm';
    }
}

sub load_wicked_tests {
    loadtest 'wicked/wicked_before_test';
    loadtest 'wicked/wicked_' . get_required_var('WICKED');
}

sub load_nfv_tests {
    boot_hdd_image();
    loadtest "nfv/openvswitch_dpdk";
    loadtest "nfv/vsperf_installation";
    loadtest "nfv/moongen_installation";
}

sub load_iso_in_external_tests {
    loadtest "boot/boot_to_desktop";
    loadtest "console/copy_iso_to_external_drive";
    loadtest "x11/reboot_and_install";
}

sub load_x11regression_documentation {
    return unless check_var('DESKTOP', 'gnome');
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
    loadtest "x11regressions/gedit/gedit_about";
    if (sle_version_at_least('12-SP1')) {
        loadtest "x11regressions/libreoffice/libreoffice_mainmenu_favorites";
        loadtest "x11regressions/evolution/evolution_prepare_servers";
        loadtest "x11regressions/libreoffice/libreoffice_pyuno_bridge";
    }
    loadtest "x11regressions/libreoffice/libreoffice_mainmenu_components";
    loadtest "x11regressions/libreoffice/libreoffice_recent_documents";
    loadtest "x11regressions/libreoffice/libreoffice_default_theme";
    loadtest "x11regressions/libreoffice/libreoffice_open_specified_file";
    loadtest "x11regressions/libreoffice/libreoffice_double_click_file";
}

sub load_x11regression_gnome {
    return unless check_var('DESKTOP', 'gnome');
    loadtest "x11regressions/gnomecase/nautilus_cut_file";
    loadtest "x11regressions/gnomecase/nautilus_permission";
    loadtest "x11regressions/gnomecase/nautilus_open_ftp";
    loadtest "x11regressions/gnomecase/application_starts_on_login";
    loadtest "x11regressions/gnomecase/change_password";
    loadtest "x11regressions/gnomecase/login_test";
    if (check_var('DISTRI', 'sle') && sle_version_at_least('12-SP1')) {
        loadtest "x11regressions/gnomecase/gnome_classic_switch";
    }
    loadtest "x11regressions/gnomecase/gnome_default_applications";
    loadtest "x11regressions/gnomecase/gnome_window_switcher";
}

sub load_x11regression_other {
    if (check_var("DESKTOP", "gnome")) {
        loadtest "x11regressions/brasero/brasero_launch";
        loadtest "x11/gnomeapps/gnome_documents";
        loadtest "x11regressions/totem/totem_launch";
    }
    # shotwell was replaced by gnome-photos in SLE15 & yast_virtualization isn't in SLE15
    if (is_sle && sle_version_at_least('12-SP2') && !sle_version_at_least('15')) {
        loadtest "x11regressions/shotwell/shotwell_import";
        loadtest "x11regressions/shotwell/shotwell_edit";
        loadtest "x11regressions/shotwell/shotwell_export";
        loadtest "virtualization/yast_virtualization";
        loadtest "virtualization/virtman_view";
    }
    if (get_var("DESKTOP") =~ /kde|gnome/) {
        loadtest "x11regressions/tracker/prep_tracker";
        # tracker-gui/tracker-needle was dropped since version 1.99.0
        if (!sle_version_at_least('15')) {
            loadtest "x11regressions/tracker/tracker_starts";
            loadtest "x11regressions/tracker/tracker_searchall";
            loadtest "x11regressions/tracker/tracker_pref_starts";
            loadtest "x11regressions/tracker/tracker_open_apps";
            loadtest "x11regressions/tracker/tracker_mainmenu";
        }
        loadtest "x11regressions/tracker/tracker_by_command";
        loadtest "x11regressions/tracker/tracker_info";
        loadtest "x11regressions/tracker/tracker_search_in_nautilus";
        loadtest "x11regressions/tracker/clean_tracker";
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
    if (sle_version_at_least('12-SP2') || check_var('VERSION', 'Tumbleweed')) {
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
    loadtest 'console/sle15_workarounds' if is_sle && sle_version_at_least('15');
    loadtest 'console/hostname' unless is_bridged_networking;
    loadtest 'console/force_cron_run' unless is_jeos;
    loadtest 'shutdown/grub_set_bootargs';
    loadtest 'shutdown/shutdown';
    loadtest 'shutdown/svirt_upload_assets' if check_var('BACKEND', 'svirt');
}

sub is_memtest {
    return get_var('MEMTEST');
}

sub is_mediacheck {
    return get_var('MEDIACHECK');
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

1;
