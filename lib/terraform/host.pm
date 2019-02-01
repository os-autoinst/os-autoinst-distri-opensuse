# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Host (hypervisor) where the test VMs will be spawned
#
# Maintainer: Jose Lausuch <jalausuch@suse.de>
#   Pre-requirements: - public ssh key in data dir must be set previously on the
#                       host to run SSH commands on the host without password
#                     - libvirt service must be running

package terraform::host;
use Mojo::Base -base;
use testapi;
use strict;

has ip   => undef;    # IP for ssh access
has user => undef;    # domain name


=head2 run_ssh_command

    run_ssh_command($cmd);

    Runs a command C<cmd> via ssh on the Host. Retrieves the output.
    If the command retrieves not zero, an exception is thrown.

=cut
sub run_ssh_command {
    my ($self, $cmd) = @_;
    die('Argument <cmd> missing') unless ($cmd);
    my $ssh_cmd = sprintf("ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no %s@%s -- '%s'",
        $self->user, $self->ip, $cmd);
    my $output = script_output($ssh_cmd);
    record_info('SSH CMD', 'HOST: ' . $self->ip . "\nCMD: $ssh_cmd\n\n$output") if check_var('DEBUG', 1);
    return $output;
}

=head2 check_host

    check_host();

    Perform some checks on the host to see if it can run the tests

=cut
sub check_host {
    my ($self) = @_;
    my $output = $self->run_ssh_command('systemctl status libvirtd');
    record_info('libvirt', "Status of libvirtd service:\n$output") if check_var('DEBUG', 1);
    # TODO: more checks, such as kvm, lscpu, storage pool, etc
}

1;
