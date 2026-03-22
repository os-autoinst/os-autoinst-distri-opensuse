use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::MockObject;
use Test::Mock::Time;
use List::Util qw(any none all);
use testapi qw(set_var);
use publiccloud::instance;

use sles4sap::crash;

subtest '[crash_deploy_azure]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(az_vm_wait_running => sub { return; });
    my @calls;
    my $azure = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azure->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    crash_deploy_azure(region => 'AmanitaMuscaria', os => 'CortinariusCinnabarinus');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az vm create/ } @calls), 'There is one VM create');
    ok((all { !/--resource-group/ || /--resource-group crashRussulaEmetica/ } @calls), 'All az calls use correct resource group');
};

subtest '[crash_deploy_aws]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    my @calls;
    my $aws = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $aws->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $aws->redefine(script_output => sub { push @calls, $_[0]; return 'LactariusTorminosus'; });
    $aws->redefine(script_retry => sub { push @calls, $_[0]; return 0; });

    my $id = crash_deploy_aws(
        region => 'SclerodermaCitrinum',
        image_name => 'RubroboletusSatanas',
        image_owner => 'TricholomaEquestre',
        ssh_pub_key => 'EntolomaSinuatum',
        instance_type => 'RussulaEmetica');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /run-instance/ } @calls), 'Run VM');
};

subtest '[crash_deploy_gcp]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(gcp_vm_wait_running => sub { return; });
    my @calls;
    my $gcp = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcp->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $gcp->redefine(script_output => sub {
            push @calls, $_[0];
            return 'ssh-rsa GyromitraEsculentaGyromitraEsculentaGyromitraEsculentaGyromitraEsculenta'; });

    my $id = crash_deploy_gcp(
        region => 'SclerodermaCitrinum',
        availability_zone => 'AmanitaExitialis',
        project => 'CalonariusSplendens',
        image_name => 'RubroboletusSatanas',
        image_project => 'CortinariusOrellanus',
        machine_type => 'GalerinaMarginata',
        ssh_pub_key => 'EntolomaSinuatum');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute networks create/ } @calls), 'gcloud networks create');
    ok((any { /gcloud compute networks subnets create/ } @calls), 'gcloud subnets create');
    ok((any { /gcloud compute firewall-rules create/ } @calls), 'gcloud firewall-rules create');
    ok((any { /gcloud compute addresses create/ } @calls), 'gcloud addresses create');
    ok((any { /gcloud compute instances create/ } @calls), 'gcloud instances create');
    ok((all { !/--project/ || /--project CalonariusSplendens/ } @calls), 'All gcloud calls use correct project');
};

subtest '[crash_pubip] not supported csp' => sub {
    dies_ok { crash_pubip(provider => 'HelvellaDryophila', region => 'AmanitaFalloide') };
};

subtest '[crash_pubip] AZURE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(crash_deploy_name => sub { return 'ImperatorTorosus'; });
    my @calls;
    my $azure = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azure->redefine(script_output => sub {
            push @calls, $_[0];
            return 'Inoc.ybe.Geo.phylla'; });

    my $res = crash_pubip(provider => 'AZURE', region => 'AmanitaFalloide');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(($res eq 'Inoc.ybe.Geo.phylla'), "Expected 'Inoc.ybe.Geo.phylla' IP address and get $res");
};

subtest '[crash_pubip] EC2' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(crash_deploy_name => sub { return 'ImperatorTorosus'; });
    my @calls;
    my $aws = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $aws->redefine(script_output => sub {
            push @calls, $_[0];
            return 'Inoc.ybe.Geo.phylla'; });

    my $res = crash_pubip(provider => 'EC2', region => 'AmanitaFalloide');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(($res eq 'Inoc.ybe.Geo.phylla'), "Expected 'Inoc.ybe.Geo.phylla' IP address and get $res");
};

subtest '[crash_pubip] GCP' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(crash_deploy_name => sub { return 'ImperatorTorosus'; });
    my @calls;
    my $gcp = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcp->redefine(script_output => sub {
            push @calls, $_[0];
            return 'GyromitraEsculenta'; });

    my $res = crash_pubip(
        provider => 'GCE',
        region => 'AmanitaFalloide',
        availability_zone => 'AmanitaExitialis');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(($res eq 'GyromitraEsculenta'), "Expected 'GyromitraEsculenta' and get $res");
};

subtest '[crash_get_username]' => sub {
    is(crash_get_username(provider => 'GCE'), 'cloudadmin', 'GCE username');
    is(crash_get_username(provider => 'AZURE'), 'cloudadmin', 'AZURE username');
    is(crash_get_username(provider => 'EC2'), 'ec2-user', 'EC2 username');
};

subtest '[crash_get_username] invalid csp' => sub {
    dies_ok { crash_get_username(provider => 'INVALID') };
};

subtest '[crash_get_instance]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(crash_pubip => sub { return 'Inoc.ybe.Geo.phylla'; });
    $crash->redefine(crash_get_username => sub { return 'cloudadmin'; });
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(aws_vm_get_id => sub { return 'AmanitaBisporigera'; });
    my $mock_instance = Test::MockObject->new();
    my @new_args;
    my $instance_mock = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instance_mock->redefine(new => sub {
            my ($class, %args) = @_;
            push @new_args, \%args;
            return $mock_instance; });

    my $res = crash_get_instance(provider => 'EC2', region => 'AmanitaFalloide');
    is($res, $mock_instance, 'Returns instance object');
    is($new_args[0]->{public_ip}, 'Inoc.ybe.Geo.phylla', 'Correct public_ip passed to new');
    is($new_args[0]->{username}, 'cloudadmin', 'Correct username passed to new');
    is($new_args[0]->{instance_id}, 'AmanitaBisporigera', 'Correct instance_id passed to new');
};

subtest '[crash_get_instance] GCE with availability_zone' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    my $mock_instance = Test::MockObject->new();
    my @new_args;
    my $instance_mock = Test::MockModule->new('publiccloud::instance', no_auto => 1);
    $instance_mock->redefine(new => sub {
            my ($class, %args) = @_;
            push @new_args, \%args;
            return $mock_instance; });

    my @calls;
    my $gcp = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcp->redefine(script_output => sub {
            push @calls, $_[0];
            return 'Inoc.ybe.Geo.phylla'; });

    my $res = crash_get_instance(
        provider => 'GCE',
        region => 'AmanitaFalloide',
        availability_zone => 'AmanitaExitialis');

    note("\n  -->  " . join("\n  -->  ", @calls));
    is($res, $mock_instance, 'Returns instance object');
    is($new_args[0]->{public_ip}, 'Inoc.ybe.Geo.phylla', 'Correct public_ip passed to new');
    is($new_args[0]->{username}, 'cloudadmin', 'Correct username passed to new');
    is($new_args[0]->{instance_id}, 'crashRussulaEmetica-vm', 'Correct instance_id passed to new');
};

subtest '[crash_cleanup] AZURE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @calls;
    my $azure = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azure->redefine(assert_script_run => sub {
            my ($cmd, %args) = @_;
            push @calls, $cmd;
            return; });
    $azure->redefine(script_run => sub {
            my ($cmd, %args) = @_;
            push @calls, $cmd;
            return 0; });

    crash_cleanup(provider => 'AZURE', region => 'reg1');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az group delete --name crashRussulaEmetica/ } @calls), 'Correct resource group deleted via crash_cleanup');
};

subtest '[crash_cleanup] GCE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my @calls;
    my $gcp = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcp->redefine(assert_script_run => sub {
            my ($cmd, %args) = @_;
            push @calls, $cmd;
            return; });
    $gcp->redefine(script_run => sub {
            my ($cmd, %args) = @_;
            push @calls, $cmd;
            return 0; });
    $gcp->redefine(script_output => sub {
            my ($cmd, %args) = @_;
            push @calls, $cmd;
            return 'crashRussulaEmetica-spoke'; });

    my $ret = crash_cleanup(provider => 'GCE', region => 'reg1', availability_zone => 'AmanitaExitialis');

    note("\n  -->  " . join("\n  -->  ", @calls));
    is($ret, 0, 'Returns 0 on success via crash_cleanup');
    ok((any { /gcloud compute instances delete crashRussulaEmetica-vm/ } @calls), 'VM terminated');
    ok((any { /gcloud compute addresses delete crashRussulaEmetica-ip/ } @calls), 'IP deleted');
    ok((any { /gcloud compute firewall-rules delete crashRussulaEmetica-allow-ssh/ } @calls), 'Firewall deleted');
    ok((any { /gcloud compute networks subnets delete crashRussulaEmetica-subnet/ } @calls), 'Subnet deleted');
    ok((any { /gcloud compute networks delete crashRussulaEmetica-network/ } @calls), 'Network deleted');
};

subtest '[crash_cleanup] EC2' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    my @calls;
    my $aws = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $aws->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $aws->redefine(script_output => sub { push @calls, $_[0]; return 'LactariusTorminosus'; });

    my $ret = crash_cleanup(provider => 'EC2', region => 'SclerodermaCitrinum');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-.*/ } @calls), 'Delete something via crash_cleanup');
    ok(($ret == 0), "Expected ret:0 and get $ret");
};

subtest '[crash_cleanup] EC2 failure' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    my @calls;
    my $aws = Test::MockModule->new('sles4sap::aws_cli', no_auto => 1);
    $aws->redefine(script_run => sub { push @calls, $_[0]; return 42; });
    $aws->redefine(script_output => sub { push @calls, $_[0]; return 'LactariusTorminosus'; });

    my $ret = crash_cleanup(provider => 'EC2', region => 'SclerodermaCitrinum');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /aws ec2 delete-.*/ } @calls), 'Delete something even if failure via crash_cleanup');
    ok(($ret == 42), "Expected ret:42 and get $ret");
};

subtest '[crash_system_ready]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    my @calls;
    $crash->redefine(script_run => sub { push @calls, $_[0]; return 0; });

    crash_system_ready(ssh_command => 'LactariusTorminosus');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /is-system-running/ } @calls), 'There is one VM create');
};

subtest '[crash_softrestart]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    my $mock_pc = Test::MockObject->new();
    $mock_pc->set_true('wait_for_ssh');
    my @calls;
    $mock_pc->mock('ssh_assert_script_run', sub {
            my ($self, %args) = @_;
            push @calls, $args{cmd};
            return; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    crash_softrestart(instance => $mock_pc);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /shutdown.*\-r/ } @calls), 'Shutdown command');
};

subtest '[crash_wait_back]' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    my @calls;
    $crash->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $crash->redefine(script_output => sub { push @calls, $_[0]; return ''; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    crash_wait_back(vm_ip => 'SchizophyllumCommune', username => 'TricholomaSulphureum');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /nc.*Schizophyllum.*22/ } @calls), 'Call nc with provided mushroom');
};

subtest '[crash_wait_back] no nc' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    my @calls;
    $crash->redefine(script_run => sub { push @calls, $_[0]; return 1; });
    $crash->redefine(script_output => sub { push @calls, $_[0]; return ''; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    dies_ok { crash_wait_back(vm_ip => 'SchizophyllumCommune', username => 'TricholomaSulphureum') };

    note("\n  -->  " . join("\n  -->  ", @calls));
};

subtest '[crash_wait_back] failed services' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    my @calls;
    $crash->redefine(script_run => sub { push @calls, $_[0]; return 0; });
    $crash->redefine(script_output => sub { push @calls, $_[0]; return 'SuillusGranulatus.service '; });
    $crash->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    dies_ok { crash_wait_back(vm_ip => 'SchizophyllumCommune', username => 'TricholomaSulphureum') };

    note("\n  -->  " . join("\n  -->  ", @calls));
};

subtest '[crash_network_peering_create] AZURE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(crash_pubip => sub { return 'Inoc.ybe.Geo.phylla'; });
    $crash->redefine(crash_get_username => sub { return 'cloudadmin'; });
    $crash->redefine(assert_script_run => sub { });

    my @peering_args;
    $crash->redefine(ibsm_network_peering_azure_create => sub {
            my (%args) = @_;
            push @peering_args, \%args;
    });

    crash_network_peering_create(
        provider => 'AZURE',
        ibsm_ip => '10.0.0.1',
        region => 'westeurope',
        ibsm_rg => 'IBSmRg');

    is(scalar @peering_args, 1, 'ibsm_network_peering_azure_create called once');
    is($peering_args[0]->{ibsm_rg}, 'IBSmRg', 'Correct ibsm_rg passed');
    is($peering_args[0]->{sut_rg}, 'crashRussulaEmetica', 'Correct sut_rg derived from job id');
};

subtest '[crash_network_peering_create] GCE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });
    $crash->redefine(crash_pubip => sub { return 'GyromitraEsculenta'; });
    $crash->redefine(crash_get_username => sub { return 'cloudadmin'; });
    $crash->redefine(assert_script_run => sub { });

    my @spoke_args;
    $crash->redefine(ibsm_network_peering_gcp_create => sub {
            my (%args) = @_;
            push @spoke_args, \%args;
    });

    crash_network_peering_create(
        provider => 'GCE',
        ibsm_ip => '10.0.0.2',
        region => 'us-central1',
        availability_zone => 'a',
        project => 'CalonariusSplendens',
        ibsm_ncc_hub => 'projects/ibsm-project/locations/global/hubs/ibsm-hub');

    is(scalar @spoke_args, 1, 'ibsm_network_peering_gcp_create called once');
    is($spoke_args[0]->{ibsm_ncc_hub}, 'projects/ibsm-project/locations/global/hubs/ibsm-hub', 'Correct hub URI');
    is($spoke_args[0]->{sut_project}, 'CalonariusSplendens', 'Correct sut_project');
    is($spoke_args[0]->{sut_network}, 'crashRussulaEmetica-network', 'Correct sut_network derived from job id');
    is($spoke_args[0]->{spoke_name}, 'crashRussulaEmetica-spoke', 'Correct spoke_name derived from job id');
};

subtest '[crash_network_peering_create] unsupported provider' => sub {
    dies_ok {
        crash_network_peering_create(provider => 'EC2', ibsm_ip => '1.2.3.4', region => 'r')
    } 'Dies for EC2 provider';
    dies_ok {
        crash_network_peering_create(provider => 'FUNGUS', ibsm_ip => '1.2.3.4', region => 'r')
    } 'Dies for unsupported provider';
};

subtest '[crash_network_peering_create] missing arguments' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(crash_pubip => sub { return '1.2.3.4'; });
    $crash->redefine(crash_get_username => sub { return 'cloudadmin'; });
    $crash->redefine(ibsm_network_peering_azure_create => sub { });
    $crash->redefine(ibsm_add_host_entry_and_repos => sub { });
    $crash->redefine(assert_script_run => sub { });

    dies_ok {
        crash_network_peering_create(provider => 'AZURE', ibsm_ip => '1.2.3.4', region => 'r')
    } 'Dies when AZURE without ibsm_rg';
    dies_ok {
        crash_network_peering_create(provider => 'GCE', ibsm_ip => '1.2.3.4', region => 'r',
            availability_zone => 'a', project => 'p')
    } 'Dies when GCE without ibsm_ncc_hub';
};

subtest '[crash_network_peering_delete] AZURE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });

    my @delete_args;
    $crash->redefine(ibsm_network_peering_azure_delete => sub {
            my (%args) = @_;
            push @delete_args, \%args;
    });

    crash_network_peering_delete(provider => 'AZURE', ibsm_rg => 'IBSmRg');

    is(scalar @delete_args, 1, 'ibsm_network_peering_azure_delete called once');
    is($delete_args[0]->{ibsm_rg}, 'IBSmRg', 'Correct ibsm_rg passed');
    is($delete_args[0]->{sut_rg}, 'crashRussulaEmetica', 'Correct sut_rg derived from job id');
};

subtest '[crash_network_peering_delete] GCE' => sub {
    my $crash = Test::MockModule->new('sles4sap::crash', no_auto => 1);
    $crash->redefine(get_current_job_id => sub { return 'RussulaEmetica'; });

    my @delete_args;
    $crash->redefine(ibsm_network_peering_gcp_delete => sub {
            my (%args) = @_;
            push @delete_args, \%args;
    });

    crash_network_peering_delete(provider => 'GCE');

    is(scalar @delete_args, 1, 'ibsm_network_peering_gcp_delete called once');
    is($delete_args[0]->{spoke_name}, 'crashRussulaEmetica-spoke', 'Correct spoke_name derived from job id');
};

subtest '[crash_network_peering_delete] unsupported provider' => sub {
    dies_ok {
        crash_network_peering_delete(provider => 'EC2')
    } 'Dies for EC2 provider';
};

subtest '[crash_network_peering_delete] missing arguments' => sub {
    dies_ok { crash_network_peering_delete() } 'Dies without provider';
    dies_ok {
        crash_network_peering_delete(provider => 'AZURE')
    } 'Dies when AZURE without ibsm_rg';
};

done_testing;
