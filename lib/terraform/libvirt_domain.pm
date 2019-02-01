# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for terraform domains (VMs)
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>

package terraform::libvirt_domain;
use Mojo::Base -base;
use testapi;
use XML::Simple;
use Data::Dumper;
use Scalar::Util qw(looks_like_number);

has domain_name   => undef;    # domain name
has domain_ip     => undef;    # private IP of the VM
has virtio_device => undef;    # host device that corresponds to virtio
has host          => undef;    # host object where the VM is running

use constant LOGIN_TIMEOUT => 30;    # (x 30)

sub init {
    my ($self) = @_;
    $self->_set_virtio_device();
    $self->_login();
}


=head2 login

    login($cmd);

Login to the VM on the console with the given user and password

=cut
sub _login {
    my ($self, %args) = @_;
    $args{user} //= 'root';
    $args{pwd}  //= 'nots3cr3t';
    my $timeout = LOGIN_TIMEOUT;
    my $pid     = $self->host->run_ssh_command('cat ' . $self->virtio_device . ' > out.log & echo $!');
    if (!looks_like_number($pid)) {
        die("Failed to get the PID '$pid'.");
    }
    record_info('login', "pid=$pid") if check_var('DEBUG', 1);
    $self->host->run_ssh_command('echo -e "\n" > ' . $self->virtio_device);    # trick for the login prompt to appear
    while ($timeout > 0) {
        my $prompt = $self->host->run_ssh_command("cat out.log");
        record_info('PROMPT', $self->domain_name . " prompt :\n" . $prompt) if check_var('DEBUG', 1);
        if ($prompt =~ /login/) {
            $self->host->run_ssh_command('echo -e "' . $args{user} . '\n" > ' . $self->virtio_device);
            sleep 10;
            $self->host->run_ssh_command('echo -e "' . $args{pwd} . '\n" > ' . $self->virtio_device);
            sleep 10;
            last;
        }
        $timeout -= 1;
        sleep 10;
    }
    $self->host->run_ssh_command('kill -9 ' . $pid);
    die('Login prompt does not appear in VM "' . $self->domain_name . '"') if ($timeout == 0);
}


=head2 run_command

    run_command($cmd, $wait_time);

Runs a command C<cmd> via virtio device in the VM. Retrieves the output.

=cut
sub run_command {
    my ($self, %args) = @_;

    die('Argument <cmd> missing') unless ($args{cmd});
    $args{wait_time} //= 1;

    record_info('run_command', 'domain_name=' . $self->domain_name . "\ncmd=" . $args{cmd} . "\nwait_time=" . $args{wait_time}) if check_var('DEBUG', 1);
    my $pid = $self->host->run_ssh_command('cat ' . $self->virtio_device . ' > out.log & echo $!');
    if (!looks_like_number($pid)) {
        die("Failed to get the PID '$pid'.");
    }
    record_info('run_command', "pid=$pid") if check_var('DEBUG', 1);
    $self->host->run_ssh_command('echo -e "' . $args{cmd} . '" > ' . $self->virtio_device);
    sleep $args{wait_time};
    $self->host->run_ssh_command('kill -9 ' . $pid);
    my $out = $self->host->run_ssh_command('cat out.log');
    $out =~ s/^(?:.*\n){1}//;    # remove first line (command)
    $out =~ s/\[1m.*//;          # remove prompt line
    record_info('cmd out', Dumper $out) if check_var('DEBUG', 1);
    $out =~ s/\e//g;
    return $out;
}


=head2 _get_domain_xml

    get_domain_xml();

    Gets the XML dump of the libvirt domain

=cut
sub _get_domain_xml {
    my ($self) = @_;
    my $xml = $self->host->run_ssh_command('virsh dumpxml ' . $self->domain_name);
    return XMLin($xml);
}


=head2 _set_virtio_device

    _set_virtio_device();

Gets the path to the virtio device in the host from the xml definition of the domain

=cut
sub _set_virtio_device {
    my ($self) = @_;
    my $device;
    my $xml      = $self->_get_domain_xml();
    my $consoles = $xml->{devices}->{console};
    foreach my $console (@{$consoles}) {
        if ($console->{target}->{type} eq 'virtio') {
            $device = $console->{source}->{path};
            last;
        }
    }
    die('Failed to get virtio device of domain ' . $self->domain_name) if (!$device);
    record_info('DEVICE', 'Domain ' . $self->domain_name . " uses virtio device mapped to : $device") if check_var('DEBUG', 1);
    $self->virtio_device($device);
}

1;
