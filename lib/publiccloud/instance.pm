# SUSE's openQA tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Base class for public cloud instances
#
# Maintainer: Clemens Famulla-Conrad <cfamullaconrad@suse.de>

package publiccloud::instance;
use testapi;
use Mojo::Base -base;
use File::Basename;

use constant SSH_TIMEOUT => 90;

has instance_id => undef;                                                                             # unique CSP instance id
has public_ip   => undef;                                                                             # public IP of instance
has username    => undef;                                                                             # username for ssh connection
has ssh_key     => undef;                                                                             # path to ssh-key for connection
has image_id    => undef;                                                                             # image from where the VM is booted
has type        => undef;
has provider    => undef, weak => 1;                                                                  # back reference to the provider
has ssh_opts    => '-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=ERROR';

=head2 run_ssh_command

    run_ssh_command(cmd => 'command', timeout => 90);

Runs a command C<cmd> via ssh in the given VM. Retrieves the output.
If the command retrieves not zero, a exception is thrown..
Timeout can be set by C<timeout> or 90 sec by default.
TODO Do not raise exception on error
TODO Be aware of special shell letters like ';'
=cut
sub run_ssh_command {
    my ($self, %args) = @_;

    die('Argument <cmd> missing') unless ($args{cmd});

    $args{timeout} //= SSH_TIMEOUT;

    my $ssh_cmd = sprintf('ssh %s -i "%s" "%s@%s" -- %s',
        $self->ssh_opts, $self->ssh_key, $self->username, $self->public_ip, $args{cmd});
    record_info('CMD', $ssh_cmd);
    return script_output($ssh_cmd, $args{timeout}, %args);
}

=head2 scp

    scp($from, $to, timeout => 90);

Use scp to copy a file from or to this instance. A url starting with
C<remote:> is replaces with the IP from this instance. E.g. a call to copy
the file I</var/log/cloudregister> to I</tmp> looks like:
C<<<$instance->scp('remote:/var/log/cloudregister', '/tmp');>>>
=cut
sub scp {
    my ($self, $from, $to, %args) = @_;

    my $url = sprintf('%s@%s:', $self->username, $self->public_ip);
    $from =~ s/^remote:/$url/;
    $to   =~ s/^remote:/$url/;

    my $ssh_cmd = sprintf('scp %s -i "%s" "%s" "%s"',
        $self->ssh_opts, $self->ssh_key, $from, $to);

    return script_run($ssh_cmd, $args{timeout});
}

=head2 upload_log

    upload_log($filename);

Upload a file from this instance to openqa using L<upload_logs()>.
If the file doesn't exists on the instance, B<no> error is thrown.
=cut
sub upload_log {
    my ($self, $remote_file) = @_;

    my $tmpdir = script_output('mktemp -d');
    my $dest   = $tmpdir . '/' . basename($remote_file);
    my $ret    = $self->scp('remote:' . $remote_file, $dest);
    if (defined($ret) && $ret == 0) {
        upload_logs($dest);
    }
    assert_script_run("test -d '$tmpdir' && rm -rf '$tmpdir'");
}

1;
