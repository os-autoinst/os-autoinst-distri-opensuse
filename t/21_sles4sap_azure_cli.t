use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none);

use sles4sap::azure_cli;

subtest '[az_group_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_group_create(name => 'Arlecchino', region => 'Pulcinella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az group create/ } @calls), 'Correct composition of the main command');
    ok((any { /--location Pulcinella/ } @calls), '--location');
    ok((any { /--name Arlecchino/ } @calls), '--name');
};

subtest '[az_group_create] missing args' => sub {
    dies_ok { az_group_create(region => 'Pulcinella') } 'Die for missing argument name';
    dies_ok { az_group_create(name => 'Arlecchino') } 'Die for missing argument region';
};

subtest '[az_group_name_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '["Arlecchino","Truffaldino"]'; });

    my $res = az_group_name_get();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az group list/ } @calls), 'Correct composition of the main command');
    ok((any { /Arlecchino/ } @$res), 'Correct result decoding');
};

subtest '[az_network_vnet_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_vnet_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        vnet => 'Pantalone',
        snet => 'Colombina');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_vnet_create] die on invalid IP' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    foreach my $arg (qw(address_prefixes subnet_prefixes)) {
        foreach my $test_pattern (qw(192.168.0/16 192.168..0/16 192.068.0.0/16 192.168.0.0 192.168.000.000/16 1192.168.0.0/16)) {
            dies_ok { az_network_vnet_create(
                    resource_group => 'Arlecchino',
                    region => 'Pulcinella',
                    vnet => 'Pantalone',
                    snet => 'Colombina',
                    $arg => $test_pattern) } "Die for invalid IP $test_pattern as argument $arg";
            ok scalar @calls == 0, "No call to assert_script_run, croak before to run the command for invalid IP $test_pattern as argument $arg";
            @calls = ();
        }
        foreach my $test_pattern (qw(192.168.0.0/16 192.0.0.0/16 2.168.0.0/16)) {
            az_network_vnet_create(
                resource_group => 'Arlecchino',
                region => 'Pulcinella',
                vnet => 'Pantalone',
                snet => 'Colombina',
                $arg => $test_pattern);
            ok scalar @calls > 0, "Some calls to assert_script_run for valid IP $test_pattern as argument $arg";
            @calls = ();
        }
    }
};

subtest '[az_network_nsg_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_nsg_create(
        resource_group => 'Arlecchino',
        name => 'Brighella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nsg create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_nsg_rule_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_nsg_rule_create(
        resource_group => 'Arlecchino',
        nsg => 'Brighella',
        name => 'Pantalone',
        port => 22);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nsg rule create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_publicip_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_publicip_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network public-ip create/ } @calls), 'Correct composition of the main command');
    ok((none { /allocation-method/ } @calls), 'No argument --allocation-method');
    ok((none { /zone/ } @calls), 'No argument --zone');
};

subtest '[az_network_publicip_create] with optional arguments' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_publicip_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        allocation_method => 'Static',
        zone => 'Venezia Mestre');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--allocation-method Static/ } @calls), 'Argument --allocation-method');
    ok((any { /--zone Venezia Mestre/ } @calls), 'Argument --zone');
};

subtest '[az_network_publicip_delete]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_publicip_delete(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network public-ip delete/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_publicip_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });

    my $res = az_network_publicip_get(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok $res eq 'Eugenia';
};

subtest '[az_network_lb_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_lb_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        vnet => 'Pantalone',
        snet => 'Colombina',
        backend => 'Smeraldina',
        frontend_ip_name => 'Momolo');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network lb create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_lb_create] with a fixed IP' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_network_lb_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        vnet => 'Pantalone',
        snet => 'Colombina',
        backend => 'Smeraldina',
        frontend_ip_name => 'Momolo',
        fip => '1.2.3.4');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network lb create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_lb_create] with an invalid fixed IP' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    dies_ok { az_network_lb_create(
            resource_group => 'Arlecchino',
            name => 'Truffaldino',
            vnet => 'Pantalone',
            snet => 'Colombina',
            backend => 'Smeraldina',
            frontend_ip_name => 'Momolo',
            fip => '1.2.3.') } "Die for invalid IP as fip argument";
    ok scalar @calls == 0, "No call to assert_script_run if IP is invalid";
};

subtest '[az_vm_as_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_as_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        region => 'Pulcinella');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm availability-set create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_vm_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_vm_create] with public IP' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina',
        public_ip => 'Fulgenzio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--public-ip-address Fulgenzio/ } @calls), 'custom Public IP address');
};

subtest '[az_vm_create] with no public IP' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina',
        public_ip => '""');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--public-ip-address ""/ } @calls), 'empty Public IP address');
};

subtest '[az_vm_name_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '["Mirandolina","Truffaldino"]'; });

    my $res = az_vm_name_get(resource_group => 'Arlecchino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm list/ } @calls), 'Correct composition of the main command');
    ok((any { /-g Arlecchino/ } @calls), 'Correct composition of the -g argument');
    ok((any { /Mirandolina/ } @$res), 'Correct result decoding');
};

subtest '[az_vm_instance_view_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '["PowerState/running","VM running"]'; });

    my $res = az_vm_instance_view_get(resource_group => 'Arlecchino', name => 'Mirandolina');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm get-instance-view/ } @calls), 'Correct composition of the main command');
    ok((any { /VM running/ } @$res), 'Correct result decoding');
};

subtest '[az_vm_openport]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_vm_openport(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        port => 80);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm open-port/ } @calls), 'Correct composition of the main command');
    ok((any { /--port 80/ } @calls), 'Correct port argument');
};

subtest '[az_vm_wait_cloudinit]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_vm_wait_cloudinit(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm run-command create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_nic_id_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_nic_id_get(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm show/ } @calls), 'Correct composition of the main command');
    ok(($res eq 'Eugenia'), 'Correct return');
};

subtest '[az_nic_name_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_nic_name_get(
        nic_id => 'Fabrizio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic show/ } @calls), 'Correct composition of the main command');
    ok((any { /--query.*name/ } @calls), 'Correct filter');
    ok(($res eq 'Eugenia'), 'Correct return');
};

subtest '[az_ipconfig_name_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_ipconfig_name_get(
        nic_id => 'Fabrizio');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic show/ } @calls), 'Correct composition of the main command');
    ok((any { /--query.*ipConfigurations.*name/ } @calls), 'Correct filter');
    ok(($res eq 'Eugenia'), 'Correct return');
};

subtest '[az_ipconfig_update]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_ipconfig_update(
        resource_group => 'Arlecchino',
        ipconfig_name => 'Truffaldino',
        nic_name => 'Mirandolina',
        ip => '192.168.0.42');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic ip-config update/ } @calls), 'Correct composition of the main command');
};

subtest '[az_ipconfig_pool_add]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_ipconfig_pool_add(
        resource_group => 'Arlecchino',
        lb_name => 'Pantalone',
        address_pool => 'Clarice',
        ipconfig_name => 'Truffaldino',
        nic_name => 'DottoreLombardi');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic ip-config address-pool add/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_lb_probe_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_network_lb_probe_create(
        resource_group => 'Arlecchino',
        lb_name => 'Pantalone',
        name => 'Clarice',
        port => '4242',
        protocol => 'Udp',
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network lb probe create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_lb_rule_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_network_lb_rule_create(
        resource_group => 'Arlecchino',
        lb_name => 'Pantalone',
        hp_name => 'Truffaldino',
        frontend_ip => 'openqa-fe',
        backend => 'openqa-be',
        name => 'Clarice',
        port => '4242'
    );

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network lb rule create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_vnet_list]' => sub {
    my $mock = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $cmd_out = '[
  "vnet_a",
  "vnet_b"
]';
    $mock->redefine(script_output => sub { push @calls, $_[0]; return $cmd_out; });

    my $result = az_network_vnet_list(resource_group => 'Eugenia');
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /az network vnet list/ } @calls), 'Correct composition of the main command');
    ok((any { /--resource-group Eugenia/ } @calls), 'Argument --resource-group');
    ok((any { /--query \"\[\].name\"/ } @calls), 'Argument --query');
    ok((any { /-o json/ } @calls), 'Return output in json format');

    is ref($result), 'ARRAY', 'Returned value must be an ARRAY';
    foreach ('vnet_a', 'vnet_b') {
         ok((any { /$_/ } @$result), "Function return value must contain '$_'");
    }
};

subtest '[az_network_vnet_subnet_list]' => sub {
    my $mock = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $cmd_out = '[
  "subnet-A",
  "subnet-B"
]';
    $mock->redefine(script_output => sub { push @calls, $_[0]; return $cmd_out; });

    my $result = az_network_vnet_subnet_list(vnet_name => 'Eugenia', resource_group => 'Elisa');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet subnet list/ } @calls), 'Correct composition of the main command');
    ok((any { /--resource-group Elisa/ } @calls), 'Argument --resource-group');
    ok((any { /--vnet-name Eugenia/ } @calls), 'Argument --resource-group');
    ok((any { /--query \"\[\].name\"/ } @calls), 'Argument --query');
    ok((any { /-o json/ } @calls), 'Return output in json format');

    is ref($result), 'ARRAY', 'Returned value must be ARRAY';
    foreach ('subnet-A', 'subnet-B') {
         ok((any { /$_/ } @$result), "Function return value must contain '$_'");
    }
};

subtest '[az_network_nat_gateway_create]' => sub {
    my $mock = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $mock->redefine(assert_script_run => sub {  push @calls, $_[0]; return; });
    $mock->redefine(record_info => sub { return; });
    my %mandatory_args = (
        resource_group => 'Elisa',
        gateway_name => 'Eugenia',
        public_ip => 'Fabrizio'
    );

    az_network_nat_gateway_create(%mandatory_args);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nat gateway create/ } @calls), 'Main command composition');
    ok((any { /--resource-group Elisa/ } @calls), 'Argument --resource-group');
    ok((any { /--name Eugenia/ } @calls), 'Argument --name');
    ok((any { /--public-ip-addresses Fabrizio/ } @calls), 'Argument --public-ip-addresses');
};

subtest '[az_network_nat_gateway_delete]' => sub {
    my $mock = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $mock->redefine(assert_script_run => sub {  push @calls, $_[0]; return; });
    $mock->redefine(record_info => sub { return; });
    my %mandatory_args = (
        resource_group => 'Elisa',
        gateway_name => 'Eugenia'
    );

    az_network_nat_gateway_delete(%mandatory_args);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nat gateway delete/ } @calls), 'Main command composition');
    ok((any { /--resource-group Elisa/ } @calls), 'Argument --resource-group');
    ok((any { /--name Eugenia/ } @calls), 'Argument --name');
};

subtest '[az_network_vnet_subnet_update]' => sub {
    my $mock = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $mock->redefine(assert_script_run => sub {  push @calls, $_[0]; return; });
    $mock->redefine(record_info => sub { return; });
    my %mandatory_args = (
        resource_group => 'Elisa',
        gateway_name => 'Eugenia',
        vnet_name => 'Fabrizio',
        subnet_name => 'Truffaldino'
    );

    az_network_vnet_subnet_update(%mandatory_args);
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet subnet update/ } @calls), 'Main command composition');
    ok((any { /--resource-group Elisa/ } @calls), 'Argument --resource-group');
    ok((any { /--name Truffaldino/ } @calls), 'Argument --name');
    ok((any { /--vnet-name Fabrizio/ } @calls), 'Argument --vnet-name');
    ok((any { /--nat-gateway Eugenia/ } @calls), 'Argument --nat-gateway');
};

done_testing;
