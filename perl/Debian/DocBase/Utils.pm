# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Utils.pm 86 2007-10-24 23:06:43Z robert $
#

package Debian::DocBase::Utils;

use Exporter();
use strict;
use warnings;
use vars qw(@ISA @EXPORT);
use Carp;
@ISA = qw(Exporter);
@EXPORT = qw(Execute HTMLEncode HTMLEncodeDescription Inform Debug Warn Error ErrorNF 
            IgnoreRestoreSignals);

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

sub IgnoreRestoreSignals($$) {
  my $mode      = shift;
  my $actions   = shift;

  Debug(ucfirst $mode . " signals");

  foreach my $sig ('INT', 'QUIT', 'HUP', 'TSTP', 'TERM') {
    if ($mode eq "ignore") {
      $actions->{$sig} = $SIG{$sig} if defined $SIG{$sig};
      $SIG{$sig} = "IGNORE";
    } elsif ($mode eq "restore") {
      $SIG{$sig} = defined $actions->{$sig} ? $actions->{$sig} : "DEFAULT";
    } else {
       croak "Invalid argument of IgnoreRestoreSignals: $mode";
    }       
  }
}

1;
