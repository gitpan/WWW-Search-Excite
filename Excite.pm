# Excite.pm
# by Martin Thurn
# Copyright (C) 1998 by USC/ISI
# $Id: Excite.pm,v 1.25 2000/09/05 13:19:59 mthurn Exp $

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

www.excite.com does not report the approximate result count.

=head1 SEE ALSO

To make new back-ends, see L<WWW::Search>.

=head1 CAVEATS

Only returns results from Excite's "Web Results".
Ignores all other sections of Excite's query results.

=head1 BUGS

Please tell the author if you find any!

=head1 TESTING

This module adheres to the C<WWW::Search> test suite mechanism. 
See the value of $TEST_CASES below.

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
use WWW::Search qw( generic_option strip_tags );
require WWW::SearchResult;

$VERSION = '2.11';
$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';

# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;

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
  
  # Fast exit if already done:
  return undef unless defined($self->{_next_url});
  
  # If this is not the first page of results, sleep so as to not overload the server:
  $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
  
  # Get some results, adhering to the WWW::Search mechanism:
  print STDERR " *   sending request (",$self->{_next_url},")\n" if $self->{'_debug'};
  my $response = $self->http_request('GET', $self->{_next_url});
  $self->{response} = $response;
  unless ($response->is_success) 
    {
    return undef;
    }

  print STDERR " *   got response\n" if $self->{'_debug'};
  $self->{'_next_url'} = undef;
  # Parse the output
  my ($HEADER, $HITS, $URL, $DESC, $DESC2, $TRAILER, $SKIP1, $SKIP2, 
      $SKIP3) = qw( HE HH UR DE D2 TR S1 S2 S3 );
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
 LINE_OF_INPUT:
  foreach ($self->split_lines($response->content()))
    {
    next if m/^$/; # short circuit for blank lines
    print STDERR " *   $state ===$_===" if 2 <= $self->{'_debug'};

    if ($state eq $HEADER && 
        m=^\[(\d+)\s+hits.=)
      {
      # Actual line of input is:
      # [9000 hits. About Your Results]</i></a></small>
      print STDERR "header line (first page)\n" if 2 <= $self->{'_debug'};
      $self->approximate_result_count($1);
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER && 
           (m=^\s*(?:\240|&nbsp;)?\d+-(\d+)\s*$=
            ||
            m!\AWeb\sSite\sResults\s\d+-(\d+)\sfor:!
            ||
            m!\AWeb\sSite\sResults\s\d+-\d+\sof\sabout\s([0-9,]+)\sfor:!))
      {
      # Actual line of input is:
      #  11-20
      # Web Site Results 1-22 for: <b>+LSAM +replication</b>
      # Web Site Results 1-46 of about 46 for: <b>+LSAM +replication</b>
      # Web Site Results 51-100 of about 52,700 for: <b>pikachu</b>
      print STDERR "header line (second/only page)\n" if 2 <= $self->{'_debug'};
      my $iCount = $1;
      $iCount =~ s!,!!g;
      unless (defined($self->approximate_result_count) and 0 < $self->approximate_result_count)
        {
        $self->approximate_result_count($iCount);
        } # unless
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER && 
           m=^\s*Top\s+(<b>)?\d+(</b>)?\s*(Web\s+Site)?$=)
      {
      # Actual line of input is:
      # Top <b>30</b>
      # Top 50 Web Site
      print STDERR "header line (no count)\n" if 2 <= $self->{'_debug'};
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results

    elsif ($state eq $HITS && 
           m=\<SMALL>(\d+)\%=i)
      {
      print STDERR "hit percentage line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <SMALL>92% </SMALL>
      $hit->score($1);
      $state = $URL;
      } # in HITS mode, saw percentage line

    elsif ($state eq $HITS && 
           m!\A(?:<(?:p|li)>\s*)?\<A\s+HREF=\"[^\";]+?;([^\"]+)\">([^\<]+)!i
          )
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual lines of input:
      # <A HREF="http://buteo.colorado.edu/~yosh/psi/system2/aliens/greedo/">Greedo</A>&nbsp;
      # <p> <A HREF="http://search.excite.com/relocate/sr=webresult|ss=pikamew|id=1265183;http://www.geocities.com/TimesSquare/Corridor/2509/geobook.html">Charmeleon's Guestbook</A>&nbsp;
      # Sometimes the </A> is on the next line.
      # Sometimes there is a /r right before the </A>
      # <li> <A HREF="http://search.excite.com/relocate/sr=webresult|ss=Martin+Thurn|id=34046238;http://www.planethalflife.com/radium/sp_reviews/assassin.shtml">|-r a d i u m-|&nbsp;&nbsp;&nbsp;&nbsp;The Half Life Map Center</A>
      if (ref($hit) && $hit->url)
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $self->{'_num_hits'}++;
      $hits_found++;
      $hit->add_url($1);
      $hit->title(strip_tags($2));
      $state = $DESC;
      $state = $SKIP1 if m!<li>!i;
      }

    elsif ($state eq $SKIP1)
      {
      print STDERR "skip1\n" if 2 <= $self->{'_debug'};
      $state = $SKIP2;
      }
    elsif ($state eq $SKIP2)
      {
      print STDERR "skip2\n" if 2 <= $self->{'_debug'};
      $state = $SKIP3;
      }
    elsif ($state eq $SKIP3)
      {
      print STDERR "skip3\n" if 2 <= $self->{'_debug'};
      $state = $DESC2;
      $state = $HITS if m!</li>!;
      }
    elsif ($state eq $DESC2)
      {
      print STDERR "desc2\n" if 2 <= $self->{'_debug'};
      $hit->description(strip_tags($_));
      $state = $HITS;
      }

    elsif ($state eq $DESC && m/^<BR>$/)
      {
      print STDERR "no desc\n" if 2 <= $self->{'_debug'};
      $state = $HITS;
      }
    elsif ($state eq $DESC &&
           (m/^\-\s(.+?)<BR>/ || m/^\-\s(.+)$/)
          )
      {
      print STDERR "hit description line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # - Bootlegs Maintained by Gus Lopez (lopez@halcyon.com) Bootlegs toys and other Star Wars collectibles were made primarily in countries where Star Wars was not commercially released in theaters. Most Star Wars bootlegs originate from the eastern bloc countries: Poland, Hungary, and Russia. <BR><SMALL>http://www.toysrgus.com/images-bootleg.html
      # (The description ends when we see <BR>, or goes to end-of-line if there is no <BR>
      $hit->description(strip_tags($1));
      $state = $HITS;
      } # line is description

    elsif ($state eq $HITS &&
           m/>\s*Show Titles Only\s*</i)
      {
      print STDERR " end of URL list\n" if 2 <= $self->{'_debug'};
      $state = $TRAILER;
      }
    elsif ((($state eq $HITS) || ($state eq $TRAILER)) &&
           m/<INPUT\s[^>]*VALUE=\"Next\sResults\"/i)
      {
      # Actual lines of input include:
      # <INPUT TYPE=submit NAME=next VALUE="Next Results">
      # <input value="Next Results" type="submit" name="next">
      print STDERR " found next button\n" if 2 <= $self->{'_debug'};
      # There is a "next" button on this page, therefore there are
      # indeed more results for us to go after next time.
      # Process the options.
      $self->{'_next_to_retrieve'} += $self->{'_hits_per_page'};
      $self->{'_options'}{'start'} = $self->{'_next_to_retrieve'};
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $self->hash_to_cgi_string($self->{_options});
      $state = $TRAILER;
      last LINE_OF_INPUT;
      }

    else
      {
      print STDERR "didn't match\n" if 2 <= $self->{'_debug'};
      }
    } # foreach line of query results HTML page

  if ($state ne $TRAILER)
    {
    # End, no other pages (missed some tag somewhere along the line?)
    $self->{_next_url} = undef;
    }
  if (ref($hit)) 
    {
    push(@{$self->{cache}}, $hit);
    }
  
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

