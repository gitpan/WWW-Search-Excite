# Excite.pm
# by Martin Thurn
# Copyright (C) 1998 by USC/ISI
# $Id: Excite.pm,v 1.34 2001/08/29 14:51:49 mthurn Exp mthurn $

=head1 NAME

WWW::Search::Excite - backend for searching www.excite.com 

=head1 SYNOPSIS

  use WWW::Search;
  my $oSearch = new WWW::Search('Excite');
  my $sQuery = WWW::Search::escape_query("+sushi restaurant +Columbus Ohio");
  $oSearch->native_query($sQuery);
  while (my $oResult = $oSearch->next_result())
    { print $oResult->url, "\n"; }

=head1 DESCRIPTION

This class is a Excite specialization of WWW::Search.
It handles making and interpreting Excite searches
F<http://www.excite.com>.

This class exports no public interface; all interaction should
be done through L<WWW::Search> objects.

=head1 NOTES

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 CAVEATS

Only returns results from Excite's "Web Results".
Ignores all other sections of Excite's query results.

=head1 BUGS

Please tell the author if you find any!

=head1 AUTHOR

As of 1998-03-23, C<WWW::Search::Excite> is maintained by Martin Thurn
(MartinThurn@iname.com).

C<WWW::Search::Excite> was originally written by Martin Thurn
based on C<WWW::Search::HotBot>.

=head1 LEGALESE

THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=head1 VERSION HISTORY

=head2 2.19, 2001-08-29

Handle yet another new output format

=head2 2.17, 2001-05-17

Handle new output format

=head2 2.16, 2000-11-02

No change in functionality, but parser was totally rewritten using HTML::TreeBuilder

=head2 2.14, 2000-

BUGFIX for missing result-count sometimes;

=head2 2.13, 2000-10-10

BUGFIX for missing result-count sometimes;
BUGFIX for missing END of results;
BUGFIX for mis-parsing URLs

=head2 2.12, 2000-09-18

BUGFIX for still missing the result-count;
BUGFIX for missing all results sometimes

=head2 2.11, 2000-09-05

BUGFIX for still missing some header formats

=head2 2.07, 2000-03-29

BUGFIX for sometimes missing header (and getting NO results)

=head2 2.06, 2000-03-02

BUGFIX for bungled next_url

=head2 2.05, 2000-02-08

testing now uses WWW::Search::Test module;
www.excite.com only allows (up to) 50 per page (and no odd numbers) 

=head2 2.04, 2000-01-28

www.excite.com changed their output format slightly

=head2 2.03, 1999-10-20

www.excite.com changed their output format slightly;
use strip_tags() on title and description results

=head2 2.02, 1999-10-05

now uses hash_to_cgi_string()

=head2 1.12, 1999-06-29

updated test cases

=head2 1.10, 1999-06-11

fixed a BUG where returned URLs were garbled (maybe this was because
www.excite.com changed their links)

=head2 1.08, 1998-11-06

www.excite.com changed their output format slightly (thank you Jim
(jsmyser@bigfoot.com) for pointing it out!)

=head2 1.7, 1998-10-09

use new split_lines function

=head2 1.5

\n changed to \012 for MacPerl compatibility

=head2 1.4

Modified for new Excite output format.

=head2 1.2

First publicly-released version.

=cut

#####################################################################

package WWW::Search::Excite;

require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);

use Carp ();
use HTML::Form;
use HTML::TreeBuilder;
use WWW::Search qw( generic_option strip_tags );
require WWW::SearchResult;

use strict;
use vars qw( $VERSION $MAINTAINER );

$VERSION = '2.19';
$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';

# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;
  my $hits_found = 0;

  # Set some private variables:
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;

  my $DEFAULT_HITS_PER_PAGE = 50;
  # $DEFAULT_HITS_PER_PAGE = 30 if $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  $self->{agent_e_mail} = 'MartinThurn@iname.com';
  $self->user_agent(0);

  $self->{'_next_to_retrieve'} = 0;
  $self->{'_num_hits'} = 0;

  # Remove '*' at end of query terms within the user's query.  If the
  # query string is not escaped (even though it's supposed to be),
  # change '* ' to ' ' at end of words and at the end of the string.
  # If the query string is escaped, change '%2A+' to '+' at end of
  # words and delete '%2A' at the end of the string.
  $native_query =~ s/(\w)\052\s/$1\040/g;
  $native_query =~ s/(\w)\052$/$1\040/g;
  $native_query =~ s/(\w)\0452A\053/$1\053/g;
  $native_query =~ s/(\w)\0452A$/$1/g;

  if (!defined($self->{_options})) 
    {
    $self->{_options} = {
                         'search_url' => 'http://search.excite.com/search.gw',
                         'perPage' => $self->{'_hits_per_page'},
                         'showSummary' => 'true',
                         'start' => $self->{'_next_to_retrieve'},
                         's' => $native_query,
                         'c' => 'web',
                        };
    } # if
  my $options_ref = $self->{_options};
  if (defined($native_options_ref)) 
    {
    # Copy in new options.
    foreach (keys %$native_options_ref) 
      {
      $options_ref->{$_} = $native_options_ref->{$_};
      } # foreach
    } # if

  # Finally, figure out the url.
  $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($options_ref);
  } # native_setup_search


# private
sub native_retrieve_some
  {
  my ($self) = @_;
  my $hits_found = 0;

  # Fast exit if already done:
  return undef unless defined($self->{_next_url});

  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};

  # Get some results, adhering to the WWW::Search mechanism:
  print STDERR " +   sending request (",$self->{_next_url},")\n" if $self->{'_debug'};
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  unless ($response->is_success)
    {
    return undef;
    }

  print STDERR " *   got response\n" if $self->{'_debug'};
  my $sBaseURL = $self->{'_next_url'};
  $self->{'_next_url'} = undef;

  # Parse the output:
  my $tree = new HTML::TreeBuilder;
  $tree->parse($response->content);
  $tree->eof;

  # Look for the result count:
  my @aoTD = $tree->look_down('_tag', 'td');
 TD:
  foreach my $oTD (@aoTD)
    {
    next unless ref $oTD;
    my $sTD = $oTD->as_text;
    # Actual TD tag as of 2001-08-29:
    # <td>Top 50 of about 476,915 found in <font color=#990000><b>Web Sites</b></font> for: <b>Martin Thurn</b></td>
    if ($sTD =~ m!\d of (?:about )?([\d,]+) found!)
      {
      my $sCount = $1;
      $sCount =~ s!,!!g;
      $self->approximate_result_count($sCount);
      last TD;
      } # if
    } # foreach

  # Each URL result is in a <LI> tag:
  my @aoLI = $tree->look_down('_tag', 'li');
 LI:
  foreach my $oLI (@aoLI)
    {
    # Actual LI contents, 2001-08-29:
    # <li><a href="/r/sr=webresult|ss=%22Martin+Thurn%22|c=enus|id=21279083|pos=49;http://www.toymania.com/news/news11_97.shtml" onmouseout="window.status=('');return true" onmouseover="window.status=('http://www.toymania.com/news/news11_97.shtml');return true">Past News and Pictures from the Raving Toy Maniac</a><br> Exclusive Puppetmaster Figures Hot on the heels of the release of the regular Puppetmaster figures from Full Moon Toys, Troll and Toad has announced their release of excluisve, limited edition var...<br><nobr><span class="size8">http://www.toymania.com/news/news11_97.shtml</span> &nbsp; <span class="size8">[<a href="/r/co=xsr_collapse_host;http://search.excite.com/search.gw?search=%22Martin+Thurn%22+site:www.toymania.com">more from this site</a>]</span><br></nobr>

    print STDERR " + LI == ", $oLI->as_HTML if 1 < $self->{'_debug'};
    my $oA = $oLI->look_down('_tag', 'a');
    next unless ref($oA);
    my $sURL = $oA->attr('href');
    $sURL =~ s!\A.+?pos=\d+;!!;
    # print STDERR " +   URL   == $sURL\n" if 1 < $self->{'_debug'};
    my $sTitle = $oA->as_text;
    # Delete tree portion, so the title does not get attached to the
    # description:
    $oA->detach;
    $oA->delete;
    # print STDERR " +   TITLE == $sTitle\n" if 1 < $self->{'_debug'};
    my @aoSPAN = $oLI->look_down('_tag', 'span');
    # Throw away the last <span> tag:
    my $oSPAN = pop @aoSPAN;
    next unless ref $oSPAN;
    $oSPAN->detach;
    $oSPAN->delete;
    # The first span is an abbreviated URL:
    $oSPAN = shift @aoSPAN;
    next unless ref $oSPAN;
    $oSPAN->detach;
    $oSPAN->delete;
    my $sDesc = $oLI->as_text;
    # print STDERR " +   DESC  == $sDesc\n" if 1 < $self->{'_debug'};
    my $hit = new WWW::SearchResult;
    $hit->add_url($sURL);
    $hit->title($sTitle);
    $hit->description($sDesc);
    push(@{$self->{cache}}, $hit);
    $self->{'_num_hits'}++;
    $hits_found++;
    } # foreach $oLI
  # See if there is a NEXT PAGE link:
  my @aoSPAN = $tree->look_down('_tag', 'span',
                                'class' => 'size10',
                               );
 SPAN:
  foreach my $oSPAN (@aoSPAN)
    {
    next unless ref $oSPAN;
    my $sSPAN = $oSPAN->as_HTML;
    my @aoA = $oSPAN->look_down('_tag', 'a');
    # The NEXT PAGE link is the last one on the line:
    my $oA = pop @aoA;
    next SPAN unless ref $oA;
    my $sA = $oA->as_text;
    # print STDERR " +   SPAN  == $sSPAN\n" if 1 < $self->{'_debug'};
    print STDERR " +   A     == $sA\n" if 1 < $self->{'_debug'};
    if ($sA =~ m!next page!i)
      {
      $self->{_next_url} = new $HTTP::URI_CLASS($oA->attr('href'));
      print STDERR " +   mtr   == ", $self->maximum_to_retrieve, "\n" if 1 < $self->{'_debug'};
      last SPAN;
      } # if
    } # foreach $oSPAN
  $tree->delete;
  return $hits_found;
  } # native_retrieve_some

1;

__END__

Martin''s page download notes, 1998-03:

fields on advanced search page:
c	(select) search where: 'web','web.review','timely','web.de','web.fr','web.uk','web.se'
FT_1	(select) 'w' the word(s) or 'p' the phrase for MAY contain
FL_1	(hidden) '3'
FI_1	(text) the search terms (MAY contain)
FT_2	(select) 'w' the word(s) or 'p' the phrase for MUST contain
FL_2	(hidden) '4'
FI_2	(text) search terms (MUST NOT contain)
FT_3	(select) 'w' the word(s) or 'p' the phrase for MUST NOT contain
FL_3	(hidden) '2'
FI_3	(text) search terms (MUST NOT contain)
mode	(hidden) 'advanced'
numFields (hidden) '3'
lk	(hidden) 'default'
sort	(radio) 'relevance' or 'site'
showSummary (select) 'true' titles & summaries or 'false' titles only
perPage (select) '10','20','30','40','50'

simplest pages, normal search:

http://search.excite.com/search.gw?search=Martin+Thurn&start=0&showSummary=true&perPage=50
http://search.excite.com/search.gw?search=Martin+Thurn&start=150&showSummary=true&perPage=50

simplest first page, advanced search:

http://search.excite.com/search.gw?c=web&FT_1=w&FI_1=Christie+Abbott&mode=advanced&numFields=3&sort=relevance&showSummary=true&perPage=50

