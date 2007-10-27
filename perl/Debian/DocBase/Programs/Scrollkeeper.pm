# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Scrollkeeper.pm 87 2007-10-27 21:17:08Z robert $
#

package Debian::DocBase::Programs::Scrollkeeper;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(RegisterScrollkeeper);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use File::Basename qw(dirname);


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

our %mapping = (undef=>undef);


sub RegisterScrollkeeper(@) { # {{{
  my @documents = @_;
  my $do_update = 0;

  # read in doc-base -> scrollkeeper mappings unless already read
  %mapping = read_map($scrollkeeper_map_file);

  foreach my $doc (@documents) {
    my $format_data;

    my $old_omf_file = $doc->get_status('Scrollkeeper-omf-file');
    my $omf_serial_id = undef; 
    my $new_omf_file = undef;
    my $omf_category = map_docbase_to_scrollkeeper($doc->section());

    if (defined $omf_category) {
      for my $omf_format (@omf_formats) {
        $format_data = $doc->format($omf_format);
        next unless defined $format_data;

        my $file = defined $$format_data{'index'} ? $$format_data{'index'} : $$format_data{'files'};
        next unless -f $file;

        $omf_serial_id = $doc->get_status('Scrollkeeper-sid');
        chomp ($omf_serial_id = `$scrollkeeper_gen_seriesid`) unless defined $omf_serial_id;
        $new_omf_file = write_omf_file($doc, $file,$omf_format,$omf_category, $omf_serial_id);
        $do_update    = 1;
        last; # register only the first format found
      }
    }

    # remove old omf file
    # FIXME: $old_omf_file might be the same file as $new_omf_file even if $old_omf_file ne $new_omf_file
    if (defined $old_omf_file and (not defined $new_omf_file or $old_omf_file ne $new_omf_file)) {
      remove_omf_file($old_omf_file);
      $do_update = 1;
    }

    $doc->set_status( 'Scrollkeeper-omf-file' => $new_omf_file, 
                      'Scrollkeeper-sid'      =>  $omf_serial_id);
  }


  Execute($scrollkeeper_update, '-q') if ($do_update and $opt_update_menus);
} # }}}




# arguments: filename
# reads a file that looks like:
# foo: bar
# returns: hash of lv -> rv
sub read_map($) { # {{{
  my ($file) = @_;
  my %map;
  open (MAP, "<$file") or croak( "Could not open $file: $!");
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
sub map_docbase_to_scrollkeeper($) { # {{{
  return $mapping{lc($_[0])};
} # }}}

sub remove_omf_file($) { # {{{
  my $omf_file = shift;
  my $omf_dir = dirname($omf_file);
  Debug("Removing scrollkeeper OMF file `$omf_file'");
  unlink($omf_file) or return Error ("$omf_file: could not delete file: $!");

  #check to see if the directory is now empty. if so, kill it.
  if (opendir(DIR, $omf_dir)) {
    if (defined grep { $_ !~ /^\.\.?$/ } readdir DIR) {
      rmdir($omf_dir) or Error ("$omf_dir: could not delete directory: $!");
    }
    closedir DIR;
  }
} # }}}

sub _HTMLEncode($) { # {{{
  my $text = shift;
  $text =~ s/&/(and)/g;     # scrollkeeper doesn't handle &amp; correctly, see Bug#429847
  return HTMLEncode($text);
} # }}}

sub write_omf_file($$$$) { # {{{
  my ($doc, $file, $format, $category, $serial_id) = @_;
  my $docid = $doc->document_id();
  my $omf_file = "$omf_locations/$docid/$docid-C.omf";
  my $date;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
  $year += 1900;
  if ($mday <10) {$mday = "0$mday";}
  if ($mon <10) {$mon = "0$mon";}
  $date = "$year-$mon-$mday";


  if (! -d "$omf_locations/$docid") {
    mkdir("$omf_locations/$docid") or &croak ("can't create dir $omf_locations/$docid: $!");
  }

  &Debug("Writing scrollkeeper OMF file `$omf_file'");
  open(OMF, ">$omf_file")
    or return &croak("$omf_file: cannot open OMF file for writing: $!");

  #now for the boiler plate XML stuff
  print OMF "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  print OMF "<!DOCTYPE omf PUBLIC \"-//OMF//DTD Scrollkeeper OMF Variant V1.0//EN\" \"http://scrollkeeper.sourceforge.net/dtds/scrollkeeper-omf-1.0/scrollkeeper-omf.dtd\">\n";
  print OMF "<omf>\n\t<resource>\n";

  #now for the dynamic stuff
  print OMF "\t\t<creator>".&_HTMLEncode($doc->author())."</creator>\n";
  print OMF "\t\t<title>".&_HTMLEncode($doc->title())."</title>\n";
  print OMF "\t\t<date>$date</date>\n";
  print OMF "\t\t<subject category=\"$category\"/>\n";
  print OMF "\t\t<description>".&_HTMLEncode($doc->abstract())."</description>\n";
  print OMF "\t\t<format $omf_mime_types{$format} />\n";
  print OMF "\t\t<identifier url=\"$file\"/>\n";
  print OMF "\t\t<language code=\"C\"/>\n";
  print OMF "\t\t<relation seriesid=\"$serial_id\"/>\n";

  #finish the boiler plate
  print OMF "\t</resource>\n</omf>\n";
  close(OMF) or die "$omf_file: cannot close OMF file: $!";

  return $omf_file;
} # }}}


1;
