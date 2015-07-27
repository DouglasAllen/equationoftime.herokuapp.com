# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Handle event entry/edit form submission

package EventFormProcessor;
use strict;
use Calendar::TimeConflict;
use Calendar::EventValidator;   # for Database::validateEvent
use CGI;

# All the fields from the Event Edit Form...and some extras
# (except for those that return multiple values! see below)
my @fields = qw (EventText PopupText ExportPopup BorderCheckbox
                 Category BackgroundColor ForegroundColor

                 DateYearPopup DateMonthPopup DateDayPopup

                 StartHourPopup StartMinutePopup EndHourPopup EndMinutePopup
                 StartHourRadio EndHourRadio TimePeriod

                 RepeatRadio Frequency Period MonthWeek MonthMonth
                 RepeatUntilRadio UntilYearPopup UntilMonthPopup UntilDayPopup
                 SkipWeekends

                 SubscriberAddresses

                 MailTo MailCC MailBCC MailComments NotifySubscribers
                 MailReminder MailReminder2 ReminderAddress

                 MultiCalDisplayed

                 IgnoreTimeConflicts IgnoreFutureLimit IgnoreNoPastEditing
                 IgnoreNoLastMinute IgnoreMaxDuration IgnoreMinDuration

                 OldEventID AllOrOne
                 Date DisplayCal ViewCal DisplayDate

                 CopyEvent DeleteEvent Cancel NextOp FromPopupWindow);
my @multiFields = qw (WhichCalendars MoreCategories);

# self has keys:
#   - op, cgi
sub new {
    my ($class, $op) = @_;
    my $self = {op     => $op,
                cgi    => CGI->new,
                parsed => {},    # compound/computed values, e.g. dates, times
                calPrefs => {},
                badCals  => {},   # keys 'time conflict', 'future limit', etc.
                                  #   vals depend on which error it is
                event    => undef,  # Event object
                isOnlyWarnings => 0,
               };

    # Get vals for all fields
    foreach (@fields) {
        $self->{$_} = $self->{op}->getParams ($_);
    }

    # Fields that return multiple values, i.e. a list
    foreach (@multiFields) {
        my @vals = $self->{cgi}->param ($_);
        $self->{$_} = \@vals;
    }

    # And grab all Custom Fields too. We don't *necessarily* use all
    #  when creating the event though, since they might not actally exist
    # Also, when adding to mult. calendars, we look up fields as defined on
    #  the main calendar
    my $param_hr = $self->{op}->rawParams;
    while (my ($name, $value) = each %$param_hr) {
        next unless $name =~ /^CF-(.+)/;
        my $field_id = $1;
        $self->{customFields}->{$field_id} = $value;
    }
    if ($self->{customFields}) {
        my $prefs = $self->{op}->prefs;
        my $fields_lr = $prefs->get_custom_fields (system => 1);
        # Get values for multi-fields, strip spaces from text fields
        foreach my $field (@$fields_lr) {
            if ($field->is_multi_valued) {
                my @values = $self->{cgi}->param ('CF-' . $field->id);
                $self->{customFields}->{$field->id} = \@values;
            }
            elsif ($field->is_text && $self->{customFields}->{$field->id}) {
                $self->{customFields}->{$field->id} =~ s/^\s+//;
                $self->{customFields}->{$field->id} =~ s/\s+$//;
            }

            # If it's a select, ignore any values that are '-', which is
            # special and means "no choice"
            if ($field->is_select) {
                my $value = $self->{customFields}->{$field->id};
                if ($field->is_multi_valued and ref $value) {
                    my @values = grep {$_ ne '-'} @$value;
                    $self->{customFields}->{$field->id} = \@values;
                } else {
                    if ($value eq '-') {
                        delete $self->{customFields}->{$field->id};
                    }
                }
            }
        }
    }

    # Strip leading/trailing spaces from strings coming from text fields
    foreach (qw /EventText PopupText BackgroundColor ForegroundColor
                 MailTo MailCC MailBCC MailComments
                 ReminderAddress SubscriberAddresses/) {
        next unless defined $self->{$_};
        $self->{$_} =~ s/^\s+//;
        $self->{$_} =~ s/\s+$//;
    }

    if (defined $self->{WhichCalendars}->[0]) {
        $self->{parsed}->{calendars} = $self->{WhichCalendars};
    } else {
        $self->{parsed}->{calendars} = [$self->{op}->calendarName];
    }

    foreach my $calName (@{$self->{parsed}->{calendars}}) {
        $self->{calPrefs}->{$calName} = Preferences->new ($calName);
    }

    bless $self, $class;
}

sub cancelled {
    return shift->{Cancel};
}

sub getValue {
    my ($self, $name) = @_;
    die "Bad param to EventFormProcessor::getValue\n"
        unless ($name =~ /NextOp     | DisplayCal | ViewCal   | DisplayDate |
                          OldEventID | Date       | CopyEvent | DeleteEvent |
                          AllOrOne   | NotifySubscribers | FromPopupWindow /x);
    return $self->{$name};
}

sub getParsedValue {
    my ($self, $name) = @_;
    die "Bad param to EventFormProcessor::getParsedValue\n"
        unless ($name =~ /date|calendars/);
    return @{$self->{parsed}->{calendars}}
        if ($name eq 'calendars');
    return $self->{parsed}->{$name};
}


sub validateFields {
    my $self = shift;
    my @errors;

    # Check for blank event; if no text, see if any custom fields to display
    if (!defined $self->{EventText} or $self->{EventText} eq '') {
        my $field_values_hr   = $self->{customFields};
        my $field_settings_lr = $self->{op}->prefs->get_custom_fields (system =>
                                                                       1);
        my $found_display_text;
        foreach my $field_info (@$field_settings_lr) {
            if ($field_info->display) {
                my $val = $field_values_hr->{$field_info->id};
                if (defined $val and $val ne '') {
                    $found_display_text = 1;
                    last;
                }
            }
        }
        if (!$found_display_text) {
            push @errors, 'blank event';
        }
    }

    push @errors, 'reminder w/no address'
        if (($self->{MailReminder} or $self->{MailReminder2})
            and !$self->{ReminderAddress});

    my ($startTime, $endTime) = $self->_parseTimes;
    $self->{parsed}->{startTime} = $startTime;
    $self->{parsed}->{endTime}   = $endTime;

    my $date = $self->_parseDate;
    push @errors, 'invalid date'
        unless $date;
    $self->{parsed}->{date} = $date;

    my $endDate;
    my $repeatType = $self->{RepeatRadio};
    if ($repeatType and $repeatType !~ /none/i and $repeatType ne '') {
        $endDate = $self->_parseEndDate;
        push @errors, 'invalid repeat until date'
            unless $endDate;
        $self->{parsed}->{endDate} = $endDate;
    }

    if ($date and $endDate and ($date > $endDate)) {
        push @errors, 'start date after end date';
    }

    $self->convertForTimezone  # must do AFTER parsing dates and times
        if $self->{parsed}->{date}; # not if date invalid

    # If multi-cal enabled, ensure at least 1 calendar selected
    push @errors, 'no calendar specified'
        if (($self->{MultiCalDisplayed}) and
            (!$self->{WhichCalendars} or !@{$self->{WhichCalendars}}));

    return @errors;
}

# origEvent and origDate undef unless editing existing event
sub validateEvent {
    my ($self, $event, $origEvent, $origDate) = @_;
    my @errors;

    foreach my $thisCal ($self->getParsedValue ('calendars')) {
        my $theDB = Database->new ($thisCal);
        my %errs = $theDB->validateEvent (
                          event           => $event,
                          op              => $self->{op},
                          dateObj         => $self->{parsed}->{date},
                          originalEvent   => $origEvent, # maybe undef
                          originalDate    => $origDate,  # maybe undef
                          ignorePast      => $self->{IgnoreNoPastEditing},
                          ignoreFuture    => $self->{IgnoreFutureLimit},
                          ignoreConflicts => $self->{IgnoreTimeConflicts},
                          ignoreNoLastMinute => $self->{IgnoreNoLastMinute},
                          ignoreMaxDuration  => $self->{IgnoreMaxDuration},
                          ignoreMinDuration  => $self->{IgnoreMinDuration},
                                         );
        # keep track of which cals had which errors
        while (my ($errName, $data) = each %errs) {
            next unless $data;
            $self->{badCals}->{$errName} ||= {};
            $self->{badCals}->{$errName}->{$thisCal} = $data;
            push @errors, $errName;
        }
    }
    return @errors;
}


sub _parseTimes {
    my $self = shift;
    my $prefs = $self->{op}->prefs;
    my ($startTime, $endTime);

    my $startHour   = $self->{StartHourPopup};
    my $startMinute = $self->{StartMinutePopup};
    my $endHour     = $self->{EndHourPopup};
    my $endMinute   = $self->{EndMinutePopup};
    my $startAmOrPm = $self->{StartHourRadio};
    my $endAmOrPm   = $self->{EndHourRadio};

    $self->{TimePeriod} = undef if ($self->{TimePeriod} and
                                    $self->{TimePeriod} eq '-');
    my $timePeriod  = $self->{TimePeriod};

    # If Time Period specified, start with the defined times
    if (defined $timePeriod) {
        my ($name, $start, $end, $disp) = $prefs->getTimePeriod ($timePeriod);
        return ($start, $end);
    }

    # Otherwise, see if there is a normal time specified.
    # Start/End times are in range [-1..23] for hours, [-1..55] for mins.
    if (defined ($startHour) and $startHour >= 0) {
        $startAmOrPm ||= '';    # undef if military time
        $endAmOrPm   ||= '';

        $startMinute = 0 unless ($startMinute and $startMinute >= 0);
        $startTime   = ($startHour + ($startAmOrPm =~ /pm/i ? 12 : 0)) * 60
                       + $startMinute;

        if ($endHour < 0) {
            $endHour = $endMinute = undef;
        } else {
            $endMinute = 0 unless ($endMinute and $endMinute > 0);
            $endHour   = 0 unless ($endHour and $endHour > 0);
            $endTime   = ($endHour + ($endAmOrPm =~ /pm/i ? 12 : 0)) * 60
                         + $endMinute;
        }
    }
    return ($startTime, $endTime);
}

# Return Date obj, or undef if invalid
sub _parseDate {
    my $self = shift;

    my $dateYear  = $self->{DateYearPopup};
    my $dateMonth = $self->{DateMonthPopup};
    my $dateDay   = $self->{DateDayPopup};

    return Date->new ($dateYear, $dateMonth, $dateDay)
        if (Date->valid ($dateYear, $dateMonth, $dateDay));
    return undef;
}

# Return Date obj, or undef on invalid date
sub _parseEndDate {
    my $self = shift;

    return Date->openFuture
        if ($self->{RepeatUntilRadio} ne ' ');

    my $untilYear  = $self->{UntilYearPopup};
    my $untilMonth = $self->{UntilMonthPopup};
    my $untilDay   = $self->{UntilDayPopup};

    return Date->new ($untilYear, $untilMonth, $untilDay)
        if (Date->valid ($untilYear, $untilMonth, $untilDay));
    return undef;
}

# Return a RepeatObject, or undef if not repeating
sub repeatObject {
    my $self = shift;

    my $repeatType = $self->{RepeatRadio};
    return undef unless ($repeatType and $repeatType =~ /Repeat|ByWeek/i);

    my $period     = $self->{Period};
    my $frequency  = $self->{Frequency};
    my $monthWeek  = $self->{MonthWeek};
    my $monthMonth = $self->{MonthMonth};

    if ($repeatType =~ /ByWeek/i) {
        $period = $frequency = undef;
    } else {    # it must be Repeat Every Third Day type
        $monthWeek = $monthMonth = undef;
    }

    my $repeatObject = RepeatInfo->new ($self->{parsed}->{date},
                                        $self->{parsed}->{endDate},
                                        $period, $frequency,
                                        $monthWeek, $monthMonth,
                                        $self->{SkipWeekends});

    # Adjust end date if necessary due to zone offset
    if ($self->{parsed}->{dateChange} and
        $repeatObject->endDate != Date->openFuture) {
        $repeatObject->endDate ($repeatObject->endDate +
                                $self->{parsed}->{dateChange});
    }

    # if date was changed by timezone offset, and we're repeating by
    # particular days of the week, adjust the days in the object. Yow!
    if ($self->{parsed}->{dateChange} and ref ($repeatObject->period)) {
        foreach my $day (@{$repeatObject->period}) {
            $day += $self->{parsed}->{dateChange};     # 1-7
            if ($day < 1 or $day > 7) {
                $day = $day % 7;
                $day ||= 7;
            }
        }
    }
    return $repeatObject;
}

sub convertForTimezone {
    my $self = shift;
    my $prefs = $self->{op}->prefs;

    # If specified as a Time Period, we don't need to convert anything!
    return if ($self->{TimePeriod});

    return unless (defined $self->{parsed}->{startTime} and $prefs->Timezone);

    my $date      = $self->{parsed}->{date};
    my $startTime = $self->{parsed}->{startTime};
    my $endTime   = $self->{parsed}->{endTime};

    # Convert times and dates based on timezone; always store server time,
    # so server times are returned.
    # Date is always the date startTime is on.
    my $z = $prefs->Timezone;
    my $dateChange = 0; # will set to -1 if we moved to yesterday, +1 if we
                        # moved to tomorrow.

    $startTime -= $z * 60;
    $endTime   -= $z * 60 if (defined $endTime);

    # If start time is yesterday or tomorrow, adjust date
    if ($startTime < 0) {
        $date -= int ($startTime/-1440) + 1;     # 1440 = 24 * 60
        $dateChange = -1;
    } elsif ($startTime >= 24*60) {
        $date += int ($startTime/1440);
        $dateChange = 1;
    }

    $startTime %= 1440;

    if (defined $endTime) {
        $endTime %= 1440;
    }

    $self->{parsed}->{dateChange} = $dateChange;
    $self->{parsed}->{date}       = $date;
    $self->{parsed}->{startTime}  = $startTime;
    $self->{parsed}->{endTime}    = $endTime;
}


# Make new Event from data in form
sub makeEvent {
    my $self = shift;

    # If the popup looks like a URL, we call it a link. Otherwise, a popup!
    # Note that this is not a very good test. But probably good enough.
    # (Basically, anything that is www.x.x, or starts http:, mailto:, ftp:,
    # etc.)
    my ($popup, $link) = Event->textToPopupOrLink ($self->{PopupText});

    my $category = $self->{Category};
    $category = undef if (defined $category and $category eq '-');

    if (my @more_cats = sort @{$self->{MoreCategories}}) {
        my @categories;
        foreach my $cat (@more_cats) {
            next if ($cat eq '-');
            if (!defined $category) { # set primary cat if not specified
                $category = $cat;
            }
            next if ($cat eq $category);
            push @categories, $cat;
        }
        $category = [$category, @categories] if @categories;
    }

    foreach ($self->{BackgroundColor}, $self->{ForegroundColor}) {
        next unless defined;
        s/\s*default\s*//i;    # If 'Default', get rid of 'em
        s/\W//g;               # And ensure nothing silly going on
        $_ = '#' . $_          # And prepend numerics with the #
            if (/^[0-9a-fA-F]+$/);
    }

    my @times;
    foreach (qw /MailReminder MailReminder2/) {
        push @times, $self->{$_}
            if ($self->{$_});
    }
    my $reminders = join (' ', @times);
    my $reminderAddress;        # only pass to event if reminder time specified
    if ($reminders) {
        $reminderAddress = $self->{ReminderAddress};
    }

    # make the new event
    my $event = Event->new (text          => $self->{EventText},
                            link          => $link,
                            popup         => $popup,
                            export        => $self->{ExportPopup},
                            startTime     => $self->{parsed}->{startTime},
                            endTime       => $self->{parsed}->{endTime},
                            timePeriod    => $self->{TimePeriod},
                            repeatInfo    => $self->repeatObject, # maybe undef
                            drawBorder    => $self->{BorderCheckbox},
                            owner         => $self->{op}->getUsername,
                            bgColor       => $self->{BackgroundColor},
                            fgColor       => $self->{ForegroundColor},
                            category      => $category,
                            mailTo        => $self->{MailTo},
                            mailCC        => $self->{MailCC},
                            mailBCC       => $self->{MailBCC},
                            mailText      => $self->{MailComments},
                            reminderTo    => $reminderAddress,
                            reminderTimes => $reminders);

    # Set Custom Fields - we only set fields that are actually defined for
    #   the main calendar
    my $fields_lr = $self->{op}->prefs->get_custom_fields (system => 1);
    foreach my $defined_field (@$fields_lr) {
        my $id = $defined_field->id;
        if (exists $self->{customFields}->{$id}
            and ($self->{customFields}->{$id} ne '')) {
            $event->customField ($id, $self->{customFields}->{$id});
        }
    }

    # Copy/set subscribers (only done when editing event)
    my $subs = $self->{SubscriberAddresses} || '';
    my @addresses = split '[\s,]+', $subs;
    my ($calName) = $self->getParsedValue ('calendars');
    foreach (@addresses) {
        $event->addSubscriber ($_, $calName);
    }

    $self->{event} = $event;
    return $event;
}


sub errorMessage {
    my ($self, $error, $newOrReplace) = @_;

    my $i18n  = $self->{op}->I18N;

    return $i18n->get ('You cannot create a blank event')
        if ($error eq 'blank event');

    return $i18n->get ('You must specify an email address if ' .
                       'Email Reminders are specified')
        if ($error eq 'reminder w/no address');

    if ($error eq 'invalid date') {
        my $dateYear  = $self->{DateYearPopup};
        my $dateMonth = $self->{DateMonthPopup};
        my $dateDay   = $self->{DateDayPopup};
        return $i18n->get ('Invalid Date: ') .
               $i18n->get (Date->monthName ($dateMonth)) .
                   " $dateDay, $dateYear";
    }

    if ($error eq 'invalid repeat until date') {
        my $untilYear  = $self->{UntilYearPopup};
        my $untilMonth = $self->{UntilMonthPopup};
        my $untilDay   = $self->{UntilDayPopup};
        return $i18n->get ('Invalid <b>Repeat Until</b> Date') . ': ' .
               $i18n->get (Date->monthName ($untilMonth)) .
                   " $untilDay, $untilYear";
    }

    if ($error eq 'start date after end date') {
        my $mess = $i18n->get ('<b>Repeat Until Date</b> cannot ' .
                               'be before the first date of the ' .
                               'event.');
        $mess .= '<br>&nbsp;&nbsp;&nbsp;' .
                 $i18n->get ('Event Start Date:') . ' ' .
                         $self->{parsed}->{date}->pretty ($i18n) .
                 '<br>&nbsp;&nbsp;&nbsp;' .
                 $i18n->get ('Repeat Until Date:') . ' ' .
                         $self->{parsed}->{endDate}->pretty ($i18n) .
                 '</blockquote>';
        return $mess;
    }

    return $i18n->get ('You must select at least one calendar')
        if ($error eq 'no calendar specified');

    if ($error eq 'missing required fields') {
        my $info = $self->{badCals}->{'missing required fields'};
        my @badCals = keys %$info;
        my $prefs = $self->{calPrefs}->{$badCals[0]};
        my %reqFields;
        foreach my $calName (@badCals) {
            my @fields = split ',', ($info->{$calName} || ''); # comma sep.
                                                               # list of
            @reqFields{@fields} = map {1} @fields              # field names
        }
        my $mess;
        if (keys %reqFields > 1) {
            $mess = $i18n->get ('These fields are required:');
        } else {
            $mess = $i18n->get ('This field is required:');
        }
        $mess .= ' ';
        $mess .= join ', ', map {$i18n->get (ucfirst $_)} keys %reqFields;
        return $mess;
    }

    if ($error eq 'past event') {
        my @badCals = keys %{$self->{badCals}->{'past event'}};
        my $start = @badCals > 1 ? 'These calendars do' : 'This calendar does';
        my $mess = $i18n->get ('Cannot add past event!') .
                   '<br>&nbsp;&nbsp;&nbsp;' .
                   $i18n->get ("$start not allow creating or editing " .
                               "events before today's date.");
        if (@badCals > 1) {
            $mess .= '<br>&nbsp;&nbsp;&nbsp;' .
                     join (',', sort {lc ($a) cmp ($b)} @badCals);
        }

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'NoPastEditing',
                                         $newOrReplace);
        return $mess;
    }

    if ($error eq 'future limit') {
        my @badCals = keys %{$self->{badCals}->{'future limit'}};
        my $start = @badCals > 1 ? 'These calendars are' : 'This calendar is';
        my $mess = $i18n->get ('Sorry, the event is too far in the future.') .
                   '<br><br>' .
                   $i18n->get ("$start set to not permit adding or " .
                               'editing events that far in the future.');
        if (@badCals == 1) {
            my $amount = $self->{calPrefs}->{$badCals[0]}->FutureLimitAmount;
            my $units  = $self->{calPrefs}->{$badCals[0]}->FutureLimitUnits;
            $mess .= '<br>' .$i18n->get ('The maximum is') . " $amount " .
                     $i18n->get ($amount == 1 ? $units : $units . 's')

        } else {
            foreach my $cal (sort {lc ($a) cmp ($b)} @badCals) {
                my $amount = $self->{calPrefs}->{$cal}->FutureLimitAmount;
                my $units  = $self->{calPrefs}->{$cal}->FutureLimitUnits;
                $mess .= "<br>&nbsp;&nbsp;&nbsp;$cal: $amount " .
                         $i18n->get ($amount == 1 ? $units : $units . 's');
            }
        }

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'FutureLimit',
                                         $newOrReplace);
        return $mess;
    }

    if ($error eq 'last minute') {
        my @badCals = keys %{$self->{badCals}->{'last minute'}};
        my $mess = $i18n->get ('Sorry, no last-minute changes allowed.') .
                   '<br><br>';
        if (@badCals == 1) {
            my $amount = $self->{calPrefs}->{$badCals[0]}->NoLastMinuteAmount;
            my $units  = 'hour';
            $mess .= $i18n->get ('This calendar does not permit changing '
                                 .'an event within')
                     . " $amount "
                     . $i18n->get ($amount == 1 ? $units : $units . 's')
                     . ' of its occurrence.';
        } else {
            $mess .= $i18n->get ('These calendars do not permit changing' .
                                 ' an event that close to its occurrence.');
            foreach my $cal (sort {lc ($a) cmp ($b)} @badCals) {
                my $amount = $self->{calPrefs}->{$cal}->NoLastMinuteAmount;
                my $units  = 'hour';
                $mess .= "<br>&nbsp;&nbsp;&nbsp;$cal: $amount " .
                         $i18n->get ($amount == 1 ? $units : $units . 's');
            }
        }

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'NoLastMinute',
                                         $newOrReplace);
        return $mess;

    }

    if ($error eq 'event too long') {
        my @badCals = keys %{$self->{badCals}->{'event too long'}};
        my $mess = $i18n->get ('Sorry, the event duration is too long.') .
                   '<br><br>';
        if (@badCals == 1) {
            my $amount = $self->{calPrefs}->{$badCals[0]}->MaxDurationAmount;
            my $units  = 'minute';
            $mess .= $i18n->get ('The maximum duration for this calendar is')
                     . " $amount "
                     . $i18n->get ($amount == 1 ? $units : $units . 's')
                     . '.';
        } else {
            $mess .= $i18n->get ('These calendars are set to not allow' .
                                 ' adding or editing events that long.');
            foreach my $cal (sort {lc ($a) cmp ($b)} @badCals) {
                my $amount = $self->{calPrefs}->{$cal}->MaxDurationAmount;
                my $units  = 'minute';
                $mess .= "<br>&nbsp;&nbsp;&nbsp;$cal: $amount " .
                         $i18n->get ($amount == 1 ? $units : $units . 's');
            }
        }

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'MaxDuration',
                                         $newOrReplace);
        return $mess;
    }

    if ($error eq 'event too short') {
        my @badCals = keys %{$self->{badCals}->{'event too short'}};
        my $mess = $i18n->get ('Sorry, the event duration is too short.') .
                   '<br><br>';
        if (@badCals == 1) {
            my $amount = $self->{calPrefs}->{$badCals[0]}->MinDurationAmount;
            my $units  = 'minute';
            $mess .= $i18n->get ('The minimum duration for this calendar is')
                     . " $amount "
                     . $i18n->get ($amount == 1 ? $units : $units . 's')
                     . '.';
        } else {
            $mess .= $i18n->get ('These calendars are set to not allow' .
                                 ' adding or editing events that short.');
            foreach my $cal (sort {lc ($a) cmp ($b)} @badCals) {
                my $amount = $self->{calPrefs}->{$cal}->MinDurationAmount;
                my $units  = 'minute';
                $mess .= "<br>&nbsp;&nbsp;&nbsp;$cal: $amount " .
                         $i18n->get ($amount == 1 ? $units : $units . 's');
            }
        }

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'MinDuration',
                                         $newOrReplace);
        return $mess;
    }

    if ($error eq 'time conflict') {
        my $confInfo = $self->{badCals}->{'time conflict'};
        my @badCals = keys %$confInfo;
        my $x = $i18n->get ('an existing event');
        if (@badCals > 1 or @{$confInfo->{$badCals[0]}} > 1) {
            $x = $i18n->get ('existing events');
        }

        my $prefs = $self->{calPrefs}->{$badCals[0]};

        my $mess = '<b>' . $i18n->get ('Times conflict!') . '</b>' .
                   '<br><br>&nbsp;&nbsp; ' .
                   $i18n->get ("The time of the event conflicts with $x.") .
                   '<br>';
        my $date = $self->{parsed}->{date}->pretty ($i18n);
        my $date18 = $i18n->get ('Date:');
        my $time18 = $i18n->get ('New Event Time');
        my $event = $self->{event};

        # Adjust times for displaying message
        if ($prefs) {
            if (my $offsetHours = $prefs->Timezone) {
                $event = $event->copy;
                $event->adjustForTimezone ($date, $offsetHours);
            }
        }

        my $times = $event->getTimeString ('both', $prefs);
        $mess .= qq (<blockquote><table>
                       <tr><td align='right'>$date18</td>
                           <td><b>$date</b></td></tr>
                       <tr><td align='right'>$time18:</td>
                           <td><b>$times</b></td></tr>
                       <tr><td colspan=2 align='center'><hr width="50%"></td>
                       </tr>);

        my $maxDisplay = 5;     # only show up to this many conflicters
        my ($totalConflicts, $totalDisplayed);

        foreach my $calName (@badCals) {
            if (@badCals > 1) {
                my $name18 = $i18n->get ('Calendar Name');
                $mess .= qq (<tr><td align="right">$name18:</td>
                                  <td>$calName></td></tr>);
            }
            my $confTime18 = $i18n->get('Conflicting Event Time');
            my $confText18 = $i18n->get('Conflicting Event Text');
            my $conflicters = $confInfo->{$calName}; # list of ev/date pairs

            $totalConflicts += @$conflicters;

            foreach my $pair (@$conflicters) {

                last unless $maxDisplay--;
                $totalDisplayed++;

                my ($event, $date) = @$pair;

                if ($prefs) {
                    if (my $offsetHours = $prefs->Timezone) {
                        $event = $event->copy;
                        $event->adjustForTimezone ($date, $offsetHours);
                    }
                }

                my $confTime = $event->getTimeString ('both', $prefs);
                if ($date != $self->{parsed}->{date}) {
                    $confTime .= ', ' . $date->pretty ($i18n);
                }
                my $confText = $event->text;
                my $category = $event->getCategoryScalar;
                if ($category) {
                    my $cat18 = $i18n->get ('Conflicting Category');
                    $category = qq (<td align="right">$cat18:</td>
                                    <td><i>$category</i></td>);
                } else {
                    $category = '<td>&nbsp;</td>';
                }
                my $prevNext = $event->{_conflictInfo}->{prevNextString};
                $prevNext = $prevNext ? $i18n->get ($prevNext) : '';
                $mess .= qq (<tr><td>$confTime18:</td>
                                 <td><b>$confTime
                                     <small><small>$prevNext</small></small>
                                 </b></td></tr>
                             <tr><td>$confText18:</td>
                                 </td><td><i>$confText</i></td></tr>
                             <tr>$category</tr>);
            }
        }

        if ($totalDisplayed < $totalConflicts) {
            my $undisp = $totalConflicts - $totalDisplayed;
            my $x;
            if ($undisp > 1) {
                $x = $i18n->get ('more conflicting events were not displayed');
            } else {
                $x = $i18n->get ('more conflicting event was not displayed');
            }
            $mess .= qq {<tr><td colspan=2>($undisp $x)</td></tr>};
        }

        $mess .= '</table></blockquote>';

        # see if just a warning - must be for *all* bad cals
        $mess .= $self->_doWarningStuff (\@badCals, 'TimeConflicts',
                                         $newOrReplace);

        return $mess;
    }

    return $i18n->get ('Someone else has deleted this event.')
        if ($error eq 'event no longer exists');

    return $i18n->get ('The specified repeat options don\'t define ' .
                       'any actual instances.')
        if ($error eq 'repeating w/no instances');

    return $i18n->get ('Unknown error creating/editing event');
}

sub _doWarningStuff {
    my ($self, $badCals, $prefName, $addOrReplace) = @_;

    my $i18n = $self->{op}->I18N;

    # If any cal is not just a warning, don't allow "add anyway"
    # (unless user has Admin permission in that calendar)
    foreach (@$badCals) {
        my $hasAdmin = Permissions->new ($_)->permitted
                                          ($self->{op}->getUsername, 'Admin');
        if (!$hasAdmin and $self->{calPrefs}->{$_}->$prefName() !~ /warn/i) {
            $self->{isOnlyWarnings} = -1;
            return '';
        }
    }

    $self->{isOnlyWarnings} = 1 unless ($self->{isOnlyWarnings});

    my $label = 'Add it anyway';
    if ($addOrReplace =~ /replace/i) {
        $label = 'Replace it anyway';
    } elsif ($addOrReplace =~ /copy/i) {
        $label = 'Copy it anyway';
    }

    my $plain = $self->{op}->makeURL ({PlainURL => 1});
    my $mess = $self->{cgi}->start_form (-action => $plain);
    while (my ($name, $val) = each (%{$self->{op}->rawParams})) {
        next unless (defined $val);
        next if (grep {$name eq $_} @multiFields);
        $mess .= $self->{cgi}->hidden (-name  => $name,
                                       -value => $val);
    }
    # Since rawParams does *not* handle multi-value ones...
    foreach (@multiFields) {
        my @vals = $self->{cgi}->param ($_);
        next unless @vals;
        $mess .= $self->{cgi}->hidden (-name => $_, -value => \@vals);
    }
    $mess .= $self->{cgi}->hidden (-name  => 'Ignore' . $prefName,
                                   -value => 1);
    $mess .= $self->{cgi}->submit (-name  => 'AddItAnyway',
                                   -value => $i18n->get ($label));
    $mess .= $self->{cgi}->end_form;
    return $mess;
}

sub isOnlyWarning {
    my $self = shift;
    return ($self->{isOnlyWarnings} == 1);
}

1;
