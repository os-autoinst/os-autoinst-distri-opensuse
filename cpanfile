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


on 'test' => sub {
  requires 'Code::DRY';
  requires 'Test::Exception';
  requires 'Test::Warnings';
  requires 'Test::YAML::Valid';
};
