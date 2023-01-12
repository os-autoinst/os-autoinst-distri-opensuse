# SUSE's openQA tests

package YuiRestClient::Filter;

use strict;
use warnings;

use YuiRestClient::Sanitizer;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        resolved => 1
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    # as only one regex makes sense, get the first element
    my ($regex_key) = grep { ref $args->{$_} eq ref qr// } keys %{$args};
    if ($regex_key) {
        $self->{regex} = {k => $regex_key, v => $args->{$regex_key}};
        delete $args->{$regex_key};
        $self->{resolved} = 0;
    }
    $self->{filter} = $args;
    return $self;
}

sub get_filter {
    my ($self) = @_;
    return $self->{filter};
}

sub is_resolved {
    my ($self) = @_;
    return $self->{resolved};
}

sub resolve {
    my ($self, $json, $args) = @_;
    my ($k, $v) = ($self->{regex}->{k}, $self->{regex}->{v});
    YuiRestClient::Wait::wait_until(object => sub {
            my @widgets = grep {
                defined $_->{$k} && YuiRestClient::Sanitizer::sanitize($_->{$k}) =~ $v
            } @{$json};
            if (scalar @widgets == 1) {
                $self->{filter}->{$k} = YuiRestClient::Sanitizer::sanitize($widgets[0]->{$k});
                $self->{resolved} = 1;
            }
        },
        timeout => $args->{timeout},
        interval => $args->{interval}
    );
}

1;

__END__

=encoding utf8

=head1 NAME

YuiRestClient::Filter - manage filter for YuiRestClient

=head1 COPYRIGHT

Copyright 2021 SUSE LLC

SPDX-License-Identifier: FSFAP

=head1 AUTHORS

QE Yam <qe-yam at suse de>

=head1 SYNOPSIS

  $filter = YuiRestClient::Filter->new($filter);
  return $self->{widget_controller}->find($self->{filter}->get_filter());
  return $self->{filter}->is_resolved();

=head1 DESCRIPTION

=head2 Overview

Every YUI object that is created in the YuiRestClient is identified
with a 'filter' that identifies the object. This class provides 
methods to work with those filters. 

=head2 Class and object methods

Class attributes:

=over 4

=item B<{resolved}> - boolean to indicate that regex matched.
On initialization of an object this will be 1 for standard arguments and
0 if the argument contains a reglular expression. 

=item B<{regex}> - a hash that stores the regex in {k, v}.
If the argument list contains a regular expression then this is stored
in the regex attribute as a hash with a key 'k' and a value 'v', where
'v' represents the regular expression.

=item B<{filter}> - a hash that contains the filter arguments. 
If the argument list contains a regex, then this regex is removed from {filter} 
during initialization.

=back

Object methods:

B<new($args)> - create a filter object.

The argument $args is a hash that can contain several key/value pairs to identify
an UI object. Key values match the keys in the JSON representation of the UI widgets
and values can be either simple strings or regular expressions ( qr/.../). 

B<get_filter()> - returns the filter hash used to create the filter object

Note that when a regex was used on creation then this is removed from the filter
hash after initialization of the object. You need to call method resolve() to 
insert a filter with the found match for the regex before calling get_filter()
then.

B<is_resolved()> - returns status of regex matching

The method returns the value of the {resolved} attribute. This value will be 
altered by the resolve() method. 

B<resolve($json)> - resolve a regex 

This method tries to match the regular expression that was used during 
object creation. If exactly B<one> match was found the {filter} attribute gets
a new key/value pair that holds the key and the true matching value for the
regular expression. If the regex is resolved, then the attribute {resolve} is
set to 1 (true). 


=cut
