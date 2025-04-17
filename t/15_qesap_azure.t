use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);

use testapi qw(set_var);
use sles4sap::qesap::qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');


subtest '[qesap_az_get_resource_group]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(get_current_job_id => sub { return 'CRAB'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az group list.*/ } @calls), 'az command properly composed');
    ok((any { /.*CRAB.*/ } @calls), 'az filtered by jobId');
    ok($result eq 'BOAT', 'function return is equal to the script_output return');
};

subtest '[qesap_az_vnet_peering] missing group arguments' => sub {
    dies_ok { qesap_az_vnet_peering() } "Expected die for missing arguments";
    dies_ok { qesap_az_vnet_peering(source_group => 'JELLYFISH') } "Expected die for missing target_group";
    dies_ok { qesap_az_vnet_peering(target_group => 'SQUID') } "Expected die for missing source_group";
};

subtest '[qesap_az_vnet_peering]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            return 'VNET_JELLYFISH' if ($args{resource_group} =~ /JELLYFISH/);
            return 'VNET_SQUID' if ($args{resource_group} =~ /SQUID/);
            return 'VNET_UNKNOWN';
    });
    $qesap->redefine(script_output => sub { push @calls, $_[0];
            return 'ID_JELLYFISH' if ($_[0] =~ /VNET_JELLYFISH/);
            return 'ID_SQUID' if ($_[0] =~ /VNET_SQUID/);
            return 'ID_UNKNOWN';
    });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });

    qesap_az_vnet_peering(source_group => 'JELLYFISH', target_group => 'SQUID');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az network vnet show.*JELLYFISH/ } @calls), 'az network vnet show command properly composed for the source_group');
    ok((any { /az network vnet show.*SQUID/ } @calls), 'az network vnet show command properly composed for the target_group');
    ok((any { /az network vnet peering create.*JELLYFISH/ } @calls), 'az network vnet peering create command properly composed for the source_group');
    ok((any { /az network vnet peering create.*SQUID/ } @calls), 'az network vnet peering create command properly composed for the target_group');
};

subtest '[qesap_az_vnet_peering_delete] missing target_group arguments' => sub {
    dies_ok { qesap_az_vnet_peering_delete() } "Expected die for missing arguments";
};

subtest '[qesap_az_get_peering_name] missing resource_group arguments' => sub {
    dies_ok { qesap_az_get_peering_name() } "Expected die for missing arguments";
};

subtest '[qesap_az_vnet_peering_delete]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(get_current_job_id => sub { return 42; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'NEMO'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(record_soft_failure => sub { note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $qesap->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            return 'VNET_WHALE' if ($args{resource_group} =~ /WHALE/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # qesap_az_get_peering_name
    ok((any { /az network vnet peering list.*grep 42/ } @calls), 'az command properly composed');
};

subtest '[qesap_az_vnet_peering_delete] delete failure' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my @soft_failure;
    $qesap->redefine(get_current_job_id => sub { return 42; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'DENTIST'; });
    # Simulate a failure in the delete
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 1; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(record_soft_failure => sub {
            push @soft_failure, $_[0];
            note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $qesap->redefine(az_network_vnet_get => sub {
            my (%args) = @_;
            return 'VNET_WHALE' if ($args{resource_group} =~ /WHALE/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  SF-->  " . join("\n  SF-->  ", @soft_failure));
    # qesap_az_get_peering_name
    ok((any { /jsc#7487/ } @soft_failure), 'soft failure');
};

subtest '[qesap_az_setup_native_fencing_permissions]' => sub {
    my $command;
    my $vm_id = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    $qesap->redefine(script_output => sub { return $vm_id; });
    $qesap->redefine(assert_script_run => sub { $command = shift; return 1; });

    my %mandatory_args = (
        vm_name => 'CaptainUsop',
        resource_group => 'StrawhatPirates'
    );

    foreach ('vm_name', 'resource_group') {
        my $orig_value = $mandatory_args{$_};
        $mandatory_args{$_} = undef;
        dies_ok { qesap_az_setup_native_fencing_permissions(%mandatory_args) } "Expected failure: missing mandatory arg: $_";
        $mandatory_args{$_} = $orig_value;
    }

    ok qesap_az_setup_native_fencing_permissions(%mandatory_args), 'PASS with all args defined';
    like($command, qr/az role assignment create.*--assignee-object-id $vm_id.*StrawhatPirates/, 'az command properly composed');
};

subtest '[qesap_az_get_tenant_id]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    dies_ok { qesap_az_get_tenant_id() } 'Expected failure: missing mandatory arg';

    my $valid_uuid = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    $qesap->redefine(script_output => sub { return $valid_uuid; });
    #$qesap->redefine(az_validate_uuid_pattern => sub { return $valid_uuid; });
    is qesap_az_get_tenant_id($valid_uuid), 'c0ffeeee-c0ff-eeee-1234-123456abcdef', 'Returned value is a valid UUID';
};

subtest '[qesap_az_get_active_peerings] die for missing mandatory arguments' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);

    # Test missing arguments
    dies_ok { qesap_az_get_active_peerings(); } "Expected die if called without arguments";
    dies_ok { qesap_az_get_active_peerings(vnet => 'SEAWEED'); } "Expected die if called without rg";
    dies_ok { qesap_az_get_active_peerings(rg => 'CORAL'); } "Expected die if called without vnet";
};

subtest '[qesap_az_get_active_peerings] test correct ID extraction' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my %results;

    $qesap->redefine(script_output => sub {
            if ($_[0] =~ /myresourcegroup/ && $_[0] =~ /myvnetname/) {
                return "vnet123456-vnet-other\nvnet789012-vnet-other\nvnet-nojobid-vnet-other";
            }
    });
    # Test correct id extraction
    %results = qesap_az_get_active_peerings(rg => 'myresourcegroup', vnet => 'myvnetname');
    my %expected_results = (
        "vnet123456-vnet-other" => 123456,
        "vnet789012-vnet-other" => 789012
    );

    foreach my $key (keys %expected_results) {
        ok($results{$key} == $expected_results{$key}, "Correct job id extracted for vnet name $key");
    }
};

subtest '[qesap_az_get_active_peerings] test for incorrect job ID' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my %results;

    $qesap->redefine(script_output => sub {
            if ($_[0] =~ /myresourcegroup/ && $_[0] =~ /myvnetname/) {
                return "vnet123456-vnet-other\nvnet789012-vnet-other\nvnet-nojobid-vnet-other";
            }
    });
    # Test incorrect job ID
    ok(!exists $results{"vnet-nojobid-vnet-other"}, "No job id extracted for vnet name without a valid job id");
};

subtest '[qesap_az_clean_old_peerings]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @delete_calls;

    $qesap->redefine(qesap_az_get_active_peerings => sub {
            return (
                peering1 => '100001',
                peering2 => '100002',
                peering3 => '100003'
            );
    });

    $qesap->redefine(qesap_is_job_finished => sub {
            my ($job_id) = @_;
            return $job_id eq '100001' || $job_id eq '100003';    # Jobs 100001 and 100003 are finished
    });

    $qesap->redefine(qesap_az_simple_peering_delete => sub {
            my (%args) = @_;
            push @delete_calls, $args{peering_name};
    });

    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    qesap_az_clean_old_peerings(rg => 'myresourcegroup', vnet => 'myvnetname');

    ok(any { $_ eq 'peering1' } @delete_calls, "Peering1 was deleted");
    ok(none { $_ eq 'peering2' } @delete_calls, "Peering2 was not deleted");
    ok(any { $_ eq 'peering3' } @delete_calls, "Peering3 was deleted");
};

subtest '[qesap_az_create_sas_token] mandatory arguments' => sub {
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', keyname => 'DORY'); } "Failed for missing argument storage";
    dies_ok { qesap_az_create_sas_token(storage => 'NEMO', keyname => 'DORY'); } "Failed for missing argument container";
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY'); } "Failed for missing argument keyname";
};

subtest '[qesap_az_create_sas_token]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok($ret eq 'BOAT', "The function return the token returned by the az command");
    ok((any { /az storage container generate-sas.*/ } @calls), 'Main az command `az storage container generate-sas` properly composed');
    ok((any { /.*--account-name DORY.*/ } @calls), 'storage argument is used for --account-name');
    ok((any { /.*--name NEMO.*/ } @calls), 'container argument is used for --name');
    ok((any { /az storage account keys list --account-name DORY.*/ } @calls), 'Inner az command `az storage account keys list` properly composed');
    ok((any { /.*--query.*MARLIN.*/ } @calls), 'keyname argument used in the query of the inner command');
    ok((any { /.*\[\?contains\(keyName.*\)\]\.value/ } @calls), 'contains query format to extract the key value is ok');
    ok((any { /.*--permission r.*/ } @calls), 'default permission is read only');
    ok((any { /.*--expiry.*date.*10/ } @calls), 'default token expire is 10 minutes');
};

subtest '[qesap_az_create_sas_token] with custom timeout' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', lifetime => 30);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*--expiry.*date.*30/ } @calls), 'Configured lifetime');
};

subtest '[qesap_az_create_sas_token] with custom permissions' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => '*') } 'Test unsupported permissions';
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'r*') } 'Test unsupported permissions';
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'l*') } 'Test unsupported permissions';
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'rl*') } 'Test unsupported permissions';
    qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'r');
    qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'l');
    qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'rl');
    qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', permission => 'lr');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok 1;
};

subtest '[qesap_az_list_container_files] missing arguments' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    dies_ok { qesap_az_list_container_files(storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Missing container argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', token => 'SAS', prefix => 'GURGLE') } 'Missing storage argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', prefix => 'GURGLE') } 'Missing token argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS') } 'Missing prefix argument';
};

subtest '[qesap_az_list_container_files] bad output' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    my $so_ret = '';
    $qesap->redefine(script_output => sub { return $so_ret; });
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Empty return string';
    $so_ret = ' ';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Space-only return string';
};

subtest '[qesap_az_list_container_files] command composition' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'GURGLE/ifrit.rpm\nGURGLE/shiva.src.rpm' });
    qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS', prefix => 'GURGLE');
    ok((any { /az storage blob list.*/ } @calls), 'Main az command `az storage blob list` properly composed');
    ok((any { /.*--account-name TAD.*/ } @calls), 'storage argument is used for --account-name');
    ok((any { /.*--container-name BLOAT.*/ } @calls), 'container argument is used for --container-name');
    ok((any { /--sas-token 'SAS'.*/ } @calls), 'token argument is used for --sas-token');
    ok((any { /.*--prefix GURGLE*/ } @calls), 'prefix argument used for --prefix');
};

subtest '[qesap_az_diagnostic_log] no VMs' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_resource_group => sub { return 'DENTIST'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Configure vm list to return no VMs
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return '[]'; });

    my @log_files = qesap_az_diagnostic_log();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az vm list.*/ } @calls), 'Proper base command for vm list');
    ok((any { /.*--resource-group DENTIST.*/ } @calls), 'Proper resource group in vm list');
    ok((any { /.*-o json.*/ } @calls), 'Proper output format in vm list');
    ok((scalar @log_files == 0), 'No returned logs');
};

subtest '[qesap_az_diagnostic_log] one VMs' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_resource_group => sub { return 'DENTIST'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Configure vm list to return no VMs
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return '[{"name": "NEMO", "id": "MARLIN"}]'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my @log_files = qesap_az_diagnostic_log();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az vm boot-diagnostics get-boot-log.*/ } @calls), 'Proper base command for vm boot-diagnostics get-boot-log');
    ok((any { /.*--ids MARLIN.*/ } @calls), 'Proper id in boot-diagnostics');
    ok((any { /.*tee.*boot-diagnostics_NEMO.*/ } @calls), 'Proper output file in boot-diagnostics');
    ok((scalar @log_files == 1), 'Exactly one returned logs for one VM');
};


done_testing;
