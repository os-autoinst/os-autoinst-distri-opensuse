use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use Data::Dumper;
use sles4sap::sap_deployment_automation_framework::networking;

sub unset_vars {
    set_var($_, undef) foreach (
        'SDAF_TFSTATE_STORAGE_ACCOUNT', 'SDAF_DEPLOYER_RESOURCE_GROUP', 'SDAF_DEPLOYER_VNET_CODE'
    );
}

subtest '[assign_address_space] Test fail conditions' => sub {
    my @incorrect_values = ('p0', 'yesterday', '08:00', ' ', undef);
    for my $value (@incorrect_values) {
        dies_ok { assign_address_space(networks_older_than => $value) }
        'Fail with non numerical "networks_older_than" argument value: "' .
          ($value //= 'undef') . '"';
    }
    unset_vars();
    dies_ok { assign_address_space(networks_older_than => '1984') } 'Fail with missing OpenQA settings';
};

subtest '[assign_address_space] Assign existing space' => sub {
    my $mocklib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::networking', no_auto => 1);
    my %checks;
    $mocklib->redefine(az_network_vnet_get => sub { return ['optimus'] });
    $mocklib->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mocklib->redefine(list_expired_files => sub { return ('192.168.0.0') });
    $mocklib->redefine(check_peering_exists => sub { $checks{check_peerings} = '1';
            return });
    $mocklib->redefine(acquire_network_file_lease => sub { $checks{lease_acquired} = '1';
            return 'yes' });
    set_var('SDAF_DEPLOYER_VNET_CODE', 'Decepticons');
    set_var('SDAF_DEPLOYER_RESOURCE_GROUP', 'Autobots');

    is assign_address_space(networks_older_than => '1984'), '192.168.0.0/26', 'Return network space if peering exists and lease was acquired';
    ok($checks{lease_acquired}, 'Test attempts to acquire file lease.');
    ok($checks{lease_acquired}, 'Test checks for existing peerings.');

    unset_vars();
};

subtest '[assign_address_space] Create new address space' => sub {
    my $mocklib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::networking', no_auto => 1);
    # mock assign_address_space
    $mocklib->redefine(az_network_vnet_get => sub { return ['optimus'] });
    $mocklib->redefine(assign_defined_network => sub { return });

    # mock create_new_address_space
    $mocklib->redefine(record_info => sub { record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); } });
    $mocklib->redefine(calculate_net_addr_space => sub { return '127.0.0.1'; });
    $mocklib->redefine(list_network_lease_files => sub { return []; });
    $mocklib->redefine(create_lease_file => sub { return; });
    $mocklib->redefine(check_peering_exists => sub { return; });

    set_var('SDAF_DEPLOYER_VNET_CODE', 'Decepticons');
    set_var('SDAF_DEPLOYER_RESOURCE_GROUP', 'Autobots');

    is assign_address_space(networks_older_than => '1984'), '127.0.0.1/26',
      'Return address space created by create_new_address_space() function';

    $mocklib->redefine(check_peering_exists => sub { return 'yes'; });
    dies_ok { assign_address_space(networks_older_than => '1984') }
    'Die if address space pool runs out - all address peerings assigned.';

    $mocklib->redefine(list_network_lease_files => sub { return ['Megatron']; });
    dies_ok { assign_address_space(networks_older_than => '1984') } 'Die if address space pool runs out - all files already created.';
    unset_vars();
};

subtest '[list_expired_files] ' => sub {
    my $mocklib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::networking', no_auto => 1);
    # mock assign_address_space
    $mocklib->redefine(az_network_vnet_get => sub { return ['optimus'] });
    $mocklib->redefine(create_new_address_space => sub { return 1 });
    # mock assign_defined_network
    $mocklib->redefine(record_info => sub { record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); } });
    $mocklib->redefine(check_peering_exists => sub { return });
    $mocklib->redefine(acquire_network_file_lease => sub { return 1 });
    $mocklib->redefine(az_storage_blob_list => sub { return [
                {network => 'old_network_file', last_modified => '2022-09-23T13:44:42+02:00'},
                {network => 'new_network_file', last_modified => '2029-09-23T13:44:42+02:00'}
    ] });

    set_var('SDAF_DEPLOYER_VNET_CODE', 'Decepticons');
    set_var('SDAF_DEPLOYER_RESOURCE_GROUP', 'Autobots');
    set_var('SDAF_TFSTATE_STORAGE_ACCOUNT', 'Nebulans');

    is assign_address_space(networks_older_than => '30'), 'old_network_file/26', 'Return only old network files';

    unset_vars();
};

subtest '[calculate_ip_count] ' => sub {
    is calculate_ip_count(subnet_prefix => '/30'), 4, "IP count must be 4";
};


subtest '[calculate_subnets] Check for required subnets' => sub {
    my %network_data = %{calculate_subnets(network_space => '192.168.1.0/26')};
    note("-> Calculated network space:\n" . Dumper(%network_data));
    foreach (
        'admin_subnet_address_prefix',
        'db_subnet_address_prefix',
        'app_subnet_address_prefix',
        'web_subnet_address_prefix',
        'network_address_space',
        'iscsi_subnet_address_prefix'
    ) {
        ok(defined($network_data{$_}), "Network data contains '$_'");
    }
};

subtest '[calculate_subnets] Validate subnet definition' => sub {
    my $mocklib = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::networking', no_auto => 1);

    # Simulate IP overflow
    # this makes `calculate_ip_count` return lower number than the total amount of all subnet IP addr
    $mocklib->redefine(calculate_ip_count => sub { return 10 if grep /\/26/, @_; return 100; });
    dies_ok { calculate_subnets(network_space => '192.168.1.0/26') } 'Die in case of IP overflow into next addr space';
};

done_testing;
