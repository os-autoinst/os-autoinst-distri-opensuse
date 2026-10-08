use Mojo::Base -strict;

use FindBin '$Bin';
use Mojo::File 'path';
use Mojo::JSON 'decode_json';
use JSON::Validator;
use Test::More;
use Test::Warnings;

# Validates data/journal_check/bug_refs.json, the known-issue list consumed by
# tests/console/journal_check.pm, against data/journal_check/schema.yaml.
#
# Note that tools/check_jsonnet deliberately excludes bug_refs.json from the
# generic data/ JSON check, so this test is the only CI coverage it has.

my $data_file = path($Bin, '..', 'data', 'journal_check', 'bug_refs.json');
my $schema_file = path($Bin, '..', 'data', 'journal_check', 'schema.yaml');

ok -f $data_file, 'data/journal_check/bug_refs.json exists';
ok -f $schema_file, 'data/journal_check/schema.yaml exists';

my $validator = JSON::Validator->new;
$validator = eval { $validator->load_and_validate_schema("$schema_file") };
BAIL_OUT("Schema $schema_file is itself invalid: $@") if $@;
pass 'schema is a valid JSON schema';

my $bugs = eval { decode_json($data_file->slurp) };
BAIL_OUT("$data_file is not valid JSON: $@") if $@;
pass 'bug_refs.json is valid JSON';

subtest 'bug_refs.json matches the schema' => sub {
    my @errors = $validator->validate($bugs);
    diag "  $_" for @errors;
    is scalar(@errors), 0, 'no schema violations';
    done_testing;
};

subtest 'every description is a usable Perl regex' => sub {
    # journal_check.pm interpolates the description straight into a match, so
    # an uncompilable pattern only blows up once the job is already running.
    for my $bugid (sort keys %$bugs) {
        my $re = $bugs->{$bugid}{description};
        ok eval { qr/$re/; 1 }, "$bugid: description compiles" or diag "  $@";
    }
    done_testing;
};

done_testing;
