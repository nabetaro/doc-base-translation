# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Document.pm 84 2007-10-24 20:32:16Z robert $
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
        DOCUMENT_ID   => $documentId,
        ABSTRACT      => undef,
        AUTHOR        => undef,
        TITLE         => undef,
        SECTION       => undef,
        FORMAT_LIST   => {},
        CONTROL_FILE_NAMES  => [], # temporary
        CONTROL_FILE  => undef, # temporary
        STATUS_DICT   => {},
        INVALID       => 1
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

sub abstract() { # {{{
  my $self = shift;
  return "" unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'CONTROL_FILE'}->{'ABSTRACT'};
} # }}}

sub title() { # {{{
  my $self = shift;
  return "" unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'CONTROL_FILE'}->{'TITLE'};
} # }}}

sub section() { # {{{
  my $self = shift;
  return "" unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'CONTROL_FILE'}->{'SECTION'};
} # }}}

sub author() { # {{{
  my $self = shift;
  return "" unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'CONTROL_FILE'}->{'AUTHOR'};
}   # }}}

sub format($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  return undef unless $self->_has_control_files();
  $self->_read_control_files();
  return $self->{'CONTROL_FILE'}->format($format_name);
} # }}}

sub get_status() { # {{{
  my $self = shift;
  my $key  = shift;
  return $self->{'STATUS_DICT'}->{$key};
}   # }}}

sub set_status() { # {{{
  my $self = shift;
  my $key  = shift;
  my $value = shift;
  my $oldvalue = $self->{'STATUS_DICT'}->{$key};

  if (defined $value) {
    $self->{'STATUS_DICT'}->{$key} = $value;
  } else {
     delete $self->{'STATUS_DICT'}->{$key};
  }

  if ( (defined $value xor defined $oldvalue)
       or (defined $value and $value ne $oldvalue) ) {
    $self->_write_status_file();
  } else {
    Debug("Status of $key in " . $self->document_id() . " not changed");
  }    
}   # }}}


sub _has_control_files() { # {{{
  my $self = shift;
  return $#{$self->{'CONTROL_FILE_NAMES'}} > -1;
} # }}}

sub _read_status_file { # {{{
  my $self  = shift;
  my $docid = $self->{'DOCUMENT_ID'};
  my $status_file = "$DATA_DIR/$docid.status";
  if (-f $status_file) {
    Debug ("Reading status file $status_file");
    my $status = {};
    open(S, "<", $status_file)
      or return Error("Cannot open status file $status_file for reading: $!");
    while (<S>) {
      chomp;
      next if /^\s*$/o;
      /^\s*(\S+):\s*(.*\S)\s*$/
        or carp "syntax error in status file: $_" and return;
      $$status{$1} = $2;
    }
    close(S)
      or croak "$status_file: cannot close status file: $!";
  
    push(@{$self->{'CONTROL_FILE_NAMES'}}, $$status{'Control-File'}) if defined $$status{'Control-File'};
    delete $$status{'Control-File'};
     $self->{'STATUS_DICT'} = $status;
  }
  $self->{'INVALID'} = 0;

} # }}}

sub _write_status_file { # {{{
  my $self = shift;
  my $docid = $self->document_id();

  my $status_file     = "$DATA_DIR/$docid.status";
  my $tmp_status_file = "$status_file.tmp";
  Debug ("Writing status information into $status_file");



  open(S, ">", $tmp_status_file)
    or croak "$tmp_status_file: cannot open status file for writing: $!";
  print S "Control-File: $self->{'CONTROL_FILE_NAMES'}[0]\n" if $self->_has_control_files();
  my $status = $self->{'STATUS_DICT'};
  for my $k (sort keys   %$status) {
    print S "$k: $$status{$k}\n";
  }
  close(S) or croak "$tmp_status_file: cannot close status file: $!";

  # remove file if it's empty
  if (-z $tmp_status_file) {
    unlink $tmp_status_file;
    unlink $status_file;
    Debug ("Removing status file $status_file");
  } else {
    rename $tmp_status_file, $status_file 
      or croak "Can't rename $tmp_status_file to $status_file: $!";
  }

} # }}}


sub _read_control_files { # {{{
  my $self = shift;

  $self->{'CONTROL_FILE'} = Debian::DocBase::DocBaseFile->new($self->{'CONTROL_FILE_NAMES'}[0], PARSE_FULL) unless defined $self->{'CONTROL_FILE'};
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
      print "Format: $format_data->{'format'}\n";
      print "Index: $tmp\n" if (defined ($tmp=$format_data->{'index'}));
      print "Files: $tmp\n" if (defined ($tmp=$format_data->{'files'}));
    }      
  }    

  print "\n";
  print "---status-information---\n";
  print "Control-File: $self->{'CONTROL_FILE_NAMES'}[0]\n" if $self->_has_control_files();
  my $status = $self->{'STATUS_DICT'};
  for my $k (sort keys %$status) {
    print "$k: $status->{$k}\n";
  }
} # }}}

sub register() { # {{{
  my $self          = shift;
  my $doc_base_file = shift;

# FIXME: temporary check if two documents have the same id's
# should be replaced with document merging
  if ($#{$self->{'CONTROL_FILE_NAMES'}} == 0) {
    my $oldfile = ${$self->{'CONTROL_FILE_NAMES'}}[0];
    my $newfile = $doc_base_file->source_file_name();
    if ($oldfile ne $newfile and -f $oldfile) {
        my $olddoc = Debian::DocBase::DocBaseFile->new($oldfile, PARSE_GETDOCID);
        if ($olddoc->document_id() eq $self->document_id()) {
          return ErrorNF("Error in `$newfile': Document " . $self->document_id()." already registered by `$oldfile'");
        }
    }
  }      
      
  
  if ($doc_base_file->invalid()) {
    $self->unregister_all(); # FIXME, temporary
    return Warn($doc_base_file->source_file_name() . " contains errors, not registering");
  }    
    
  $self->{'CONTROL_FILE_NAMES'} = [$doc_base_file->source_file_name()];
  $self->{'CONTROL_FILE'} = $doc_base_file;
  $self->_write_status_file();
} # }}}

sub unregister() { # {{{
  my $self          = shift;
  my $doc_base_file = shift;

  Warn("File " . $doc_base_file->source_file_name() . "is not registered, cannot remove")
    if ($#{$self->{'CONTROL_FILE_NAMES'}} < 0);
      

# FIXME: temporary
  $self->unregister_all();  
} # }}}

sub unregister_all() { # {{{
  my $self          = shift;
  my $doc_base_file = shift;

  $self->{'CONTROL_FILE_NAMES'} = [];
  $self->{'CONTROL_FILE'} = {};
  $self->_write_status_file();
} # }}}

1;
