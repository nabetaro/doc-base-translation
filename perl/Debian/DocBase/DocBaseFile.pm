# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DocBaseFile.pm 49 2007-04-12 19:32:04Z robert $
#

package Debian::DocBase::DocBaseFile;

use Exporter();
#use strict;
use warnings;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(read_control_file);

use Debian::DocBase::Common;



##
## assuming filehandle IN is the control file, read a section (or
## "stanza") of the doc-base control file and adds data in that
## section to the hash reference passed as an argument.  Returns 1 if
## there is data and 0 if it was empty
##
sub read_control_file_section { # {{{
  my $fh = shift;
  my ($pfields) = @_;

  my $empty = 1;
  my ($cf,$v);
  while (<$fh>) {
    chomp;
    s/\s*$//;                   # trim trailing whitespace

    # empty line?
    if (/^\s*$/o) {
      if ($empty) {
        next;
      } else {
        last;
      }
    }

    $empty = 0;

    # new field?
    if (/^(\S+)\s*:\s*(.*)$/) {
      ($cf,$v) = ($1,$2);
      $cf = lc $cf;
      #print STDERR "$cf -> $v\n";
      if (exists $$pfields{$cf}) {
        warn "warning: $cf: overwriting previous setting of control field";
      }
      $$pfields{$cf} = $v;
    } elsif (/^\s+(\S.*)$/) {
      $v = $&;
      defined($cf) or die "syntax error in control file: no field specified";
      #print STDERR "$cf -> $v (continued)\n";
      $$pfields{$cf} .= "\n$v";
    } else {
      die "syntax error in control file: $_";
    }
  }

  return not $empty;
} # }}}

# reads control file specified as argument
# output:
#    sets $docid
#    sets $doc_data to point to a hash containing the document data
#    sets @format_list, a list of pointers to hashes containing the format data
sub read_control_file { # {{{
  my ($file) = @_;

  my $fh=$file; 
  open($fh, $file) or 
    open($fh, "/usr/share/doc-base/$file") or
    die "$file: cannot open control file for reading: $!\n";

  $doc_data = {};
  read_control_file_section($fh, $doc_data) or die "error: empty control file";
  if (defined $$doc_data{'version'}) {
      warn "skipping $file, because of unsupported Version field\n" if ($verbose);
      exit 0;
  }      
  # check for required information
  ($docid = $$doc_data{'document'}) 
    or die "error in control file: `Document' value not specified";
  $$doc_data{'title'}
    or die "error in control file: `Title' value not specified";
  $$doc_data{'section'}
    or die "error in control file: `Section' value not specified";

  undef @format_list;
  my $format_data = {};
  while (read_control_file_section($fh, $format_data)) {
    # adjust control fields
    $$format_data{'format'} =~ tr/A-Z/a-z/;
    # check for required information
    $$format_data{'format'}
      or die "error in control file: `Format' value not specified";
    $$format_data{'files'}
      or die "error in control file: `Files' value not specified";
      
    if ($verbose) {
      grep { $_ eq $$format_data{'format'} } @supported_formats
        or  warn "warning: ignoring unknown format `$$format_data{'format'}'";
    }
    if (grep { $_ eq $$format_data{'format'}} @need_index_formats) {
      $$format_data{'index'}
         or die "error in control file: `Index' value missing for format `" . $$format_data{'format'} . "'"
    } 

    my $ok = 1;
    if ($warn_nonexistent_files) {
      if (defined $$format_data{'index'} && ! -e $$format_data{'index'}) {
        warn "warning: file `$$format_data{'index'}' does not exist" if ($verbose);
        $ok = 0;
      }
      my @globlist = glob($$format_data{'files'});
      # if the mask doesn't contain any meta-characters, then glob simply returns its argument 
      pop @globlist if ($#globlist == 0 && ! -f $globlist[0]);
      if ($#globlist < 0) {
        warn "warning: file mask `$$format_data{'files'}' does not match any files" if ($verbose);
        $ok = 0;
      }    
    }

    push(@format_list,$format_data) if $ok;
    $format_data = {};
  }
  close($fh);
} # }}}

1;
