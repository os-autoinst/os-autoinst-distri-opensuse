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

subtest '[az_group_delete]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_group_delete(name => 'Arlecchino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az group delete/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_vnet_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_network_vnet_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        vnet => 'Pantalone');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet create/ } @calls), 'Correct composition of the main command');
    ok((any { /--name Pantalone/ } @calls), 'Correct --name argument');
};

subtest '[az_network_vnet_create] vnet snet' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_network_vnet_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        vnet => 'Pantalone',
        snet => 'Colombina');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--name Pantalone/ } @calls), 'Correct --name argument');
    ok((any { /--address-prefixes/ } @calls), 'Present --address-prefixes argument');
    ok((any { /--subnet-name/ } @calls), 'Present --subnet-name argument');
    ok((any { /--subnet-prefixes/ } @calls), 'Present --subnet-prefixes argument');
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

subtest '[az_network_vnet_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '{"name": "Arlecchino"}'; });

    my $res = az_network_vnet_get(resource_group => 'Arlecchino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet list/ } @calls), 'Correct composition of the main command');
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

subtest '[az_vm_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["Mirandolina","Truffaldino"]'; });

    my $res = az_vm_list(resource_group => 'Arlecchino', query => 'ZAMZAM');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm list/ } @calls), 'Correct composition of the main command');
    ok((any { /-g Arlecchino/ } @calls), 'Correct composition of the -g argument');
    ok((any { /Mirandolina/ } @$res), 'Correct result decoding');
};

subtest '[az_vm_list] query' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["Mirandolina","Truffaldino"]'; });

    my $res = az_vm_list(resource_group => 'Arlecchino', query => 'ZAMZAM');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--query.*ZAMZAM/ } @calls), 'Correct composition of the --query argument');
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

subtest '[az_vm_wait_running] running at first try' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '["PowerState/running","VM running"]'; });

    az_vm_wait_running(resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((scalar @calls == 1), 'Calls az cli only once if return is running');
};

subtest '[az_vm_wait_running] running at second try' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $is_first = 1;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            if ($is_first) {
                $is_first = 0;
                return '["PowerState/running","VM starting"]';
            }
            return '["PowerState/running","VM running"]'; });

    az_vm_wait_running(resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((scalar @calls == 2), 'Calls az cli twice if return is not running');
};

subtest '[az_vm_wait_running] never running default timeout' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $is_first = 1;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["PowerState/running","VM starting"]'; });

    my $start_time = time();
    dies_ok {
        az_vm_wait_running(resource_group => 'Arlecchino',
            name => 'Truffaldino');
    } 'Die for timeout after ' . (time() - $start_time);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(((scalar @calls > 8) and (scalar @calls < 12)),
        'Timeout default is 300, sleep is 30. Expected near 10 retry, get ' . (scalar @calls));
};

subtest '[az_vm_wait_running] never running long timeout' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $is_first = 1;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["PowerState/running","VM starting"]'; });

    my $start_time = time();
    dies_ok {
        az_vm_wait_running(resource_group => 'Arlecchino',
            name => 'Truffaldino',
            timeout => 600);
    } 'Die for timeout after ' . (time() - $start_time);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(((scalar @calls > 19) and (scalar @calls < 22)),
        'Timeout is 600, sleep is 30. Expected near 20 retry, get ' . (scalar @calls));
};

subtest '[az_vm_wait_running] never running short' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $is_first = 1;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return '["PowerState/running","VM starting"]'; });

    my $start_time = time();
    dies_ok {
        az_vm_wait_running(resource_group => 'Arlecchino',
            name => 'Truffaldino',
            timeout => 10);
    } 'Die for timeout after ' . (time() - $start_time);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(((scalar @calls > 1) and (scalar @calls < 4)),
        'Timeout is 10, sleep is 5. Expected near 2 retry, get ' . (scalar @calls));
};

subtest '[az_vm_wait_running] missing args' => sub {
    dies_ok { az_vm_wait_running(resource_group => 'Arlecchino') } 'Die for missing argument resource_group';
    dies_ok { az_vm_wait_running(name => 'Truffaldino') } 'Die for missing argument name';
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

subtest '[az_vm_diagnostic_log_enable]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return 'http://storage/Truffaldino'; });
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; });

    az_vm_diagnostic_log_enable(resource_group => 'Arlecchino',
        storage_account => 'Pantalone',
        vm_name => 'Pulcinella');

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /az storage account show/ } @calls), 'Correct composition of the account show command');
    ok((any { /az vm boot-diagnostics enable/ } @calls), 'Correct composition of the enable command');
    ok((any { /enable.*--storage.*Truffaldino/ } @calls), 'Correct argument from one to the other command');
};

subtest '[az_vm_diagnostic_log_get]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            # simulate 2 VM
            return '[{"id": "0001", "name": "Truffaldino"}, {"id": "0002", "name": "Mirandolina"}]'; });
    $azcli->redefine(script_run => sub { push @calls, $_[0]; });

    az_vm_diagnostic_log_get(resource_group => 'Arlecchino');

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /az vm boot-diagnostics get-boot-log/ } @calls), 'Correct composition of the main command');
    ok((any { /--ids 0001.*tee.*Truffaldino\.txt/ } @calls), 'Correct composition of the --id for the first VM');
    ok((any { /--ids 0002.*tee.*Mirandolina\.txt/ } @calls), 'Correct composition of the --id for the second VM');
};

subtest '[az_storage_account_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_storage_account_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        name => 'Cassandro');

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /az storage account create/ } @calls), 'Correct composition of the main command');

};

subtest '[az_network_peering_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '/some/long/id/string'; });
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_network_peering_create(
        name => 'Pantalone',
        source_rg => 'ArlecchinoQui',
        source_vnet => 'TruffaldinoQui',
        target_rg => 'ArlecchinoLi',
        target_vnet => 'TruffaldinoLi');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet show --query id/ } @calls), 'Correct composition of the main command');
    ok((any { /az network vnet peering create/ } @calls), 'Correct composition of the main command');
    ok((any { /--remote-vnet.*\/some\/long\/id\/string/ } @calls), 'Correct target ID');
};

subtest '[az_network_peering_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '{"name": "Arlecchino"}'; });

    my $res = az_network_peering_list(
        resource_group => 'ArlecchinoQui',
        vnet => 'TruffaldinoQui');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet peering list/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_peering_delete]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $res = az_network_peering_delete(
        name => 'Pantalone',
        resource_group => 'ArlecchinoQui',
        vnet => 'TruffaldinoQui');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet peering delete/ } @calls), 'Correct composition of the main command');
};


subtest '[az_disk_create] Create disk by cloning' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka', source => 'Harvepino');
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/az disk create/, @calls), 'Test base command');
    ok(grep(/--resource-group Pa_a_Pi/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name Od_Kuka_do_Kuka/, @calls), 'Check for argument "--name"');
    ok(grep(/--source Harvepino/, @calls), 'Check for argument "--source"');

    az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka', size_gb => '42');
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--size-gb 42/, @calls), 'Check for argument "--size-gb"');
};

subtest '[az_disk_create] Create empty disk defining size' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka', size_gb => '42');
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--size-gb 42/, @calls), 'Check for argument "--size-gb"');
};


subtest '[az_disk_create] Check exceptions' => sub {
    dies_ok { az_disk_create(resource_group => 'Pa_a_Pi', size_gb => '42') } "Croak with missing mandatory argument 'resource_group'";
    dies_ok { az_disk_create(name => 'Od_Kuka_do_Kuka', size_gb => '42') } "Croak with missing mandatory argument 'name'";
    dies_ok { az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka') } "Croak with missing mandatory argument 'size_gb'";
    dies_ok { az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka') } "Croak with missing mandatory argument 'source'";
    dies_ok { az_disk_create(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka', size_gb => '42', source => 'Slovenska_televizia') } "Croak with both 'size_gb' and 'source' defined at the same time";
};

subtest '[az_resource_delete]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_resource_delete(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka');
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/az resource delete/, @calls), 'Test base command');
    ok(grep(/--resource-group Pa_a_Pi/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name Od_Kuka_do_Kuka/, @calls), 'Check for argument "--name"');

    az_resource_delete(resource_group => 'Pa_a_Pi', ids => 'od Kuka do Kuka');
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--ids od Kuka do Kuka/, @calls), 'Check for argument "--ids"');
};

subtest '[az_resource_delete]' => sub {
    dies_ok { az_resource_delete(ids => 'od Kuka do Kuka') } "Dies with missing argument 'resource_group'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi') } "Dies with missing argument 'name'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi') } "Dies with missing argument 'ids'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi', ids => 'od Kuka do Kuka', name => 'Od_Kuka_do_Kuka') }
    "Dies with both 'ids' and 'name' being defined";
};

done_testing;
