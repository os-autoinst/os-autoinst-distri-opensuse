# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon ec2
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

package publiccloud::ec2;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use publiccloud::utils "is_byos";
use publiccloud::aws_client;
use publiccloud::ssh_interactive 'select_host_console';

has ssh_key_file => undef;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->provider_client(publiccloud::aws_client->new());
    $self->provider_client->init();
}

sub find_img {
    my ($self, $name) = @_;

    $name = $self->prefix . '-' . $name;

    my $out = script_output("aws ec2 describe-images  --filters 'Name=name,Values=$name'");
    if ($out =~ /"ImageId":\s+"([^"]+)"/) {
        return $1;
    }
    return;
}

sub get_default_instance_type {
    # Returns the default machine family type to be used, based on the public cloud architecture

    my $arch = get_var("PUBLIC_CLOUD_ARCH", "x86_64");
    return "a1.large" if ($arch eq 'arm64');
    return "t2.large";
}

sub create_keypair {
    my ($self, $prefix, $out_file) = @_;

    return $self->ssh_key_file if ($self->ssh_key_file);

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd = "aws ec2 create-key-pair --key-name '" . $key_name
          . "' --query 'KeyMaterial' --output text > " . $out_file;
        my $ret = script_run($cmd);
        if (defined($ret) && $ret == 0) {
            assert_script_run('chmod 600 ' . $out_file);
            $self->ssh_key($key_name);
            $self->ssh_key_file($out_file);
            return $key_name;
        }
    }
    return;
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

    die("Create key-pair failed") unless ($self->create_keypair($self->prefix . time, 'QA_SSH_KEY.pem'));

    # AMI of image to use for helper VM to create/build the image on CSP.
    my $helper_ami_id = get_var('PUBLIC_CLOUD_EC2_UPLOAD_AMI');

    # in case AMI for helper VM is not provided in job settings fallback to predefined hash
    unless (defined($helper_ami_id)) {

        # AMI is region specific also we need to use different AMI's for on-demand/BYOS uploads
        my $ami_id_hash = {
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-x86_64
            'us-west-1-byos' => 'ami-0cf60a7351ac9f023',
            # suse-sles-15-sp4-v20220915-hvm-ssd-x86_64
            'us-west-1' => 'ami-095b00d1799acbc5d',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-x86_64
            'us-west-2-byos' => 'ami-02538b480fd1330ac',
            # suse-sles-15-sp4-v20220915-hvm-ssd-x86_64
            'us-west-2' => 'ami-0fbef12dbf17e9796',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-x86_64
            'eu-central-1-byos' => 'ami-01fee8ad5154e745b',
            # suse-sles-15-sp4-v20220915-hvm-ssd-x86_64
            'eu-central-1' => 'ami-0622ab5c21c604604',
            # suse-sles-15-sp4-v20220915-hvm-ssd-arm64
            'eu-central-1-arm64' => 'ami-0f33a69f25295ee23',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-arm64
            'eu-central-1-byos-arm64' => 'ami-0fe6d5a106cf46cce',
            # suse-sles-15-sp4-v20220915-hvm-ssd-x86_64
            'eu-west-1' => 'ami-0ddb9fc2019be3eef',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-x86_64
            'eu-west-1-byos' => 'ami-0067ff53440565874',
            # suse-sles-15-sp4-v20220915-hvm-ssd-arm64
            'eu-west-1-arm64' => 'ami-06033303bb6c72a35',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-arm64
            'eu-west-1-byos-arm64' => 'ami-0e70bccfe7758f9fe',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-x86_64
            'us-east-2-byos' => 'ami-00d3e0231db6eeee3',
            # suse-sles-15-sp4-v20220915-hvm-ssd-x86_64
            'us-east-2' => 'ami-0ca19ecee2be612fc',
            # suse-sles-15-sp4-v20220915-hvm-ssd-arm64
            'us-east-1-arm64' => 'ami-05dbc19aca86fdae4',
            # suse-sles-15-sp4-byos-v20220915-hvm-ssd-arm64
            'us-east-1-byos-arm64' => 'ami-0e0756f0108a91de8',
        };

        my $ami_id_key = $self->provider_client->region;
        $ami_id_key .= '-byos' if is_byos();
        $ami_id_key .= '-arm64' if check_var('PUBLIC_CLOUD_ARCH', 'arm64');
        $helper_ami_id = $ami_id_hash->{$ami_id_key} if exists($ami_id_hash->{$ami_id_key});
    }

    die('Unable to detect AMI for helper VM') unless (defined($helper_ami_id));

    my ($img_name) = $file =~ /([^\/]+)$/;
    my $img_arch = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    my $sec_group = get_var('PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP');
    my $vpc_subnet = get_var('PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET');
    my $instance_type = get_var('PUBLIC_CLOUD_EC2_UPLOAD_INSTANCE_TYPE', get_default_instance_type());

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
          . "--ssh-key-pair '" . $self->ssh_key . "' "
          . "--private-key-file " . $self->ssh_key_file . " "
          . "-d 'OpenQA upload image' "
          . "--wait-count 3 "
          . "--ec2-ami '" . $helper_ami_id . "' "
          . "--type '" . $instance_type . "' "
          . "--user '" . $self->provider_client->username . "' "
          . ($sec_group ? "--security-group-ids '" . $sec_group . "' " : '')
          . ($vpc_subnet ? "--vpc-subnet-id '" . $vpc_subnet . "' " : '')
          . "'$file'",
        timeout => 60 * 60
    );

    my $ami = $self->find_img($img_name);
    die("Cannot find image after upload!") unless $ami;
    validate_script_output('aws ec2 describe-images --image-id ' . $ami, sub { /"EnaSupport":\s+true/ });
    record_info('INFO', "AMI: $ami");    # Show the ami-* number, could be useful
    return $ami;
}

sub img_proof {
    my ($self, %args) = @_;

    $args{instance_type} //= 't2.large';
    $args{user} //= 'ec2-user';
    $args{provider} //= 'ec2';
    $args{ssh_private_key_file} //= $self->ssh_key_file;
    $args{key_name} //= $self->ssh_key;

    return $self->run_img_proof(%args);
}

sub cleanup {
    my ($self, $args) = @_;
    my $instance_id = $args->{my_instance}->{instance_id};

    select_host_console(force => 1);

    script_run("aws ec2 get-console-output --instance-id $instance_id | jq -r '.Output' > console.txt");
    upload_logs("console.txt", failok => 1);

    script_run("aws ec2 get-console-screenshot --instance-id $instance_id | jq -r '.ImageData' | base64 --decode > console.jpg");
    upload_logs("console.jpg", failok => 1);

    $self->terraform_destroy() if ($self->terraform_applied);
    $self->delete_keypair();
    $self->provider_client->cleanup();
}

sub describe_instance
{
    my ($self, $instance) = @_;
    my $json_output = decode_json(script_output('aws ec2 describe-instances --filter Name=instance-id,Values=' . $instance->instance_id(), quiet => 1));
    my $i_desc = $json_output->{Reservations}->[0]->{Instances}->[0];
    return $i_desc;
}

sub get_state_from_instance
{
    my ($self, $instance) = @_;
    return $self->describe_instance($instance)->{State}->{Name};
}

sub get_ip_from_instance
{
    my ($self, $instance) = @_;
    return $self->describe_instance($instance)->{PublicIpAddress};
}

sub stop_instance
{
    my ($self, $instance) = @_;
    my $instance_id = $instance->instance_id();
    my $attempts = 60;

    die("Outdated instance object") if ($instance->public_ip ne $self->get_ip_from_instance($instance));

    assert_script_run('aws ec2 stop-instances --instance-ids ' . $instance_id, quiet => 1);

    while ($self->get_state_from_instance($instance) ne 'stopped' && $attempts-- > 0) {
        sleep 5;
    }
    die("Failed to stop instance $instance_id") unless ($attempts > 0);
}

sub start_instance
{
    my ($self, $instance, %args) = @_;
    my $attempts = 60;
    my $instance_id = $instance->instance_id();

    my $i_desc = $self->describe_instance($instance);
    die("Try to start a running instance") if ($i_desc->{State}->{Name} ne 'stopped');

    assert_script_run("aws ec2 start-instances --instance-ids $instance_id", quiet => 1);
    sleep 1;    # give some time to update public_ip
    my $public_ip;
    while (!defined($public_ip) && $attempts-- > 0) {
        $public_ip = $self->get_ip_from_instance($instance);
    }
    die("Unable to get new public IP") unless ($public_ip);
    $instance->public_ip($public_ip);
}

1;
