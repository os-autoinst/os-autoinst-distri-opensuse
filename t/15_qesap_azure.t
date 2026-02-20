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
use sles4sap::qesap::azure;

set_var('QESAP_CONFIG_FILE', 'MARLIN');


subtest '[qesap_az_get_resource_group] match job_id' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my $az_call = 0;
    $qesap->redefine(az_group_name_get => sub { $az_call = 1; return ['BOAT1234'] });
    $qesap->redefine(get_current_job_id => sub { return '1234'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group();

    ok($az_call eq 1, 'az_group_name_get calles');
    ok($result eq 'BOAT1234', "result:$result is BOAT1234 like expected.");
};

subtest '[qesap_az_get_resource_group] substring' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my $az_call = 0;
    $qesap->redefine(az_group_name_get => sub { $az_call = 1; return ['BOAT1234', 'CRAB1234'] });
    $qesap->redefine(get_current_job_id => sub { return '1234'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group(substring => 'CRAB');

    ok($az_call eq 1, 'az_group_name_get calles');
    ok($result eq 'CRAB1234', "result:$result is CRAB1234 like expected.");
};

subtest '[qesap_az_get_resource_group] not match job_id' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my $az_call = 0;
    $qesap->redefine(az_group_name_get => sub { $az_call = 1; return ['BOAT1234'] });
    $qesap->redefine(get_current_job_id => sub { return '3456'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group();

    ok($az_call eq 1, 'az_group_name_get calles');
    ok(!defined($result), 'result is UNDEFINED as expected');
};

subtest '[qesap_az_get_resource_group] match QESAP_DEPLOYMENT_IMPORT' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my $az_call = 0;
    $qesap->redefine(az_group_name_get => sub { $az_call = 1; return ['BOAT1234'] });
    $qesap->redefine(get_current_job_id => sub { return '3456'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    set_var('QESAP_DEPLOYMENT_IMPORT', '1234');
    my $result = qesap_az_get_resource_group();
    set_var('QESAP_DEPLOYMENT_IMPORT', undef);

    ok($az_call eq 1, 'az_group_name_get calles');
    ok($result eq 'BOAT1234', "result:$result is like expected BOAT1234");
};

subtest '[qesap_az_get_resource_group] az integrate' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    $qesap->redefine(get_current_job_id => sub { return '1234'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["BOAT1234", "BOAT3456"]' });

    my $result = qesap_az_get_resource_group();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az group list.*/ } @calls), 'az command properly composed');
    ok($result eq 'BOAT1234', "result:$result is like expected BOAT1234");
};

subtest '[qesap_az_get_resource_group] die when job_id is undef' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    $qesap->redefine(az_group_name_get => sub { return ['BOAT1234']; });
    # Mock get_current_job_id to return undef
    $qesap->redefine(get_current_job_id => sub { return undef; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Ensure QESAP_DEPLOYMENT_IMPORT is not set
    set_var('QESAP_DEPLOYMENT_IMPORT', undef);

    dies_ok { qesap_az_get_resource_group() } 'Die when job_id is not defined';
};

subtest '[qesap_az_setup_native_fencing_permissions] missing argument' => sub {
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
};

subtest '[qesap_az_setup_native_fencing_permissions]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    my $vm_id = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return $vm_id; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return 1; });
    $qesap->redefine(az_role_definition_list => sub { return 'ROLEID-Squall-888'; });

    my %mandatory_args = (
        vm_name => 'CaptainUsop',
        resource_group => 'StrawhatPirates'
    );

    ok qesap_az_setup_native_fencing_permissions(%mandatory_args), 'PASS with all args defined';
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az role assignment create.*/ } @calls), 'Main az command properly composed');
    ok((any { /.*--assignee-object-id $vm_id/ } @calls), 'assignee-object-id in az command properly composed');
    ok((any { /.*StrawhatPirates/ } @calls), 'resource group in az command properly composed');
};

subtest '[qesap_az_setup_native_fencing_permissions] invalid UUID' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'AnneBonny'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; return 1; });

    my %mandatory_args = (
        vm_name => 'CaptainUsop',
        resource_group => 'StrawhatPirates'
    );

    dies_ok { ok qesap_az_setup_native_fencing_permissions(%mandatory_args) } 'PASS with all args defined';
};

subtest '[qesap_az_get_tenant_id] missing arguments' => sub {
    dies_ok { qesap_az_get_tenant_id() } 'Expected failure: missing mandatory arg';
};

subtest '[qesap_az_get_tenant_id]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my $valid_uuid = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    $qesap->redefine(script_output => sub { return $valid_uuid; });

    is qesap_az_get_tenant_id(subscription_id => $valid_uuid), 'c0ffeeee-c0ff-eeee-1234-123456abcdef', 'Returned value is a valid UUID';
};

subtest '[qesap_az_clean_old_peerings]' => sub {
    my $qesap_az = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @delete_calls;

    $qesap_az->redefine(qesap_az_get_active_peerings => sub {
            return (
                peering1 => '100001',
                peering2 => '100002',
                peering3 => '100003'
            );
    });

    $qesap_az->redefine(qesap_is_job_finished => sub {
            my (%args) = @_;
            return $args{job_id} eq '100001' || $args{job_id} eq '100003';    # Jobs 100001 and 100003 are finished
    });

    $qesap_az->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    $qesap_az->redefine(az_network_peering_delete => sub {
            my (%args) = @_;
            push @delete_calls, $args{name};
            return; });

    qesap_az_clean_old_peerings(rg => 'myresourcegroup', vnet => 'myvnetname');

    note("\n  DC-->  " . join("\n  DC-->  ", @delete_calls));
    ok((any { $_ eq 'peering1' } @delete_calls), "Peering1 was deleted");
    ok((none { $_ eq 'peering2' } @delete_calls), "Peering2 was not deleted");
    ok((any { $_ eq 'peering3' } @delete_calls), "Peering3 was deleted");
};

subtest '[qesap_az_clean_old_peerings] integrate test' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_is_job_finished => sub {
            my (%args) = @_;
            return $args{job_id} eq '100001' || $args{job_id} eq '100003';    # Jobs 100001 and 100003 are finished
    });

    my @calls;

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(script_run => sub {
            push @calls, $_[0];
            return 0;
    });
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            if ($_[0] =~ /az network vnet peering list.*/) {
                return '["COCCO100001", "COCCO100002", "COCCO100003"]'; }
            return 'INVALID'; });

    qesap_az_clean_old_peerings(rg => 'myresourcegroup', vnet => 'myvnetname');
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az network vnet peering delete --name COCCO100001/ } @calls), "Peering1 was deleted");
    ok((none { /az network vnet peering delete --name COCCO100002/ } @calls), "Peering2 was not deleted");
    ok((any { /az network vnet peering delete --name COCCO100003/ } @calls), "Peering3 was deleted");
};

subtest '[qesap_az_create_sas_token] mandatory arguments' => sub {
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', keyname => 'DORY'); } "Failed for missing argument storage";
    dies_ok { qesap_az_create_sas_token(storage => 'NEMO', keyname => 'DORY'); } "Failed for missing argument container";
    dies_ok { qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY'); } "Failed for missing argument keyname";
};

subtest '[qesap_az_create_sas_token]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ret eq 'BOAT'), "The function return the token returned by the az command");
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', lifetime => 30);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /.*--expiry.*date.*30/ } @calls), 'Configured lifetime');
};

subtest '[qesap_az_create_sas_token] with invalid custom permissions' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    foreach my $perm ('*', 'r*', 'l*', 'rl*') {
        dies_ok { qesap_az_create_sas_token(
                container => 'NEMO',
                storage => 'DORY',
                keyname => 'MARLIN',
                permission => $perm) } "Test unsupported permissions '$perm'";
        note("\n  C-->  " . join("\n  C-->  ", @calls));
        @calls = ();
    }
};

subtest '[qesap_az_create_sas_token] with custom permissions' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    foreach my $perm ('r', 'l', 'rl', 'lr') {
        qesap_az_create_sas_token(
            container => 'NEMO',
            storage => 'DORY',
            keyname => 'MARLIN',
            permission => $perm);
        note("\n  C-->  " . join("\n  C-->  ", @calls));
        ok((any { /permission $perm/ } @calls), "Main az command properly composed with permission $perm");
        @calls = ();
    }
};

subtest '[qesap_az_list_container_files] missing arguments' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    dies_ok { qesap_az_list_container_files(storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Missing container argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', token => 'SAS', prefix => 'GURGLE') } 'Missing storage argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', prefix => 'GURGLE') } 'Missing token argument';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS') } 'Missing prefix argument';
};

subtest '[qesap_az_list_container_files] bad output' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    my $so_ret = '';
    $qesap->redefine(script_output => sub { return $so_ret; });
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Empty return string';
    $so_ret = ' ';
    dies_ok { qesap_az_list_container_files(container => 'BLOAT', storage => 'TAD', token => 'SAS', prefix => 'GURGLE') } 'Space-only return string';
};

subtest '[qesap_az_list_container_files] command composition' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
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
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_resource_group => sub { return 'DENTIST'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Configure vm list to return no VMs
    $qesap->redefine(az_vm_list => sub { push @calls, {@_}; return []; });

    my @log_files = qesap_az_diagnostic_log();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { $_->{resource_group} eq 'DENTIST' } @calls), 'Proper resource group in vm list');
    ok((any { $_->{query} =~ /id:id,name:name/ } @calls), 'Proper query in vm list');
    ok((scalar @log_files == 0), 'No returned logs');
};

subtest '[qesap_az_diagnostic_log] one VMs' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_resource_group => sub { return 'DENTIST'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Configure vm list to return one VM
    $qesap->redefine(az_vm_list => sub {
            push @calls, {@_};
            return [{name => "NEMO", id => "MARLIN"}];
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my @log_files = qesap_az_diagnostic_log();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { $_->{resource_group} eq 'DENTIST' } @calls), 'Proper resource group in vm list');
    ok((any { /az vm boot-diagnostics get-boot-log.*/ } @calls), 'Proper base command for vm boot-diagnostics get-boot-log');
    ok((any { /.*--ids MARLIN.*/ } @calls), 'Proper id in boot-diagnostics');
    ok((any { /.*boot-diagnostics_NEMO.*/ } @calls), 'Proper output file in boot-diagnostics');
    ok((scalar @log_files == 1), 'Exactly one returned logs for one VM');
};

subtest '[qesap_az_diagnostic_log] three VMs' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::azure', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_resource_group => sub { return 'DENTIST'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    # Configure vm list to return three VMs
    $qesap->redefine(az_vm_list => sub {
            push @calls, {@_};
            return [
                {name => "DORY", id => "BLUE_TANG"},
                {name => "BRUCE", id => "GREAT_WHITE"},
                {name => "CRUSH", id => "SEA_TURTLE"}
            ];
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my @log_files = qesap_az_diagnostic_log();

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { ref($_) eq 'HASH' && $_->{resource_group} eq 'DENTIST' } @calls), 'Proper resource group in vm list');

    my %expected_vms = (
        DORY => "BLUE_TANG",
        BRUCE => "GREAT_WHITE",
        CRUSH => "SEA_TURTLE"
    );

    while (my ($name, $id) = each %expected_vms) {
        ok((any { /az vm boot-diagnostics get-boot-log --ids $id/ } @calls), "Proper command for $name");
        ok((any { $_ eq "/tmp/boot-diagnostics_$name.txt" } @log_files), "Log file for $name returned");
    }
    ok((scalar @log_files == 3), 'Exactly three returned logs for three VMs');
};

done_testing;
