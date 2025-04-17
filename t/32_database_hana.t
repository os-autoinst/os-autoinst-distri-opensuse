use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use testapi;
use sles4sap::database_hana;

subtest '[hdb_stop] HDB command compilation' => sub {
    my $db_hana = Test::MockModule->new('sles4sap::database_hana', no_auto => 1);
    my @calls;
    $db_hana->redefine(assert_script_run => sub { @calls = $_[0]; return 0; });
    $db_hana->redefine(script_output => sub { return 'Dumbledore'; });
    $db_hana->redefine(sapcontrol_process_check => sub { return 0; });
    $db_hana->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    hdb_stop(instance_id => '00', switch_user => 'Albus');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /HDB/, @calls), 'Execute HDB command');
    ok((grep /stop/, @calls), 'Use "stop" function');
    ok((grep /sudo su \- Albus/, @calls), 'Run as another user');

    hdb_stop(instance_id => '00', switch_user => 'Albus', command => 'kill');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /kill \-x/, @calls), 'Use "kill" function');
};

subtest '[hdb_stop] Sapcontrol arguments' => sub {
    my $db_hana = Test::MockModule->new('sles4sap::database_hana', no_auto => 1);
    my @sapcontrol_args;
    $db_hana->redefine(assert_script_run => sub { return 0; });
    $db_hana->redefine(script_output => sub { return 'Dumbledore'; });
    $db_hana->redefine(sapcontrol_process_check => sub { @sapcontrol_args = @_; return 0; });
    $db_hana->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    hdb_stop(instance_id => 'Albus');
    note("\n  -->  " . join("\n  -->  ", @sapcontrol_args));
    ok((grep /instance_id/, @sapcontrol_args), 'Mandatory arg "instance_id"');
    ok((grep /expected_state/, @sapcontrol_args), 'Define expected state');
    ok((grep /wait_for_state/, @sapcontrol_args), 'Wait until processes are in correct state');
};

subtest '[register_replica] Command compilation' => sub {
    my $db_hana = Test::MockModule->new('sles4sap::database_hana', no_auto => 1);
    my $topology = {
        Host => {
            Hogwarts => {
                site => 'Dumbledore'
            },
            Durmstrang => {
                site => 'Karkaroff'
            }
        },
        Site => {
            Dumbledore => {
                srMode => 'FunnyGuy',
                opMode => 'VeryOP'
            },
            Karkaroff => {
                srMode => 'DeathEater',
                opMode => 'SeemsWeak'
            }
        }
    };
    my @calls;
    $db_hana->redefine(assert_script_run => sub { @calls = @_; return 0; });
    $db_hana->redefine(script_output => sub { return 'Revelio'; });
    $db_hana->redefine(calculate_hana_topology => sub { return $topology; });
    $db_hana->redefine(get_primary_node => sub { return 'Durmstrang'; });
    $db_hana->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    register_replica(instance_id => '00', target_hostname => 'Hogwarts');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /hdbnsutil/, @calls), 'Main "hdbnsutil" command');
    ok((grep /-sr_register/, @calls), '"-sr_rergister" option');
    ok((grep /--remoteHost=Durmstrang/, @calls), 'Define "--remoteHost"');
    ok((grep /--remoteInstance=00/, @calls), 'Define "--remoteInstance"');
    ok((grep /--operationMode=VeryOP/, @calls), 'Define "--operationMode"');
    ok((grep /--name=/, @calls), 'Define "--name"');

};

subtest '[get_node_roles] ' => sub {
    my $db_hana = Test::MockModule->new('sles4sap::database_hana', no_auto => 1);
    $db_hana->redefine(script_output => sub { return 'Revelio'; });
    $db_hana->redefine(calculate_hana_topology => sub { return 'Aparecium'; });
    $db_hana->redefine(get_primary_node => sub { return 'AccioPrimary'; });
    $db_hana->redefine(get_failover_node => sub { return 'AccioFailover'; });

    my %result = %{get_node_roles()};
    is $result{primary_node}, 'AccioPrimary', 'Return correct primary node in hash';
    is $result{failover_node}, 'AccioFailover', 'Return correct failover node in hash';
};

subtest '[find_hana_resource_name]' => sub {
    my $db_hana = Test::MockModule->new('sles4sap::database_hana', no_auto => 1);
    my $mock_output = '
primitive rsc_SAPHanaTopology_HDB_HDB00 ocf:suse:SAPHanaTopology \
not relevant line \
primitive rsc_SAPHana_HDB_HDB00 ocf:suse:SAPHana \
another not relevant line \
';

    my @calls;
    $db_hana->redefine(script_output => sub { @calls = @_; return $mock_output; });
    $db_hana->redefine(assert_script_run => sub { return 0; });

    my $returned_value = find_hana_resource_name();
    note("\n  -->  " . join("\n  -->  ", @calls));
    is $returned_value, 'rsc_SAPHana_HDB_HDB00', 'Check for correct value returned';

};

done_testing;
