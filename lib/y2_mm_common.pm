=head1 y2_mm_common.pm

Configure a static network.

=cut
package y2_mm_common;

use strict;
use warnings;
use Exporter 'import';
use testapi;
use mm_tests 'configure_static_network';
use x11utils 'turn_off_gnome_screensaver';

our @EXPORT = qw(prepare_xterm_and_setup_static_network);

=head2 prepare_xterm_and_setup_static_network

 prepare_xterm_and_setup_static_network();

Use C<x11_start_program('xterm')> to open a xterm. 
Then setup a static network by C<configure_static_network(%args{ip})>.
C<%args> is a list with possible keys like {message} or {ip}.

=cut

sub prepare_xterm_and_setup_static_network {
    my %args = @_;
    die "Static network configuration failed, no IP specified!\n" unless defined($args{ip});
    x11_start_program('xterm -geometry 160x45+5+5', target_match => 'xterm');
    turn_off_gnome_screensaver;
    become_root;
    record_info 'Network', $args{message} if defined($args{message});
    configure_static_network($args{ip});
}

1;
