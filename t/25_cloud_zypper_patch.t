use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none all);

use sles4sap::cloud_zypper_patch;

subtest '[zp_azure_deploy]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);

    my $called = 0;
    $zp->redefine(az_version => sub { $called++; });
    $zp->redefine(zp_azure_resource_group => sub { $called++; return 'SPIAGGIA'; });
    $zp->redefine(az_group_create => sub { $called++; });
    $zp->redefine(az_network_vnet_create => sub { $called++; });
    $zp->redefine(az_network_publicip_create => sub { $called++; });
    $zp->redefine(az_vm_create => sub { $called++; });

    zp_azure_deploy(region => 'SABBIA', os => 'MARE');

    ok $called eq 6;
};

subtest '[zp_azure_deploy] integration test' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    $zp->redefine(get_current_job_id => sub { return 'SPIAGGIA'; });
    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    my @calls;
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'PALETTA'; });

    zp_azure_deploy(region => 'SABBIA', os => 'MARE');

    for my $call_idx (0 .. $#calls) {
        note('sles4sap::' . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }

    # Todo : expand it
    ok $#calls > 0, 'There are some command calls';
};

subtest '[zp_azure_destroy]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my $called = 0;
    $zp->redefine(zp_azure_resource_group => sub { $called++; return 'SPIAGGIA'; });
    $zp->redefine(az_group_delete => sub { $called++; });

    zp_azure_destroy();

    ok $called eq 2;
};

subtest '[zp_azure_destroy] network peering' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my $called = 0;
    $zp->redefine(zp_azure_resource_group => sub { $called++; return 'SPIAGGIA'; });
    $zp->redefine(az_group_delete => sub { $called++; });
    my @vnets = ('ONDE');
    $zp->redefine(az_network_vnet_get => sub { $called++; return \@vnets; });
    $zp->redefine(az_network_peering_delete => sub { $called++; });

    zp_azure_destroy(ibsm_rg => 'PEDALO`');

    ok $called eq 4;
};

subtest '[zp_azure_netpeering]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my $called = 0;
    $zp->redefine(zp_azure_resource_group => sub { $called++; return 'SPIAGGIA'; });
    my @vnets = ('ONDE');
    $zp->redefine(az_network_vnet_get => sub { $called++; return \@vnets; });
    $zp->redefine(az_network_peering_create => sub { $called++; });
    $zp->redefine(az_network_peering_list => sub { $called++; });

    zp_azure_netpeering(target_rg => 'OMBRELLONI');

    ok $called > 0;
};

subtest '[zp_ssh_connect]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });

    zp_ssh_connect();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*StrictHostKeyChecking=accept-new.*cloudadmin\@GRANCHIETTI/ } @calls),
        'StrictHostKeyChecking');
};

subtest '[zp_repos_add]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });
    $zp->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @repos = ('SDRAIO', 'Development-Tools', 'SEDIA', 'ASCIUGAMANO');
    zp_repos_add(
        ip => 'CREMASOLARE',
        name => 'PANINO',
        repos => \@repos);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*zypper.*ar.*TEST_0.*SDRAIO/ } @calls), 'SDRAIO repo is in TEST_0');
    ok((any { /ssh.*zypper.*ar.*TEST_1.*SEDIA/ } @calls), 'SEDIA repo is in TEST_1');
    ok((any { /ssh.*zypper.*ar.*TEST_2.*ASCIUGAMANO/ } @calls), 'ASCIUGAMANO repo is in TEST_2');
};

subtest '[zp_repos_add] no repos' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });
    $zp->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @repos = ();
    zp_repos_add(
        ip => 'CREMASOLARE',
        name => 'PANINO',
        repos => \@repos);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((none { /ssh.*zypper.*ar/ } @calls), 'no repos should be added');
};

subtest '[zp_zypper_patch]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });

    zp_zypper_patch();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*zypper.*patch/ } @calls), 'SDRAIO repo is in TEST_0');
};

subtest '[zp_scc_register]' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });

    zp_scc_register(scc_code => '1234567890');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*registercloudguest --clean/ } @calls), 'registercloudguest --clean is called');
    ok((any { /ssh.*registercloudguest --force-new -r "1234567890"/ } @calls), 'registercloudguest with scc_code is called');
};

subtest '[zp_scc_register] missing scc_code' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    dies_ok { zp_scc_register() } 'dies if scc_code is missing';
};

subtest '[zp_scc_check] registered' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    my @calls;
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });

    # All registered (with various statuses)
    $zp->redefine(script_output => sub {
            push @calls, $_[0];
            return '[{"status":"Registered"}, {"status":"Active"}]';
    });
    my $ret = zp_scc_check();
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*sudo SUSEConnect -s/ } @calls), 'SUSEConnect -s is called for "all registered" case');
    is($ret, 1, 'All modules registered, returns 1');

    # Empty list
    @calls = ();
    $zp->redefine(script_output => sub {
            push @calls, $_[0];
            return '[]';
    });
    $ret = zp_scc_check();
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ssh.*sudo SUSEConnect -s/ } @calls), 'SUSEConnect -s is called for "empty list" case');
    is($ret, 1, 'Empty list of modules, returns 1');
};

subtest '[zp_scc_check] not registered' => sub {
    my $zp = Test::MockModule->new('sles4sap::cloud_zypper_patch', no_auto => 1);
    $zp->redefine(zp_azure_resource_group => sub { return 'SPIAGGIA'; });
    $zp->redefine(az_network_publicip_get => sub { return 'GRANCHIETTI'; });
    $zp->redefine(script_output => sub { return '[{"status":"Registered"}, {"status":"Not Registered"}]'; });
    is(zp_scc_check(), 0, 'One module not registered, returns 0');
};

done_testing;
