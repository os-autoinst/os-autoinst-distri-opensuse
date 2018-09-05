# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Use IPA framework to test public cloud SUSE images
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

use base "opensusebasetest";
use strict;
use testapi;
use utils;
use serial_terminal 'select_virtio_console';

sub get_ipa_tests {
    my $ipa_tests = get_required_var('PUBLIC_CLOUD_IPA_TESTS');
    $ipa_tests =~ s/,/ /g;
    return $ipa_tests;
}

sub save_logs {
    my $ret = script_run("test -d ipa_results");
    return if (!defined($ret) || $ret != 0);

    my $image = get_required_var('PUBLIC_CLOUD_IMAGE_ID');

    my $output = script_output("find ipa_results -type f");
    for my $file (split(/\n/, $output)) {
        if ($file =~ m"ipa_results/ec2/ami-[0-9a-z]+/i-[0-9a-z]+/[0-9]{14}\.(log|results)" or
            $file =~ m"ipa_results/azure/$image/azure-ipa-test-\w+/[0-9]{14}\.(log|results)") {
            upload_logs($file, failok => 1);
            if ($file =~ /results$/) {
                parse_extra_log(IPA => $file);
            }
        }
    }
}

sub ec2_find_secgroup {
    my ($name) = @_;

    my $out = script_output("aws ec2 describe-security-groups --group-names '$name'", 30, proceed_on_failure => 1);
    if ($out =~ /"GroupId":\s+"([^"]+)"/) {
        return $1;
    }
    return;
}

sub ec2_create_secgroup {
    my ($name) = @_;

    my $secgroup_id = ec2_find_secgroup($name);
    return $secgroup_id if (defined($secgroup_id));

    assert_script_run("aws ec2 create-security-group --group-name '$name' --description 'SSH_OPEN'");
    assert_script_run("aws ec2 authorize-security-group-ingress --group-name '$name' --protocol tcp --port 22 --cidr 0.0.0.0/0");
    assert_script_run("aws ec2 authorize-security-group-ingress --group-name '$name' --protocol icmp --cidr 0.0.0.0/0 --port 0 ");
    return ec2_find_secgroup($name);
}

sub ec2_create_ssh_key {
    my ($prefix, $out_file) = @_;

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd      = "aws ec2 create-key-pair --key-name '" . $key_name . "' --query 'KeyMaterial' --output text > " . $out_file;
        my $ret      = script_run($cmd);
        if (defined($ret) && $ret == 0) {
            return $key_name;
        }
    }
    die("Unable to create SSH key on aws with prefix '$prefix'");
}

sub ec2_cleanup {
    my ($self) = @_;

    # Terminate instance
    if (defined($self->{'ipa_instance_id'})) {
        assert_script_run("aws ec2 terminate-instances --instance-ids " . $self->{'ipa_instance_id'});
    }

    if (defined($self->{'ipa_ssh_key_name'})) {
        assert_script_run("aws ec2 delete-key-pair --key-name " . $self->{'ipa_ssh_key_name'});
    }
}

sub ec2_run_ipa {
    my ($self) = @_;

    my $region = get_var('PUBLIC_CLOUD_REGION', 'eu-central-1');

    assert_script_run("export AWS_ACCESS_KEY_ID=" . get_required_var('PUBLIC_CLOUD_KEY_ID'));
    assert_script_run("export AWS_SECRET_ACCESS_KEY=" . get_required_var('PUBLIC_CLOUD_KEY_SECRET'));
    assert_script_run('export AWS_DEFAULT_REGION="' . $region . '"');

    # Create SSH key.
    my $ssh_key_name = ec2_create_ssh_key("openqa_" . time, 'QA_SSH_KEY.pem');
    $self->{'ipa_ssh_key_name'} = $ssh_key_name;

    # Create security group
    my $secgroup_id = ec2_create_secgroup("qa_secgroup");
    die "Failed on creating security group" unless $secgroup_id;

    #Prestart instance, cause IPA might use the wrong security group
    my $ami_id = get_required_var("PUBLIC_CLOUD_IMAGE_ID");
    my ($instance_id)
      = script_output("aws ec2 run-instances --image-id $ami_id --instance-type '"
          . get_var('PUBLIC_CLOUD_INSTANCE_TYPE', 't2.large')
          . "' --key-name " . $ssh_key_name . " --security-group-ids '$secgroup_id'")
      =~ /"InstanceId":\s*"([^"]+)"/;
    $self->{'ipa_instance_id'} = $instance_id;


    assert_script_run(
        "ipa test ec2 "
          . "--access-key-id '"
          . get_required_var('PUBLIC_CLOUD_KEY_ID') . "' "
          . "--secret-access-key '"
          . get_required_var('PUBLIC_CLOUD_KEY_SECRET') . "' "
          . "-D 'IPA test $ami_id' "
          . "--distro sles "
          . "-R '$instance_id' "
          . "--region '$region' "
          . "-u ec2-user "
          . "--ssh-private-key-file QA_SSH_KEY.pem "
          . "--ssh-key-name '" . $ssh_key_name . "' "
          . "--results-dir ipa_results "
          . get_ipa_tests(),
        timeout => 600
    );
    delete $self->{'ipa_instance_id'};

    ec2_cleanup;
}

sub az_run_ipa {
    my ($self) = @_;

    my $clientid      = get_required_var('PUBLIC_CLOUD_KEY_ID');
    my $clientsecret  = get_required_var('PUBLIC_CLOUD_KEY_SECRET');
    my $subscription  = get_required_var('PUBLIC_CLOUD_SUBSCRIPTION_ID');
    my $tenantid      = get_required_var('PUBLIC_CLOUD_TENANT_ID');
    my $image         = get_required_var('PUBLIC_CLOUD_IMAGE_ID');
    my $instance_type = get_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'Standard_A2');
    my $region        = get_var('PUBLIC_CLOUD_REGION', 'westeurope');

    my $credentials = <<EOT;
{
  "clientId": "$clientid", 
  "clientSecret": "$clientsecret", 
  "subscriptionId": "$subscription", 
  "tenantId": "$tenantid", 
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com", 
  "resourceManagerEndpointUrl": "https://management.azure.com/", 
  "activeDirectoryGraphResourceId": "https://graph.windows.net/", 
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/", 
  "galleryEndpointUrl": "https://gallery.azure.com/", 
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOT

    save_tmp_file("azure_credentials.txt", $credentials);
    assert_script_run('curl -O ' . autoinst_url . "/files/azure_credentials.txt");

    assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ~/.ssh/id_rsa');

    assert_script_run(
        "ipa test azure "
          . "--service-account-file azure_credentials.txt "
          . "-D 'IPA test $image' "
          . "--distro sles "
          . "--ssh-private-key-file ~/.ssh/id_rsa "
          . "--region '$region' "
          . "--results-dir ipa_results "
          . "--cleanup "
          . "--instance-type '$instance_type' "
          . "-i '$image' "
          . get_ipa_tests(),
        timeout => 1200
    );
}

sub run {
    my ($self) = @_;

    select_virtio_console();

    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        ec2_run_ipa($self);
    }
    elsif (check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE')) {
        az_run_ipa($self);
    }
    else {
        die('Unknown PUBLIC_CLOUD_PROVIDER given');
    }
    save_logs;
}

sub post_fail_hook {
    my ($self) = @_;

    save_logs;

    if (check_var('PUBLIC_CLOUD_PROVIDER', 'EC2')) {
        ec2_cleanup($self);
    }
}

1;

=head1 Discussion

This module use IPA tool to test public cloud SLE images.
Logs are uploaded at the end.

When running IPA from SLES, it must have a valid SCC registration to enable 
public cloud module.

The variables DISTRI, VERSION and ARCH must correspond to the system where
IPA get installed in and not to the public cloud image.

=head1 Configuration

=head2 PUBLIC_CLOUD_IMAGE_ID

The image ID which is used to instantiate a VM and run tests on it.
For azure, the name of the image, e.g. B<SUSE:SUSE-Manager-Server-BYOS:3.1:2018.08.27>.
For ec2 the AMI, e.g. B<ami-067a77ef88a35c1a5>.

=head2 PUBLIC_CLOUD_PROVIDER

The type of the CSP (Cloud service provider). 

=head2 PUBLIC_CLOUD_KEY_ID

The CSP credentials key-id to used to access API.

=head2 PUBLIC_CLOUD_KEY_SECRET

The CSP credentials secret used to access API.

=head2 PUBLIC_CLOUD_REGION

The region to use. (default-azure: westeurope, default-ec2: eu-central-1)

=head2 PUBLIC_CLOUD_INSTANCE_TYPE

Specify the instance type. Which instance types exists depends on the CSP.
(default-azure: Standard_A2, default-ec2: t2.large )

More infos:
Azure: https://docs.microsoft.com/en-us/rest/api/compute/virtualmachinesizes/list
EC2: https://aws.amazon.com/ec2/instance-types/

=head2 PUBLIC_CLOUD_TENANT_ID

This is B<only for azure> and used to create the service account file.

=head2 PUBLIC_CLOUD_SUBSCRIPTION_ID

This is B<only for azure> and used to create the service account file.

=cut

