# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles installation reboot screen.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Yam::Agama::Pom::RebootPage;
use strict;
use warnings;

use testapi;

sub new {
    my ($class, $args) = @_;
    return bless {
        tag_installation_complete => 'agama-install-finished',
        tag_reboot_button => 'reboot'
    }, $class;
}

sub expect_is_shown {
    my ($self, %args) = @_;
    my $timeout = $args{timeout};
    if ($timeout <= 1200) {
        assert_screen($self->{tag_installation_complete}, ${timeout});
    } else {
        my $mouse_x = 1;
        while (1) {
            die "timeout ($timeout) hit on during installation" if $timeout <= 0;
            if (check_screen $self->{tag_installation_complete}, 30) {
                last;
            } else {
                $timeout -= 30;
                diag("left total timeout: $timeout");
                diag('installation not finished, move mouse around a bit to keep screen unlocked');
                mouse_set(($mouse_x + 10) % 1024, 1);
                sleep 1;
                mouse_set($mouse_x, 1);
                next;
            }
        }
    }
}

sub reboot {
    my ($self) = @_;
    select_console('installation');
    assert_and_click($self->{tag_reboot_button});
}

1;
