# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Utils.pm 88 2007-10-27 22:20:32Z robert $
#

package Debian::DocBase::Utils;

use Exporter();
use strict;
use warnings;
use vars qw(@ISA @EXPORT);
use Carp;
@ISA = qw(Exporter);
@EXPORT = qw(Execute HTMLEncode HTMLEncodeDescription Inform Debug Warn Error ErrorNF 
            IgnoreSignals RestoreSignals);

use Debian::DocBase::Common;

sub HTMLEncode($) { # {{{
  my $text        = shift;

  $text =~ s/&/&amp;/g;
  $text =~ s/</&lt;/g;
  $text =~ s/>/&gt;/g;
  $text =~ s/"/&quot;/g;
  no locale; # always use byte semantics for this regex range
  # We take gratuitous advantage of the first 256 Unicode codepoints
  # happening to coincide with ISO-8859-1 so that we can HTML-encode
  # ISO-8859-1 characters without using any non-pragmatic modules.
  $text =~ s/([^\0-\x7f])/sprintf('&#%d;', ord $1)/eg;
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

  croak "Internal error: no arguments passed to Execute" if $#args < 0;

  if (-x $args[0]) {
    Debug ("Executing `$sargs'");
    if (system(@args) != 0) {
      Warn ("error occured during execution of `$sargs'");
    }
  } else {
    Debug ("Skipping execution of `$sargs'");
  }   
} # }}}


sub Debug($) { # {{{
  print STDOUT (join ' ', @_ ) . "\n" if $opt_debug;
} # }}}

sub Inform($) { # {{{
  print STDOUT (join ' ', @_) . "\n";
} # }}}

sub Warn($) { # {{{
  print STDERR (join ' ', @_) . "\n" if $opt_verbose;
} # }}}

sub Error($) { # {{{
  print STDERR (join ' ', @_) . "\n";
  $exitval = 1;
} # }}}

# non-fatal error
sub ErrorNF($) { # {{{
  print STDERR (join ' ', @_) . "\n";
} # }}}

{ # IgnoreSignals, RestoreSignals # {{{
  
our %sigactions = ('ignore_cnt' => 0);

sub _IgnoreRestoreSignals($) { # {{{
  my $mode      = shift;

  my $ign_cnt   = undef;


  if ($mode eq "ignore") {
    $ign_cnt = $sigactions{'ignore_cnt'}++;
  } elsif ($mode eq "restore") {
    $ign_cnt = --$sigactions{'ignore_cnt'};
  } else {  
     croak "Invalid argument of IgnoreRestoreSignals: $mode";
  }       
  
  croak "Invalid ign_cnt (" . $ign_cnt . ") in IgnoreRestoreSignals(" . $mode . ")"
    if $ign_cnt < 0;

  return unless $ign_cnt == 0;

  Debug(ucfirst $mode . " signals");

  foreach my $sig ('INT', 'QUIT', 'HUP', 'TSTP', 'TERM') {
    if ($mode eq "ignore") {
      $sigactions{$sig} = $SIG{$sig} if defined $SIG{$sig};
      $SIG{$sig} = "IGNORE";
    } elsif ($mode eq "restore") {
      $SIG{$sig} = defined $sigactions{$sig} ? $sigactions{$sig} : "DEFAULT";
    } else {
       croak "Invalid argument of IgnoreRestoreSignals: $mode";
    }       
  }
} # }}}

sub IgnoreSignals() {
  return _IgnoreRestoreSignals("ignore");
}


sub RestoreSignals() {
  return _IgnoreRestoreSignals("restore");
}
} # }}}
1;
