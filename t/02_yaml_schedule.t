use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use YAML::PP;
use File::Basename;

my $include = YAML::PP::Schema::Include->new(paths => (dirname(__FILE__) . '/../'));
my $ypp     = YAML::PP->new(schema => ['Core', $include, 'Merge']);
$include->yp($ypp);

subtest 'parse_yaml_test_data_single_import' => sub {
    use scheduler;
    # compare versions if possible
    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_schedule_single_import.yaml');
    scheduler::parse_test_suite_data($schedule);
    my $testdata = scheduler::get_test_suite_data();
    ok $testdata->{test_in_yaml_schedule} eq 'test_in_yaml_schedule_value', "Value from schedule file was overwritten by yaml import";
    ok $testdata->{test_in_yaml_import_1} eq 'test_in_yaml_import_value_1', "Value from single imported yaml were not parsed properly";

};

subtest 'parse_yaml_test_data_multiple_imports' => sub {
    use scheduler;
    # compare versions if possible
    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_schedule_multi_imports.yaml');
    scheduler::parse_test_suite_data($schedule);
    my $testdata = scheduler::get_test_suite_data();
    ok $testdata->{test_in_yaml_schedule} eq 'test_in_yaml_schedule_value', "Value from schedule file was overwritten by yaml import";
    ok $testdata->{test_in_yaml_import_1} eq 'test_in_yaml_import_value_1', "Value from the first imported yaml were not parsed properly";
    ok $testdata->{test_in_yaml_import_2} eq 'test_in_yaml_import_value_2', "Value from the second imported yaml were not parsed properly";

};

subtest 'parse_yaml_test_data_using_yaml_data_setting' => sub {
    use scheduler;
    use testapi 'set_var';

    set_var('YAML_TEST_DATA', 't/data/test_data_yaml_data_setting.yaml');
    # compare versions if possible
    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_schedule_yaml_data_setting.yaml');
    scheduler::parse_test_suite_data($schedule);
    my $testdata = scheduler::get_test_suite_data();
    ok $testdata->{test_in_yaml_data} eq 'test_in_yaml_data',               "Value from data file was overwritten by value from schedule or other imports";
    ok $testdata->{test_in_yaml_import_3} eq 'test_in_yaml_import_value_3', "Value in data file was overwritten by value in schedule file";
};

subtest 'parse_yaml_test_schedule_recursive_conditional' => sub {
    use scheduler;
    use testapi 'set_var';

    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_schedule_recursive_conditional.yaml');
    my @modules;
    @modules = scheduler::parse_schedule($schedule);
    ok $modules[0] eq 'bar/test0', "Basic scheduling";
    ok $modules[1] eq 'bar/test3', "Basic scheduling";
    set_var('VAR1', 'foo');
    @modules = scheduler::parse_schedule($schedule);
    ok $modules[0] eq 'bar/test0', "Basic scheduling";
    ok $modules[1] eq 'foo/test1', "Conditional scheduling";
    ok $modules[2] eq 'bar/test3', "Basic scheduling";
    set_var('VAR2', 'foo');
    @modules = scheduler::parse_schedule($schedule);
    ok $modules[0] eq 'bar/test0', "Basic scheduling";
    ok $modules[1] eq 'foo/test1', "Conditional scheduling";
    ok $modules[2] eq 'foo/test2', "Recursive conditional scheduling";
    ok $modules[3] eq 'bar/test3', "Basic scheduling";
};

done_testing;
