# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Event - vEvent routines for Calcium events

package Event;
use strict;
use Calendar::Date;
use Calendar::vCalendar::vEvent;
use Calendar::Preferences;      # only for repeating events w/COUNT specified

# Returns ($event, $date) ($date same as startDate if repeater)
# Return undef if vEvent has no SUMMARY
# Limitations: only localtime and UTC are supported. Note that we always
#  store events in servers localtime.
sub newFromvEvent {
    my ($class, $vEvent) = @_;

    return (undef, ['', 'no event text']) unless defined $vEvent->summary;

    my %dayMap = (MO => 1,
                  TU => 2,
                  WE => 3,
                  TH => 4,
                  FR => 5,
                  SA => 6,
                  SU => 7);

    my $date = Date->new (@{$vEvent->startDate});
    my $recur = $vEvent->recurrence;
    my $repInfo;
    if ($recur) {
        require Calendar::RepeatInfo;
        my %periodMap = (SECONDLY => undef,
                         MINUTELY => undef,
                         HOURLY   => undef,
                         DAILY    => 'day',
                         WEEKLY   => 'week',
                         MONTHLY  => 'month',
                         YEARLY   => 'year');

        my ($endDate, $period, $frequency, $monthWeek, $monthMonth);

        # COUNT instead of UNTIL handled below
        if ($recur->{UNTIL}) {
            $endDate = Date->new (@{$recur->{UNTIL}});
        } else {
            $endDate = Date->openFuture;
        }

        if ($recur->{FREQ}) {
            $period = $periodMap{$recur->{FREQ}};
        }
        if ($recur->{INTERVAL}) {
            $frequency = $recur->{INTERVAL};
        }
        if ($recur->{BYDAY}) {
            # only relative simple ones; things like
            #  RRULE:FREQ=MONTHLY;BYDAY=MO,-2WE won't work
            my @days = split ',', $recur->{BYDAY};
            my @monthWeek;
            my @daysOfWeek;
            foreach my $dayAndNum (@days) {        # e.g. 3MO,2SU
                $dayAndNum =~ /(-?\d+)*([A-Z][A-Z])/;
                my ($which, $dayName) = ($1, $2);
                # if weekly, save days of week
                if ($period eq 'week') {
                    push @daysOfWeek, $dayMap{$dayName};
                } else {
                    # if no which, it's supposed to be 'every', but we do 1st,
                    # since some ics files are broken.
                    $which ||= 1;
                    $which = 5 if ($which eq -1);
                    push @monthWeek, $which;
                }
            }
            if ($period eq 'week') {
                $period = join (' ', @daysOfWeek)
                    if (@daysOfWeek > 1);
            } else {
                $monthWeek = join ' ', @monthWeek;
                $monthMonth = $frequency;
                if ($period eq 'year') {
                    $monthMonth *= 12;
                }
                undef $period;
            }
        }

        if ($recur->{BYSETPOS}) {         # only works for weeks of month
            my @positions = split ',', $recur->{BYSETPOS};
            my @monthWeek;
            foreach my $posit (@positions) {
                $posit = 5 if ($posit == -1);  # if -1, it's last.
                next if ($posit < 1 or $posit > 5);
                push @monthWeek, $posit;
            }
            $monthWeek = join ' ', sort @monthWeek;
        }

        return (undef, [$vEvent->summary . ' - ', 'bad RRULE'])
            unless ($date and $endDate and
                    ($date <= $endDate) and
                    (($period and $frequency) or
                     ($monthWeek and $monthMonth)));

        $repInfo = RepeatInfo->new ($date, $endDate, $period, $frequency,
                                    $monthWeek, $monthMonth);

        my $exclusions = $vEvent->exceptionDates;
        my @exdates;
        if ($exclusions) {
            foreach my $ymd (@$exclusions) {
                push @exdates, Date->new (@$ymd);
            }
            $repInfo->exclusionList (\@exdates) if @exdates;
        }
    }

    my $endDate = $vEvent->endDate ? Date->new (@{$vEvent->endDate}) : $date;

    # times
    my ($startTime, $endTime);

    if (defined $vEvent->startTime) {
        my $dayShift = 0;
        ($startTime, $dayShift) = _parseTime ($vEvent->startTime);
        $date += $dayShift;

        if (defined $vEvent->endTime) {
            ($endTime, $dayShift) = _parseTime ($vEvent->endTime);
            $endDate += $dayShift;
        } elsif ($vEvent->duration) {
            $endTime = $startTime + int ($vEvent->duration / 60);
        }
    }

    # If a multi-day iCalendar event, make it a repeating one in Calcium
    if (!$recur and $endDate > $date + 1) {
        $repInfo = RepeatInfo->new ($date, $endDate - 1, 'day', 1);
    }

    undef $endTime if (defined $startTime and defined $endTime and
                       $startTime == $endTime);

    my $self = $class->new (text       => $vEvent->summary,
                            startTime  => $startTime,
                            endTime    => $endTime,
                            popup      => $vEvent->description,
                            category   => $vEvent->categories,
                            repeatInfo => $repInfo);

    # If COUNT used instead of UNTIL for repeating event
    # Set end date if COUNT used (RFC allows only one of UNTIL, COUNT)
    if ($repInfo and $recur and $recur->{COUNT}) {
        my $count = $recur->{COUNT};
        $count = 1 if ($count < 1);
        my $weekStart = $dayMap{$recur->{WKST} || 'SU'};  # default to Sunday
        my $prefs = Preferences->new ({StartWeekOn => $weekStart});
        my $hash = $repInfo->nextNOccurrences ($self, $count, $date, $prefs);
        my @dates = sort  {Date->new($a) <=> Date->new($b)} keys %$hash;
        my $endDate = pop @dates || Date->openFuture;
        $repInfo->endDate ($endDate);
    }

    return ($self, $date);
}

sub _parseTime {
    my $time = shift;
    my ($h, $m, $s) = unpack ("A2A2A2", $time);

    my $dateShift = 0;

    # if UTC, convert to local server time
    if ($time =~ /Z$/) {
        use Time::Local;
        my $now = time;
        my $utc   = timegm (gmtime ($now));
        my $local = timegm (localtime ($now));
        my $hours = int (($local - $utc) / 3600);
        $h += $hours;
        if ($h < 0) {
            $dateShift = -1;
            $h += 24;
        } elsif ($h > 23) {
            $dateShift = 1;
            $h -= 24;
        }
    }

    # convert times into number of minutes
    my $minutes = $h * 60 + $m + int (($s || 0)/ 60);
    return ($minutes, $dateShift);
}


# Returns vEvent object (or undef on errr)
# $date ignored if repeater
sub vEvent {
    my ($self, $date) = @_;

    my $privacy;
    if ($self->export) {
        $privacy = uc ($self->export);
        $privacy = 'CONFIDENTIAL'
            if ($privacy =~ /NOPOPUP|UNAVAILABLE|OUTOFOFFICE/);
        undef $privacy unless ($privacy =~ /PUBLIC|PRIVATE|CONFIDENTIAL/);
    }

    my ($startDate, $repeatInfo);
    if ($self->isRepeating) {
        $repeatInfo = $self->repeatInfo;
        $startDate = $repeatInfo->startDate;
    } else {
        # if $date not a Date, make it a Date
        $date = Date->new ($date) unless ref ($date);
        $startDate = $date;
    }

    # If Start Time, DTEND is End Time (same as start time if no end time.)
    # If no Start Time (i.e. "All Day", DTEND is tomorrow.) Although not
    #  recommended practice, this is what Outlook requires
    my $dtstart = sprintf ("%4d%02d%02d", $startDate->ymd);
    my $dtend;
    if (defined $self->startTime) {
        my $startTime = $self->startTime;
        my ($hour, $minute) = (int ($startTime / 60), $startTime % 60);
        $dtstart .= sprintf ("T%02d%02d00", $hour, $minute);

        if (!defined $self->endTime) {
            $dtend = $dtstart;
        } else {
            my $endTime = $self->endTime;
            # Might be on next day
            if ($endTime < $startTime) {
                $dtend = sprintf ("%4d%02d%02d", ($startDate + 1)->ymd);
            } else {
                $dtend = sprintf ("%4d%02d%02d", $startDate->ymd);
            }
            my ($hour, $minute) = (int ($endTime / 60), $endTime % 60);
            $dtend .= sprintf ("T%02d%02d00", $hour, $minute);
        }
    } else {
        $dtend = sprintf ("%4d%02d%02d", ($startDate + 1)->ymd);
    }

    my ($recur, $endDate, $exdates);
    if ($self->isRepeating) {
        my @dayNames = qw /foo MO TU WE TH FR SA SU/;

        # recur rule, e.g. "FREQ=YEARLY;INTERVAL=1;BYDAY=2MO;BYMONTH=10"
        my ($until, $freq, $interval, $byDay, $byMonthDay, $bySetPos);

        # until
        if ($repeatInfo->endDate != Date->openFuture) {
            $until = sprintf ("UNTIL=%4d%02d%02d", $repeatInfo->endDate->ymd);
        }

        if ($repeatInfo->frequency and $repeatInfo->period) {
            if (ref $repeatInfo->period) { # if list of days of week
                $freq = 'WEEKLY';
                $byDay = 'BYDAY=';
                foreach (@{$repeatInfo->period}) {
                    $byDay .= "$dayNames[$_],";
                }
                chop $byDay; # remove last ,
            } else {
                $freq = {day   => 'DAILY',
                         dayBanner => 'DAILY',
                         week  => 'WEEKLY',
                         month => 'MONTHLY',
                         year  => 'YEARLY'}->{$repeatInfo->period};
            }

            $interval = $repeatInfo->frequency;

            # Outlook requires BYMONTHDAY, though spec says it doesn't. Doh.
            if ($freq eq 'MONTHLY') {
                my $monthDay = $startDate->day;
                $byMonthDay = "BYMONTHDAY=$monthDay";
            }
        }

        my $mw = $repeatInfo->monthWeek;
        if ($mw) {
            $byDay = 'BYDAY=';
            my $dow = $startDate->dayOfWeek;
            my @weeks = (ref $mw ? @$mw : ($mw));
            foreach my $weekNum (@weeks) {
                $weekNum = -1 if ($weekNum == 5);
                $weekNum =  5 if ($weekNum == 6); # 5th, if there is a 5th.

                if (1) {    # Outlook compatible mode
                    # Outlook only supports 1 of these, e.g. "1st, 3rd" is
                    # rejected
                    $bySetPos  = "BYSETPOS=$weekNum";
                    $byDay    .= "$dayNames[$dow],";
                } else {    # old way; doesn't work for Outlook
                    $byDay .= "$weekNum$dayNames[$dow],";
                }
            }
            chop $byDay; # remove last ,

            $freq     = 'MONTHLY';
            $interval = $repeatInfo->monthMonth;
        }

        $recur = "FREQ=$freq;INTERVAL=$interval";
if (!defined ($freq) or !defined ($interval)) {
    warn "RECUR: $recur\n";
    warn $self->text, "\n";
}
        foreach ($byMonthDay, $byDay, $until, $bySetPos) {
            $recur .= ";$_" if $_;
        }

        my $exclusions = $repeatInfo->exclusionList;
        if ($exclusions and @$exclusions) {
            $exdates = join ',',
                         map {sprintf "%4d%02d%02d", $_->ymd} @$exclusions;
        }
    }

    my @cats = $self->getCategoryList;

    my $vEvent = vEvent->new (summary     => $self->text,
                              description => $self->popup || $self->link,
                              categories  => \@cats,
                              class       => $privacy,
                              dtstart     => $dtstart,
                              dtend       => $dtend,
                              rrule       => $recur,
                              exdates     => $exdates);
    $vEvent;
}

1;
