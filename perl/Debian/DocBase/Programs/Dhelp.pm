# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 67 2007-05-05 07:19:44Z robert $
#

package Debian::DocBase::Programs::Dhelp;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(RegisterDhelp);

use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use File::Basename;

my $dhelp_parse = "/usr/sbin/dhelp_parse";
my $usd_dir    = "/usr/share/doc";

# Registering documents to dhelp
sub RegisterDhelp {  # {{{
  my @documents = @_;
  

  foreach my $doc (@documents) {
    &register_one_dhelp_document($doc);
  }    

} # }}}


sub register_one_dhelp_document($) { # {{{
  my $doc = shift;
  my @new_dhelp_data = ();
  my $docid = $doc->document_id();

  my $new_dhelp_file = undef;

  my $format_data = $doc->format('html');
  if (defined $format_data) {
    my $file = $$format_data{'index'};
    $file =~ s/\/+/\//;
    # ensure the documentation is in an area dhelp can deal with
    if ( $file !~ /^$usd_dir\/([^\/]+)\/(.+)$/o ) {
      &Warn ("register_dhelp: skipping $file
              because dhelp only knows about /usr/share/doc");
  } else {

    my $dir=$1;
    my $filename=$2;

    $new_dhelp_file = "$usd_dir/$dir/.dhelp";
    # last minute data munging,
    # FIXME when we finally get a real document hierarchy
    my $dhelp_section;
    ( $dhelp_section = $doc->section()) =~ tr/A-Z/a-z/;
    $dhelp_section =~ s|^apps/||;
    $dhelp_section =~ s/^(howto|faq)$/\U$&\E/;
    # now push our data onto the array (undefs are ok)
    (my $documents =  $$format_data{'files'}) =~ s/\B\Q$usd_dir\E\/\Q$dir\E\///g;
    push(@new_dhelp_data, &generate_dhelp_item({
       '1_x-doc-base-id' => $docid, 
       '2_directory'     => &HTMLEncode($dhelp_section, 1),
       '3_linkname'      => $doc->title(),
       '4_filename'      => $filename,
       '5_documents'     => $documents,
       '6_description'   => &HTMLEncodeDescription($doc->abstract(), 1)
       })
     );
    }    
  }   


## update the files
  my @dhelp_data = ();
  my $old_dhelp_file = $doc->get_status('Dhelp-file');
  my @old_dhelp_data = ();

  my $exists_old_dhelp_file = (defined $old_dhelp_file and -f $old_dhelp_file);
  my $exists_new_dhelp_file = (defined $new_dhelp_file and -f $new_dhelp_file);
  my $same_files  = (defined $old_dhelp_file and defined $new_dhelp_file and
                    $old_dhelp_file eq $new_dhelp_file);

  read_dhelp_file($docid, $old_dhelp_file, \@dhelp_data, \@old_dhelp_data) if $exists_old_dhelp_file;

  if (not $same_files) {
    write_dhelp_file($old_dhelp_file, \@dhelp_data) if $exists_old_dhelp_file 
                                                     and $#old_dhelp_data > -1;

    @dhelp_data = ();
    read_dhelp_file($docid, $new_dhelp_file, \@dhelp_data, \@old_dhelp_data) if $exists_new_dhelp_file 
  }

  if (defined $new_dhelp_file) {
    push(@dhelp_data, @new_dhelp_data);

    if (($#old_dhelp_data != $#new_dhelp_data)
        or defined grep {$old_dhelp_data[$_] ne $new_dhelp_data[$_]} (0..$#new_dhelp_data)) {
      &Debug("`$new_dhelp_file' not changed, skipping its registration");
    } else {
      write_dhelp_file($new_dhelp_file, \@dhelp_data);
   }       

    @new_dhelp_data = ();
  }  

  $doc->set_status('Dhelp-file', $new_dhelp_file);

} # }}}

# read an existing dhelp file
# returns items from our document into @$our_dhelp_data
# returns othher items in @other_dhelp_data
sub read_dhelp_file($$$) { # {{{
  my ($docid, $dhelp_file, $other_dhelp_data, $our_dhelp_data) = @_;
  &Debug("Reading dhelp file: $dhelp_file");
  @$other_dhelp_data = ();
  @$our_dhelp_data  = ();

  open(FH, "<$dhelp_file") or return &Warn ("can't open file '$dhelp_file': $!\n");
  $_ = join('', <FH>);    # slurp in the file

# <x-doc-base-id> may be anywhere in <item>
#  while ( m{(<item>\s*  # item defines a block, required
#        (?:  # alternate everything group
#          (?:<x-doc-base-id>([^<\s]+)\s*)  # x-doc-base-id, optional
#        |
#          (?:<.*?)   # not interested in other tags, non greedy
#        )*  # end alternating
#        \s*</item> # spaces ok, item ends
#        )}gscx )
#
#  simpler version depending on <x-doc-base-id> being the first element in <item>
  while ( m{(<item>\s*   # item defines a block, required
          (?:<x-doc-base-id>([^<\s]+)\s*)?   # x-doc-base-id, optional
          .*?         # non greedy
        \s*</item>
        )}gscx )
    {
    # $1 is everything beetwen <item> and </item>
    # $2 is value of the <x-doc-base-id> tag
      if (defined $2 and $2 eq $docid) {
        push (@$our_dhelp_data, $1);
      } else {
        push (@$other_dhelp_data, $1);
      }
    }

  close FH;
} # }}}


sub generate_dhelp_item { # {{{
  my $data = shift;
  my $result = "";

  $result .= "<item>\n";
  foreach my $tmpfield (sort keys %$data) {
      (my $field = $tmpfield) =~ s/^\d+_//;
      my $value = $$data{$tmpfield};
      next unless defined $value;
      $value =~ s/^\s+//m;
      $value =~ s/\s+$//m;
      next unless length ($value);

      if ($field eq 'description') {        
        $result .= "<$field>\n$value\n</$field>\n";
      } else {   
        $value =~ s/\n/ /mg;
        $result .= "<$field>$value\n";
     }
  }
  $result .= "</item>";
  return $result;;
} # }}}


sub write_dhelp_file($$) { # {{{
  my $file = shift;
  my $dhelp_data = shift;

  my $dir = &dirname($file);

  &Debug("Writing dhelp file: $file");

  if (-f $file) {
    &Execute($dhelp_parse, '-d', $dir);
    unlink $file or &Warn ("can't unlink $file: $!");
  }

  return 0 if  ($#{$dhelp_data} < 0); # no data to write, the file already deleted

  open (FH, ">$file") or &Warn ("can't open file $file for wirting: $!");
  print FH join("\n\n", @$dhelp_data);
  close FH;

  &Execute($dhelp_parse, '-a', $dir);

  return 1;
} # }}}


1;
