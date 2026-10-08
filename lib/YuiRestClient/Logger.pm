# SUSE's openQA tests

package YuiRestClient::Logger;
use strict;
use warnings;
use Term::ANSIColor;

my $instance;

sub get_instance {
    my ($class, $args) = @_;

    return $instance if defined $instance;
    $instance = bless {
        logger => Mojo::Log->new(
            level => $args->{level},
            format => $args->{format},
            path => $args->{path})
    }, $class;
}

sub debug {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('white'));
    $instance->{logger}->debug($message)->append(color('reset'));
}

sub info {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('blue'));
    $instance->{logger}->info($message)->append(color('reset'));
}

sub warn {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('yellow'));
    $instance->{logger}->warn($message)->append(color('reset'));
}

sub error {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('bold red'));
    $instance->{logger}->error($message)->append(color('reset'));
}

sub fatal {
    my ($self, $message) = @_;
    $instance->{logger}->append(color('bold red'));
    $instance->{logger}->fatal($message)->append(color('reset'));
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Logger - class to log messages 

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  YuiRestClient::Logger->get_instance({format => \&bmwqemu::log_format_callback, 
                         path => $path_to_log, level => $yui_log_level});

  YuiRestClient::Logger->get_instance()->debug('Finding widget by url: ' . $uri);
  YuiRestClient::Logger->info("Info message");
  YuiRestClient::Logger->warn("Warn message");
  YuiRestClient::Logger->error("Error message");
  YuiRestClient::Logger->fatal("Fatal message");


=head1 DESCRIPTION

=head2 Overview

A class that provides logging services. The class uses Mojo::Log for
logging and works with Term::ANSIColor to colorize the log messages
according to their level.

=head2 Class and object methods

B<get_instance(%args)> - create or use existing logger instance

The %arg named parameters are

=over 4

=item * B<{level}> - the minimum log levels, log entries below this level will not appear in the log.

=item * B<{format}> - a callback for formatting log messages

=item * B<{path}> - the path and filename for the log file

=back

An instance for Logger is only created on the first invocation of get_instance(),
further invocations use the already existing instance.

B<debug($message)> - logs a debug message

Debug messages are logged in white text color.

=for Maintenance: Hopefully on a black background :-)

B<info($message)> - logs an info message

Info messages are logged in blue text color.

B<warn($message)> - logs a warn message

Warn messages are logged in yellow text color.

B<error($message)> - logs an error message

Error messages are logged in bold red text color.

B<fatal($message)> - logs a fatal message

Fatal messages are logged in bold red text color.

=cut
