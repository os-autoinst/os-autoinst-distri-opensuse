requires 'Net::Telnet';
requires 'File::Basename';
requires 'Data::Dumper';
requires 'XML::LibXML';
requires 'XML::Writer';
requires 'XML::Simple';
requires 'IO::File';
requires 'List::Util';

on 'test' => sub {
  requires 'Code::DRY';
};
