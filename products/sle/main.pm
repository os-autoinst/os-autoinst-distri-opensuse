use strict;
use testapi qw/get_var set_var/;
use Cwd qw/abs_path/;
use File::Basename;
my $dirname = dirname(__FILE__);

my $version = get_var('VERSION', '');
require "$dirname/$version/main.pm";
my $versioned_distri = get_var('DISTRI') . "/$version";
set_var('DISTRI', $versioned_distri);
bmwqemu::diag("overwrote DISTRI to fool os-autoinst before loading needles: " . get_var('DISTRI'));

1;
# vim: set sw=4 et:
