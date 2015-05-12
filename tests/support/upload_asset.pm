use base "installbasetest";
use strict;
use testapi;

sub run() {
    my $self = shift;
    # store resulting hdd as job asset
    # this only creates link, actual upload is done after qemu stops
    upload_image(1, get_var('STORE_ASSET'), 'assets_public');
    $self->result('ok');
}

1;
# vim: set sw=4 et: