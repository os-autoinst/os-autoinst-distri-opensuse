use strict;
use warnings;
use Test::MockModule;
use Test::MockObject;
use Test::Exception;
use Test::More;
use Test::Mock::Time;
use testapi;
use List::Util qw(any none sum);
use Mojo::JSON qw(encode_json decode_json);
use Data::Dumper;

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
    note("\n  C -->  " . join("\n  C -->  ", @calls));
    ok $ret eq 'BABUUUUUUUUM';
};

subtest "[sles4sap_cleanup] no args and all pass" => sub {
    # sles4sap_cleanup is called with no args
    # it result in only to perform terraform destroy
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(select_host_console => sub { return; });
    my $unlock_terminal = 0;
    $sles4sap_publiccloud->redefine(type_string => sub { $unlock_terminal = 1; });
    $sles4sap_publiccloud->redefine(qesap_upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_cluster_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_supportconfig_logs => sub { return; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $sles4sap_publiccloud->redefine(qesap_execute => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return (0, 0); });
    my $self = sles4sap_publiccloud->new();
    set_var('PUBLIC_CLOUD_PROVIDER', 'FRUTTOLO');

    my $ret = $self->sles4sap_cleanup();

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(any { /terraform/ } @calls, "Check if terraform is called");
    ok(any { /ansible/ } @calls, "Check that ansible is not called");
    ok($ret eq 0, "Expected return 0 ret:$ret");
    ok($unlock_terminal eq 1, "ETX called at the beginning to eventually unlock the terminal");
};

subtest "[sles4sap_cleanup] ansible and all pass" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(select_host_console => sub { return; });
    $sles4sap_publiccloud->redefine(type_string => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_cluster_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_supportconfig_logs => sub { return; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $sles4sap_publiccloud->redefine(qesap_execute => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return (0, 0); });
    my $self = sles4sap_publiccloud->new();
    set_var('PUBLIC_CLOUD_PROVIDER', 'FRUTTOLO');

    my $ret = $self->sles4sap_cleanup(ansible_present => 1);

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(any { /terraform/ } @calls, "Check if terraform is called");
    ok(any { /ansible/ } @calls, "Check if ansible is called");
    ok($ret eq 0, "Expected return 0 ret:$ret");
};

subtest "[sles4sap_cleanup] terraform to be called even if ansible fails" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(select_host_console => sub { return; });
    $sles4sap_publiccloud->redefine(type_string => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(upload_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_cluster_logs => sub { return; });
    $sles4sap_publiccloud->redefine(qesap_supportconfig_logs => sub { return; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my @calls;
    $sles4sap_publiccloud->redefine(qesap_execute => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            if ($args{cmd} =~ /ansible/) {
                return (1, 0);
            } else {
                return (0, 0);
            }
    });
    my $self = sles4sap_publiccloud->new();
    set_var('PUBLIC_CLOUD_PROVIDER', 'FRUTTOLO');

    my $ret = $self->sles4sap_cleanup(ansible_present => 1);

    set_var('PUBLIC_CLOUD_PROVIDER', undef);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(any { /terraform/ } @calls, "Check if terraform is called");
    ok(any { /ansible/ } @calls, "Check if ansible is called");
    ok($ret eq 1, "Expected return 1 ret:$ret");
};

subtest "[sles4sap_cleanup] no need to clean" => sub {
    # No args result in only terraform destroy to be called
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $self = sles4sap_publiccloud->new();
    my $ret = $self->sles4sap_cleanup(cleanup_called => 1);

    ok($ret eq 0, "Expected return 0 ret:$ret");
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
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    $self->{my_instance} = $mock_pc;

    set_var('INSTANCE_SID', 'INSTANCE_SIDTEST');
    $self->stop_hana();
    set_var('INSTANCE_SID', undef);
    note("\n  C -->  " . join("\n  C -->  ", @calls));

    ok((any { qr/HDB stop/ } @calls), 'function calls HDB stop');
};

subtest "[stop_hana] crash" => sub {
    my @calls;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(type_string => sub { note(join(' ', 'TYPED -->', @_)); });
    $sles4sap_publiccloud->redefine(wait_for_sync => sub { return; });
    $sles4sap_publiccloud->redefine(wait_hana_node_up => sub { return; });
    $sles4sap_publiccloud->redefine(serial_term_prompt => sub { return '# '; });
    $sles4sap_publiccloud->redefine(wait_serial => sub { return; });
    $sles4sap_publiccloud->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    my $self = sles4sap_publiccloud->new();
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    $mock_pc->mock('run_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'BABUUUUUUUUM' });
    $mock_pc->mock('ssh_opts', sub { return '-i .ssh/id_rsa'; });
    $self->{my_instance} = $mock_pc;
    $self->{my_instance}->{public_ip} = '1.2.3.4';

    $self->stop_hana(method => 'crash');
    note("\n  C -->  " . join("\n  C -->  ", @calls));
    ok((any { qr/echo b.*sysrq-trigger/ } @calls), 'function calls HDB stop');
};

subtest "[stop_hana] crash wait_hana_node_up running" => sub {
    # simulate system that, after the crash, immediately
    # return 'running' in the polling loop within wait_hana_node_up
    my @calls;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(type_string => sub { note(join(' ', 'TYPED -->', @_)); });
    $sles4sap_publiccloud->redefine(wait_for_sync => sub { return; });
    $sles4sap_publiccloud->redefine(serial_term_prompt => sub { return '# '; });
    $sles4sap_publiccloud->redefine(wait_serial => sub { return; });
    $sles4sap_publiccloud->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    my $self = sles4sap_publiccloud->new();
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    $mock_pc->mock('run_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'running' if ($args{cmd} =~ /is-system-running/);
            return 'BABUUUUUUUUM' });
    $mock_pc->mock('ssh_opts', sub { return '-i .ssh/id_rsa'; });
    $self->{my_instance} = $mock_pc;
    $self->{my_instance}->{public_ip} = '1.2.3.4';

    $self->stop_hana(method => 'crash');
    note("\n  C -->  " . join("\n  C -->  ", @calls));
    # Not very important test as we are checking the same within the run_ssh_command mock
    ok((any { qr/systemctl is-system-running/ } @calls), 'function calls systemctl at least one');
};

subtest "[stop_hana] crash wait_hana_node_up degradated" => sub {
    # simulate system that, after the crash,
    # never return 'running' in the polling loop within wait_hana_node_up
    my @calls;
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(type_string => sub { note(join(' ', 'TYPED -->', @_)); });
    $sles4sap_publiccloud->redefine(wait_for_sync => sub { return; });
    $sles4sap_publiccloud->redefine(serial_term_prompt => sub { return '# '; });
    $sles4sap_publiccloud->redefine(wait_serial => sub { return; });
    $sles4sap_publiccloud->redefine(script_run => sub { push @calls, $_[0]; return 1; });

    my $self = sles4sap_publiccloud->new();
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    $mock_pc->mock('run_ssh_command', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return 'degradated' if ($args{cmd} =~ /is-system-running/);
            return 'BABUUUUUUUUM' });
    $mock_pc->mock('ssh_opts', sub { return '-i .ssh/id_rsa'; });
    $self->{my_instance} = $mock_pc;
    $self->{my_instance}->{public_ip} = '1.2.3.4';

    dies_ok { $self->stop_hana(method => 'crash') } 'Test expected to die within wait_hana_node_up';
    note("\n  C -->  " . join("\n  C -->  ", @calls));
    ok((any { qr/systemctl --failed/ } @calls), 'function calls systemctl --failed to figure out which service is failed');
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
    note("\n  C -->  " . join("\n  C -->  ", @calls));
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
        'fence_type' => 'LieutenantWilliamBligh,',
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


subtest '[azure_fencing_agents_playbook_args] Invalid fencing type' => sub {
    dies_ok { azure_fencing_agents_playbook_args(fence_type => 'Bounty') };
};


subtest '[azure_fencing_agents_playbook_args] MSI setup' => sub {
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', 'msi');
    my $returned_value = azure_fencing_agents_playbook_args(fence_type => 'msi');
    is $returned_value, '-e azure_identity_management=msi', "Default to MSI if called without arguments and AZURE_FENCE_AGENT_CONFIGURATION is 'msi'";
    set_var('AZURE_FENCE_AGENT_CONFIGURATION', undef);
};


subtest '[azure_fencing_agents_playbook_args] SPN setup' => sub {
    my %mandatory_args =
      ('fence_type' => 'spn',
        'spn_application_id' => 'GoldRodger',
        'spn_application_password' => 'JackSparrow');

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
    note("\n  C -->  " . join("\n  C -->  ", @calls));

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
    note("\n  C -->  " . join("\n  C -->  ", @calls));
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
        Host => {
            vmhanaBBBBB => {
                vhost => 'vmhanaBBBBB',
                site => 'site_b'
            },
            vmhanaAAAAA => {
                site => 'site_a',
                vhost => 'vmhanaAAAAA',
            }
        },
        Site => {
            site_b => {
                lss => '4',
                mns => 'vmhanaAAAAA',
                srPoll => 'SOK',
            },
            site_a => {
                lss => '4',
                mns => 'vmhanaBBBBB',
                srPoll => 'PRIM',
            }
        }
    );
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%test_topology; });
    $sles4sap_publiccloud->redefine(run_cmd_retry => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });

    my $topology = $self->get_hana_topology();

    note("\n  C -->  " . join("\n  C -->  ", @calls));

    ok((keys %{$topology->{Host}} eq 2 && %{$topology->{Site}} eq 2), 'Two hosts and two sites returned by calculate_hana_topology');
    # how to access one inner value in one shot
    ok(($topology->{Host}->{vmhanaAAAAA}->{vhost} eq 'vmhanaAAAAA'), 'vhost of vmhanaAAAAA is vmhanaAAAAA');
    ok((any { qr/SAPHanaSR-showAttr --format=script/ } @calls), 'function calls SAPHanaSR-showAttr with --format=script');
};

subtest '[get_hana_topology_angi' => sub {
    my @calls;
    my $self = sles4sap_publiccloud->new();
    set_var('USE_SAP_HANA_SR_ANGI', 'true');
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %test_topology = (
        Host => {
            vmhanaBBBBB => {
                vhost => 'vmhanaBBBBB',
                site => 'site_b'
            },
            vmhanaAAAAA => {
                site => 'site_a',
                vhost => 'vmhanaAAAAA',
            }
        },
        Site => {
            site_b => {
                lss => '4',
                mns => 'vmhanaAAAAA',
                srPoll => 'SOK',
            },
            site_a => {
                lss => '4',
                mns => 'vmhanaBBBBB',
                srPoll => 'PRIM',
            }
        }
    );
    $sles4sap_publiccloud->redefine(calculate_hana_topology => sub { return \%test_topology; });
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return "Output does no matter as calculate_hana_topology is redefined.";
    });
    $sles4sap_publiccloud->redefine(wait_for_idle => sub { return; });
    my $topology = $self->get_hana_topology();
    note("\n  C -->  " . join("\n  C -->  ", @calls));
    set_var('USE_SAP_HANA_SR_ANGI', undef);
    # how to access one inner value in one shot
    ok((any { qr/SAPHanaSR-showAttr --format=json/ } @calls), 'function calls SAPHanaSR-showAttr with JSON format');
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

    note("\n  C -->  " . join("\n  C -->  ", @calls));
    ok keys %$topology eq 0;
};


subtest '[check_takeover]' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'Yondu';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    my @calls;
    my %test_topology = (
        Host => {
            vmhana02 => {
                vhost => 'vmhana02',
                site => 'site_b'
            },
            vmhana01 => {
                site => 'site_a',
                vhost => 'vmhana01',
            }
        },
        Site => {
            site_b => {
                lss => '4',
                mns => 'vmhana02',
                srPoll => 'SOK',
            },
            site_a => {
                lss => '4',
                mns => 'vmhana01',
                srPoll => 'PRIM',
            }
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

    note("\n  C -->  " . join("\n  C -->  ", @calls));
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

    note("\n  C -->  " . join("\n  C -->  ", @calls));
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
    note("\n  C -->  " . join("\n  C -->  ", @calls));
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
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list();
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*/ } @$ansible_playbooks), 'registration playbook is called');
    ok((any { /.*sap-hana-preconfigure\.yaml.*use_sapconf=Colombo/ } @$ansible_playbooks), 'pre-cluster playbook is called with use_sapconf from USE_SAPCONF');
};


subtest '[create_playbook_section_list] scc_code' => sub {
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(scc_code => 'Magellano');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*reg_code=Magellano/ } @$ansible_playbooks), 'registration playbook is called with reg code from scc_code');
    ok((any { /.*sap-hana-preconfigure\.yaml.*use_sapconf=Colombo/ } @$ansible_playbooks), 'pre-cluster playbook is called with use_sapconf from USE_SAPCONF');
};


subtest '[create_playbook_section_list] ltss' => sub {
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(ltss => 'XuFu,Jofuku');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*sles_modules=.*key.*XuFu.*value.*Jofuku/ } @$ansible_playbooks), 'registration playbook is called with additional reg codes');
};


subtest '[create_playbook_section_list] ha_enabled => 0' => sub {
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(ha_enabled => 0);
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*registration\.yaml.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
    ok((any { /.*fully-patch-system\.yaml.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
    ok(scalar @$ansible_playbooks == 2, 'Only two playbooks in ha_enabled => 0 mode');
};


subtest '[create_playbook_section_list] fencing => azure native msi' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(fencing => 'native', fence_type => 'msi');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((none { /.*cluster_sbd_prep\.yaml.*/ } @$ansible_playbooks), 'cluster_sbd_prep playbook is not called when fencing => native');
    ok((any { /.*sap-hana-cluster\.yaml.*azure_identity_management=.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
};


subtest '[create_playbook_section_list] fencing => azure native spn' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(fencing => 'native', fence_type => 'spn', spn_application_id => '123', spn_application_password => 'abc');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((none { /.*cluster_sbd_prep\.yaml.*/ } @$ansible_playbooks), 'cluster_sbd_prep playbook is not called when fencing => native');
    ok((any { /.*sap-hana-cluster\.yaml.*azure_identity_management=.*/ } @$ansible_playbooks), 'registration playbook is called when ha_enabled => 0');
};


subtest '[create_playbook_section_list] registration => noreg' => sub {
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(registration => 'noreg');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((none { /.*registration\.yaml.*/ } @$ansible_playbooks), 'registration playbook is not called when registration => noreg');
};


subtest '[create_playbook_section_list] registration => suseconnect' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(registration => 'suseconnect');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*use_suseconnect=true.*/ } @$ansible_playbooks), 'registration playbook is called with use_suseconnect=true when registration => suseconnect');
};


subtest '[create_playbook_section_list] ptf' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_azure => sub { return 1 });
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(
        ptf_files => 'Marcantonio Colonna',
        ptf_token => 'Seb4sti4n0Ven1er',
        ptf_container => 'VettorPisani',
        ptf_account => 'LorenzoMarcello');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /ptf_installation\.yaml.*/ } @$ansible_playbooks), 'ptf_installation playbook');
};


subtest '[create_playbook_section_list] IBSm' => sub {
    set_var('USE_SAPCONF', 'Colombo');
    my $ansible_playbooks = create_playbook_section_list(
        ibsm_ip => 'Giovanni',
        download_hostname => 'Petronio',
        repos => 'Russo');
    set_var('USE_SAPCONF', undef);
    note("\n  -->  " . join("\n  -->  ", @$ansible_playbooks));
    ok((any { /.*ibsm\.yaml.*/ } @$ansible_playbooks), 'IBSm playbook is called');
};


subtest '[enable_replication]' => sub {
    my $self = sles4sap_publiccloud->new();
    $self->{my_instance}->{instance_id} = 'vmhana01';
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(is_hana_database_online => sub { return 0; });
    $sles4sap_publiccloud->redefine(is_primary_node_online => sub { return 0; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my %test_topology = (
        Resource => {
            msl_SAPHana_HA1_HDB00 => {
                'is-managed' => '',
                maintenance => 'false'
            },
            'rsc_ip_HA1' => {
                maintenance => 'false',
                'is-managed' => ''
            }
        },
        Host => {
            vmhana01 => {
                vhost => 'vmhana01',
                site => 'WilliamAdama'
            },
            vmhana02 => {
                site => 'site_b',
                vhost => 'vmhana02',
            }
        },
        Site => {
            WilliamAdama => {
                lss => '4',
                srMode => 'LeeAdama',
                opMode => 'ZakAdama',
                mns => 'vmhana01',
                srPoll => 'SOK',
            },
            site_b => {
                lss => '4',
                srMode => 'LeeAdama',
                opMode => 'ZakAdama',
                mns => 'vmhana02',
                srPoll => 'PRIM',
            }
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

    note("\n  C -->  " . join("\n  C -->  ", @calls));
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

subtest '[wait_for_sync] all pass' => sub {
    # SAPHanaSR-showAttr return the same for N times in a row
    #
    # $ SAPHanaSR-showAttr
    #
    # Global cib-time                 maintenance
    # --------------------------------------------
    # global Thu Apr  1 00:01:02 2024 false
    #
    # Resource              maintenance
    # ----------------------------------
    # msl_SAPHanaCtl_HQ0_HA000 false
    #
    # Sites  b
    # -----------
    # site_b SOK
    #
    # Hosts    clone_state lpa_ha0_lpt node_state op_mode   remoteHost roles                            score site   srah srmode sync_state version     vhost
   # -----------------------------------------------------------------------------------------------------------------------------------------------------------
    # vmhana01 PROMOTED    1712205541  online     logreplay vmhana02   4:P:master1:master:worker:master 150   site_a -    sync   PRIM       1.02.03.04 vmhana01
    # vmhana02 DEMOTED     30          online     logreplay vmhana01   4:S:master1:master:worker:master 100   site_b -    sync   SOK        1.02.03.04 vmhana02
    #
    #
    #  ... or to be more precise the tested lib function will use the `--format=script`
    #
    #
    # $  SAPHanaSR-showAttr --format=script'
    #
    # Global/global/cib-time="Thu Apr  1 00:01:02 2024"
    # Global/global/maintenance="false"
    # Resource/msl_SAPHanaCtl_HQ0_HA000/maintenance="false"
    # Sites/site_b/b="SOK"
    # Hosts/vmhana01/clone_state="PROMOTED"
    # Hosts/vmhana01/lpa_ha0_lpt="123456789"
    # Hosts/vmhana01/node_state="online"
    # Hosts/vmhana01/op_mode="logreplay"
    # Hosts/vmhana01/remoteHost="vmhana02"
    # Hosts/vmhana01/roles="1:P:master1::worker:"
    # Hosts/vmhana01/score="150"
    # Hosts/vmhana01/site="site_a"
    # Hosts/vmhana01/srah="-"
    # Hosts/vmhana01/srmode="sync"
    # Hosts/vmhana01/sync_state="PRIM"
    # Hosts/vmhana01/version="1.02.03.04"
    # Hosts/vmhana01/vhost="vmhana01"
    # Hosts/vmhana02/clone_state="DEMOTED"
    # Hosts/vmhana02/lpa_ha0_lpt="30"
    # Hosts/vmhana02/node_state="online"
    # Hosts/vmhana02/op_mode="logreplay"
    # Hosts/vmhana02/remoteHost="vmhana01"
    # Hosts/vmhana02/roles="4:S:master1:master:worker:master"
    # Hosts/vmhana02/score="100"
    # Hosts/vmhana02/site="site_b"
    # Hosts/vmhana02/srah="-"
    # Hosts/vmhana02/srmode="sync"
    # Hosts/vmhana02/sync_state="SOK"
    # Hosts/vmhana02/version="1.02.03.04"
    # Hosts/vmhana02/vhost="vmhana02"

    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $stability_counter = 0;
    $sles4sap_publiccloud->redefine(pacemaker_version => sub { return '1.2.3'; });
    # return of get_hana_topology does no matter so much as we stub the check_hana_topology
    $sles4sap_publiccloud->redefine(get_hana_topology => sub { return; });
    $sles4sap_publiccloud->redefine(check_hana_topology => sub { $stability_counter++; return 1; });
    my $self = sles4sap_publiccloud->new();
    $self->wait_for_sync();
    ok($stability_counter >= 5, "stability_counter : $stability_counter should be greater or equal than 5");
};

subtest '[wait_for_sync] never ok' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $stability_counter = 0;
    $sles4sap_publiccloud->redefine(pacemaker_version => sub { return '1.2.3'; });
    # return of get_hana_topology does no matter so much as we stub the check_hana_topology
    $sles4sap_publiccloud->redefine(get_hana_topology => sub { return; });
    $sles4sap_publiccloud->redefine(check_hana_topology => sub { $stability_counter++; return 0; });
    $sles4sap_publiccloud->redefine(run_cmd => sub { return "Marko Ramius"; });
    my $self = sles4sap_publiccloud->new();
    dies_ok { $self->wait_for_sync() };
};

subtest '[wait_for_sync] one not ok reset the counter' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $stability_counter = 0;
    # return of get_hana_topology does no matter so much as we stub the check_hana_topology
    $sles4sap_publiccloud->redefine(get_hana_topology => sub { return; });
    $sles4sap_publiccloud->redefine(pacemaker_version => sub { return '1.2.3'; });
    # The trick here is to return a single cluster failure at run 4, the internal score variable in
    # tested code will start counting back from zero
    # so in total the tested code should look 4 + 5 = 9 times.
    $sles4sap_publiccloud->redefine(check_hana_topology => sub { $stability_counter++; return $stability_counter == 4 ? 0 : 1; });
    my $self = sles4sap_publiccloud->new();
    $self->wait_for_sync();
    ok($stability_counter >= 9, "stability_counter : $stability_counter should be more than 9.");
};

subtest '[wait_for_sync] all pass with Pacemaker >= 2.1.7' => sub {
    # SAPHanaSR-showAttr no more return 'online' but an integer
    #
    # $ SAPHanaSR-showAttr
    #
    # Global cib-time                 maintenance
    # --------------------------------------------
    # global Thu Apr  1 00:01:02 2024 false
    #
    # Resource              maintenance
    # ----------------------------------
    # msl_SAPHanaCtl_HQ0_HA000 false
    #
    # Sites  b
    # -----------
    # site_b SOK
    #
    # Hosts    clone_state lpa_ha0_lpt node_state op_mode   remoteHost roles                            score site   srah srmode sync_state version     vhost
   # -----------------------------------------------------------------------------------------------------------------------------------------------------------
 # vmhana01 PROMOTED    1712205541  1712205541     logreplay vmhana02   4:P:master1:master:worker:master 150   site_a -    sync   PRIM       1.02.03.04 vmhana01
 # vmhana02 DEMOTED     30          1712205541     logreplay vmhana01   4:S:master1:master:worker:master 100   site_b -    sync   SOK        1.02.03.04 vmhana02
    #
    #
    #  ... or to be more precise the tested lib function will use the `--format=script`
    #
    #
    # $  SAPHanaSR-showAttr --format=script'
    #
    #...
    # Hosts/vmhana01/node_state="1712205541"
    # ...
    # Hosts/vmhana02/node_state="1712205541"

    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    my $stability_counter = 0;
    $sles4sap_publiccloud->redefine(pacemaker_version => sub { return '2.1.9'; });
    # return of get_hana_topology does no matter so much as we stub the check_hana_topology
    $sles4sap_publiccloud->redefine(get_hana_topology => sub { return 'Bart Mancuso'; });
    my $node_state_match;
    $sles4sap_publiccloud->redefine(check_hana_topology => sub {
            my (%args) = @_;
            note("check_hana_topology(node => , node_state_match => $args{node_state_match} )");
            # store in a variable to be inspected later
            $node_state_match = $args{node_state_match};
            $stability_counter++;
            return 1; });
    my $self = sles4sap_publiccloud->new();
    $self->wait_for_sync();
    ok($node_state_match =~ /[1-9][0-9]+/ or $node_state_match eq '4', 'node_state_match : ' . $node_state_match . ' is expected to be 4 or an integer');
};

subtest '[wait_for_cluster]' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(pacemaker_version => sub { return '1.2.3'; });
    my @calls;
    $sles4sap_publiccloud->redefine(run_cmd => sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            # Jack will not make check_crm_output unhappy
            return 'Jack Aubrey'; }
    );
    $sles4sap_publiccloud->redefine(get_hana_topology => sub {
            # not functional to the test, just for a nice UT output
            push @calls, 'SAPHanaSR-showAttr --format=script';
            return 0; });
    my @node_state_matches;
    $sles4sap_publiccloud->redefine(check_hana_topology => sub {
            my (%args) = @_;
            push @node_state_matches, $args{node_state_match};
            return 1; });
    $sles4sap_publiccloud->redefine(check_crm_output => sub { return 1; });

    my $self = sles4sap_publiccloud->new();

    $self->wait_for_cluster();

    note("\n  C -->  " . join("\n  C -->  ", @calls));
    note("\n  node_state_matches -->  " . join("\n  -->  ", @node_state_matches));

    ok((any { qr/crm_mon -r -R -n -N -1/ } @calls), 'function calls crm_mon -r -R -n -N -1');
    ok((any { qr/online/ } @node_state_matches), 'Pacemaker older than 2.1.7 match with online');
};

subtest '[saphanasr_showAttr_version]' => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $sles4sap_publiccloud->redefine(run_cmd => sub { return 'hello-world-1.2.3.4-12345.6.78.9.end'; });
    my $self = sles4sap_publiccloud->new();

    my $ret = $self->saphanasr_showAttr_version();
    ok $ret eq '1.2.3.4';
};

subtest '[create_hana_vars_section]' => sub {
    set_var('HANA_MEDIA', '>>>HANA_MEDIA---VALUE<<<');
    set_var('_HANA_MASTER_PW', '>>>_HANA_MASTER_PW---VALUE<<<');
    set_var('INSTANCE_SID', '>>>INSTANCE_SID---VALUE<<<');
    set_var('INSTANCE_ID', '>>>INSTANCE_ID---VALUE<<<');

    my $ret = create_hana_vars_section();

    set_var('HANA_MEDIA', undef);
    set_var('_HANA_MASTER_PW', undef);
    set_var('INSTANCE_SID', undef);
    set_var('INSTANCE_ID', undef);

    ok %$ret{sap_hana_install_sid} eq '>>>INSTANCE_SID---VALUE<<<';
};

subtest '[create_hana_vars_section] firewall' => sub {
    set_var('HANA_MEDIA', '>>>HANA_MEDIA---VALUE<<<');
    set_var('_HANA_MASTER_PW', '>>>_HANA_MASTER_PW---VALUE<<<');
    set_var('INSTANCE_SID', '>>>INSTANCE_SID---VALUE<<<');
    set_var('INSTANCE_ID', '>>>INSTANCE_ID---VALUE<<<');
    set_var('SLES4SAP_FIREWALL_PORTS', 'true');

    my $ret = create_hana_vars_section();

    set_var('HANA_MEDIA', undef);
    set_var('_HANA_MASTER_PW', undef);
    set_var('INSTANCE_SID', undef);
    set_var('INSTANCE_ID', undef);
    set_var('SLES4SAP_FIREWALL_PORTS', undef);

    ok %$ret{sap_hana_install_update_firewall} eq 'true';
};

subtest "[get_replication_info]" => sub {
    my $sles4sap_publiccloud = Test::MockModule->new('sles4sap_publiccloud', no_auto => 1);

    my $cmd_output = <<'END';
online: true

site name: site_b
dropline:^None
END

    $sles4sap_publiccloud->redefine(run_cmd => sub { return $cmd_output; });
    $sles4sap_publiccloud->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $self = sles4sap_publiccloud->new();
    set_var('SAP_SIDADM', 'SAP_SIDADMTEST');
    my $result = $self->get_replication_info();
    set_var('SAP_SIDADM', undef);

    ok(ref($result) eq 'HASH', 'Result is a hash reference');
    is($result->{online}, 'true', 'Online status is true');
    is($result->{dropline}, undef, 'No filtered lines');
};

done_testing;
