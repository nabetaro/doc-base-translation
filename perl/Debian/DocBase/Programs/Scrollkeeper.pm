# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Scrollkeeper.pm 59 2007-04-14 09:12:02Z robert $
#

package Debian::DocBase::Programs::Scrollkeeper;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(register_scrollkeeper update_scrollkeeper remove_omf_files write_omf_file);

use Debian::DocBase::Common;
use Debian::DocBase::Utils;


our $omf_locations = "/var/lib/doc-base/omf";


our $scrollkeeper_update       = "/usr/bin/scrollkeeper-update";
our $scrollkeeper_gen_seriesid = "/usr/bin/scrollkeeper-gen-seriesid";
our $scrollkeeper_map_file     = "/usr/share/doc-base/data/scrollkeeper.map";


our %omf_mime_types = ( 
                            'html'        => 'mime="text/html"',
                            'text'        => 'mime="text/plain"',
                            'pdf'         => 'mime="application/pdf"',
                            'postscript'  => 'mime="application/postscript"',
                            'dvi'         => 'mime="application/x-dvi"',
                            'docbook-xml' => 'mime="text/xml" dtd="-//OASIS//DTD DocBook XML V4.1.2//EN"'
                  );

our @omf_formats = (
                        'html',
                        'docbook-xml',
                        'pdf',
                        'postscript',
                        'dvi',
                        'text' 
                 );

our %mapping;
    

# arguments: filename
# reads a file that looks like:
# foo: bar
# returns: hash of lv -> rv
sub read_map { # {{{
  my ($file) = @_;
  my %map;
  open (MAP, "<$file") or die "Could not open $file: $!";
  while(<MAP>) {
          chomp;
          my ($lv,$rv) = split(/: /);
          $map{lc($lv)} = $rv;
  }
  close(MAP);
  return %map;
} # }}}

# arguments: doc-base section
# returns: scrollkeeper category
sub map_docbase_to_scrollkeeper { # {{{
  return $mapping{lc($_[0])};
} # }}}
  



sub remove_omf_files { # {{{
  my $omf_file = $doc->status('Scrollkeeper-omf-file');
  my $omf_dir = dirname($omf_file);
  unlink($omf_file) or die "$omf_file: could not delete file: $!";

  #check to see if the directory is now empty. if so, kill it.
  opendir(DIR, $omf_dir);
  if (readdir DIR == 0) {
    rmdir($omf_dir) or die "$omf_dir: could not delete directory: $!";
  }
  closedir DIR;
} # }}}

sub register_scrollkeeper { # {{{
  my $document = $doc->document_id();
  my $format_data;
  for my $omf_format (@omf_formats) {
    $format_data = $doc->format($omf_format);
      next unless defined $format_data;

      my $file = defined $$format_data{'index'} ? $$format_data{'index'} : $$format_data{'files'};
      next unless -f $file;
      write_omf_file($file,$omf_format);

      #set status
      $doc->status('Registered-to-scrollkeeper',  1);
      update_scrollkeeper();

      return; # only register the first format we found
      
  }
} # }}}

sub update_scrollkeeper { # {{{
  if ($do_dwww_update && -x $scrollkeeper_update) {
    print "Executing $scrollkeeper_update\n" if $verbose;
    if (system("$scrollkeeper_update -q >/dev/null 2>&1") != 0) {
      warn "warning: error occurred during execution of $scrollkeeper_update -q\n";
    }
  }
} # }}}

sub write_omf_file { # {{{
  my ($file, $format) = @_;
  my $document = $doc->document_id();
  my $omf_file = "$omf_locations/$document/$document-C.omf";
  my $date;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  if ($mday <10) {$mday = "0$mday";}
  if ($mon <10) {$mon = "0$mon";}
  $date = "$year-$mon-$mday";

  chomp(my $serial_id = `$scrollkeeper_gen_seriesid`);

  if (! -d "$omf_locations/$document") {
    mkdir("$omf_locations/$document") or die "can't create dir $omf_locations/$document: $!";
  }

  open(OMF, ">$omf_file")
    or die "$omf_file: cannot open OMF file for writing: $!";
  
  #now for the boiler plate XML stuff
  print OMF "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print OMF "<!DOCTYPE omf PUBLIC \"-//OMF//DTD Scrollkeeper OMF Variant V1.0//EN\" \"http://scrollkeeper.sourceforge.net/dtds/scrollkeeper-omf-1.0/scrollkeeper-omf.dtd\">\n";
  print OMF "<omf>\n\t<resource>\n";

  #now for the dynamic stuff
  print OMF "\t\t<creator>".&html_encode($doc->author(), 1)."</creator>\n";
  print OMF "\t\t<title>".&html_encode($doc->title(), 1)."</title>\n";
  print OMF "\t\t<date>$date</date>\n";
  print OMF "\t\t<subject category=\"".map_docbase_to_scrollkeeper($doc->section())."\"/>\n";
  print OMF "\t\t<description>".&html_encode($doc->abstract(), 1)."</description>\n";
  print OMF "\t\t<format $omf_mime_types{$format} />\n";
  print OMF "\t\t<identifier url=\"$file\"/>\n";
  print OMF "\t\t<language code=\"C\"/>\n";
  print OMF "\t\t<relation seriesid=\"$serial_id\"/>\n";

  #finish the boiler plate
  print OMF "\t</resource>\n</omf>\n";
  close(OMF) or die "$omf_file: cannot close OMF file: $!";
  $doc->status('Scrollkeeper-omf-file', $omf_file);
} # }}}


# read in doc-base -> scrollkeeper mappings
%mapping = read_map($scrollkeeper_map_file);
1;
