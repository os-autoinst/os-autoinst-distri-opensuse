use base "y2logsstep";
use testapi;

sub run() {
    if (check_screen('mouse-not-hidden'), 120) {
        die 'Mouse Stuck Detected';
    }
}

1;
