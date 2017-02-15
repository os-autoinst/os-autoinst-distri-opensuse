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
    our @EXPORT = qw(login);
}

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
    wait_serial(qr/$escseq* \w+:~\s\# \s* $escseq* \s*$/x);
    # TODO: use distribution::set_standard_prompt
    type_string(qq/PS1="# "\n/);
    wait_serial(qr/PS1="# "\s+# $/);
    # TODO: Send 'tput rmam' instead/also
    assert_script_run('stty cols 2048');
    assert_script_run('echo Logged into $(tty)', $bmwqemu::default_timeout, result_title => 'vconsole_login');
}

1;
