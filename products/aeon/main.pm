# SUSE's openQA tests
#
# Copyright SUSE LLC and contributors
# SPDX-License-Identifier: FSFAP

# Summary: Entry point for testing Aeon installation and initial setup

# Maintainer: Jan-Willem Harmannij <jwharmannij at gmail com>

use strict;
use warnings;
use needle;
use File::Basename;
use scheduler 'load_yaml_schedule';
use DistributionProvider;
BEGIN {
    unshift @INC, dirname(__FILE__) . '/../../lib';
}
use utils;
use testapi;
use main_common;

init_main();

my $casedir = testapi::get_required_var('CASEDIR');
my $distri = $casedir . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(DistributionProvider->provide());

return 1 if load_yaml_schedule;

loadtest 'aeon/tik';
loadtest 'aeon/firstboot';

1;
