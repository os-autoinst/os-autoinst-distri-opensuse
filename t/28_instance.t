use strict;
use warnings;
use Test::MockModule;
use Test::MockObject;
use Test::Exception;
use Test::More;
use Test::Mock::Time;
use testapi;
use List::Util qw(any none sum);

use publiccloud::instance;

subtest "[retry_on_script_output]" => sub {
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $result = "";
    my $data_test = (
        username => 'test'
    );
    $pc_instance->redefine(ssh_script_output => sub { return "running"; });
    $pc_instance->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO --> System is running.', @_)); });

    $result = publiccloud::instance->retry_on_script_output($pc_instance, $data_test);
    ok $result eq 'running';
};

subtest "[retry_on_script_output_stop]" => sub {
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $result = "";
    my $data_test = (
        username => 'test'
    );
    $pc_instance->redefine(ssh_script_output => sub { return "stopped"; });
    $pc_instance->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO --> Failed after retries.', @_)); });

    $result = publiccloud::instance->retry_on_script_output($pc_instance, $data_test);
    ok $result eq 'stopped';
};

done_testing;
