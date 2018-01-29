# SUSE's openQA tests
#
# Copyright © 2016-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
package serial_terminal;
use 5.018;
use warnings;
use testapi;
use utils;
use autotest;
use base 'Exporter';
use Exporter;
use bmwqemu ();

BEGIN {
    our @EXPORT = qw(
      add_serial_console
      get_login_message
      login
      select_virtio_console
      serial_term_prompt
    );
}

our $serial_term_prompt;

=head2 add_serial_console

    add_serial_console($console);

Adds $console to /etc/securetty (unless already in file), enables systemd
service and start it. It requires selecting root console before.
=cut
sub add_serial_console {
    my ($console) = @_;
    my $service   = 'serial-getty@' . $console;
    my $config    = '/etc/securetty';
    script_run(qq{grep -q "^$console\$" $config || echo '$console' >> $config; systemctl enable $service; systemctl start $service});
}

=head2 get_login_message

   get_login_message();

Get login message printed by OS at the end of the boot.
Suitable for testing whether boot has been finished:

wait_serial(get_login_message(), 300);
=cut
sub get_login_message {
    my $arch = get_required_var("ARCH");
    return check_var('VERSION', 'Tumbleweed') ? qr/Welcome to openSUSE Tumbleweed 20.*/ : qr/Welcome to SUSE Linux Enterprise .*\($arch\)/;
}

=head2 login

   login($user);

Enters root's name and password to login. Also sets the prompt to something static without ANSI
escape sequences (i.e. a single #) and changes the terminal width.

=cut
sub login {
    die 'Login expects two arguments' unless @_ == 2;
    my $user   = shift;
    my $escseq = qr/(\e [\(\[] [\d\w]{1,2})/x;

    $serial_term_prompt = shift;

    bmwqemu::log_call;

    # newline nudges the guest to display the login prompt, if this behaviour
    # changes then remove it
    type_string("\n");
    wait_serial(qr/login:\s*$/i);
    type_string("$user\n");
    wait_serial(qr/Password:\s*$/i);
    type_password;
    type_string("\n");
    wait_serial(qr/$escseq* \w+:~\s\# $escseq* \s*$/x);
    type_string(qq/PS1="$serial_term_prompt"\n/);
    wait_serial(qr/PS1="$serial_term_prompt"/);
    # TODO: Send 'tput rmam' instead/also
    assert_script_run('export TERM=dumb; stty cols 2048');
    assert_script_run('echo Logged into $(tty)', $bmwqemu::default_timeout, result_title => 'vconsole_login');
}

=head2 select_virtio_console

   select_virtio_console();

Helper to select console 'root-virtio-terminal' or 'root-console'.
=cut
# TODO: Move here optional init with add_serial_console($console);
sub select_virtio_console {
    my $is_virtio = get_var('VIRTIO_CONSOLE');

    if ($is_virtio && !get_var('S390_ZKVM')) {
        select_console('root-virtio-terminal');
        return 1;
    }

    bmwqemu::fctwarn("Cannot use virtio console on s390 on ZKVM") if $is_virtio;
    select_console('root-console');
    return 0;
}

sub serial_term_prompt {
    return $serial_term_prompt;
}

1;
# vim: set sw=4 et:
