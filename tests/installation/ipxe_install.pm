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

use strict;
use warnings;

use testapi;
use bmwqemu;
use base "y2logsstep";

use HTTP::Tiny;
use IPC::Run;
use Socket;
use Time::HiRes 'sleep';

sub ipmitool {
    my ($cmd) = @_;

    my @cmd = ('ipmitool', '-I', 'lanplus', '-H', $bmwqemu::vars{IPMI_HOSTNAME}, '-U', $bmwqemu::vars{IPMI_USER}, '-P', $bmwqemu::vars{IPMI_PASSWORD});
    push(@cmd, split(/ /, $cmd));

    my ($stdin, $stdout, $stderr, $ret);
    print @cmd;
    $ret = IPC::Run::run(\@cmd, \$stdin, \$stdout, \$stderr);
    chomp $stdout;
    chomp $stderr;

    die join(' ', @cmd) . ": $stderr" unless ($ret);
    bmwqemu::diag("IPMI: $stdout");
    return $stdout;
}

sub poweroff_host {
    ipmitool("chassis power off");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is off/;
        ipmitool('chassis power off');
    }
}

sub poweron_host {
    ipmitool("chassis power on");
    while (1) {
        sleep(3);
        my $stdout = ipmitool('chassis power status');
        last if $stdout =~ m/is on/;
        ipmitool('chassis power on');
    }
}

sub set_bootscript {
    my $host        = get_required_var('SUT_IP');
    my $ip          = inet_ntoa(inet_aton($host));
    my $http_server = get_required_var('IPXE_HTTPSERVER');
    my $url         = "$http_server/$ip/script.ipxe";

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

    poweroff_host;

    set_bootscript;

    ipmitool('chassis bootdev pxe');
    poweron_host;

    select_console 'sol', await_console => 0;

    # make sure to wait for a while befor changing the boot device again, in order to not change it too early
    sleep 120;

    ipmitool('chassis bootdev disk');
    assert_screen('linux-login', 1800);
}

1;
