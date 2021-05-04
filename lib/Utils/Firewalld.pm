package Utils::Firewalld;
use strict;
use warnings;
use Exporter 'import';
use testapi;

our @EXPORT_OK = qw(add_port_to_zone);

=head1 Utils::Firewalld

C<Utils::Firewalld> - Library for firewalld related functionality

=cut


=head2 add_port_to_zone

    add_port_to_zone($port, $zone);

Adds C<$port> to C<$zone> to permanent configuration, then reloads firewall.

=cut
sub add_port_to_zone {
    my ($port, $zone) = @_;
    assert_script_run("firewall-cmd --zone=$zone --add-port=$port/tcp --permanent");
    assert_script_run('firewall-cmd --reload');
}

1;
