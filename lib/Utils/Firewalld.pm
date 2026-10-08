package Utils::Firewalld;
use strict;
use warnings;
use Exporter 'import';
use testapi;

our @EXPORT_OK = qw(add_port_to_zone reload_firewalld);

=head1 Utils::Firewalld

C<Utils::Firewalld> - Library for firewalld related functionality

=cut


=head2 add_port_to_zone

    add_port_to_zone({ port => $port, zone => $zone });

Adds tcp C<$port> to C<$zone> of permanent configuration. Port can be a single port 
number or a range of ports e.g. 3000-5000

=cut

sub add_port_to_zone {
    my ($args) = @_;
    assert_script_run("firewall-cmd --zone=$args->{zone} --add-port=$args->{port}/tcp --permanent");
}

sub reload_firewalld {
    assert_script_run('firewall-cmd --reload');
}

1;
