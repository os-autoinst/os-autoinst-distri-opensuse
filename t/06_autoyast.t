use strict;
use warnings;

use File::Basename;
use Test::More;
use Test::MockModule;
use Test::Warnings;
use YAML::PP;

use autoyast;


subtest 'ns' => sub {
    is autoyast::ns('node'), 'ns:node';
};

subtest 'has_properties' => sub {
    ok !autoyast::has_properties('scalar'), 'Test if node is scalar';
    ok !autoyast::has_properties(undef), 'Test if node is undef';
    ok autoyast::has_properties({_t => 'boolean'}), 'Test if type property _t is detected';
    ok autoyast::has_properties({__text => 'value'}), 'Test if text value property _text is detected';
    ok autoyast::has_properties({__count => 2}), 'Test if number of children node value property __count is detected';
    ok autoyast::has_properties({_descendant => 'any'}), 'Test if look for descendant node value property _descendant is detected';
    ok autoyast::has_properties({_t => 'boolean', __text => 'true', __count => 2}), 'Test if multiple properties are defined';
};

subtest 'close_predicate' => sub {
    is autoyast::close_predicate('/book/title'), '[/book/title]', 'Test single predicate';
    is autoyast::close_predicate(('/title/lotr', '/author/tolkien')), '[/title/lotr and /author/tolkien]', 'Test multiple predicates';
};

subtest 'get_descendant' => sub {
    is autoyast::get_descendant({_descendant => 'any'}), './/', 'Test when _descendant property is defined';
    is autoyast::get_descendant({_descendant => undef}), '', 'Test when _descendant property is not defined';
    is autoyast::get_descendant('scalar'), '', 'Test when _descendant property is scalar';
};

subtest 'get_traversable' => sub {
    is autoyast::get_traversable([]), undef, 'Expect undef if is an array';
    is autoyast::get_traversable(0), undef, 'Expect undef if is a scalar';
    is autoyast::get_traversable({root => {node => 'value'}}), 'root', 'Expect root if child is a hash';
};

subtest 'is_processable' => sub {
    ok autoyast::is_processable({__text => 'true'}), 'Test key pair node with property';
    ok autoyast::is_processable('scalar'), 'Test scalar';
    ok !autoyast::is_processable({name => 'test'}), 'Test simple key pair node';
    ok !autoyast::is_processable([{__text => '1'}, {__text => '2'}]), 'Test array of hashes';
};

subtest 'create_xpath_predicate' => sub {
    is autoyast::create_xpath_predicate('test'), "[text()='test']", 'Test simple text';
    is autoyast::create_xpath_predicate(''), '[not(text())]', 'Test empty text search';
    is autoyast::create_xpath_predicate({_t => 'boolean', __text => 'false'}), '[text()=\'false\' and @t=\'boolean\']', 'Test node with _t and __text properties';
    is autoyast::create_xpath_predicate({__count => 2, child => [1, 2]}), '[count(ns:child)=2]', 'Test node with count defined for the child node';
};

subtest 'generate_expressions' => sub {
    my @rez = autoyast::generate_expressions({node => 'value'});
    is_deeply \@rez, ["/ns:node[text()='value']"];
    @rez = autoyast::generate_expressions([{name => "Andy"}, {name => 'Mary'}]);
    is_deeply \@rez, ["[ns:name[text()='Andy']]", "[ns:name[text()='Mary']]"];
    @rez = autoyast::generate_expressions({root => {__text => 'true', _t => 'boolean'}});
    is_deeply \@rez, ['/ns:root[text()=\'true\' and @t=\'boolean\']'];
    @rez = autoyast::generate_expressions({names => [{name => "Andy"}, {name => 'Mary'}]});
    is_deeply \@rez, ["/ns:names[ns:name[text()='Andy']]", "/ns:names[ns:name[text()='Mary']]"];
    @rez = autoyast::generate_expressions({root => {__count => 2, _t => 'list', child => ['item1', 'item2']}});
    is_deeply \@rez, ['/ns:root[@t=\'list\' and count(ns:child)=2]', "/ns:root/ns:child[text()='item1']", "/ns:root/ns:child[text()='item2']"];
};

subtest 'validate_autoyast_profile' => sub {
    # Load autoyast profile xml
    my $input_xml = dirname(__FILE__) . '/data/autoyast_profile.xml';
    open my $fh, '<', $input_xml or die "error opening $input_xml: $!";
    my $xml = do { local $/; <$fh> };
    # Load expectations being set in yaml
    my $ypp = YAML::PP->new(schema => ['Core', 'Merge']);
    my $yaml = $ypp->load_file(dirname(__FILE__) . '/data/autoyast_profile.yaml');
    # Mock methods which use testapi
    my $autoyast_mock = Test::MockModule->new('autoyast');
    # Mock method which returns xml from the SUT
    $autoyast_mock->redefine("init_autoyast_profile", sub { return $xml; });
    # Mock testapi call inside of validate_autoyast_profile
    $autoyast_mock->redefine("record_info", sub { my ($title, $output) = @_; print("$title\n$output"); });
    # Test that profile validates
    eval { autoyast::validate_autoyast_profile($yaml) };
    is $@, '', 'autoyast validation succeeded';
};

done_testing;
