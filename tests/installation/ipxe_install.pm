# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Verify installation starts and is in progress
# Maintainer: Michael Moese <mmoese@suse.de>

use base 'baremetalbasetest';
use strict;
use warnings;

use testapi;
use bmwqemu;

use HTTP::Tiny;
use IPC::Run;
use Socket;
use Time::HiRes 'sleep';


sub set_ipxe_bootscript {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url         = "$http_server/v1/bootscript/script.ipxe/$ip";

    my $autoyast = get_required_var('AUTOYAST');

    my $kernel  = get_required_var('MIRROR_HTTP') . '/boot/x86_64/loader/linux';
    my $initrd  = get_required_var('MIRROR_HTTP') . '/boot/x86_64/loader/initrd';
    my $install = get_required_var('MIRROR_NFS');

    my $bootscript = <<"END_BOOTSCRIPT";
#!ipxe
echo ++++++++++++++++++++++++++++++++++++++++++
echo ++++++++++++ openQA ipxe boot ++++++++++++
echo +    Host: $host
echo ++++++++++++++++++++++++++++++++++++++++++

kernel $kernel install=$install autoyast=$autoyast console=tty0 console=ttyS1,115200
initrd $initrd
boot
END_BOOTSCRIPT

    diag "setting iPXE bootscript to: $bootscript";
    my $response = HTTP::Tiny->new->request('POST', $url, {content => $bootscript, headers => {'content-type' => 'text/plain'}});
    diag "$response->{status} $response->{reason}\n";
}

sub run {
    my $self = shift;

    if !($self->host_is_locked()) {
        die("Host has to be locked before installing!")
    }

    $self->poweroff();

    if (check_var('BACKEND', 'ipmi')) { }
    set_ipxe_bootscript();
} else {
    die("Backend " . get_var('BACKEND') . ' is not supported.');
}

self->set_net_boot();
self->poweron();

$self->wait_boot();
}

1;
