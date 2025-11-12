# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon ec2
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::ec2;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use publiccloud::utils "is_byos";
use publiccloud::aws_client;
use publiccloud::ssh_interactive 'select_host_console';
use DateTime;

has ssh_key_pair => undef;
use constant SSH_KEY_PEM => 'QA_SSH_KEY.pem';

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::aws_client->new());
    $self->provider_client->init();
}

sub find_img {
    my ($self, $name) = @_;

    $name = $self->prefix . '-' . $name;

    my $ownerId = get_var('PUBLIC_CLOUD_EC2_ACCOUNT_ID', script_output('aws sts get-caller-identity --query "Account" --output text'));
    my $out = script_output("aws ec2 describe-images  --filters 'Name=name,Values=$name' --owners '$ownerId'");
    if ($out =~ /"ImageId":\s+"([^"]+)"/) {
        return $1;
    }
    return;
}

# Returns true if key is already created in EC2 otherwise tries 10 times to create it and then fails
# If the subroutine manager to create key pair in EC2 it stores it in $self->ssh_key_pair

sub create_keypair {
    my ($self, $prefix) = @_;

    return 1 if (script_run('test -s ' . SSH_KEY_PEM) == 0);

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd = "aws ec2 create-key-pair --key-name '" . $key_name
          . "' --query 'KeyMaterial' --output text > " . SSH_KEY_PEM;
        my $ret = script_run($cmd);
        if (defined($ret) && $ret == 0) {
            assert_script_run('chmod 0400 ' . SSH_KEY_PEM);
            $self->ssh_key_pair($key_name);
            return 1;
        }
    }
    return 0;
}

sub delete_keypair {
    my $self = shift;
    my $name = shift || $self->ssh_key;

    return unless $name;

    assert_script_run("aws ec2 delete-key-pair --key-name " . $name);
    $self->ssh_key(undef);
}

sub upload_img {
    my ($self, $file) = @_;

    die("Create key-pair failed") unless ($self->create_keypair($self->prefix . time));

    # AMI of image to use for helper VM to create/build the image on CSP.
    my $helper_ami_id = get_var('PUBLIC_CLOUD_EC2_UPLOAD_AMI');

    die('Please specify PUBLIC_CLOUD_EC2_UPLOAD_AMI variable.') unless (defined($helper_ami_id));

    my ($img_name) = $file =~ /([^\/]+)$/;
    my $img_arch = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    my $sec_group = get_var('PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP');
    my $vpc_subnet = get_var('PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET');
    my $instance_type = get_required_var('PUBLIC_CLOUD_EC2_UPLOAD_INSTANCE_TYPE');

    if (!$sec_group) {
        $sec_group = script_output("aws ec2 describe-security-groups --output text "
              . "--region " . $self->provider_client->region . " "
              . "--filters 'Name=group-name,Values=tf-sg' "
              . "--query 'SecurityGroups[0].GroupId'"
        );
        $sec_group = "" if ($sec_group eq "None");
    }
    if (!$vpc_subnet) {
        my $vpc_id = script_output("aws ec2 describe-vpcs --output text "
              . "--region " . $self->provider_client->region . " "
              . "--filters 'Name=tag:Name,Values=tf-vpc' "
              . "--query 'Vpcs[0].VpcId'"
        );
        if ($vpc_id ne "None") {
            # Grab subnet with CidrBlock defined in https://gitlab.suse.de/qac/infra/-/blob/master/aws/tf/main.tf
            $vpc_subnet = script_output("aws ec2 describe-subnets --output text "
                  . "--region " . $self->provider_client->region . " "
                  . "--filters 'Name=vpc-id,Values=$vpc_id' 'Name=cidr-block,Values=10.11.4.0/22' "
                  . "--query 'Subnets[0].SubnetId'"
            );
            $vpc_subnet = "" if ($vpc_subnet eq "None");
        }
    }

    # ec2uploadimg will fail without this file, but we can have it empty
    # because we passing all needed info via params anyway
    assert_script_run('echo " " > /root/.ec2utils.conf');

    assert_script_run("ec2uploadimg --access-id \$AWS_ACCESS_KEY_ID -s \$AWS_SECRET_ACCESS_KEY "
          . "--backing-store ssd "
          . "--grub2 "
          . "--machine '" . $img_arch . "' "
          . "-n '" . $self->prefix . '-' . $img_name . "' "
          . "--virt-type hvm --sriov-support "
          . (is_byos() ? '' : '--use-root-swap ')
          . '--ena-support '
          . "--verbose "
          . "--regions '" . $self->provider_client->region . "' "
          . "--ssh-key-pair '" . $self->ssh_key_pair . "' "
          . "--private-key-file " . SSH_KEY_PEM . " "
          . "-d 'OpenQA upload image' "
          . "--wait-count 3 "
          . "--ec2-ami '" . $helper_ami_id . "' "
          . "--type '" . $instance_type . "' "
          . "--user '" . $self->provider_client->username . "' "
          . "--boot-mode '" . get_var('PUBLIC_CLOUD_EC2_BOOT_MODE', 'uefi-preferred') . "' "
          . ($sec_group ? "--security-group-ids '" . $sec_group . "' " : '')
          . ($vpc_subnet ? "--vpc-subnet-id '" . $vpc_subnet . "' " : '')
          . "'$file'",
        timeout => 60 * 60
    );

    my $ami = $self->find_img($img_name);
    die("Cannot find image after upload!") unless $ami;
    script_run("aws ec2 create-tags --resources $ami --tags Key=pcw_ignore,Value=1") if (check_var('PUBLIC_CLOUD_KEEP_IMG', '1'));
    validate_script_output('aws ec2 describe-images --image-id ' . $ami, sub { /"EnaSupport":\s+true/ });
    record_info('INFO', "AMI: $ami");    # Show the ami-* number, could be useful
}

sub terraform_apply {
    my ($self, %args) = @_;
    $args{confidential_compute} = get_var("PUBLIC_CLOUD_CONFIDENTIAL_VM", 0);
    return $self->SUPER::terraform_apply(%args);
}

sub on_terraform_apply_timeout {
    my ($self) = @_;
}

sub upload_boot_diagnostics {
    my ($self, %args) = @_;
    my $instance_id = $self->get_terraform_output('.vm_name.value[]');
    return if (check_var('PUBLIC_CLOUD_SLES4SAP', 1));
    unless (defined($instance_id)) {
        record_info('UNDEF. diagnostics', 'upload_boot_diagnostics: on ec2, undefined instance');
        return;
    }
    my $dt = DateTime->now;
    my $time = $dt->hms;
    $time =~ s/:/-/g;
    my $asset_path = "/tmp/console-$time.txt";
    script_run("aws ec2 get-console-output --latest --color=off --no-paginate --output text --instance-id $instance_id &> $asset_path", proceed_on_failure => 1);
    if (script_output("du $asset_path | cut -f1") < 8) {
        record_info("EMPTY", "The console log is empty. `cat $asset_path`:\n" . script_output("cat $asset_path"));
    } elsif (check_var('PUBLIC_CLOUD_INSTANCE_TYPE', 'i3.large')) {
        record_info('UNSUPPORTED_INSTANCE', "The 'i3.large' instance doesn't support serial terminal.");
    } else {
        upload_logs("$asset_path", failok => 1);
    }

    $asset_path = "/tmp/console-$time.jpg";
    script_run("aws ec2 get-console-screenshot --instance-id $instance_id | jq -r '.ImageData' | base64 --decode > $asset_path");
    if (script_output("du $asset_path | cut -f1") < 8) {
        record_info('empty screenshot', 'The console screenshot is empty.');
        record_info($asset_path, script_output("cat $asset_path"));
    } else {
        upload_logs("$asset_path", failok => 1);
    }
}

sub img_proof {
    my ($self, %args) = @_;

    $args{instance_type} //= 't3a.large';
    $args{user} //= 'ec2-user';
    $args{provider} //= 'ec2';
    $args{ssh_private_key_file} //= SSH_KEY_PEM;
    $args{key_name} //= $self->ssh_key;

    return $self->run_img_proof(%args);
}

sub teardown {
    my ($self, $args) = @_;

    $self->SUPER::teardown();
    $self->delete_keypair();
    return 1;
}

sub describe_instance {
    my ($self, $instance_id, $query) = @_;
    my $region = get_required_var('PUBLIC_CLOUD_REGION');
    chomp($query);
    return script_output("aws ec2 describe-instances --filter Name=instance-id,Values=$instance_id --region $region | jq -r '.Reservations[0].Instances[0]" . $query . "'", quiet => 1);
}

sub get_state_from_instance {
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    return $self->describe_instance($instance_id, '.State.Name');
}

sub get_public_ip {
    my ($self) = @_;
    my $instance_id = $self->get_terraform_output('.vm_name.value[]');
    return $self->describe_instance($instance_id, '.PublicIpAddress');
}

sub stop_instance
{
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    my $attempts = 60;

    die("Outdated instance object") if ($instance->public_ip ne $self->get_public_ip());

    assert_script_run('aws ec2 stop-instances --instance-ids ' . $instance_id, quiet => 1);

    while ($self->get_state_from_instance($instance) ne 'stopped' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $instance_id") unless ($attempts > 0);
}

sub start_instance {
    my ($self, $instance, %args) = @_;
    my $attempts = 60;
    my $instance_id = $instance->instance_id();

    my $state = $self->describe_instance($instance_id, '.State.Name');
    die("Try to start a running instance") if ($state ne 'stopped');

    assert_script_run("aws ec2 start-instances --instance-ids $instance_id", quiet => 1);
    sleep 1;    # give some time to update public_ip
    my $public_ip;
    while (!defined($public_ip) && $attempts-- > 0) {
        $public_ip = $self->get_public_ip();
    }
    die("Unable to get new public IP") unless ($public_ip);
    $instance->public_ip($public_ip);
}

sub change_instance_type {
    my ($self, $instance, $instance_type) = @_;
    my $instance_id = $instance->instance_id();
    die "Instance type is already $instance_type" if ($self->describe_instance($instance_id, '.InstanceType') eq $instance_type);
    assert_script_run("aws ec2 modify-instance-attribute --instance-id $instance_id --instance-type '{\"Value\": \"$instance_type\"}'");
    die "Failed to change instance type to $instance_type" if ($self->describe_instance($instance_id, '.InstanceType') ne $instance_type);
}

sub query_metadata {
    my ($self, $instance, %args) = @_;
    my $ifNum = $args{ifNum};
    my $addrCount = $args{addrCount};

    # Cloud metadata service API is reachable at local destination
    # 169.254.169.254 in case of all public cloud providers.
    my $pc_meta_api_ip = '169.254.169.254';

    my $access_token = $instance->ssh_script_output(qq(curl -sw "\\n" -X PUT http://$pc_meta_api_ip/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds:60"));
    record_info("DEBUG", $access_token);
    my $query_meta_ipv4_cmd = qq(curl -sw "\\n" -H "X-aws-ec2-metadata-token: $access_token" "http://$pc_meta_api_ip/latest/meta-data/local-ipv4");
    my $data = $instance->ssh_script_output($query_meta_ipv4_cmd);

    die("Failed to get data from metadata server") unless length($data);
    return $data;
}

1;
