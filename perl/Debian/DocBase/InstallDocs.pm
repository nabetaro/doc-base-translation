#!/usr/bin/perl
# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: InstallDocs.pm 64 2007-04-29 15:07:26Z robert $

package Debian::DocBase::InstallDocs;

use warnings;
use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
our @EXPORT = qw(SetMode InstallDocsMain
                 $MODE_INSTALL $MODE_REMOVE $MODE_STATUS $MODE_REREGISTER $verbose $debug);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Debian::DocBase::Document;
use Debian::DocBase::DocBaseFile;
use Debian::DocBase::Programs::Dhelp;
use Debian::DocBase::Programs::Dwww;
use Debian::DocBase::Programs::Scrollkeeper;


# constants
our $MODE_INSTALL    = 'install';
our $MODE_REMOVE     = 'remove';
our $MODE_REREGISTER = 'reregister';
our $MODE_STATUS     = 'status';

our $mode       = undef;
our @arguments  = undef;
our  $docbasedir="/usr/share/doc-base";
our  $infodir="/var/lib/doc-base/info";



sub SetMode($@) { # {{{
  my $newmode = shift;
  my @args    = @_;


  &croak("Internal error: mode already set: $mode, $newmode") if (defined $mode);

  $mode = $newmode;

  if ($#args == 0 and $args[0] eq '-') {
    # get list from stdin
    @arguments = map {+chomp} <STDIN>;
  }
  else {
    @arguments = @args;
  }

} # }}}


sub InstallDocsMain($) { # {{{
  my $do_dwww_update = shift;

  my $file = undef;
  my $doc  = undef;
  my $docid = undef;
  my $docfile = undef;



  croak("Internal error: Unknown mode") unless defined $mode;

  if ($mode eq $MODE_REREGISTER) { # {{{
      @arguments = &GetAllRegisteredDocumentIDs();
      foreach $docid (@arguments) {
        $doc = Debian::DocBase::Document->new($docid);
        $doc->unregister_all();
      }
      @arguments = &GetAllDocBaseFiles();
  } # }}}

  if ($mode eq $MODE_REMOVE) { # {{{
    foreach $file (@arguments) {
      if ($file !~ /\//) {
        carp ("Ignoring nonregistered document $file") unless -f "$infodir/$file.status";
        $doc     = Debian::DocBase::Document->new($docid);
        $doc->unregister_all();
      } elsif (! -e $file) {
        carp ("Ignoring unregisteration of nonexistant file $file");
      } else {
        $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_GETDOCID);
        $docid   = $docfile->document_id();
        next unless defined $docid;
        $doc     = Debian::DocBase::Document->new($docid);

        $doc->unregister($docfile);
        $doc->write_status();
      } 
    }
  } # }}}

  if ($mode eq $MODE_INSTALL or $mode eq $MODE_REREGISTER) { # {{{
    foreach $file (@arguments) {
      next unless -f $file;
      $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL);
      $docid   = $docfile->document_id();
      next unless defined $docid;
      $doc     = Debian::DocBase::Document->new($docid);

      $doc->register($docfile)   if ($mode eq $MODE_INSTALL or $mode eq $MODE_REREGISTER);
      $doc->write_status();
    }
  } # }}}

  if ($mode eq $MODE_STATUS) { # {{{
    foreach my $docid (@arguments) {
      $doc     = Debian::DocBase::Document->new($docid);
      $doc->display_status_information();
    }
  } # }}}

  if ($mode eq $MODE_INSTALL or $mode eq $MODE_REMOVE or $mode eq $MODE_REREGISTER)  { # {{{
    my @documents = Debian::DocBase::Document->GetDocumentList();
    &RegisterDhelp(@documents);
    &RegisterScrollkeeper(@documents);
    &RegisterDwww(@documents) if $do_dwww_update ;
  } # }}}

  $file = undef;
  $doc  = undef;
  $docid = undef;
  $docfile = undef;
} # }}}


sub GetAllRegisteredDocumentIDs() { # {{{
  my @result = ();
  if (opendir(DIR, $DATA_DIR)) {
    @result = grep { -f "$DATA_DIR/$_" and s|^${DATA_DIR}/(\w+)\.status$|$1|o } readdir(DIR); 
    closedir DIR;
  }  
  return @result;
} # }}}

sub GetAllDocBaseFiles() { # {{{
  my @result = ();
  if (opendir(DIR, $CONTROL_DIR)) {
    @result = grep { -f "$CONTROL_DIR/$_" } readdir(DIR); 
    closedir DIR;
  }  
  return @result;
} # }}}
1;
