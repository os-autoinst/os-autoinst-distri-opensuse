use strict;
use warnings;
use Test::More;
use Test::MockModule;
use testapi;
use bugzilla;
use Mojo::URL;
use feature qw(say signatures);

# Mock the Mojo::URL object
my $mocked_bugzilla_url = Mojo::URL->new('https://bugzilla.suse.com/show_bug.cgi?id=@BUGID@');

my $mocked_bugzilla_xml = <<'XML';
<bug>
  <bug_id>123</bug_id>
  <summary>Example Bug</summary>
  <description>This is an example bug for testing purposes.</description>
  <status>NEW</status>
  <priority>HIGH</priority>
</bug>
XML

my $mocked_bugzilla_response = {
    bug_id => '123',
    summary => 'Example Bug',
    description => 'This is an example bug for testing purposes.',
    status => 'NEW',
    priority => 'HIGH',
};

# Mock the Mojo::UserAgent result
# internally the bugzilla_buginfo function calls:
# my $msg = Mojo::UserAgent->new->get($url)->result;
# so we need to mock the result method and return a mocked object
# that has a code method that returns 200 and a body method that
# returns the bugzilla_xml string

my $user_agent_mock = Test::MockModule->new('Mojo::UserAgent');

=head1 NAME

create_transaction - Create a transaction object

=head1 DESCRIPTION

This function creates a transaction object using the provided code and body. It sets the response code, body, and creates a new transaction object.

=cut

sub create_transaction ($code, $body) {
    my $response = Mojo::Message::Response->new;
    my $transaction = Mojo::Transaction::HTTP->new;
    $transaction->res($response);
    $transaction->res->body($body);
    $transaction->res->code($code);
    return $transaction;
}

# Mock the get method of the Mojo::UserAgent object
# using a similar strategy we used for the worker cache tests
$user_agent_mock->mock(get => sub {
        my ($self, $url) = @_;
        $url = Mojo::URL->new($url);
        # Return the desired response based on the URL
        say "URL: " . $url->query;
        say "Mocked URL:" . $mocked_bugzilla_url->query;
        if ($url->query eq $mocked_bugzilla_url->query) {
            say "URL $url matches mocked URL $mocked_bugzilla_url";
            return create_transaction(200, $mocked_bugzilla_xml);
        } elsif ($mocked_bugzilla_url->query->id eq 0) {
            say "URL $url matches mocked URL $mocked_bugzilla_url, we want invalid xml";
            return create_transaction(200, "<invalid xml>");
        } elsif ($mocked_bugzilla_url->query->id eq 500) {
            say "URL $url matches mocked URL $mocked_bugzilla_url, we want invalid xml";
            return create_transaction(500, "provoked error 500");
        } else {
            say "URL $url does not match mocked URL $mocked_bugzilla_url";
            return create_transaction(404, 'Not found');
        }
});

is_deeply(bugzilla::parse_buginfo($mocked_bugzilla_xml), $mocked_bugzilla_response, 'Bugzilla XML mocked bugzilla_xml is parsed correctly');

# Mock the 'get_var' function
set_var('BUGZILLA_URL', $mocked_bugzilla_url->to_string);
# $utils_mock->mock('get_var', sub { say join(', ', @_); return $mocked_bugzilla_url; });

# Run the test, since we expect the bugid to be 123, we need to change the query of the mocked URL
$mocked_bugzilla_url->query('id=123');
is_deeply(bugzilla::bugzilla_buginfo('123'), $mocked_bugzilla_response, 'bugzilla_buginfo returns correct info');

done_testing();
