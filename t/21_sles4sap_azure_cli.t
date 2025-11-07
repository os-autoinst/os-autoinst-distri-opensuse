use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none);

use sles4sap::azure_cli;

subtest '[az_img_from_vhd_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_img_from_vhd_create(resource_group => 'Mycenaeans', name => 'Agamemnon', source => 'TrojanHorse.vhd');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az image create/ } @calls), 'command creates image');
    ok((any { /--resource-group Mycenaeans/ } @calls), 'RG is correctly used');
    ok((any { /-n Agamemnon/ } @calls), 'name is correctly used');
    ok((any { /--source TrojanHorse.vhd/ } @calls), 'source is correctly used');
};

subtest '[az_group_create] missing args' => sub {
    dies_ok { az_img_from_vhd_create(name => 'Agamemnon', source => 'TrojanHorse.vhd'); } 'Die for missing argument resource_group';
    dies_ok { az_img_from_vhd_create(recource_group => 'Mycenaeans', source => 'TrojanHorse.vhd') } 'Die for missing argument name';
    dies_ok { az_img_from_vhd_create(recource_group => 'Mycenaeans', name => 'Agamemnon') } 'Die for missing argument source';
};

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

subtest '[az_group_name_get] query' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '{"Arlecchino": "Truffaldino"}'; });

    my $res = az_group_name_get(query => 'MASCHERA');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--query.*MASCHERA/ } @calls), 'Correct composition of the query argument');
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
        note('---------------------------- Invalid patterns that NetAddr::IP->new cannot fix');
        foreach my $test_pattern (qw(192.168..0/16 192.068.0.0/16 1192.168.0.0/16)) {
            dies_ok { az_network_vnet_create(
                    resource_group => 'Arlecchino',
                    region => 'Pulcinella',
                    vnet => 'Pantalone',
                    snet => 'Colombina',
                    $arg => $test_pattern) } "Die for invalid IP $test_pattern as argument $arg";
            ok scalar @calls == 0, "No call to assert_script_run, croak before to run the command for invalid IP $test_pattern as argument $arg";
            @calls = ();
        }
        note('---------------------------- Invalid patterns that NetAddr::IP->new can fix');
        foreach my $test_pattern (qw(192.168.0/16 192.168.000.000/16 192.168.0.0)) {
            az_network_vnet_create(
                resource_group => 'Arlecchino',
                region => 'Pulcinella',
                vnet => 'Pantalone',
                snet => 'Colombina',
                $arg => $test_pattern);
            #ok scalar @calls == 0, "No call to assert_script_run, croak before to run the command for invalid IP $test_pattern as argument $arg";
            note("\n NetAddr transforms $test_pattern in -->  " . join("\n  -->  ", @calls));
            @calls = ();
        }
        note('---------------------------- Valid patterns');
        foreach my $test_pattern (qw(192.168.0.0/16 192.0.0.0/16 2.168.0.0/16 10.4.104.0/21)) {
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
    foreach my $test_ip (qw(1.2.3.4 10.12.208.50)) {
        az_network_lb_create(
            resource_group => 'Arlecchino',
            name => 'Truffaldino',
            vnet => 'Pantalone',
            snet => 'Colombina',
            backend => 'Smeraldina',
            frontend_ip_name => 'Momolo',
            fip => $test_ip);
        note("\n  -->  " . join("\n  -->  ", @calls));
        ok((any { /az network lb create/ } @calls), 'Correct composition of the main command for the IP:' . $test_ip);
        @calls = ();
    }
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
            fip => '1.2.3.') } "Die for invalid IP as fip argument '1.2.3.'";
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

subtest '[az_vm_as_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return; });

    az_vm_as_list(resource_group => 'Arlecchino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm availability-set list/ } @calls), 'Correct composition of the main command');
};

subtest '[az_vm_as_show]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_vm_as_show(resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm availability-set show/ } @calls), 'Correct composition of the main command');
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
    ok((none { /--public-ip-address ""/ } @calls), 'not force empty Public IP address');
};

subtest '[az_vm_create] with no public IP' => sub {
    # Here function call is same of the previous test '[az_vm_create]'
    # What is different is that this test has a dedicated
    # expectation check about --public-ip-address
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        image => 'Mirandolina');
    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /--public-ip-address ""/ } @calls), 'empty Public IP address');
};

subtest '[az_vm_create] with empty public IP' => sub {
    # The user can in theory provide a public_ip
    # with an empty string. It doesn't make much sense
    # as the user can obtain the same result without using
    # the public_ip argument at all (like covered by the previous test).
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

subtest '[az_vm_create] SDAF mix' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    my @tags = ('Balanzone', 'CapitanSpaventa');

    az_vm_create(
        resource_group => 'Arlecchino',
        name => 'Truffaldino',
        attach_os_disk => 'Mirandolina',
        size => 'Stenterello',
        os_type => 'Tartaglia',
        tags => \@tags);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm create/ } @calls), 'Correct composition of the main command');
    ok((any { /.*--tags Balanzone CapitanSpaventa/ } @calls), 'Correct composition of tags');
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


subtest '[az_vm_wait_running] running at first try' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return <<'END_REPLY';
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM running",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
    });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $wt = az_vm_wait_running(resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((scalar @calls == 1), 'Calls az cli only once if return is running');
    ok($wt eq 0), "WT:$wt is 0 as expected, as getting the Running state at first attempt.";
};

subtest '[az_vm_wait_running] running at second try' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my @outputs;
    push @outputs, <<'END_REPLY'
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM running",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
      ;
    push @outputs, <<'END_REPLY'
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM starting",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
      ;
    push @outputs, <<'END_REPLY'
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  }
]
END_REPLY
      ;

    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return pop @outputs; });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $wt = az_vm_wait_running(resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    note("--> WT:$wt");
    ok((scalar @calls == 3), 'Calls az cli 3 times until the return value does not contain "VM running"');
    ok($wt > 0), "WT:$wt is greate than 0 as expected.";
};

subtest '[az_vm_wait_running] never running default timeout' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $is_first = 1;
    $azcli->redefine(script_output => sub {
            push @calls, $_[0];
            return <<'END_REPLY';
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM starting",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
    });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

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
            return <<'END_REPLY';
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM starting",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
    });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

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
            return <<'END_REPLY';
[
  {
    "code": "ProvisioningState/succeeded",
    "displayStatus": "Provisioning succeeded",
    "level": "Info",
    "message": null,
    "time": "2025-12-09T13:50:39.894595+00:00"
  },
  {
    "code": "PowerState/running",
    "displayStatus": "VM starting",
    "level": "Info",
    "message": null,
    "time": null
  }
]
END_REPLY
    });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

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

subtest '[az_vm_identity_assign]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '00000000-0000-0000-0000-000000000000'; });

    my $id = az_vm_identity_assign(
        resource_group => 'Arlecchino',
        name => 'Truffaldino');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm identity assign/ } @calls), 'Correct composition of the main command');
    ok(($id eq '00000000-0000-0000-0000-000000000000'), 'Correct returned id');
};

subtest '[az_nic_get_id]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Eugenia'; });
    my $res = az_nic_get_id(
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

subtest '[az_nic_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    az_nic_create(
        resource_group => 'Arlecchino',
        name => 'Fabrizio',
        vnet => 'Pulcinella',
        subnet => 'Colombina',
        nsg => 'Pantalone',
        pubip_name => 'Ottone');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic create/ } @calls), 'Correct composition of the main command');
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

    foreach my $test_ip (qw(192.168.0.42 10.12.208.41)) {
        az_ipconfig_update(
            resource_group => 'Arlecchino',
            ipconfig_name => 'Truffaldino',
            nic_name => 'Mirandolina',
            ip => $test_ip);

        note("\n  -->  " . join("\n  -->  ", @calls));
        ok((any { /az network nic ip-config update/ } @calls), 'Correct composition of the main command');
        @calls = ();
    }
};

subtest '[az_ipconfig_delete]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    az_ipconfig_delete(
        resource_group => 'Arlecchino',
        ipconfig_name => 'Truffaldino',
        nic_name => 'Mirandolina');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network nic ip-config delete/ } @calls), 'Correct composition of the main command');
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
    $azcli->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    my $res = az_network_peering_delete(
        name => 'Pantalone',
        resource_group => 'ArlecchinoQui',
        vnet => 'TruffaldinoQui');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az network vnet peering delete/ } @calls), 'Correct composition of the main command');
};

subtest '[az_disk_create] Create disk by cloning with source' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_disk_create(
        resource_group => 'Pa_a_Pi',
        name => 'Od_Kuka_do_Kuka',
        source => 'Harvepino');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az disk create/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pa_a_Pi/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name Od_Kuka_do_Kuka/, @calls), 'Check for argument "--name"');
    ok(grep(/--source Harvepino/, @calls), 'Check for argument "--source"');
};

subtest '[az_disk_create] Create empty disk defining size' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_disk_create(
        resource_group => 'Pa_a_Pi',
        name => 'Od_Kuka_do_Kuka',
        size_gb => '42');

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

subtest '[az_resource_delete] by name' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_run => sub { return; });
    $azcli->redefine(assert_script_run => sub { return 1; });
    $azcli->redefine(write_sut_file => sub { @calls = $_[1]; return; });

    az_resource_delete(resource_group => 'Pa_a_Pi', name => 'Od_Kuka_do_Kuka');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az resource delete/ } @calls), 'Correct composition of the main command');
    ok((any { /--resource-group Pa_a_Pi/ } @calls), 'Check for argument "--resource-group"');
    ok((any { /--name Od_Kuka_do_Kuka/ } @calls), 'Check for argument "--name"');
};

subtest '[az_resource_delete] by id' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_run => sub { return; });
    $azcli->redefine(assert_script_run => sub { return 1; });
    $azcli->redefine(write_sut_file => sub { @calls = $_[1]; return; });

    az_resource_delete(resource_group => 'Pa_a_Pi', ids => 'odKukadoKuka');

    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--ids odKukadoKuka/, @calls), 'Check for argument "--ids"');
};

subtest '[az_resource_delete]' => sub {
    dies_ok { az_resource_delete(ids => 'od Kuka do Kuka') } "Dies with missing argument 'resource_group'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi') } "Dies with missing argument 'name'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi') } "Dies with missing argument 'ids'";
    dies_ok { az_resource_delete(resource_group => 'Pa_a_Pi', ids => 'od Kuka do Kuka', name => 'Od_Kuka_do_Kuka') }
    "Dies with both 'ids' and 'name' being defined";
};

subtest '[az_network_nat_gateway_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_nat_gateway_create(
        resource_group => 'Arlecchino',
        region => 'Pulcinella',
        name => 'CavaliereDiRipafratta',
        public_ip => 'Fulgenzio');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network nat gateway create/ } @calls), 'Correct composition of the main command');
};

subtest '[az_network_vnet_subnet_update]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_vnet_subnet_update(
        resource_group => 'Arlecchino',
        vnet => 'Pantalone',
        snet => 'Colombina',
        nat_gateway => 'Momolo');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network vnet subnet update/ } @calls), 'Correct composition of the main command');
};

subtest '[az_validate_uuid_pattern] valid UUID' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(diag => sub { return; });
    my @uuid_list = ('c0ffeeee-c0ff-eeee-1234-123456abcdef',
        'C0fFeeee-c0ff-EEEE-1234-123456ABcdEF');

    foreach my $good_uuid (@uuid_list) {
        is az_validate_uuid_pattern(uuid => $good_uuid), $good_uuid, "Return UUID if valid: $good_uuid ";
    }
};

subtest '[az_validate_uuid_pattern] invalid UUID' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(diag => sub { return; });
    my @uuid_list = ('OhCaptainMyCaptain',    # complete nonsense
        'c0ffeee-c0ff-eeee-1234-123456abcdef',    # First 7 characters instead of 8
        'c0ffeeee-c0ff-eeee-xxxx-123456abcde',    # Using non hexadecimal values 'x'
        'c0ffeeee_c0ff-eeee-1234-123456abcdef',    # Underscore instead of dash
        <<'END_MSG'
There is already a lease present.
RequestId:'c0ffeeee-c0ff-eeee-1234-123456abcdef
Time:2025-07-21T00:00:eciapili70Z
ErrorCode:LeaseAlreadyPresent
END_MSG
    );    # A message with a UUID inside, but not a valid UUID
    foreach my $bad_uuid (@uuid_list) {
        is az_validate_uuid_pattern(uuid => $bad_uuid), undef, "Return 'undef' with invalid UUID: $bad_uuid";
    }
};

subtest '[az_resource_list] Check command composition' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '[]'; });

    az_resource_list();

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az resource list/ } @calls), 'Correct composition of the main command');

    az_resource_list(resource_group => 'Carlo', query => '[].Goldoni');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /--resource-group Carlo/ } @calls), 'Check for --resource-group option.');
    ok((any { /--query \"\[].Goldoni\"/ } @calls), 'Check for --query option.');
};

subtest '[az_resource_list] Check return values' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(script_output => sub { return '["Carlo", "Goldoni"]'; });

    my $output = az_resource_list();

    note("\n --> " . join("\n --> ", join(' ', @$output)));
    is join(' ', @$output), 'Carlo Goldoni', 'Check json based output';
};

subtest '[az_storage_blob_upload]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_storage_blob_upload(
        container_name => 'Arlecchino',
        storage_account_name => 'Pantalone',
        file => 'Colombina');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az storage blob upload/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--container-name Arlecchino/, @calls), 'Check for argument "--container-name"');
    ok(grep(/--account-name Pantalone/, @calls), 'Check for argument "--account-name"');
    ok(grep(/--file Colombina/, @calls), 'Check for argument "--file"');
};

subtest '[az_storage_blob_lease_acquire] valid UUID' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    my $uuid = '521fa121-4e04-448e-a8ec-d17e6b9c5e78';
    $azcli->redefine(script_output => sub { @calls = $_[0]; return $uuid; });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = az_storage_blob_lease_acquire(
        container_name => 'Arlecchino',
        storage_account_name => 'Pantalone',
        blob_name => 'Colombina',
        lease_duration => 30
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az storage blob lease acquire/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--container-name Arlecchino/, @calls), 'Check for argument "--container-name"');
    ok(grep(/--account-name Pantalone/, @calls), 'Check for argument "--account-name"');
    ok(grep(/--blob-name Colombina/, @calls), 'Check for argument "--blob-name"');
    ok(grep(/--lease-duration 30/, @calls), 'Check for argument "--lease-duration"');
    ok($ret eq $uuid), "The return value '$ret' is the UUID:'$uuid'";
};

subtest '[az_storage_blob_lease_acquire] invalid UUID' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return 'Pantalone'; });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = az_storage_blob_lease_acquire(
        container_name => 'Arlecchino',
        storage_account_name => 'Pantalone',
        blob_name => 'Colombina',
        lease_duration => 30
    );

    note("\n --> " . join("\n --> ", @calls));
    my $ret_val = $ret // 'undef';
    is $ret, undef, "The return value '$ret_val' is undef as expected";
};

subtest '[az_storage_blob_lease_acquire] valid UUID with error ErrorCode' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '521fa121-4e04-448e-a8ec-d17e6b9c5e78 ErrorCode'; });
    $azcli->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = az_storage_blob_lease_acquire(
        container_name => 'Arlecchino',
        storage_account_name => 'Pantalone',
        blob_name => 'Colombina',
        lease_duration => 30
    );

    note("\n --> " . join("\n --> ", @calls));
    my $ret_val = $ret // 'undef';
    is $ret, undef, "The return value '$ret_val' is undef as expected";
};

subtest '[az_storage_blob_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["Arlecchino", "Pantalone"]'; });

    my $return_value = az_storage_blob_list(
        container_name => 'Arlecchino',
        storage_account_name => 'Pantalone',
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az storage blob list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--container-name Arlecchino/, @calls), 'Check for argument "--container-name"');
    ok(grep(/--account-name Pantalone/, @calls), 'Check for argument "--account-name"');
    ok(grep(/--output json/, @calls), 'Return output in "json" format');
    is(join(' ', @$return_value), 'Arlecchino Pantalone', 'Return correct value');
};

subtest '[az_storage_blob_update]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_run => sub { @calls = @_; return 'wololo'; });

    az_storage_blob_update(
        container_name => 'Arlecchino',
        account_name => 'Pantalone',
        name => 'Colombina'
    );
    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az storage blob update/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--container-name Arlecchino/, @calls), 'Check for argument "--container-name"');
    ok(grep(/--account-name Pantalone/, @calls), 'Check for argument "--account-name"');
    ok(grep(/--output json/, @calls), 'Return output in "json" format');
    ok(grep(/--name Colombina/, @calls), 'Return output in "json" format');

    az_storage_blob_update(
        container_name => 'Arlecchino',
        account_name => 'Pantalone',
        name => 'Colombina',
        lease_id => '12345'
    );
    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--lease-id 12345/, @calls), 'Check for argument "--lease-id"');
};

subtest '[az_keyvault_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["Arlecchino", "Pantalone"]'; });

    my $return_value = az_keyvault_list(
        resource_group => 'Arlecchino',
        query => '[].Pantalone',
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az keyvault list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--resource-group Arlecchino/, @calls), 'Check for argument "--resource_group"');
    ok(grep(/--query \[\].Pantalone/, @calls), 'Check for argument "--query"');
    ok(grep(/--output json/, @calls), 'Return output in "json" format');
    is(join(' ', @$return_value), 'Arlecchino Pantalone', 'Return correct value');
};

subtest '[az_keyvault_list] Test exception' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(croak => sub { @calls = $_[0]; die; });

    dies_ok { az_keyvault_list() } 'Fail with missing "resource_group" argument';
    ok(grep(/resource_group/, @calls), 'Check if test fails for correct reason - Missing resource group argument');
};

subtest '[az_keyvault_secret_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["Arlecchino", "Pantalone"]'; });

    my $return_value = az_keyvault_secret_list(
        vault_name => 'Arlecchino',
        query => '[].Pantalone',
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az keyvault secret list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--vault-name Arlecchino/, @calls), 'Check for argument "--vault-name"');
    ok(grep(/--query \[\].Pantalone/, @calls), 'Check for argument "--query"');
    ok(grep(/--output json/, @calls), 'Return output in "json" format');
    is(join(' ', @$return_value), 'Arlecchino Pantalone', 'Return correct value');
};

subtest '[az_keyvault_secret_list] Test exception' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(croak => sub { @calls = $_[0]; die; });

    dies_ok { az_keyvault_secret_list() } 'Fail with missing "resource_group" argument';
    ok(grep(/vault_name/, @calls), 'Check if test fails for correct reason - Missing vault name argument');
};

subtest '[az_keyvault_secret_show] Test exception' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(croak => sub { note("\n --> " . join("\n --> ", $_[0])); die; });
    dies_ok { az_keyvault_secret_show(id => '123', vault_name => 'Arlecchino', name => 'Colombina') }
    'Fail with mutually exclusive arguments defined';
    dies_ok { az_keyvault_secret_show(vault_name => 'Pantalone') } 'Fail with missing "name" argument';
    dies_ok { az_keyvault_secret_show(name => 'Colombina') } 'Fail with missing "vault_name" argument';
    dies_ok { az_keyvault_secret_show() } 'Fail with missing "id" argument';
};

subtest '[az_keyvault_secret_show] Calling with "id" argument' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return 'SUper$ecretStuffAnD_even_m0re_secret$tuFF'; });

    az_keyvault_secret_show(id => 'Arlecchino');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az keyvault secret show/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--id Arlecchino/, @calls), 'Check for argument "--id"');
    ok(grep(/--query value/, @calls), 'Check for argument "--query"');
    ok(grep(/--output tsv/, @calls), 'Return output in "tsv" format');
};

subtest '[az_keyvault_secret_show] Calling with "name" and "vault_name" arguments' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '"SUper$ecretStuffAnD_even_m0re_secret$tuFF"'; });

    my $result = az_keyvault_secret_show(name => 'Arlecchino', vault_name => 'Pantalone', output => 'json');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az keyvault secret show/ } @calls), 'Correct composition of the main command');
    ok(grep(/--only-show-errors/, @calls), 'Check for argument "--only-show-errors"');
    ok(grep(/--name Arlecchino/, @calls), 'Check for argument "--name"');
    ok(grep(/--vault-name Pantalone/, @calls), 'Check for argument "--vault-name"');
    ok(grep(/--query value/, @calls), 'Check for argument "--query"');
    ok(grep(/--output json/, @calls), 'Return output in "json" format');
    is $result, 'SUper$ecretStuffAnD_even_m0re_secret$tuFF', 'Decode JSON output';
};

subtest '[az_group_exists] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return 'Arlecchino'; });

    my $ret = az_group_exists(name => 'Pantalone');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az group exists/ } @calls), 'Correct composition of the main command');
    ok((grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"'), 'Correct argument about resource group name');
    ok(($ret eq 'Arlecchino'), "Correct return code: expect 'Arlecchino' get '$ret'");
};

subtest '[az_nic_list] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '[]'; });

    az_nic_list(resource_group => 'Pantalone');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network nic list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--query "\[].name"/, @calls), 'Check for default query');
};

subtest '[az_nic_list] Optional args' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '[]'; });

    az_nic_list(resource_group => 'Pantalone', query => '[].calzini');

    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--query "\[].calzini"/, @calls), 'Check for optional argument "--query"');
};


subtest '[az_network_vnet_show] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '[]'; });

    az_network_vnet_show(resource_group => 'Pantalone', name => 'calzini');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network vnet show/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name calzini/, @calls), 'Check for argument "--name"');
};

subtest '[az_network_vnet_show] Optional arg' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '[]'; });

    az_network_vnet_show(resource_group => 'Pantalone', name => 'calzini', query => 'id');

    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--query "id"/, @calls), 'Check for argument "--query"');
};

subtest '[az_network_dns_zone_create] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_dns_zone_create(resource_group => 'Pantalone', name => 'calzini');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns zone create/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name calzini/, @calls), 'Check for argument "--name"');
};

subtest '[az_network_dns_zone_delete] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_dns_zone_delete(resource_group => 'Pantalone', zone_name => 'calzini');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns zone delete/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--name calzini/, @calls), 'Check for argument "--name"');
    ok(grep(/--yes/, @calls), 'Autoapprove option "--yes"');
};

subtest '[az_network_dns_add_record] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_dns_add_record(
        resource_group => 'Pantalone',
        zone_name => 'opensuse.org',
        record_name => 'openqa',
        ip_addr => '192.168.1.5'
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns record-set a add-record/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--zone-name opensuse.org/, @calls), 'Check for argument "--zone-name"');
    ok(grep(/--record-set-name openqa/, @calls), 'Check for argument "--record-set-name"');
    ok(grep(/--ipv4-address 192.168.1.5/, @calls), 'Check for argument "--ipv4-address"');
};

subtest '[az_network_dns_link_create] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_dns_link_create(
        resource_group => 'Pantalone',
        zone_name => 'opensuse.org',
        vnet => 'vnet_rg',
        name => 'link_to_rg_vnet'
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns link vnet create/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--zone-name opensuse.org/, @calls), 'Check for argument "--zone-name"');
    ok(grep(/--virtual-network vnet_rg/, @calls), 'Check for argument "--virtual-network"');
    ok(grep(/--name link_to_rg_vnet/, @calls), 'Check for argument "--name"');
    ok(grep(/--registration-enabled true/, @calls), 'Check for argument "--auto-registration"');
};

subtest '[az_network_dns_zone_list] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["zone1", "zone2"]'; });

    az_network_dns_zone_list(resource_group => 'Pantalone');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns zone list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--query "\[].name"/, @calls), 'Check for default argument "--query" value');
};

subtest '[az_network_dns_zone_list] check custom query' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["zone1", "zone2"]'; });

    az_network_dns_zone_list(resource_group => 'Pantalone', query => '[].id');

    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--query "\[].id"/, @calls), 'Check for custom argument "--query" value');
};

subtest '[az_network_dns_link_list] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["zone1", "zone2"]'; });

    az_network_dns_link_list(resource_group => 'Pantalone', zone_name => 'opensuse.org');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns link vnet list/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--zone-name opensuse.org/, @calls), 'Check for argument "--zone-name"');
    ok(grep(/--query "\[].name"/, @calls), 'Check for custom argument "--query" value');
};

subtest '[az_network_dns_link_list] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { @calls = $_[0]; return '["zone1", "zone2"]'; });

    az_network_dns_link_list(resource_group => 'Pantalone', zone_name => 'opensuse.org', query => '[].id');

    note("\n --> " . join("\n --> ", @calls));
    ok(grep(/--query "\[].id"/, @calls), 'Check for custom argument "--query" value');
};

subtest '[az_network_dns_link_delete] Compose command' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });

    az_network_dns_link_delete(
        resource_group => 'Pantalone',
        zone_name => 'opensuse.org',
        link_name => 'link_to_rg_vnet'
    );

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az network private-dns link vnet delete/ } @calls), 'Correct composition of the main command');
    ok(grep(/--resource-group Pantalone/, @calls), 'Check for argument "--resource-group"');
    ok(grep(/--zone-name opensuse.org/, @calls), 'Check for argument "--zone-name"');
    ok(grep(/--name link_to_rg_vnet/, @calls), 'Check for argument "--name"');
    ok(grep(/--yes/, @calls), 'Check for autoapprove argument "--yes"');
};

subtest '[az_account_show]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '"00000000-0000-0000-0000-000000000000"'; });

    my $ret = az_account_show();

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az account show/ } @calls), 'Correct composition of the main command');
    ok(($ret eq '00000000-0000-0000-0000-000000000000'), 'Ret is the expected value, of type string');
};

subtest '[az_role_definition_list]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return '["Pantalone"]'; });

    my $ret = az_role_definition_list(name => 'Pulcinella');

    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az role definition list/ } @calls), 'Correct composition of the main command');
    ok((any { /\[\?roleName=='Pulcinella'\]\.id/ } @calls), 'Query uses roleName filter');
    ok(($ret eq 'Pantalone'), 'Ret is the expected value, of type string');
};

subtest '[az_role_assignment_create]' => sub {
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { @calls = $_[0]; return; });
    az_role_assignment_create(
        vm_id => '123456',
        role_id => 'aaa-bbb-ccc',
        subscription_id => 'f0123-a0123',
        resource_group => 'hanasr-jobid12345');
    note("\n --> " . join("\n --> ", @calls));
    ok((any { /az role assignment create/ } @calls), 'Correct composition of the main command');
};

done_testing;
