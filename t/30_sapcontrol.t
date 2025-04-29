use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use sles4sap::sapcontrol;

sub undef_vars {
    set_var($_, undef) for qw(
      INSTANCE_TYPE
      INSTANCE_SID
      INSTANCE_ID);
}

subtest '[sapcontrol] Test expected failures' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    $sapcontrol->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %arguments = (instance_id => '00', webmethod => 'GoOverThere', sidadm => 'abcadm');

    $sapcontrol->redefine(script_output_retry_check => sub { return 'abcadm'; });
    $sapcontrol->redefine(script_run => sub { return '0'; });
    $arguments{webmethod} = '';
    dies_ok { sapcontrol(%arguments) } 'Fail without specifying webmethod';
    $arguments{webmethod} = 'GoOverThere';

    $arguments{instance_id} = '';
    dies_ok { sapcontrol(%arguments) } 'Fail without specifying instance_id';
    $arguments{instance_id} = '00';

    $sapcontrol->redefine(script_output_retry_check => sub { return 'abcadm'; });
    $arguments{remote_hostname} = 'charlie';
    dies_ok { sapcontrol(%arguments) } 'Remote execution fail without sidadm password';
};

subtest '[sapcontrol] Test using correct values' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    my @calls;
    $sapcontrol->redefine(script_output => sub { return 'command output' });
    $sapcontrol->redefine(script_output_retry_check => sub { return 'abcadm'; });
    $sapcontrol->redefine(script_run => sub { push(@calls, @_); return '0'; });
    $sapcontrol->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my %arguments = (instance_id => '00', webmethod => 'GoOverThere', sidadm => 'abcadm');

    is sapcontrol(%arguments), '0', 'Return correct RC';
    is $calls[0], 'sapcontrol -nr 00 -function GoOverThere', 'Execute correct command';
    $arguments{additional_args} = 'And Return Back';
    sapcontrol(%arguments);
    is $calls[1], 'sapcontrol -nr 00 -function GoOverThere And Return Back', 'Execute correct command with additional args';
    $arguments{additional_args} = '';

    $arguments{return_output} = 1;
    is sapcontrol(%arguments), 'command output', 'Return command output instead of RC';
    $arguments{return_output} = 0;

    $arguments{remote_hostname} = 'charlie';
    $arguments{sidadm_password} = 'Fr@ncis';
    sapcontrol(%arguments);
    is $calls[2], 'sapcontrol -nr 00 -host charlie -user abcadm Fr@ncis -function GoOverThere',
      'Execute correct command for remote execution';
};

subtest '[sapcontrol_process_check] Test expected failures.' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    $sapcontrol->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sapcontrol->redefine(sapcontrol => sub { return '3'; });
    my %argument_values = (
        sidadm => 'sidadm', instance_id => '00', expected_state => 'started');

    $argument_values{expected_state} = undef;
    dies_ok { sapcontrol_process_check(%argument_values) } "Expected failure with missing argument: 'expected_state'";
    $argument_values{expected_state} = 'started';

    foreach ('stoped', 'stated', 'sstopped', 'startedd', 'somethingweird', ' started ') {
        my $orig_value = $argument_values{expected_state};
        $argument_values{expected_state} = $_;
        dies_ok { sapcontrol_process_check(%argument_values) } "Fail with unsupported 'expected_state' value: \'$_'";
        $argument_values{expected_state} = $orig_value;
    }

    $sapcontrol->redefine(sapcontrol => sub { return '3' });
    $argument_values{expected_state} = 'stopped';
    dies_ok { sapcontrol_process_check(%argument_values) } 'Fail with services not stopped.';
    $sapcontrol->redefine(sapcontrol => sub { return '4' });
    $argument_values{expected_state} = 'started';
    dies_ok { sapcontrol_process_check(%argument_values) } 'Fail with services not started.';
};

subtest '[sapcontrol_process_check] Function PASS.' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    $sapcontrol->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %argument_values = (instance_id => '00', expected_state => 'started');

    $sapcontrol->redefine(sapcontrol => sub { return '4' });
    $argument_values{expected_state} = 'stopped';
    is sapcontrol_process_check(%argument_values), 'stopped', 'Pass with services being stopped (RC4)';
    $sapcontrol->redefine(sapcontrol => sub { return '3' });
    $argument_values{expected_state} = 'started';
    is sapcontrol_process_check(%argument_values), 'started', 'Pass with services being started (RC3)';
};

subtest '[get_remote_instance_number]' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    $sapcontrol->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    set_var('INSTANCE_ID', '00');
    my $sapcontrol_out = '
30.11.2023 07:15:42
GetSystemInstanceList
OK
hostname, instanceNr, httpPort, httpsPort, startPriority, features, dispstatus
sapen2er, 1, 50113, 50114, 0.5, ENQREP, GREEN
sapen2as, 0, 50013, 50014, 1, MESSAGESERVER|ENQUE, GREEN';
    $sapcontrol->redefine(sapcontrol => sub { return $sapcontrol_out });

    is get_remote_instance_number(instance_type => 'ASCS'), '00', 'Return correct ASCS instance number.';
    is get_remote_instance_number(instance_type => 'ERS'), '01', 'Return correct ERS instance number.';

    undef_vars();
};

subtest '[get_instance_type]' => sub {
    my $sapcontrol = Test::MockModule->new('sles4sap::sapcontrol', no_auto => 1);
    $sapcontrol->redefine(sapcontrol => sub { return ('INSTANCE_NAME, Attribute, ERS02') });
    is get_instance_type(local_instance_id => '00'), 'ERS', 'Return instance type: "ERS"';
};

subtest '[get_remoget_instance_typete_instance_number] Mandatory args' => sub {
    dies_ok { get_instance_type(local_instance_id => '00') }, 'Fail with missing argument "local_instance_id"';
};

done_testing;
