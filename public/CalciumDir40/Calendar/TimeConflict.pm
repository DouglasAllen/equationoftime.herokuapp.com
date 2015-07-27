# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Check for Time Conflicts between events

package Event;
use strict;

# Pass operation and event ID of event we're modifying, if we're modifying
# one. (undef otherwise)
# Return list of conflicting events, or undef if no conflict.
sub conflicts {
    my ($self, $db, $date, $oldEventID) = @_;

    my ($startTime, $endTime) = ($self->startTime, $self->endTime);

    return unless defined $startTime;

    my $prefs = Preferences->new ($db);
    my $separation = $prefs->TimeSeparation || 0;

    $self->{_conflictInfo}->{oldEventID} = $oldEventID;
    $self->{_conflictInfo}->{separation} = $separation;
    $self->{_conflictInfo}->{date}       = $date;

    # Get possibly conflicting events
    my @events = $db->getApplicableEvents ($date, $prefs,
                                           'yesterday,noadjust');

    my @conflicters;

    foreach my $event (@events) {
        # don't check against ourself if we're editing an event
        next if ((defined $oldEventID) and ($event->id == $oldEventID));

        my ($start, $end);
        # if stored as period, get time as defined by the period
        if (my $period = $event->timePeriod) {
            my $thePrefs = $prefs;
            if (my $incFrom = $event->includedFrom) {
                $thePrefs = Preferences->new ($incFrom);
            }
            my ($name, $s, $e, $disp) = $thePrefs->getTimePeriod ($period);
            ($start, $end) = ($s, $e);
        }
        # otherwise, get start/end stored w/event
        else {
            ($start, $end) = ($event->startTime, $event->endTime);
        }

        # if from yesterday, adjust start time to midnight today
        if (defined $end and $end < $start and
            $event->Date and $event->Date != $date) {
            $start = 0;
        }

        if (_timeConflict ($start, $end, $startTime, $endTime, $separation)) {
            push @conflicters, $event;
        }
    }

    # If we extend into next day...
    if (defined $endTime and $endTime < $startTime) {
        $startTime = 0;
        my @tomorrow = $db->getApplicableEvents ($date + 1, $prefs,
                                                 'noadjust');

        foreach my $event (@tomorrow) {
            # don't check against ourself if we're editing an event
            next if ((defined $oldEventID) and ($event->id == $oldEventID));

            my ($start, $end);
            # if stored as period, get time as defined by the period
            if (my $period = $event->timePeriod) {
                my $thePrefs = $prefs;
                if (my $incFrom = $event->includedFrom) {
                    $thePrefs = Preferences->new ($incFrom);
                }
                my ($name, $s, $e, $disp) = $thePrefs->getTimePeriod ($period);
                ($start, $end) = ($s, $e);
            }
            # otherwise, get start/end stored w/event
            else {
                ($start, $end) = ($event->startTime, $event->endTime);
            }

            if (_timeConflict ($start, $end,
                               $startTime, $endTime, $separation)) {
                push @conflicters, $event;
            }
        }
    }

    return @conflicters unless $separation;

    # if a separation is specified, and it offsets into the prev/next day,
    # we need to check yesterday (or tomorrow). (Of course an event can run
    # from 12:01-23:59, so we might need to check both ends.)
    my ($previousDay, $nextDay);
    if (($startTime - $separation) < 0) {
        $previousDay = $date - 1;
    }
    if ($endTime and ($endTime + $separation) > 1440) {
        $nextDay = $date + 1;                            # 1440 = 24*60
    }
    return @conflicters unless ($previousDay or $nextDay);

    if ($previousDay) {
        my @events = $db->getApplicableEvents ($previousDay, $prefs,
                                               'noadjust');
        my $startx = $startTime + 1440;
        my $endx   = $endTime ? $endTime + 1440 : undef;
        foreach my $event (@events) {
            if (_timeConflict ($event->startTime, $event->endTime,
                               $startx, $endx, $separation)) {
                $self->{_conflictInfo}->{prevNextString}='on the previous day';
                push @conflicters, $event;
            }
        }
    }

    if ($nextDay) {
        my @events = $db->getApplicableEvents ($nextDay, $prefs, 'noadjust');
        my $startx = $startTime - 1440;
        my $endx   = $endTime ? $endTime - 1440 : undef;
        foreach my $event (@events) {
            if (_timeConflict ($event->startTime, $event->endTime,
                               $startx, $endx, $separation)) {
                $self->{_conflictInfo}->{prevNextString} = 'on the next day';
                push @conflicters, $event;
            }
        }
    }
    return @conflicters;
}

# Assumes start < end for both
sub _timeConflict {
    my ($start, $end, $start2, $end2, $separation) = @_;
    return 0 unless defined $start;

    $end  = $start  if !defined $end;
    $end2 = $start2 if !defined $end2;

    $end  += 1440 if ($end < $start); # ends on next day
    $end2 += 1440 if ($end2 < $start2);

    return 0 if (defined ($end)  and ($end + $separation <= $start2));
    return 0 if (defined ($end2) and ($start >= $end2 + $separation));
    return 1;
}

1;
