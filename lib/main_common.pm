package main_common;
use base Exporter;
use File::Basename;
use Exporter;
use testapi qw(check_var get_var get_required_var set_var diag);
use autotest;
use utils;
use strict;
use warnings;

our @EXPORT = qw(
  init_main
  loadtest
  load_testdir
  set_defaults_for_username_and_password
  setup_env
  logcurrentenv
  is_staging
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
  consolestep_is_applicable
  rescuecdstep_is_applicable
  bootencryptstep_is_applicable
  remove_common_needles
  remove_desktop_needles
  check_env
  ssh_key_import
  unregister_needle_tags
  any_desktop_is_applicable
  console_is_applicable
  boot_hdd_image
  load_yast2_ui_tests
  maybe_load_kernel_tests
  load_extra_tests
  load_rollback_tests
  load_application_tests
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
    my $testdir = testapi::get_var("CASEDIR") . "/tests/$testsuite";
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

sub any_desktop_is_applicable() {
    return get_var("DESKTOP") !~ /textmode/;
}

sub console_is_applicable() {
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
        loadtest("autoyast/logs");
    }
    loadtest("autoyast/autoyast_reboot");
    #    next boot in load_reboot_tests
}

sub load_slepos_tests() {
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

sub consolestep_is_applicable {
    return !get_var("INSTALLONLY") && !get_var("DUALBOOT") && !get_var("RESCUECD") && !is_gnome_next && !is_krypton_argon;
}

sub rescuecdstep_is_applicable {
    return get_var("RESCUECD");
}

sub ssh_key_import {
    return get_var("SSH_KEY_IMPORT") || get_var("SSH_KEY_DO_NOT_IMPORT");
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
    if (get_var('UEFI') && get_var('BOOTFROM')) {
        loadtest "boot/uefi_bootmenu";
    }
    loadtest "boot/boot_to_desktop";
}

sub load_yast2_ui_tests {
    boot_hdd_image;
    # setup $serialdev permission and so on
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
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
    # TODO: why are the following two modules called on sle but not on opensuse?
    # TODO: check if the following two modules also work on opensuse and delete if
    if (check_var('DISTRI', 'sle')) {
        loadtest "console/yast2_lan_hostname";
        loadtest "console/yast2_nis";
    }
    # TODO: check if the following two modules also work on sle and delete if.
    # yast-lan related tests do not work when using networkmanager.
    # (Livesystem and laptops do use networkmanager)
    if (check_var('DISTRI', 'opensuse') && !get_var("LIVETEST") && !get_var("LAPTOP")) {
        loadtest "console/yast2_cmdline";
        loadtest "console/yast2_dns_server";
        loadtest "console/yast2_nfs_client";
    }
    loadtest "console/yast2_http";
    loadtest "console/yast2_ftp";
    # back to desktop
    loadtest "console/consoletest_finish";
    return
      unless (!get_var("INSTALLONLY")
        && is_desktop_installed()
        && !get_var("DUALBOOT")
        && !get_var("RESCUECD")
        && get_var("Y2UITEST"));
    # TODO: check why this was not called on opensuse
    if (check_var('DISTRI', 'sle')) {
        loadtest "x11/yast2_lan_restart";
    }
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

sub maybe_load_kernel_tests {
    if (get_var('INSTALL_LTP')) {
        if (get_var('INSTALL_KOTD')) {
            loadtest 'kernel/install_kotd';
        }
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
        if (get_var('INSTALL_KOTD')) {
            loadtest 'kernel/install_kotd';
        }
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
        return 0;
    }
    return 1;
}

sub load_extra_tests() {
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
            loadtest 'x11/yast2_lan_restart';
            loadtest 'x11/user_defined_snapshot';
        }
        elsif (check_var('DISTRI', 'opensuse')) {
            if (!get_var("NOAUTOLOGIN")) {
                loadtest "x11/multi_users_dm";
            }
            if (gnomestep_is_applicable()) {
                if (check_var('VERSION', '42.2')) {
                    # 42.2 feature - not even on Tumbleweed
                    loadtest "x11/gdm_session_switch";
                }
                loadtest "x11/seahorse";
            }
        }
    }
    else {
        loadtest "console/zypper_lr";
        loadtest "console/openvswitch";
        # dependency of git test
        loadtest "console/sshd";
        loadtest "console/zypper_ref";
        loadtest "console/zypper_info";
        loadtest "console/update_alternatives";
        # start extra console tests from here
        # Audio device is not supported on ppc64le, JeOS, and Xen PV
        if (!get_var("OFW") && !is_jeos && !check_var('VIRSH_VMM_TYPE', 'linux')) {
            loadtest "console/aplay";
        }
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
        loadtest "console/command_not_found";
        if (check_var('DISTRI', 'sle')) {
            loadtest 'console/snapper_thin_lvm';
            if (sle_version_at_least('12-SP2')) {
                loadtest 'console/openssl_alpn';
                loadtest 'console/autoyast_removed';
            }
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
        }
        loadtest "console/git";
        loadtest "console/java";
        loadtest "console/curl_ipv6";
        loadtest "console/wget_ipv6";
        loadtest "console/unzip";
        loadtest "console/zypper_moo";
        if (get_var("SYSAUTHTEST")) {
            # sysauth test scenarios run in the console
            loadtest "sysauth/sssd";
        }
        # finished console test and back to desktop
        loadtest "console/consoletest_finish";
        # kdump is not supported on aarch64, see BSC#990418
        if (!check_var('ARCH', 'aarch64')) {
            loadtest "toolchain/crash";
        }
    }
    return 1;
}

sub load_rollback_tests() {
    loadtest "boot/grub_test_snapshot";
    if (get_var('UPGRADE') || get_var('ZDUP')) {
        loadtest "boot/snapper_rollback";
    }
    if (get_var('MIGRATION_ROLLBACK')) {
        loadtest "online_migration/sle12_online_migration/snapper_rollback";
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

1;
