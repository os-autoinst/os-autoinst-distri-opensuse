# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon connection and authentication
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

package publiccloud::aws_client;
use Mojo::Base -base;
use testapi;
use publiccloud::vault;
use publiccloud::utils;

has key_id => undef;
has key_secret => undef;
has security_token => undef;
has region => sub { get_var('PUBLIC_CLOUD_REGION', 'eu-central-1') };
has vault => undef;
has aws_account_id => undef;
has service => undef;
has container_registry => sub { get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY", 'suse-qec-testing') };
has username => sub { get_var('PUBLIC_CLOUD_USER', 'ec2-user') };

sub vault_create_credentials {
    my ($self) = @_;
    my $data = undef;

    if ($self->service =~ /ECR|EC2/) {
        record_info('INFO', 'Get credentials from VAULT server.');
        $data = $self->vault->get_secrets('/aws/creds/openqa-role');
    } elsif ($self->service eq "EKS") {
        record_info('INFO', 'Get credentials from VAULT server for EKS');
        my $path = '/aws/sts/openqa-role-eks';
        my $res
          = $self->vault->api('/v1/' . get_required_var('PUBLIC_CLOUD_VAULT_NAMESPACE') . $path, method => 'post');
        $data = $res->{data};
        $self->security_token($data->{security_token});
        define_secret_variable("AWS_SESSION_TOKEN", $self->security_token);
        die('Failed to retrieve token') unless (defined($self->security_token));
    } else {
        die('Invalid service: ' . $self->service);
    }

    die('Failed to retrieve key') unless (defined($data->{access_key}) && defined($data->{secret_key}));
    $self->key_id($data->{access_key});
    $self->key_secret($data->{secret_key});
}

sub _check_credentials {
    my ($self) = @_;
    if ($self->service =~ /ECR|EC2/) {
        my $max_tries = 6;
        for my $i (1 .. $max_tries) {
            my $out = script_output('aws ec2 describe-images --dry-run', 300, proceed_on_failure => 1);
            return 1 if ($out !~ /AuthFailure/m && $out !~ /"aws configure"/m);
            sleep 30;
        }
    } elsif ($self->service eq "EKS") {
        return 1;
    } else {
        die('Invalid service: ' . $self->service);
    }

    return;
}

sub init {
    my ($self, %params) = @_;

    $self->service("EC2") unless (defined($self->service));

    if (get_var('PUBLIC_CLOUD_CREDENTIALS_URL')) {
        my $data = get_credentials('aws.json');
        if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
            $self->key_id($data->{access_key});
            $self->key_secret($data->{secret_key});
        } else {
            $self->key_id($data->{access_key_id});
            $self->key_secret($data->{secret_access_key});
        }
    } elsif (!defined($self->key_id) || !defined($self->key_secret)) {
        $self->vault(publiccloud::vault->new());
        $self->vault_create_credentials();
    }

    assert_script_run('export AWS_DEFAULT_REGION="' . $self->region . '"');
    define_secret_variable("AWS_ACCESS_KEY_ID", $self->key_id);
    define_secret_variable("AWS_SECRET_ACCESS_KEY", $self->key_secret);

    die('Credentials are invalid') unless ($self->_check_credentials());

    # AWS STS is the secure token service, which is used for those credentials
    $self->aws_account_id(script_output("aws sts get-caller-identity | jq -r '.Account'"));
    die("Cannot get the UserID") unless ($self->aws_account_id);
    die("The UserID doesn't have the correct format: $self->{user_id}") unless $self->aws_account_id =~ /^\d{12}$/;
}

=head2 get_container_image_full_name

Returns the full name of the container image in ECR registry
C<tag> Tag of the container
=cut

sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = sprintf('%s.dkr.ecr.%s.amazonaws.com', $self->aws_account_id, $self->region);

    return "$full_name_prefix/" . $self->container_registry . ":$tag";
}

=head2 configure_podman

Configure the podman to access the cloud provider registry
=cut

sub configure_podman {
    my ($self) = @_;
    my $full_name_prefix = sprintf('%s.dkr.ecr.%s.amazonaws.com', $self->aws_account_id, $self->region);

    assert_script_run("aws ecr get-login-password --region "
          . $self->region
          . " | podman login --username AWS --password-stdin $full_name_prefix");
}

sub cleanup {
    my ($self) = @_;
    $self->vault->revoke() unless (get_var('PUBLIC_CLOUD_CREDENTIALS_URL'));
}

1;
