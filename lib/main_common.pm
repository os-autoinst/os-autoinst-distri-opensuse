package main_common;
use base Exporter;
use Exporter;
use testapi qw/check_var get_var set_var diag/;
use autotest;
use strict;
use warnings;

our @EXPORT = qw/
  init_main
  loadtest
  set_defaults_for_username_and_password
  setup_env
  logcurrentenv
  is_staging
  is_reboot_after_installation_necessary
  load_login_tests
  load_rescuecd_tests
  load_zdup_tests
  load_autoyast_tests
  installzdupstep_is_applicable
  snapper_is_applicable
  gnomestep_is_applicable
  installyaststep_is_applicable
  bigx11step_is_applicable
  noupdatestep_is_applicable
  kdestep_is_applicable
  consolestep_is_applicable
  rescuecdstep_is_applicable
  remove_desktop_needles
  check_env
  ssh_key_import
  unregister_needle_tags
  /;

sub init_main {
    set_defaults_for_username_and_password();
    setup_env();
    check_env();
}

sub loadtest {
    my ($test) = @_;
    autotest::loadtest("tests/$test");
}

sub set_defaults_for_username_and_password {
    if (get_var("LIVETEST")) {
        $testapi::username = "root";
        $testapi::password = '';
    }
    else {
        $testapi::username = "bernhard";
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

sub is_reboot_after_installation_necessary {
    return 0 if get_var("DUALBOOT") || get_var("RESCUECD") || get_var("ZDUP");

    return get_var("REBOOTAFTERINSTALL") && !get_var("UPGRADE");
}

sub load_login_tests {
    if (!get_var("UEFI")) {
        loadtest "login/boot.pm";
    }
}

sub load_rescuecd_tests {
    if (rescuecdstep_is_applicable()) {
        loadtest "rescuecd/rescuecd.pm";
    }
}

sub load_zdup_tests {
    loadtest 'installation/setup_zdup.pm';
    loadtest 'installation/zdup.pm';
    loadtest 'installation/post_zdup.pm';
    loadtest 'boot/boot_to_desktop.pm';
}

sub load_autoyast_tests {
    #    init boot in load_boot_tests
    loadtest("autoyast/installation.pm");
    loadtest("autoyast/console.pm");
    loadtest("autoyast/login.pm");
    loadtest("autoyast/wicked.pm");
    loadtest("autoyast/autoyast_verify.pm") if get_var("AUTOYAST_VERIFY");
    if (get_var("SUPPORT_SERVER_GENERATOR")) {
        loadtest("support_server/configure.pm");
    }
    else {
        loadtest("autoyast/repos.pm");
        loadtest("autoyast/clone.pm");
        loadtest("autoyast/logs.pm");
    }
    loadtest("autoyast/autoyast_reboot.pm");
    #    next boot in load_reboot_tests
}

sub installzdupstep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && get_var("ZDUP");
}

sub snapper_is_applicable {
    my $fs = get_var("FILESYSTEM", 'btrfs');
    return ($fs eq "btrfs" && get_var("HDDSIZEGB", 10) > 10);
}

sub gnomestep_is_applicable {
    return check_var("DESKTOP", "gnome");
}

sub installyaststep_is_applicable {
    return !get_var("NOINSTALL") && !get_var("RESCUECD") && !get_var("ZDUP");
}

sub bigx11step_is_applicable {
    return get_var("BIGTEST");
}

sub noupdatestep_is_applicable {
    return !get_var("UPGRADE");
}

sub kdestep_is_applicable {
    return check_var("DESKTOP", "kde");
}

sub consolestep_is_applicable {
    return !get_var("INSTALLONLY") && !get_var("DUALBOOT") && !get_var("RESCUECD");
}

sub rescuecdstep_is_applicable {
    return get_var("RESCUECD");
}

sub ssh_key_import {
    return get_var("SSH_KEY_IMPORT") || get_var("SSH_KEY_DO_NOT_IMPORT");
}

sub remove_desktop_needles {
    my $desktop = shift;
    if (!check_var("DESKTOP", $desktop) && !check_var("FULL_DESKTOP", $desktop)) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES           => [0, 1],
    USEIMAGES          => [0, 1],
    REBOOTAFTERINSTALL => [0, 1],
    DOCRUN             => [0, 1],

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
    for my $n (@a) { $n->unregister(); }
}

1;
