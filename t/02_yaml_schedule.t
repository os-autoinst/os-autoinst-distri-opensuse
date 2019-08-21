use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use FindBin;
use YAML::Tiny;
use File::Basename;

# This is required to be able to read
# packages in distri's lib/ folder.
# Alternatively it can be supplied as -I option
# while running prove.
use lib ("$FindBin::Bin/lib", "$FindBin::Bin/../lib");

subtest 'parse_yaml_test_data_single_import' => sub {
    use scheduler;
    # compare versions if possible
    my $schedule = YAML::Tiny::LoadFile(dirname(__FILE__) . '/data/test_schedule_single_import.yaml');
    scheduler::parse_test_data($schedule);
    my $testdata = scheduler::get_test_data();
    ok $testdata->{test_in_yaml_schedule} eq 'test_in_yaml_schedule_value', "Value from schedule file was overwritten by yaml import";
    ok $testdata->{test_in_yaml_import_1} eq 'test_in_yaml_import_value_1', "Value from single imported yaml were not parsed properly";

};

subtest 'parse_yaml_test_data_multiple_imports' => sub {
    use scheduler;
    # compare versions if possible
    my $schedule = YAML::Tiny::LoadFile(dirname(__FILE__) . '/data/test_schedule_multi_imports.yaml');
    scheduler::parse_test_data($schedule);
    my $testdata = scheduler::get_test_data();
    ok $testdata->{test_in_yaml_schedule} eq 'test_in_yaml_schedule_value', "Value from schedule file was overwritten by yaml import";
    ok $testdata->{test_in_yaml_import_1} eq 'test_in_yaml_import_value_1', "Value from the first imported yaml were not parsed properly";
    ok $testdata->{test_in_yaml_import_2} eq 'test_in_yaml_import_value_2', "Value from the second imported yaml were not parsed properly";

};

subtest 'do_not_allow_nested_imports' => sub {
    my $schedule = YAML::Tiny::LoadFile(dirname(__FILE__) . '/data/test_schedule_nested_import.yaml');
    dies_ok { scheduler::parse_test_data($schedule) } "Error: test_data can only be defined in a dedicated file for data\n";
};

done_testing;
