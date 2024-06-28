use strict;
use warnings;
use Test::Mock::Time;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use testapi;
use Data::Dumper;
use Scalar::Util qw(reftype);
use List::Util qw(any none);
use sles4sap::sap_deployment_automation_framework::deployment_connector;

subtest '[get_deployer_vm] Test expected failures' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(diag => sub { return; });
    $mock_function->redefine(script_output => sub { return '
[
  "0079-Zaku_II",
  "0079-MSM-07"
]
'; });

    dies_ok { get_deployer_vm(deployer_resource_group => 'Char') } 'Croak with missing mandatory arg: deployment_id';
    dies_ok { get_deployer_vm(deployer_resource_group => 'Char', deployment_id => '0079') } 'Die with multiple VMs tagged with same ID';
};

subtest '[get_deployer_vm] Check command composition' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;
    $mock_function->redefine(diag => sub { return; });
    $mock_function->redefine(script_output => sub { push(@calls, @_); return '[
  "0079-Zaku_II"
]'
    });

    my $result = get_deployer_vm(deployer_resource_group => 'Char', deployment_id => '0079');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /az vm list/, @calls), 'Check main az command');
    ok((grep /--resource-group Char/, @calls), 'Check --resource-group argument');
    ok((grep /--query "\[\?tags.deployment_id == '0079'].name"/, @calls), 'Check --query argument');
    ok((grep /--output json/, @calls), 'Output must be in json format');
    is $result, '0079-Zaku_II', 'Return VM name';

    $mock_function->redefine(script_output => sub { push(@calls, @_); return '[]' });
    is get_deployer_vm(deployer_resource_group => 'Char', deployment_id => '0079'), undef, 'Return empty string if no VM found';
};

subtest '[find_deployment_id]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(get_current_job_id => sub { return '0079'; });
    $mock_function->redefine(get_parent_ids => sub { return ['0083', '0087']; });
    $mock_function->redefine(get_deployer_vm => sub { return '0079' if grep(/0079/, @_); });

    is find_deployment_id(deployer_resource_group => 'Char'), '0079', 'Current job ID belongs to VM';

    $mock_function->redefine(get_current_job_id => sub { return; });
    is find_deployment_id(deployer_resource_group => 'Char'), undef, 'Return undef if no ID found';

    $mock_function->redefine(get_deployer_vm => sub { return '0083' if grep(/0083/, @_); });
    is find_deployment_id(deployer_resource_group => 'Char'), '0083', 'Parent job ID belongs to VM';
};

subtest '[find_deployer_resources] Check command composition' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;
    $mock_function->redefine(diag => sub { return; });
    $mock_function->redefine(script_output => sub { push(@calls, @_); return '[
  "0079-Zaku_II_VM_OS",
  "0079-Zaku_II_VMNSG",
  "0079-Zaku_II_VMPublicIP",
  "0079-Zaku_II_VMVMNIC",
  "0079-Zaku_II_VM"
]'
    });

    my $result = find_deployer_resources(deployer_resource_group => 'Char', deployment_id => '0079');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /az resource list/, @calls), 'Check main az command');
    ok((grep /--resource-group Char/, @calls), 'Check --resource-group argument');
    ok((grep /--query "\[\?tags.deployment_id == '0079'].name"/, @calls), 'Query resource names');
    ok((grep /--output json/, @calls), 'Output must be in json format');

    find_deployer_resources(deployer_resource_group => 'Char', deployment_id => '0079', return_value => 'id');
    ok((grep /--query "\[\?tags.deployment_id == '0079'].id"/, @calls), 'Query resource IDs');

    is ref($result), 'ARRAY', 'Return results in array';

    dies_ok { find_deployer_resources(deployer_resource_group => 'Char', deployment_id => '0079', return_value => 'Amuro'); }
    'Croak with incorrect "return_value" argument';
};

subtest '[get_deployer_ip]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;
    $mock_function->redefine(record_info => sub { return; });
    $mock_function->redefine(check_deployer_ssh => sub { return 1; });
    $mock_function->redefine(script_output => sub { push @calls, $_[0]; return '[
  "192.168.1.1",
  "192.168.1.2"
]' });

    get_deployer_ip(deployer_resource_group => 'OpenQA_SDAF_0087', deployer_vm_name => 'Zeta');
    ok(grep(/az vm list-ip-addresses/, @calls), 'Test base command');
    ok(grep(/--resource-group/, @calls), 'Check for --resource-group argument');
    ok(grep(/--name/, @calls), 'Check for vm name --name argument');
    ok(grep(/--query \"\[].virtualMachine.network.publicIpAddresses\[].ipAddress\"/, @calls),
        'Check for vm name --query argument');
    ok(grep(/-o json/, @calls), 'Output result in json format');
};

subtest '[get_deployer_ip] Test expected failures' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(record_info => sub { return; });
    my @incorrect_ip_addresses = (
        '192.168.0.500',
        '192.168.o.5',
        '192.168.0.',
        '2001:db8:85a3::8a2e:370:7334'
    );

    dies_ok { get_deployer_ip(deployer_vm_name => 'RMS-106_Hizack') } 'Fail with missing deployer resource group argument';
    dies_ok { get_deployer_ip(deployer_resource_group => 'RX-178_Mk-II') } 'Fail with missing deployer resource group argument';
    for my $ip_input (@incorrect_ip_addresses) {
        $mock_function->redefine(script_output => sub { return $ip_input; });
        dies_ok { get_deployer_ip(deployer_resource_group => 'OpenQA_SDAF_0087') } "Detect incorrect IP addr pattern: $ip_input";
    }
};


subtest '[check_deployer_ssh]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 0; });
    $mock_function->redefine(record_info => sub { return; });

    my $ssh_avail = check_deployer_ssh('1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 1), "ssh_avail= $ssh_avail as expected 1");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_deployer_ssh] timeout but no wait_started' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 1; });
    $mock_function->redefine(record_info => sub { return; });
    my $ssh_avail = check_deployer_ssh('1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 0), "ssh_avail=$ssh_avail as expected 0");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_deployer_ssh] timeout and wait_started=0' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 1; });
    $mock_function->redefine(record_info => sub { return; });
    my $ssh_avail = check_deployer_ssh('1.2.3.4', wait_started => 0);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 0), "ssh_avail=$ssh_avail as expected 0");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_deployer_ssh] Test command looping' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my $loop_count = 0;
    $mock_function->redefine(diag => sub { $loop_count++; return; });
    $mock_function->redefine(record_info => sub { return; });
    my $ip_addr = '10.10.10.10';

    $mock_function->redefine(script_run => sub { return 1 if $loop_count == 2; $loop_count++; return 0 });

    check_deployer_ssh($ip_addr, wait_started => '1');
    ok(($loop_count > 0), "Test retry loop with \$args{wait_started}. Loop count: $loop_count");

};


done_testing;
