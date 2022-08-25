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
use Config::Tiny;

my $config = Config::Tiny->read($ARGV[0]);
my $go_test = '';
my $skip_test = '';
my $extra_opt = '';

foreach my $key (keys %{$config->{$ARGV[1]}}) {
    if ($key eq 'GINKGO_FOCUS') {
        $go_test = $config->{$ARGV[1]}->{$key};
    } elsif ($key eq 'GINKGO_SKIP') {
        $skip_test = "|$config->{$ARGV[1]}->{$key}";
    } elsif ($key eq 'EXTRA_OPT') {
        $extra_opt = $config->{$ARGV[1]}->{$key};
    }
}

my $params = join(",", $go_test, $skip_test, $extra_opt);
print $params;
