# Excite.pm
# by Martin Thurn
# Copyright (C) 1998 by USC/ISI
# $Id: Excite.pm,v 1.16 2000/01/28 19:17:48 mthurn Exp $

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

=head2 2.04, 2000-01-28

www.excite.com changed their output format slightly

=head2 2.03, 1999-10-20

www.excite.com changed their output format slightly;
new uses strip_tags() on title and description results

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
$VERSION = '2.04';

use Carp ();
use WWW::Search qw( generic_option strip_tags );
require WWW::SearchResult;

$MAINTAINER = 'Martin Thurn <MartinThurn@iname.com>';
$TEST_CASES = <<"ENDTESTCASES";
&test('Excite', '$MAINTAINER', 'zero', \$bogus_query, \$TEST_EXACTLY);
&test('Excite', '$MAINTAINER', 'one_page', '+L'.'S'.'A'.'M +replic'.'ation', \$TEST_RANGE, 2,49);
&test('Excite', '$MAINTAINER', 'two_page', 'bundu'.'ki', \$TEST_GREATER_THAN, 51);
ENDTESTCASES

# private
sub native_setup_search
  {
  my ($self, $native_query, $native_options_ref) = @_;

  # Set some private variables:
  $self->{_debug} = $native_options_ref->{'search_debug'};
  $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
  $self->{_debug} ||= 0;

  my $DEFAULT_HITS_PER_PAGE = 100;
  $DEFAULT_HITS_PER_PAGE = 30 if $self->{_debug};
  $self->{'_hits_per_page'} = $DEFAULT_HITS_PER_PAGE;

  # Add one to the number of hits needed, because Search.pm does ">"
  # instead of ">=" on line 672!
  my $iMaximum = 1 + $self->maximum_to_retrieve;
  # Divide the problem into N pages of K hits per page.
  my $iNumPages = 1 + int($iMaximum / $self->{'_hits_per_page'});
  if (1 < $iNumPages)
    {
    $self->{'_hits_per_page'} = 1 + int($iMaximum / $iNumPages);
    }
  else
    {
    $self->{'_hits_per_page'} = $iMaximum;
    }

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
                         'search' => $native_query,
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
  my ($HEADER, $HITS, $URL, $DESC, $TRAILER) = qw( HE HH UR DE TR );
  my $hits_found = 0;
  my $state = $HEADER;
  my $hit;
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
           m=^\s*(\240|&nbsp;)?\d+-(\d+)\s*$=)
      {
      # Actual line of input is:
      #  11-20
      print STDERR "header line (second/only page)\n" if 2 <= $self->{'_debug'};
      unless (defined($self->approximate_result_count) and 0 < $self->approximate_result_count)
        {
        $self->approximate_result_count($2);
        } # unless
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results
    elsif ($state eq $HEADER && 
           m=^Top\s<b>\d+</b>$=)
      {
      # Actual line of input is:
      # Top <b>30</b>
      print STDERR "header line (no count)\n" if 2 <= $self->{'_debug'};
      $state = $HITS;
      } # we're in HEADER mode, and line has number of results

    elsif ($state eq $HITS && 
           m=\<SMALL>(\d+)\%=i)
      {
      print STDERR "hit percentage line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <SMALL>92% </SMALL>
      if (ref($hit) && $hit->url)
        {
        push(@{$self->{cache}}, $hit);
        }
      $hit = new WWW::SearchResult;
      $hit->score($1);
      $self->{'_num_hits'}++;
      $hits_found++;
      $state = $URL;
      } # in HITS mode, saw percentage line

    elsif ($state eq $URL && 
           m!\A\<A\s+HREF=\"[^\";]+?;([^\"]+)\">([^\<]+)!i)
      {
      print STDERR "hit url line\n" if 2 <= $self->{'_debug'};
      # Actual line of input:
      # <A HREF="http://buteo.colorado.edu/~yosh/psi/system2/aliens/greedo/">Greedo</A>&nbsp;
      # Sometimes the </A> is on the next line.
      # Sometimes there is a /r right before the </A>
      $hit->add_url($1);
      $hit->title(strip_tags($2));
      $state = $DESC;
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
      my($options) = '';
      foreach (keys %{$self->{_options}}) 
        {
        next if (generic_option($_));
        $options .= $_ . '=' . $self->{_options}{$_} . '&';
        }
      # Finally, figure out the url.
      $self->{_next_url} = $self->{_options}{'search_url'} .'?'. $options;
      $state = $TRAILER;
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

