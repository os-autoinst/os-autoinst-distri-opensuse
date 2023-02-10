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
use main_common qw(init_main);
use main_micro_alp;

init_main();

my $distri = testapi::get_required_var('CASEDIR') . '/lib/susedistribution.pm';
require $distri;
testapi::set_distribution(DistributionProvider->provide());

return 1 if load_yaml_schedule;
main_micro_alp::load_tests();

1;
