use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;
use List::Util qw(any none all);
use testapi qw(set_var);

use sles4sap::ipaddr2;

subtest '[ipaddr2_infra_deploy]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(ipaddr2_cloudinit_create => sub { return '/tmp/Faggin'; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'Fermi'; });

    ipaddr2_infra_deploy(region => 'Marconi', os => 'Meucci');

    # push the list of commands in another list, this one without the source
    # In this way it is easier to inspect the content
    my @cmds;
    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
        push @cmds, $calls[$call_idx][1];
    }

    ok(($#calls > 0), "There are some command calls");
    ok((none { /az storage account create/ } @cmds), 'Do not create storage');
    ok((none { /az vm create.*custom-data/ } @cmds),
        'No cloudinit_profile provided so az vm create has no custom-data. Cloud-init disabled by default');
    ok((none { /sudo cloud-init status/ } @cmds),
        'No cloudinit_profile. Cloud-init disabled by default');
};

subtest '[ipaddr2_infra_deploy] cloudinit_profile' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'Fermi'; });

    ipaddr2_infra_deploy(
        region => 'Marconi',
        os => 'Meucci:gen2:ByoS',
        cloudinit_profile => '/AAAAA/BBBBB');

    # push the list of commands in another list, this one without the source
    # In this way it is easier to inspect the content
    my @cmds;
    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
        push @cmds, $calls[$call_idx][1];
    }

    # Todo : expand it
    ok(($#calls > 0), "There are some command calls");
    ok((any { /az vm create.*custom-data/ } @cmds), 'custom-data in az vm create when cloud-init is enabled');
    ok((any { /sudo cloud-init status/ } @cmds), 'wait cloud-init when cloud-init is enabled');
};

subtest '[ipaddr2_infra_deploy] no cloud-init' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(data_url => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'Fermi'; });

    ipaddr2_infra_deploy(region => 'Marconi', os => 'Meucci:gen2:ByoS');

    # push the list of commands in another list, this one without the source
    # In this way it is easier to inspect the content
    my @cmds;
    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
        push @cmds, $calls[$call_idx][1];
    }

    # Todo : expand it
    ok(($#calls > 0), "There are some command calls");
    ok((none { /az vm create.*custom-data/ } @cmds), 'Cloud-init disabled');
    ok((none { /sudo cloud-init status/ } @cmds), 'Cloud-init disabled');
};

subtest '[ipaddr2_infra_deploy] diagnostic' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(write_sut_file => sub { return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Fermi'; });

    ipaddr2_infra_deploy(region => 'Marconi', os => 'Meucci', diagnostic => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /az storage account create/ } @calls), 'Create storage');
    ok((any { /az vm boot-diagnostics enable.*vm-01/ } @calls), 'Enable diagnostic for VM1');
    ok((any { /az vm boot-diagnostics enable.*vm-02/ } @calls), 'Enable diagnostic for VM2');
};

subtest '[ipaddr2_infra_deploy] disable trusted launch' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(write_sut_file => sub { return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub {
            push @calls, $_[0] if $_[0] =~ /az vm create/;
            return; });
    $azcli->redefine(script_output => sub { push @calls, $_[0]; return 'Fermi'; });

    ipaddr2_infra_deploy(region => 'Marconi', os => 'Meucci', trusted_launch => 0);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /--security-type.*Standard/ } @calls), 'Disable trustedLaunch by setting --security-type Standard');
};

subtest '[ipaddr2_infra_deploy] with .vhd' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ['ipaddr2', $_[0]]; return; });
    $ipaddr2->redefine(az_vm_wait_running => sub { return 300; });
    $ipaddr2->redefine(ipaddr2_cloudinit_create => sub { return '/tmp/Faggin'; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $azcli = Test::MockModule->new('sles4sap::azure_cli', no_auto => 1);
    $azcli->redefine(assert_script_run => sub { push @calls, ['azure_cli', $_[0]]; return; });
    $azcli->redefine(script_output => sub { push @calls, ['azure_cli', $_[0]]; return 'Fermi'; });

    ipaddr2_infra_deploy(region => 'Sithonia', os => 'Toroni.vhd');

    # push the list of commands in another list, this one without the source
    # In this way it is easier to inspect the content
    my @cmds;
    for my $call_idx (0 .. $#calls) {
        note("sles4sap::" . $calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
        push @cmds, $calls[$call_idx][1];
    }

    ok(($#calls > 0), "There are some command calls");
    ok(any { /az image create/ } @calls, 'az image create is called');
};

subtest '[ipaddr2_infra_destroy]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(get_current_job_id => sub { return 'Volta'; });
    my $az_called = 0;
    $ipaddr2->redefine(az_group_delete => sub { $az_called = 1; return; });

    ipaddr2_infra_destroy();

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
    $ipaddr2->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /nc.*22/) { return 0; }
            if ($_[0] =~ /ssh.*accept-new/) { return 0; }
            return 1; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_bastion_ssh_addr => sub { return 'AlessandroArtom@1.2.3.4'; });

    my $ret = ipaddr2_internal_key_accept();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /StrictHostKeyChecking=accept-new/ } @calls), 'Correct call ssh command');
    ok((any { /1\.2\.3\.4/ } @calls), 'Bastion IP in the ssh command');
    ok((any { /0\.41/ } @calls), 'Internal VM1 IP in the ssh command');
    ok((any { /0\.42/ } @calls), 'Internal VM2 IP in the ssh command');
};

subtest '[ipaddr2_internal_key_accept] key_checking' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /nc.*22/) { return 0; }
            if ($_[0] =~ /ssh.*StrictHostKeyChecking/) { return 0; }
            return 1; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_bastion_ssh_addr => sub { return 'AlessandroArtom@1.2.3.4'; });

    my $ret = ipaddr2_internal_key_accept(key_checking => 'LuigiTorchi');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /StrictHostKeyChecking=LuigiTorchi/ } @calls), 'Correct call ssh command value StrictHostKeyChecking');
};

subtest '[ipaddr2_internal_key_accept] nc timeout' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(script_run => sub {
            push @calls, $_[0];
            if ($_[0] =~ /nc.*22/) { return 1; }
            if ($_[0] =~ /ssh.*accept-new/) { return 0; }
            return 1; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_bastion_ssh_addr => sub { return 'AlessandroArtom@1.2.3.4'; });

    dies_ok { ipaddr2_internal_key_accept() } "die if ssh port 22 is not open";

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((none { /StrictHostKeyChecking=accept-new/ } @calls), 'Correct call ssh command');
};

subtest '[ipaddr2_cluster_create]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return 'Moriondo'; });

    ipaddr2_cluster_create();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*41.*cluster init/ } @calls), 'crm cluster init on VM1');
    ok((any { /.*42.*cluster join/ } @calls), 'crm cluster join on VM2');
    # by default it run in root mode
    # so the join has not to  specify the user
    ok((none { /.*cluster join.*-c.*cloudadmin@/ } @calls), 'crm cluster join root mode without user name');
};

subtest '[ipaddr2_cluster_create] rootless' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return 'Moriondo'; });

    ipaddr2_cluster_create(rootless => 1);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /.*cluster join.*-c.*cloudadmin@/ } @calls), 'crm cluster join uses a non root username');
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
    $ipaddr2->redefine(ipaddr2_ssh_bastion_assert_script_run => sub {
            my (%args) = @_;
            push @calls, ['bastion', $args{cmd}]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}];
            # return exactly what ipaddr2_os_ssh_sanity needs
            return 3; });

    ipaddr2_os_sanity();

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_os_sanity] root' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $ipaddr2->redefine(ipaddr2_get_internal_vm_name => sub { return 'Galileo'; });
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return 'Galileo'; });
    my @calls;
    $ipaddr2->redefine(script_run => sub {
            push @calls, ['local', $_[0]]; });
    $ipaddr2->redefine(assert_script_run => sub {
            push @calls, ['local', $_[0]]; });
    $ipaddr2->redefine(ipaddr2_ssh_bastion_assert_script_run => sub {
            my (%args) = @_;
            push @calls, ['bastion', $args{cmd}]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}];
            # return exactly what ipaddr2_os_ssh_sanity needs
            return 3; });

    ipaddr2_os_sanity(user => 'root');

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

subtest '[ipaddr2_internal_key_gen]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub {
            push @calls, $_[0];
            return 'BeniaminoFiammaPubKeyBeniaminoFiammaPubKey'; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_internal_key_gen();

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /ssh-keygen/ } @calls), 'Generate the keys if they does not exist');
    # search through all the ssh-keygen and extract the ssh key file path after -f
    # then check if there's a scp uploading it
    foreach my $cmd (@calls) {
        ok((any { qr/scp.*$1.*@.*/ } @calls), "There is at least one scp command uploading key $1") if ($cmd =~ qr/ssh-keygen.*-f (.*)/);
    }
    # search through all the scp and extract the target path
    # then check if there's a mv command moving it from the remote /tmp to the remote home folder
    foreach my $cmd (@calls) {
        ok((any { qr/mv.*$1.*/ } @calls), "There is at least one mv command moving the uploaded key $1") if ($cmd =~ qr/scp.*@.*:(.*)/);
    }
};

subtest '[ipaddr2_internal_key_gen] custom user' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub {
            push @calls, $_[0];
            return 'BeniaminoFiammaPubKeyBeniaminoFiammaPubKey'; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_internal_key_gen(user => 'EliaLocatelli');

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /mv.*\/home\/EliaLocatelli.*/ } @calls), 'Move the key in the remote user home folder');
};

subtest '[ipaddr2_internal_key_gen] root' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub {
            push @calls, $_[0];
            return 'BeniaminoFiammaPubKeyBeniaminoFiammaPubKey'; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_internal_key_gen(user => 'root');

    note("\n  -->  " . join("\n  -->  ", @calls));

    ok((any { /mv.*\/root\/.*/ } @calls), 'Move the key in the remote root home folder');
};

subtest '[ipaddr2_deployment_logs]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my $called = 0;
    $ipaddr2->redefine(ipaddr2_azure_resource_group => sub { return 'Volta'; });
    $ipaddr2->redefine(az_vm_diagnostic_log_get => sub { $called = 1; return ('aaaaa.log', 'bbbbbb.log'); });
    $ipaddr2->redefine(upload_logs => sub { return; });

    ipaddr2_deployment_logs();

    ok(($called eq 1), "az_vm_diagnostic_log_get called");
};

subtest '[ipaddr2_crm_move]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_get_internal_vm_name => sub {
            my (%args) = @_;
            return 'UT-VM-' . $args{id}; });
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd}; });

    ipaddr2_crm_move(destination => 24);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /crm resource move rsc_web_00.*24/ } @calls), "Expected crm command called");
};

subtest '[ipaddr2_crm_clear]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_get_internal_vm_name => sub {
            my (%args) = @_;
            return 'UT-VM-' . $args{id}; });
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd}; });

    ipaddr2_crm_clear(destination => 42);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /crm resource clear rsc_web_00/ } @calls), "Expected crm command called");
};

subtest '[ipaddr2_wait_for_takeover]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub { push @calls, $_[0]; return 'I am ip2t-vm-042'; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = ipaddr2_wait_for_takeover(destination => 42);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(($ret eq 1), "Expected result 1 get $ret");
    ok((any { /ssh.*1.2.3.4.*curl.*http.*192.168.0.50/ } @calls), "Expected curl command called");
};

subtest '[ipaddr2_wait_for_takeover] timeout' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub { push @calls, $_[0]; return 'I am Galileo Galilei.'; });
    $ipaddr2->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });

    my $ret = ipaddr2_wait_for_takeover(destination => 42);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ret eq 0), "Expected result 1 get $ret");
};

subtest '[ipaddr2_test_master_vm]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_get_web => sub { return 1; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return only good vibes for expected commands ...
            if ($args{cmd} =~ /crm resource failcount/) {
                $out = 'value=0';
            } elsif ($args{cmd} =~ /crm resource locate/) {
                $out = 'is running on: ip2t-vm-042';
            } elsif ($args{cmd} =~ /crm configure show/) {
                $out = 'cli-prefer-ip2t-vm-042';
            } elsif ($args{cmd} =~ /ip a show eth0/) {
                $out = '192.168.0.50';
            } elsif ($args{cmd} =~ /ps -xa/) {
                $out = '12345   ?   S 12:34  nginx';
            } else {
                # ... otherwise !!!
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    ipaddr2_test_master_vm(id => 42);

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_test_master_vm] crm failure' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_get_web => sub { return 1; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return non zero failcount
            if ($args{cmd} =~ /crm resource failcount/) {
                $out = "value=1";
            } elsif ($args{cmd} =~ /crm resource locate/) {
                $out = "is running on: ip2t-vm-042";
            } elsif ($args{cmd} =~ /crm configure show/) {
                $out = 'cli-prefer-ip2t-vm-042';
            } elsif ($args{cmd} =~ /ip a show eth0/) {
                $out = '192.168.0.50';
            } else {
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });
    $ipaddr2->redefine(ipaddr2_ssh_bastion_script_output => sub {
            my (%args) = @_;
            my $out = "nginx";
            push @calls, ["BASTION", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    dies_ok { ipaddr2_test_master_vm(id => 42) } "Die for failcount";

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
};

subtest '[ipaddr2_test_master_vm] web failure' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });

    # Simulate a failure in curl response
    $ipaddr2->redefine(ipaddr2_get_web => sub { return 0; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return only good vibes
            if ($args{cmd} =~ /crm resource failcount/) {
                $out = "value=0";
            } elsif ($args{cmd} =~ /crm resource locate/) {
                $out = "is running on: ip2t-vm-042";
            } elsif ($args{cmd} =~ /crm configure show/) {
                $out = 'cli-prefer-ip2t-vm-042';
            } elsif ($args{cmd} =~ /ip a show eth0/) {
                $out = '192.168.0.50';
            } else {
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });
    $ipaddr2->redefine(ipaddr2_ssh_bastion_script_output => sub {
            my (%args) = @_;
            my $out = "nginx";
            push @calls, ["BASTION", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    dies_ok { ipaddr2_test_master_vm(id => 42) } "Die for web failure";

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
};

subtest '[ipaddr2_test_master_vm] nginx not running' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    $ipaddr2->redefine(ipaddr2_get_web => sub { return 1; });
    my @calls;
    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""]; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return only good vibes
            if ($args{cmd} =~ /crm resource failcount/) {
                $out = "value=0";
            } elsif ($args{cmd} =~ /crm resource locate/) {
                $out = "is running on: ip2t-vm-042";
            } elsif ($args{cmd} =~ /crm configure show/) {
                $out = 'cli-prefer-ip2t-vm-042';
            } else {
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });
    $ipaddr2->redefine(ipaddr2_ssh_bastion_script_output => sub {
            my (%args) = @_;
            my $out = "galileo.galilei";
            push @calls, ["BASTION", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    dies_ok { ipaddr2_test_master_vm(id => 42) } "Die for nginx not running";

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_cluster_sanity]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""];
            return;
    });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return only good vibes
            if ($args{cmd} =~ /crm status/) {
                $out = "Some generic string that is good for cluster_status_matches_regex";
            } elsif ($args{cmd} =~ /crm configure show/) {
                $out = "primitive primitive primitive that is what the ipaddr2_cluster_sanity wants";
            } else {
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    ipaddr2_cluster_sanity();

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_configure_web_server]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return;
    });

    ipaddr2_configure_web_server(id => 42);

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
    ok((any { /zypper in.*nginx/ } @calls), 'Install nginx using zypper');
};

subtest '[ipaddr2_configure_web_server] nginx_root' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return;
    });

    ipaddr2_configure_web_server(id => 42, nginx_root => 'AAA');

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    ok((any { /mv.*index\.html.*AAA/ } @calls), 'Place test index.html in the folder from the argument');
};

subtest '[ipaddr2_configure_web_server] external_repo' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return;
    });

    ipaddr2_configure_web_server(id => 42, external_repo => 'BBB');

    note("\n  C-->  " . join("\n  C-->  ", @calls));

    ok((any { /SUSEConnect.*BBB/ } @calls), 'Add external repo');
    ok((any { /zypper in.*nginx/ } @calls), 'Install nginx using zypper');
};

subtest '[ipaddr2_scc_check] all registered' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub {
            push @calls, $_[0];
            # due to the internal implementation of the
            # function under test, this status is equivalent to `Registered`
            return '[{"status":"Bialetti"}]'; });

    my $ret = ipaddr2_scc_check(id => 42);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /SUSEConnect -s/ } @calls), 'SUSEConnect to check what is registered');
    ok(($ret eq 1), "Is registered ret:$ret");
};

subtest '[ipaddr2_scc_check] one not registered' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_output => sub {
            push @calls, $_[0];
            # due to the internal implementation of the
            # function under test, this status is equivalent to `Registered`
            return '[{"status":"Bialetti"}, {"status":"Not Registered"}]'; });

    my $ret = ipaddr2_scc_check(id => 42);

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok(($ret eq 0), "Is not registered ret:$ret");
};

subtest '[ipaddr2_scc_register]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, $args{cmd};
            return;
    });

    ipaddr2_scc_register(id => 42, scc_code => '1234567890');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /registercloudguest.*clean/ } @calls), 'registercloudguest clean');
    ok((any { /registercloudguest.*-r.*1234567890/ } @calls), 'registercloudguest register');
};

subtest '[ipaddr2_cloudinit_logs]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;

    $ipaddr2->redefine(ipaddr2_ssh_internal => sub {
            my (%args) = @_;
            push @calls, ["VM$args{id}", $args{cmd}, ""];
            return;
    });

    ipaddr2_cloudinit_logs();

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
    ok((scalar @calls > 0), "Some calls to ipaddr2_ssh_internal");
};

subtest '[ipaddr2_cloudinit_create]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my $cloud_init_content;
    $ipaddr2->redefine(write_sut_file => sub {
            $cloud_init_content = $_[1];
            return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });

    ipaddr2_cloudinit_create();

    note("cloud_init_content:\n" .
          "--------------------------\n" .
          $cloud_init_content .
          "\n--------------------------");

    like($cloud_init_content, qr/nginx/, "cloud-init script is also about nginx");
    unlike($cloud_init_content, qr/registercloudguest/, "cloud-init script does not register");
};

subtest '[ipaddr2_cloudinit_create] with scc_code' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my $cloud_init_content;
    $ipaddr2->redefine(write_sut_file => sub {
            $cloud_init_content = $_[1];
            return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });

    ipaddr2_cloudinit_create(scc_code => 'ABCD');

    note("cloud_init_content:\n" .
          "--------------------------\n" .
          $cloud_init_content .
          "\n--------------------------");

    like($cloud_init_content, qr/registercloudguest.*ABCD/, "cloud-init script registers");
};

subtest '[ipaddr2_cloudinit_create] nginx_root' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    my $cloud_init_content;
    $ipaddr2->redefine(write_sut_file => sub {
            $cloud_init_content = $_[1];
            return; });
    $ipaddr2->redefine(upload_logs => sub { return '/Faggin'; });

    ipaddr2_cloudinit_create(nginx_root => 'ABCD');

    note("cloud_init_content:\n" .
          "--------------------------\n" .
          $cloud_init_content .
          "\n--------------------------");

    like($cloud_init_content, qr/echo.*>.*ABCD.*index/, "cloud-init deploy the index.html in a custom folder");
};

subtest '[ipaddr2_os_connectivity_sanity]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(script_run => sub { push @calls, $_[0]; return; });
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_os_connectivity_sanity();

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /ping/ } @calls), 'Connectivity sanity has some ping');
};

subtest '[ipaddr2_test_other_vm]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, ["VM???", $_[0], '']; return; });
    $ipaddr2->redefine(ipaddr2_ssh_internal_output => sub {
            my (%args) = @_;
            my $out;
            # return only good vibes for expected commands ...
            if ($args{cmd} =~ /crm resource locate/) {
                $out = 'is running on: ip2t-vm-01';
            } else {
                # ... otherwise !!!
                $out = "Galileo Galilei";
            }
            push @calls, ["VM$args{id}", $args{cmd}, "OUT-->  $out"];
            return $out;
    });

    ipaddr2_test_other_vm(id => '42');

    for my $call_idx (0 .. $#calls) {
        note($calls[$call_idx][0] . " C-->  $calls[$call_idx][1]   $calls[$call_idx][2]");
    }
    ok((scalar @calls > 0), "Some calls");
};

subtest '[ipaddr2_refresh_repo]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(ipaddr2_bastion_pubip => sub { return '1.2.3.4'; });
    my @calls;
    $ipaddr2->redefine(assert_script_run => sub { push @calls, $_[0]; return; });

    ipaddr2_refresh_repo(id => '42');

    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((any { /zypper ref/ } @calls), 'Call zypper ref');
};

subtest '[get_private_ip_range]' => sub {
    my %ip_range = sles4sap::ipaddr2::get_private_ip_range();
    my %expected_value = (main_address_range => '192.168.0.0/16', subnet_address_range => '192.168.0.0/24', priv_ip_range => '192.168.0');
    is_deeply \%ip_range, \%expected_value, "No worker_id, return 192.168.0.0 ip range";

    set_var('WORKER_ID', '123');
    %ip_range = sles4sap::ipaddr2::get_private_ip_range();
    $expected_value{main_address_range} = '10.3.208.0/21';
    $expected_value{subnet_address_range} = '10.3.208.0/24';
    $expected_value{priv_ip_range} = '10.3.208';
    is_deeply \%ip_range, \%expected_value, "IP range is count according by worker_id";
    set_var('WORKER_ID', undef);
};

subtest '[ipaddr2_network_peering_create]' => sub {
    my $ipaddr2 = Test::MockModule->new('sles4sap::ipaddr2', no_auto => 1);
    $ipaddr2->redefine(az_network_vnet_get => sub { return 'DavidCuartielles'; });
    $ipaddr2->redefine(qesap_az_clean_old_peerings => sub { return; });
    $ipaddr2->redefine(ipaddr2_azure_resource_group => sub { return 'Volta'; });

    my $create_peering = 0;
    $ipaddr2->redefine(qesap_az_vnet_peering => sub { $create_peering = 1; });

    ipaddr2_network_peering_create(ibsm_rg => 'MassimoBanzi');

    ok $create_peering, "qesap_az_vnet_peering called";
};

done_testing;
