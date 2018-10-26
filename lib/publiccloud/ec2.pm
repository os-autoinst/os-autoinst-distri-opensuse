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

    die("Create key-pair failed") unless ($self->create_ssh_key($self->prefix . time, 'QA_SSH_KEY.pem'));

    $args{instance_type}        //= 't2.large';
    $args{user}                 //= 'ec2-user';
    $args{provider}             //= 'ec2';
    $args{ssh_private_key_file} //= $self->ssh_key_file;
    $args{key_id}               //= $self->key_id;
    $args{key_secret}           //= $self->key_secret;
    $args{key_name}             //= $self->ssh_key;

    return $self->run_ipa(%args);
}

sub cleanup {
    my ($self) = @_;
    $self->SUPER::cleanup();
    $self->delete_ssh_key;
}

1;
