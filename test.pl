# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use ExtUtils::testlib;

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..8\n"; }
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
my $MAINTAINER = $oSearch->maintainer;

# Find out where WebSearch is installed:
$iTest++;
my @as = split(/\s/, `WebSearch --VERSION`);
print $? ? 'not ' : '';
print "ok $iTest\n";
my $websearch = shift @as;

$iTest++;
use WWW::Search::Test;
my $oTest = new WWW::Search::Test($sEngine);
$oTest->{websearch} = "$websearch";
unless (ref($oTest))
  {
  print "not ok $iTest\n";
  # Can not continue without Test object:
  exit 0;
  } # unless
print "ok $iTest\n";
# $oTest->{debug} = 1;

$oTest->mode($MODE_EXTERNAL);
$iTest++;
$oTest->test($sEngine, $MAINTAINER, 'zero', $WWW::Search::Test::bogus_query, $TEST_EXACTLY);
print 0 < $o->{error_count} ? 'not ' : '';
print "ok $iTest\n";

$iTest++;
$oTest->test($sEngine, $MAINTAINER, 'one', '+LS'.'AM +replic'.'ation', $TEST_RANGE, 2, 49);
print 0 < $o->{error_count} ? 'not ' : '';
print "ok $iTest\n";

$iTest++;
$oTest->test($sEngine, $MAINTAINER, 'two', '+thurn +topp'.'s', $TEST_RANGE, 51, 99);
print 0 < $o->{error_count} ? 'not ' : '';
print "ok $iTest\n";

$iTest++;
$oTest->test($sEngine, $MAINTAINER, 'three', 'bundu'.'ki', $TEST_GREATER_THAN, 101);
print 0 < $o->{error_count} ? 'not ' : '';
print "ok $iTest\n";
