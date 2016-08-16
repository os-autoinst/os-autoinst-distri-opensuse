# SUSE's openQA tests
#
# Copyright © 2009-2013 Bernhard M. Wiedemann
# Copyright © 2012-2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

use base "y2logsstep";
use strict;
use testapi;

sub run() {
    my $self          = shift;
    my @default_repos = qw/update-non-oss update-oss main-non-oss main-oss debug-main untested-update debug-update source/;    # ordered according to repos lists in real

    assert_screen 'online-repos', 200;                                                                                         # maybe slow due to network connectivity

    # move the cursor to repos lists
    if (check_var("VIDEOMODE", "text")) {
        send_key 'alt-l';
    }
    else {
        send_key 'alt-i';
    }

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

    if (get_var("WITH_MAIN_REPO")) {
        assert_screen 'license-dialog-oss-repo';
        send_key $cmd{next};    # Next
    }

    if (get_var("WITH_UNTESTED_REPO")) {
        assert_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48';
        while (1) {
            send_key 'alt-t';    # Trust
                                 # for some reason the key is prompted twice, bug?
            last unless check_screen 'import-untrusted-gpg-key-598D0E63B3FD7E48';
        }
    }
    # make sure we are done with the setup and arrived at the next screen
    # which can take some time as this involves network traffic
    assert_screen 'before-package-selection', 300;
}

1;
