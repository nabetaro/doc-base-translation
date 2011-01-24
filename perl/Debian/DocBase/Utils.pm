# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Utils.pm 209 2011-01-24 22:44:21Z robert $
#

package Debian::DocBase::Utils;

use Exporter();
use strict;
use warnings;

use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(Execute HTMLEncode HTMLEncodeDescription Inform Debug Warn Error ErrorNF Fatal
            IgnoreSignals RestoreSignals SetupSignals ReadMap);

use Debian::DocBase::Common;
use Debian::DocBase::Gettext;

sub HTMLEncode($) { # {{{
  my $text        = shift;

  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/"/&quot;/g;
  return $text;
} # }}}

sub HTMLEncodeDescription($) { # {{{
  my $text        = shift;

  $text = HTMLEncode($text);
  my @lines=split(/\n/, $text);
  $text = "";
  my $in_pre = 0;
  foreach $_  (@lines) {
    s/^\s//;
    if (/^\s/) {
      $_ = "<pre>\n$_" unless $in_pre;
      $in_pre = 1;
    } else {
      $_ = "$_\n<\\pre>" if $in_pre;
      $in_pre = 0;
    }
    s/^\.\s*$/<br>&nbsp;<br>/;
    s/(http|ftp)s?:\/([\w\/~\.%#-])+[\w\/]/<a href="$&">$&<\/a>/g;

    $text .= $_ . "\n";
   }
  $text .= "</pre>\n" if $in_pre;
  return $text;
} # }}}

sub Execute(@) { # {{{
  my @args = @_;
  my $sargs = join " ", @args;

  Fatal (_g("Internal error: no arguments passed to Execute()")) if $#args < 0;

  if (-x $args[0]) {
    Debug (_g("Executing `%s'"), $sargs);
    if (system(@args) != 0) {
      Warn (_g("Error occured during execution of `%s'"), $sargs);
    }
  } else {
    Debug (_g("Skipping execution of `%s'"), $sargs);
  }
} # }}}


sub Debug(@) { # {{{
  printf STDOUT  ((shift) . "\n", @_) if $opt_debug;
} #  }}}

sub  Inform(@) { # {{{
  printf STDOUT ((shift) . "\n", @_);
} # }}}

sub Warn(@) { # {{{
  printf STDERR ((shift) . "\n", @_) if $opt_verbose;
} # }}}

sub Error(@) { # {{{
  printf STDERR ((shift) . "\n", @_);
  $exitval = 1;
} # }}}

# non-fatal error - doesn't set exitval
sub ErrorNF(@) { # {{{
  printf STDERR ((shift) . "\n", @_);
} # }}}

# fatal error, runs $on_fatal_handler and exits
sub Fatal(@) { # {{{
  printf STDERR ((shift) . "\n", @_);
  if ($on_fatal_handler)
  {
    Debug(_g("Running fatal errors handler"));
    my $handler = $on_fatal_handler;
    $on_fatal_handler = undef;
    $handler->();
  }
  exit (2);
} # }}}

{ # Signal handling routines - IgnoreSignals, RestoreSignals, SetupSignals # {{{

sub _SigHandler { # {{{
  Fatal(_g("Signal %s received, terminating."), shift);
} # }}}

our %sigactions = ('ignore_cnt' => 0);

sub _IgnoreRestoreSignals($) { # {{{
  my $mode      = shift;

  my $ign_cnt   = undef;


  if ($mode eq "ignore") {
    $ign_cnt = $sigactions{'ignore_cnt'}++;
  } elsif ($mode eq "restore") {
    $ign_cnt = --$sigactions{'ignore_cnt'};
  } elsif ($mode ne "setup") {
     Fatal(_g("Internal error: invalid argument of IgnoreRestoreSignals: %s"), $mode);
  }

  if ($mode ne "setup")
  {
    Fatal( _g("Internal error: invalid ign_cnt (%d) in IgnoreRestoreSignals(%s)"), $ign_cnt, $mode)
      if $ign_cnt < 0;

    return unless $ign_cnt == 0;
  }

  Debug(ucfirst $mode . " signals");

  foreach my $sig ('INT', 'QUIT', 'HUP', 'TSTP', 'TERM') {
    if ($mode eq "ignore") {
      $sigactions{$sig} = $SIG{$sig} if defined $SIG{$sig};
      $SIG{$sig} = "IGNORE";
    } elsif ($mode eq "restore") {
      $SIG{$sig} = defined $sigactions{$sig} ? $sigactions{$sig} : "DEFAULT";
    } elsif ($mode eq "setup") {
      $SIG{$sig} = \&_SigHandler;
    } else {
      Fatal(_g("Invalid argument of IgnoreRestoreSignals: %s"), $mode);
    }
  }
} # }}}

sub IgnoreSignals() {
  return _IgnoreRestoreSignals("ignore");
}


sub RestoreSignals() {
  return _IgnoreRestoreSignals("restore");
}

sub SetupSignals() {
  return _IgnoreRestoreSignals("setup");
}
} # }}}


sub ReadMap($$;$) { # {{{
  my $file    = shift;
  my $map     = shift;
  my $defval  = shift;
  $defval     = "" unless $defval;
  open (MAP, "<", $file) or Fatal(_g("Cannot open file `%s' for reading: %s"), $file, $!);
  while(<MAP>) {
          chomp;
          next if /^\s*$/;
          next if /^#/;
          my ($lv,$rv) = split(/\s*:\s*/, $_, 2);
          $map->{lc($lv)} = $rv ? $rv : $defval;
  }
  close(MAP);
} # }}}



1;
