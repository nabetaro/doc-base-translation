# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DocBaseFile.pm 65 2007-05-02 12:03:51Z robert $
#

package Debian::DocBase::DocBaseFile;

use strict;
use warnings;


use File::Glob ':glob';
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Scalar::Util qw(weaken);

our %CONTROLFILES = ();

# constants for _prserr function
use constant PRS_FATAL_ERR    => 1;   # fatal error, marks documents as invalid
use constant PRS_WARN_ERR     => 2;   # warning, marks document as invalid
use constant PRS_WARN_IGN     => 3;   # ingored warning

use base 'Exporter';
our @EXPORT = qw(PARSE_GETDOCID PARSE_FULL); 
# constants for new and
use constant PARSE_GETDOCID => 1;
use constant PARSE_FULL     => 2;

sub new { # {{{
    my $class       = shift;
    my $filename    = shift;
    my $parse_flag  = shift; # PARSE_FULL or PARSE_GETDOCID
    if (defined  $CONTROLFILES{$filename}) {
      $CONTROLFILES{$filename}->_parse($parse_flag);
      return $CONTROLFILES{$filename} 
    }      

    my $self = {
        DOCUMENT_ID   => undef,
        ABSTRACT      => undef,
        AUTHOR        => undef,
        TITLE         => undef,
        SECTION       => undef,
        FORMAT_LIST   => {},
        FILE_NAME     => $filename,
        PARSE_FLAG    => 0,
        INVALID       => 1
    };
    bless($self, $class);
    $self->_parse($parse_flag);
    $CONTROLFILES{$filename} = $self;
    weaken $CONTROLFILES{$filename};
    return $self;
} # }}}


sub DESTROY { # {{{
  my $self = shift;
  delete $CONTROLFILES{$self->source_file_name()};
} # }}}


sub document_id() { # {{{
  my $self = shift;
  return $self->{'DOCUMENT_ID'};
} # }}}

sub _check_parsed() { # {{{
  my $self = shift;
  croak ("Internal error") if $self->{'PARSE_FLAG'} != PARSE_FULL;
} # }}}

sub abstract() { # {{{
  my $self = shift;
  $self->_check_parsed();
  return $self->{'ABSTRACT'};
} # }}}

sub title() { # {{{
  my $self = shift;
  $self->_check_parsed();
  return $self->{'TITLE'};
} # }}}

sub section() { # {{{
  my $self = shift;
  $self->_check_parsed();
  return $self->{'SECTION'};
} # }}}

sub author() { # {{{
  my $self = shift;
  $self->_check_parsed();
  return $self->{'AUTHOR'};
} # }}}

sub format($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  $self->_check_parsed();
  return $self->{'FORMAT_LIST'}->{$format_name};
} # }}}

sub source_file_name() { # {{{
  my $self = shift;
  return $self->{'FILE_NAME'};
} # }}}

sub invalid() { # {{{
  my $self = shift;
  return $self->{'INVALID'};
} # }}}


# Parsing errors routine
# The first argument should be
#     FATAL_PARSE_ERROR, which sets global exit status to 1 and {'INVALID'} to 1
#  or PARSE_ERROR       , INVALID to 1
#  or PARSE_WARNING     , does not change INVALID
# The second argument should be the message
sub _prserr($$) { # {{{
  my $self = shift;
  my $flag = shift;
  my $msg = shift;
  my $filepos =  "`" . $self->source_file_name()  . ((defined $.) ? "', line $." : "");


  $self->{'INVALID'} = 1 if $flag != PRS_WARN_IGN;

  if ($flag == PRS_FATAL_ERR) {
    &Error("Error in $filepos: $msg");
  } elsif ($flag == PRS_WARN_IGN) {
    &Warn("Warning in $filepos: $msg (ignored)");
  } elsif ($flag == PRS_WARN_ERR) {
    &Warn("Warning in $filepos: $msg (ignored)");
  } else {
    croak ("Internal error: Unknown flag ($flag, $msg)");
  }    

  return undef;
} # }}}


sub _parse { # {{{
  my $self      = shift;
  my $parseflag = shift;
  my $file      = $self->{FILE_NAME};
  my $fh        = undef;
  my $docid     = undef;

  # is file already parsed
  return if ($self->{'PARSE_FLAG'} == PARSE_FULL);
  return if ($self->{'PARSE_FLAG'} == $parseflag);

  open($fh, $file) or
    return $self->_prserr(PRS_FATAL_ERR, "cannot open file for reading: $!\n");

  $self->_read_control_file($parseflag, $fh);

  $self->{'PARSE_FLAG'} = $parseflag;

  close($fh);
} # }}}

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
      if (exists $$pfields{$cf}) {
        return $self->_prserr(PRS_WARN_IGN, "overwriting previous setting of control field $cf");
      }
      $$pfields{$cf} = $v;
    } elsif (/^\s+(\S.*)$/) {
      $v = $&;
      defined($cf) or return $self->_prserr(PRS_FATAL_ERR, "syntax error - no field specified");
      #print STDERR "$cf -> $v (continued)\n";
      $$pfields{$cf} .= "\n$v";
    } else {
      return $self->_prserr(PRS_FATAL_ERR, "syntax error in control file: $_");
    }
  }

  return not $empty;
} # }}}


# reads control file specified as argument
# output:
#    sets $docid
#    sets $doc_data to point to a hash containing the document data
#    sets @format_list, a list of pointers to hashes containing the format data
sub _read_control_file { # {{{
  my $self      = shift;
  my $parseflag = shift;
  my $fh        = shift;
  my ($tmp, $tmpnam);


  # first find doc id
  $_ = <$fh>;
  return $self->_prserr(PRS_FATAL_ERR, "the first line does not contain valid `Document' field")
    unless /^\s*Document\s*:\s*([\w\+\.\-]+)\s*$/i;
  $self->{'DOCUMENT_ID'} = $tmp = $1;
  $self->_prserr(PRS_WARN_IGN, "invalid value of `Document' field")
    if $tmp ne lc $tmp;


  return if $parseflag == PARSE_GETDOCID;


  # parse rest of the file
  my $doc_data = {};
  $self->_read_control_file_section($fh, $doc_data) or die "error: empty control file";
  defined $$doc_data{'version'} and
      return $self->_pwarn ("unsupported Version: $$doc_data{'version'}");

  $self->{TITLE} = $$doc_data{'title'}
    or return $self->_prserr(PRS_FATAL_ERR, "`Title' value not specified");
  $self->{SECTION} = $$doc_data{'section'}
    or return $self->_prserr(PRS_FATAL_ERR, "`Section' value not specified");
  $self->{ABSTRACT} = defined $$doc_data{'abstract'} ?  $$doc_data{'abstract'} : "";
  $self->{AUTHOR} = defined $$doc_data{'author'} ? $$doc_data{'author'} : "";
  undef $doc_data;


  my $format_data = {};
  while ($self->_read_control_file_section($fh, $format_data)) {
    my $format = $$format_data{'format'};
    # check for required information

    $format
      or return $self->_prserr(PRS_FATAL_ERR, "`Format' value not specified");

    # adjust control fields
    $format =~ tr/A-Z/a-z/;

    if (defined $self->{FORMAT_LIST}->{$format}) {
      $self->_prserr(PRS_WARN_IGN, "format $format already defined");
      next;
    }

    if (not grep { $_ eq $format } @supported_formats) {
      $self->_prserr(PRS_WARN_IGN, "format `$$format_data{'format'}' is not supported");
      next;
    }


    # Check `Index' field
    if (grep { $_ eq $format } @need_index_formats) {
        $tmp = $$format_data{'index'};
        $tmpnam = "Index";

        # a) does the field exist?
        defined $tmp
          or return $self->_prserr(PRS_FATAL_ERR,"`$tmpnam' value missing for format $format");

        # b) does it start with / ?
        if ($$format_data{'index'} !~ /^\//) {
          $self->_prserr(PRS_WARN_IGN, "`$tmpnam' value has to be specified with absolute path: $tmp");
          next;
       }

       # c) does the index file exist?
       if (not -e $tmp) {
        $self->_prserr(PRS_WARN_IGN, "file `$$format_data{'index'}' does not exist");
        next;
      }
    }


    # `Files' fields checks
    # a) is field defined?
    $tmp    =  $$format_data{'files'};
    $tmpnam = "Files";
    if (not defined $tmp) {
      $self->_prserr(PRS_WARN_IGN, "`$tmpnam' value not specified for format $format");
      next;
    }

    my @masks = split /\s+/, $tmp;
    # b) do values start with / ?
    my @invalid = grep { /^[^\/]/ } @masks;
    if ($#invalid > -1) {
      $self->_prserr(PRS_WARN_IGN, "`$tmpnam' value has to be specified with absolute path: " . join (' ', @invalid));
      next;
    }

   # c) do files exist ?
   if (not grep { &bsd_glob($_, GLOB_NOSORT) }  @masks) {
      $self->_prserr(PRS_WARN_IGN, "file mask `" . join(' ', @masks) . "' does not match any files");
      next;
   }

   $self->{FORMAT_LIST}->{$format} = $format_data;
   $format_data = {};
  }

  return $self->_prserr(PRS_WARN_ERR, "no valid `Format' section found") if (keys %{$self->{FORMAT_LIST}} < 0);

 $self->{'INVALID'} = 0;
} # }}}

1;
