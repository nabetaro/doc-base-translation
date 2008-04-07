#!/usr/bin/perl

# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: InstallDocs.pm 129 2008-04-07 18:36:39Z robert $

package Debian::DocBase::InstallDocs;

use warnings;
use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
our @EXPORT = qw(SetMode InstallDocsMain
                 $MODE_INSTALL $MODE_REMOVE $MODE_STATUS $MODE_REMOVE_ALL $MODE_INSTALL_ALL
                 $MODE_INSTALL_CHANGED $MODE_DUMP_DB $MODE_CHECK  $verbose $debug);

use Carp;
use Debian::DocBase::Common;
use Debian::DocBase::Utils;
use Debian::DocBase::Document;
use Debian::DocBase::DocBaseFile;
use Debian::DocBase::DB;
use Debian::DocBase::Programs::Dhelp;
use Debian::DocBase::Programs::Dwww;
use Debian::DocBase::Programs::Scrollkeeper;


# constants
our $MODE_INSTALL         = 1;
our $MODE_REMOVE          = 2;
our $MODE_INSTALL_ALL     = 3;
our $MODE_REMOVE_ALL      = 4;
our $MODE_STATUS          = 5;
our $MODE_CHECK           = 6;
our $MODE_INSTALL_CHANGED = 7;
our $MODE_DUMP_DB         = 8;

# global module variables
our $mode                 = undef;
our @arguments            = undef;



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

  croak("Internal error: Unknown mode") unless defined $mode;

  if ($mode == $MODE_CHECK) {
    _HandleCheck();
  } elsif ($mode == $MODE_STATUS) {
    _HandleStatus();
  } elsif ($mode == $MODE_DUMP_DB) {
    _HandleDumpDB();
  } else {
    _HandleRegistrationAndUnregistation();
  }

  # don't fail on reregistering docs
  $exitval = 0 if    $mode == $MODE_INSTALL_ALL
                  or $mode == $MODE_REMOVE_ALL
                  or $mode == $MODE_INSTALL_CHANGED;

} # }}}


sub _HandleCheck() { # {{{
  foreach my $file (@arguments) {
    if (! -f $file) {
      Error("Can't read doc-base file `$file'");
      next;
    }

    my $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL, 1);
    if ($docfile->invalid()) {
        Inform("$file: Fatal error found, the file won't be registered");
    } elsif ((my $cnt = $docfile->warn_err_count()) > 0) {
        Inform("$file: $cnt warning(s) or non-fatal error(s) found");
    } else {
        Inform("$file: No problems found");
    }
  }
} # }}}

sub _HandleStatus() { # {{{
  foreach my $docid (@arguments) {
    unless (Debian::DocBase::Document::IsRegistered($docid)) {
      Inform ("Document `$docid' is not registered");
      next;
    }
    my $doc = Debian::DocBase::Document->new($docid);
    $doc -> DisplayStatusInformation();
  }
} # }}}

sub _HandleDumpDB() { # {{{
  foreach my $arg (@arguments) {
    if ($arg eq "files.db") {
      Debian::DocBase::DB::GetFilesDB()->DumpDB();
    } elsif ($arg eq "status.db") {  
      Debian::DocBase::DB::GetStatusDB()->DumpDB();
    } else {
      Error("Invalid argument `$arg' passed to --dump-db option");
      exit (1);
    }
  }    
} # }}}

sub _HandleRegistrationAndUnregistation() { # {{{
  my @toinstall     = ();       # list of files to install
  my @toremove      = ();       # list of files to remove
  my @toremovedocs  = ();       # list of docs to remove
  my $bshowmsg      = 0;

  if ($mode == $MODE_INSTALL_CHANGED) {
    $bshowmsg = 1;
    Debian::DocBase::DocBaseFile::GetChangedDocBaseFiles(\@toremove, \@toinstall);
  }

  elsif ($mode == $MODE_REMOVE_ALL or $mode == $MODE_INSTALL_ALL) {
      @toremovedocs  = Debian::DocBase::Document::GetAllRegisteredDocumentIDs();
      $bshowmsg      = 1;
      @toinstall     = Debian::DocBase::DocBaseFile::GetAllDocBaseFiles() if $mode == $MODE_INSTALL_ALL;
  }

  elsif  ($mode == $MODE_INSTALL) {
      @toinstall = @arguments;
  }

  elsif ($mode == $MODE_REMOVE)  {
      @toremove     = grep { /\//  } @arguments;
      @toremovedocs = grep { /^[^\/]+$/ } @arguments; # for backward compatibility  -> arguments are document-ids

  }

  Inform("Removing " . ($#toremovedocs + $#toremove + 2) . " registered documents") if $bshowmsg and (@toremovedocs or @toremove);

  foreach my $docid (@toremovedocs) {
    unless (Debian::DocBase::Document::IsRegistered($docid)) {
      Inform ("Ignoring nonregistered document `$docid'");
      next;
    }
    Debug("Trying to remove document $docid");
    my $doc   = Debian::DocBase::Document->new($docid);
    $doc->UnregisterAll();
  }

  foreach my $file (@toremove) {
    my $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_GETDOCID, $opt_verbose);
    my $docid   = $docfile->GetDocumentID();
    unless ($docid) {
      Inform ("Ignoring nonregistered file `$file'");
      next;
    }
    my $doc = Debian::DocBase::Document->new($docid);
    $doc->Unregister($docfile);
  }


  Inform("Registering " . ($#toinstall + 1) . " installed documents") if $bshowmsg and @toinstall;

  foreach my $file (@toinstall) {
    unless (-f $file) {
      Error("Can't read doc-base file `$file'");
      next;
    }
    Debug("Trying to install file $file");
    my $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL, $opt_verbose);
    my $docid   = $docfile->GetDocumentID();
    next unless defined $docid;
    my $doc     = Debian::DocBase::Document->new($docid);

    $doc->Register($docfile);
  }

  my @documents = Debian::DocBase::Document::GetDocumentList();

  UnregisterDhelp(@documents) unless $mode == $MODE_INSTALL_ALL;

  foreach my $doc (@documents) {
      $doc -> MergeCtrlFiles();
  }

  IgnoreSignals();
  foreach my $doc (@documents) {
    $doc -> WriteNewCtrlFile();
    $doc -> SaveStatusChanges();
  }
  RestoreSignals();

  if (@documents)
  {
    Inform("Registering documents with dwww...") if $bshowmsg;
    RegisterDwww(@documents);
    Inform("Registering documents with dhelp...") if $bshowmsg;
    RegisterDhelp($mode == $MODE_INSTALL_ALL, @documents);
    Inform("Registering documents with scrollkeeper...") if $bshowmsg;
    RegisterScrollkeeper(@documents);
  }     

  undef @toinstall;
  undef @toremove;
  undef @toremovedocs;

} # }}}


1;
