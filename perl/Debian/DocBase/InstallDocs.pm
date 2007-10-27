#!/usr/bin/perl
# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: InstallDocs.pm 88 2007-10-27 22:20:32Z robert $

package Debian::DocBase::InstallDocs;

use warnings;
use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
our @EXPORT = qw(SetMode InstallDocsMain
                 $MODE_INSTALL $MODE_REMOVE $MODE_STATUS $MODE_REMOVE_ALL $MODE_INSTALL_ALL 
                 $MODE_CHECK  $verbose $debug);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Debian::DocBase::Document;
use Debian::DocBase::DocBaseFile;
use Debian::DocBase::Programs::Dhelp;
use Debian::DocBase::Programs::Dwww;
use Debian::DocBase::Programs::Scrollkeeper;


# constants
our $MODE_INSTALL    = 1;
our $MODE_REMOVE     = 2;
our $MODE_INSTALL_ALL= 3;
our $MODE_REMOVE_ALL = 4;
our $MODE_STATUS     = 5;
our $MODE_CHECK      = 6;

our $mode       = undef;
our @arguments  = undef;
our  $docbasedir="/usr/share/doc-base";
our  $infodir="/var/lib/doc-base/info";



sub SetMode($@) { # {{{
  my $newmode = shift;
  my @args    = @_;


  croak("Internal error: mode already set: $mode, $newmode") if (defined $mode);

  $mode = $newmode;

  Inform("Value of --rootdir option ignored") if ($mode != $MODE_CHECK) and ($opt_rootdir ne "");

  if ($#args == 0 and $args[0] eq '-') {
    # get list from stdin
    @arguments = map {+chomp} <STDIN>;
  }
  else {
    @arguments = @args;
  }

} # }}}


sub InstallDocsMain() { # {{{

  my $file = undef;
  my $doc  = undef;
  my $docid = undef;
  my $docfile = undef;



  croak("Internal error: Unknown mode") unless defined $mode;

  if ($mode == $MODE_REMOVE_ALL or $mode == $MODE_INSTALL_ALL) { # {{{
      @arguments = GetAllRegisteredDocumentIDs();
      Inform("Removing " . ($#arguments + 1) . " registered documents") unless $#arguments < 0;
      foreach $docid (@arguments) {
        $doc = Debian::DocBase::Document->new($docid);
        $doc->unregister_all();
      }        
  } # }}}

  if ($mode == $MODE_INSTALL_ALL) { # {{{
    @arguments = GetAllDocBaseFiles();
    Inform("Registering " . ($#arguments + 1) . " installed documents") unless $#arguments < 0;
  } # }}}

  if ($mode == $MODE_REMOVE) { # {{{
    foreach $file (@arguments) {
      if ($file !~ /\//) {
        Inform ("Ignoring nonregistered document $file") unless -f "$infodir/$file.status";
        $doc     = Debian::DocBase::Document->new($file);
        $doc->unregister_all();
      } elsif (! -e $file) {
        Inform ("Ignoring deregisteration of nonexistant file $file");
      } else {
        $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_GETDOCID);
        $docid   = $docfile->document_id();
        next unless defined $docid;
        $doc     = Debian::DocBase::Document->new($docid);

        $doc->unregister($docfile);
      } 
    }
  } # }}}

  if ($mode == $MODE_INSTALL or $mode == $MODE_INSTALL_ALL) { # {{{
    foreach $file (@arguments) {
      if (! -f $file) {
        Error("Can't read doc-base file `$file'");
        next;
      }        
      $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL);
      $docid   = $docfile->document_id();
      next unless defined $docid;
      $doc     = Debian::DocBase::Document->new($docid);

      $doc->register($docfile);
    }
  } # }}}

  if ($mode == $MODE_CHECK) { # {{{
    foreach $file (@arguments) {
      if (! -f $file) {
        Error("Can't read doc-base file `$file'");
        next;
      }        

      $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL);
      if ($docfile->invalid()) {
          Inform("$file: Fatal error found, the file won't be registered");
      } elsif ((my $cnt = $docfile->warn_err_count()) > 0) { 
          Inform("$file: $cnt warning(s) or non-fatal error(s) found");
      } else {
          Inform("$file: No problems found");
     }          
    }
  } # }}}

  if ($mode == $MODE_STATUS) { # {{{
    foreach my $docid (@arguments) {
      $doc     = Debian::DocBase::Document->new($docid);
      $doc->display_status_information();
    }
  } # }}}

  if ($mode == $MODE_INSTALL or $mode == $MODE_REMOVE 
      or $mode == $MODE_INSTALL_ALL or $mode == $MODE_REMOVE_ALL)  { # {{{
    my @documents = Debian::DocBase::Document->GetDocumentList();
    IgnoreSignals();
    foreach my $doc (@documents) {
      $doc -> save_changes();
    }
    RestoreSignals();
    RegisterDhelp(@documents);
    RegisterScrollkeeper(@documents);
    RegisterDwww(@documents);
  } # }}}

  $file = undef;
  $doc  = undef;
  $docid = undef;
  $docfile = undef;

  # don't fail on reregistering docs
  $exitval = 0 if $mode == $MODE_INSTALL_ALL or $mode == $MODE_REMOVE_ALL;

} # }}}


sub GetAllRegisteredDocumentIDs() { # {{{
  my @result = ();
  if (opendir(DIR, $DATA_DIR)) {
    @result = grep { -f "$DATA_DIR/$_" and s|^(\S+)\.status$|$1|o } readdir(DIR); 
    closedir DIR;
  }  
  return @result;
} # }}}

sub GetAllDocBaseFiles() { # {{{
  my @result = ();
  if (opendir(DIR, $CONTROL_DIR)) {
    @result = grep { $_ = "$CONTROL_DIR/$_" if -f "$CONTROL_DIR/$_" } readdir(DIR); 
    closedir DIR;
  }  
  return @result;
} # }}}
1;
