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
use testapi qw(check_var get_var get_required_var set_var);
use lockapi;
use needle;
use version_utils ':VERSION';
use File::Find;
use File::Basename;
use YAML::Syck 'LoadFile';

BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use version_utils qw(is_jeos is_gnome_next is_krypton_argon is_leap is_tumbleweed is_rescuesystem is_desktop_installed is_opensuse is_sle is_staging);
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

# Set serial failures
my $serial_failures = [];
push @$serial_failures, {type => 'soft', message => 'bsc#1112109', pattern => qr/serial-getty.*service: Service RestartSec=.*ms expired, scheduling restart/};

$testapi::distri->set_expected_serial_failures($serial_failures);

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
    # lightdm is the default DM for Tumbleweed and Leap 15.0 per boo#1081760
    if (is_leap('<15.0')) {
        set_var("XDMUSED",           1);
        set_var('DM_NEEDS_USERNAME', 1);
    }
    # Set patterns for the new system role flow, as we need to select patterns, similarly to SLE12
    if (is_using_system_role && !get_var('PATTERNS')) {
        set_var('PATTERNS', 'default,minimalx');
    }
}

if (is_using_system_role && check_var('DESKTOP', 'lxde') && !get_var('PATTERNS')) {
    set_var('PATTERNS', 'default,lxde');
}

if (is_using_system_role && check_var('DESKTOP', 'xfce') && !get_var('PATTERNS')) {
    set_var('PATTERNS', 'default,xfce');
}

# openSUSE specific variables
set_var('LEAP', '1') if is_leap;
set_var("WALLPAPER", '/usr/share/wallpapers/openSUSEdefault/contents/images/1280x1024.jpg');

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# now Plasma 5 is default KDE desktop
# openSUSE version less than or equal to 13.2 have to set KDE4 variable as 1
if (check_var('DESKTOP', 'kde') && !get_var('KDE4')) {
    set_var("PLASMA5", 1);
}

# ZDUP_IN_X imply ZDUP
if (get_var('ZDUP_IN_X')) {
    set_var('ZDUP', 1);
}

if (is_updates_test_repo && !get_var('ZYPPER_ADD_REPOS')) {
    my $repos = map_incidents_to_repo({OS => get_required_var('OS_TEST_ISSUES')}, {OS => get_required_var('OS_TEST_TEMPLATE')});
    set_var('ZYPPER_ADD_REPOS', $repos);
    # these are not using default gpg keys
    set_var('ZYPPER_ADD_REPO_PREFIX', 'untrusted');
}

if (get_var("WITH_UPDATE_REPO")
    || get_var("WITH_MAIN_REPO")
    || get_var("WITH_DEBUG_REPO")
    || get_var("WITH_SOURCE_REPO")
    || get_var("WITH_UNTESTED_REPO"))
{
    set_var('HAVE_ADDON_REPOS', 1);
}

$needle::cleanuphandler = \&cleanup_needles;

# YAML::Any seems to be a good choice but we do not have that package it
# seems, YAML::Tiny does not seem to support JSON-like arrays
my %declared_schedule = %{LoadFile(dirname(__FILE__) . '/main.yml')};

=head2 eval_yaml

  eval_yaml($string)

Evaluates the string as either a test variable when the string is just a single non-space string or tries to evaluate as a a more complex perl expression.
=cut

sub eval_yaml {
    my ($expression) = @_;
    return get_var($expression) if $expression =~ /[a-zA-Z0-9_]/;
    {
        return eval { $expression };
    }
    die "YAML expression failed to evaluate: $@" if $@;
}

=head2 load_module

  load_module($module)

Load one test module from a schedule hash. The inclusion/exclusion of the
module can be controlled by specifying the module with C<module> and the key
C<only> or <except> next to the module.

We could have this logic to include/exclude specific modules in the modules itself but this would contradict
https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/150
even though we still have C<is_applicable> in basetest.pm in os-autoinst.

=cut

sub load_module {
    my ($module) = @_;
    return $module unless ref $module eq 'HASH';
    my %module = %{$module};
    return $module{module} if ($module{module} && ($module{only} && eval_yaml($module{only})) && !($module{except} && !eval_yaml($module{except})));
}

=head2 load_schedule

  load_schedule($tests)

Loads test modules or groups of tests by identifier from C<main.yml> in the same directory as the current file.

In the simple case of just scheduling a list of test modules specify them as an array directly:

 my_tests:
   - module1
   - module2

or in shorter JSON style:

 my_tests: [module_1, module_2]

More advanced instructions are possible by specifying according keys in the
section. In this case the test modules must be specified in an array with the
name C<modules>. The keywords C<only> an C<except> denote a test variable or a
perl expression that must evaluate to a true respectively false value for the
section to load. Other sections can be referenced with C<groups>. Test
variables specified like perl variables are expanded.
Inclusion/exclusion of single modules within the modules list is also possible
by specifying the module with C<module> and the key C<only> or <except> next
to the module.

An advanced example:

 my_tests_advanced:
   only: is_advanced()
   except: VAR1
   modules:
     - module1
     - module2
     - module: module3
       except: NO_MOD3

=cut

sub load_schedule {
    my ($key) = @_;
    die "Schedule reference '$key' not found in any definition files." unless exists $declared_schedule{$key};
    my $section = $declared_schedule{$key};
    return map { load_module($_) } $section if ref $section eq 'ARRAY';
    return 0 if $section->{only} and eval_yaml($section->{only});


}

# dump other important ENV:
logcurrentenv(
    qw(ADDONURL BTRFS DESKTOP LIVETEST LVM
      MOZILLATEST NOINSTALL UPGRADE USBBOOT ZDUP
      ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL
      ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE
      LIVECD NETBOOT NOIMAGES QEMUVGA SPLITUSR VIDEOMODE)
);

sub have_addn_repos {
    return !get_var("NET") && !get_var("EVERGREEN") && get_var("SUSEMIRROR") && !is_staging();
}

sub install_online_updates {
    return 0 unless get_var('INSTALL_ONLINE_UPDATES');

    my @tests = qw(
      console/zypper_disable_deltarpm
      console/zypper_add_repos
      update/zypper_up
      console/console_reboot
    );

    for my $test (@tests) {
        loadtest "$test";
    }
    load_shutdown_tests;

    return 1;
}

sub load_qam_install_tests {
    return 0 unless get_var('INSTALL_PACKAGES');
    loadtest "console/system_prepare";
    loadtest 'console/consoletest_setup';
    loadtest 'console/import_gpg_keys';
    loadtest 'update/zypper_up';
    loadtest 'console/install_packages';
    loadtest 'console/zypper_add_repos';
    loadtest 'console/qam_zypper_patch';
    loadtest 'console/qam_verify_package_install';

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

sub load_default_tests {
    load_boot_tests();
    load_inst_tests();
    return 1 if get_var('EXIT_AFTER_START_INSTALL');
    load_reboot_tests();
}

# load the tests in the right order
if (is_jeos) {
    load_jeos_tests();
}

if (is_kernel_test()) {
    load_kernel_tests();
}
elsif (get_var("NETWORKD")) {
    boot_hdd_image();
    load_networkd_tests();
}
elsif (get_var("WICKED")) {
    boot_hdd_image();
    load_wicked_tests();
}
elsif (get_var('NFV')) {
    load_nfv_tests();
}
elsif (get_var("REGRESSION")) {
    load_common_x11;
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
elsif (get_var("FILESYSTEM_TEST")) {
    boot_hdd_image;
    load_filesystem_tests();
}
elsif (get_var("SYSCONTAINER_IMAGE_TEST")) {
    boot_hdd_image;
    load_syscontainer_tests();
}
elsif (get_var('GNUHEALTH')) {
    boot_hdd_image;
    loadtest 'gnuhealth/gnuhealth_install';
    loadtest 'gnuhealth/gnuhealth_setup';
    loadtest 'gnuhealth/gnuhealth_client_install';
    loadtest 'gnuhealth/gnuhealth_client_preconfigure';
    loadtest 'gnuhealth/gnuhealth_client_first_time';
}
elsif (is_rescuesystem) {
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
        loadtest "support_server/wait_children";
    }
}
elsif (get_var("WINDOWS")) {
    loadtest "installation/win10_installation";
    loadtest "installation/win10_firstboot";
    loadtest "installation/win10_reboot";
    loadtest "installation/win10_shutdown";
}
elsif (ssh_key_import) {
    load_ssh_key_import_tests;
}
elsif (get_var("ISO_IN_EXTERNAL_DRIVE")) {
    load_iso_in_external_tests();
    load_inst_tests();
    load_reboot_tests();
}
elsif (get_var('SECURITY_TEST')) {
    boot_hdd_image;
    loadtest "console/system_prepare";
    loadtest "console/consoletest_setup";
    loadtest "console/hostname";
    if (check_var('SECURITY_TEST', 'core')) {
        load_security_tests_core;
    }
    elsif (check_var('SECURITY_TEST', 'web')) {
        load_security_tests_web;
    }
    elsif (check_var('SECURITY_TEST', 'misc')) {
        load_security_tests_misc;
    }
    elsif (check_var('SECURITY_TEST', 'crypt')) {
        load_security_tests_crypt;
    }
    elsif (check_var("SECURITY_TEST", "apparmor")) {
        load_security_tests_apparmor;
    }
    elsif (check_var("SECURITY_TEST", "openscap")) {
        load_security_tests_openscap;
    }
    elsif (check_var("SECURITY_TEST", "selinux")) {
        load_security_tests_selinux;
    }
}
elsif (get_var('SYSTEMD_TESTSUITE')) {
    load_systemd_patches_tests;
}
elsif (get_var('DOCKER_IMAGE_TEST')) {
    boot_hdd_image;
    load_extra_tests_docker;
}
else {
    if (get_var("LIVETEST") || get_var('LIVE_INSTALLATION') || get_var('LIVE_UPGRADE')) {
        load_boot_tests();
        loadtest "installation/finish_desktop";
        if (get_var('LIVE_INSTALLATION') || get_var('LIVE_UPGRADE')) {
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
        loadtest "console/force_scheduled_tasks";
        loadtest "jeos/diskusage";
        loadtest "jeos/root_fs_size";
        loadtest "jeos/mount_by_label";
        if (get_var("SCC_EMAIL") && get_var("SCC_REGCODE")) {
            loadtest "jeos/sccreg";
        }
    }
    else {
        return 1 if load_default_tests;
    }

    unless (install_online_updates()
        || load_qam_install_tests()
        || load_extra_tests()
        || load_virtualization_tests()
        || load_schedule('otherDE')
        || load_slenkins_tests())
    {
        load_schedule('fixup_network');
        load_schedule('fixup_firewall');
        load_system_update_tests();
        load_rescuecd_tests();
        if (consolestep_is_applicable) {
            load_consoletests();
        }
        elsif (is_staging() && get_var('UEFI') || is_gnome_next || is_krypton_argon) {
            load_schedule('consoletests_minimal');
        }
        load_x11tests();
        if (get_var('ROLLBACK_AFTER_MIGRATION') && (snapper_is_applicable())) {
            load_rollback_tests();
        }
    }
}

load_common_opensuse_sle_tests;

1;
