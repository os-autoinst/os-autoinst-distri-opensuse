use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use YAML::PP;
use File::Basename;

my $include = YAML::PP::Schema::Include->new(paths => (dirname(__FILE__) . '/../'));
my $ypp = YAML::PP->new(schema => ['Core', $include, 'Merge']);
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

subtest 'parse_yaml_test_data_vars_expansion' => sub {
    use scheduler;
    use testapi 'set_var';

    set_var('ENV_VAR_1', 'aaa');
    set_var('ENV_VAR_2', 'bbb');
    set_var('ENV_VAR_3', 'ccc');
    set_var('ENV_VAR_4', 'ddd');
    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_data_vars_expansion.yaml');
    scheduler::parse_test_suite_data($schedule);
    my $testdata = scheduler::get_test_suite_data();
    ok $testdata->{var1} eq 'pre-aaa-post', 'Test data expanded properly for hash';
    ok $testdata->{nested1}->[0]->{nested2}->{var2} eq 'bbb-post', 'Test data expanded properly for nested hash';
    ok $testdata->{nested1}->[1] eq 'pre-ccc', 'Test data expanded properly for array';
    ok $testdata->{nested1}->[2]->{var4} eq 'ddd', 'Test data expanded properly for hash in array';
    ok $testdata->{nested1}->[3] eq '', 'Non-existing variable expanded as empty in test data for array';
    ok $testdata->{no_var} eq '', 'Non-existing variable expanded as empty string in test data for hash';
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
    ok $testdata->{test_in_yaml_data} eq 'test_in_yaml_data', "Value from data file was overwritten by value from schedule or other imports";
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

subtest 'merge default schedules with flows and individual schedules' => sub {
    use scheduler;
    use testapi 'set_var';

    # positive unit tests

    my $schedule = $ypp->load_file(dirname(__FILE__) . '/data/test_schedule_based_on_default.yaml');
    my @modules;
    set_var('YAML_SCHEDULE_DEFAULT', '/t/data/flows/default.yaml');
    set_var('YAML_SCHEDULE_FLOWS', 'flow_a');
    @modules = scheduler::parse_schedule($schedule);
    my @expected = ('flow_a_foo', 'flow_a_bar', 'individual_step_3');
    ok(eq_array(\@modules, \@expected), "Merge default with flows and schedule");
    set_var('YAML_SCHEDULE_FLOWS', 'flow_b');
    @modules = scheduler::parse_schedule($schedule);
    @expected = ('flow_b_foo', 'flow_b_bar', 'individual_step_3');
    ok(eq_array(\@modules, \@expected), "Merge default with flows and schedule");
    set_var('YAML_SCHEDULE_FLOWS', 'flow_a,flow_b');    # flow_b should win
    @modules = scheduler::parse_schedule($schedule);
    ok(eq_array(\@modules, \@expected), "Merge default with flows and schedule");
    set_var('YAML_SCHEDULE_FLOWS', 'flow_b,flow_a');    # flow_a should win
    @modules = scheduler::parse_schedule($schedule);
    @expected = ('flow_a_foo', 'flow_a_bar', 'individual_step_3');
    ok(eq_array(\@modules, \@expected), "Merge default with flows and schedule");


};

done_testing;
