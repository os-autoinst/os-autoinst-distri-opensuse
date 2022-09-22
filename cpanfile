# If you update this file you must also:
# - run ./tools/update_spec
# - add the updated spec to your commit
# - the rest should happen automatically
# - os-autoinst-distri-opensuse-deps in devel:openQA will get updated immediately
# - os-autoinst-distri-opensuse-deps in Factory will get updated with next openQA submit

requires 'Carp';
requires 'Code::DRY';
requires 'Config::Tiny';
requires 'Class::Accessor::Fast';
requires 'Cwd';
requires 'Data::Dump';
requires 'Data::Dumper';
requires 'DateTime';
requires 'Digest::file';
requires 'Exporter';
requires 'File::Basename';
requires 'File::Copy';
requires 'File::Find';
requires 'File::Path';
requires 'File::Temp';
requires 'IO::File';
requires 'IO::Socket::INET';
requires 'LWP::Simple';
requires 'List::MoreUtils';
requires 'List::Util';
requires 'Mojo::Base';
requires 'Mojo::File';
requires 'Mojo::JSON';
requires 'Mojo::UserAgent';
requires 'Mojo::Util';
requires 'NetAddr::IP';
requires 'Net::IP';
requires 'POSIX';
requires 'Perl::Critic::Freenode';
requires 'Regexp::Common';
requires 'Selenium::Chrome';
requires 'Selenium::Remote::Driver';
requires 'Selenium::Remote::WDKeys';
requires 'Selenium::Waiter';
requires 'Storable';
requires 'Term::ANSIColor', '2.01';
requires 'Test::Assert';
requires 'Tie::IxHash';
requires 'Time::HiRes';
requires 'XML::LibXML';
requires 'XML::Simple';
requires 'XML::Writer';
requires 'YAML::PP';
requires 'constant';
requires 'parent';
requires 'strict';
requires 'utf8';
requires 'version';
requires 'warnings';


on 'test' => sub {
  requires 'Code::DRY';
  requires 'Test::Exception';
  requires 'Test::Fatal';
  requires 'Test::MockModule';
  requires 'Test::MockObject';
  requires 'Test::More', '0.88';
  requires 'Test::Warnings';
  requires 'JSON::Validator';
};
