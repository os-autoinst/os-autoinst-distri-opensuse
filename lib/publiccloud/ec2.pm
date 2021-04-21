# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Helper class for amazon ec2
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::ec2;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use publiccloud::utils "is_byos";

use constant CREDENTIALS_FILE => '/root/amazon_credentials';

has ssh_key      => undef;
has ssh_key_file => undef;
has credentials  => undef;

sub vault_create_credentials {
    my ($self) = @_;

    record_info('INFO', 'Get credentials from VAULT server.');
    my $data = $self->vault_get_secrets('/aws/creds/openqa-role');
    $self->key_id($data->{access_key});
    $self->key_secret($data->{secret_key});
    die('Failed to retrieve key') unless (defined($self->key_id) && defined($self->key_secret));
}

sub _check_credentials {
    my ($self) = @_;
    my $max_tries = 6;
    for my $i (1 .. $max_tries) {
        my $out = script_output('aws ec2 describe-images --dry-run', 300, proceed_on_failure => 1);
        return 1 if ($out !~ /AuthFailure/m && $out !~ /"aws configure"/m);
        sleep 30;
    }
    return;
}

sub init {
    my ($self, %params) = @_;
    $self->SUPER::init();

    if (!defined($self->key_id) || !defined($self->key_secret)) {
        $self->vault_create_credentials();
    }

    assert_script_run("export AWS_ACCESS_KEY_ID=" . $self->key_id);
    assert_script_run("export AWS_SECRET_ACCESS_KEY=" . $self->key_secret);
    assert_script_run('export AWS_DEFAULT_REGION="' . $self->region . '"');

    die('Credentials are invalid') unless ($self->_check_credentials());

    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        my $credentials_file = "[default]" . $/
          . 'aws_access_key_id=' . $self->key_id . $/
          . 'aws_secret_access_key=' . $self->key_secret;

        save_tmp_file(CREDENTIALS_FILE, $credentials_file);
        assert_script_run('curl -O ' . autoinst_url . "/files/" . CREDENTIALS_FILE);
    }
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

sub create_keypair {
    my ($self, $prefix, $out_file) = @_;

    return $self->ssh_key if ($self->ssh_key);

    for my $i (0 .. 9) {
        my $key_name = $prefix . "_" . $i;
        my $cmd      = "aws ec2 create-key-pair --key-name '" . $key_name
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
            # suse-sles-15-sp2-byos-v20210310-hvm-ssd-x86_64
            'us-west-1-byos' => 'ami-00dce4ab26f53989c',
            # suse-sles-15-sp2-v20210310-hvm-ssd-x86_64
            'us-west-1' => 'ami-099dc1001c74f4813',
            # suse-sles-15-sp2-byos-v20210310-hvm-ssd-x86_64
            'us-west-2-byos' => 'ami-088f33f7fdcd2e657',
            # suse-sles-15-sp2-v20210310-hvm-ssd-x86_64
            'us-west-2' => 'ami-072cfc789636fd055',
            # suse-sles-15-sp2-byos-v20210310-hvm-ssd-x86_64
            'eu-central-1-byos' => 'ami-0e0c1a6d906f89e31',
            # suse-sles-15-sp2-v20210310-hvm-ssd-x86_64
            'eu-central-1' => 'ami-0174e85f7925868aa',
            # suse-sles-15-sp2-v20210303-hvm-ssd-arm64
            'eu-central-1-arm64' => 'ami-0b01dd8e9169233b8',
            # suse-sles-15-sp2-byos-v20210303-hvm-ssd-arm64
            'eu-central-1-byos-arm64' => 'ami-0c8748d383cef954d'
        };

        my $ami_id_key = $self->region;
        $ami_id_key .= '-byos'  if is_byos();
        $ami_id_key .= '-arm64' if check_var('PUBLIC_CLOUD_ARCH', 'arm64');
        $helper_ami_id = $ami_id_hash->{$ami_id_key} if exists($ami_id_hash->{$ami_id_key});
    }

    die('Unable to detect AMI for helper VM') unless (defined($helper_ami_id));

    my ($img_name)    = $file =~ /([^\/]+)$/;
    my $img_arch      = get_var('PUBLIC_CLOUD_ARCH', 'x86_64');
    my $sec_group     = get_var('PUBLIC_CLOUD_EC2_UPLOAD_SECGROUP');
    my $vpc_subnet    = get_var('PUBLIC_CLOUD_EC2_UPLOAD_VPCSUBNET');
    my $instance_type = get_var('PUBLIC_CLOUD_EC2_UPLOAD_INSTANCE_TYPE', 't2.micro');

    # ec2uploadimg will fail without this file, but we can have it empty
    # because we passing all needed info via params anyway
    assert_script_run('echo " " > /root/.ec2utils.conf');

    assert_script_run("ec2uploadimg --access-id '" . $self->key_id
          . "' -s '" . $self->key_secret . "' "
          . "--backing-store ssd "
          . "--grub2 "
          . "--machine '" . $img_arch . "' "
          . "-n '" . $self->prefix . '-' . $img_name . "' "
          . "--virt-type hvm --sriov-support "
          . (is_byos() ? '' : '--use-root-swap ')
          . '--ena-support '
          . "--verbose "
          . "--regions '" . $self->region . "' "
          . "--ssh-key-pair '" . $self->ssh_key . "' "
          . "--private-key-file " . $self->ssh_key_file . " "
          . "-d 'OpenQA upload image' "
          . "--wait-count 3 "
          . "--ec2-ami '" . $helper_ami_id . "' "
          . "--type '" . $instance_type . "' "
          . "--user '" . $self->username . "' "
          . ($sec_group  ? "--security-group-ids '" . $sec_group . "' " : '')
          . ($vpc_subnet ? "--vpc-subnet-id '" . $vpc_subnet . "' "     : '')
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

    $args{instance_type}        //= 't2.large';
    $args{user}                 //= 'ec2-user';
    $args{provider}             //= 'ec2';
    $args{ssh_private_key_file} //= $self->ssh_key_file;
    $args{key_id}               //= $self->key_id;
    $args{key_secret}           //= $self->key_secret;
    $args{key_name}             //= $self->ssh_key;

    return $self->run_img_proof(%args);
}

sub cleanup {
    my ($self) = @_;
    $self->terraform_destroy();
    $self->delete_keypair();
    $self->vault_revoke();
}

sub describe_instance
{
    my ($self, $instance) = @_;
    my $json_output = decode_json(script_output('aws ec2 describe-instances --filter Name=instance-id,Values=' . $instance->instance_id(), quiet => 1));
    my $i_desc      = $json_output->{Reservations}->[0]->{Instances}->[0];
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
    my $attempts    = 60;

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
    my $attempts    = 60;
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
