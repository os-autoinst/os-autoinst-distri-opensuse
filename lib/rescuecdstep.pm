=head1 rescuecdstep

Base class for all RESCUECD tests

=cut

package rescuecdstep;
use base "opensusebasetest";
use testapi;
use strict;
use warnings;

# Base class for all RESCUECD tests

=head2 test_flags

Return test flag fatal => 1

=cut
sub test_flags {
    return {fatal => 1};
}

1;
