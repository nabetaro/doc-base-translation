# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DocBaseFile.pm 57 2007-04-13 19:18:32Z robert $
#

package Debian::DocBase::DocBaseFile;

use strict;
use warnings;

use Debian::DocBase::Common;
use Carp;

sub new {
    my $class    = shift;
    my $filename = shift;
    my $self = {
        DOCUMENT_ID   => undef,
        ABSTRACT      => undef,
        AUTHOR        => undef,
        TITLE         => undef,
        SECTION       => undef,
        FORMAT_LIST   => {},
        FILE_NAME     => $filename,
        INVALID       => 1
    };
    bless($self, $class);
    $self->_parse($filename);
    return $self;
}

sub document_id() {
  my $self = shift;
  return $self->{'DOCUMENT_ID'};
}

sub abstract() {
  my $self = shift;
  return $self->{'ABSTRACT'};
}  

sub title() {
  my $self = shift;
  return $self->{'TITLE'};
}  

sub section() {
  my $self = shift;
  return $self->{'SECTION'};
}  

sub author() {
  my $self = shift;
  return $self->{'AUTHOR'};
}  

sub format($$) {
  my $self = shift;
  my $format_name = shift;
  return $self->{'FORMAT_LIST'}->{$format_name};
}

sub source_file_name() {
  my $self = shift;
  return $self->{'FILE_NAME'};
}

sub invalid() {
  my $self = shift;
  return $self->{'INVALID'};
}  

sub _error {
  my $self = shift;
  my $msg = shift;
  croak($msg);
  return undef;
}



##
## assuming filehandle IN is the control file, read a section (or
## "stanza") of the doc-base control file and adds data in that
## section to the hash reference passed as an argument.  Returns 1 if
## there is data and 0 if it was empty
##
sub _read_control_file_section { # {{{
  my $self = shift;
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

sub _parse { 
  my $self = shift;
  my $file = $self->{FILE_NAME};
  my $fh   = undef;

  open($fh, $file) or 
    return &Error("Cannot open control file $file for reading: $!\n");
  
  $self->_read_control_file($fh);
  close($fh);
}  

# reads control file specified as argument
# output:
#    sets $docid
#    sets $doc_data to point to a hash containing the document data
#    sets @format_list, a list of pointers to hashes containing the format data
sub _read_control_file { # {{{
  my $self=shift;
  my $fh=shift;


  my $doc_data = {};
  $self->_read_control_file_section($fh, $doc_data) or die "error: empty control file";
  defined $$doc_data{'version'} and
      return &Error ("unsupported Version: $$doc_data{'version'}");

  # check for required information
  $self->{DOCUMENT_ID} = $$doc_data{'document'}
    or return $self->_error("`Document' value not specified");
  $self->{TITLE} = $$doc_data{'title'}
    or return $self->_error("`Title' value not specified");
  $self->{SECTION} = $$doc_data{'section'}
    or return $self->error("`Section' value not specified");
  $self->{ABSTRACT} = defined $$doc_data{'abstract'} ?  $$doc_data{'abstract'} : "";
  $self->{AUTHOR} = defined $$doc_data{'author'} ? $$doc_data{'author'} : "";
  undef $doc_data;    

  my $format_data = {};
  while ($self->_read_control_file_section($fh, $format_data)) {
    my $format = $$format_data{'format'}; 
    # check for required information
    $format
      or return $self->_error("`Format' value not specified");
    # adjust control fields
    $format =~ tr/A-Z/a-z/;

    defined $self->{FORMAT_LIST}->{$format} 
      and return $self->_error("format $format already defined");

    grep { $_ eq $format } @supported_formats
        or return $self->_error("format `$$format_data{'format'}' is not supported");
    
    $$format_data{'files'}
      or return $self->_error("`Files' value not specified for format $format");
      
    if (grep { $_ eq $format } @need_index_formats) {
        $$format_data{'index'}
          or return $self->_error("`Index' value missing for format `" . $$format_data{'format'} . "'");
       (-e $$format_data{'index'}) 
          or return $self->_error("file `$$format_data{'index'}' does not exist");
    } else {
#      $$format_data{'index'} = undef;
    }   

   my @globlist = glob($$format_data{'files'});
   # if the mask doesn't contain any meta-characters, then glob simply returns its argument 
   pop @globlist if ($#globlist == 0 && ! -f $globlist[0]);
   ($#globlist < 0) and 
    return $self->_error("file mask `$$format_data{'files'}' does not match any files"); 

   $self->{FORMAT_LIST}->{$format} =  $format_data;
   $format_data = {};
  }

  
 $self->{'INVALID'} = 0;
} # }}}

1;
