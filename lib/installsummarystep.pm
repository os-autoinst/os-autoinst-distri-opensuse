package installsummarystep;
use base 'y2_installbase';
use testapi;
use strict;
use warnings;


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
    my $timeout = 30 * get_var('TIMEOUT_SCALE', 1);    # Default timeout
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
    assert_screen 'inst-overview', $timeout;
}

1;
