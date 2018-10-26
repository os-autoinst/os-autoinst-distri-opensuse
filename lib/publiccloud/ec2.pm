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
use testapi;

has ssh_key      => undef;
has ssh_key_file => undef;

sub init {
    my ($self, %params) = @_;

    assert_script_run("export AWS_ACCESS_KEY_ID=" . $self->key_id);
    assert_script_run("export AWS_SECRET_ACCESS_KEY=" . $self->key_secret);
    assert_script_run('export AWS_DEFAULT_REGION="' . $self->region . '"');
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

sub create_ssh_key {
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

sub delete_ssh_key {
    my $self = shift;
    my $name = shift || $self->ssh_key;

    return unless $name;

    assert_script_run("aws ec2 delete-key-pair --key-name " . $name);
    $self->ssh_key(undef);
}

sub upload_img {
    my ($self, $file) = @_;

    die("Create key-pair failed") unless ($self->create_ssh_key($self->prefix . time, 'QA_SSH_KEY.pem'));

    my ($img_name) = $file =~ /([^\/]+)$/;

    assert_script_run("ec2uploadimg --access-id '"
          . $self->key_id
          . "' -s '"
          . $self->key_secret . "' "
          . "--backing-store ssd "
          . "--grub2 "
          . "--machine 'x86_64' "
          . "-n '" . $self->prefix . '-' . $img_name . "' "
          . (($img_name =~ /hvm/i) ? "--virt-type hvm --sriov-support " : "--virt-type para ")
          . "--verbose "
          . "--regions '" . $self->region . "' "
          . "--ssh-key-pair '" . $self->ssh_key . "' "
          . "--private-key-file " . $self->ssh_key_file . " "
          . "-d 'OpenQA tests' "
          . "'$file'",
        timeout => 60 * 60
    );

    my $ami = $self->find_img($img_name);
    die("Cannot find image after upload!") unless $ami;
    return $ami;
}

sub ipa {
    my ($self, %args) = @_;

    $args{instance_type} //= 't2.large';
    $args{cleanup}       //= 1;
    $args{tests}         //= '';
    $args{timeout}       //= 60 * 20;
    $args{results_dir}   //= 'ipa_results';
    $args{distro}        //= 'sles';
    my $user = 'ec2-user';

    $args{tests} =~ s/,/ /g;

    die("Create key-pair failed") unless ($self->create_ssh_key($self->prefix . time, 'QA_SSH_KEY.pem'));

    my $cmd = "ipa --no-color test ec2 ";
    $cmd .= '--debug ';
    $cmd .= "--access-key-id '" . $self->key_id . "' ";
    $cmd .= "--secret-access-key '" . $self->key_secret . "' ";
    $cmd .= "--distro " . $args{distro} . " ";
    $cmd .= '--region "' . $self->region . '" ';
    $cmd .= '--results-dir "' . $args{results_dir} . '" ';
    $cmd .= '-u ' . $user . ' ';
    $cmd .= ($args{cleanup}) ? '--cleanup ' : '--no-cleanup ';
    $cmd .= '--instance-type "' . $args{instance_type} . '" ';
    $cmd .= "--ssh-private-key-file '" . $self->ssh_key_file . "' ";
    $cmd .= "--ssh-key-name '" . $self->ssh_key . "' ";
    if (exists($args{running_instance_id})) {
        $cmd .= '--running-instance-id "' . $args{running_instance_id} . '" ';
    } else {
        $cmd .= '--image-id "' . $args{image_id} . '" ';
    }
    $cmd .= $args{tests};

    my $output = script_output($cmd . ' 2>&1', $args{timeout}, proceed_on_failure => 1);
    my $ipa = $self->parse_ipa_output($output);
    die($output) unless (defined($ipa));

    # retrieves username and password for ssh login
    $ipa->{username} = $user;
    $ipa->{ssh_key}  = $self->ssh_key_file;

    $self->{running_instances} //= {};
    if ($args{cleanup}) {
        delete($self->{running_instances}->{$ipa->{instance_id}});
    } else {
        $self->{running_instances}->{$ipa->{instance_id}} = $ipa;
    }

    return $ipa;
}

sub cleanup {
    my ($self) = @_;

    for my $i (keys(%{$self->{running_instances}})) {
        my $instance = $self->{running_instances}->{$i};
        $self->ipa(cleanup => 1, running_instance_id => $instance->{instance_id});
    }
    $self->delete_ssh_key;
}

1;
