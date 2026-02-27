use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none);

use sles4sap::gcp_cli;

subtest '[gcp_network_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    gcp_network_create(
        project => 'flute',
        name => 'my-network');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute networks create/ } @calls), 'Command networks create');
    ok((any { /--project.*flute/ } @calls), 'project parameter is in command');
    ok((any { /--subnet-mode=custom/ } @calls), 'subnet-mode=custom is in command');
};

subtest '[gcp_network_delete]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_network_delete(name => 'my-network');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute networks delete/ } @calls), 'Command networks delete');
    ok((any { /--quiet/ } @calls), 'quiet flag is in command');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_subnet_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    gcp_subnet_create(
        project => 'flute',
        region => 'clarinet',
        name => 'my-subnet',
        network => 'my-network',
        cidr => '10.0.0.0/24');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute networks subnets create/ } @calls), 'Command subnets create');
    ok((any { /--region.*clarinet/ } @calls), 'region parameter is in command');
    ok((any { /--network.*my-network/ } @calls), 'network parameter is in command');
    ok((any { /--range.*10\.0\.0\.0\/24/ } @calls), 'cidr parameter is in command');
};

subtest '[gcp_subnet_delete]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_subnet_delete(
        region => 'clarinet',
        name => 'my-subnet');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute networks subnets delete/ } @calls), 'Command subnets delete');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_firewall_rule_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    gcp_firewall_rule_create(
        project => 'flute',
        name => 'bassoon',
        network => 'my-network',
        port => 22);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute firewall-rules create/ } @calls), 'Command firewall-rules create');
    ok((any { /--allow.*tcp:22/ } @calls), 'allow tcp:22 is in command');
    ok((any { /--source-ranges.*0\.0\.0\.0\/0/ } @calls), 'source-ranges is in command');
};

subtest '[gcp_firewall_rule_delete]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_firewall_rule_delete(name => 'bassoon');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute firewall-rules delete/ } @calls), 'Command firewall-rules delete');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_external_ip_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    gcp_external_ip_create(
        project => 'flute',
        region => 'clarinet',
        name => 'my-ip');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute addresses create/ } @calls), 'Command addresses create');
    ok((any { /--region.*clarinet/ } @calls), 'region parameter is in command');
};

subtest '[gcp_external_ip_delete]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_external_ip_delete(
        region => 'clarinet',
        name => 'my-ip');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute addresses delete/ } @calls), 'Command addresses delete');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_vm_create]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $gcpcli->redefine(script_output => sub { push @calls, $_[0]; return 'bassoonAAAABBBB'; });

    gcp_vm_create(
        project => 'flute',
        zone => 'us-central1-a',
        name => 'my-vm',
        image => 'oboe',
        machine_type => 'saxophone',
        network => 'my-network',
        subnet => 'my-subnet',
        address => 'my-ip',
        ssh_key => 'bassoon.pub');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute instances create/ } @calls), 'Command instances create');
    ok((any { /--zone.*us-central1-a/ } @calls), 'zone parameter is in command');
    ok((any { /--image.*oboe/ } @calls), 'image parameter is in command');
    ok((any { /--machine-type.*saxophone/ } @calls), 'machine-type parameter is in command');
    ok((any { /--network.*my-network/ } @calls), 'network parameter is in command');
    ok((any { /--subnet.*my-subnet/ } @calls), 'subnet parameter is in command');
    ok((any { /--address.*my-ip/ } @calls), 'address parameter is in command');
    ok((any { /--metadata.*ssh-keys.*bassoonAAAABBBB/ } @calls), 'metadata ssh-keys is in command');
};

subtest '[gcp_vm_create] image_project' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $gcpcli->redefine(script_output => sub { return 'bassoonAAAABBBB'; });

    gcp_vm_create(
        project => 'flute',
        zone => 'us-central1-a',
        name => 'my-vm',
        image => 'oboe',
        image_project => 'suse-cloud',
        machine_type => 'saxophone',
        network => 'my-network',
        subnet => 'my-subnet',
        address => 'my-ip',
        ssh_key => 'bassoon.pub');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--image-project.*suse-cloud/ } @calls), 'image-project parameter is in command');
};

subtest '[gcp_vm_create] image invalid format' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $gcpcli->redefine(script_output => sub { return 'bassoonAAAABBBB'; });

    dies_ok {
        gcp_vm_create(
            project => 'flute',
            zone => 'us-central1-a',
            name => 'my-vm',
            image => 'flute/oboe',
            machine_type => 'saxophone',
            network => 'my-network',
            subnet => 'my-subnet',
            address => 'my-ip',
            ssh_key => 'bassoon.pub');
    } 'Invalid image value including the project';

    note("\n  -->  " . join("\n  -->  ", @calls));
};

subtest '[gcp_vm_create] missing arguments' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    $gcpcli->redefine(script_output => sub { return 'bassoonAAAABBBB'; });

    dies_ok {
        gcp_vm_create(
            project => 'flute',
            zone => 'z',
            name => 'n',
            image => 'i',
            image_project => 'ip',
            machine_type => 'saxophone',
            network => 'net',
            subnet => 's',
            ssh_key => '/path/to/key')
    } 'Dies without address';
};

subtest '[gcp_vm_wait_running] success' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_output => sub { push @calls, $_[0]; return 'RUNNING'; });

    my $wait_time = gcp_vm_wait_running(
        zone => 'us-central1-a',
        name => 'my-vm',
        timeout => 60);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute instances describe/ } @calls), 'Command instances describe');
    ok((any { /--format.*get\(status\)/ } @calls), 'format get(status) is in command');
    ok(defined($wait_time), "Wait time is defined: $wait_time");
};

subtest '[gcp_vm_wait_running] timeout' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_output => sub { push @calls, $_[0]; return 'STAGING'; });

    dies_ok {
        gcp_vm_wait_running(
            zone => 'us-central1-a',
            name => 'my-vm',
            timeout => 1);
    } 'Dies on timeout when VM not running';
};

subtest '[gcp_vm_terminate]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_run => sub { push @calls, $_[0]; return 42; });

    my $ret = gcp_vm_terminate(
        zone => 'us-central1-a',
        name => 'my-vm');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute instances delete/ } @calls), 'Command instances delete');
    ok((any { /--quiet/ } @calls), 'quiet flag is in command');
    ok(($ret eq 42), "Return expected 42 get $ret");
};

subtest '[gcp_public_ip_get]' => sub {
    my $gcpcli = Test::MockModule->new('sles4sap::gcp_cli', no_auto => 1);
    my @calls;
    $gcpcli->redefine(script_output => sub { push @calls, $_[0]; return '35.192.0.1'; });

    my $res = gcp_public_ip_get(
        zone => 'us-central1-a',
        name => 'my-vm');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /gcloud compute instances describe/ } @calls), 'Command instances describe');
    ok((any { /--format.*get\(networkInterfaces\[0\]\.accessConfigs\[0\]\.natIP\)/ } @calls), 'format get natIP is in command');
    ok(($res eq '35.192.0.1'), "Result is '$res' expected to be '35.192.0.1'");
};

subtest '[gcp_network_create] missing arguments' => sub {
    dies_ok { gcp_network_create(project => 'flute') } 'Dies without name';
    dies_ok { gcp_network_create(name => 'my-network') } 'Dies without project';
};

subtest '[gcp_subnet_create] missing arguments' => sub {
    dies_ok { gcp_subnet_create(project => 'flute', region => 'clarinet', name => 'n', network => 'net') } 'Dies without cidr';
    dies_ok { gcp_subnet_create(project => 'flute', region => 'clarinet', name => 'n', cidr => 'c') } 'Dies without network';
};


done_testing;

