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
use sles4sap_publiccloud;

subtest "[run_cmd] missing cmd" => sub {
    my $self = sles4sap_publiccloud->new();
    dies_ok { $self->run_cmd() } 'Expected failure: missing mandatory argument cmd';
};

subtest "[run_cmd]" => sub {
    my $self = sles4sap_publiccloud->new();

    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    my @calls;
    $mock_pc->mock('run_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'BABUUUUUUUUM' });
    $self->{my_instance} = $mock_pc;
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = $self->run_cmd(cmd => 'babum');
    note("\n  C -->  " . join("\n  -->  ", @calls));
    ok $ret eq 'BABUUUUUUUUM';
};

subtest "[sles4sap_cleanup] no argument ret 0" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(select_host_console => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $self = sles4sap_publiccloud->new();
    my $ret = $self->sles4sap_cleanup();
    ok $ret eq 0;
};

subtest "[is_hana_online]" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return <<END;
Performing Final Memory Release with 8 threads.
Finished Final Memory Release successfuly.
online: true
mode: sync
operation mode: logreplay
site id: 2
site name: site_b
is source system: false
is secondary/consumer system: true
has secondaries/consumers attached: false
is a takeover active: false
is primary suspended: false
is timetravel enabled: false
replay mode: auto
active primary site: 1
primary masters: vmhana01
Tier of site_a: 1
Tier of site_b: 2
Replication mode of site_a: primary
Replication mode of site_b: sync
Operation mode of site_a: primary
Operation mode of site_b: logreplay
Mapping: site_a -> site_b
Hint based routing site:
END
    });

    my $self = sles4sap_publiccloud->new();
    set_var('SAP_SIDADM', 'SAP_SIDADMTEST');
    my $ret = $self->is_hana_online();
    set_var('SAP_SIDADM', undef);
    ok $ret eq 1;
};

subtest "[stop_hana]" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(wait_for_sync => sub { return; });
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return; }
    );
    my $self = sles4sap_publiccloud->new();

    set_var('INSTANCE_SID', 'INSTANCE_SIDTEST');
    $self->stop_hana();
    set_var('INSTANCE_SID', undef);
    note("\n  C -->  " . join("\n  -->  ", @calls));

    ok((any { qr/HDB stop/ } @calls), 'function calls HDB stop');
};

subtest "[stop_hana] crash" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(wait_for_sync => sub { return; });

    my $self = sles4sap_publiccloud->new();
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    my @calls;
    $mock_pc->mock('run_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'BABUUUUUUUUM' });
    $self->{my_instance} = $mock_pc;

    $self->stop_hana(method => 'crash');
    note("\n  C -->  " . join("\n  -->  ", @calls));
    ok((any { qr/echo b.*sysrq-trigger/ } @calls), 'function calls HDB stop');
};

subtest "[setup_sbd_delay_publiccloud]" => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { return; });
    $sles4sap_publiccloud->redefine(sbd_delay_formula => sub { return 30; });
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'BABUUUUUUUUM'; }
    );
    my $returned_delay = $self->setup_sbd_delay_publiccloud();
    note("\n  C -->  " . join("\n  -->  ", @calls));
    ok((any { qr/echo.*>>.*sbd_delay_start\.conf/ } @calls), 'write sbd_delay_start.conf');
};

subtest "[setup_sbd_delay_publiccloud] with different values" => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { return; });
    $sles4sap_publiccloud->redefine(cloud_file_content_replace => sub { return; });
    $sles4sap_publiccloud->redefine(croak => sub { die; });
    $sles4sap_publiccloud->redefine(change_sbd_service_timeout => sub { return; });
    $sles4sap_publiccloud->redefine(sbd_delay_formula => sub { return 30; });

    my %passing_values_vs_expected = (
        '1' => '1',
        yes => 'yes',
        no => 'no',
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
    # Create a list of mandatory arguments.
    my %mandatory_args = (
        'spn_application_id' => 'LongJohnSilver',
        'spn_application_password' => 'CaptainFlint');
    # Notice like they are mandatory only if fencing is SPN
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn');

    # For each mandatory args, try to call the sub
    # without it and expect an exception.
    for my $key (keys %mandatory_args) {
        my $original_value = $mandatory_args{$key};
        delete $mandatory_args{$key};
        dies_ok { azure_fencing_agents_playbook_args(%mandatory_args) } "Expected failure: missing mandatory arg - $key";
        $mandatory_args{$key} = $original_value;
    }
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', undef);
};


subtest '[azure_fencing_agents_playbook_args] Native fencing setup (default value)' => sub {
    my $returned_value = azure_fencing_agents_playbook_args();
    is $returned_value, '-e azure_identity_management=msi', "Default to MSI if called without arguments and AZURE_FENCE_AGENT_CONFIGURATION is not specified";
};


subtest '[azure_fencing_agents_playbook_args] MSI setup' => sub {
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
    my $returned_value = azure_fencing_agents_playbook_args();
    is $returned_value, '-e azure_identity_management=msi', "Default to MSI if called without arguments and AZURE_FENCE_AGENT_CONFIGURATION is 'msi'";
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', undef);
};


subtest '[azure_fencing_agents_playbook_args] SPN setup' => sub {
    my %mandatory_args =
      ('spn_application_id' => 'GolDRodger', 'spn_application_password' => 'JackSparrow');

    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'spn');
    my $returned_value = azure_fencing_agents_playbook_args(%mandatory_args);
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', undef);

    my @expected_results = (
        '-e azure_identity_management=spn',
        "-e spn_application_id=$mandatory_args{spn_application_id}",
        "-e spn_application_password=$mandatory_args{spn_application_password}",
    );
    foreach (@expected_results) {
        like($returned_value, "/$_/", "$_ is part of the playbooks options");
    }
};


subtest '[list_cluster_nodes]' => sub {
    my $self = sles4sap_publiccloud->new();
    my @instances = ('Captain_hook', 'CaptainHarlock');
    $self->{instances} = \@instances;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 0 if $args{cmd} eq 'crm status';
            return "Captain_hook\nCaptainHarlock"; }
    );

    my $node_list = $self->list_cluster_nodes();
    note("\n  C -->  " . join("\n  -->  ", @calls));

    is ref($node_list), 'ARRAY', 'Func,tion returns array ref.';
    is @$node_list, @instances, 'Test expected result.';
};


subtest '[list_cluster_nodes] failure' => sub {
    my $self = sles4sap_publiccloud->new();
    my @instances = ('Captain_hook', 'CaptainHarlock');
    $self->{instances} = \@instances;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 1; }
    );

    dies_ok { $self->list_cluster_nodes() } 'Expected failure: missing mandatory arg';
    note("\n  C -->  " . join("\n  -->  ", @calls));
};


subtest '[is_hana_database_online]' => sub {
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


subtest '[is_hana_database_online] with status online' => sub {
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


subtest '[is_primary_node_online]' => sub {
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

subtest '[get_hana_topology]' => sub {
    my @calls;
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %test_topology = (
        vmhanaAAAAA => {
            vhost => 'vmhanaAAAAA'},
        vmhanaBBBBB => {
            vhost => 'vmhanaBBBBB'}
    );
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%test_topology; });
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });

    my $topology = $self->get_hana_topology();

    note("\n  C -->  " . join("\n  -->  ", @calls));

    ok((keys %$topology eq 2), "Two nodes returned by calculate_hana_topology");
    # how to access one inner value in one shot
    ok((%$topology{vmhanaAAAAA}->{vhost} eq 'vmhanaAAAAA'), 'vhost of vmhanaAAAAA is vmhanaAAAAA');
    ok((any { qr/SAPHanaSR-showAttr --format=script/ } @calls), 'function calls SAPHanaSR-showAttr');
};


subtest '[get_hana_topology] bad output' => sub {
    my $self = sles4sap_publiccloud->new();
    my @calls;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %empty_topology = ();
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%empty_topology; });

    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });

    my $topology = $self->get_hana_topology();

    note("\n  C -->  " . join("\n  -->  ", @calls));
    ok keys %$topology eq 0;
};


subtest '[check_takeover]' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my @calls;
    my %test_topology = (
        vmhana01 => {
            sync_state => 'PRIM',
            vhost => 'vmhana01',
        },
        vmhana02 => {
            sync_state => 'SOK',
            vhost => 'vmhana02',
        }
    );
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%test_topology; });
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Note how it pass at the first iteration because:
    #  - two nodes in the output are named vmhana01 and vmhana02
    #  - none has the name of "current node" that is Yondu
    #  - at least one of them with name different from Yondu is in state PRIM
    ok $self->check_takeover();

    note("\n  C -->  " . join("\n  -->  ", @calls));
};


subtest '[check_takeover] fail in showAttr' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my @calls;
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %empty_topology = ();
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%empty_topology; });

    dies_ok { $self->check_takeover() } "check_takeover fails if SAPHanaSR-showAttr keep give bad respose";

    note("\n  C -->  " . join("\n  -->  ", @calls));
};


subtest '[check_takeover] missing fields in SAPHanaSR-showAttr' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'vmhana01';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my @calls;
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });
    my $showAttr;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return $showAttr;
    });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    $showAttr = <<END;
Hosts/vmhana01/vhost="vmhana01"
Hosts/vmhana01/sync_state="SOK"
Hosts/vmhana02/vhost="vmhana02"
END
    dies_ok { $self->check_takeover() } "check_takeover fails if sync_state is missing in SAPHanaSR-showAttr output";
    note("\n  C -->  " . join("\n  -->  ", @calls));
    @calls = ();

    $showAttr = <<END;
Hosts/vmhana01/vhost="vmhana01"
Hosts/vmhana01/sync_state="SOK"
Hosts/vmhana02/sync_state="SOK"
END
    dies_ok { $self->check_takeover() } "check_takeover fails if vhost is missing in SAPHanaSR-showAttr output";
    note("\n  -->  " . join("\n  -->  ", @calls));
};


subtest '[check_takeover] fail if DB online' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my @calls;
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 1 });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });

    dies_ok { $self->check_takeover() } "Takeover failed if sles4sap_publiccloud return 1";
};


subtest '[check_takeover] fail if primary online' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });
    my @calls;
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0 });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 1 });

    dies_ok { $self->check_takeover() } "Takeover failed if is_primary_node_online return 1";
};


subtest '[create_playbook_section_list]' => sub {
    set_var('SCC_REGCODE_SLES4SAP', 'Magellano');
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list();
    set_var('SCC_REGCODE_SLES4SAP', undef);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*reg_code=Magellano/ } @$ansible_playbooks), 'registration playbook is called with reg code from SCC_REGCODE_SLES4SAP');
    ok((any { /.*sap-hana-preconfigure\.yaml.*use_sapconf=Colombo/ } @$ansible_playbooks), 'pre-cluster playbook is called with use_sapconf from USE_SAPCONF');
};


subtest '[create_playbook_section_list] ha_enabled => 0' => sub {
    set_var('SCC_REGCODE_SLES4SAP', 'Magellano');
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(ha_enabled => 0);
    set_var('SCC_REGCODE_SLES4SAP', undef);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
    ok((any { /.*fully-patch-system\.yaml.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
    ok(scalar @$ansible_playbooks == 2, 'Only two playbooks in ha_enabled => 0 mode');
};


subtest '[create_playbook_section_list] fencing => native in azure' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('SCC_REGCODE_SLES4SAP', 'Magellano');
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(fencing => 'native');
    set_var('SCC_REGCODE_SLES4SAP', undef);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((none { /.*cluster_sbd_prep\.yaml.*/ } @$ansible_playbooks), 'cluster_sbd_prep playbook is not called when fencing => native');
    ok((any { /.*sap-hana-cluster\.yaml.*azure_identity_management=.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
};


subtest '[create_playbook_section_list] registration => noreg' => sub {
    set_var('SCC_REGCODE_SLES4SAP', 'Magellano');
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(registration => 'noreg');
    set_var('SCC_REGCODE_SLES4SAP', undef);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((none { /.*registration\.yaml.*/ } @$ansible_playbooks), 'registration playbook is not called when registration => noreg');
};


subtest '[create_playbook_section_list] registration => suseconnect' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('SCC_REGCODE_SLES4SAP', 'Magellano');
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(registration => 'suseconnect');
    set_var('SCC_REGCODE_SLES4SAP', undef);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*use_suseconnect=true.*/ } @$ansible_playbooks), 'registration playbook is called with use_suseconnect=true when registration => suseconnect');
};


subtest '[enable_replication]' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'vmhana01';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0; });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 0; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %test_topology = (
        vmhana01 => {
            vhost => 'vmhana01',
            remoteHost => 'vmhana02',
            srmode => 'LeeAdama',
            op_mode => 'ZakAdama',
        },
        vmhana02 => {
            vhost => 'vmhana02',
            remoteHost => 'vmhana01',
            srmode => 'LeeAdama',
            op_mode => 'ZakAdama',
        }
    );
    $sles4sap_publiccloud->redefine(get_hana_topology => sub { return \%test_topology; });
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 1; }
    );

    set_var('SAP_SIDADM', 'YONDUR');

    $self->enable_replication(site_name => 'WilliamAdama');

    set_var('SAP_SIDADM', undef);

    note("\n  C -->  " . join("\n  -->  ", @calls));
    ok((any { qr/hdbnsutil -sr_register/ } @calls), 'hdbnsutil cmd correctly called');
    ok((any { qr/-name WilliamAdama/ } @calls), 'hdbnsutil cmd has right site name');
};

subtest '[get_hana_site_names] default values' => sub {
    my @res = get_hana_site_names();
    ok(($res[0] eq 'site_a'), "Default value for the primary site is site_a");
    ok(($res[1] eq 'site_b'), "Default value for the secondary site is site_b");
};

subtest '[get_hana_site_names] values from settings' => sub {
    set_var('HANA_PRIMARY_SITE', 'MarcoPolo');
    set_var('HANA_SECONDARY_SITE', 'ZhengHe');
    my @res = get_hana_site_names();
    set_var('HANA_PRIMARY_SITE', undef);
    set_var('HANA_SECONDARY_SITE', undef);
    ok(($res[0] eq 'MarcoPolo'), "Value for the primary site is from setting");
    ok(($res[1] eq 'ZhengHe'), "Value for the secondary site is from setting");
};

subtest '[wait_for_zypper] zypper unlocked at first try' => sub {
    my $self = sles4sap_publiccloud->new();
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $instance = publiccloud::instance->new();
    $pc_instance->redefine(run_ssh_command => sub { return 0; });

    lives_ok { $self->wait_for_zypper(instance => $instance) } 'Zypper was not locked, command succeeded without retries';
};

subtest '[wait_for_zypper] zypper fails at first try with non 7 rc' => sub {
    my $self = sles4sap_publiccloud->new();
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $instance = publiccloud::instance->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud');
    $sles4sap_publiccloud->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO -->', @_));
    });
    $pc_instance->redefine(run_ssh_command => sub { return 1; });

    lives_ok { $self->wait_for_zypper(instance => $instance) } 'Zypper command failed with a non-locking issue and did not retry';
};

subtest '[wait_for_zypper] zypper fails at first try with 7 rc but pass at second retry' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud');
    my $self = sles4sap_publiccloud->new();
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $instance = publiccloud::instance->new();
    my $attempt = 0;
    my @record_infos;

    $pc_instance->redefine(run_ssh_command => sub {
            return $attempt++ ? 0 : 7;    # return 7 on first call, 0 on second
    });
    $sles4sap_publiccloud->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO -->', @_));
    });

    lives_ok { $self->wait_for_zypper(instance => $instance) } 'Zypper was locked initially but succeeded on retry';
};

subtest '[wait_for_zypper] zypper fails always with 7 rc' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud');
    my $pc_instance = Test::MockModule->new('publiccloud::instance');
    my $instance = publiccloud::instance->new();
    my @record_infos;

    $pc_instance->redefine(run_ssh_command => sub { return 7; });
    $sles4sap_publiccloud->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO -->', @_));
    });

    dies_ok { $self->wait_for_zypper(instance => $instance, max_retries => 3) } 'Zypper remained locked after max retries';
};

subtest '[wait_for_idle] command passes at first try' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud');
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub { my ($self, %args) = @_; push @calls, $args{cmd}; return 0; });
    $sles4sap_publiccloud->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO -->', @_));
    });

    lives_ok { $self->wait_for_idle() } 'Cluster was idle, command succeeded without retries';

    my $count_cs_wait_for_idle = sum(map { /cs_wait_for_idle/ ? 1 : 0 } @calls);
    ok($count_cs_wait_for_idle == 1, "'cs_wait_for_idle' appears exactly once");
};

subtest '[wait_for_idle] command fails with rc 124, passes at second try' => sub {
    my $self = sles4sap_publiccloud->new();
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud');
    my $failed = 0;
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            if ($failed) {
                return 0;
            }
            else {
                return 124;
                $failed = 1;
            }
    });
    $sles4sap_publiccloud->redefine(record_info => sub {
            note(join(' ', 'RECORD_INFO -->', @_));
    });

    lives_ok { $self->wait_for_idle() } 'Cluster was not idle the first time but succeeded the second';
    ok((any { qr/cs_clusterstate/ } @calls), 'function calls cs_clusterstate');
    ok((any { qr/crm_mon -r -R -n -N -1/ } @calls), 'function calls crm_mon -r -R -n -N -1');
    ok((any { qr/SAPHanaSR-showAttr/ } @calls), 'function calls SAPHanaSR-showAttr');
};

done_testing;
