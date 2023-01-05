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
use publiccloud::instances;
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::utils qw(is_azure is_ec2);
use Carp;
use List::Util qw(max);
use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use utils qw(file_content_replace script_retry);
use mmapi;

use constant TERRAFORM_DIR => get_var('PUBLIC_CLOUD_TERRAFORM_DIR', '/root/terraform');
use constant TERRAFORM_TIMEOUT => 30 * 60;

has prefix => 'openqa';
has terraform_env_prepared => 0;
has terraform_applied => 0;
has resource_name => sub { get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm') };
has provider_client => undef;

=head1 METHODS

=cut

sub init {
    my ($self) = @_;
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
        assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -C "" -m pem -f ' . $args{ssh_private_key_file});
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

    my $exclude = $args{exclude} // '';
    my $beta = $args{beta} // 0;

    my $version = script_output('img-proof --version', 300);
    record_info("img-proof version", $version);

    my $cmd = 'img-proof --no-color test ' . $args{provider};
    $cmd .= ' --debug ';
    $cmd .= "--distro " . $args{distro} . " ";
    $cmd .= '--region "' . $self->provider_client->region . '" ';
    $cmd .= '--results-dir "' . $args{results_dir} . '" ';
    $cmd .= '--no-cleanup ';
    $cmd .= '--collect-vm-info ';
    $cmd .= '--service-account-file "' . $args{credentials_file} . '" ' if ($args{credentials_file});
    #TODO: this if is just dirty hack which needs to be replaced with something more sane ASAP.
    $cmd .= '--access-key-id $AWS_ACCESS_KEY_ID --secret-access-key $AWS_SECRET_ACCESS_KEY ' if (is_ec2());
    $cmd .= "--ssh-key-name '" . $args{key_name} . "' " if ($args{key_name});
    $cmd .= '-u ' . $args{user} . ' ' if ($args{user});
    $cmd .= '--ssh-private-key-file "' . $args{instance}->ssh_key . '" ';
    $cmd .= '--running-instance-id "' . ($args{running_instance_id} // $args{instance}->instance_id) . '" ';
    $cmd .= "--beta $beta " if ($beta);
    if ($exclude) {
        # Split exclusion tests by command and add them individually
        for my $excl (split ',', $exclude) {
            $excl =~ s/^\s+|\s+$//g;    # trim spaces
            $cmd .= "--exclude $excl ";
        }
    }

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
    # If a URI is given, then no image ID should be determined
    return '' if (get_var('PUBLIC_CLOUD_IMAGE_URI'));
    # Determine image ID from image filename
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
        record_info("INSTANCE", $instance->{instance_id});
        if ($args{check_connectivity}) {
            $instance->wait_for_ssh();
            # Install server's ssh publicckeys to prevent authenticity interactions
            assert_script_run(sprintf('ssh-keyscan %s >> ~/.ssh/known_hosts', $instance->public_ip));
        }
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

=head2 terraform_prepare_env

This method is used to initialize the terraform environment.
it is executed only once, guareded by `terraform_env_prepared` member.
=cut

sub terraform_prepare_env {
    my ($self) = @_;
    return if $self->terraform_env_prepared;

    my $file = lc get_var('PUBLIC_CLOUD_PROVIDER');
    assert_script_run('mkdir -p ' . TERRAFORM_DIR);
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        my $cloud_name = $self->conv_openqa_tf_name;
        # Disable SSL verification only if explicitly asked!
        assert_script_run('git config --global http.sslVerify false') if get_var('HA_SAP_GIT_NO_VERIFY');
        assert_script_run('cd ' . TERRAFORM_DIR);
        assert_script_run('git clone --depth 1 --branch ' . get_var('HA_SAP_GIT_TAG', 'master') . ' ' . get_required_var('HA_SAP_GIT_REPO') . ' .');
        # Workaround for https://github.com/SUSE/ha-sap-terraform-deployments/issues/810
        assert_script_run('sed -i "/key_name/s/terraform/&$RANDOM/" aws/infrastructure.tf');
        # By default use the default provided Salt formula packages
        assert_script_run('rm -f requirements.yml') unless get_var('HA_SAP_USE_REQUIREMENTS');
        assert_script_run('cd');    # We need to ensure to be in the home directory
        assert_script_run('curl ' . data_url("publiccloud/terraform/sap/$file.tfvars") . ' -o ' . TERRAFORM_DIR . "/$cloud_name/terraform.tfvars");
    }
    else {
        $file = get_var('PUBLIC_CLOUD_TERRAFORM_FILE', "publiccloud/terraform/$file.tf");
        assert_script_run('curl ' . data_url("$file") . ' -o ' . TERRAFORM_DIR . '/plan.tf');
    }
    $self->terraform_env_prepared(1);
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
    my $image_uri = get_var("PUBLIC_CLOUD_IMAGE_URI");
    my $ssh_private_key_file = '/root/.ssh/id_rsa';
    my $cloud_name = $self->conv_openqa_tf_name;

    record_info('WARNING', 'Terraform apply has been run previously.') if ($self->terraform_applied);

    $self->terraform_prepare_env();

    record_info('INFO', "Creating instance $instance_type from $image ...");
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        assert_script_run('cd ' . TERRAFORM_DIR . "/$cloud_name");
        my $sap_media = get_required_var('HANA');
        my $sap_regcode = get_required_var('SCC_REGCODE_SLES4SAP');
        my $storage_account_name = get_var('STORAGE_ACCOUNT_NAME');
        my $storage_account_key = get_var('STORAGE_ACCOUNT_KEY');
        # Enable specifying resource group name to allow running multiple tests simultaneously
        my $resource_group = get_var('PUBLIC_CLOUD_RESOURCE_GROUP', 'qashapopenqa');
        my $sle_version = get_var('FORCED_DEPLOY_REPO_VERSION') ? get_var('FORCED_DEPLOY_REPO_VERSION') : get_var('VERSION');
        $sle_version =~ s/-/_/g;
        my $ha_sap_repo = get_var('HA_SAP_REPO') ? get_var('HA_SAP_REPO') . '/SLE_' . $sle_version : '';
        my $suffix = sprintf("%04x", rand(0xffff));
        my $fencing_mechanism = get_var('FENCING_MECHANISM', 'sbd');
        file_content_replace('terraform.tfvars',
            q(%MACHINE_TYPE%) => $instance_type,
            q(%REGION%) => $self->provider_client->region,
            q(%HANA_BUCKET%) => $sap_media,
            q(%SLE_IMAGE%) => $image,
            q(%SCC_REGCODE_SLES4SAP%) => $sap_regcode,
            q(%STORAGE_ACCOUNT_NAME%) => $storage_account_name,
            q(%STORAGE_ACCOUNT_KEY%) => $storage_account_key,
            q(%HA_SAP_REPO%) => $ha_sap_repo,
            q(%SLE_VERSION%) => $sle_version,
            q(%FENCING_MECHANISM%) => $fencing_mechanism
        );
        upload_logs(TERRAFORM_DIR . "/$cloud_name/terraform.tfvars", failok => 1);
        script_retry('terraform init -no-color', timeout => $terraform_timeout, delay => 3, retry => 6);
        assert_script_run("terraform workspace new ${resource_group}${suffix} -no-color", $terraform_timeout);
    }
    else {
        assert_script_run('cd ' . TERRAFORM_DIR);
        script_retry('terraform init -no-color', timeout => $terraform_timeout, delay => 3, retry => 6);
    }

    my $cmd = 'terraform plan -no-color ';
    if (!get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # Some auxiliary variables, requires for fine control and public cloud provider specifics
        for my $key (keys %{$args{vars}}) {
            my $value = $args{vars}->{$key};
            $cmd .= sprintf(q(-var '%s=%s' ), $key, escape_single_quote($value));
        }
        # image_uri and image_id are mutally exclusive
        if ($image_uri && $image) {
            die "PUBLIC_CLOUD_IMAGE_URI and PUBLIC_CLOUD_IMAGE_ID are mutually exclusive";
        } elsif ($image_uri) {
            $cmd .= "-var 'image_uri=" . $image_uri . "' ";
        } elsif ($image) {
            $cmd .= "-var 'image_id=" . $image . "' ";
        }
        if (is_azure) {
            # Note: Only the default Azure terraform profiles contains the 'storage-account' variable
            my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT');
            $cmd .= "-var 'storage-account=$storage_account' " if ($storage_account);
        }
        $cmd .= "-var 'instance_count=" . $args{count} . "' ";
        $cmd .= "-var 'type=" . $instance_type . "' ";
        $cmd .= "-var 'region=" . $self->provider_client->region . "' ";
        $cmd .= "-var 'name=" . $self->resource_name . "' ";
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
    if (get_var('PUBLIC_CLOUD_NVIDIA')) {
        $cmd .= "-var gpu=true ";
    }
    $cmd .= "-out myplan";
    record_info('TFM cmd', $cmd);

    script_retry($cmd, timeout => $terraform_timeout, delay => 3, retry => 6);
    my $ret = script_run('terraform apply -no-color -input=false myplan', $terraform_timeout);
    $self->terraform_applied(1);    # Must happen here to prevent resource leakage
    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');    # Send QUIT signal
        }
        assert_script_run('true');    # make sure we have a prompt
        record_info('ERROR', 'Terraform apply failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_apply_timeout();
        die('Terraform apply failed with timeout');
    }
    die('Terraform exit with ' . $ret) if ($ret != 0);

    my $output = decode_json(script_output("terraform output -json"));
    my $vms;
    my $ips;
    my $resource_id;
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        foreach my $vm_type ('hana', 'drbd', 'netweaver') {
            push @{$vms}, @{$output->{$vm_type . '_name'}->{value}};
            push @{$ips}, @{$output->{$vm_type . '_public_ip'}->{value}};
        }
    } else {
        $vms = $output->{vm_name}->{value};
        $ips = $output->{public_ip}->{value};
        # ResourceID is only provided in the PUBLIC_CLOUD_AZURE_NFS_TEST
        $resource_id = $output->{resource_id}->{value} if (get_var('PUBLIC_CLOUD_AZURE_NFS_TEST'));
    }

    foreach my $i (0 .. $#{$vms}) {
        my $instance = publiccloud::instance->new(
            public_ip => @{$ips}[$i],
            resource_id => $resource_id,
            instance_id => @{$vms}[$i],
            username => $self->provider_client->username,
            ssh_key => $ssh_private_key_file,
            image_id => $image,
            region => $self->provider_client->region,
            type => $instance_type,
            provider => $self
        );
        push @instances, $instance;
    }

    publiccloud::instances::set_instances(@instances);
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

    select_host_console(force => 1);

    my $cmd;
    record_info('INFO', 'Removing terraform plan...');
    if (get_var('PUBLIC_CLOUD_SLES4SAP')) {
        assert_script_run('cd ' . TERRAFORM_DIR . '/' . $self->conv_openqa_tf_name);
        $cmd = 'terraform destroy -no-color -auto-approve';
    }
    else {
        assert_script_run('cd ' . TERRAFORM_DIR);
        # Add region variable also to `terraform destroy` (poo#63604) -- needed by AWS.
        $cmd = sprintf(q(terraform destroy -no-color -auto-approve -var 'region=%s'), $self->provider_client->region);
        # Add image_id, offer and sku on Azure runs, if defined.
        if (is_azure) {
            my $image = $self->get_image_id();
            my $image_uri = get_var('PUBLIC_CLOUD_IMAGE_URI');
            my $offer = get_var('PUBLIC_CLOUD_AZURE_OFFER');
            my $sku = get_var('PUBLIC_CLOUD_AZURE_SKU');
            my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT');
            $cmd .= " -var 'image_id=$image'" if ($image);
            $cmd .= " -var 'image_uri=$image'" if ($image_uri);
            $cmd .= " -var 'offer=$offer'" if ($offer);
            $cmd .= " -var 'sku=$sku'" if ($sku);
            $cmd .= " -var 'storage-account=$storage_account'" if ($storage_account);
        }
    }
    # Retry 3 times with considerable delay. This has been introduced due to poo#95932 (RetryableError)
    # terraform keeps track of the allocated and destroyed resources, so its safe to run this multiple times.
    my $ret = script_retry($cmd, retry => 3, delay => 60, timeout => get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT), die => 0);
    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');    # Send QUIT signal
        }
        assert_script_run('true');    # make sure we have a prompt
        record_info('ERROR', 'Terraform destroy failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_destroy_timeout();
    }

    if ($ret != 0) {
        record_info('ERROR', 'Terraform exited with ' . $ret, result => 'fail');
        die('Terraform destroy failed');
    }
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

=head2 cleanup

This method is called called after each test on failure or success.

=cut

sub cleanup {
    my ($self) = @_;
    $self->terraform_destroy();
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
