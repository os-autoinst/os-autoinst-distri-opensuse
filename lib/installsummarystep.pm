package installsummarystep;
use base "y2logsstep";
use testapi;
use strict;
use utils 'sle_version_at_least';


sub accept3rdparty {
    #Third party licenses sometimes appear
    while (check_screen([qw(3rdpartylicense automatic-changes inst-overview)], 15)) {
        last if match_has_tag("automatic-changes");
        last if match_has_tag("inst-overview");
        wait_screen_change {
            send_key $cmd{acceptlicense};
        };
    }
}

sub accept_changes_with_3rd_party_repos {
    my ($self) = @_;
    if (check_var('VIDEOMODE', 'text')) {
        send_key $cmd{accept};
        accept3rdparty;
        assert_screen 'automatic-changes';
        send_key $cmd{ok};
    }
    else {
        send_key $cmd{ok};
        accept3rdparty;
    }
    if (sle_version_at_least '15') {
        $self->sle15_workaround_broken_patterns;
    }
    assert_screen 'inst-overview';
}

1;
# vim: set sw=4 et:
