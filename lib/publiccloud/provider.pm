# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base helper class for public cloud
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::provider;
use testapi;
use Mojo::Base -base;
use publiccloud::instance;
use Data::Dumper;
use Mojo::JSON 'decode_json';

use constant TERRAFORM_DIR     => '/root/terraform';
use constant TERRAFORM_TIMEOUT => 17 * 60;

has key_id            => undef;
has key_secret        => undef;
has region            => undef;
has username          => undef;
has prefix            => 'openqa';
has terraform_applied => 0;
has vault_token       => undef;
has vault_lease_id    => undef;

=head1 METHODS

=head2 init

Needs provider specific credentials, e.g. key_id, key_secret, region.

=cut
sub init {
    my ($self) = @_;
    my $file = lc get_var('PUBLIC_CLOUD_PROVIDER');
    assert_script_run('mkdir -p ' . TERRAFORM_DIR);
    assert_script_run('curl ' . data_url('publiccloud/terraform/' . $file . '.tf') . ' -o ' . TERRAFORM_DIR . '/plan.tf');
    $self->create_ssh_key();
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
            $ret->{pass}  = $2;
            $ret->{skip}  = $3;
            $ret->{fail}  = $4;
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
        assert_script_run('ssh-keygen -b 2048 -t rsa -q -N "" -f ' . $args{ssh_private_key_file});
    }
}

=head2 run_img_proof

called by childs within img-proof function

=cut
sub run_img_proof {
    my ($self, %args) = @_;
    die('Must provide an instance object') if (!$args{instance});

    $args{tests}       //= '';
    $args{timeout}     //= 60 * 30;
    $args{results_dir} //= 'img_proof_results';
    $args{distro}      //= 'sles';
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
    $cmd .= '--running-instance-id "' . $args{instance}->instance_id . '" ';

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
=cut
sub get_image_id {
    my ($self, $img_url) = @_;
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
    my ($self, %args) = @_;
    $args{check_connectivity} //= 1;

    my @vms      = $self->terraform_apply(%args);
    my $instance = $vms[0];
    record_info('INSTANCE', Dumper($instance));

    if ($args{check_connectivity}) {
        $instance->check_ssh_port();
    }
    return $instance;
}

=head2 on_terraform_timeout

This method can be overwritten but child classes to do some special
cleanup task.
Terraform was already terminated using the QUIT signal and openqa has a
valid shell.
The working directory is always the terraform directory, where the statefile
and the *.tf is placed.

=cut
sub on_terraform_timeout {
}

=head2 terraform_apply

Calls terraform tool and applies the corresponding configuration .tf file

=cut
sub terraform_apply {
    my ($self, %args) = @_;
    my @instances;
    my $create_extra_disk = 'false';
    my $extra_disk_size   = 0;

    $args{count} //= '1';
    my $instance_type        = get_var('PUBLIC_CLOUD_INSTANCE_TYPE');
    my $image                = $self->get_image_id();
    my $ssh_private_key_file = '/root/.ssh/id_rsa';
    my $name                 = get_var('PUBLIC_CLOUD_RESOURCE_NAME', 'openqa-vm');

    record_info('WARNING', 'Terraform apply has been run previously.') if ($self->terraform_applied);

    assert_script_run('cd ' . TERRAFORM_DIR);
    record_info('INFO', "Creating instance $instance_type from $image ...");
    assert_script_run('terraform init -no-color', TERRAFORM_TIMEOUT);

    my $cmd = 'terraform plan -no-color ';
    $cmd .= "-var 'image_id=" . $image . "' ";
    $cmd .= "-var 'instance_count=" . $args{count} . "' ";
    $cmd .= "-var 'type=" . $instance_type . "' ";
    $cmd .= "-var 'region=" . $self->region . "' ";
    $cmd .= "-var 'name=" . $name . "' ";
    $cmd .= "-var 'project=" . $args{project} . "' " if $args{project};
    if ($args{use_extra_disk}) {
        $cmd .= "-var 'create-extra-disk=true' ";
        $cmd .= "-var 'extra-disk-size=" . $args{use_extra_disk}->{size} . "' " if $args{use_extra_disk}->{size};
        $cmd .= "-var 'extra-disk-type=" . $args{use_extra_disk}->{type} . "' " if $args{use_extra_disk}->{type};
    }
    if (get_var('FLAVOR') =~ 'UEFI') {
        $cmd .= "-var 'uefi=true' ";
    }

    $cmd .= "-out myplan";
    record_info('TFM cmd', $cmd);

    assert_script_run($cmd);
    my $ret = script_run('terraform apply -no-color myplan', TERRAFORM_TIMEOUT);
    unless (defined $ret) {
        type_string(qq(\c\\));        # Send QUIT signal
        assert_script_run('true');    # make sure we have a prompt
        record_info('ERROR', 'Terraform apply failed with timeout', result => 'fail');
        assert_script_run('cd ' . TERRAFORM_DIR);
        $self->on_terraform_timeout();
        die('Terraform apply failed with timeout');
    }
    die('Terraform exit with ' . $ret) if ($ret != 0);

    $self->terraform_applied(1);

    my $output = decode_json(script_output("terraform output -json"));
    my $vms    = $output->{vm_name}->{value};
    my $ips    = $output->{public_ip}->{value};

    foreach my $i (0 .. $#{$vms}) {
        my $instance = publiccloud::instance->new(
            public_ip   => @{$ips}[$i],
            instance_id => @{$vms}[$i],
            username    => $self->username,
            ssh_key     => $ssh_private_key_file,
            image_id    => $image,
            region      => $self->region,
            type        => $instance_type,
            provider    => $self
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
    record_info('INFO', 'Removing terraform plan...');
    assert_script_run('cd ' . TERRAFORM_DIR);
    script_run('terraform destroy -no-color -auto-approve', TERRAFORM_TIMEOUT);
}

=head2 vault_login

Login to vault using C<_SECRET_PUBLIC_CLOUD_REST_USER> and
C<_SECRET_PUBLIC_CLOUD_REST_PW>. The retrieved VAULT_TOKEN is stored in this
instance and used for further C<publiccloud::provider::vault_api()> calls.
=cut
sub vault_login
{
    my ($self)   = @_;
    my $url      = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $user     = get_required_var('_SECRET_PUBLIC_CLOUD_REST_USER');
    my $password = get_required_var('_SECRET_PUBLIC_CLOUD_REST_PW');
    my $ua       = Mojo::UserAgent->new;

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $url = $url . '/v1/auth/userpass/login/' . $user;
    my $res = $ua->post($url => json => {password => $password})->result;
    if (!$res->is_success) {
        bmwqemu::diag('Request ' . $url . ' failed with: ' . $res->message . '(' . $res->code . ')');
        if ($res->code == 400) {
            for my $e (@{$res->json->{errors}}) {
                bmwqemu::diag($e);
            }
        }
        die("Vault login failed - $url");
    }

    return $self->vault_token($res->json('/auth/client_token'));
}

=head2 vault_api

Invoke a vault API call. It use _SECRET_PUBLIC_CLOUD_REST_URL as base
url.
Depending on the method (get|post) you can pass additional data as json.
=cut
sub vault_api {
    my ($self, $path, %args) = @_;
    my $method = $args{method} // 'get';
    my $data   = $args{data}   // {};
    my $ua     = Mojo::UserAgent->new;
    my $url    = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $res;

    $self->vault_login() unless ($self->vault_token);

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $url = $url . $path;
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
        bmwqemu::diag('Request ' . $url . ' failed with: ' . $res->message . '(' . $res->code . ')');
        if ($res->code == 400) {
            for my $e (@{$res->json->{errors}}) {
                bmwqemu::diag($e);
            }
        }
        die("Vault REST api call failed - $url");
    }

    return $res->json;
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
    $self->terraform_destroy() if ($self->terraform_applied);
    $self->vault_revoke();
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


1;
