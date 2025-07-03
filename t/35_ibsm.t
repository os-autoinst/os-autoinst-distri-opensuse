use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;


use sles4sap::ibsm;

subtest '[ibsm_calculate_address_range]' => sub {
    my %result_1 = ibsm_calculate_address_range(slot => 1);
    my %result_2 = ibsm_calculate_address_range(slot => 2);
    my %result_64 = ibsm_calculate_address_range(slot => 64);
    my %result_65 = ibsm_calculate_address_range(slot => 65);
    my %result_8192 = ibsm_calculate_address_range(slot => 8192);

    is($result_1{main_address_range}, "10.0.0.0/21", 'result_1 main_address_range is correct');
    is($result_1{subnet_address_range}, "10.0.0.0/24", 'result_1 subnet_address_range is correct');
    is($result_2{main_address_range}, "10.0.8.0/21", 'result_2 main_address_range is correct');
    is($result_2{subnet_address_range}, "10.0.8.0/24", 'result_2 subnet_address_range is correct');
    is($result_64{main_address_range}, "10.1.248.0/21", 'result_64 main_address_range is correct');
    is($result_64{subnet_address_range}, "10.1.248.0/24", 'result_64 subnet_address_range is correct');
    is($result_65{main_address_range}, "10.2.0.0/21", 'result_65 main_address_range is correct');
    is($result_65{subnet_address_range}, "10.2.0.0/24", 'result_65 subnet_address_range is correct');
    is($result_8192{main_address_range}, "10.255.248.0/21", 'result_8192 main_address_range is correct');
    is($result_8192{subnet_address_range}, "10.255.248.0/24", 'result_8192 subnet_address_range is correct');
    dies_ok { ibsm_calculate_address_range(slot => 0); } "Expected die for slot < 1";
    dies_ok { ibsm_calculate_address_range(slot => 8193); } "Expected die for slot > 8192";
};

done_testing;
