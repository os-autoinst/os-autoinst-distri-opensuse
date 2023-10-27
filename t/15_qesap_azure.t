use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use Data::Dumper;

use testapi 'set_var';
use qesapdeployment;
set_var('QESAP_CONFIG_FILE', 'MARLIN');


subtest '[qesap_az_get_resource_group]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(get_current_job_id => sub { return 'CRAB'; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $result = qesap_az_get_resource_group();

    ok((any { /az group list.*/ } @calls), 'az command properly composed');
    ok((any { /.*CRAB.*/ } @calls), 'az filtered by jobId');
    ok($result eq 'BOAT', 'function return is equal to the script_output return');
};

subtest '[qesap_az_calculate_address_range]' => sub {
    my %result_1 = qesap_az_calculate_address_range(slot => 1);
    my %result_2 = qesap_az_calculate_address_range(slot => 2);
    my %result_64 = qesap_az_calculate_address_range(slot => 64);
    my %result_65 = qesap_az_calculate_address_range(slot => 65);

    is($result_1{vnet_address_range}, "10.0.0.0/21", 'result_1 vnet_address_range is correct');
    is($result_1{subnet_address_range}, "10.0.0.0/24", 'result_1 subnet_address_range is correct');
    is($result_2{vnet_address_range}, "10.0.8.0/21", 'result_2 vnet_address_range is correct');
    is($result_2{subnet_address_range}, "10.0.8.0/24", 'result_2 subnet_address_range is correct');
    is($result_64{vnet_address_range}, "10.1.248.0/21", 'result_64 vnet_address_range is correct');
    is($result_64{subnet_address_range}, "10.1.248.0/24", 'result_64 subnet_address_range is correct');
    is($result_65{vnet_address_range}, "10.2.0.0/21", 'result_65 vnet_address_range is correct');
    is($result_65{subnet_address_range}, "10.2.0.0/24", 'result_65 subnet_address_range is correct');
    dies_ok { qesap_az_calculate_address_range(slot => 0); } "Expected die for slot < 1";
    dies_ok { qesap_az_calculate_address_range(slot => 8193); } "Expected die for slot > 8192";
};

subtest '[qesap_az_get_vnet]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'DIVER'; });

    my $result = qesap_az_get_vnet('AUSTRALIA');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /az network vnet list.*/ } @calls), 'az command properly composed');
    ok($result eq 'DIVER', 'function return is equal to the script_output return');
};

subtest '[qesap_az_get_vnet] no resource_group' => sub {
    dies_ok { qesap_az_get_vnet() } "Expected die for missing resource_group";
};

subtest '[qesap_az_vnet_peering] missing group arguments' => sub {
    dies_ok { qesap_az_vnet_peering() } "Expected die for missing arguments";
    dies_ok { qesap_az_vnet_peering(source_group => 'JELLYFISH') } "Expected die for missing target_group";
    dies_ok { qesap_az_vnet_peering(target_group => 'SQUID') } "Expected die for missing source_group";
};

subtest '[qesap_az_vnet_peering]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_JELLYFISH' if ($_[0] =~ /JELLYFISH/);
            return 'VNET_SQUID' if ($_[0] =~ /SQUID/);
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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(get_current_job_id => sub { return 42; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'NEMO'; });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(record_soft_failure => sub { note(join(' ', 'RECORD_SOFT_FAILURE -->', @_)); });
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_WHALE' if ($_[0] =~ /WHALE/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    # qesap_az_get_peering_name
    ok((any { /az network vnet peering list.*grep 42/ } @calls), 'az command properly composed');
};

subtest '[qesap_az_vnet_peering_delete] delete failure' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
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
    $qesap->redefine(qesap_az_get_vnet => sub {
            return 'VNET_WHALE' if ($_[0] =~ /WHALE/);
            return;
    });

    qesap_az_vnet_peering_delete(target_group => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  SF-->  " . join("\n  SF-->  ", @soft_failure));
    # qesap_az_get_peering_name
    ok((any { /jsc#7487/ } @soft_failure), 'soft failure');
};

subtest '[qesap_az_setup_native_fencing_permissions]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(qesap_az_enable_system_assigned_identity => sub { return 'WalkThePlank!'; });
    $qesap->redefine(qesap_az_assign_role => sub { return 'AyeAyeCaptain!'; });
    my %mandatory_args = (
        vm_name => 'CaptainUsop',
        subscription_id => 'c0ffeeee-c0ff-eeee-1234-123456abcdef',
        resource_group => 'StrawhatPirates'
    );

    foreach ('vm_name', 'subscription_id', 'resource_group') {
        my $orig_value = $mandatory_args{$_};
        $mandatory_args{$_} = undef;
        dies_ok { qesap_az_setup_native_fencing_permissions(%mandatory_args) } "Expected failure: missing mandatory arg: $_";
        $mandatory_args{$_} = $orig_value;
    }

    ok qesap_az_setup_native_fencing_permissions(%mandatory_args), 'PASS with all args defined';
};

subtest '[qesap_az_assign_role]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(assert_script_run => sub { return 1; });

    my %mandatory_args = (
        assignee => 'CaptainUsop',
        subscription_id => 'c0ffeeee-c0ff-eeee-1234-123456abcdef',
        resource_group => 'StrawhatPirates',
        role => 'Liar'
    );
    # check mandatory args
    foreach ('assignee', 'role', 'subscription_id', 'resource_group') {
        my $orig_value = $mandatory_args{$_};
        $mandatory_args{$_} = undef;
        dies_ok { qesap_az_assign_role(%mandatory_args) } "Expected failure: missing mandatory arg: $_";
        $mandatory_args{$_} = $orig_value;
    }

    ok qesap_az_assign_role(%mandatory_args), 'PASS with all args defined';
};

subtest '[qesap_az_validate_uuid_pattern]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    $qesap->redefine(diag => sub { return; });
    my $good_uuid = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    my @bad_uuid_list = ('OhCaptainMyCaptain',    # complete nonsense
        'c0ffeee-c0ff-eeee-1234-123456abcdef',    # First 7 characters inttead of 8
        'c0ffeeee-c0ff-eeee-xxxx-123456abcde',    # Using non hexadecimal values 'x'
        'c0ffeeee_c0ff-eeee-1234-123456abcdef');    # Underscore instead of dash

    is qesap_az_validate_uuid_pattern($good_uuid), $good_uuid, "Return UUID if valid: $good_uuid ";

    foreach my $bad_uuid (@bad_uuid_list) {
        is qesap_az_validate_uuid_pattern($bad_uuid), 0, "Return '0' with invalid UUID: $bad_uuid";
    }
};

subtest '[qesap_az_enable_system_assigned_identity]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my $vm_name = 'CaptainHook';
    my $resource_group = 'TheJollyRoger';
    my $good_uuid = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';

    $qesap->redefine(script_output => sub { return $good_uuid; });
    is qesap_az_enable_system_assigned_identity($vm_name, $resource_group), $good_uuid, 'PASS with valid UUID';
    # Missing args
    dies_ok { qesap_az_enable_system_assigned_identity($vm_name) } 'Fail with missing resource group';
    dies_ok { qesap_az_enable_system_assigned_identity() } 'Fail with missing args';
};

subtest '[qesap_az_get_tenant_id]' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    dies_ok { qesap_az_get_tenant_id() } 'Expected failure: missing mandatory arg';

    my $valid_uuid = 'c0ffeeee-c0ff-eeee-1234-123456abcdef';
    $qesap->redefine(script_output => sub { return $valid_uuid; });
    $qesap->redefine(qesap_az_validate_uuid_pattern => sub { return $valid_uuid; });
    is qesap_az_get_tenant_id($valid_uuid), 'c0ffeeee-c0ff-eeee-1234-123456abcdef', 'Returned value is a valid UUID';
};

subtest '[qesap_az_get_active_peerings] die for missing mandatory arguments' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);

    # Test missing arguments
    dies_ok { qesap_az_get_active_peerings(); } "Expected die if called without arguments";
    dies_ok { qesap_az_get_active_peerings(vnet => 'SEAWEED'); } "Expected die if called without rg";
    dies_ok { qesap_az_get_active_peerings(rg => 'CORAL'); } "Expected die if called without vnet";
};

subtest '[qesap_az_get_active_peerings] test correct ID extraction' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @delete_calls;

    $qesap->redefine(qesap_az_get_active_peerings => sub {
            return (
                'peering1' => '100001',
                'peering2' => '100002',
                'peering3' => '100003'
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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN');

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
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', lifetime => 30);

    ok((any { /.*--expiry.*date.*30/ } @calls), 'Configured lifetime');
};


subtest '[qesap_az_create_sas_token] with custom permissions' => sub {
    my $qesap = Test::MockModule->new('qesapdeployment', no_auto => 1);
    my @calls;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'BOAT' });
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = qesap_az_create_sas_token(container => 'NEMO', storage => 'DORY', keyname => 'MARLIN', 'permission' => 'SHELL');

    ok((any { /.*--permission SHELL.*/ } @calls), 'Configured permission');
};

done_testing;
