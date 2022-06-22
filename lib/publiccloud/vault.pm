# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Base helper class for vault client
#
# Maintainer: qa-c team <qa-c@suse.de>

package publiccloud::vault;
use testapi qw(is_serial_terminal :DEFAULT);
use Mojo::Base -base;
use List::Util qw(max);

has token => undef;
has lease_id => undef;

=head2 retry

Retry n times the execution of a function.
=cut

sub retry {
    my ($self, $code, %args) = @_;
    my $max_tries = max(1, get_var('PUBLIC_CLOUD_VAULT_TRIES', $args{max_tries} // 3));
    my $sleep_duration = get_var('PUBLIC_CLOUD_VAULT_TIMEOUT', $args{sleep_duration} // 60);
    $args{name} //= Carp::shortmess("retry()");

    my $ret;
    my $try_cnt = 0;

    while ($try_cnt++ < $max_tries) {
        eval { $ret = $code->(); };
        return $ret unless ($@);
        sleep $sleep_duration;
    }
    die($args{name} . " call failed after $max_tries attempts -- " . $@);
}

=head2 __login

Login to vault using C<_SECRET_PUBLIC_CLOUD_REST_USER> and
C<_SECRET_PUBLIC_CLOUD_REST_PW>. The retrieved TOKEN is stored in this
instance and used for further C<publiccloud::provider::api()> calls.
=cut

sub __login {
    my ($self) = @_;
    my $url = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $user = get_required_var('_SECRET_PUBLIC_CLOUD_REST_USER');
    my $password = get_required_var('_SECRET_PUBLIC_CLOUD_REST_PW');
    my $ua = Mojo::UserAgent->new;

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $url = $url . '/v1/auth/userpass/login/' . $user;
    my $res = $ua->post($url => json => {password => $password})->result;
    if (!$res->is_success) {
        my $err_msg = 'Request ' . $url . ' failed with: ' . $res->message . ' (' . $res->code . ')';
        $err_msg .= "\n" . join("\n", @{$res->json->{errors}}) if ($res->code == 400);
        record_info('Vault login', $err_msg, result => 'fail');
        die("Vault login failed - $url");
    }

    return $self->token($res->json('/auth/client_token'));
}

=head2 login

Wrapper arround C<<$self->login()>> to have retry capability.
=cut

sub login {
    my $self = shift;
    return $self->retry(
        sub { $self->__login() },
        name => 'login()',
        sleep_duration => 10
    );
}

=head2 __api

Invoke a vault API call. It use _SECRET_PUBLIC_CLOUD_REST_URL as base
url.
Depending on the method (get|post) you can pass additional data as json.
=cut

sub __api {
    my ($self, $path, %args) = @_;
    my $method = $args{method} // 'get';
    my $data = $args{data} // {};
    my $ua = Mojo::UserAgent->new;
    my $url = get_required_var('_SECRET_PUBLIC_CLOUD_REST_URL');
    my $res;

    $self->login() unless ($self->token);

    $ua->insecure(get_var('_SECRET_PUBLIC_CLOUD_REST_SSL_INSECURE', 0));
    $ua->request_timeout(40);
    $url = $url . $path;
    bmwqemu::diag("Request Vault REST API: $url");
    if ($method eq 'get') {
        $res = $ua->get($url => {'X-Vault-Token' => $self->token()})->result;
    }
    elsif ($method eq 'post') {
        $res = $ua->post($url => {'X-Vault-Token' => $self->token()} => json => $data)->result;
    }
    else {
        die("Unknown method $method");
    }

    if (!$res->is_success) {
        my $err_msg = 'Request ' . $url . ' failed with: ' . $res->message . ' (' . $res->code . ')';
        $err_msg .= "\n" . join("\n", @{$res->json->{errors}}) if ($res->code == 400);
        record_info('Vault API', $err_msg, result => 'fail');
        die("Vault REST api call failed - $url");
    }

    return $res->json;
}

=head2 api

Wrapper around C<<$self->api()>> to get retry capability.
=cut

sub api {
    my ($self, $path, %args) = @_;
    my $max_tries = delete($args{max_tries}) // 3;
    my $sleep_duration = delete($args{sleep_duration}) // 60;

    return $self->retry(
        sub { $self->__api($path, %args) },
        name => 'api()',
        max_tries => $max_tries,
        sleep_duration => $sleep_duration
    );
}

=head2 get_secrets

  my $data = $csp->get_secrets('/azure/creds/openqa-role' [, max_tries => 3][, sleep_duration => 60])

This is a wrapper around C<api()> to retrieve secrets from aws, gce or
azure secret engine.
It prepend C<'/v1/' + $NAMESPACE> to the given path before sending the request.
It stores lease_id and also adjust the token-live-time.
=cut

sub get_secrets {
    my ($self, $path, %args) = @_;
    my $res = $self->api('/v1/' . get_var('PUBLIC_CLOUD_VAULT_NAMESPACE', '') . $path, method => 'get', %args);
    $self->lease_id($res->{lease_id});
    $self->api(
        '/v1/auth/token/renew-self',
        method => 'post',
        data => {increment => $res->{lease_duration} . 's'},
        %args
    );
    return $res->{data};
}

=head2 revoke

Revoke a previous retrieved credential
=cut

sub revoke {
    my ($self) = @_;

    return unless (defined($self->lease_id));

    $self->api('/v1/sys/leases/revoke', method => 'post', data => {lease_id => $self->lease_id});
    $self->lease_id(undef);
}

1;
