# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Document.pm 94 2007-11-26 21:06:42Z robert $
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

sub _get_main_fld($$) {
  my $self = shift;
  my $fld  = shift;

  carp "Internal error: Document " . $self->document_id(). " not yet merged"
    unless $self->{'MERGED_CTRL_FILES'};

  return "" if $self->invalid();

  return "" unless $self->{'MAIN_DATA'}->{$fld};

  return $self->{'MAIN_DATA'}->{$fld};
}



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

sub format($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  return undef unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'FORMAT_LIST'}->{$format_name};
} # }}}

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
                                   } split(/\s*,\s*/, $status->{'Control-File'}) 
                                      if $status->{'Control-File'};

    delete $$status{'Control-File'};
    $self->{'STATUS_DICT'} = $status;
  }
  $self->{'INVALID'} = 0;

} # }}}

sub _write_status_file { # {{{
  my $self  = shift;
  my $docid = $self->document_id();

  my $status_file     = "$DATA_DIR/$docid.status";
  my $tmp_status_file = "$status_file.tmp";
  Debug ("Writing status information into `$status_file'");

  open(S, ">", $tmp_status_file)
    or croak "Cannot open status file `$tmp_status_file' for writing: $!";

  my $control_files = '"' . join('", "', sort keys %{$self->{'CONTROL_FILES'}}) . '"';
  print S "Control-File: $control_files\n" unless $control_files eq '""';

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


sub _read_control_files($) { # {{{
  my $self = shift;

  foreach my $cfname (sort keys %{$self->{'CONTROL_FILES'}}) {
    $self->{'CONTROL_FILE'}->{$cfname} = Debian::DocBase::DocBaseFile->new($cfname, PARSE_FULL)
      unless $self->{'CONTROL_FILES'}->{$cfname};
  }
} # }}}

sub display_status_information { # {{{
  my $self = shift;
  my $docid = $self->document_id();
  my $status_file = "$DATA_DIR/$docid.status";
  return unless -f $status_file;
  print "---document-information---\n";

  $self->_read_control_files();

  my $tmp = undef;
  print "Document: " . $self->document_id() ."\n";
  if ($self->_has_control_files()) {
    print "Abstract: $tmp\n"  if (($tmp = $self->abstract()) ne "");
    print "Author: $tmp\n"    if (($tmp = $self->author()) ne "");
    print "Section: $tmp\n"   if (($tmp = $self->section()) ne "");
    print "Title: $tmp\n"     if (($tmp = $self->title()) ne "");

    for my $format (@SUPPORTED_FORMATS) {
      my $format_data = $self->format($format);
      next unless $format_data;
      print "\n";
      print "---format-description---\n";
      print "Format: $format_data->{$FLD_FORMAT}\n";
      print "Index: $tmp\n" if (defined ($tmp=$format_data->{$FLD_INDEX}));
      print "Files: $tmp\n" if (defined ($tmp=$format_data->{$FLD_FILES}));
    }
  }

  print "\n";
  print "---status-information---\n";
  print "Control-File: " . join(", ", sort keys  %{$self->{'CONTROL_FILES'}}) . "\n"
    if $self->_has_control_files();
  my $status = $self->{'STATUS_DICT'};
  for my $k (sort keys %$status) {
    print "$k: $status->{$k}\n";
  }
} # }}}

sub register() { # {{{
  my $self          = shift;
  my $db_file       = shift;
  my $db_file_name  = $db_file->source_file_name();

  Debug("Registering `$db_file_name'");

  if ($db_file->document_id() ne $self->document_id()) {
    return Error("Invalid doc id");
  }

  if ($db_file->invalid()) {
    delete $self->{'CONTROL_FILES'}->{$db_file_name};
    return Warn($db_file->source_file_name() . " contains errors, not registering");
  }

  $self->{'CONTROL_FILES'}->{$db_file_name} = $db_file;
} # }}}

sub unregister() { # {{{
  my $self          = shift;
  my $db_file       = shift;
  my $db_filename   = $db_file->source_file_name();

  Warn("File `" . $db_filename . "' is not registered, cannot remove")
    unless $self->{'CONTROL_FILES'}->{$db_filename};

  delete $self->{'COMNTROL_FILES'}->{$db_filename};

} # }}}

sub unregister_all() { # {{{
  my $self          = shift;

  Debug('Unregistering all control files from document `' . $self->document_id() . "'");

  $self->{'CONTROL_FILES'} = {};
} # }}}

sub WriteNewCtrlFile() {
  my $self     = shift;
  my $docid    = $self->document_id();
  my $tmpfile  = $VAR_CTRL_DIR . "/." . $docid . ".tmp";
  my $file     = $VAR_CTRL_DIR . "/" . $docid;
  my $fld      = undef;

  if ($self->invalid() && -e $file) {
    Debug("Removing control file $file");
    unlink $file or carp "Can't remove $file: $!";
  }
  return if $self->invalid();


  open(F, '>', $tmpfile) or
    carp ("Can't open $tmpfile for writing: $_");

  foreach $fld (GetFldKeys($FLDTYPE_MAIN)) {
    print F ucfirst($fld) . ": " .  $self->{'MAIN_DATA'}->{$fld} . "\n"
      if $self->{'MAIN_DATA'}->{$fld};
  }

  print F "Control-Files: " . join (' ', sort keys %{$self->{'CONTROL_FILES'}}) . "\n";

  foreach my $format (sort keys %{$self->{'FORMAT_LIST'}}) {
    print F "\n";
    foreach $fld (GetFldKeys($FLDTYPE_FORMAT)) {
      print F ucfirst($fld) . ": " .  $self->{'FORMAT_LIST'}->{$format}->{$fld} . "\n"
        if $self->{'FORMAT_LIST'}->{$format}->{$fld}; 
    }
  }

  close F or carp "Can't close $file: $!";

  rename $tmpfile, $file or carp "Can't rename $tmpfile to $file: $!";
}

sub MergeCtrlFiles($) {
  my $self    = shift;

  $self->_read_control_files();

  $self->{'INVALID'}           = 1;
  $self->{'MERGED_CTRL_FILES'} = 1;
  $self->{'MAIN_DATA'}         = {};
  $self->{'FORMAT_LIST'}       = {};

  foreach my $db_file_name (sort keys %{$self->{'CONTROL_FILES'}}) {
    print STDERR ">>> $db_file_name\n";
    my $doc_data = $self->{'CONTROL_FILES'}->{$db_file_name};

    # merge main sections' fields
    foreach my $fld (GetFldKeys($FLDTYPE_MAIN)) {
      my $old_val = $self->{'MAIN_DATA'}->{$fld};
      my $new_val = $doc_data->GetFldValue($fld);
      if ($new_val) {
        if ($old_val and $old_val ne $new_val and
            ($fld eq $FLD_DOCUMENT or $fld eq $FLD_SECTION)) {
            return Error("merge error");
          }
        $self->{'MAIN_DATA'}->{$fld} = $new_val unless $old_val;
      }
    }

    # merge formats
    foreach my $format ($doc_data->GetFormatNames()) {
      print STDERR ">> $format : " . join (" ", keys %{$self->{'FORMAT_LIST'}}) . "\n";
      return Error("format $format already defined") if $self->{'FORMAT_LIST'}->{$format};
      $self->{'FORMAT_LIST'}->{$format} = $doc_data->format($format);
    }
  }
  $self->{'INVALID'}           = 0;
}


sub SaveStatusChanges($) { # {{{
  my $self = shift;

  $self->_write_status_file();
} # }}}

1;
