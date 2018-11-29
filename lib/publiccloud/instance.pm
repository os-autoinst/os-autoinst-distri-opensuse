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

has instance_id => undef;               # unique CSP instance id
has public_ip   => undef;               # public IP of instance
has username    => undef;               # username for ssh connection
has ssh_key     => undef;               # path to ssh-key for connection
has provider    => undef, weak => 1;    # back reference to the provider

=head2 run_ssh_command

    run_ssh_command($cmd);

Runs a command C<cmd> via ssh in the given VM. Retrieves the output.
If the command retrieves not zero, a exception is thrown.
TODO Do not raise exception on error
TODO Be aware of special shell letters like ';'
=cut
sub run_ssh_command {
    my ($self, $cmd) = @_;

    die('Argument <cmd> missing') unless ($cmd);

    my $ssh_cmd = sprintf('ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i "%s" "%s@%s" -- %s',
        $self->ssh_key, $self->username, $self->public_ip, $cmd);
    record_info('CMD', $ssh_cmd);
    return script_output($ssh_cmd);
}

1;
