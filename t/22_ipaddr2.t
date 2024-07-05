use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none all);

use sles4sap::ipaddr2;

subtest '[ipaddr2_azure_deployment]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(data_url => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return; });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'Fermi'; });

    ipaddr2_azure_deployment(region => 'Marconi', os => 'Meucci');

    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }

    # Todo : expand it
    ok(($#calls > 0), "There are some command calls");
    ok((none { /az storage account create/ } @calls), 'Do not create storage');
};

subtest '[ipaddr2_azure_deployment] diagnostic' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(data_url => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return; });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Fermi'; });

    ipaddr2_azure_deployment(region => 'Marconi', os => 'Meucci', diagnostic => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az storage account create/ } @calls), 'Create storage');
    ok((any { /az vm boot-diagnostics enable.*vm-01/ } @calls), 'Enable diagnostic for VM1');
    ok((any { /az vm boot-diagnostics enable.*vm-02/ } @calls), 'Enable diagnostic for VM2');
};

subtest '[ipaddr2_destroy]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my $az_called = 0;
    $ipaddr2->redefine(az_group_delete => sub { $az_called = 1; return; });

    ipaddr2_destroy();

    ok(($az_called eq 1), 'az_group_delete called');
};

subtest '[ipaddr2_bastion_key_accept]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });

    my $ret = ipaddr2_bastion_key_accept();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /StrictHostKeyChecking=accept-new/ } @calls), 'Correct call ssh command');
    ok((any { /1\.2\.3\.4/ } @calls), 'Bastion IP in the ssh command');
    ok((scalar @calls eq 2), "Exactly 2 calls and get " . (scalar @calls));
};

subtest '[ipaddr2_bastion_key_accept] without providing the bastion_ip' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    my $ret = ipaddr2_bastion_key_accept(bastion_ip => '1.2.3.4');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /StrictHostKeyChecking=accept-new/ } @calls), 'Correct call ssh command');
    ok((any { /1\.2\.3\.4/ } @calls), 'Bastion IP in the ssh command');
    ok((scalar @calls eq 2), "Exactly 2 calls and get " . (scalar @calls));
};

subtest '[ipaddr2_internal_key_accept]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_bastion_ssh_addr => sub { return 'artom@1.2.3.4'; });

    my $ret = ipaddr2_internal_key_accept();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /StrictHostKeyChecking=accept-new/ } @calls), 'Correct call ssh command');
    ok((any { /1\.2\.3\.4/ } @calls), 'Bastion IP in the ssh command');
    ok((any { /0\.41/ } @calls), 'Internal VM1 IP in the ssh command');
    ok((any { /0\.42/ } @calls), 'Internal VM2 IP in the ssh command');
};

subtest '[ipaddr2_create_cluster]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return 'Moriondo'; });

    ipaddr2_create_cluster();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*41.*cluster init/ } @calls), 'crm cluster init on VM1');
    ok((any { /.*42.*cluster join/ } @calls), 'crm cluster join on VM2');
};

subtest '[ipaddr2_deployment_sanity] Pass' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);


    $azcli->redefine(script_output => sub {
            push @calls, ['azure_cli', $_[0]];
            # Simulate az cli to return 2 resource groups
            # one for the current jobId Volta and another one
            if ($_[0] =~ /az group list*/) { return '["ip2tVolta","ip2tFermi"]'; }
            # Simulate az cli to return exactly one name for the bastion VM name
            if ($_[0] =~ /az vm list*/) { return '["ip2t-vm-bastion", "ip2t-vm-01", "ip2t-vm-02"]'; }
            if ($_[0] =~ /az vm get-instance-view*/) { return '[ "PowerState/running", "VM running" ]'; }
    });

    ipaddr2_deployment_sanity();

    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }
    ok(($#calls > 0), "There are some command calls");
};

subtest '[ipaddr2_deployment_sanity] Fails rg num' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);

    # Simulate az cli to return 2 resource groups
    # one for the current jobId Volta and another one
    $ipaddr2->redefine(get_current_job_id => sub { return 'Majorana'; });
    $azcli->redefine(script_output => sub {
            push @calls, ['azure_cli', $_[0]];
            if ($_[0] =~ /az group list*/) { return '["ip2tVolta","ip2tFermi"]'; }
            if ($_[0] =~ /az vm list*/) { return '["ip2t-vm-bastion"]'; }
    });

    dies_ok { ipaddr2_deployment_sanity() } "Sanity check if there's any rg with the expected name";

    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }
    ok((scalar @calls > 0), "Some calls to script_run and script_output");
};

subtest '[ipaddr2_os_sanity]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ipaddr2->redefine(ipaddr2_get_internal_vm_name => sub { return 'Galileo'; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return 'Galileo'; });
    my @calls;
    $ipaddr2->redefine(script_run => sub {
            push @calls, ['local', $_[0]]; });
    $ipaddr2->redefine(assert_script_run => sub {
            push @calls, ['local', $_[0]]; });
    $ipaddr2->redefine(ipaddr2_ssh_assert_script_run_bastion => sub {
            my (%args) = @_;
            push @calls, ['bastion', $args{cmd}]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}]; });

    ipaddr2_os_sanity();

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_bastion_pubip]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    $ipaddr2->redefine(az_network_publicip_get => sub { return '1.2.3.4'; });
    my $res = ipaddr2_bastion_pubip();
    ok(($res eq '1.2.3.4'), "Expect 1.2.3.4 and get $res");
};

subtest '[ipaddr2_os_connectivity_sanity]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_os_connectivity_sanity();

    note("\n  -->  " . join("\n  -->  ", @calls));
    my $count = 0;
    foreach my $cmd (@calls) {
        $count++ if $cmd =~ m/^ssh/;
    }
    ok(($count eq 12),
        "Expected 2VM * 2address_forms * 3cmd = 12 commands from the bastion and get $count");
};

subtest '[ipaddr2_internal_key_gen]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    # return 1 means file does not exist.
    #$ipaddr2->redefine(script_run => sub { push @calls, $_[0]; return 1; });
    $ipaddr2->redefine(script_output => sub { push @calls, $_[0]; return 'BeniaminoFiammaPubKeyBeniaminoFiammaPubKey'; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_internal_key_gen();

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /ssh-keygen/ } @calls), 'Generate the keys if they does not exist');
};

done_testing;
