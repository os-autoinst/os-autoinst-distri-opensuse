requires 'Net::Telnet';
requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'List::Util';
requires 'LWP::Simple';
requires 'File::Copy';
requires 'File::Path';

on 'test' => sub {
  requires 'Code::DRY';
};
