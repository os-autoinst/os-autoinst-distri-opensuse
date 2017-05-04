# SUSE's openQA tests
#
# Copyright © 2016 SUSE LLC
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
    our @EXPORT = qw($serial_term_prompt login);
}

=head2 serial_term_prompt

   wait_serial($serial_term_prompt);

A simple undecorated prompt for serial terminals. ANSI escape characters only
serve to create log noise in most tests which use the serial terminal, so
don't use them here. Also avoid using characters which have special meaning in
a regex. Note that our common prompt character '#' denotes a comment in a
regex with '/z' on the end, but if you are using /z you will need to wrap the
prompt in \Q and \E anyway otherwise the whitespace will be ignored.

=cut
our $serial_term_prompt = '# ';

=head2 login

   login($user);

Enters root's name and password to login. Also sets the prompt to something static without ANSI
escape sequences (i.e. a single #) and changes the terminal width.

=cut
sub login {
    die 'Login expects one argument' unless @_ == 1;
    my $user = shift || 'root';
    my $escseq = qr/(\e [\(\[] [\d\w]{1,2})/x;

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
    wait_serial(qr/PS1="$serial_term_prompt"\s+# $/);
    # TODO: Send 'tput rmam' instead/also
    assert_script_run('stty cols 2048');
    assert_script_run('echo Logged into $(tty)', $bmwqemu::default_timeout, result_title => 'vconsole_login');
}

1;
