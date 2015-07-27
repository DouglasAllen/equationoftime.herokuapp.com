# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# RepeatInfo

# RepeatInfo holds information needed to handle the repeating part of
# repeating events. An event that repeats would have one of these objects
# in it.

package RepeatInfo;
use strict;
use vars '$AUTOLOAD';
use Calendar::Date;

sub new {
  my $class = shift;
  my ($startDate, $endDate, $period, $frequency,
      $monthWeek, $monthMonth, $skipWeekends) = @_;
  my $self = {};
  bless $self, $class;

  # If you want open-ended repeating, use Date->openPast() and openFuture()
  $self->{'startDate'}  = Date->new ($startDate)  || Date->openPast();
  $self->{'endDate'}    = Date->new ($endDate)    || Date->openFuture();
  $self->{'period'}     = $period     if $period;
  $self->{'frequency'}  = $frequency  if $frequency;
  $self->{'monthWeek'}  = $monthWeek  if $monthWeek;
  $self->{'monthMonth'} = $monthMonth if $monthMonth;
  $self->{'skipWeekends'} = $skipWeekends if $skipWeekends;
  $self->{'monthDay'}   = $self->{'startDate'}->dayOfWeek if $monthWeek;
# $self->{'exclusions'} = [];

  # Fixup the period; either a 'day' (or 'dayBanner'), 'week', 'month', or
  # 'year', or a list of day of the week integers
  if ($period && $period !~ /day|week|month|year/i) {
      my @days = split /\s+/, $self->{'period'};
      $self->{'period'} = \@days;
  }

  # And the same for $monthWeek; either a single int, a space separated list
  if ($monthWeek) {
      my @weeks = split /\s+/, $monthWeek;
      $self->{'monthWeek'} = \@weeks;
  }
  $self;
}

# Get/set methods done by AUTOLOAD
sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;                 # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    # Make sure it's a valid field, eh wot?
    die "Bad Field Name to RepeatInfo! '$name'\n"
        unless {period       => 1,
                frequency    => 1,
                startDate    => 1,
                endDate      => 1,
                monthWeek    => 1,
                monthMonth   => 1,
                monthDay     => 1,
                skipWeekends => 1}->{$name};
#               exclusions

    $self->{$name} = shift if (@_);
    $self->{$name};
}


# See if we land on the specified date
sub applies {
    my $self = shift;
    my ($date) = @_;

    # return false if we're out of range
    return undef unless ($self->{'startDate'} <= $date) and
                        ($self->{'endDate'}   >= $date);

    # return false if this date is in our list of excluded dates (i.e. this
    # date was specifically deleted from the repeating event)
    return undef if $self->excluded ($date);

    # return false if it's a weekend and we're skipping weekends
    return undef if $self->skipWeekends && $date->isWeekend;

    # otherwise see if we fall on the specified date

    # First we check for the Repeat Every Nth (day|week|year) type
    if (defined $self->{'period'} && !ref ($self->{'period'})) {

        # If repeating by day, it's easy.
        if ($self->{'period'} =~ /day/i) {
            # check degenerate case first
            return 1 if $self->{'frequency'} == 1;
            # find how many days since the start; if diff mod freq is 0, a hit
            my $delta = $self->{'startDate'}->deltaDays ($date);
            return !($delta % $self->{'frequency'});
        }

        # If repeating by month or year, it's also easy. Notice first that
        # if the day (and month for year) doesn't match, we return false
        # right away.
        if ($self->{'period'} =~ /month/i) {
            return undef if ($self->{'startDate'}->day() != $date->day());
            return 1 if $self->{'frequency'} == 1;
            # Ok, find how many months apart we are, and mod it by the
            # frequency. Always 12 months in a year.
            my $delta = $self->{'startDate'}->deltaMonths ($date);
            return !($delta % $self->{'frequency'});
        }
        if ($self->{'period'} =~ /year/i) {
            return undef if ($self->{'startDate'}->day()   != $date->day() or
                             $self->{'startDate'}->month() != $date->month());
            return 1 if $self->{'frequency'} == 1;
            my $delta = $self->{'startDate'}->deltaYears ($date);
            return !($delta % $self->{'frequency'});
        }

        if ($self->{'period'} =~ /week/i) {
            return undef if ($self->{'startDate'}->dayOfWeek() !=
                             $date->dayOfWeek());
            return 1 if $self->{'frequency'} == 1;
            my $delta = $self->{'startDate'}->deltaWeeks ($date);
            return !($delta % $self->{'frequency'});
        }

        return undef;

    } elsif (defined $self->{'period'} && ref ($self->{'period'})) {
        # OK, it must be of the repeat on every M,W,F type
        my $dow = $date->dayOfWeek ();
        return undef unless grep {/$dow/} @{$self->{'period'}};
        return 1 if $self->{'frequency'} == 1;
        my $delta = $self->{'startDate'}->deltaWeeks ($date, 1);
        return !($delta % $self->{'frequency'});
    }

    # Well now, me must be repeating in the special month way, e.g. First
    # Tuesday of every 3rd month.
    # Lets see if we're in the right month
    if ($self->{'monthMonth'} > 1) {
        my $delta = $self->{'startDate'}->deltaMonths ($date);
        return undef if ($delta % $self->{'monthMonth'});
    }

    # Ok, we're on the right month, check the nth occurence in month. Note
    # that the 5th occurrence means the last, which might be the 4th.
    # montWeek can be a list, which means, e.g. "1st and 3rd xday"
    foreach (@{$self->{'monthWeek'}}) {
        my $nth = Date->getNthWeekday ($date->year, $date->month,
                                       $self->{'monthDay'}, $_);
        return 1 if ($nth and $date == $nth);
    }
    return undef;
}

# Find all dates this event falls on in the range, add to the hash passed in.
# This is fairly gross, and needs to be rewritten properly.
sub addToDateHash {
    my $self = shift;
    my ($hash, $fromDate, $toDate, $theEvent, $prefs) = @_;

    # return right away if outside our range
    return if (($self->{'startDate'} > $toDate) or
               ($self->{'endDate'}   < $fromDate));

    my $dayChange = 0;              # 0, -1, or 1
    if ($prefs->Timezone and defined ($theEvent->startTime)) {
        my $newStart = $theEvent->startTime + $prefs->Timezone * 60;
        if ($newStart < 0) {
            $dayChange = -1;
        } elsif ($newStart >= 24*60) {
            $dayChange = 1;
        }
    }

    # OK, now the hard part. Do the 'Repeat Every Nth (day|week|year)' type
    if (defined $self->{'period'}) {

        # shouldn't be 0/null, but just in case
        my $frequency = $self->{frequency} || 1;

        # First, find the limits of the range
        # Get date of earliest event we could possibly care about.
        my ($rangeStart, $rangeEnd);
        if ($fromDate <= $self->{'startDate'}) {
            $rangeStart = Date->new ($self->{'startDate'});
        } else {
            $rangeStart = Date->new ($fromDate);
        }

        # Similarly, for latest event.
        if ($toDate > $self->{'endDate'}) {
            $rangeEnd = $self->{'endDate'};
            $rangeEnd++ if ($dayChange > 0);
        } else {
            $rangeEnd = Date->new ($toDate);
        }

        # If repeating by day
        if ($self->{'period'} =~ /day/i) {
            # find how many days since the repeat start to range start
            my $delta = $self->{'startDate'}->deltaDays ($rangeStart);
            my $offset = $delta % $frequency;

            if ($offset) {
                $offset = $frequency - $offset;
            }

            # and add to the hash
            for ($rangeStart += $offset;
                 $rangeStart <= $rangeEnd;
                 $rangeStart += $frequency) {
                my $foo = $dayChange ? $rangeStart + $dayChange : $rangeStart;
                next if ($foo > $rangeEnd);
#               next if $self->excluded ($rangeStart);
#               next if $self->skipWeekends && $rangeStart->isWeekend;
                next if $self->excluded ($foo);
                next if $self->skipWeekends && $foo->isWeekend;
                $hash->{"$rangeStart"} = [] unless $hash->{"$rangeStart"};
                push @{$hash->{"$rangeStart"}}, $theEvent;
            }
            return;
        }

        # If repeating by month
        if ($self->{'period'} =~ /month/i) {
            my $repeatOnDay = $self->{'startDate'}->day();

            # Go to first of next month if we're already past the day of
            # the repeat
            if ($rangeStart->day > $repeatOnDay) {
                $rangeStart = $rangeStart->firstOfMonth->addMonths (1);
                return if ($rangeStart > $rangeEnd);
            }

            # find how many months since the repeat start to range start
            my $delta = $self->{'startDate'}->deltaMonths ($rangeStart);
            # mod by the frequency, to find first month
            my $offset = $delta % $frequency;
            $offset = $frequency - $offset if $offset;

            # and add to the hash
            my $thisDay = $rangeStart;
            $thisDay->addMonths ($offset);
            if ($thisDay->day() > $repeatOnDay) {
                $thisDay->addMonths ($frequency);
            }

            my $theDay = Date->new ($thisDay);
            my $i = 1;
            while ($theDay <= $rangeEnd) {
                # use last day of month, if not enough days in month
                if ($theDay->daysInMonth < $repeatOnDay) {
                    $theDay = Date->new ($theDay->year,
                                          $theDay->month,
                                          $theDay->daysInMonth);
                } else {
                    $theDay = Date->new ($theDay->year(),
                                          $theDay->month(),
                                          $repeatOnDay);
                }
#                unless ($self->excluded ($theDay) or
#                        $self->skipWeekends && $theDay->isWeekend) {
                my $foo = $dayChange ? $theDay + $dayChange : $theDay;
                unless ($self->excluded ($foo) or
                        $self->skipWeekends && $foo->isWeekend) {
                    $hash->{"$theDay"} = [] unless $hash->{"$theDay"};
                    push @{$hash->{"$theDay"}}, $theEvent;
                }
#                next if $self->excluded ($theDay);
#                next if $self->skipWeekends && $theDay->isWeekend;
#                $hash->{"$theDay"} = [] unless $hash->{"$theDay"};
#                push @{$hash->{"$theDay"}}, $theEvent;

                # need this so addMonths adjusts for months with < 31 days
                # if 31st (or 30th for Feb.) is used.
                $theDay = Date->new ($thisDay);
                $theDay->addMonths ($i++ * $frequency);
            }
            return;
        }

        # If repeating by year; one day, every N years
        if ($self->{'period'} =~ /year/i) {
            my $monthDay = Date->new($self->{'startDate'});
            $monthDay->year ($rangeStart->year());

            # If our range is within the same year (typically it will be),
            # return right away unless the repeat date is in our range.
            if ($rangeStart->year() == $rangeEnd->year()) {
                return if ($monthDay < $fromDate) || ($monthDay > $toDate);
            }

            # find how many years from start of repeat to start of range
            my $delta = $self->{'startDate'}->deltaYears ($rangeStart);

            # if range crosses into next year, adjust delta unless we occur
            # in range in the earlier year
            if ($rangeStart->year != $rangeEnd->year and
                $monthDay < $rangeStart) {
                $delta++;
            }

            my $offset = $delta % $frequency;
            if ($offset) {
                $offset = $frequency - $offset;
            }

            my $start = Date->new ($rangeStart);

            # Get correct starting year. What a bother.
            if ($rangeStart > $self->{'startDate'}) {
                $start->month ($self->{'startDate'}->month());
                $start->day   ($self->{'startDate'}->day());
                $start->addYears(1) if ($monthDay < $rangeStart);
            }

            # And add to the hash, if the date falls in our range!
            for ($start->addYears ($offset);
                 $start <= $rangeEnd;
                 $start->addYears ($frequency)) {
#                next if $self->excluded ($start);
#                next if $self->skipWeekends && $start->isWeekend;
                my $foo = $dayChange ? $start + $dayChange : $start;
                next if $self->excluded ($foo);
                next if $self->skipWeekends && $foo->isWeekend;
                $hash->{"$start"} = [] unless $hash->{"$start"};
                push @{$hash->{"$start"}}, $theEvent;
            }
        }

        # If repeating by week; can be 1 day each week, or a list of days
        # of the week. And don't forget about weeks that start on Sunday vs
        # Monday. Oh, such a pain.
        if ($self->{'period'} =~ /week/i or ref ($self->{'period'})) {
            my @dayList;
            if (ref ($self->{'period'})) {
                @dayList = sort @{$self->{'period'}};
            } else {
                push @dayList, $self->{'startDate'}->dayOfWeek;
            }

            my $dayOfWeek = $dayList[0];

            # Set the Repeat Start to be the date of the first specified
            # day (so, if the repeat is specified as M W F, but RepeatStart
            # is a Friday, we go back to Monday. (Unless it's a case like
            # repeat every Sat. and Sun., but start date is a Wednesday;
            # then we go forward.)
            my $repeatStart = Date->new ($self->{'startDate'});
            if ($repeatStart->dayOfWeek > $dayOfWeek) {
                while ($repeatStart->dayOfWeek != $dayOfWeek) {
                    $repeatStart--;
                }
            } else {
                while ($repeatStart->dayOfWeek != $dayOfWeek) {
                    $repeatStart++;
                }
            }

            # Set RangeStart to the first of the week
            my $first = $prefs->StartWeekOn || 7;
            my $theStart = $rangeStart->firstOfWeek ($first);

            # if computed start is same as start of range, go back a week
            # to make sure we get the first instance.
            $theStart -= 7 if ($theStart == $rangeStart);

            # Compute num weeks from Repeat Start to this date, and mod by the
            # frequency, to find the week with the first event
            my $deltaWeeks = $repeatStart->deltaWeeks ($theStart, $first);
            my $offset = $deltaWeeks % $frequency;
            if ($offset) {
                $offset = $frequency - $offset;
            }

            # OK, lets account for weeks that don't start on 1.
            # If not Monday, we assume it starts on Sunday.
            if ($first != 1) {
#               @dayList = map {(($_+7-$first) % 7)+1} @dayList;
                # The GUI only allows starting on Sunday, and don't mod,
                # since we want Sunday and Saturday to stick together...ack

                # Shift each day
                # If multiple days of week, this Sunday is really next week
                if (@dayList > 1) {
                    @dayList = map {$_ + 1} @dayList;
                } else {
                    @dayList = map {$_ == 7 ? 1 : $_ + 1} @dayList;
                }
                $first = 1;
            }

            # Finally, add the ding-dang events
            for ($theStart->addWeeks ($offset);
                 $theStart <= $rangeEnd;
                 $theStart->addWeeks ($frequency)) {
                foreach (@dayList) {
                    my $fnord = Date->new ($theStart - $first + $_);
#                    next if $self->excluded ($fnord);
#                    next if $self->skipWeekends && $fnord->isWeekend;
                    my $foo = $dayChange ? $fnord + $dayChange : $fnord;
                    next if $self->excluded ($foo);
                    next if $self->skipWeekends && $foo->isWeekend;
                    if ($fnord >= $rangeStart and $fnord <= $rangeEnd) {
                        $hash->{"$fnord"} = [] unless $hash->{"$fnord"};
                        push @{$hash->{"$fnord"}}, $theEvent;
                    }
                }
            }
            return;
        }
        return;
    }

    # Well now, me must be repeating in the special month way, e.g. First
    # and Third Tuesday of every 3rd month.

    # Make range as small as needed
    my $theDay = Date->new ($fromDate);
    $theDay = Date->new ($self->{'startDate'})
        if ($theDay < $self->{'startDate'});

    $self->{monthMonth} ||= 1;

    my $delta = $self->{'startDate'}->deltaMonths ($theDay);
    my $offset = $delta % $self->{'monthMonth'};
    $theDay->addMonths (-$offset);

    $toDate = $self->{'endDate'} if ($toDate > $self->{'endDate'});

    while ($theDay <= $toDate) {
        foreach my $n (@{$self->{'monthWeek'}}) {
            my $nth = Date->getNthWeekday ($theDay->year(), $theDay->month(),
                                           $self->{'monthDay'}, $n);
            next unless $nth;
            $theDay = $nth;
#            next if $self->excluded ($theDay);
#            next if $self->skipWeekends && $theDay->isWeekend;
            my $foo = $dayChange ? $theDay + $dayChange : $theDay;
            next if $self->excluded ($foo);
            next if $self->skipWeekends && $foo->isWeekend;
            if ($theDay >= $fromDate and $theDay >= $self->{'startDate'} and
                $theDay <= $toDate) {
                $hash->{"$theDay"} = [] unless $hash->{"$theDay"};
                push @{$hash->{"$theDay"}}, $theEvent;
            }
        }
        $theDay->day(1);
        $theDay->addMonths ($self->{'monthMonth'});
    }
}


# Use this to keep track of which instances of a repeating event we deleted
sub excludeThisInstance {
    my $self = shift;
    my ($date) = @_;
    $self->{exclusions} = [] unless $self->{exclusions};
    push @{$self->{exclusions}}, $date;
}

# Return true if date is in excluded list
sub excluded {
    my $self = shift;
    my ($date) = @_;
    if ($self->{exclusions}) {
        foreach (@{$self->{exclusions}}) {
            return 1 if ($date == $_);
        }
    }
    return undef;
}

# Set or Get list of excluded dates; return ref to list of Date objects
sub exclusionList {
    my $self = shift;
    my $listRef = shift;
    return ($self->{exclusions} || []) unless defined $listRef;
    $self->{exclusions} = $listRef;
}

# Find the next N (e.g. 4) occurrences of a repeating event. We'll be lazy
# and stupid and avoid writing more code by calling addToDateHash. Return a
# ref to a hash w/date=>eventlistref
sub nextNOccurrences {
    my $self = shift;
    my ($event, $n, $startFromDate, $prefs) = @_;

    $n ||= 1;
    $startFromDate ||= Date->new;   # today

    # Guess a toDate based on repeat period. Make it big enough to get
    # enough events, but small enough to not waste time filling the hash
    # w/too many events. E.g., for N=5, repeat by week, the date range will
    # be 150 days, or about 5 months (so "repeat every 5th week" will work.)
    my $size = 7;
    for ($self->period || '') {
        $size =    /day/   && 7
                || /week/  && 30
                || /month/ && 365
                || /year/  && 365*5
                || 7;
    }
    my $toDate = $startFromDate + $n * $size;

    $toDate = $self->endDate if ($toDate > $self->endDate);

    my %hash;

    while (keys %hash < $n and
           $startFromDate <= $self->endDate) {
        $self->addToDateHash (\%hash, $startFromDate, $toDate, $event, $prefs);
        $startFromDate = $toDate + 1;
        $toDate += $n * $size;
        $toDate = $self->endDate if ($toDate > $self->endDate);
    }

    my %returnHash;
    foreach (sort  {Date->new($a) <=> Date->new($b)} keys %hash) {
        $returnHash{$_} = $hash{$_};
        last unless --$n;
    }

    \%returnHash;
}

sub bannerize {
    my $self = shift;
    my $f = $self->frequency || 0;
    my $p = $self->period    || '';
    return ($f == 1 and $p =~ /dayBanner/i);
}

1;
