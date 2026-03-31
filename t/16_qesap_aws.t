use strict;
use warnings;
use Test::More;
use Test::Exception;
use Test::Warnings;
use Test::MockModule;
use Test::Mock::Time;

use List::Util qw(any none);
use Data::Dumper;

use testapi 'set_var';
use sles4sap::qesap::aws;

subtest '[qesap_aws_get_vpc_id]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    my @soft_failure;
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'FISHERMAN'; });
    set_var('PUBLIC_CLOUD_REGION', 'OCEAN');

    qesap_aws_get_vpc_id(resource_group => 'LATTE');

    set_var('PUBLIC_CLOUD_REGION', undef);
    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /aws ec2 describe-instances/ } @calls), 'Base command aws ec2 describe-instances');
    ok((any { /--region OCEAN/ } @calls), 'Region from argument');
    ok((any { /--filters.*Values=LATTE/ } @calls), 'Filter resource_group in tag');
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            push @calls, 'qesap_aws_get_transit_gateway_vpc_attachment';
            my @tga = ({TransitGatewayAttachmentId => '000000000000', State => 'deleted'});
            return \@tga;
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(id => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok $res, 'Delete of transit gateway vpc attachment is fine.';
};

subtest '[qesap_aws_delete_transit_gateway_vpc_attachment] timeout' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    $qesap->redefine(record_info => sub { note(join(' ', 'RECORD_INFO -->', @_)); });
    $qesap->redefine(qesap_aws_get_transit_gateway_vpc_attachment => sub {
            push @calls, 'qesap_aws_get_transit_gateway_vpc_attachment';
            my @tga = ({TransitGatewayAttachmentId => '000000000000', State => 'deleting'});
            return \@tga;
    });
    $qesap->redefine(script_run => sub { push @calls, $_[0]; });

    my $res = qesap_aws_delete_transit_gateway_vpc_attachment(id => 'WHALE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok !$res, 'Delete of transit gateway vpc attachment timeout.';
};

subtest '[qesap_aws_create_config]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);

    my @calls;
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(script_output => sub { push @calls, $_[0]; return 'SOMEOUTPUT' });
    $qesap->redefine(save_tmp_file => sub { });
    $qesap->redefine(autoinst_url => sub { return 'SOMEURL' });

    qesap_aws_create_config(region => 'SOMEWHERE');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    ok((any { /mkdir.*\.aws/ } @calls), 'Create a folder in HOME for the AWS config files');
    ok((any { /curl SOMEURL.*\.aws\/config/ } @calls), 'Place the aws config file in the right place');
};

subtest '[qesap_aws_create_credentials]' => sub {
    my $qesap = Test::MockModule->new('sles4sap::qesap::aws', no_auto => 1);
    my @calls;
    my @contents;

    $qesap->redefine(script_output => sub { return 'eu-central-1'; });
    $qesap->redefine(assert_script_run => sub { push @calls, $_[0]; });
    $qesap->redefine(save_tmp_file => sub { push @contents, @_; });
    $qesap->redefine(autoinst_url => sub { return 'http://10.0.2.2/tests/'; });

    qesap_aws_create_credentials(key => 'THEKEY', secret => 'THESECRET', conf_trgt => 'SOME_CONF.YAML');

    note("\n  C-->  " . join("\n  C-->  ", @calls));
    note("\n  CONTENT-->  " . join("\n  CONTENT-->  ", @contents));
    ok((any { qr|mkdir -p ~/\.aws| } @calls), '.aws directory initialized');
    ok((any { qr|curl.+/files/config.+~/\.aws/config| } @calls), 'AWS Config file downloaded');
    is $contents[0], 'credentials', "AWS credentials file: credentials is the expected value and got $contents[0]";
    like $contents[1], qr/aws_access_key_id/, "Expected aws_access_key_id is in the config file got $contents[1]";
    like $contents[1], qr/aws_secret_access_key/, "Expected aws_secret_access_key is in the config file got $contents[1]";
};


done_testing;
