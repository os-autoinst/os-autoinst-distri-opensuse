# SUSE's openQA tests
#
# Copyright 2024 SUSE LLC

# Summary: boot disk using the right moodules
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'installbasetest';
use utils;
use Utils::Architectures;
use Utils::Backends;
use security_boot_utils;
use version_utils qw(is_sle is_sle_micro);
use testapi;

sub run {
    my ($self) = shift;

    if (boot_has_no_video) {
        $self->boot_encrypt_no_video;
    } else {
        my $timeout = get_var('BOOTLOADER_TIMEOUT', 200);
        # Increase timeout on ipmi bare metal backend, firmware initialization takes a lot of time
        $timeout += 300 if is_ipmi;

        # Booting of encrypted disk needs additional time too.
        $timeout += 60 if get_var('ENCRYPT');

        # Add additional 120s if the test suite is pvm
        $timeout += 120 if is_pvm;

        my $enable_root_ssh = (is_sle_micro('>=6.0') && is_s390x) ? 1 : 0;
        if (is_s390x && get_var('S390_ZKVM')) {
            eval { $self->wait_boot(bootloader_time => $timeout, enable_root_ssh => $enable_root_ssh) };
            if (my $err = $@) {
                die $err unless $err =~ /Passwor\[dt\]/;
                record_info('login retry', "Login prompt dropped the user name, retrying:\n$err");
                $self->retry_svirt_login(enable_root_ssh => $enable_root_ssh);
            }
        } else {
            $self->wait_boot(bootloader_time => $timeout, enable_root_ssh => $enable_root_ssh);
        }
    }
}

# Finish the svirt login done by reconnect_s390 when agetty dropped the
# typed user name while redrawing the login prompt
sub retry_svirt_login {
    my ($self, %args) = @_;
    my $attempts = 3;
    for my $attempt (1 .. $attempts) {
        type_line_svirt 'root';
        last if wait_serial(qr/Passwor[dt]/, 30);
        die 'Password prompt not found after typing root' if $attempt == $attempts;
    }
    type_line_svirt $testapi::password;
    type_line_svirt 'systemctl is-active network', expect => qr/^active\s*$/m;
    if ($args{enable_root_ssh}) {
        type_line_svirt 'mkdir -p /etc/ssh/sshd_config.d';
        type_line_svirt "echo 'PermitRootLogin yes' \\> /etc/ssh/sshd_config.d/root.conf";
        type_line_svirt 'systemctl restart sshd';
    }
    type_line_svirt 'systemctl is-active sshd', expect => qr/^active\s*$/m;
    select_console(check_var('DESKTOP', 'textmode') ? 'root-console' : 'x11', await_console => 0);
    $self->wait_boot_past_bootloader;
    $self->{in_wait_boot} = 0;
}

sub test_flags {
    # add milestone flag to save setup in lastgood VM snapshot
    return {fatal => 1, milestone => 1};
}

1;
