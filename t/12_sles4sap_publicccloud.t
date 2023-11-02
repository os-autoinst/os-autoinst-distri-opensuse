use strict;
use warnings;
use Test::MockModule;
use Test::Exception;
use Test::More;
use testapi;

use sles4sap_publiccloud;

subtest "Run 'setup_sbd_delay_publiccloud' with different values" => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { return; });
    $sles4sap_publiccloud->redefine(cloud_file_content_replace => sub { return; });
    $sles4sap_publiccloud->redefine(croak => sub { die; });
    $sles4sap_publiccloud->redefine(change_sbd_service_timeout => sub { return; });
    $sles4sap_publiccloud->redefine(sbd_delay_formula => sub { return 30; });

    my %passing_values_vs_expected = (
        '1' => '1',
        'yes' => 'yes',
        'no' => 'no',
        '0' => '0',
        '100' => '100',
        '100s' => '100');
    my @failok_values = qw(aasd 100asd 100S "" undef);

    for my $input_value (@failok_values) {
        set_var('HA_SBD_START_DELAY', $input_value);
        dies_ok { $self->setup_sbd_delay_publiccloud() } "Test expected failing 'HA_SBD_START_DELAY' value: $input_value";
    }

    for my $value (keys %passing_values_vs_expected) {
        set_var('HA_SBD_START_DELAY', $value);
        my $returned_value = $self->setup_sbd_delay_publiccloud();
        is($returned_value, $passing_values_vs_expected{$value},
            "Test 'HA_SBD_START_DELAY' passing values:\ninput_value: $value\n result: $returned_value");
    }

    set_var('HA_SBD_START_DELAY', undef);
    my $returned_delay = $self->setup_sbd_delay_publiccloud();
    is $returned_delay, 30, "Test with undefined 'HA_SBD_START_DELAY':\n Expected: 30\nGot: $returned_delay";

};

subtest '[azure_fencing_agents_playbook_args] Check Mandatory args' => sub {
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn');
    my %mandatory_args = (
        'spn_application_id' => 'LongJohnSilver',
        'spn_application_password' => 'CaptainFlint');

    for my $key (keys %mandatory_args) {
        my $original_value = $mandatory_args{$key};
        delete $mandatory_args{$key};
        dies_ok { azure_fencing_agents_playbook_args(%mandatory_args) } "Expected failure: missing mandatory arg - $key";
        $mandatory_args{$key} = $original_value;
    }
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', '');
};

subtest '[azure_fencing_agents_playbook_args] Native fencing setup (default value)' => sub {
    set_var('FENCING_MECHANISM', 'native');
    my $returned_value = azure_fencing_agents_playbook_args();
    is $returned_value, '-e azure_identity_management=msi', "Test returned value: $returned_value";
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', '');
};

subtest '[azure_fencing_agents_playbook_args] MSI setup' => sub {
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
    set_var('FENCING_MECHANISM', 'native');
    my $returned_value = azure_fencing_agents_playbook_args();
    is $returned_value, '-e azure_identity_management=msi', "Test returned value: $returned_value";
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', '');
};

subtest '[azure_fencing_agents_playbook_args] SPN setup' => sub {
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn');
    set_var('FENCING_MECHANISM', 'native');
    my %mandatory_args =
      ('spn_application_id' => 'GolDRodger', 'spn_application_password' => 'JackSparrow');

    my $expected_result = join(' ',
        '-e azure_identity_management=spn',
        "-e spn_application_id=$mandatory_args{spn_application_id}",
        "-e spn_application_password=$mandatory_args{spn_application_password}",
    );

    my $returned_value = azure_fencing_agents_playbook_args(%mandatory_args);
    is $returned_value, $expected_result, "Test returned value:\n$returned_value";

    set_var('AZURE_FENCE_AGENT_CONFIGURATION', '');
};

subtest '[list_cluster_nodes]' => sub {
    my $self = sles4sap_publiccloud->new();
    my @instances = ('Captain_hook', 'CaptainHarlock');
    $self->{instances} = \@instances;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $crm_node_server_out = "Captain_hook\nCaptainHarlock";
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            return 0 if $args{cmd} eq 'crm status';
            return $crm_node_server_out; }
    );

    my $node_list = $self->list_cluster_nodes();
    is ref($node_list), 'ARRAY', 'Func,tion returns array ref.';
    is @$node_list, @instances, 'Test expected result.';

    $sles4sap_publiccloud->redefine(run_cmd => sub { return 1; });
    dies_ok { $self->list_cluster_nodes() } 'Expected failure: missing mandatory arg';
};

subtest '[is_hana_database_offline]' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(get_hana_database_status => sub { return 0; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    set_var('SAP_SIDADM', 'SAP_SIDADMTEST');
    set_var('INSTANCE_ID', 'INSTANCE_IDTEST');
    set_var('_HANA_MASTER_PW', '1234');

    my $res = $self->is_hana_database_online();
    set_var('SAP_SIDADM', undef);
    set_var('INSTANCE_ID', undef);
    set_var('_HANA_MASTER_PW', undef);
    is $res, 0, "Hana database is offline";
};

subtest '[is_hana_database_offine with status online]' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(get_hana_database_status => sub { return 1; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    set_var('SAP_SIDADM', 'SAP_SIDADMTEST');
    set_var('INSTANCE_ID', 'INSTANCE_IDTEST');
    set_var('_HANA_MASTER_PW', '1234');

    my $res = $self->is_hana_database_online();
    set_var('SAP_SIDADM', undef);
    set_var('INSTANCE_ID', undef);
    set_var('_HANA_MASTER_PW', undef);
    is $res, 1, "Hana database is online";
};

subtest '[is_primary_node_offline]' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my $res = "";
    $sles4sap_publiccloud->redefine(run_cmd => sub { die "this system is not a system replication site" });
    $sles4sap_publiccloud->redefine(record_info => sub { return; });

    # Check if virtual machine 01 is a primary node and still belong to the system replication
    set_var('INSTANCE_SID', 'INSTANCE_SIDTEST');
    eval {
        $res = $self->is_primary_node_online();
    };
    set_var('INSTANCE_SID', undef);
    unlike($@, qr/mode:[\r\n\s]+PRIMARY/, 'System replication is offline on primary node');
};

subtest '[is_primary_node_online]' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(run_cmd => sub { return 'mode: PRIMARY'; });
    $sles4sap_publiccloud->redefine(record_info => sub { return; });
    set_var('INSTANCE_SID', 'INSTANCE_SIDTEST');

    my $res = $self->is_primary_node_online();
    set_var('INSTANCE_SID', undef);
    is $res, 1, "System replication is online on primary node";
};

done_testing;
