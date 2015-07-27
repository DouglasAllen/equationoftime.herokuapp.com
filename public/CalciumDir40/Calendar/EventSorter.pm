# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# EventSorter
# Sorts Events using specified criteria

package EventSorter;
use strict;

# Pass list of ordered criteria; zero or more of
#  "text"     - sort by event text, alphabetically
#  "time"     - sort by start time
#  "incFrom"  - sort by included from calendar (not included events first)
#  "category" - sort by category (events w/no category come first
#  "eventID"  - sort by EventID (relatively useless; since each cal has own
#                                set of IDs, won't be in entry order for
#                                included cals)
# If none specified, defaults to ("time", "text")
sub new {
    my ($class, @criteria) = @_;
    push @criteria, ('time', 'text') unless @criteria;
    bless \@criteria, $class;
}

# Single entry to sort a list of Events. Pass a listref of events, returns
# sorted listref
sub sortEvents {
    my ($self, $events) = @_;
    return [] unless @$events;
    my @sorted = sort {$self->sortByCriteria ($a, $b)} @$events;
    return \@sorted;
}

my %sortSubs = (text     => \&_byText,
                time     => \&_byTime,
                incFrom  => \&_byIncFrom,
                category => \&_byCategory,
                eventID  => \&_byEventID);

sub sortByCriteria {
    my ($self, $a, $b) = @_;
    my $ret = 0;
    foreach my $criterium (@$self) {
        my $theSub = $sortSubs{$criterium};
        next unless defined $theSub;
        $ret = $theSub->($a, $b);
        return $ret if $ret;
    }
    return 0; # two events sort equally
}

# Sort first by Event Text
sub _byText {
    my ($e1, $e2) = (@_);
    return (lc($e1->text) cmp lc($e2->text));
}
sub _byTime {
    my ($e1, $e2) = (@_);
    return _timeCompare ($e1, $e2);
}
sub _byIncFrom {
    my ($e1, $e2) = (@_);
    my ($from1, $from2) = ($e1->includedFrom, $e2->includedFrom);
    return _textCompareUndefsFirst ($from1, $from2);
}
sub _byCategory {
    my ($e1, $e2) = (@_);
    my ($cat1, $cat2) = ($e1->primaryCategory, $e2->primaryCategory);
    return _textCompareUndefsFirst ($cat1, $cat2);
}
sub _byEventID {
    my ($e1, $e2) = (@_);
    my ($id1, $id2) = ($e1->id, $e2->id);
    return ($id1 <=> $id2);
}
sub _textCompareUndefsFirst {
    my ($t1, $t2) = (@_);
    return -1 if (!defined $t1 and  defined $t2);
    return  1 if (defined  $t1 and !defined $t2);
    return  0 if (!defined $t1 and !defined $t2);
    return (lc($t1) cmp lc($t2));
}

sub _timeCompare {
    my ($e1, $e2) = (@_);
    my $timeCompare = _compareTimes ($e1, $e2);
    return $timeCompare if $timeCompare;

    if ($e1->isRepeating || $e2->isRepeating) {
        return -1 if (!$e2->isRepeating());
        return  1 if (!$e1->isRepeating());
        # if comparing 2 repeating events, repeat by day comes first
        my ($e1p, $e2p);
        $e1p = $e1->repeatInfo->period || '';
        $e2p = $e2->repeatInfo->period || '';
        return -1 if ($e1p =~ /day/i && $e2p !~ /day/i);
        return  1 if ($e1p !~ /day/i && $e2p =~ /day/i);
        # if both repeat by day, which ever has smallest frequency comes first
        # if both repeat by day, which ever started first comes first
        if ($e1p =~ /day/i && $e2p =~ /day/i) {
            return -1
                if $e1->repeatInfo->frequency < $e2->repeatInfo->frequency;
            return 1
                if $e1->repeatInfo->frequency > $e2->repeatInfo->frequency;
            return -1
                if $e1->repeatInfo->startDate < $e2->repeatInfo->startDate;
            return  1
                if $e1->repeatInfo->startDate > $e2->repeatInfo->startDate;
        }
    }
    return 0;
}

# Routine to be passed to sort to compare events on time. Untimed events
# compare less than timed events. Start time is used, ties broken by end
# time. Not real efficient, so you probably don't want to use this for
# sorting a long list of events.
sub _compareTimes {
    sub compare {
        my ($atime, $btime) = @_;
        return  1 if ($atime  && !$btime);
        return -1 if (!$atime &&  $btime);
        return  0 if (!$atime && !$btime);
        return ($atime <=> $btime);
    }
    my ($e1, $e2) = (@_);
    my $atime = $e1->startTime();
    my $btime = $e2->startTime();
    if ($atime || $btime) {
        my $comp = compare ($atime, $btime);
        return $comp if $comp;

        $atime = $e1->endTime();
        $btime = $e2->endTime();
        return (compare ($atime, $btime));
    }
    return 0;
}

1;
