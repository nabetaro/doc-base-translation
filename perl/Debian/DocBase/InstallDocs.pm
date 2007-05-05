#!/usr/bin/perl
# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: InstallDocs.pm 67 2007-05-05 07:19:44Z robert $

package Debian::DocBase::InstallDocs;

use warnings;
use strict;

use base qw(Exporter);
use vars qw(@EXPORT);
our @EXPORT = qw(SetMode InstallDocsMain
                 $MODE_INSTALL $MODE_REMOVE $MODE_STATUS $MODE_REREGISTER $MODE_CHECK 
                 $verbose $debug);

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
our $MODE_CHECK      = 'check';

our $mode       = undef;
our @arguments  = undef;
our  $docbasedir="/usr/share/doc-base";
our  $infodir="/var/lib/doc-base/info";



sub SetMode($@) { # {{{
  my $newmode = shift;
  my @args    = @_;


  &croak("Internal error: mode already set: $mode, $newmode") if (defined $mode);

  $mode = $newmode;

  &Inform("Value of --rootdir option ignored") if ($mode ne $MODE_CHECK) and ($opt_rootdir ne "");

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
      &Inform("Removing " . ($#arguments + 1) . " registered documents") unless $#arguments < 0;
      foreach $docid (@arguments) {
        $doc = Debian::DocBase::Document->new($docid);
        $doc->unregister_all();
      }
      @arguments = &GetAllDocBaseFiles();
      &Inform("Registering " . ($#arguments + 1) . " installed documents") unless $#arguments < 0;
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
      } 
    }
  } # }}}

  if ($mode eq $MODE_INSTALL or $mode eq $MODE_REREGISTER) { # {{{
    foreach $file (@arguments) {
      if (! -f $file) {
        &Error("Can't read doc-base file `$file'");
        next;
      }        
      $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL);
      $docid   = $docfile->document_id();
      next unless defined $docid;
      $doc     = Debian::DocBase::Document->new($docid);

      $doc->register($docfile);
    }
  } # }}}

  if ($mode eq $MODE_CHECK) { # {{{
    foreach $file (@arguments) {
      if (! -f $file) {
        &Error("Can't read doc-base file `$file'");
        next;
      }        

      $docfile = Debian::DocBase::DocBaseFile->new($file, PARSE_FULL);
      if ($docfile->invalid()) {
          &Inform("`$file' contains errors, won't be registered");
      } elsif ((my $cnt = $docfile->warn_err_count()) > 0) { 
          &Inform("`$file' contains $cnt warnings or non-fatal errors");
      } else {
          &Inform("No problems found while parsing `$file'");
     }          
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

  # don't fail on reregistering docs
  $exitval = 0 if $mode eq $MODE_REREGISTER;

} # }}}


sub GetAllRegisteredDocumentIDs() { # {{{
  my @result = ();
  if (opendir(DIR, $DATA_DIR)) {
    @result = grep { -f "$DATA_DIR/$_" and s|^(\w+)\.status$|$1|o } readdir(DIR); 
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
