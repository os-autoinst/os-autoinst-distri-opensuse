# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Checks if the used image version is up-to-date
#          This test is a cross-check to ensure the logic of the openQA QAM Bot is working properly
#
# Maintainer: Felix Niederwanger <felix.niederwanger@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use Mojo::Base -strict;
use Mojo::UserAgent;

# Fetch links from a given url that match the given regexp
sub fetch_matching_links {
    my $url   = $_[0];
    my $match = $_[1];
    my $ua    = Mojo::UserAgent->new();
    my $links = $ua->get($url)->res->dom->find('a')->map(attr => 'href');
    return grep { $_ =~ $match } @{$links};
}

# Compare two version strings (e.g. '0.9.1' and '0.9.0' or '0.141' and '0.139')
# returns -1 if the first is smaller, 1 if larger and 0 if they are the same
sub version_cmp {
    my @v1 = split('\.', $_[0]);
    my @v2 = split('\.', $_[1]);

    my $l = scalar @v1;
    die "No versions to compare"  if ($l <= 0);
    die "Version scheme mismatch" if ($l != scalar @v2);
    for (my $i = 0; $i < $l; $i++) {
        if ($v1[$i] < $v2[$i]) {
            return -1;
        } elsif ($v1[$i] > $v2[$i]) {
            return 1;
        }
    }
    return 0;
}

# Given an publiccloud image URL/regex location, this routine returns the URL of the latest available version
sub get_latest_image_version {
    my $image    = $_[0];
    my $i        = rindex($image, '/');
    my $regex    = substr($image, $i + 1);
    my $basepath = substr($image, 0, $i) . '/';


    # Fetch links from the URL base path that match the generated regex
    my @links = fetch_matching_links("$basepath", ".*$regex\$");
    my $links = scalar @links;
    return "" if ($links <= 0);
    #Disabled but useful prints, in case something breaks
    #print("Running PublicCloud image check on $links links ... \n");
    #print("    Image location       : $basepath\n");
    #print("    Regex                : $regex\n");
    #print("\n");

    my $filename = $links[0];
    die "Error building regex for $filename" unless ($filename =~ $regex);
    my $kiwi_build = $+{kiwi_build};
    my $build      = $+{build};

    for my $link (@links) {
        if ($link =~ $regex) {
            my $c_kiwi_build = $+{kiwi_build};
            my $c_build      = $+{build};

            my $cmp = version_cmp($kiwi_build, $c_kiwi_build);
            if ($cmp < 0) {
                $filename = $link;
            } elsif ($cmp > 0) {
                next;
            }
            $cmp = version_cmp($build, $c_build);
            if ($cmp < 0) {
                $filename = $link;
            } elsif ($cmp > 0) {
                next;
            }
        }
    }
    return $basepath . $filename;
}

sub run {
    # Preparation
    my $self = shift;
    $self->select_serial_terminal;
    my $regex = get_var('PUBLIC_CLOUD_IMAGE_REGEX');
    if ($regex ne "") {
        my $image = get_var('PUBLIC_CLOUD_IMAGE_LOCATION');
        if ($image eq "") {
            record_soft_failure("PUBLIC_CLOUD_IMAGE_LOCATION not set but regex present:\n$image");
            return;
        }
        my $latest_image = get_latest_image_version($regex);
        if ($latest_image eq "") {
            record_soft_failure("No images found for PUBLIC_CLOUD_IMAGE_REGEX:\n$regex");
            return;
        }
        if ($image ne $latest_image) {
            record_soft_failure("Please update PUBLIC_CLOUD_IMAGE_LOCATION to:\n$latest_image");
        } else {
            record_info("PUBLIC_CLOUD_IMAGE_LOCATION is up to date", "Up-to-date: $image");
        }
    }
}

1;
