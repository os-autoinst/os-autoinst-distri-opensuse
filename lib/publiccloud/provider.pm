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
use publiccloud::utils qw(is_azure is_gce is_ec2 is_hardened get_ssh_private_key_path);
use Carp;
use List::Util qw(max);
use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use utils qw(file_content_replace script_retry);
use mmapi;
use db_utils qw(is_ok_url);
use version_utils qw(is_openstack is_sle_micro);

use constant TERRAFORM_DIR => get_var('PUBLIC_CLOUD_TERRAFORM_DIR', '/root/terraform');
use constant TERRAFORM_TIMEOUT => 30 * 60;

our $instance_counter;    # Package variable tracking create_instance calls

has prefix => 'openqa';
has terraform_env_prepared => 0;
has terraform_applied => 0;
has resource_name => sub { get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm') };
has provider_client => undef;

has ssh_key => get_ssh_private_key_path();

=head1 METHODS

=cut

sub init {
    my ($self) = @_;
    $self->create_ssh_key();
    $self->place_ssh_config();
}

=head2 generate_basename

    Call: $self->generate_basename();

    openqa test product name composition, based on basic product parameters values and eventual modifiers.

    Returns a string-name containing distri, version, flavor, arch.

=cut

sub generate_basename {
    my ($self, %args) = @_;

    my $distri = (is_sle_micro('>=6.0')) ? 'sl-micro' : get_required_var('DISTRI');
    my $version = get_required_var('VERSION');
    my $flavor = get_required_var('FLAVOR');
    my $arch = (is_azure) ? $self->az_arch() : get_required_var('ARCH');

    return "$distri-$version-$flavor-$arch";
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

=head2 upload_img

Upload a image to the CSP. Required parameter is the
location of the C<image> file.
UEFI images are supported by giving the optional
parameter C<type> = 'uefi'. This is only supported
on GCE at the momment.

Retrieves the image-id after upload or die.

=cut

sub upload_img {
    die('upload_img() isn\'t implemented');
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
        $ret->{output} .= $line . "\n";
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
    my ($self) = @_;
    my $alg = $self->ssh_key;
    $alg =~ s@[a-z0-9/-_~.]*id_@@;
    record_info($alg, "The $alg key will be generated.");
    if (script_run('test -f ' . $self->ssh_key) != 0) {
        assert_script_run('SSH_DIR=`dirname ' . $self->ssh_key . '`; mkdir -p $SSH_DIR');
        assert_script_run('ssh-keygen -t ' . $alg . ' -q -N "" -C "" -m pem -f ' . $self->ssh_key);
    }
}

=head2 place_ssh_config

Creates ~/.ssh/config file with all the common ssh client settings

=cut

sub place_ssh_config {
    # configure ssh client
    # ssh will be configured by a ~/.ssh/config file, the config file come from a template.
    # By default the template is in publiccloud/ssh_config data directory.
    # The user can overwrite the template with PUBLIC_CLOUD_SSH_CONFIG variable.
    # From now on all ssh calls will use this configuration file.
    my $ssh_config_url = data_url(get_var('PUBLIC_CLOUD_SSH_CONFIG', 'publiccloud/ssh_config'));
    assert_script_run("curl $ssh_config_url -o ~/.ssh/config");
    file_content_replace("~/.ssh/config", "%SSH_KEY%" => get_ssh_private_key_path());
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
    $cmd .= '--ssh-key-name $(realpath ' . $args{key_name} . ') ' if ($args{key_name});
    $cmd .= '-u ' . $args{user} . ' ' if ($args{user});
    $cmd .= '--ssh-private-key-file $(realpath ' . $self->ssh_key . ') ';
    $cmd .= '--running-instance-id "' . ($args{running_instance_id} // $args{instance}->instance_id) . '" ';
    $cmd .= "--beta " if ($beta);
    if ($exclude) {
        # Split exclusion tests by command and add them individually
        for my $excl (split ',', $exclude) {
            $excl =~ s/^\s+|\s+$//g;    # trim spaces
            $cmd .= "--exclude $excl ";
        }
    }

    # Tell img-proof to generate SCAP report on hardened images
    if (is_hardened) {
        my $scap_report = get_var("SCAP_REPORT", "skip");
        $cmd = "SCAP_REPORT=$scap_report " . $cmd;
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

=head2 get_image_uri

Retrieves the CSP image uri if exists, otherwise exception is thrown.
This is currently used specifically in Azure so the subroutine will die afterwards.
=cut

sub get_image_uri {
    my ($self) = @_;
    my $image_uri = get_var("PUBLIC_CLOUD_IMAGE_URI");
    die 'The PUBLIC_CLOUD_IMAGE_URI variable makes sense only for Azure' if ($image_uri && !is_azure);
    if (!!$image_uri && $image_uri =~ /^auto$/mi) {
        my $definition = $self->generate_azure_image_definition();
        my $version = $self->generate_img_version();    # PUBLIC_CLOUD_BUILD PUBLIC_CLOUD_BUILD_KIWI
        my $subscriptions = $self->provider_client->subscription;
        my $resource_group = $self->resource_group;
        my $image_gallery = $self->image_gallery;
        $image_uri = "/subscriptions/$subscriptions/resourceGroups/$resource_group/providers/";
        $image_uri .= "Microsoft.Compute/galleries/$image_gallery/images/$definition/versions/$version";
        record_info 'IMAGE_URI', "Calculated IMAGE_URI=$image_uri";
    } elsif (!!$image_uri) {
        record_info 'IMAGE_URI', "Provided IMAGE_URI=$image_uri";
    } else {
        record_info 'IMAGE_URI', 'IMAGE_URI not found!';
    }
    return $image_uri;
}

=head2 create_instance

Creates an instance on the public cloud provider. Retrieves a publiccloud::instance
object.

C<image>         defines the image_id to create the instance.
C<instance_type> defines the flavor of the instance. If not specified, it will load it
                     from PUBLIC_CLOUD_INSTANCE_TYPE.

=cut

sub create_instance {
    my $max = get_var('PUBLIC_CLOUD_MAX_INSTANCES', 1);
    if ($max > 0 && ++$instance_counter > $max) {
        die "Maximum number of instances reached ($instance_counter)";
    }
    return (shift->create_instances(@_))[0];
}

=head2 create_instances

Creates multiple instances on the public cloud provider. Retrieves an array of
publiccloud::instance objects.

C<image>         defines the image_id to create the instance.
C<instance_type> defines the flavor of the instance. If not specified, it will load it
                     from PUBLIC_CLOUD_INSTANCE_TYPE.
C<timeout>             Parameter to pass to instance::wait_for_ssh.
C<proceed_on_failure>  Same as timeout.

=cut

sub create_instances {
    my ($self, %args) = @_;
    $args{check_connectivity} //= 1;
    $args{check_guestregister} //= 1;
    $args{upload_boot_diagnostics} //= 1;
    my @vms = $self->terraform_apply(%args);
    my $url = get_var('PUBLIC_CLOUD_PERF_DB_URI', 'http://larry.qe.suse.de:8086');

    foreach my $instance (@vms) {
        record_info("INSTANCE", $instance->{instance_id});
        if ($args{check_connectivity}) {
            $instance->wait_for_ssh(timeout => $args{timeout},
                proceed_on_failure => $args{proceed_on_failure}, scan_ssh_host_key => 1);
        }
        # check guestregister conditional, default yes:
        $instance->wait_for_guestregister() if ($args{check_guestregister});
        $self->upload_boot_diagnostics() if ($args{upload_boot_diagnostics});

        $self->show_instance_details();

        # Performance data: boottime
        next if is_openstack;

        if (is_ok_url($url)) {
            local $@;
            eval {
                my $btime = $instance->measure_boottime($instance, 'first');
                $instance->store_boottime_db($btime, $url);
            };
            record_info("WARN", "Boottime measures cannot be provided", result => 'fail') if ($@);
        } else {
            record_info("WARN", "Cannot connect url:" . $url, result => 'fail');
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
    $file = get_var('PUBLIC_CLOUD_TERRAFORM_FILE', "publiccloud/terraform/$file.tf");
    assert_script_run('curl ' . data_url("$file") . ' -o ' . TERRAFORM_DIR . '/plan.tf');
    assert_script_run('curl ' . data_url("publiccloud/cloud-init.yaml") . ' -o ' . TERRAFORM_DIR . "/cloud-init.yaml") if (get_var('PUBLIC_CLOUD_CLOUD_INIT'));
    $self->terraform_env_prepared(1);
}

sub terraform_cmd {
    my ($prefix, %vars) = @_;
    my $cmd = $prefix . ' ';
    for my $var (keys %vars) {
        $cmd .= sprintf(q(-var '%s=%s' ), $var, $vars{$var});
    }
    record_info('TFM cmd', $cmd);
    return $cmd;
}

=head2 terraform_apply

Calls terraform tool and applies the corresponding configuration .tf file

=cut

sub terraform_apply {
    my ($self, %args) = @_;
    my $terraform_timeout = get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT);
    my $terraform_vm_create_timeout = get_var('TERRAFORM_VM_CREATE_TIMEOUT');

    my $image_uri = $self->get_image_uri();
    my $image_id = $self->get_image_id();

    $args{count} //= '1';
    my $instance_type = get_var('PUBLIC_CLOUD_INSTANCE_TYPE');
    my $cloud_name = $self->conv_openqa_tf_name;

    record_info('WARNING', 'Terraform apply has been run previously.') if ($self->terraform_applied);

    $self->terraform_prepare_env();

    # 1) Terraform init

    assert_script_run('cd ' . TERRAFORM_DIR);
    script_retry('terraform init -no-color', timeout => $terraform_timeout, delay => 3, retry => 6);

    # 2) Terraform plan

    my %vars = ();
    if (!get_var('PUBLIC_CLOUD_SLES4SAP')) {
        # Some auxiliary variables, requires for fine control and public cloud provider specifics
        for my $key (keys %{$args{vars}}) {
            $vars{$key} = escape_single_quote($args{vars}->{$key});
        }

        # image_uri and image_id are mutually exclusive
        if ($image_uri && $image_id) {
            die "PUBLIC_CLOUD_IMAGE_URI and PUBLIC_CLOUD_IMAGE_ID are mutually exclusive";
        } elsif ($image_uri) {
            $vars{image_uri} = $image_uri;
            record_info('INFO', "Creating instance $instance_type from $image_uri ...");
        } elsif ($image_id) {
            $vars{image_id} = $image_id;
            record_info('INFO', "Creating instance $instance_type from $image_id ...");
        }
        if (is_ec2) {
            $vars{availability_zone} = script_output("aws ec2 describe-instance-type-offerings --location-type availability-zone  --filters Name=instance-type,Values=" . $instance_type . "  --region '" . $self->provider_client->region . "' --query 'InstanceTypeOfferings[0].Location' --output 'text'");
            die('Instance type not supported by the selected Availability Zone') if ($vars{availability_zone} =~ /None/);
            $vars{vpc_security_group_ids} = script_output("aws ec2 describe-security-groups --region '" . $self->provider_client->region . "' --filters 'Name=group-name,Values=tf-sg' --query 'SecurityGroups[0].GroupId' --output text");
            $vars{subnet_id} = script_output("aws ec2 describe-subnets --region '" . $self->provider_client->region . "' --filters 'Name=tag:Name,Values=tf-subnet' 'Name=availabilityZone,Values=" . $vars{availability_zone} . "' --query 'Subnets[0].SubnetId' --output text");
            $vars{ipv6_address_count} = get_var('PUBLIC_CLOUD_EC2_IPV6_ADDRESS_COUNT', 0);
        } elsif (is_azure) {
            my $subnet_id = script_output("az network vnet subnet list -g 'tf-" . $self->provider_client->region . "-rg' --vnet-name 'tf-network' --query '[0].id' --output 'tsv'");
            $vars{subnet_id} = $subnet_id if ($subnet_id);
            # Note: Only the default Azure terraform profiles contains the 'storage-account' variable
            my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT');
            $vars{'storage-account'} = $storage_account if ($storage_account);
        } elsif (is_gce) {
            my $stack_type = get_var('PUBLIC_CLOUD_GCE_STACK_TYPE', 'IPV4_ONLY');
            $vars{stack_type} = $stack_type;
        }
        $vars{instance_count} = $args{count};
        $vars{type} = $instance_type;
        $vars{region} = $self->provider_client->region;
        $vars{name} = $self->resource_name;
        $vars{project} = $args{project} if ($args{project});
        $vars{cloud_init} = TERRAFORM_DIR . "/cloud-init.yaml" if (get_var('PUBLIC_CLOUD_CLOUD_INIT'));
        $vars{vm_create_timeout} = $terraform_vm_create_timeout if $terraform_vm_create_timeout;
        $vars{enable_confidential_vm} = 'true' if ($args{confidential_compute} && is_gce());
        $vars{enable_confidential_vm} = 'enabled' if ($args{confidential_compute} && is_ec2());
        my $root_size = get_var('PUBLIC_CLOUD_ROOT_DISK_SIZE');
        $vars{'root-disk-size'} = $root_size if ($root_size);
        $vars{tags} = escape_single_quote($self->terraform_param_tags);
        if ($args{use_extra_disk}) {
            $vars{'create-extra-disk'} = 'true';
            $vars{'extra-disk-size'} = $args{use_extra_disk}->{size} if $args{use_extra_disk}->{size};
            $vars{'extra-disk-type'} = $args{use_extra_disk}->{type} if $args{use_extra_disk}->{type};
        }
    }
    if (get_var('FLAVOR') =~ 'UEFI') {
        $vars{uefi} = 'true';
    }
    if (get_var('PUBLIC_CLOUD_NVIDIA')) {
        $vars{gpu} = 'true';
    }
    unless (is_openstack) {
        $vars{ssh_public_key} = $self->ssh_key . '.pub';
    }

    my $cmd = terraform_cmd('terraform plan -no-color -out myplan', %vars);
    script_retry($cmd, timeout => $terraform_timeout, delay => 3, retry => 6);

    # 3) Terraform apply

    # Valid values according to documentation: TRACE, DEBUG, INFO, WARN, ERROR & OFF
    # https://developer.hashicorp.com/terraform/internals/debugging
    my $tf_log = get_var("TERRAFORM_LOG", "");

    # The $terraform_timeout must higher than $terraform_vm_create_timeout (See also var.vm_create_timeout in *.tf file)
    my $ret = script_run("set -o pipefail; TF_LOG=$tf_log terraform apply -no-color -input=false myplan 2>&1 | tee tf_apply_output", timeout => $terraform_timeout);
    my $tf_apply_output = script_output('cat tf_apply_output', proceed_on_failure => 1);
    $self->terraform_applied(1);    # Must happen here to prevent resource leakage

    record_info("TFM apply output", $tf_apply_output);
    record_info("TFM apply exit code", $ret);

    # when testing instances that have nvidia gpus,
    # the zone (i.e. "sub-region") might not have them available and
    # suggest other zones instead (the pattern is GCE specific)
    if ($ret != 0 && get_var('PUBLIC_CLOUD_NVIDIA') && ($tf_apply_output =~ /A .* VM instance with 1 .* accelerator\(s\) is currently unavailable in the .* zone\. Consider trying your request in the (.*) zone\(s\)/)) {
        # split captured suggestions by a ',' char, trim whitespace
        my @alternative_zones = split /\s*,\s*/, $1;
        record_info('ZONE UNAVAILABLE', "Alternative zones " . join(', ', @alternative_zones));
        for my $zone (@alternative_zones) {
            # try to apply in all regions before hardfailing
            record_info('RETRYING', "Attempting with zone $zone");
            $vars{region} = $zone;
            $cmd = terraform_cmd('terraform plan -no-color -out myplan', %vars);
            script_retry($cmd, timeout => $terraform_timeout, delay => 3, retry => 6);
            $ret = script_run("set -o pipefail; TF_LOG=$tf_log terraform apply -no-color -input=false myplan 2>&1 | tee tf_apply_output", timeout => $terraform_timeout);
            $tf_apply_output = script_output('cat tf_apply_output', proceed_on_failure => 1);
            record_info("TFM apply output", $tf_apply_output);
            record_info("TFM apply exit code", $ret);
            last if $ret == 0;
        }
    }

    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');    # Send QUIT signal
        }
        assert_script_run('true');    # Make sure we have a prompt
        script_run("killall -KILL terraform");    # Send SIGKILL in case SIGQUIT doesn't work
        record_info('ERROR', 'Terraform apply failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_apply_timeout();
        die('Terraform apply failed with timeout');
    }
    die('Terraform exit with ' . $ret) if ($ret != 0);

    # 4) Terraform output

    my $output = decode_json(script_output("terraform output -json"));
    my ($vms, $ips, $resource_id);
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

    my @instances;
    foreach my $i (0 .. $#{$vms}) {
        my $instance = publiccloud::instance->new(
            public_ip => @{$ips}[$i],
            resource_id => $resource_id,
            instance_id => @{$vms}[$i],
            username => $self->provider_client->username,
            image_id => $image_id,
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
    record_info('TFM DESTROY', 'Running terraform_destroy() now');
    # Do not destroy if terraform has not been applied or the environment doesn't exist
    return unless ($self->terraform_applied);

    select_host_console(force => 1);

    my %vars = ();

    assert_script_run('cd ' . TERRAFORM_DIR);
    $self->show_instance_details();
    record_info('INFO', 'Removing terraform plan...');
    # Add region variable also to `terraform destroy` (poo#63604) -- needed by AWS.
    $vars{region} = $self->provider_client->region;
    $vars{cloud_init} = TERRAFORM_DIR . '/cloud-init.yaml' if (get_var('PUBLIC_CLOUD_CLOUD_INIT'));
    unless (is_openstack) {
        $vars{ssh_public_key} = $self->ssh_key . '.pub';
    }
    # Add image_id, offer and sku on Azure runs, if defined.
    if (is_azure) {
        my $image = $self->get_image_id();
        my $image_uri = $self->get_image_uri();
        my $offer = get_var('PUBLIC_CLOUD_AZURE_OFFER');
        my $sku = get_var('PUBLIC_CLOUD_AZURE_SKU');
        my $storage_account = get_var('PUBLIC_CLOUD_STORAGE_ACCOUNT');
        $vars{image_id} = $image if ($image);
        $vars{image_uri} = $image_uri if ($image_uri);
        $vars{offer} = $offer if ($offer);
        $vars{sku} = $sku if ($sku);
        $vars{'storage-account'} = $storage_account if ($storage_account);
    }
    # Regarding the use of '-lock=false': Ignore lock to avoid "Error acquiring the state lock"
    my $cmd = terraform_cmd('terraform destroy -no-color -auto-approve -lock=false', %vars);
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
    my $openqa_var_server = get_var('OPENQA_URL', get_var('OPENQA_HOSTNAME'));
    # Remove the http:// https:// and/or the slash at the end
    $openqa_var_server =~ s@^https?://|/$@@gm;
    my $tags = {
        openqa_ttl => get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300),
        openqa_var_job_id => get_current_job_id(),
        openqa_var_name => get_var(NAME => ''),
        openqa_var_server => $openqa_var_server
    };

    return encode_json($tags);
}

=head2 get_terraform_output

Query the terraform data structure in json format.
Input: <jq-query-format> string; <empty> = no query then full output of data structure.
E.g: to get the VM instance name from json data structure, the call is: 
    get_terraform_output(".vm_name.value[0]");
To get the complete output structure, the call is:
    get_terraform_output();

=cut

sub get_terraform_output {
    my ($self, $jq_query) = @_;
    script_run("cd " . TERRAFORM_DIR);
    my $res = script_output("terraform output -no-color -json | jq -r '$jq_query' 2>/dev/null", proceed_on_failure => 1);
    # jq 'null' shall return empty
    script_run('cd -');
    return $res unless ($res =~ /^null$/);
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
    return 1;
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

sub query_metadata {
    die('query_metadata() isn\'t implemented');
}

sub show_instance_details {
    my ($self) = @_;
    record_info('NAME', $self->get_terraform_output(".vm_name.value[0]"));
    record_info('IP', $self->get_public_ip());
}

1;
