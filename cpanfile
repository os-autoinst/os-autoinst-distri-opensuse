# If you update this file you must also:
# - run ./tools/update_spec
# - add the updated spec to your commit
# - the rest should happen automatically
# - os-autoinst-distri-opensuse-deps in devel:openQA will get updated immediately
# - os-autoinst-distri-opensuse-deps in Factory will get updated with next openQA submit

requires 'Config::Tiny';
requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'IO::Socket::INET';
requires 'List::Util';
requires 'LWP::Simple';
requires 'File::Copy';
requires 'File::Path';
requires 'Selenium::Remote::Driver';
requires 'Selenium::Chrome';
requires 'Selenium::Waiter';
requires 'Selenium::Remote::WDKeys';
requires 'Digest::file';
requires 'YAML::Tiny';
requires 'Test::Assert';
requires 'Perl::Critic::Freenode';


on 'test' => sub {
  requires 'Code::DRY';
  requires 'Test::Exception';
  requires 'Test::Warnings';
  requires 'Test::YAML::Valid';
};
