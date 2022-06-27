=head1 xml_utils.pm

Library for parsing xml files

=cut
# SUSE's openQA tests
#
# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Library for parsing xml files
# Maintainer: Rodion Iafarov <riafarov@suse.com>
use strict;
use warnings;
use XML::LibXML;
use Exporter 'import';

=head2 get_xpc

 get_xpc($string);

Returns XPathContext for the dom build using the string, which contains xml.

=cut

our @EXPORT = qw(get_xpc verify_option find_nodes);

sub get_xpc {
    my ($string) = @_;
    my $dom = XML::LibXML->load_xml(string => $string);
    # Init xml namespace
    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs('ns', 'http://www.suse.com/1.0/yast2ns');

    return $xpc;
}

=head2 verify_option

 verify_option(%args);

Verifies that node by given XPath is unique and has expected value. C<%args> is a hash which must have following keys:

=over 

=item * C<xpc> - XPathContext object for the parsed xml,

=item * C<xpath> - XPath to the node which value we want to check

=item * C<expected_val> - expected value for the node

=back

=cut

sub verify_option {
    my (%args) = @_;

    my @nodes = find_nodes(%args);
    ## Verify that there is node found by xpath and it's single one
    if (scalar @nodes != 1) {
        return "Generated autoinst.xml contains unexpected number of nodes for xpath: $args{xpath}. Found: " . scalar @nodes . ", expected: 1.";
    }
    if ($nodes[0]->to_literal ne $args{expected_val}) {
        return "Unexpected value for xpath $args{xpath}. Expected: '$args{expected_val}', got: '$nodes[0]'";
    }

    return '';

}

=head2 find_nodes

 find_nodes(%args);

Finds all the nodes by xpath and returns the nodes as array.

C<xpc> - XPathContext object for the parsed xml,
C<xpath> - XPath to the target node

=cut

sub find_nodes {
    my (%args) = @_;
    my $nodeset = $args{xpc}->findnodes($args{xpath});
    for my $node ($nodeset->get_nodelist) {
        print $node->to_literal;
    }
    return $nodeset->get_nodelist;
}

1;
