# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Dhelp.pm 61 2007-04-26 20:40:12Z robert $
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
use Carp;

our $usd_dir = "/usr/share/doc";

our $dhelp_parse = "/usr/sbin/dhelp_parse";

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
carp "file = $file";
    # ensure the documentation is in an area dhelp can deal with
    if ( $file !~ /^$usd_dir\/([^\/]+)\/(.+)$/o ) {
      carp "register_dhelp: skipping $file
           because dhelp only knows about /usr/share/doc\n"
            if $verbose;
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
    push(@new_dhelp_data, &generate_dhelp_item({
       '2_directory'     => &html_encode($dhelp_section, 1),
       '1_x-doc-base-id' => $docid, 
       '3_linkname'      => $doc->title(),
       '4_filename'      => $filename,
       '5_documents'     => $$format_data{'files'},
       '6_description'   => &html_encode_description($doc->abstract(), 1)
       })
     );
    }    
  }   


## update the files
  my @dhelp_data = ();
  my $old_dhelp_file = $doc->get_status('Dhelp-file');
  my $exists_old_dhelp_file = (defined $old_dhelp_file and -f $old_dhelp_file);
  my $exists_new_dhelp_file = (defined $new_dhelp_file and -f $new_dhelp_file);
  my $same_files  = (defined $old_dhelp_file and defined $new_dhelp_file and
                    $old_dhelp_file eq $new_dhelp_file);

  read_dhelp_file($docid, $old_dhelp_file, \@dhelp_data) if $exists_old_dhelp_file;

  if (not $same_files) {
    write_dhelp_file($old_dhelp_file, \@dhelp_data) if $exists_old_dhelp_file;

    @dhelp_data = ();
    read_dhelp_file($docid, $new_dhelp_file, \@dhelp_data) if $exists_new_dhelp_file 
  }

  if (defined $new_dhelp_file) {
    push(@dhelp_data, @new_dhelp_data);
    @new_dhelp_data = ();
    write_dhelp_file($new_dhelp_file, \@dhelp_data) if $exists_old_dhelp_file;
  }  

  $doc->set_status('Dhelp-file', $new_dhelp_file);

} # }}}

# read an existing dhelp file ignoring any entries from our document
sub read_dhelp_file($$$) { # {{{
  my ($docid, $dhelp_file, $dhelp_data) = @_;

  open(FH, "<$dhelp_file") or croak "can't open file '$dhelp_file': $!\n";
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
    # add the item unless comes from our document
      push (@$dhelp_data, $1) unless (defined $2 and $2 eq $docid);
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
        $result .= "<$field>$value\n</$field>\n";
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

  if (-f $file) {
    if (-x $dhelp_parse) {
      carp "Executing $dhelp_parse -d $dir\n" if $verbose;
      if (system("$dhelp_parse -d $dir") != 0) {
        carp "warning: error occured during execution of $dhelp_parse -d $dir";
      }
    }
    unlink $file or croak "can't unlink $file: $!"
  }

  return 0 if  ($#{$dhelp_data} < 0); # no data to write, the file already deleted

  open (FH, ">$file") or croak "can't open file $file for wirting: $!";
  print FH join("\n\n", @$dhelp_data);
  close FH;

  if (-x $dhelp_parse) {
    print "Executing $dhelp_parse -a $dir\n" if $verbose;
    if (system("$dhelp_parse -a $dir") != 0) {
      warn "warning: error occured during execution of $dhelp_parse -a $dir";
    }
  } else {
    carp "Skipping $dhelp_parse, program not found\n" if $verbose;
  }

  return 1;
} # }}}


1;
