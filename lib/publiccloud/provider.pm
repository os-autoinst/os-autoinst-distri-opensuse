# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base helper class for public cloud
#
# Maintainer: QE-C team <qa-c@suse.de>

package publiccloud::provider;
use testapi qw(is_serial_terminal :DEFAULT);
use Mojo::Base -base;
use publiccloud::instance;
use publiccloud::instances;
use publiccloud::ssh_interactive 'select_host_console';
use publiccloud::utils qw(is_azure is_gce is_ec2 is_hardened get_ssh_private_key_path calculate_custodian_ttl);
use Carp;
use List::Util qw(max);
use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use utils qw(file_content_replace script_retry);
use mmapi;
use db_utils qw(is_ok_url);
use version_utils qw(is_sle_micro);

use constant TERRAFORM_DIR => get_var('PUBLIC_CLOUD_TERRAFORM_DIR', '/root/terraform');
use constant TERRAFORM_TIMEOUT => 30 * 60;
use constant TERRAFORM_INIT_TIMEOUT => 3 * 60;
use constant TERRAFORM_PLAN_TIMEOUT => 5 * 60;
# Valid values according to documentation: TRACE, DEBUG, INFO, WARN, ERROR & OFF
# https://developer.hashicorp.com/terraform/internals/debugging
use constant TERRAFORM_LOG => get_var('TERRAFORM_LOG', '');

our $instance_counter;    # Package variable tracking create_instance calls

has prefix => 'openqa';
has terraform_env_prepared => 0;
has terraform_applied => 0;
has resource_name => sub { get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm') };
has provider_client => undef;

has ssh_key => get_ssh_private_key_path();

my $runner = get_var('PUBLIC_CLOUD_TERRAFORM_RUNNER', 'tofu');
unless ($runner eq 'terraform' || $runner eq 'tofu') {
    die "Unsupported PUBLIC_CLOUD_TERRAFORM_RUNNER: '$runner'. Must be 'terraform' or 'tofu'";
}

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
        assert_script_run('ssh-keygen -t ' . $alg . ' -q -N "" -C ""' . ($alg eq 'rsa' ? ' -m pem' : '') . ' -f ' . $self->ssh_key);
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
    if (is_gce()) {
        $cmd .= '--region "' . $self->provider_client->region . '-' . $self->provider_client->availability_zone . '" ';
    }
    else {
        $cmd .= '--region "' . $self->provider_client->region . '" ';
    }
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
    my @vms = $self->terraform_apply(%args);

    foreach my $instance (@vms) {
        record_info("INSTANCE", $instance->{instance_id});
        $self->show_instance_details();
        if ($args{check_connectivity}) {
            # An error in VM-up causes test to stop
            $instance->wait_for_ssh(timeout => $args{timeout},
                proceed_on_failure => $args{proceed_on_failure}, scan_ssh_host_key => 1);
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

=head2 on_terraform_destroy_failure

This method can be overwritten by child classes to do some special
cleanup task if 'destroy' fails (including timeout).
The working directory is always the terraform directory, where the statefile
and the *.tf is placed.
Returns 1 if the fallback cleanup succeeded (caller should not die),
or a false value if it did not (caller should die).

=cut

sub on_terraform_destroy_failure {
}

=head2 terraform_prepare_env

This method is used to initialize the terraform environment.
it is executed only once, guareded by `terraform_env_prepared` member.
=cut

sub terraform_prepare_env {
    my ($self) = @_;
    return if $self->terraform_env_prepared;

    my $file = lc get_required_var('PUBLIC_CLOUD_PROVIDER');
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

=head2 _tofu_run_step

    my ($ret, $output) = $self->_tofu_run_step(
        step    => 'init',            # short label, also used to name the output file (tf_<step>_output)
        cmd     => 'tofu init -no-color',
        timeout => 180,               # overall script_retry() timeout, in seconds
        delay   => 10,                # seconds to wait between retries
        retry   => 6,                 # number of script_retry() attempts
    );

Run a single tofu/terraform step (C<init>, C<plan> or C<apply>) via
C<script_retry()>, capturing its combined stdout/stderr to C<tf_<step>_output>
so the output survives even on a timeout (unlike letting C<script_retry> die
internally with no diagnostics). Always returns the exit code and the
captured output rather than dying itself, so the caller decides how to react
to a failure.

=cut

sub _tofu_run_step {
    my ($self, %args) = @_;
    my $output_file = "tf_$args{step}_output";
    my $cmd = "set -o pipefail; TF_LOG=" . TERRAFORM_LOG . " $args{cmd} 2>&1 | tee $output_file";
    my $ret = script_retry($cmd, timeout => $args{timeout}, delay => $args{delay}, retry => $args{retry}, die => 0);
    my $output = script_output("cat $output_file", proceed_on_failure => 1);
    record_info("TFM $args{step} output", "exit code: $ret", result => ($ret) ? 'fail' : 'ok');
    return ($ret, $output);
}

=head2 region_out_of_resources

    my $bool = $self->region_out_of_resources($terraform_output);

Return true if the given terraform C<apply> output indicates that the current
region has no resources available to fulfil the request for the selected
instance type (e.g. STOCKOUT on GCE, C<InsufficientInstanceCapacity> on EC2 or
C<SkuNotAvailable>/C<AllocationFailed> on Azure).

It is used by L</terraform_apply> to decide whether it is worth retrying the
deployment in one of the C<PUBLIC_CLOUD_ALTERNATE_REGIONS> (poo#202446, AC2).
Any other kind of error must fail immediately, so it returns false for them.

=cut

sub region_out_of_resources {
    my ($self, $output) = @_;
    return 0 unless defined($output);
    # Provider-specific messages emitted by terraform when a region cannot
    # fulfil the request for the requested instance type.
    return ($output =~ /does not have enough resources available to fulfill the request/i    # GCE
          || $output =~ /is currently unavailable in the .* zone/i    # GCE (e.g. nvidia accelerators)
          || $output =~ /STOCKOUT|ZONE_RESOURCE_POOL_EXHAUSTED/i    # GCE
          || $output =~ /InsufficientInstanceCapacity|Insufficient capacity/i    # EC2
          || $output =~ /SkuNotAvailable|AllocationFailed|OverconstrainedAllocationRequest/i    # Azure
    ) ? 1 : 0;
}

=head2 terraform_apply

Calls terraform tool and applies the corresponding configuration .tf file

=cut

sub terraform_apply {
    my ($self, %args) = @_;
    my $terraform_timeout = get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT);
    die('TERRAFORM_TIMEOUT must be greater than 60') if ($terraform_timeout <= 60);
    my $terraform_vm_create_timeout = ($terraform_timeout - 60) . 's';

    my $image_uri = $self->get_image_uri();
    my $image_id = $self->get_image_id();

    $args{count} //= '1';
    my $instance_type = get_var('PUBLIC_CLOUD_INSTANCE_TYPE');

    record_info('WARNING', 'Terraform apply has been run previously.') if ($self->terraform_applied);

    $self->terraform_prepare_env();

    # 1) Terraform init
    assert_script_run('cd ' . TERRAFORM_DIR);
    my ($init_ret) = $self->_tofu_run_step(step => 'init', cmd => $runner . ' init -no-color', timeout => TERRAFORM_INIT_TIMEOUT, delay => 10, retry => 6);
    die("Terraform init failed with exit code $init_ret") if $init_ret;

    # 2) Terraform plan & apply
    #
    # Attempt the deployment in the primary region (PUBLIC_CLOUD_REGION) first.
    # Only it has no resources available for the requested instance type,
    # retry in each region listed in PUBLIC_CLOUD_ALTERNATE_REGIONS.
    # Any other kind of failure fails immediately.
    my @regions = ($self->provider_client->region);
    push @regions, split(/\s*,\s*/, get_var('PUBLIC_CLOUD_ALTERNATE_REGIONS', ''));

    my %vars = ();
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
    $vars{instance_count} = $args{count};
    $vars{type} = $instance_type;
    $vars{name} = $self->resource_name;
    $vars{project} = $args{project} if ($args{project});
    $vars{cloud_init} = TERRAFORM_DIR . "/cloud-init.yaml" if (get_var('PUBLIC_CLOUD_CLOUD_INIT'));
    $vars{vm_create_timeout} = $terraform_vm_create_timeout;
    my $root_size = get_var('PUBLIC_CLOUD_ROOT_DISK_SIZE');
    $vars{'root-disk-size'} = $root_size if ($root_size);
    $vars{tags} = escape_single_quote($self->terraform_param_tags);
    if ($args{use_extra_disk}) {
        $vars{'create-extra-disk'} = 'true';
        $vars{'extra-disk-size'} = $args{use_extra_disk}->{size} if $args{use_extra_disk}->{size};
        $vars{'extra-disk-type'} = $args{use_extra_disk}->{type} if $args{use_extra_disk}->{type};
    }
    $vars{uefi} = 'true' if (get_var('FLAVOR') =~ 'UEFI');
    $vars{gpu} = 'true' if (get_var('PUBLIC_CLOUD_NVIDIA'));
    $vars{ssh_public_key} = $self->ssh_key . '.pub';

    my @alternative_zones;
    my ($ret, $tf_apply_output);
    for my $region (@regions) {
        # Swap the active region inline so all the region-dependent variables
        # and any test relying on provider_client->region are aware.
        $self->provider_client->region($region);
        record_info('REGION', "Attempting the deployment in region '$region'");

        if (is_ec2) {
            $vars{availability_zone} = script_output("aws ec2 describe-instance-type-offerings --location-type availability-zone --filters Name=instance-type,Values=" . $instance_type . " --region '" . $region . "' --query 'InstanceTypeOfferings[0].Location' --output 'text'");
            die('Instance type not supported by the selected Availability Zone') if ($vars{availability_zone} =~ /None/);
            $vars{vpc_security_group_ids} = script_output("aws ec2 describe-security-groups --region '" . $region . "' --filters 'Name=group-name,Values=tf-sg' --query 'SecurityGroups[0].GroupId' --output text");
            $vars{subnet_id} = script_output("aws ec2 describe-subnets --region '" . $region . "' --filters 'Name=tag:Name,Values=tf-subnet' 'Name=availabilityZone,Values=" . $vars{availability_zone} . "' --query 'Subnets[0].SubnetId' --output text");
        } elsif (is_azure) {
            my $subnet_id = script_output("az network vnet subnet list -g 'tf-" . $region . "-rg' --vnet-name 'tf-network' --query '[0].id' --output 'tsv'");
            $vars{subnet_id} = $subnet_id if ($subnet_id);
        } elsif (is_gce) {
            @alternative_zones = split /\s*,\s*/,
              script_output("gcloud compute zones list --filter='region=" . $region . "' --format=\"value(name.split('-').slice(-1))\" | tr '\n' ','");
            $vars{availability_zone} = $alternative_zones[0];
        }
        $vars{region} = $self->provider_client->region;

        my $cmd = terraform_cmd($runner . ' plan -no-color -out myplan', %vars);
        my ($plan_ret) = $self->_tofu_run_step(step => 'plan', cmd => $cmd, timeout => TERRAFORM_PLAN_TIMEOUT, delay => 10, retry => 6);
        die("Terraform plan failed with exit code $plan_ret") if $plan_ret;

        ($ret, $tf_apply_output) = $self->_tofu_run_step(step => 'apply', cmd => "$runner apply -no-color -input=false myplan", timeout => $terraform_timeout, delay => 0, retry => 1);
        $self->terraform_applied(1);    # Must happen here to prevent resource leakage

        # when all instances of certain type are booked in one AZ there is a chance that other AZ in same region still have them
        # to improve test stability let's loop over all available AZ in case initial one throwing error that all instances are booked
        if ($ret != 0 && is_gce() && ($tf_apply_output =~ /A .* VM instance with 1 .* accelerator\(s\) is currently unavailable in the .* zone|Machine type with name .* does not exist in zone .*|The zone 'projects.*' does not have enough resources available to fulfill the request/)) {
            @alternative_zones = grep { $_ ne $vars{availability_zone} } @alternative_zones;
            record_info('ZONE UNAVAILABLE', "Alternative zones " . join(', ', @alternative_zones));
            for my $az (@alternative_zones) {
                # try to apply in all regions before hardfailing
                record_info('RETRYING', "Attempting with availability_zone: $az");
                $vars{availability_zone} = $az;

                $cmd = terraform_cmd($runner . ' plan -no-color -out myplan', %vars);
                ($plan_ret) = $self->_tofu_run_step(step => 'plan', cmd => $cmd, timeout => TERRAFORM_PLAN_TIMEOUT, delay => 10, retry => 6);
                die("Terraform plan failed with exit code $plan_ret") if $plan_ret;

                ($ret, $tf_apply_output) = $self->_tofu_run_step(step => 'apply', cmd => "$runner apply -no-color -input=false myplan", timeout => $terraform_timeout, delay => 0, retry => 1);
                if ($ret == 0) {
                    $self->provider_client->availability_zone($az);
                    last;
                }
            }
        }

        # Deployment succeeded: no need to try any alternate region.
        last if (defined($ret) && $ret == 0);

        # AC2: fall back to an alternate region only when the failure is caused by
        # the region running out of resources; any other error must fail immediately.
        last unless ($self->region_out_of_resources($tf_apply_output));
        record_info('REGION UNAVAILABLE', "Region '$region' has no resources available for instance type '$instance_type'");
    }

    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');    # Send QUIT signal
        }
        assert_script_run('true');    # Make sure we have a prompt
        script_run("killall -KILL $runner");    # Send SIGKILL in case SIGQUIT doesn't work
        record_info('ERROR', 'Terraform apply failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_apply_timeout();
        die('Terraform apply failed with timeout');
    }
    die('Terraform exit with ' . $ret) if ($ret != 0);

    # 3) Terraform output

    my $output = decode_json(script_output($runner . ' output -json'));
    my ($vms, $ips, $resource_id);
    $vms = $output->{vm_name}->{value};
    $ips = $output->{public_ip}->{value};
    # ResourceID is only provided in the PUBLIC_CLOUD_AZURE_NFS_TEST
    $resource_id = $output->{resource_id}->{value} if (get_var('PUBLIC_CLOUD_AZURE_NFS_TEST'));

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

    # Do not destroy if terraform has not been applied or the environment doesn't exist
    unless ($self->terraform_applied) {
        record_info('NO TFM DESTROY', 'Skipping terraform_destroy() due to missing $self->terraform_applied');
        return;
    }

    # Do not destroy if PUBLIC_CLOUD_NO_TEARDOWN=1
    if (check_var('PUBLIC_CLOUD_NO_TEARDOWN', '1')) {
        record_info('NO TFM DESTROY', 'Skipping terraform_destroy() due to PUBLIC_CLOUD_NO_TEARDOWN=1');
        return;
    }

    record_info('TFM DESTROY', 'Running terraform_destroy() now');

    select_host_console(force => 1);

    my %vars = ();

    assert_script_run('cd ' . TERRAFORM_DIR);
    $self->show_instance_details();
    record_info('INFO', 'Removing terraform plan...');
    # Add region variable also to `terraform destroy` (poo#63604) -- needed by AWS.
    $vars{region} = $self->provider_client->region;
    $vars{cloud_init} = TERRAFORM_DIR . '/cloud-init.yaml' if (get_var('PUBLIC_CLOUD_CLOUD_INIT'));
    $vars{ssh_public_key} = $self->ssh_key . '.pub';

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
    my $cmd = terraform_cmd($runner . ' destroy -no-color -auto-approve -lock=false', %vars);
    my $terraform_timeout = get_var('TERRAFORM_TIMEOUT', TERRAFORM_TIMEOUT);
    # Retry 3 times with considerable delay. This has been introduced due to poo#95932 (RetryableError)
    # terraform keeps track of the allocated and destroyed resources, so its safe to run this multiple times.
    my $ret = script_retry($cmd, retry => 9, delay => 180, timeout => $terraform_timeout, die => 0, kill_timeout => 15, retry_grace => 45);
    unless (defined $ret) {
        if (is_serial_terminal()) {
            type_string(qq(\c\\));    # Send QUIT signal
        }
        else {
            send_key('ctrl-\\');    # Send QUIT signal
        }
        assert_script_run('true');    # make sure we have a prompt
        $ret = -1;
    }

    if ($ret != 0) {
        record_info('ERROR', 'Terraform destroy failed with exit code ' . $ret, result => 'fail');
        record_info('TFM CLEANUP', 'Attempting provider-level cleanup after failed destroy...');
        assert_script_run('cd ' . TERRAFORM_DIR);
        die('Terraform destroy failed') unless $self->on_terraform_destroy_failure();
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
    my $openqa_ttl = get_var('MAX_JOB_TIME', 7200) + get_var('PUBLIC_CLOUD_TTL_OFFSET', 300);
    my $tags = {
        openqa_ttl => $openqa_ttl,
        openqa_var_job_id => get_current_job_id(),
        openqa_var_name => get_var(NAME => ''),
        openqa_var_server => $openqa_var_server,
        custodian_ttl => calculate_custodian_ttl($openqa_ttl)
    };

    # Add pcw_ignore tag if requested
    $tags->{pcw_ignore} = '1' if (check_var('PUBLIC_CLOUD_PCW_IGNORE', '1'));

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
    my $res = script_output("$runner output -no-color -json | jq -Mr '$jq_query' 2>/dev/null", proceed_on_failure => 1);
    # jq 'null' shall return empty
    script_run('cd -');
    return $res unless ($res =~ /^null$/);
    return;
}

sub escape_single_quote {
    my $s = shift;
    $s =~ s/'/'"'"'/g;
    return $s;
}

=head2 teardown

This method is calling the terraform_destroy() subroutine.

=cut

sub teardown {
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

sub initialize_logging {
    record_info("initialize_logging not implemented");
}

sub finalize_logging {
    record_info("finalize_logging not implemented");
}

1;
