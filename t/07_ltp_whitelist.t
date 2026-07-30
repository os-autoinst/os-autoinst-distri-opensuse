use Mojo::Base -strict;

use Cwd ();
use File::Temp ();
use Mojo::File qw(path);
use Mojo::JSON qw(encode_json);
use Test::More;
use Test::MockModule;
use Test::MockObject;
use Test::Warnings;
use LTP::WhiteList;
use testapi;

# Build a mock test module (the `$testmod` that override_known_failures records results onto)
# that records what would have been reported.
sub _mock_testmod {
    my $testmod = Test::MockObject->new();
    $testmod->{result} = 'not_set';
    $testmod->{soft_msg} = undef;
    $testmod->{resultfiles} = [];
    $testmod->mock('record_soft_failure_result' => sub {
            my ($self, $msg, %opts) = @_;
            $self->{soft_msg} = $msg;
            $self->{result} = 'softfail';
    });
    $testmod->mock('record_resultfile' => sub {
            my ($self, $title, $msg, %opts) = @_;
            push @{$self->{resultfiles}}, {title => $title, message => $msg, %opts};
    });
    return $testmod;
}

# Clear the constructor-relevant openQA settings so each construction test
# starts from a known state.
sub _reset_source_vars {
    set_var('LTP_KNOWN_ISSUES', undef);
    set_var('LTP_KNOWN_ISSUES_LOCAL', undef);
}

subtest 'whitelist_entry_match' => sub {
    # An entry matches an environment only when every attribute the
    # entry constrains matches (as a regex); missing or differing env values fail
    # the match, and entries with fewer attributes are more permissive.
    my $entry = {
        product => '^sle:15-SP[23]$'
    };
    my $env = {
        foo => 'something',
        product => 'sle:15-SP3'
    };

    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Product match regex");

    $entry->{arch} = '^x86_64$';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), undef, "Missing field in ltp-environment, doesn't match the entry");

    $env->{arch} = 'foo';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), undef, "Different value in ltp-environment, doesn't match the entry");

    $env->{arch} = 'x86_64';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Multiple values need match");

    $env->{flavor} = 'EC2-HVM';
    is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Entry match with less attributes");

    for my $attr (qw(product ltp_version revision arch kernel backend retval flavor test_variant)) {
        $entry = {$attr => '^incredible_value$'};
        $env = {$attr => "incredible_value"};
        is_deeply(LTP::WhiteList::_whitelist_entry_match($entry, $env), $entry, "Check match attribute $attr");
    }

};

subtest '[WhiteList->new] local file source populates whitelist' => sub {
    # When LTP_KNOWN_ISSUES_LOCAL variable points to an existing file,
    # the constructor loads and parses it into $self->{whitelist}.
    my $data = {suite_a => {test_x => [{product => '^sle:15', message => 'known'}]}};
    my $dir = File::Temp->newdir();
    my $file = "$dir/whitelist.json";
    path($file)->spew(encode_json($data));

    _reset_source_vars();
    set_var('LTP_KNOWN_ISSUES_LOCAL', $file);

    my $whitelist = LTP::WhiteList->new();
    is_deeply($whitelist->{whitelist}, $data, 'whitelist loaded from local JSON file');
};

subtest '[WhiteList->new] missing local file yields empty whitelist' => sub {
    # A configured but non-existent local path does not fail;
    # the whitelist falls back to an empty hash.
    _reset_source_vars();
    set_var('LTP_KNOWN_ISSUES_LOCAL', '/does/not/exist/whitelist.json');

    my $whitelist = LTP::WhiteList->new();
    is_deeply($whitelist->{whitelist}, {}, 'missing local file => empty whitelist');
};

subtest '[WhiteList->new] no source yields empty whitelist' => sub {
    # With neither a local path nor a URL configured, the constructor
    # produces an empty whitelist rather than dying.
    _reset_source_vars();

    my $whitelist = LTP::WhiteList->new();
    is_deeply($whitelist->{whitelist}, {}, 'no source => empty whitelist');
};

subtest '[WhiteList->new] URL source populates whitelist via _download_whitelist' => sub {
    # When only LTP_KNOWN_ISSUES (a URL) is set, the constructor
    # downloads the file (via _download_whitelist) and loads it.
    my $data = {suite_b => {test_y => [{product => '^sle:12', message => 'downloaded'}]}};
    my $dir = File::Temp->newdir();
    my $file = "$dir/downloaded.json";
    path($file)->spew(encode_json($data));

    # _download_whitelist is an internal collaborator here: stub it so this test
    # stays focused on new()'s source selection, not on HTTP.
    my $mock = Test::MockModule->new('LTP::WhiteList');
    my @dl_args;
    $mock->redefine(_download_whitelist => sub { push @dl_args, @_; return $file; });

    _reset_source_vars();
    set_var('LTP_KNOWN_ISSUES', 'http://example.com/whitelist.json');

    my $whitelist = LTP::WhiteList->new();
    is_deeply(\@dl_args, ['http://example.com/whitelist.json'], '_download_whitelist called with URL from LTP_KNOWN_ISSUES');
    is_deeply($whitelist->{whitelist}, $data, 'whitelist loaded from the downloaded file');
};

subtest '[WhiteList->new] explicit url argument downloads and ignores local var' => sub {
    # URL passed directly to new() takes the download path and
    # suppresses the LTP_KNOWN_ISSUES_LOCAL source entirely.
    my $data = {suite_c => {test_z => [{product => '^sle:11', message => 'from-arg'}]}};
    my $dir = File::Temp->newdir();
    my $file = "$dir/from_arg.json";
    path($file)->spew(encode_json($data));

    my $mock = Test::MockModule->new('LTP::WhiteList');
    my @dl_args;
    $mock->redefine(_download_whitelist => sub { push @dl_args, @_; return $file; });

    _reset_source_vars();
    set_var('LTP_KNOWN_ISSUES_LOCAL', '/should/be/ignored.json');

    my $whitelist = LTP::WhiteList->new('http://arg.example.com/whitelist.json');
    is_deeply(\@dl_args, ['http://arg.example.com/whitelist.json'], 'download uses the explicit url argument');
    is_deeply($whitelist->{whitelist}, $data, 'whitelist from arg-url download; LTP_KNOWN_ISSUES_LOCAL ignored');
};

subtest '[WhiteList->new] local file takes precedence over URL' => sub {
    # When both a local file and a URL are configured, the local file
    # wins and no download is attempted.
    my $data = {suite_local => {test_local => [{product => '^sle:15', message => 'local-wins'}]}};
    my $dir = File::Temp->newdir();
    my $file = "$dir/local.json";
    path($file)->spew(encode_json($data));

    my $mock = Test::MockModule->new('LTP::WhiteList');
    my $dl_called = 0;
    $mock->redefine(_download_whitelist => sub { $dl_called++; return undef; });

    _reset_source_vars();
    set_var('LTP_KNOWN_ISSUES_LOCAL', $file);
    set_var('LTP_KNOWN_ISSUES', 'http://example.com/whitelist.json');

    my $whitelist = LTP::WhiteList->new();
    is($dl_called, 0, '_download_whitelist not called when a local file is present');
    is_deeply($whitelist->{whitelist}, $data, 'local file used, URL ignored');
};

subtest '[WhiteList->new] _download_whitelist fetches, caches, and softfails on error' => sub {
    # A successful GET is saved locally and its path returned & cached
    # (repeat calls for the same URL do not re-fetch); an unsuccessful GET records
    # a softfail and returns undef.
    # This is the single test that really exercises the download path. Only the
    # genuine external boundaries are mocked (HTTP transport + testapi/File::Copy
    # I/O helpers); the private logic runs for real. chdir into a temp dir so the
    # mkdir('ulogs') side effect leaves nothing behind.
    my $dir = File::Temp->newdir();
    my $orig_cwd = Cwd::getcwd();
    chdir $dir or die "chdir failed: $!";

    my $body = encode_json({suite_dl => {}});
    my $success = 1;
    my $get_calls = 0;

    my $ua_mock = Test::MockModule->new('Mojo::UserAgent');
    $ua_mock->redefine(get => sub {
            $get_calls++;
            my $res = Test::MockObject->new();
            $res->mock('is_success', sub { $success });
            $res->mock('body', sub { $body });
            $res->mock('message', sub { 'download failed' });
            my $tx = Test::MockObject->new();
            $tx->mock('result', sub { $res });
            return $tx;
    });

    my @info;
    my $mock = Test::MockModule->new('LTP::WhiteList');
    $mock->redefine(hashed_string => sub { "$dir/hashed_$_[0]" });
    $mock->redefine(save_tmp_file => sub { path("$dir/hashed_$_[0]")->spew($_[1]); });
    $mock->redefine(copy => sub { 1 });
    $mock->redefine(record_info => sub { push @info, [@_]; });

    my $url = 'http://example.com/dir/whitelist.json';
    my $lfile = LTP::WhiteList::_download_whitelist($url);
    is($lfile, "$dir/hashed_whitelist.json", 'returns hashed local file path on success');
    is($get_calls, 1, 'HTTP GET performed once');
    is(path($lfile)->slurp, $body, 'response body saved to the local file');

    # Second call for the same URL must hit the cache and not fetch again.
    my $cached = LTP::WhiteList::_download_whitelist($url);
    is($cached, $lfile, 'cached path returned on second call');
    is($get_calls, 1, 'no additional HTTP GET on cache hit');

    # A non-success response records a softfail and returns undef.
    $success = 0;
    my $fail_url = 'http://example.com/dir/missing.json';
    my $res = LTP::WhiteList::_download_whitelist($fail_url);
    is($res, undef, 'undef returned when download is not successful');
    is($get_calls, 2, 'HTTP GET attempted for the failing URL');
    is(scalar @info, 1, 'record_info called once for the failed download');
    my (undef, undef, %info_opts) = @{$info[0] // []};
    is($info_opts{result}, 'softfail', 'download failure recorded as softfail') if @info;

    chdir $orig_cwd or die "chdir back failed: $!";
};

subtest '[override_known_failures] retval matching' => sub {
    # A failure is overridden only when every non-zero return value has
    # a matching whitelist entry; zero return values are ignored (unless all are
    # zero, which can match a retval '^0$' entry), and the matched entry's message
    # is used for the softfail.
    my $whitelist = bless({whitelist => {
                testsuite_01 => {
                    test_01 => [
                        {
                            product => '^sle:15',
                            retval => '^2$',
                            message => 'overwrite result 2'
                        },
                        {
                            product => '^sle:12',
                            message => 'overwrite for product sle:12',
                            skip => 1
                        },
                        {
                            product => '^sle:11',
                            message => 'overwrite ZERO result',
                            retval => '^0$'
                        },
                        {
                            product => '^sle:11',
                            message => 'overwrite TWO result',
                            retval => '^2$'
                        }
                    ],
                }
    }}, 'LTP::WhiteList');

    my $testmod = _mock_testmod();

    my $env = {product => 'sle:15', retval => 0};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 0, "Check override_known_failures doesn't override");

    $env = {product => 'sle:15', retval => 2};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures single retval");

    $env = {product => 'sle:15', retval => [0, 2]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures retval array");

    $env = {product => 'sle:15', retval => [0, 2, 3]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 0, "Check override_known_failures don't override on new error");


    $env = {product => 'sle:12', retval => 0};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override with retval=0");

    $env = {product => 'sle:12', retval => [0]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override with retval=0");

    $env = {product => 'sle:12', retval => 1};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override");

    $env = {product => 'sle:12', retval => [1]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check override_known_failures override");


    $testmod->{soft_msg} = undef;
    $env = {product => 'sle:11', retval => 0};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check for zero result");
    like($testmod->{soft_msg}, qr/ZERO/, 'Check softrecord_message contains correct entry message ZERO');

    $testmod->{soft_msg} = undef;
    $env = {product => 'sle:11', retval => [0, 0, 0]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Check for zero result, if all are zero");
    like($testmod->{soft_msg}, qr/ZERO/, 'Check softrecord_message contains correct entry message ZERO');

    delete $testmod->{result};
    $testmod->{soft_msg} = undef;
    $env = {product => 'sle:11', retval => [0, 0, 2, 0]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 1, "Ignore zero and softfail");
    like($testmod->{soft_msg}, qr/TWO/, 'Check softrecord_message contains correct entry message TWO');
    is($testmod->{result}, 'softfail', 'Result was patched to `softfail`');

    $env = {product => 'sle:11', retval => [0, 0, 1, 0]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 0, "Ignore zero and fail");

    $env = {product => 'sle:11', retval => [0, 2, 1, 0]};
    is($whitelist->override_known_failures($testmod, $env, 'testsuite_01', 'test_01'), 0, "Ignore zero and fail [2]");
};

subtest '[override_known_failures] keep_fail records fail instead of softfail' => sub {
    # A matching entry with keep_fail records a 'fail' resultfile and
    # does not downgrade the result to softfail.
    my $whitelist = bless({whitelist => {
                suite => {test => [{product => '^sle:15', retval => '^1$', keep_fail => 1, message => 'stays fail'}]}
    }}, 'LTP::WhiteList');

    my $testmod = _mock_testmod();
    my $ret = $whitelist->override_known_failures($testmod, {product => 'sle:15', retval => 1}, 'suite', 'test');

    is($ret, 1, 'known failure is handled');
    is($testmod->{result}, 'not_set', 'keep_fail does not downgrade to softfail');
    is(scalar @{$testmod->{resultfiles}}, 1, 'a resultfile was recorded');
    is($testmod->{resultfiles}[0]{title}, 'Known', 'recorded with title Known');
    is($testmod->{resultfiles}[0]{result}, 'fail', 'recorded as fail');
};

subtest '[override_known_failures] bugzilla open vs closed vs error' => sub {
    # An entry tied to a bugzilla bug overrides only while the bug is
    # open; a resolved/verified bug or a failed status query keeps the failure and
    # records the corresponding resultfile.
    my $whitelist = bless({whitelist => {
                suite => {test => [{product => '^sle:15', retval => '^1$', bugzilla => 12345, message => 'bug ref'}]}
    }}, 'LTP::WhiteList');

    my $mock = Test::MockModule->new('LTP::WhiteList');

    # Open bug => override to softfail.
    $mock->redefine(bugzilla_buginfo => sub { {bug_status => 'NEW'} });
    my $testmod = _mock_testmod();
    is($whitelist->override_known_failures($testmod, {product => 'sle:15', retval => 1}, 'suite', 'test'), 1, 'open bug is overridden');
    is($testmod->{result}, 'softfail', 'open bug downgraded to softfail');

    # Resolved bug => stale whitelist entry, keep failing.
    $mock->redefine(bugzilla_buginfo => sub { {bug_status => 'RESOLVED'} });
    $testmod = _mock_testmod();
    ok(!$whitelist->override_known_failures($testmod, {product => 'sle:15', retval => 1}, 'suite', 'test'), 'resolved bug is not overridden');
    is($testmod->{resultfiles}[0]{title}, 'Bug closed', 'resolved bug recorded as Bug closed');

    # Bugzilla query error => keep failing.
    $mock->redefine(bugzilla_buginfo => sub { undef });
    $testmod = _mock_testmod();
    ok(!$whitelist->override_known_failures($testmod, {product => 'sle:15', retval => 1}, 'suite', 'test'), 'bugzilla error is not overridden');
    is($testmod->{resultfiles}[0]{title}, 'Bugzilla error', 'bugzilla error recorded as Bugzilla error');
};

done_testing;
