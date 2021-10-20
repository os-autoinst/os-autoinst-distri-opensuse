# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper class for amazon connection and authentication
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>, qa-c team <qa-c@suse.de>

package publiccloud::aws;
use Mojo::Base 'publiccloud::provider';
use Mojo::JSON 'decode_json';
use testapi;
use mmapi 'get_current_job_id';

use constant CREDENTIALS_FILE => '/root/amazon_credentials';

has ssh_key => undef;
has ssh_key_file => undef;
has credentials => undef;
has container_registry => undef;

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

    $self->{aws_account_id} = script_output("aws sts get-caller-identity | jq -r '.Account'");
    die("Cannot get the UserID") unless ($self->{aws_account_id});
    die("The UserID doesn't have the correct format: $self->{user_id}") unless $self->{aws_account_id} =~ /^\d{12}$/;

    $self->container_registry(get_var("PUBLIC_CLOUD_CONTAINER_IMAGES_REGISTRY", 'suse-qec-testing'));
}

=head2 get_container_registry_prefix
Get the full registry prefix URL for any containers image registry of ECR based on the account and region
=cut
sub get_container_registry_prefix {
    my ($self) = @_;
    my $region = $self->region;
    my $aws_account_id = $self->{aws_account_id};
    my $full_name_prefix = sprintf('%s.dkr.ecr.%s.amazonaws.com', $aws_account_id, $region);
    return $full_name_prefix;
}

=head2 get_container_image_full_name
Get the full name for a container image in ECR registry
=cut
sub get_container_image_full_name {
    my ($self, $tag) = @_;
    my $full_name_prefix = $self->get_container_registry_prefix();
    return "$full_name_prefix/" . $self->container_registry . ":$tag";
}

=head2 get_default_tag
Returns a default tag for container images based of the current job id
=cut
sub get_default_tag {
    my ($self) = @_;
    return join('-', get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm'), get_current_job_id());
}
1;
