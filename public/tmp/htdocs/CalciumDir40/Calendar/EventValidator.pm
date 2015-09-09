# Copyright 2004-2006, Fred Steinberg, Brown Bear Software

# Check event for things like 'in the past', time conflicts

package Database;
use strict;
use Calendar::TimeConflict;

sub validateEvent {
    my $self = shift;
    my %args = (event           => undef,
                op              => undef,
                dateObj         => undef,
                originalEvent   => undef,
                originalDate    => undef,
                ignorePast      => undef,
                ignoreFuture    => undef,
                ignoreConflicts => undef,
                ignoreNoLastMinute => undef,
                ignoreMaxDuration  => undef,
                ignoreMinDuration  => undef,
                @_);
    my $event           = $args{event};
    my $prefs           = Preferences->new ($self);
    my $dateObj         = $args{dateObj};
    my $ignoreFuture    = $args{ignoreFuture};
    my $ignoreConflicts = $args{ignoreConflicts};
    my $ignorePast      = $args{ignorePast};
    my $ignoreLastMinute = $args{ignoreNoLastMinute};
    my $ignoreMaxTime   = $args{ignoreMaxDuration};
    my $ignoreMinTime   = $args{ignoreMinDuration};
    my $originalEvent   = $args{originalEvent};
    my $originalDate    = $args{originalDate};
    my $hasAdmin = $args{op} && Permissions->new ($self)->permitted
                                            ($args{op}->getUsername, 'Admin');

    $event->Prefs ($prefs);     # needed for Time Periods

    my %errHash;

    # Check for required fields
    my $requireds = $prefs->RequiredFields || '';
    my @reqErrs;
    foreach (split ',', $requireds) {
        if (/category/i) {
            push @reqErrs, $_ unless defined $event->category;
        }
        if (/details/i) {
            push @reqErrs, $_ unless defined ($event->popup or $event->link);
        }
        if (/time/i) {
            push @reqErrs, $_ unless $event->hasTime;
        }
    }
    # And required custom fields
    my $fields_lr = $prefs->get_custom_fields;
    my $event_fields_hr = $event->get_custom_fields; # {id => value}
    foreach my $field (@$fields_lr) {
        next unless $field->required;
        my $value = $event_fields_hr->{$field->id};
        # If multi-valued, could be empty list, which is no good
        if (!defined $value
            or ($field->is_multi_valued and !$value)) {
            push @reqErrs, $field->name;
        }
    }

    $errHash{'missing required fields'} = join (',', @reqErrs)
        if @reqErrs;

    # Make sure repeating stuff actually makes sense
    if ($event->isRepeating) {
        my $instances = $event->repeatInfo->nextNOccurrences
                              ($event, 1, $dateObj, $prefs);
        $errHash{'repeating w/no instances'} = 1
            unless keys %$instances;
    }

    if ($prefs->NoPastEditing and (!$ignorePast or !$hasAdmin)) {
        my $now = Date->new;
        # If new event is in past, or editing past event, reject
        if ($dateObj < $now or ($originalDate && $originalDate < $now)) {
            $errHash{'past event'} = 1;
        }
    }

    $errHash{'future limit'} = 1
        if $self->_checkFutureLimit ($event, $prefs, $dateObj, $ignoreFuture,
                                     $hasAdmin);

    # Only check 'last minute' restriction if editing an event.
    # But don't even bother if we've already caught a 'no past editing' error
    if (!$errHash{'past event'} and defined $originalEvent) {
        $errHash{'last minute'} =
          $self->_checkLastMinute ($event, $prefs, $dateObj, $ignoreLastMinute,
                                   $hasAdmin, $originalEvent, $originalDate);
    }

    $errHash{'event too long'} =
        $self->_checkMaxTime ($event, $prefs, $ignoreMaxTime, $hasAdmin);

    $errHash{'event too short'} =
        $self->_checkMinTime ($event, $prefs, $ignoreMinTime, $hasAdmin);

    $errHash{'time conflict'} =
        $self->_checkTimeConflicts ($event, $prefs, $dateObj, $originalEvent,
                                    $ignoreConflicts, $hasAdmin);
    return %errHash;
}

sub _checkFutureLimit {
    my ($self, $event, $prefs, $date, $ignoreFuture, $hasAdmin) = @_;

    return unless $prefs->FutureLimit;
    return if ($prefs->FutureLimit =~ /allow/i);
    return if ($prefs->FutureLimit =~ /warn/i and $ignoreFuture);
    return if ($hasAdmin and $ignoreFuture);       # admin can always do it

    my $futureDate = Date->new;
    my $amount = ($prefs->FutureLimitAmount || 0) + 0;

    my $units = $prefs->FutureLimitUnits;
    ($units =~ /day/i   and $futureDate->addDays   ($amount)) or
    ($units =~ /week/i  and $futureDate->addWeeks  ($amount)) or
    ($units =~ /month/i and $futureDate->addMonths ($amount)) or
    ($units =~ /year/i  and $futureDate->addYears  ($amount));

    return 1 if ($date > $futureDate or
                 ($event->isRepeating and
                  $event->repeatInfo->endDate > $futureDate));
    return;
}

sub _checkLastMinute {
    my ($self, $event, $prefs, $theDate, $ignoreIt, $hasAdmin,
        $origEvent, $origDate) = @_;

    return unless $prefs->NoLastMinute;
    return if ($prefs->NoLastMinute =~ /allow/i);
    return if ($prefs->NoLastMinute =~ /warn/i and $ignoreIt);
    return if ($hasAdmin and $ignoreIt);       # admin can always do it

    # get the epoch time of the event
    my $hour = int (($origEvent->startTime || 0) / 60);
    my $min  =      ($origEvent->startTime || 0) % 60;
    my $seconds = Time::Local::timelocal (0, $min, $hour,
                                          $origDate->day,
                                          $origDate->month - 1,
                                          $origDate->year - 1900);
    # see if it's too late!
    # NoLastMinuteAmount is always in units of hours (so convert to seconds)
    my $now = time;
    if ($now + $prefs->NoLastMinuteAmount * 3600 >= $seconds) {
        return 1;
    }
    return;
}

# See if event is longer then allowed
sub _checkMaxTime {
    my ($self, $event, $prefs, $ignoreIt, $hasAdmin) = @_;

    return unless $prefs->MaxDuration;

    # If no time, or no end time (i.e. no duration), we're ok
    return if (!$event->hasTime or !defined ($event->endTime));

    return if ($prefs->MaxDuration =~ /allow/i);
    return if ($prefs->MaxDuration =~ /warn/i and $ignoreIt);
    return if ($hasAdmin and $ignoreIt);       # admin can always do it

    my $num_minutes = $prefs->MaxDurationAmount || 0;

    my ($start_time, $end_time) =  ($event->startTime, $event->endTime);
    if ($end_time < $start_time) {
        $end_time += 24*60;    # end time is the next day
    }
    my $duration = $end_time - $start_time;
    return ($duration > $num_minutes);
}

# See if event is shorter then allowed
sub _checkMinTime {
    my ($self, $event, $prefs, $ignoreIt, $hasAdmin) = @_;

    return unless $prefs->MinDuration;

    # If no time, that's ok
    return if !$event->hasTime;

    return if ($prefs->MinDuration =~ /allow/i);
    return if ($prefs->MinDuration =~ /warn/i and $ignoreIt);
    return if ($hasAdmin and $ignoreIt);       # admin can always do it

    my $num_minutes = $prefs->MinDurationAmount || 0;

    my ($start_time, $end_time) =  ($event->startTime, $event->endTime);
    $end_time = $start_time if (!defined $end_time);    # 0 duration
    if ($end_time < $start_time) {
        $end_time += 24*60;    # end time is the next day
    }
    my $duration = $end_time - $start_time;
    return ($duration < $num_minutes);
}

sub _checkTimeConflicts {
    my ($self, $event, $prefs, $date, $origEvent, $ignore, $hasAdmin) = @_;

    return unless defined $event->hasTime; # if no time, no conflicts!

    my @dateOccurs = ($date);
    my $alreadyFoundRepeaters;

    my @conflicts;

    return unless $prefs->TimeConflicts;
    return if ($prefs->TimeConflicts =~ /allow/i);
    return if ($prefs->TimeConflicts =~ /warn/i and $ignore);
    return if ($hasAdmin and $ignore);       # admin can always do it

    # if we're a repeating event, must check many instances, not just one.
    # check up to 5 years in advance
    if ($event->isRepeating) {
        my $repeatObject = $event->repeatInfo;
        my %occurences;
        my $endDate = $repeatObject->endDate;
        $endDate = $repeatObject->startDate + 365*5
            if ($repeatObject->startDate->deltaDays ($endDate) > 365*5);
        $event->addToDateHash (\%occurences, $repeatObject->startDate,
                              $endDate, $prefs);
        my @dates = map {Date->new ($_)} keys %occurences;
        @dateOccurs = sort {$a <=> $b} @dates;
    }

    my $editedEventID = $origEvent ? $origEvent->id : undef;

    foreach my $thisDate (@dateOccurs) {
       if (my @conflicters = $event->conflicts ($self, $thisDate,
                                                $editedEventID)) {
            foreach (@conflicters) {
                push @conflicts, [$_, $thisDate];
            }
        }
    }

    # Return list of conflicting event/date pairs. oy.
    return \@conflicts
        if @conflicts;
    return;
}

1;
