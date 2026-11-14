# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Obtain test parameters from test config file on SUT
# Maintainer: Nan Zhang <nan.zhang@suse.com>
#
# Usage: perl config_parser.pl <kubevirt-tests.conf> <vmi_lifecycle_test>

use strict;
use warnings;

my ($conf_file, $section) = @ARGV;
die "Usage: perl config_parser.pl <kubevirt-tests.conf> <section>\n" unless defined $conf_file && defined $section;
die "Config file '$conf_file' not found\n" unless -e $conf_file;

# Plain INI: [section] headers, KEY=VALUE lines, '#' comments and blank lines
my %config;
my $current;
open(my $fh, '<', $conf_file) or die "Cannot open config file '$conf_file': $!\n";
while (my $line = <$fh>) {
    chomp $line;
    next if $line =~ /^\s*(#|$)/;
    if ($line =~ /^\s*\[(.+?)\]\s*$/) {
        $current = $1;
        $config{$current} //= {};
    } elsif ($line =~ /^\s*([^=]+?)\s*=\s*(.*?)\s*$/ && defined $current) {
        $config{$current}{$1} = $2;
    }
}
close($fh);

die "Section '$section' not found in '$conf_file'\n" unless $config{$section};

my $go_test = '';
my $skip_test = '';
my $extra_opt = '';

foreach my $key (keys %{$config{$section}}) {
    if ($key eq 'GINKGO_FOCUS') {
        $go_test = $config{$section}->{$key};
    } elsif ($key eq 'GINKGO_SKIP') {
        $skip_test = "|$config{$section}->{$key}";
    } elsif ($key eq 'EXTRA_OPT') {
        $extra_opt = $config{$section}->{$key};
    }
}

my $params = join(",", $go_test, $skip_test, $extra_opt);
print $params;
