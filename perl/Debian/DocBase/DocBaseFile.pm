# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DocBaseFile.pm 81 2007-10-21 11:33:05Z robert $
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
use constant PRS_ERR_IGN      => 2;   # error, marks documents as invalid
use constant PRS_WARN         => 3;   # warning, marks document as invalid


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
        WARNERR_CNT   => 0, # errors/warnings count
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

sub warn_err_count() { # {{{
  my $self = shift;
  return $self->{'WARNERR_CNT'};
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


  $self->{'WARNERR_CNT'}++;
  $self->{'INVALID'} = 1 if $flag != PRS_WARN;

  if ($flag == PRS_FATAL_ERR) {
    &Error("Error in $filepos: $msg");
  } elsif ($flag == PRS_ERR_IGN) {
    &ErrorNF("Error in $filepos: $msg");
  } elsif ($flag == PRS_WARN) {
    &Warn("Warning in $filepos: $msg");
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

  open($fh, "<", $file) or
    return $self->_prserr(PRS_FATAL_ERR, "cannot open file for reading: $!\n");

  $self->_read_control_file($parseflag, $fh);

  $self->{'PARSE_FLAG'} = $parseflag;

  close($fh);
} # }}}

##
## assuming filehandle IN is the control file, read a section (or
## "stanza") of the doc-base control file and adds data in that
## section to the hash reference passed as an argument.  Returns 1 if
## there is data, 0 if it was empty or undef in case of parse error
##
sub _read_control_file_section($$$$) { # {{{
  my $self     = shift;
  my $fh       = shift;    # file handle
  my $pfields  = shift;    # read fields
  my $fldstype = shift;    # $FLDTYPE_MAIN or $FLDTYPE_FORMAT


  my $empty = 1;
  my ($origcf, $cf,$v);
  while (<$fh>) {
    chomp;
    s/\s*$//o;                   # trim trailing whitespace

    # empty line?
    if (/^\s*$/o) {
      $empty ? next : last;
    }

    $empty = 0;

    # new field?
    if (/^(\S+)\s*:\s*(.*)$/o) {
      ($origcf, $cf, $v) = ($1, lc $1, $2);
      if (exists $pfields->{$cf}) {
        return $self->_prserr(PRS_FATAL_ERR, "control field `$origcf' already defined");
      } elsif (not defined $FIELDS_DEF{$cf}) {
        return $self->_prserr(PRS_FATAL_ERR, "unrecognised control field `$origcf'");
      } elsif ($FIELDS_DEF{$cf}->{$FLDDEF_TYPE} != $fldstype) {
        return $self->_prserr(PRS_FATAL_ERR, "field `$origcf' in incorrect section (missing empty line before the field?)");
      }
      $pfields->{$cf} = $v;

    } elsif (/^\s+(\S.*)$/o) {
      $v = $&;
      defined($cf) or return $self->_prserr(PRS_FATAL_ERR, "syntax error - no field specified");
      $FIELDS_DEF{$cf}->{$FLDDEF_MULTILINE} or return $self->_prserr(PRS_FATAL_ERR, "field `$origcf' can't consist of multi lines");
    #print STDERR "$cf -> $v (continued)\n";
      $$pfields{$cf} .= "\n$v";
    } else {
      return $self->_prserr(PRS_FATAL_ERR, "syntax error in control file: $_");
    }
  }
  return $self->_check_required_fields($pfields, $fldstype) unless $empty and $fldstype == $FLDTYPE_FORMAT;
  return not $empty;
} # }}}

sub _check_required_fields($$$) { # {{{
  my $self       = shift;
  my $pfields    = shift;
  my $fldstype   = shift;    # $FLDTYPE_MAIN or $FLDTYPE_FORMAT

  foreach my $fldname (sort keys (%FIELDS_DEF)) {
    if (
        $FIELDS_DEF{$fldname} -> {$FLDDEF_TYPE} == $fldstype
        and $FIELDS_DEF{$fldname} -> {$FLDDEF_REQUIRED}
        and not exists $pfields->{$fldname}
       ) {
      return $self -> _prserr(PRS_FATAL_ERR, "`" . ucfirst($fldname) . "' value not specified");
    }
  }
  return 1;
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
    unless /^\s*Document\s*:\s*(\S+)\s*$/i;
  $self->{'DOCUMENT_ID'} = $tmp = $1;
  $self->_prserr(PRS_WARN, "invalid value of `Document' field")
    unless $tmp =~ /^[a-z0-9\.\+\-]+$/;


  return if $parseflag == PARSE_GETDOCID;

  my $doc_data = {'document' => $self->{'DOCUMENT_ID'} };
  # parse rest of the file
  $self->_read_control_file_section($fh, $doc_data, $FLDTYPE_MAIN) 
    or return undef;
  return $self->_prserr(PRS_WARN, "unsupported Version: $$doc_data{'version'}") if
    defined $$doc_data{'version'};

  $self->{TITLE} = $$doc_data{'title'};
  $self->{SECTION} = $$doc_data{'section'};
  $self->{ABSTRACT} = defined $$doc_data{'abstract'} ?  $$doc_data{'abstract'} : "";
  $self->{AUTHOR} = defined $$doc_data{'author'} ? $$doc_data{'author'} : "";
  undef $doc_data;


  my $format_data = {};
  my $status      = 0;
  while ($status = $self->_read_control_file_section($fh, $format_data, $FLDTYPE_FORMAT)) {
    my $format = $$format_data{'format'};

    # adjust control fields
    $format =~ tr/A-Z/a-z/;

    if (defined $self->{FORMAT_LIST}->{$format}) {
      return $self->_prserr(PRS_ERR_IGN, "format $format already defined");
    }

    if (not grep { $_ eq $format } @SUPPORTED_FORMATS) {
      $self->_prserr(PRS_WARN, "format `$$format_data{'format'}' is not supported");
      next;
    }

    my $index_value = undef;
    # Check `Index' field
    if (grep { $_ eq $format } @NEED_INDEX_FORMATS) {
        $index_value = $tmp = $$format_data{'index'};
        $tmpnam = "Index";

        # a) does the field exist?
        defined $tmp
          or return $self->_prserr(PRS_FATAL_ERR,"`$tmpnam' value missing for format $format");

        # b) does it start with / ?
        if ($$format_data{'index'} !~ /^\//) {
          $self->_prserr(PRS_WARN, "`$tmpnam' value has to be specified with absolute path: $tmp");
          next;
       }

       # c) does the index file exist?
       if (not -e $opt_rootdir.$tmp) {
        $self->_prserr(PRS_WARN, "file `$tmp' does not exist" .
                       ($opt_rootdir eq "" ? "" : " (using `$opt_rootdir' as the root directory)"));
        next;
      }
    }


    # `Files' fields checks
    # a) is field defined?
    $tmp    =  $$format_data{'files'};
    $tmpnam = "Files";
    if (not defined $tmp) {
      $self->_prserr(PRS_WARN, "`$tmpnam' value not specified for format $format");
      next;
    }

    if (not defined $index_value or $tmp ne $index_value) {
      my @masks = split /\s+/, $tmp;
      # b) do values start with / ?
      my @invalid = grep { /^[^\/]/ } @masks;
      if ($#invalid > -1) {
        $self->_prserr(PRS_WARN, "`$tmpnam' value has to be specified with absolute path: " . join (' ', @invalid));
        next;
      }

      # c) do files exist ?
      if (not grep { &bsd_glob($opt_rootdir.$_, GLOB_NOSORT) }  @masks) {
        $self->_prserr(PRS_WARN, "file mask `" . join(' ', @masks) . "' does not match any files" .
                         ($opt_rootdir eq "" ? "" : " (using `$opt_rootdir' as the root directory)"));
        next;
      }
    }

   $self->{FORMAT_LIST}->{$format} = $format_data;
  } continue {
   $format_data = {};
  }
  return undef unless defined $status;

  return $self->_prserr(PRS_ERR_IGN, "no valid `Format' section found") if (keys %{$self->{FORMAT_LIST}} < 0);

 $self->{'INVALID'} = 0;
} # }}}

1;
