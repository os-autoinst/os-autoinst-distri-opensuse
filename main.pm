#!/usr/bin/perl -w
use strict;
use bmwqemu;
use autotest;
use needle;
use File::Find;

our %valueranges = (

    #   LVM=>[0,1],
    NOIMAGES           => [ 0, 1 ],
    REBOOTAFTERINSTALL => [ 0, 1 ],
    DOCRUN             => [ 0, 1 ],

    #   BTRFS=>[0,1],
    DESKTOP => [qw(kde gnome xfce lxde minimalx textmode)],

    #   ROOTFS=>[qw(ext3 xfs jfs btrfs reiserfs)],
    VIDEOMODE => [ "", "text" ],
);

our @can_randomize = qw/NOIMAGES REBOOTAFTERINSTALL DESKTOP VIDEOMODE/;

our $envs = load_envs();

sub logcurrentenv(@) {
    foreach my $k (@_) {
        my $e = $envs->{$k};
        next unless defined $e;
        diag("usingenv $k=$e");
    }
}

sub setrandomenv() {
    for my $k (@can_randomize) {
        next if defined $envs->{$k};
        next if $k eq "DESKTOP" && $envs->{LIVECD};
        if ( $envs->{DOCRUN} ) {
            next if $k eq "VIDEOMODE";
            next if $k eq "NOIMAGES";
        }
        my @range = @{ $valueranges{$k} };
        my $rand  = int( rand( scalar @range ) );
        $envs->{$k} = $range[$rand];
        logcurrentenv($k);
    }
}

sub check_env() {
    for my $k ( keys %valueranges ) {
        next unless exists $envs->{$k};
        unless ( grep { $envs->{$k} eq $_ } @{ $valueranges{$k} } ) {
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
    if ( !checkEnv( "DESKTOP", $desktop ) ) {
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

    if ( !$envs->{LIVECD} ) {
        unregister_needle_tags("ENV-LIVECD-1");
    }
    else {
        unregister_needle_tags("ENV-LIVECD-0");
    }
    if ( !checkEnv( "VIDEOMODE", "text" ) ) {
        unregister_needle_tags("ENV-VIDEOMODE-text");
    }
    if ( $envs->{INSTLANG} && $envs->{INSTLANG} ne "en_US" ) {
        unregister_needle_tags("ENV-INSTLANG-en_US");
    }
    else {    # english default
        unregister_needle_tags("ENV-INSTLANG-de_DE");
    }

}

# wait for qemu to start
while ( !getcurrentscreenshot() ) {
    sleep 1;
}

#assert_screen "inst-bootmenu",12; # wait for welcome animation to finish

if ( $envs->{LIVETEST} && ( $envs->{LIVECD} || $envs->{PROMO} ) ) {
    $username = "linux";    # LiveCD account
    $password = "";
}

check_env();
setrandomenv if ( $envs->{RANDOMENV} );

unless ( $envs->{DESKTOP} ) {
    if ( checkEnv( "VIDEOMODE", "text" ) ) {
        $envs->{DESKTOP} = "textmode";
    }
    else {
        $envs->{DESKTOP} = "kde";
    }
}
if ( checkEnv( 'DESKTOP', 'minimalx' ) ) {
    $envs->{'NOAUTOLOGIN'} = 1;
    $envs->{XDMUSED} = 1;
}

$envs->{SUSEMIRROR} ||= "download.opensuse.org/factory";

$needle::cleanuphandler = \&cleanup_needles;

$envs->{SCREENSHOTINTERVAL} ||= .5;

save_envs($envs);

# dump other important envrionment variables:
logcurrentenv(qw"ADDONURL BIGTEST BTRFS DESKTOP HW HWSLOT LIVETEST LVM MOZILLATEST NOINSTALL REBOOTAFTERINSTALL UPGRADE USBBOOT TUMBLEWEED WDUP ZDUP ZDUPREPOS TEXTMODE DISTRI NOAUTOLOGIN QEMUCPU QEMUCPUS RAIDLEVEL ENCRYPT INSTLANG QEMUVGA DOCRUN UEFI DVD GNOME KDE ISO ISO_MAXSIZE LIVECD NETBOOT NICEVIDEO NOIMAGES PROMO QEMUVGA SPLITUSR VIDEOMODE");

sub _wanted() {
    autotest::loadtestdir("$File::Find::name") if -d;
}

# load the tests in the right order
if ( $envs->{REGRESSION} ) {
    if ( $envs->{KEEPHDDS} ) {
        autotest::loadtestdir("$envs->{CASEDIR}/login.d");
    }
    else {
        autotest::loadtestdir("$envs->{CASEDIR}/inst.d");
    }

    if ( $envs->{DESKTOP} =~ /gnome/ ) {
        find( \&_wanted, "$envs->{CASEDIR}/x11regression.d" );
    }

}
else {
    autotest::loadtestdir("$envs->{CASEDIR}/inst.d");
    if ( !$envs->{'INSTALLONLY'} ) {
        if ( !$envs->{NICEVIDEO} && !$envs->{DUALBOOT} ) {
            autotest::loadtestdir("$envs->{CASEDIR}/consoletest.d");
        }
        if ( $envs->{DESKTOP} !~ /textmode|minimalx/ && !$envs->{DUALBOOT} ) {
            autotest::loadtestdir("$envs->{CASEDIR}/x11test.d");
        }
    }
}

1;
# vim: set sw=4 et:
