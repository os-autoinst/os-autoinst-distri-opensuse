#!/usr/bin/perl -w
use strict;
use testapi;
use autotest;
use needle;
use File::Find;

our %valueranges = (

    #   LVM=>[0,1],
#    NOIMAGES           => [ 0, 1 ],
#    REBOOTAFTERINSTALL => [ 0, 1 ],
#    DOCRUN             => [ 0, 1 ],

    #   BTRFS=>[0,1],
#    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode)],

    #   ROOTFS=>[qw(ext3 xfs jfs btrfs reiserfs)],
    VIDEOMODE => [ "", "text" ],
);

sub logcurrentenv(@) {
    foreach my $k (@_) {
        my $e = get_var("$k");
        next unless defined $e;
        bmwqemu::diag("usingenv $k=$e");
    }
}

sub check_env() {
    for my $k ( keys %valueranges ) {
        next unless get_var($k);
        unless ( grep { get_var($k) eq $_ } @{ $valueranges{$k} } ) {
            die sprintf( "%s must be one of %s\n", $k, join( ',', @{ $valueranges{$k} } ) );
        }
    }
}

sub unregister_needle_tags($) {
    my $tag = shift;
    my @a   = @{ needle::tags($tag) };
    for my $n (@a) { $n->unregister(); }
}

sub remove_desktop_needles($) {
    my $desktop = shift;
    if ( !check_var( "DESKTOP", $desktop ) ) {
        unregister_needle_tags("ENV-DESKTOP-$desktop");
    }
}

sub cleanup_needles() {
    remove_desktop_needles("lxde");
    remove_desktop_needles("kde");
    remove_desktop_needles("gnome");
    remove_desktop_needles("xfce");
    remove_desktop_needles("minimalx");
    remove_desktop_needles("textmode");

    if ( !get_var("LIVECD") ) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if ( !check_var( "VIDEOMODE", "text" ) ) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }
    if ( get_var("INSTLANG") && get_var("INSTLANG") ne "en_US" ) {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

}

# defaults for username and password
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

if ( get_var("LIVETEST") && ( get_var("LIVECD") || get_var("PROMO") ) ) {
    $testapi::username = "linux";    # LiveCD account
    $testapi::password = "";
}

if (check_var( 'DESKTOP', 'minimalx')) {
    set_var("NOAUTOLOGIN", 1);
    set_var("XDMUSED", 1);
    set_var('DM_NEEDS_USERNAME', 1);
}

my $distri = testapi::get_var("CASEDIR") . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(susedistribution->new());

check_env();

unless ( get_var("DESKTOP") ) {
    if ( check_var( "VIDEOMODE", "text" ) ) {
        set_var("DESKTOP", "textmode");
    }
    else {
        set_var("DESKTOP", "kde");
    }
}
if ( check_var( 'DESKTOP', 'minimalx' ) ) {
    set_var("NOAUTOLOGIN", 1);
    set_var("XDMUSED", 1);
    set_var('DM_NEEDS_USERNAME', 1);
}

# openSUSE specific variables
set_var("PACKAGETOINSTALL", "xdelta");
set_var("WALLPAPER", '/usr/share/wallpapers/openSUSEdefault/contents/images/1280x1024.jpg');
if ( !defined get_var( "YAST_SW_NO_SUMMARY" ) ) {
    set_var("YAST_SW_NO_SUMMARY", 1) if get_var('UPGRADE') || get_var("ZDUP");
}

# set KDE and GNOME, ...
set_var(uc(get_var('DESKTOP')), 1);

# now Plasma 5 is default KDE desktop
if (check_var( 'DESKTOP', 'kde' ) && check_var('VERSION', 'Tumbleweed')) {
    set_var("PLASMA5", 1);
}

$needle::cleanuphandler = \&cleanup_needles;

bmwqemu::save_vars(); # update variables

# dump other important ENV:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM USBBOOT TEXTMODE DISTRI QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA  UEFI DVD GNOME KDE ISO LIVECD NETBOOT NICEVIDEO PROMO QEMUVGA SPLITUSR VIDEOMODE");

sub loadtest($) {
    my ($test) = @_;
    autotest::loadtest("tests/$test");
}

my @console_tests;
my @x11_tests;
my $data_needed = 0;
my $t; # To iterate the different list of tests

# Boot the system from the hard disk
set_var("BOOT_HDD_IMAGE", 1);
loadtest "installation/bootloader.pm";
loadtest "installation/first_boot.pm";

# YaST specific setup
if (get_var("YAST_HEAD")) {
    push @console_tests, "console/add_yast_head.pm";
    push @console_tests, "console/install_yast_head.pm";
}

if (get_var("YAST_RUN_ONLY")) {
    foreach $t (split(/[;:]/, get_var("YAST_RUN_ONLY"))) {
        if ($t =~ /^console/) {
            push @console_tests, "$t.pm";
        } else {
            push @x11_tests, "$t.pm";
            $data_needed = 1 if ($t eq "x11/yast2_snapper");
        }
    }
} else {
    # Run all the relevant test
    unless (get_var("YAST_SKIP_CONSOLE")) {
        push @console_tests, "console/yast2_i.pm";
        push @console_tests, "console/yast2_bootloader.pm";
    }
    unless (get_var("YAST_SKIP_X11")) {
        $data_needed = 1; # Because of yast2_snapper
        push @x11_tests, "x11/yast2_snapper.pm";
        push @x11_tests, "x11/yast2_users.pm";
    }
}

if (@console_tests || $data_needed) {
    loadtest "console/consoletest_setup.pm";
    foreach $t (@console_tests) {
        loadtest $t;
    }
    loadtest "console/consoletest_finish.pm";
}
foreach $t (@x11_tests) {
    loadtest $t;
}

# Shutdown the system
loadtest "x11/shutdown.pm";

1;
# vim: set sw=4 et:
