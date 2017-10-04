# SUSE's openQA tests

# Summary: SAP Pattern test
# Maintainer: Alvaro Carvajal <acarvajal@suse.de>

use base "x11test";
use strict;
use testapi;

sub run {
    my ($self) = @_;
    my @sappatterns = qw(sap-nw sap-b1 sap-hana);

    x11_start_program('xterm');
    assert_screen('xterm');

    foreach my $pattern (@sappatterns) {
        assert_script_sudo("zypper in -y -t pattern $pattern", 100);
        script_sudo("zypper info -t pattern $pattern");
        assert_screen \@sappatterns, 60;
        die "SAP zypper pattern [$pattern] info check failed" unless (match_has_tag 'sap-pattern');
    }

    send_key 'alt-f4';
}

1;
# vim: set sw=4 et:
