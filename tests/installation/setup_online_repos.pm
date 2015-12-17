use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self          = shift;
    my @default_repos = qw/update-non-oss update-oss main-non-oss main-oss debug-main untested-update debug-update source/;    # ordered according to repos lists in real

    assert_screen 'online-repos', 200;                                                                                         # maybe slow due to network connectivity

    send_key 'alt-i', 1;                                                                                                       # move the cursor to repos lists

    foreach my $repotag (@default_repos) {
        my $needs_to_be_selected = 0;

        if (get_var("WITH_UPDATE_REPO") && $repotag =~ /^update/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_MAIN_REPO") && $repotag =~ /^main/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_DEBUG_REPO") && $repotag =~ /^debug/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_SOURCE_REPO") && $repotag =~ /^source/) {
            $needs_to_be_selected = 1;
        }
        elsif (get_var("WITH_UNTESTED_REPO") && $repotag =~ /^untested/) {
            $needs_to_be_selected = 1;
        }
        # check current entry is selected or not
        if (!check_screen("$repotag-selected", 5)) {
            send_key "spc" if $needs_to_be_selected;
        }
        else {
            send_key "spc" unless $needs_to_be_selected;
        }
        send_key "down";
    }

    if (get_var("WITH_UPDATE_REPO")) {
        assert_screen 'update-repos-selected', 10;
    }
    # TODO: assert screen for the rest of repos in case they are enabled

    send_key $cmd{next};    # Next

    assert_screen "desktop-selection", 200;    # Make sure repos setup is finished and went to next step already
}

1;
