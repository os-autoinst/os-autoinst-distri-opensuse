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

subtest '[get_deployer_vm_name] Test expected failures' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(diag => sub { return; });
    $mock_function->redefine(script_output => sub { return '
[
  "0079-Zaku_II",
  "0079-MSM-07"
]
'; });

    dies_ok { get_deployer_vm_name(deployer_resource_group => 'Char') } 'Croak with missing mandatory arg: deployment_id';
    dies_ok { get_deployer_vm_name(deployer_resource_group => 'Char', deployment_id => '0079') } 'Die with multiple VMs tagged with same ID';
};

subtest '[get_deployer_vm_name] Check command composition' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;
    $mock_function->redefine(diag => sub { return; });
    $mock_function->redefine(script_output => sub { push(@calls, @_); return '[
  "0079-Zaku_II"
]'
    });

    my $result = get_deployer_vm_name(deployer_resource_group => 'Char', deployment_id => '0079');
    note("\n  -->  " . join("\n  -->  ", @calls));
    ok((grep /az vm list/, @calls), 'Check main az command');
    ok((grep /--resource-group Char/, @calls), 'Check --resource-group argument');
    ok((grep /--query "\[\?tags.deployment_id == '0079'].name"/, @calls), 'Check --query argument');
    ok((grep /--output json/, @calls), 'Output must be in json format');
    is $result, '0079-Zaku_II', 'Return VM name';

    $mock_function->redefine(script_output => sub { push(@calls, @_); return '[]' });
    is get_deployer_vm_name(deployer_resource_group => 'Char', deployment_id => '0079'), undef, 'Return empty string if no VM found';
};

subtest '[find_deployment_id]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(get_current_job_id => sub { return '0079'; });
    $mock_function->redefine(get_parent_ids => sub { return ['0083', '0087']; });
    $mock_function->redefine(get_deployer_vm_name => sub { return '0079' if grep(/0079/, @_); });

    is find_deployment_id(deployer_resource_group => 'Char'), '0079', 'Current job ID belongs to VM';

    $mock_function->redefine(get_current_job_id => sub { return; });
    is find_deployment_id(deployer_resource_group => 'Char'), undef, 'Return undef if no ID found';

    $mock_function->redefine(get_deployer_vm_name => sub { return '0083' if grep(/0083/, @_); });
    is find_deployment_id(deployer_resource_group => 'Char'), '0083', 'Parent job ID belongs to VM';
};

subtest '[find_deployment_id]' => sub {
    set_var('SDAF_DEPLOYMENT_ID', '0079');
    is find_deployment_id(deployer_resource_group => 'Char'), '0079', 'Override deployment id using "SDAF_DEPLOYMENT_ID"';
    set_var('SDAF_DEPLOYMENT_ID', undef);
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
    $mock_function->redefine(check_ssh_availability => sub { return 1; });
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


subtest '[check_ssh_availability]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 0; });
    $mock_function->redefine(record_info => sub { return; });

    my $ssh_avail = check_ssh_availability('1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 1), "ssh_avail= $ssh_avail as expected 1");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_ssh_availability] timeout but no wait_started' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 1; });
    $mock_function->redefine(record_info => sub { return; });
    my $ssh_avail = check_ssh_availability('1.2.3.4');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 0), "ssh_avail=$ssh_avail as expected 0");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_ssh_availability] timeout and wait_started=0' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @calls;

    $mock_function->redefine(script_run => sub { push(@calls, $_[0]); return 1; });
    $mock_function->redefine(record_info => sub { return; });
    my $ssh_avail = check_ssh_availability('1.2.3.4', wait_started => 0);

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok(($ssh_avail eq 0), "ssh_avail=$ssh_avail as expected 0");
    ok((none { /nc.*-w/ } @calls), 'No -w in nc if wait_started is not enabled');
    ok((any { /nc.*\s+1\.2\.3\.4/ } @calls), 'IP in nc command');
};

subtest '[check_ssh_availability] Test command looping' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my $loop_count = 0;
    $mock_function->redefine(diag => sub { $loop_count++; return; });
    $mock_function->redefine(record_info => sub { return; });
    my $ip_addr = '10.10.10.10';

    $mock_function->redefine(script_run => sub { return 1 if $loop_count == 2; $loop_count++; return 0 });

    check_ssh_availability($ip_addr, wait_started => '1');
    ok(($loop_count > 0), "Test retry loop with \$args{wait_started}. Loop count: $loop_count");
};

subtest '[destroy_deployer_vm]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my $destroy_resource_called;
    my @destroy_list;

    $mock_function->redefine(record_info => sub { return; });
    $mock_function->redefine(find_deployer_resources => sub { return \@destroy_list; });
    $mock_function->redefine(destroy_resources => sub { $destroy_resource_called = 1; return; });

    destroy_deployer_vm();
    ok(!$destroy_resource_called, 'Exit early if there is nothing to destroy');

    @destroy_list = ('Gihren', 'Garma', 'Dozle');
    destroy_deployer_vm();
    ok($destroy_resource_called, 'Call function "destroy_resources" if resource list is not empty');
};

subtest '[destroy_resources]' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my @destroy_list;
    my $destroy_called = 0;
    $mock_function->redefine(record_info => sub { return; });
    $mock_function->redefine(find_deployer_resources => sub { return \@destroy_list; });
    $mock_function->redefine(az_resource_delete => sub { $destroy_called++; return 0; });
    set_var('SDAF_DEPLOYER_RESOURCE_GROUP', 'Zabi');

    destroy_deployer_vm();
    ok(!$destroy_called, 'Early exit if there is nothing to destroy');

    @destroy_list = ('Gihren', 'Garma', 'Dozle');
    destroy_deployer_vm();
    is $destroy_called, 1, 'Destroy defined resources on first loop';
};

subtest '[destroy_resources] Test retry function' => sub {
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    my $loop_no = 0;
    $mock_function->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock_function->redefine(find_deployer_resources => sub { return ['Gihren', 'Garma']; });
    $mock_function->redefine(az_resource_delete => sub { $loop_no++; return 0 if $loop_no == 3; return 42 });

    set_var('SDAF_DEPLOYER_RESOURCE_GROUP', 'Zabi');

    destroy_deployer_vm();
    is $loop_no, 3, 'Pass on third attempt';
};

subtest '[destroy_orphaned_resources]' => sub {
    my %arguments;
    my $mock_function = Test::MockModule->new('sles4sap::sap_deployment_automation_framework::deployment_connector', no_auto => 1);
    $mock_function->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $mock_function->redefine(destroy_resources => sub { %arguments = @_; return; });
    # Couple of examples to test regexes. Keep real world values here.
    $mock_function->redefine(az_resource_list => sub { return [
                {"creation_time" => "2020-10-10T07:18:11.094118+00:00", "resource_id" => "602-OpenQA_Deployer_VM_orphaned"},
                {"creation_time" => "2055-10-10T07:18:11.094118+00:00", "resource_id" => "602-OpenQA_Deployer_VM_not_orphaned"},
                {"creation_time" => "2020-10-10T07:18:11.094118+00:00", "resource_id" => "deployer_snapshot_12082024"},
                {"creation_time" => "2020-10-10T07:18:11.094118+00:00", "resource_id" => "LAB-SECE-DEP10_labsecedep10deploy00"},
                {"creation_time" => "2020-10-10T07:18:11.094118+00:00", "resource_id" => "LAB-SECE-DEP10-vnet"}];
    });
    destroy_orphaned_resources();
    note("Resources being deleted:\n" . join(', ', @{$arguments{resource_cleanup_list}}));
    ok(grep(/602-OpenQA_Deployer_VM_orphaned/, @{$arguments{resource_cleanup_list}}), 'Delete orphaned resource');
    ok(!grep(/602-OpenQA_Deployer_VM_not_orphaned/, @{$arguments{resource_cleanup_list}}), 'Do not delete resource which is not orphaned');
    ok(!grep(/deployer_snapshot_12082024|LAB-SECE-DEP10_labsecedep10deploy00|LAB-SECE-DEP10-vnet/, @{$arguments{resource_cleanup_list}}),
        'Do not delete permanent resources');
};

done_testing();
