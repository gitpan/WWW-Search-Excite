# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use ExtUtils::testlib;

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..6\n"; }
END {print "not ok 1\n" unless $loaded;}
use WWW::Search::Excite;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $iTest = 2;

my $sEngine = 'Excite';
my $oSearch = new WWW::Search($sEngine);
print ref($oSearch) ? '' : 'not ';
print "ok $iTest\n";

use WWW::Search::Test;

# This test returns no results (but we should not get an HTTP error):
$iTest++;
$oSearch->native_query($WWW::Search::Test::bogus_query);
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
print STDOUT (0 < $iResults) ? 'not ' : '';
print "ok $iTest\n";

# This query returns 1 page of results:
$iTest++;
$oSearch->native_query(WWW::Search::escape_query('+LS'.'AM +replic'.'ation'));
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
# print STDERR " + got $iResults results for +LSAM +replication\n";
if (($iResults < 2) || (49 < $iResults))
  {
  print STDOUT 'not ';
  print STDERR " --- got $iResults results for 'bunduki', but expected 2..49\n";
  }
print "ok $iTest\n";

# This query returns 2 pages of results:
$iTest++;
$oSearch->native_query(WWW::Search::escape_query('+Thurn +topp'.'s'));
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
# print STDERR " + got $iResults results for +Thurn +topps\n";
if (($iResults < 51) || (99 < $iResults))
  {
  print STDOUT 'not ';
  print STDERR " --- got $iResults results for 'bunduki', but expected 51..99\n";
  }
print "ok $iTest\n";

# This query returns 1 page of results:
$iTest++;
$oSearch->native_query('bundu'.'ki');
@aoResults = $oSearch->results();
$iResults = scalar(@aoResults);
if ($iResults < 101)
  {
  print STDOUT 'not ';
  print STDERR " --- got $iResults results for 'bunduki', but expected > 101\n";
  }
print "ok $iTest\n";
