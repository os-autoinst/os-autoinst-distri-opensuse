# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base helper class for public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::provider;
use testapi qw(is_serial_terminal :DEFAULT);
use Mojo::Base -base;
use publiccloud::instance;
use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use utils qw(file_content_replace script_retry);
use mmapi;

use constant TERRAFORM_DIR => '/root/terraform';
use constant TERRAFORM_TIMEOUT => 30 * 60;

has key_id => undef;
has key_secret => undef;
has region => undef;
has username => undef;
has prefix => 'openqa';
has terraform_applied => 0;
has vault_token => undef;
has vault_lease_id => undef;

=head1 METHODS

=head2 init

Needs provider specific credentials, e.g. key_id, key_secret, region.

=cut
sub init {
    my ($self) = @_;
    my $file = lc get_var('PUBLIC_CLOUD_PROVIDER');
    assert_script_run('mkdir -p ' . TERRAFORM_DIR);
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        my $cloud_name = $self->conv_openqa_tf_name;
        # Disable SSL verification only if explicitly asked!
        assert_script_run('git config --global http.sslVerify false') if get_var('HA_SAP_GIT_NO_VERIFY');
        assert_script_run('cd ' . TERRAFORM_DIR);
        assert_script_run('git clone --depth 1 --branch ' . get_var('HA_SAP_GIT_TAG', 'master') . ' ' . get_required_var('HA_SAP_GIT_REPO') . ' .');
        # By default use the default provided Salt formula packages
        assert_script_run('rm -f requirements.yml') unless get_var('HA_SAP_USE_REQUIREMENTS');
        assert_script_run('cd');    # We need to ensure to be in the home directory
        assert_script_run('curl ' . data_url("publiccloud/terraform/sap/$file.tfvars") . ' -o ' . TERRAFORM_DIR . "/$cloud_name/terraform.tfvars");
    }
    else {
        assert_script_run('curl ' . data_url("publiccloud/terraform/$file.tf") . ' -o ' . TERRAFORM_DIR . '/plan.tf');
    }
    $self->create_ssh_key();
}

=head2 conv_openqa_tf_name

Does the conversion between C<PUBLIC_CLOUD_PROVIDER> and Terraform providers name.

=cut
sub conv_openqa_tf_name {
    # Check https://github.com/SUSE/ha-sap-terraform-deployments/issues/177 for more information
    my $cloud_provider = lc get_var('PUBLIC_CLOUD_PROVIDER');
    return 'aws' if $cloud_provider eq 'ec2';
    return 'gcp' if $cloud_provider eq 'gce';
    return $cloud_provider;
}

=head2 find_img

Retrieves the image-id by given image C<name>.

=cut
sub find_img {
    die('find_image() isn\'t implemented');
}

=head2 upload_image

Upload a image to the CSP. Required parameter is the
location of the C<image> file.
UEFI images are supported by giving the optional
parameter C<type> = 'uefi'. This is only supported
on GCE at the momment.

Retrieves the image-id after upload or die.

=cut
sub upload_image {
    die('find_image() isn\'t implemented');
}


=head2 img_proof

  img_proof(instance_type => <string>, cleanup => <bool>, tests => <string>, timeout => <seconds>, results_dir => <string>, distro => <string>);

Call img-proof tool and retrieves a hashref as result. Do not die if img-proof call exit with error.
  $result_hash = {
        instance    => <publiccloud:instance>,    # instance object
        logfile     => <string>,                  # the pytest logfile
        results     => <string>,                  # json results file
        tests       => <int>,                     # total number of tests
        pass        => <int>,                     # successful tests
        skip        => <int>,                     # skipped tests
        fail        => <int>,                     # number of failed tests
        error       => <int>,                     # number of errors
  };

=cut
sub img_proof {
    die('img_proof() isn\'t implemented');
}

=head2 parse_img_proof_output

Parse the output from img-proof command and retrieves instance-id, ip and logfile names.

=cut
sub parse_img_proof_output {
    my ($self, $output) = @_;
    my $ret = {};
    my $instance_id;
    my $ip;

    for my $line (split(/\r?\n/, $output)) {
        if ($line =~ m/^ID of instance: (\S+)$/) {
            $ret->{instance_id} = $1;
        }
        elsif ($line =~ m/^Terminating instance (\S+)$/) {
            $ret->{instance_id} = $1;
        }
        elsif ($line =~ m/^IP of instance: (\S+)$/) {
            $ret->{ip} = $1;
        }
        elsif ($line =~ m/^Created log file (\S+)$/) {
            $ret->{logfile} = $1;
        }
        elsif ($line =~ m/^Created results file (\S+)$/) {
            $ret->{results} = $1;
        }
        elsif ($line =~ m/tests=(\d+)\|pass=(\d+)\|skip=(\d+)\|fail=(\d+)\|error=(\d+)/) {
            $ret->{tests} = $1;
            $ret->{pass} = $2;
            $ret->{skip} = $3;
            $ret->{fail} = $4;
            $ret->{error} = $5;
        }
    }

    for my $k (qw(ip logfile results tests pass skip fail error)) {
        return unless (exists($ret->{$k}));
    }
    return $ret;
}

=head2 create_ssh_key

Creates an ssh keypair in a given file path by $args{ssh_private_key_file}

=cut
sub create_ssh_key {
    my ($self, %args) = @_;
    $args{ssh_private_key_file} //= '/root/.ssh/id_rsa';
    if (script_run('test -f ' . $args{ssh_private_key_file}) != 0) {
        assert_script_run('SSH_DIR=`dirname ' . $args{ssh_private_key_file} . '`; mkdir -p $SSH_DIR');
        assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -m pem -f ' . $args{ssh_private_key_file});
    }
}

=head2 run_img_proof

called by childs within img-proof function

=cut
sub run_img_proof {
    my ($self, %args) = @_;
    die('Must provide an instance object') if (!$args{instance});

    $args{tests} //= '';
    $args{timeout} //= 60 * 120;
    $args{results_dir} //= 'img_proof_results';
    $args{distro} //= 'sles';
    $args{tests} =~ s/,/ /g;

    my $version = script_output('img-proof --version', 300);
    record_info("img-proof version", $version);

    my $cmd = 'img-proof --no-color test ' . $args{provider};
    $cmd .= ' --debug ';
    $cmd .= "--distro " . $args{distro} . " ";
    $cmd .= '--region "' . $self->region . '" ';
    $cmd .= '--results-dir "' . $args{results_dir} . '" ';
    $cmd .= '--no-cleanup ';
    $cmd .= '--collect-vm-info ';
    $cmd .= '--service-account-file "' . $args{credentials_file} . '" ' if ($args{credentials_file});
    $cmd .= "--access-key-id '" . $args{key_id} . "' " if ($args{key_id});
    $cmd .= "--secret-access-key '" . $args{key_secret} . "' " if ($args{key_secret});
    $cmd .= "--ssh-key-name '" . $args{key_name} . "' " if ($args{key_name});
    $cmd .= '-u ' . $args{user} . ' ' if ($args{user});
    $cmd .= '--ssh-private-key-file "' . $args{instance}->ssh_key . '" ';
    $cmd .= '--running-instance-id "' . ($args{running_instance_id} // $args{instance}->instance_id) . '" ';

    $cmd .= $args{tests};
    record_info("img-proof cmd", $cmd);

    my $output = script_output($cmd . ' 2>&1', $args{timeout}, proceed_on_failure => 1);
    record_info("img-proof output", $output);
    my $img_proof = $self->parse_img_proof_output($output);
    record_info("img-proof results", Dumper($img_proof));
    die($output) unless (defined($img_proof));

    $args{instance}->public_ip($img_proof->{ip});
    delete($img_proof->{instance_id});
    delete($img_proof->{ip});

    return $img_proof;
}

=head2 get_image_id

    get_image_id([$img_url]);

Retrieves the CSP image id if exists, otherwise exception is thrown.
The given C<$img_url> is optional, if not present it retrieves from
PUBLIC_CLOUD_IMAGE_LOCATION.
If PUBLIC_CLOUD_IMAGE_ID is set, then this value will be used
=cut
sub get_image_id {
    my ($self, $img_url) = @_;
    my $predefined_id = get_var('PUBLIC_CLOUD_IMAGE_ID');
    return $predefined_id if ($predefined_id);
    $img_url //= get_required_var('PUBLIC_CLOUD_IMAGE_LOCATION');
    my ($img_name) = $img_url =~ /([^\/]+)$/;
    $self->{image_cache} //= {};
    return $self->{image_cache}->{$img_name} if ($self->{image_cache}->{$img_name});
    my $image_id = $self->find_img($img_name);
    die("Image $img_name is not available in the cloud provider") unless ($image_id);
    $self->{image_cache}->{$img_name} = $image_id;
    return $image_id;
}

=head2 create_instance

Creates an instance on the public cloud provider. Retrieves a publiccloud::instance
object.

C<image>         defines the image_id to create the instance.
C<instance_type> defines the flavor of the instance. If not specified, it will load it
                     from PUBLIC_CLOUD_INSTANCE_TYPE.

=cut
sub create_instance {
    return (shift->create_instances(@_))[0];
}

=head2 create_instances

Creates multiple instances on the public cloud provider. Retrieves an array of
publiccloud::instance objects.

C<image>         defines the image_id to create the instance.
C<instance_type> defines the flavor of the instance. If not specified, it will load it
                     from PUBLIC_CLOUD_INSTANCE_TYPE.

=cut
sub create_instances {
    my ($self, %args) = @_;
    $args{check_connectivity} //= 1;

    my @vms = $self->terraform_apply(%args);
    foreach my $instance (@vms) {
        record_info("INSTANCE $instance->{instance_id}", Dumper($instance));
        $instance->wait_for_ssh() if ($args{check_connectivity});
    }
    return @vms;
}

=head2 on_terraform_apply_timeout

This method can be overwritten by child classes to do some special
cleanup task if 'apply' fails.
Terraform was already terminated using the QUIT signal and openqa has a
valid shell.
The working directory is always the terraform directory, where the statefile
and the *.tf is placed.

=cut
sub on_terraform_apply_timeout {
}

=head2 on_terraform_destroy_timeout

This method can be overwritten by child classes to do some special
cleanup task if 'destroy' fails.
Terraform was already terminated using the QUIT signal and openqa has a
valid shell.
The working directory is always the terraform directory, where the statefile
and the *.tf is placed.

=cut
sub on_terraform_destroy_timeout {
}

=head2 terraform_apply

Calls terraform tool and applies the corresponding configuration .tf file

=cut
sub terraform_apply {
    my ($self, %args) = @_;
    my @instances;
    my $create_extra_disk = 'false';
    my $extra_disk_size = 0;
    my $terraform_timeout = get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT);

    $args{count} //= '1';
    my $instance_type = get_var('PUBLIC_CLOUD_INSTANCE_TYPE');
    my $image = $self->get_image_id();
    my $ssh_private_key_file = '/root/.ssh/id_rsa';
    my $name = get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm');
    my $cloud_name = $self->conv_openqa_tf_name;

    record_info('WARNING', 'Terraform apply has been run previously.') if ($self->terraform_applied);

    record_info('INFO', "Creating instance $instance_type from $image ...");
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        assert_script_run('cd ' . TERRAFORM_DIR . "/$cloud_name");
        my $sap_media = get_required_var('HANA');
        my $sap_regcode = get_required_var('SCC_REGCODE_SLES4SAP');
        my $storage_account_name = get_var('STORAGE_ACCOUNT_NAME');
        my $storage_account_key = get_var('STORAGE_ACCOUNT_KEY');
        my $sle_version = get_var('FORCED_DEPLOY_REPO_VERSION') ? get_var('FORCED_DEPLOY_REPO_VERSION') : get_var('VERSION');
        $sle_version =~ s/-/_/g;
        my $ha_sap_repo = get_var('HA_SAP_REPO') ? get_var('HA_SAP_REPO') . '/SLE_' . $sle_version : '';
        file_content_replace('terraform.tfvars',
            q(%MACHINE_TYPE%) => $instance_type,
            q(%REGION%) => $self->region,
            q(%HANA_BUCKET%) => $sap_media,
            q(%SLE_IMAGE%) => $image,
            q(%SCC_REGCODE_SLES4SAP%) => $sap_regcode,
            q(%STORAGE_ACCOUNT_NAME%) => $storage_account_name,
            q(%STORAGE_ACCOUNT_KEY%) => $storage_account_key,
            q(%HA_SAP_REPO%) => $ha_sap_repo,
            q(%SLE_VERSION%) => $sle_version
        );
        upload_logs(TERRAFORM_DIR . "/$cloud_name/terraform.tfvars", failok => 1);
        assert_script_run('terraform workspace new qashapopenqa -no-color', $terraform_timeout);
    }
    else {
        assert_script_run('cd ' . TERRAFORM_DIR);
    }
    script_retry('terraform init -no-color', timeout => $terraform_timeout, delay => 3, retry => 6);

    my $cmd = 'terraform plan -no-color ';
    if (!get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # Some auxiliary variables, requires for fine control and public cloud provider specifics
        for my $key (keys %{$args{vars}}) {
            my $value = $args{vars}->{$key};
            $cmd .= sprintf(q(-var '%s=%s' ), $key, escape_single_quote($value));
        }
        $cmd .= "-var 'image_id=" . $image . "' " if ($image);
        $cmd .= "-var 'instance_count=" . $args{count} . "' ";
        $cmd .= "-var 'type=" . $instance_type . "' ";
        $cmd .= "-var 'region=" . $self->region . "' ";
        $cmd .= "-var 'name=" . $name . "' ";
        $cmd .= "-var 'project=" . $args{project} . "' " if $args{project};
        $cmd .= "-var 'enable_confidential_vm=true' " if $args{confidential_compute};
        $cmd .= sprintf(q(-var 'tags=%s' ), escape_single_quote($self->terraform_param_tags));
        if ($args{use_extra_disk}) {
            $cmd .= "-var 'create-extra-disk=true' ";
            $cmd .= "-var 'extra-disk-size=" . $args{use_extra_disk}->{size} . "' " if $args{use_extra_disk}->{size};
            $cmd .= "-var 'extra-disk-type=" . $args{use_extra_disk}->{type} . "' " if $args{use_extra_disk}->{type};
        }
    }
    if (get_var('FLAVOR') =~ 'UEFI') {
        $cmd .= "-var 'uefi=true' ";
    }

    $cmd .= "-out myplan";
    record_info('TFM cmd', $cmd);

    script_retry($cmd, timeout => $terraform_timeout, delay => 3, retry => 6);
    my $ret = script_run('terraform apply -no-color -input=false myplan', $terraform_timeout);
    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');      # Send QUIT signal
        }
        assert_script_run('true');    # make sure we have a prompt
        record_info('ERROR', 'Terraform apply failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_apply_timeout();
        die('Terraform apply failed with timeout');
    }
    die('Terraform exit with ' . $ret) if ($ret != 0);

    $self->terraform_applied(1);

    my $output = decode_json(script_output("terraform output -json"));
    my $vms;
    my $ips;
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        foreach my $vm_type ('cluster_nodes', 'drbd', 'netweaver') {
            push @{$vms}, @{$output->{$vm_type . '_name'}->{value}};
            push @{$ips}, @{$output->{$vm_type . '_public_ip'}->{value}};
        }
    }
    else {
        $vms = $output->{vm_name}->{value};
        $ips = $output->{public_ip}->{value};
    }

    foreach my $i (0 .. $#{$vms}) {
        my $instance = publiccloud::instance->new(
            public_ip => @{$ips}[$i],
            instance_id => @{$vms}[$i],
            username => $self->username,
            ssh_key => $ssh_private_key_file,
            image_id => $image,
            region => $self->region,
            type => $instance_type,
            provider => $self
        );
        push @instances, $instance;
    }

    # Return an ARRAY of objects 'instance'
    return @instances;
}

=head2 terraform_destroy

Destroys the current terraform deployment

=cut
sub terraform_destroy {
    my ($self) = @_;
    # Do not destroy if terraform has not been applied or the environment doesn't exist
    return unless ($self->terraform_applied);

    my $cmd;
    record_info('INFO', 'Removing terraform plan...');
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        assert_script_run('cd ' . TERRAFORM_DIR . '/' . $self->conv_openqa_tf_name);
        $cmd = 'terraform destroy -no-color -auto-approve';
    }
    else {
        assert_script_run('cd ' . TERRAFORM_DIR);
        # Add region variable also to `terraform destroy` (poo#63604) -- needed by AWS.
        $cmd = sprintf(q(terraform destroy -no-color -auto-approve -var 'region=%s'), $self->region);
    }
    # Retry 3 times with considerable delay. This has been introduced due to poo#95932 (RetryableError)
    # terraform keeps track of the allocated and destroyed resources, so its safe to run this multiple times.
    my $ret = script_retry($cmd, retry => 3, delay => 60, timeout => get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT), die => 0);
    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');      # Send QUIT signal
        }
        assert_script_run('true');    # make sure we have a prompt
        record_info('ERROR', 'Terraform destroy failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_destroy_timeout();
    }
    record_info('ERROR', 'Terraform exited with ' . $ret, result => 'fail') if ($ret != 0);
}

=head2 terraform_param_tags

Build the tags parameter for terraform. It is a single depth json like
c<{"key": "value"}> where c<value> must be a string.
=cut
sub terraform_param_tags
{
    my ($self) = @_;
    my $tags = {
        openqa_ttl => get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300),
        openqa_var_JOB_ID => get_current_job_id(),
        openqa_var_NAME => get_var(NAME => '')
    };

    return encode_json($tags);
}

sub escape_single_quote {
    my $s = shift;
    $s =~ s/'/'"'"'/g;
    return $s;
}

=head2 __vault_login

Login to vault using C<_SECRET_PUBLIC_CLOUD_REST_USER> and
C<_SECRET_PUBLIC_CLOUD_REST_PW>. The retrieved VAULT_TOKEN is stored in this
instance and used for further C<publiccloud::provider::vault_api()> calls.
=cut
sub __vault_login
{
    my ($self) = @_;
    my $url = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $user = get_required_var('_SECRET_PUBLIC_CLOUD_REST_USER');
    my $password = get_required_var('_SECRET_PUBLIC_CLOUD_REST_PW');
    my $ua = Mojo::UserAgent->new;

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $url = $url . '/v1/auth/userpass/login/' . $user;
    my $res = $ua->post($url => json => {password => $password})->result;
    if (!$res->is_success) {
        my $err_msg = 'Request ' . $url . ' failed with: ' . $res->message . ' (' . $res->code . ')';
        $err_msg .= "\n" . join("\n", @{$res->json->{errors}}) if ($res->code == 400);
        record_info('Vault login', $err_msg, result => 'fail');
        die("Vault login failed - $url");
    }

    return $self->vault_token($res->json('/auth/client_token'));
}

=head2 vault_login

Wrapper arround C<<$self->vault_login()>> to have retry capability.
=cut
sub vault_login {
    my $self = shift;
    my $max_tries = get_var('PUBLIC_CLOUD_VAULT_TRIES', 3);
    my $try_cnt = 0;
    my $ret;
    while ($try_cnt++ < $max_tries) {
        eval {
            $ret = $self->__vault_login();
        };
        return $ret unless $@;
        sleep 10;
    }
    die("vault_login() failed after $max_tries attempts -- " . $@);
}

=head2 __vault_api

Invoke a vault API call. It use _SECRET_PUBLIC_CLOUD_REST_URL as base
url.
Depending on the method (get|post) you can pass additional data as json.
=cut
sub __vault_api {
    my ($self, $path, %args) = @_;
    my $method = $args{method} // 'get';
    my $data = $args{data} // {};
    my $ua = Mojo::UserAgent->new;
    my $url = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $res;

    $self->vault_login() unless ($self->vault_token);

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $ua->request_timeout(40);
    $url = $url . $path;
    bmwqemu::diag("Request Vault REST API: $url");
    if ($method eq 'get') {
        $res = $ua->get($url =>
              {'X-Vault-Token' => $self->vault_token()})->result;
    } elsif ($method eq 'post') {
        $res = $ua->post($url =>
              {'X-Vault-Token' => $self->vault_token()} =>
              json => $data)->result;
    } else {
        die("Unknown method $method");
    }

    if (!$res->is_success) {
        my $err_msg = 'Request ' . $url . ' failed with: ' . $res->message . ' (' . $res->code . ')';
        $err_msg .= "\n" . join("\n", @{$res->json->{errors}}) if ($res->code == 400);
        record_info('Vault API', $err_msg, result => 'fail');
        die("Vault REST api call failed - $url");
    }

    return $res->json;
}

=head2 vault_api

Wrapper around C<<$self->vault_api()>> to get retry capability.
=cut
sub vault_api {
    my ($self, $path, %args) = @_;
    my $ret;
    my $max_tries = get_var('PUBLIC_CLOUD_VAULT_TRIES', 3);
    my $try_cnt = 0;

    while ($try_cnt++ < $max_tries) {
        eval {
            $ret = $self->__vault_api($path, %args);
        };
        return $ret unless ($@);
        sleep get_var('PUBLIC_CLOUD_VAULT_TIMEOUT', 60);
    }
    die("vault_api() call failed after $max_tries attempts -- " . $@);
}

=head2 vault_get_secrets

  my $data = $csp->vault_get_secrets('/azure/creds/openqa-role')

This is a wrapper around C<vault_api()> to retrieve secrets from aws, gce or
azure secret engine.
It prepend C<'/v1/' + $NAMESPACE> to the given path before sending the request.
It stores lease_id and also adjust the token-live-time.
=cut
sub vault_get_secrets {
    my ($self, $path) = @_;
    my $res = $self->vault_api('/v1/' . get_var('PUBLIC_CLOUD_VAULT_NAMESPACE', '') . $path, method => 'get');
    $self->vault_lease_id($res->{lease_id});
    $self->vault_api('/v1/auth/token/renew-self', method => 'post', data => {increment => $res->{lease_duration} . 's'});
    return $res->{data};
}

=head2 vault_revoke

Revoke a previous retrieved credential
=cut
sub vault_revoke {
    my ($self) = @_;

    return unless (defined($self->vault_lease_id));

    $self->vault_api('/v1/sys/leases/revoke', method => 'post', data => {lease_id => $self->vault_lease_id});
    $self->vault_lease_id(undef);
}


=head2 cleanup

This method is called called after each test on failure or success.

=cut
sub cleanup {
    my ($self) = @_;
    $self->terraform_destroy();
    $self->vault_revoke();
    assert_script_run "cd";
}

=head2 stop_instance

This function implements a provider specifc stop call for a given instance.

=cut
sub stop_instance
{
    die('stop_instance() isn\'t implemented');
}

=head2 start_instance

This function implements a provider specifc start call for a given instance.

=cut
sub start_instance
{
    die('start_instance() isn\'t implemented');
}

=head2 get_state_from_instance

This function implements a provider specifc get_state call for a given instance.

=cut
sub get_state_from_instance
{
    die('get_state_from_instance() isn\'t implemented');
}

1;
