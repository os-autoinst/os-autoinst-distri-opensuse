#!/usr/bin/perl

use strict;
use warnings;

my @temp_array;
my @return_array;
my $installed_products = '/tmp/installed_products';

open my $fd, '<', $installed_products or die "Could not open '$installed_products' $!\n";

while (my $line = <$fd>) {
    chomp $line;
    #trim whitespaces
    $line =~ s/^\s+//;
    push(@temp_array, $line);
}

# $i-3 as one should expect product 3 lines above
# excpeceted file should look like:
# Installed Products:
#------------------------------------------
#
#  SUSE Linux Enterprise Server 12 SP4
#  (SLES/12.4/x86_64)
#
#  Not Registered
my $i = 0;
foreach (@temp_array) {
    if ($_ =~ 'Not Registered') {
        my $s = substr($temp_array[$i - 2], 1, -1);
        push(@return_array, $s);
    }
    $i++;
}

## return scalar for ease of handling
my $compactify //= 'empty';
my $y = 0;
foreach (@return_array) {
    if ($y == 0) {
        $compactify = "$_";
    } else {
        $compactify .= "|$_";
    }
    $y++;
}

print("$compactify");
