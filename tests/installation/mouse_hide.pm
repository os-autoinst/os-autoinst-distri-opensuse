use base "opensusebasetest";
use testapi;

sub run() {
    my $self = shift;
    if (check_screen('mouse-not-hidden', 120)) {
        die 'Mouse Stuck Detected';
    }
    $self->result('ok');
}

sub test_flags {
    return { fatal => 1 };
}

1;
