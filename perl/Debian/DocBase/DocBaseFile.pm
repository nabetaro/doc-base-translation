# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: DocBaseFile.pm 139 2008-04-23 20:42:34Z robert $
#

package Debian::DocBase::DocBaseFile;

use strict;
use warnings;


use File::Glob ':glob';
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Scalar::Util qw(weaken);
use Carp;

our %CONTROLFILES = ();


# constants for _PrsErr function
use constant PRS_FATAL_ERR    => 1;   # fatal error, marks documents as invalid
use constant PRS_ERR_IGN      => 2;   # error, marks documents as invalid
use constant PRS_WARN         => 3;   # warning, marks document as invalid

my %valid_sections = ();

#################################################
###        PUBLIC STATIC FUNCTIONS            ###
#################################################

sub GetDocIdFromRegisteredFile($) { # {{{
  my $file = shift;
  my $data = Debian::DocBase::DB::GetFilesDB()->GetData($file);
  return undef unless $data;
  return $data->{'ID'};
} # }}}

sub GetAllDocBaseFiles() { # {{{
  my @global = ();
  my @local  = ();
  if (opendir(DIR, $CONTROL_DIR)) {
    @global = grep { $_ = "$CONTROL_DIR/$_" if -f "$CONTROL_DIR/$_" } readdir(DIR);
    closedir DIR;
  }
  if (opendir(DIR, $LOCAL_CONTROL_DIR)) {
    @local = grep { $_ = "$LOCAL_CONTROL_DIR/$_"
                       if $_ ne "README"
                          and $_ !~ /\.(bak|swp|~)$/o
                          and -f "$LOCAL_CONTROL_DIR/$_" } readdir(DIR);
    closedir DIR;
  }
  return (@global, @local);
}  # }}}

sub GetChangedDocBaseFiles($$){ # {{{
  my ($toremove, $toinstall) = @_;

  my @changed = ();

  my %files = map { $_ => (stat $_)[$CTIME_FIELDNO] } GetAllDocBaseFiles();

  my $db    = Debian::DocBase::DB::GetFilesDB()->GetDB();
  foreach my $file ( keys %{$db} ) {
    my $realfile =  Debian::DocBase::DB::GetFilesDB()->DecodeKey($file);
    if ($files{$realfile} ) {
      push @changed, $realfile if $files{$realfile} != $db->{$file}->{'CT'};
      delete $files{$realfile}
    } else {
      push @$toremove, $realfile;
    }
  }
  @$toinstall = keys %files;

  my @retval = ($#{$toremove}+1, $#changed+1, $#{$toinstall}+1);

  push @$toinstall, @changed;
  push @$toremove, @changed;
  undef @changed;
  return @retval;
} # }}}

sub new { # {{{
    my $class         = shift;
    my $filename      = shift;
    my $do_add_checks = shift;
    if (defined  $CONTROLFILES{$filename}) {
      return $CONTROLFILES{$filename}
    }

    my $self = {
        MAIN_DATA     => {},    # hash of main_fld=>value
        FORMAT_LIST   => {},    # array of format data hashes
        FILE_NAME     => $filename,
        CTIME         => 0,
        DO_ADD_CHECKS => $do_add_checks ? 1 : 0,
        WARNERR_CNT   => 0, # errors/warnings count
        INVALID       => 1,
        PARSED        => 0
    };
    bless($self, $class);
    $self->_ReadStatusDB();
    $CONTROLFILES{$filename} = $self;
    weaken $CONTROLFILES{$filename};
    return $self;
 } # }}}

#################################################
###            PUBLIC FUNCTIONS               ###
#################################################

sub DESTROY { # {{{
  my $self = shift;
  delete $CONTROLFILES{$self->GetSourceFileName()};
} # }}}

sub GetDocumentID() { # {{{
  my $self = shift;
  $self->_CheckParsed();
  return $self->{'MAIN_DATA'}->{$FLD_DOCUMENT};
} # }}}

sub GetFldValue($$) { # {{{
  my $self = shift;
  my $fld  = shift;
  $self->_CheckParsed();
  return $self->{'MAIN_DATA'}->{$fld};
} # }}}

sub GetFormat($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  $self->_CheckParsed();
  return $self->{'FORMAT_LIST'}->{$format_name};
} # }}}

# returns list of all format names defined in control file
sub GetFormatNames($$) { # {{{
  my $self   = shift;
  my @fnames = sort keys %{$self->{'FORMAT_LIST'}};
  return @fnames;
} # }}}

sub GetSourceFileName() { # {{{
  my $self = shift;
  return $self->{'FILE_NAME'};
} # }}}

sub Invalid() { # {{{
  my $self = shift;
  return $self->{'INVALID'};
} # }}}

sub GetWarnErrCount() { # {{{
  my $self = shift;
  return $self->{'WARNERR_CNT'};
} # }}}

sub OnRegistered($$) { # {{{
  my ($self, $valid)  = @_;
  my $docid = $valid ? $self->GetDocumentID() : undef;
  my $data  = { CT => $self->{'CTIME'},
                ID => $docid,
             };
  Debug("OnRegistered (".$self->GetSourceFileName().", $valid)");
  Debian::DocBase::DB::GetFilesDB()->PutData($self->GetSourceFileName(), $data);
} # }}}

sub OnUnregistered() { # {{{
  my $self = shift;
  Debug("OnUnregistered (".$self->GetSourceFileName().")");

  Debian::DocBase::DB::GetFilesDB()->RemoveData($self->GetSourceFileName());

} # }}}

sub GetLastChangeTime($) { # {{{
  my $self = shift;
  return $self->{'CTIME'};
} # }}}

sub _ReadStatusDB($) { # {{{
  my $self = shift;
  my $data = Debian::DocBase::DB::GetFilesDB()->GetData($self->GetSourceFileName());
  return unless $data;
  $self->{'MAIN_DATA'}->{$FLD_DOCUMENT} = $data->{'ID'};
  $self->{'CTIME'} = $data->{'CT'}
} # }}}


sub Parse { # {{{
  my $self      = shift;
  my $file      = $self->{'FILE_NAME'};
  my $fh        = undef;
  my $docid     = undef;

  # is file already parsed
  return if $self->{'PARSED'};

  open($fh, "<", $file) or
    carp "Cannot open control file `$file' for reading: $!";

  $self->{'CTIME'} = (stat $fh)[$CTIME_FIELDNO];

  $self->_ReadControlFile($fh);

  $self->{'PARSED'} = 1;

  close($fh);
} # }}}

#################################################
###            PRIVATE FUNCTIONS              ###
#################################################

# Parsing errors routine
# The first argument should be
#     PRS_FATAL_ERR, which sets global exit status to 1 and {'INVALID'} to 1
#  or PRS_ERR      , INVALID to 1
#  or PRS_WARN     , does not change INVALID
# The second argument should be the message
sub _PrsErr($$) { # {{{
  my $self = shift;
  my $flag = shift;
  my $msg = shift;
  my $filepos =  "`" . $self->GetSourceFileName()  . ((defined $.) ? "', line $." : "");


  $self->{'WARNERR_CNT'}++;
  $self->{'INVALID'} = 1 if $flag != PRS_WARN;

  if ($flag == PRS_FATAL_ERR) {
    Error("Error in $filepos: $msg");
  } elsif ($flag == PRS_ERR_IGN) {
    ErrorNF("Error in $filepos: $msg");
  } elsif ($flag == PRS_WARN) {
    Warn("Warning in $filepos: $msg");
  } else {
    croak ("Internal error: Unknown flag ($flag, $msg)");
  }

  return undef;
} # }}}

# Check if input is UTF-8 encoded.  If it's not recode and warn
# Parameters: $line- input line
#             $fld - original field name
sub _CheckUTF8($$) { # {{{
  my ($self, $line, $fld) = @_;
  my $is_utf8_expr= '^(?:[\x{00}-\x{7f}]|[\x{80}-\x{255}]{2,})*$';

  return $line if length($line) > 512;

  if ($line !~ /$is_utf8_expr/o) {
      $self->_PrsErr(PRS_WARN, "line in field `$fld' seems not to be UTF-8 encoded, recoding");
      utf8::encode($line);
  }
  return $line;
} # }}}

##
## assuming filehandle IN is the control file, read a section (or
## "stanza") of the doc-base control file and adds data in that
## section to the hash reference passed as an argument.  Returns 1 if
## there is data, 0 if it was empty or undef in case of parse error
##
sub _ReadControlFileSection($$$) { # {{{
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
        $self->_PrsErr(PRS_WARN, "control field `$origcf' already defined");
        next;
      } elsif (not defined $FIELDS_DEF{$cf}) {
        $self->_PrsErr(PRS_WARN, "unrecognised control field `$origcf'");
        next;
      } elsif ($FIELDS_DEF{$cf}->{$FLDDEF_TYPE} != $fldstype) {
        $self->_PrsErr(PRS_WARN, "field `$origcf' in incorrect section (missing empty line before the field?)");
        next;
      }
      $pfields->{$cf} = $self->_CheckUTF8($v, $origcf);

    } elsif (/^\s+(\S.*)$/o) {
      $v = $&;
      defined($cf) or return $self->_PrsErr(PRS_FATAL_ERR, "syntax error - no field specified");
      not defined($FIELDS_DEF{$cf}) or $FIELDS_DEF{$cf}->{$FLDDEF_MULTILINE} or return $self->_PrsErr(PRS_FATAL_ERR, "field `$origcf' can't consist of multi lines");
    #print STDERR "$cf -> $v (continued)\n";
      $$pfields{$cf} .= "\n" . $self->_CheckUTF8($v, $origcf);
    } else {
      return $self->_PrsErr(PRS_FATAL_ERR, "syntax error in control file: $_");
    }
  }
  return $self->_CheckRequiredFields($pfields, $fldstype) unless $empty and $fldstype == $FLDTYPE_FORMAT;
  return not $empty;
} # }}}

sub _CheckParsed() { # {{{
  my $self      = shift;
  my $filename  = $self->GetSourceFileName();
  croak ('Internal error: file `' . (defined $filename ?  $filename : "") . "' not parsed")
    unless $self->{'PARSED'};
} # }}}

sub _CheckSection($$) { # {{{
  my $self          = shift;
  my $orig_section  = shift;

  ReadMap($DOCBASE_VALID_SECTIONS_LIST, \%valid_sections, 1) unless %valid_sections;
  my $section  = lc $orig_section;
  $section  =~ s/[\/\s]+$//g;
  $section  =~ s/^[\/\s]+//g;

  while ($section) {
    return if $valid_sections{$section};
    last unless $section =~ s/\/[^\/]+$//;
  }

 $self->_PrsErr(PRS_WARN, "unknown section: `$orig_section'\n");
} # }}}

sub _CheckRequiredFields($$$) { # {{{
  my $self       = shift;
  my $pfields    = shift;
  my $fldstype   = shift;    # $FLDTYPE_MAIN or $FLDTYPE_FORMAT

  foreach my $fldname (sort keys (%FIELDS_DEF)) {
    if (
        $FIELDS_DEF{$fldname} -> {$FLDDEF_TYPE} == $fldstype
        and $FIELDS_DEF{$fldname} -> {$FLDDEF_REQUIRED}
        and not exists $pfields->{$fldname}
       ) {
      return $self -> _PrsErr(PRS_FATAL_ERR, "`" . ucfirst($fldname) . "' value not specified");
    }
  }
  return 1;
} # }}}

# reads control file specified as argument
# output:
#    sets $docid
#    sets $doc_data to point to a hash containing the document data
#    sets @format_list, a list of pointers to hashes containing the format data
sub _ReadControlFile { # {{{
  my $self      = shift;
  my $fh        = shift;
  my ($tmp, $tmpnam);

  # first find doc id
  $_ = <$fh>;
  return $self->_PrsErr(PRS_FATAL_ERR, "the first line does not contain valid `Document' field")
    unless defined $_ and /^\s*Document\s*:\s*(\S+)\s*$/i;
  $self->{'MAIN_DATA'} = { $FLD_DOCUMENT => ($tmp = $1) };
  $self->_PrsErr(PRS_WARN, "invalid value of `Document' field")
    unless $tmp =~ /^[a-z0-9\.\+\-]+$/;

  my $doc_data = $self->{'MAIN_DATA'};
  # parse rest of the file
  $self->_ReadControlFileSection($fh, $doc_data, $FLDTYPE_MAIN)
    or return undef;
  return $self->_PrsErr(PRS_WARN, "unsupported Version: $$doc_data{'version'}") if
    defined $$doc_data{'version'};

  $self->_CheckSection($doc_data->{$FLD_SECTION}) if $self->{'DO_ADD_CHECKS'};


  $self->{'MAIN_SECTION'} = $doc_data;
  undef $doc_data;


  my $format_data = {};
  my $status      = 0;
  while ($status = $self->_ReadControlFileSection($fh, $format_data, $FLDTYPE_FORMAT)) {
    my $format = $$format_data{'format'};

    # adjust control fields
    $format =~ tr/A-Z/a-z/;

    if (defined $self->{FORMAT_LIST}->{$format}) {
      return $self->_PrsErr(PRS_ERR_IGN, "format $format already defined");
    }

    if (not grep { $_ eq $format } @SUPPORTED_FORMATS) {
      $self->_PrsErr(PRS_WARN, "format `$$format_data{'format'}' is not supported");
      next;
    }

    my $index_value = undef;
    # Check `Index' field
    if (grep { $_ eq $format } @NEED_INDEX_FORMATS) {
        $index_value = $tmp = $$format_data{'index'};
        $tmpnam = "Index";

        # a) does the field exist?
        defined $tmp
          or return $self->_PrsErr(PRS_FATAL_ERR,"`$tmpnam' value missing for format `$format'");

        # b) does it start with / ?
        if ($$format_data{'index'} !~ /^\//) {
          $self->_PrsErr(PRS_WARN, "`$tmpnam' value has to be specified with absolute path: $tmp");
          next;
       }

       # c) does the index file exist?
       if (not -e $opt_rootdir.$tmp) {
        $self->_PrsErr(PRS_WARN, "file `$tmp' does not exist" .
                       ($opt_rootdir eq "" ? "" : " (using `$opt_rootdir' as the root directory)"));
        next;
      }
    }


    # `Files' fields checks
    # a) is field defined?
    $tmp    =  $$format_data{'files'};
    $tmpnam = "Files";
    if (not defined $tmp) {
      $self->_PrsErr(PRS_WARN, "`$tmpnam' value not specified for format `$format'");
      next;
    }

    if (not defined $index_value or $tmp ne $index_value) {
      my @masks = split /\s+/, $tmp;
      # b) do values start with / ?
      my @invalid = grep { /^[^\/]/ } @masks;
      if ($#invalid > -1) {
        $self->_PrsErr(PRS_WARN, "`$tmpnam' value has to be specified with absolute path: " . join (' ', @invalid));
        next;
      }

      # c) do files exist ?
      if (not grep { &bsd_glob($opt_rootdir.$_, GLOB_NOSORT) }  @masks) {
        $self->_PrsErr(PRS_WARN, "file mask `" . join(' ', @masks) . "' does not match any files" .
                         ($opt_rootdir eq "" ? "" : " (using `$opt_rootdir' as the root directory)"));
        next;
      }
    }

   $self->{FORMAT_LIST}->{$format} = $format_data;
  } continue {
   $format_data = {};
  }
  return undef unless defined $status;

  return $self->_PrsErr(PRS_ERR_IGN, "no valid `Format' section found") if (keys %{$self->{FORMAT_LIST}} < 0);

 $self->{'INVALID'} = 0;
} # }}}



1;
