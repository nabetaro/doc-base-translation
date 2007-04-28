# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Document.pm 63 2007-04-28 22:41:18Z robert $
#

package Debian::DocBase::Document;

use strict;
use warnings;

use Debian::DocBase::Common;
use Carp;
use Dumpvalue;
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
        CONTROL_FILE  => {}, # temporary
        STATUS_DICT   => {},
        STATUS_CHANGED=> 0
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
  carp "Removing " .$self->document_id() . "\n"
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
  return $self->{'CONTROL_FILE'}->{'ABSTRACT'};
} # }}}

sub title() { # {{{
  my $self = shift;
  return $self->{'CONTROL_FILE'}->{'TITLE'};
} # }}}

sub section() { # {{{
  my $self = shift;
  return $self->{'CONTROL_FILE'}->{'SECTION'};
} # }}}

sub author() { # {{{
  my $self = shift;
  return $self->{'CONTROL_FILE'}->{'AUTHOR'};
}   # }}}

sub get_status() { # {{{
  my $self = shift;
  my $key  = shift;
  return $self->{'STATUS_DICT'}->{$key};
}   # }}}

sub set_status() { # {{{
  my $self = shift;
  my $key  = shift;
  my $value = shift;
  if (defined $value) {
    $self->{'STATUS_DICT'}->{$key} = $value;
  } else {
     delete $self->{'STATUS_DICT'}->{$key};
  }
}   # }}}

sub format($$) { # {{{
  my $self = shift;
  my $format_name = shift;
  return $self->{'CONTROL_FILE'}->format($format_name);
} # }}}

sub status_changed() { # {{{
  my $self = shift;
  return $self->{'STATUS_CHANGED'};
}   # }}}

sub _read_status_file { # {{{
  my $self  = shift;
  my $docid = $self->{'DOCUMENT_ID'};
  my $status_file = "$DATA_DIR/$docid.status";
  return  unless -f $status_file;
###  if (not -f $status_file) {
###    return(0) if $ignore;
###
###    warn "Document `$docid' is not installed.\n";
###    exit 1;
###  }

  my $status = {};
  open(S,"$status_file")
    or die "$status_file: cannot open status file for reading: $!";
  while (<S>) {
    chomp;
    next if /^\s*$/o;
    /^\s*(\S+):\s*(.*\S)\s*$/
      or carp "syntax error in status file: $_" and return;
    $$status{$1} = $2;
  }
  close(S)
    or croak "$status_file: cannot close status file: $!";

  push(@{$self->{'CONTROL_FILE_NAMES'}}, $$status{'Control-File'});
  delete $$status{'Control-File'};
   $self->{'STATUS_DICT'} = $status;

} # }}}

sub write_status { # {{{
  my $self = shift;
  my $docid = $self->document_id();
#  Dumpvalue->new()->dumpValue(\$self);
  return unless $self->status_changed();

  my $status_file = "$DATA_DIR/$docid.status";

  if ($#{$self->{'CONTROL_FILE_NAMES'}} < 0) {
    unlink($status_file) if -e $status_file;
    return;
  }


  open(S,">$status_file")
    or croak "$status_file: cannot open status file for writing: $!";
  print S "Control-File: $self->{'CONTROL_FILE_NAMES'}[0]\n";
  my $status = $self->{'STATUS_DICT'};
  for my $k (sort keys %$status) {
    print S "$k: $$status{$k}\n";
  }
  close(S) or croak "$status_file: cannot close status file: $!";

  $self->{'STATUS_CHANGED'} = 0;
} # }}}

sub display_status_information { # {{{
  my $self = shift;
  my $docid = $self->document_id();
  my $status_file = "$DATA_DIR/$docid.status";
  return unless -f $status_file;
  print "---document-information---\n";
  print "Document: " . $self->document_id() ."\n";
  print "Control-File: $self->{'CONTROL_FILE_NAMES'}[0]\n";
  my $status = $self->{'STATUS_DICT'};
  for my $k (keys %$status) {
    print "$k: $$status{$k}\n";
  }
####  for my  $k (sort keys %$doc_data) {
####    next if $k eq 'document';
####    my $kk = $k;
####    substr($kk,0,1) =~ tr/a-z/A-Z/;
####    print "$kk: $$doc_data{$k}\n";
####  }
####  for my $format_data (@format_list) {
####    print "\n";
####    print "---format-description---\n";
####    print "Format: $$format_data{'format'}\n";
####    for my $k (sort keys %$format_data) {
####      next if $k eq 'format';
####      my $kk = $k;
####      substr($kk,0,1) =~ tr/a-z/A-Z/;
####      print "$kk: $$format_data{$k}\n";
####    }
####  }
####  print "\n";
####  print "---status-information---\n";
####  for my $k (sort keys %status) {
####    print "$k: $status{$k}\n";
####  }
} # }}}

sub register() { # {{{
  my $self          = shift;
  my $doc_base_file = shift;

  $self->{'CONTROL_FILE_NAMES'} = [$doc_base_file->{'FILE_NAME'}];
  $self->{'CONTROL_FILE'} = $doc_base_file;
  $self->{'STATUS_CHANGED'} = 1;
} # }}}

sub unregister() { # {{{
  my $self          = shift;
  my $doc_base_file = shift;

 $self->{'CONTROL_FILE_NAMES'} = [];
 $self->{'CONTROL_FILE'} = {};
 $self->{'STATUS_CHANGED'} = 1;
} # }}}

1;
