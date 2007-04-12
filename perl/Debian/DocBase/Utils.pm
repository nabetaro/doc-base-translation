# vim:cindent:ts=2:sw=2:et:fdm=marker:cms=\ #\ %s
#
# $Id: Utils.pm 42 2007-04-12 17:20:09Z robert $
#


package Debian::DocBase::Utils;

use Exporter();
use strict;

use vars qw(@ISA @EXPORT);  
@ISA = qw(Exporter);
@EXPORT = qw(base_name dir_name html_encode html_encode_description);

sub base_name { # {{{
  (my $basename = $_[0]) =~ s#.*/##s;
  return $basename;
} # }}}

sub dir_name { # {{{
  my ($dirname, $basename) = ($_[0] =~ m#^(.*/)?(.*)#s);
  $dirname = './' if not defined $dirname or $dirname eq '';
  $dirname =~ s#(.)/*\z#$1#s;
  unless (length $basename) {
    ($dirname) = ($dirname =~ m#^(.*/)?#s);
    $dirname = './' if not defined $dirname or $dirname eq '';
    $dirname =~ s#(.)/*\z#$1#s;
  }
  return $dirname;
} # }}}


sub html_encode { # {{{
  my $text        = shift;
  my $do_convert  = shift;

  return $text unless $do_convert;

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

sub html_encode_description { # {{{
  my $text        = shift;
  my $do_convert  = shift;

  return $text unless $do_convert;

  $text = &html_encode($text, $do_convert);
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

1;
