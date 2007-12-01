# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Document.pm 96 2007-12-01 15:05:52Z robert $
#

package Debian::DocBase::Document;

use strict;
use warnings;

use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Debian::DocBase::DocBaseFile qw(PARSE_FULL PARSE_GETDOCID);
use Carp;
#use Scalar::Util qw(weaken);

our %DOCUMENTS = ();

sub new { # {{{
    my $class      = shift;
    my $documentId = shift;
    return $DOCUMENTS{$documentId} if defined  $DOCUMENTS{$documentId};

    my $self = {
        DOCUMENT_ID       => $documentId,
        MAIN_DATA         => {},
        FORMAT_LIST       => {},
        CONTROL_FILES     => {},
        STATUS_DICT       => {},
        MERGED_CTRL_FILES => 0,
        INVALID           => 1
    };
    bless($self, $class);
    $self->_read_status_file($documentId);
    $DOCUMENTS{$documentId} = $self;
#  weaken $DOCUMENTS{$documentId};
    return $self;
} # }}}

sub DESTROY { # {{{
  my $self = shift;
  delete $DOCUMENTS{$self->document_id()};
} # }}}

# class function: return list of all proceseed documents
sub GetDocumentList() { # {{{
  return values %DOCUMENTS;
} # }}}

sub document_id() { # {{{
  my $self = shift;
  return $self->{'DOCUMENT_ID'};
} # }}}

sub invalid() { # {{{
  my $self = shift;
  return $self->{'INVALID'};
} # }}}

# dies with Internal error if document hasn't been merged yet
sub _check_merged($) { # {{{
  my $self = shift;

  carp "Internal error: Document " . $self->document_id(). " not yet merged"
    unless $self->{'MERGED_CTRL_FILES'};
} # }}}

# returns $fld from $self->{'MAIN_DATA'}
sub _get_main_fld($$) { # {{{
  my $self = shift;
  my $fld  = shift;

  $self->_check_merged();

  return "" if $self->invalid();

  return "" unless $self->{'MAIN_DATA'}->{$fld};

  return $self->{'MAIN_DATA'}->{$fld};
} # }}}


# getters for common fields
sub abstract() { # {{{
  my $self = shift;
  return $self->_get_main_fld($FLD_ABSTRACT);
} # }}}

sub title() { # {{{
  my $self = shift;
  return $self->_get_main_fld($FLD_TITLE);
} # }}}

sub section() { # {{{
  my $self = shift;
  return $self->_get_main_fld($FLD_SECTION);
} # }}}

sub author() { # {{{
  my $self = shift;
  return $self->_get_main_fld($FLD_AUTHOR);
}   # }}}

# returns hash with format data (i.e. with FLD_FORMAT, $FLD_INDEX, $FLD_FILES keys) 
# for $format_name 
sub format($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  return undef unless $self->_has_control_files();
  $self->_check_merged();
  return $self->{'FORMAT_LIST'}->{$format_name};
} # }}}

# returns status data for $key 
sub get_status() { # {{{
  my $self = shift;
  my $key  = shift;
  return $self->{'STATUS_DICT'}->{$key};
}   # }}}

sub set_status($%) { # {{{
  my $self      = shift;
  my %status    = @_;

  my $changed = 0;

  foreach my $key (keys %status) {
    my $oldvalue = $self->{'STATUS_DICT'}->{$key};
    my $value   = $status{$key};

    if (defined $value) {
      $self->{'STATUS_DICT'}->{$key} = $value;
    } else {
       delete $self->{'STATUS_DICT'}->{$key};
    }

    $changed = 1 if ( (defined $value xor defined $oldvalue)
                   or (defined $value and $value ne $oldvalue) );
  }

  $changed ? $self->_write_status_file()
           : Debug("Status of `" . join ("', `", keys %status) . "' in " .
                    $self->document_id() . " not changed");
}   # }}}


sub _has_control_files() { # {{{
  my $self = shift;
  return $self->{'CONTROL_FILES'}
} # }}}

# reads our status file and sets $self->{'STATUS_DICT'} and sets keys of
# $self->{'CONTROL_FILES'} 
sub _read_status_file { # {{{
  my $self        = shift;
  my $docid       = $self->document_id();
  my $status_file = "$DATA_DIR/$docid.status";

  if (-f $status_file) {
    Debug ("Reading status file `$status_file'");
    my $status = {};
    open(S, "<", $status_file)
      or return Error("Cannot open status file `$status_file' for reading: $!");

    while (<S>) {
      chomp;
      next if /^\s*$/o;
      /^\s*(\S+):\s*"?(.*?)"?\s*$/o
        or return Warn("Syntax error in status file `$status_file': $_");
      $$status{$1} = $2;
    }
    close(S)
      or croak "Cannot close status file `$status_file': $!";

    %{$self->{'CONTROL_FILES'}} = map {
                                    s/^"//;
                                    s/"$//;
                                    Debug("Existing control file in status: $_");
                                    (-f $_) ? ($_ => undef): Warn("Registered control file `$_' no longer exists")
                                   } split(/\s*,\s*/, $status->{'Control-Files'})
                                      if $status->{'Control-Files'};

    delete $$status{'Control-Files'};
    $self->{'STATUS_DICT'} = $status;
  }
  $self->{'INVALID'} = 0;

} # }}}

# writes our status file
sub _write_status_file { # {{{
  my $self  = shift;
  my $docid = $self->document_id();

  my $status_file     = "$DATA_DIR/$docid.status";
  my $tmp_status_file = "$status_file.tmp";
  Debug ("Writing status information into `$status_file'");

  open(S, ">", $tmp_status_file)
    or croak "Cannot open status file `$tmp_status_file' for writing: $!";

  my $control_files = '"' . join('", "', sort keys %{$self->{'CONTROL_FILES'}}) . '"';
  print S "Control-Files: $control_files\n" unless $control_files eq '""';

  my $status = $self->{'STATUS_DICT'};
  for my $k (sort keys   %$status) {
    print S "$k: \"$$status{$k}\"\n";
  }
  close(S) or croak "Cannot close status file `$tmp_status_file': $!";

  IgnoreSignals();
  # remove file if it's empty
  if (-z $tmp_status_file) {
    unlink $tmp_status_file;
    unlink $status_file;
    Debug ("Removing status file `$status_file'");
  } else {
    rename $tmp_status_file, $status_file
      or croak "Can't rename `$tmp_status_file' to `$status_file': $!";
  }
  RestoreSignals();

} # }}}


# if called without any argument, returns array of control files' names 
# if called with an argument returns string containing names of the control files
#  joined with value of the argument
sub _GetControlFileNames($;$) { # {{{
  my $self      = shift;
  my $join_str  = shift;

  my @cfnames = sort keys %{$self->{'CONTROL_FILES'}};

  return @cfnames unless ($join_str);
  return join($join_str, @cfnames);
} # }}}


# reads and parses all control files mentioned in $self->{'CONTROL_FILES'}
sub _read_control_files($) { # {{{
  my $self = shift;

  foreach my $cfname ($self->_GetControlFileNames()) {
    $self->{'CONTROL_FILES'}->{$cfname} = Debian::DocBase::DocBaseFile->new($cfname, PARSE_FULL)
      unless $self->{'CONTROL_FILES'}->{$cfname};
  }
} # }}}

# displays informations about the document (called by `install-docs -s')
sub DisplayStatusInformation($) { # {{{
  my $self            = shift;
  my $docid           = $self->document_id();
  my $status_file     = "$DATA_DIR/$docid.status";
  my $var_ctrl_file   = "$VAR_CTRL_DIR/$docid";
  return unless -f $status_file;

  if (-f $var_ctrl_file) {
    if (open(F, '<', $var_ctrl_file)) {
      print "---document-information---\n";
      while (<F>) {
        next if /^Control-Files:/;
        s/^$/\n---format-description---/;
        print $_;
      }
      close(F);
    } else {
      Warn("Cannot open `$var_ctrl_file': $!");
    }
  }

  if (-f $status_file) {
    if (open(F, '<', $status_file)) {
      print "\n---status-information---\n";
      while (<F>) {
        print $_;
      }
      close(F);
    } else {
      Warn("Cannot open `$status_file': $!");
    }
  }
} # }}}

sub Register($$) { # {{{
  my $self          = shift;
  my $db_file       = shift;
  my $db_filename   = $db_file->source_file_name();

  Debug("Registering `$db_filename'");

  if ($db_file->document_id() ne $self->document_id()) {
    delete $self->{'CONTROL_FILES'}->{$db_filename};
    return Error("Document id in `$db_filename' does not match our document id (" .
                  $db_file->document_id() . ' != ' . $self->document_id() . ")");
  }

  if ($db_file->invalid()) {
    delete $self->{'CONTROL_FILES'}->{$db_filename};
    return Warn($db_file->source_file_name() . " contains errors, not registering");
  }

  $self->{'CONTROL_FILES'}->{$db_filename} = $db_file;
} # }}}

sub Unregister($$) { # {{{
  my $self          = shift;
  my $db_file       = shift;
  my $db_filename   = $db_file->source_file_name();

  Warn("File `" . $db_filename . "' is not registered, cannot remove")
    unless $self->{'CONTROL_FILES'}->{$db_filename};

  delete $self->{'CONTROL_FILES'}->{$db_filename};

} # }}}

sub UnregisterAll($) { # {{{
  my $self          = shift;

  Debug('Unregistering all control files from document `' . $self->document_id() . "'");

  $self->{'CONTROL_FILES'} = {};
} # }}}

# generate and write new merged control file into /var/lib/doc-base/documents
sub WriteNewCtrlFile() { # {{{
  my $self     = shift;
  my $docid    = $self->document_id();
  my $tmpfile  = $VAR_CTRL_DIR . "/." . $docid . ".tmp";
  my $file     = $VAR_CTRL_DIR . "/" . $docid;
  my $fld      = undef;

  $self->_check_merged();

  if ($self->invalid() || !$self->_has_control_files()) {
    if (-e $file)  {
      Debug("Removing control file $file");
      unlink $file or carp "Can't remove $file: $!";
    }
    return;
  }


  open(F, '>', $tmpfile) or
    carp ("Can't open $tmpfile for writing: $_");

  foreach $fld (GetFldKeys($FLDTYPE_MAIN)) {
    print F ucfirst($fld) . ": " .  $self->{'MAIN_DATA'}->{$fld} . "\n"
      if $self->{'MAIN_DATA'}->{$fld};
  }

  print F "Control-Files: " . $self->_GetControlFileNames(' ') . "\n" if $self->_has_control_files();

  foreach my $format (sort keys %{$self->{'FORMAT_LIST'}}) {
    print F "\n";
    foreach $fld (GetFldKeys($FLDTYPE_FORMAT)) {
      print F ucfirst($fld) . ": " .  $self->{'FORMAT_LIST'}->{$format}->{$fld} . "\n"
        if $self->{'FORMAT_LIST'}->{$format}->{$fld};
    }
  }

  close F or carp "Can't close $file: $!";

  rename $tmpfile, $file or carp "Can't rename $tmpfile to $file: $!";
} # }}}

# merge contents of all available control files for the document
#  into $self->{'MAIN_DATA'} and $self->{'FORMAT_LIST'}
# Fields 'Document' and 'Section' must have the same value in all control files.
# Value of fields 'Author', 'Abstract', 'Title' is taken from the first control file 
#  in which the value is not empty.
# Format sections are joined. It's an error if the same format is defined in more
#  than one control file.
sub MergeCtrlFiles($) { # {{{
  my $self    = shift;

  $self->_read_control_files();

  $self->{'INVALID'}           = 1;
  $self->{'MERGED_CTRL_FILES'} = 1;
  $self->{'MAIN_DATA'}         = {};
  $self->{'FORMAT_LIST'}       = {};

  foreach my $db_file_name ($self->_GetControlFileNames()) {
    my $doc_data = $self->{'CONTROL_FILES'}->{$db_file_name};

    if ($doc_data->document_id() ne $self->document_id()) {
      Warn("Document id in `" . $doc_data->source_file_name() ."' does not match our document id (" .
                  $doc_data->document_id() . ' != ' . $self->document_id() . ")");
      $self->Unregister($doc_data);
      next;
    }

    # merge main sections' fields
    foreach my $fld (GetFldKeys($FLDTYPE_MAIN)) {
      my $old_val = $self->{'MAIN_DATA'}->{$fld};
      my $new_val = $doc_data->GetFldValue($fld);
      if ($new_val) {
        if ($old_val and $old_val ne $new_val and
            ($fld eq $FLD_DOCUMENT or $fld eq $FLD_SECTION)) {
            return Error("Error while merging: inconsistent values of $fld");
          }
        $self->{'MAIN_DATA'}->{$fld} = $new_val unless $old_val;
      }
    }

    # merge formats
    foreach my $format ($doc_data->GetFormatNames()) {
      return Error("format $format already defined") if $self->{'FORMAT_LIST'}->{$format};
      $self->{'FORMAT_LIST'}->{$format} = $doc_data->format($format);
    }
  }
  return unless  %{$self->{'FORMAT_LIST'}};
  $self->{'INVALID'}           = 0;
} # }}}


# Save status changes, calls _write_status_file()
sub SaveStatusChanges($) { # {{{
  my $self = shift;

  $self->_write_status_file();
} # }}}

1;
