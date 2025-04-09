# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>

=head1 SYNOPSIS

This library contains various functions that help finding and connecting openQA job to the correct deployment VM.
Deployment VM is recognized from other VMs by being tagged with B<deployment_id> tag. Deployment ID is an unique
identifier which is an OpenQA job ID of a job that created this VM.
In single machine test Deployment ID equals test ID. This is not always true in case of multi-machine jobs.
Deployment ID might be an ID of the parent job which executed the deployment itself.

B<Example>:
Job: 123456 - deployment module - created deployer VM tagged with "deployment_id=123456",
Job: 123457 (child of 123456) - some test module
Deployment ID returned from both jobs: 123456 - because it matches with existing VM tagged with "deployment_id=123456"

=cut

package sles4sap::sap_deployment_automation_framework::deployment_connector;

use strict;
use warnings;
use testapi;
use Exporter qw(import);
use Mojo::JSON qw(decode_json);
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw( duplicates );
use utils qw(write_sut_file);
use Carp qw(croak);
use Time::Piece;
use mmapi qw(get_parents get_job_autoinst_vars get_children get_job_info get_current_job_id);
use sles4sap::azure_cli qw(az_resource_delete az_resource_list);
use Data::Dumper;

our @EXPORT = qw(
  get_deployer_vm_name
  get_deployer_ip
  check_ssh_availability
  find_deployment_id
  find_deployer_resources
  destroy_deployer_vm
  destroy_orphaned_resources
  no_cleanup_tag
);

=head2 check_ssh_availability

    check_ssh_availability($deployer_ip_addr [, ssh_port=>42 ,$wait_started=>'true', wait_timeout=>'42']);

Checks if deployer VM is running and listening on ssh port. Returns found state.
Optionally function can wait till VM reaches requested state until timeout.
Function dies only with internal errors, VM status should be evaluated and handled by caller.

=over

=item * B<deployer_ip_addr>: Deployer VM IP address

=item * B<wait_started>: Probe SSH port in loop until it is available or B<wait_timeout> is reached.

=item * B<wait_timeout>: Time in sec to stop probing SSH port.

=item * B<ssh_port>: Specify custom SSH port number. Default: 22

=back
=cut

sub check_ssh_availability {
    my ($deployer_ip_addr, %args) = @_;
    croak 'Deployer IP not specified.' unless $deployer_ip_addr;
    $args{wait_timeout} //= 180;
    $args{ssh_port} //= 22;
    my $ssh_available = 0;

    my $nc_cmd = 'nc -zv';
    # With `-w 10` netcat keeps waiting 10s for server response instead of returning immediately
    $nc_cmd .= ' -w 10' if $args{wait_started};
    $nc_cmd .= " $deployer_ip_addr $args{ssh_port}";

    my $start_time = time();
    until ($ssh_available) {
        $ssh_available = 1 if !script_run($nc_cmd, quiet => 1);
        last unless $args{wait_started};
        last if (time() - $start_time) >= $args{wait_timeout};
        record_info('SSH N/A', 'SSH unavailable, retrying in 10s');
        sleep 10;    # just a separation between loops, to avoid bombarding the server constantly
    }
    my $status = $ssh_available ? 'available' : 'unavailable';
    record_info('SSH check', "SSH connection to '$deployer_ip_addr -p $args{ssh_port}': $status");
    return $ssh_available;
}

=head2 get_deployer_ip

    get_deployer_ip(deployer_resource_group=>$deployer_resource_group, deployer_vm_name=>$deployer_vm_name);

Returns first public IP of deployer VM that is reachable and can be used for SDAF deployment connection.

=over

=item * B<deployer_resource_group>: Deployer resource group. Default: get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP')

=item * B<deployer_vm_name>: Deployer VM resource name

=back
=cut

sub get_deployer_ip {
    my (%args) = @_;
    $args{deployer_resource_group} //= get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');
    croak 'Missing "deployer_vm_name" argument' unless $args{deployer_vm_name};

    my $az_query_cmd = join(' ', 'az', 'vm', 'list-ip-addresses', '--resource-group', $args{deployer_resource_group},
        '--name', $args{deployer_vm_name}, '--query', '"[].virtualMachine.network.publicIpAddresses[].ipAddress"', '-o', 'json');

    my $ip_addr = decode_json(script_output($az_query_cmd));
    # Find first IP connection working
    for my $ip (@{$ip_addr}) {
        return $ip if check_ssh_availability($ip, wait_started => 'yes');
    }
    return undef;
}

=head2 get_deployer_vm_name

    get_deployer_vm_name(deployer_resource_group=>$deployer_resource_group, deployment_id=>'123456');

Returns deployer VM name which is tagged with B<deployment_id> specified in parameter. This means that the VM was used
to deploy the infrastructure under this ID and contains whole SDAF setup.
Function returns VM name or undef if no VM was found.
Function dies if there is more than one VM found, because two VM's must not have same ID.

=over

=item * B<deployer_resource_group>: Deployer resource group. Default: get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP')

=item * B<deployment_id>: Deployment ID

=back
=cut

sub get_deployer_vm_name {
    my (%args) = @_;
    $args{deployer_resource_group} //= get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');
    $args{deployment_id} //= find_deployment_id();
    croak 'Missing mandatory argument $args{deployment_id}' unless $args{deployment_id};

    # Following query lists VMs within a resource group that were tagged with specified deployment id.
    my $az_cmd = join(' ',
        'az vm list',
        "--resource-group $args{deployer_resource_group}",
        "--query \"\[?tags.deployment_id == '$args{deployment_id}'].name\"",
        '--output json'
    );

    my @vm_list = @{decode_json(script_output($az_cmd))};
    diag((caller(0))[3] . " - VMs found: " . join(', ', @vm_list));
    die "Multiple VMs with same IDs found. Each VM must have unique ID!\n
    Following VMs found tagged with: deployment_id=$args{deployment_id}"
      if @vm_list > 1;

    return $vm_list[0];
}

=head2 get_parent_ids

    get_parent_ids();

Returns B<ARRAYREF> of all parent job IDs acquired from current job data.

=cut

sub get_parent_ids {
    my $job_info = get_job_info(get_current_job_id());
    # This will loop through all parent job types (chained, parallel, etc...) and creates a list of IDs
    my @parent_ids = map { @{$job_info->{parents}{$_}} } keys(%{$job_info->{parents}});
    diag((caller(0))[3] . "Parent job data: " . Dumper($job_info->{parents}));
    foreach (@parent_ids) { die "Returned parent ID must be a number: '$_'" unless looks_like_number($_); }
    return \@parent_ids;
}

=head2 find_deployment_id

    find_deployment_id(deployer_resource_group=>$deployer_resource_group);

Finds deployment ID for currently running test. Deployment ID is ID of an OpenQA test which created deployer VM.
In case of multi-machine test this can be either parent test ID or current job id as well.
This function collects all OpenQA job IDs related to current test run and checks if any of them match an existing
deployer VM tagged with this ID.

Using OpenQA parameter B<SDAF_DEPLOYMENT_ID> it is possible to override this value. It is mostly intended for development
purposes where it allows you to run test code on already existing deployment. Use it with caution and override
the value only with ID of the infrastructure that belongs to you.

B<Example>:
Job: 123456 - deployment module - created deployer VM tagged with "deployment_id=123456",
Job: 123457 (child of 123456) - some test module
Deployment ID returned from both jobs: 123456 - because it matches with existing VM tagged with "deployment_id=123456"

=over

=item * B<deployer_resource_group>: Deployer resource group. Default: get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP')

=back
=cut

sub find_deployment_id {
    my (%args) = @_;
    return get_var('SDAF_DEPLOYMENT_ID') if get_var('SDAF_DEPLOYMENT_ID');
    $args{deployer_resource_group} //= get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');
    my @check_list = (get_current_job_id(), @{get_parent_ids()});

    diag("Job IDs found: " . Dumper(@check_list));
    my @ids_found;
    for my $deployment_id (@check_list) {
        my $vm_name =
          get_deployer_vm_name(deployer_resource_group => $args{deployer_resource_group}, deployment_id => $deployment_id);
        push(@ids_found, $deployment_id) if $vm_name;
    }
    die "More than one deployment found.\nJobs IDs: " .
      join(', ', @check_list) . "\nVMs found: " . join(', ', @ids_found) if @ids_found > 1;

    return ($ids_found[0]);
}

=head2 get_deployer_resources

    get_deployer_resources(deployer_resource_group=>$deployer_resource_group [, deployment_id=>'123456', return_ids=1]);

Returns ARRAYREF of all resources belonging to B<deployer_resource_group> tagged with B<deployment_id>.

=over

=item * B<deployer_resource_group>: Deployer resource group. Default: get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP')

=item * B<deployment_id>: Deployment ID

=item * B<return_value>: Control the content of the returned array. It can either return array of resource IDs or resource names.
    Values allowed: id, name
    Default: name

=back
=cut

sub find_deployer_resources {
    my (%args) = @_;
    $args{deployer_resource_group} //= get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');
    $args{deployment_id} //= find_deployment_id();
    $args{return_value} //= 'name';
    croak "Argument 'return_value' accepts only 'id' or 'name'" unless grep(/$args{return_value}/, ('id', 'name'));

    my $az_cmd = join(' ',
        'az resource list',
        "--resource-group $args{deployer_resource_group}",
        "--query \"[?tags.deployment_id == '$args{deployment_id}'].$args{return_value}\"",
        '--output json'
    );

    my @resource_list = @{decode_json(script_output($az_cmd))};

    return \@resource_list;
}


=head2 destroy_resources

    destroy_resources(resource_cleanup_list=>['resource_A', 'resource_B'] [, timeout=>900]);

Destroys all resources specified by B<resources> argument in ARRAYREF format.

=over

=item * B<timeout> Timeout for AZ command to destroy resources. Default: 800

=item * B<resource_cleanup_list> ARRAYREF specifying resources to be deleted. If empty, function will just return.

=back

=cut

sub destroy_resources {
    my (%args) = @_;
    croak("Argument 'resource_cleanup_list' must be ARRAYREF.\nGot:" . ref($args{resource_cleanup_list})) unless
      ref($args{resource_cleanup_list}) eq 'ARRAY';

    $args{timeout} //= '800';
    my $retries = 3;    # retry to delete 3x
    my $deployer_resource_group = get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP');

    unless ($args{resource_cleanup_list}) {
        record_info('Destroy resources', 'No resources defined, cleanup skipped.');
        return;
    }

    my @resource_cleanup_list = @{$args{resource_cleanup_list}};

    for my $attempt (1 .. $retries) {
        record_info("Attempt #$attempt");

        last unless az_resource_delete(ids => join(' ', @resource_cleanup_list),
            resource_group => $deployer_resource_group, verbose => 'yes', timeout => $args{timeout});
        sleep 5;    # Just give things few secs to avoid command spamming.
        die "Failed to clean up resources:\n" . join("\n", @resource_cleanup_list) if ($attempt == $retries);
    }
    record_info('Destroy resources', 'All resources destroyed');
}

=head2 destroy_deployer_vm

    destroy_deployer_vm([timeout=>900]);

Collects resource id of all resources belonging to the deployer VM and deletes them.
Cleanup deployer VM resources only, B<deployer resource group itself will stay intact>.

=over

=item * B<timeout>: Timeout for destroy command. Default: 800

=back
=cut

sub destroy_deployer_vm {
    my (%args) = @_;
    # Deployer VM is located in permanent deployer resource group. This RG **MUST STAY INTACT**
    my $resource_cleanup_list = find_deployer_resources(return_value => 'id');
    # Early exit  in case there is nothing to clean up
    unless (@{$resource_cleanup_list}) {
        record_info('Deployer cleanup', 'No resources related to deployer VM found');
        return;
    }

    record_info('Deployer cleanup',
        "Following resources are being destroyed:\n" . join("\n", @{$resource_cleanup_list}));

    destroy_resources(timeout => $args{timeout}, resource_cleanup_list => $resource_cleanup_list);
    record_info('Deployer cleanup', 'All resources destroyed');
}

=head2 destroy_orphaned_deployers

    destroy_orphaned_deployers([timeout=>9999]);

Destroys orphaned deployer VM resources existing inside permanent deployer resource group.
Function lists all resources and their creation time belonging to deployer RG which are tagged with 'deployment_id'.
Resource being tagged with 'deployment_id' means it was created by an OpenQA test.
Resource names are as well checked against OpenQA naming convention as another prevention from unwanted resource deletion.
Resources older than 'SDAF_DEPLOYER_VM_RETENTION_SEC' seconds (Default 7H) are considered as orphans and deleted.
Be very careful with changes here (especially with regexes and az cli filters) as mistakes can lead to damage on
permanent SDAF infrastructure.

=over

=item * B<timeout>: Timeout for az destroy command. Default: 1200

=back

=cut

sub destroy_orphaned_resources {
    my (%args) = @_;
    $args{timeout} //= 1200;
    # List all resources containing 'deployment_id' tag with exception of ones containing 'no cleanup' tag
    # Result will show only resources created by OpenQA tests and only those which are allowed to be cleaned up.
    my $all_resources = az_resource_list(
        resource_group => get_required_var('SDAF_DEPLOYER_RESOURCE_GROUP'),
        query => '[?tags.deployment_id && tags.' . no_cleanup_tag() . '].{resource_id:id, creation_time:createdTime}'
    );
    my @orphaned_resources;

    foreach (@$all_resources) {
        # Couple of notes to time formats:
        # - for format explanation check 'man strftime' - az cli returns date in ISO 8601 format
        # - Time::Piece does not recognize microseconds, they need to be neutered using regex
        $_->{creation_time} =~ s/\.\d+(?=\+\d\d)//;

        # - Time::Piece does not recognize az cli timezone format `+02:00`, only `+0200`
        #   - therefore we have to do some colonoscopy and remove `:` from az cli output
        $_->{creation_time} =~ s/(?<=\+\d\d):(?=\d\d$)//;
        my $time = Time::Piece->strptime($_->{creation_time}, '%Y-%m-%dT%H:%M:%S%z')->epoch();
        # naming convention check. Resources coming from OpenQA have name like: <test_id>-OpenQA_Deployer_VM*
        next unless $_->{resource_id} =~ m/\d+-OpenQA_Deployer_VM/;
        # Mark for deletion resources older than 'SDAF_DEPLOYER_VM_RETENTION_SEC' or default 7H
        push(@orphaned_resources, $_->{resource_id}) if $time < time() - get_var('SDAF_DEPLOYER_VM_RETENTION_SEC', '25200');
    }
    # Do nothing in case there is nothing to delete
    return unless @orphaned_resources;
    record_info('az destroy', "Following orphaned resources will be destroyed:\n" . join("\n", @orphaned_resources));
    destroy_resources(timeout => $args{timeout}, resource_cleanup_list => \@orphaned_resources);
}

=head2 no_cleanup_tag

    no_cleanup_tag();

Returns tag name that marks resource to be omitted during cleanup routine. Tag name can be defined by OpenQA setting
`SDAF_NO_CLEANUP_TAG` with default value being 'sdaf_cleanup_ignore'.
This function ensures default value naming consistency across all modules, instead defining it with each 'get_var' call.

=cut

sub no_cleanup_tag {
    return get_var('SDAF_NO_CLEANUP_TAG', 'sdaf_cleanup_ignore');
}
