# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Create a New Event

package EventNew;
use strict;

use Calendar::Date;
use Calendar::EventFormProcessor;
use Calendar::GetHTML;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my $form = EventFormProcessor->new ($self);
    my $i18n = $self->I18N;

    if ($form->cancelled) {
        $self->{audit_formcancelled}++;
        my $next_op = $form->getValue('NextOp') || '';
        # NextOp can be full URL, or usually just an operation name
        if ($next_op =~ /[^a-zA-Z]/) {
            print $self->redir ($next_op);
        }
        else {
            print $self->redir ($self->makeURL ({Op => $next_op}));
        }
        return;
    }

    my @whichCals = $form->getParsedValue ('calendars');

    # parse dates, times, check for errors. Date and times are adjusted for
    # timezone offsets.
    my @errors = $form->validateFields;
    if (@errors) {
        $self->_errorExit ($form, @errors);
        return;
    }

    my $newEvent = $form->makeEvent;

    # If any hidden fields, use their default values
    my $hideThese = $self->prefs->EditFormHide || '';
    my %hideIt = (privacy     => ($hideThese =~ /whenInc/i)     || 0,
                  border      => ($hideThese =~ /border/i)      || 0,
                  category    => ($hideThese =~ /category/i)    || 0,
                  mail        => ($hideThese =~ /mail/i)        || 0);
    my %defaults = (privacy     => $self->prefs->EventPrivacy,
                    border      => $self->prefs->DefaultBorder,
                    category    => $self->prefs->DefaultCategory,
                    timePeriod  => $self->prefs->DefaultTimePeriod,
                    subscribers => $self->prefs->DefaultSubsNotify,
                    );

    $newEvent->export ($defaults{privacy} || 'Public')
        if ($hideIt{privacy});
    $newEvent->drawBorder ($defaults{border})
        if ($hideIt{border});
    $newEvent->timePeriod ($defaults{timePeriod} || undef)
        if ($self->prefs->TimeEditWhich and
            $self->prefs->TimeEditWhich eq 'none');
    $newEvent->category ($defaults{category})
        if ($hideIt{category} and defined ($defaults{category}) and
            ($defaults{category} ne '-'));

    my $notifySubscribers = $hideIt{mail} ? $defaults{subscribers}
                                       : $form->getValue ('NotifySubscribers');

    # Field values valid, and we have an Event object. Check for violations
    # of calendar settings, e.g. no past events, time conflicts, and for
    # invalid repeat settings.
    @errors = $form->validateEvent ($newEvent);
    if (@errors) {
        $self->_errorExit ($form, @errors);
        return;
    }

    my $eventDate = $form->getParsedValue ('date');

    # keep track of things in case we're auditing
    $self->{audit_calendars} = [sort {lc($a) cmp lc($b)} @whichCals];
    $self->{audit_event}     = $newEvent;
    $self->{audit_eventDate} = $eventDate;

    # If adding to mult. calendars, must do special stuff w/custom fields
    # Fields are set in EventFormProcessor
    my $custom_fields_lr = $self->prefs->get_custom_fields (system => 1);
    my %event_custom_fields = %{$newEvent->get_custom_fields || {}}; # save copy

    # Stick it in the database(s)
    foreach my $thisCal (@whichCals) {
        my $db = Database->new ($thisCal);
        my $prefs = $db->getPreferences;

        # Set "tentative" flag
        if ($prefs->TentativeSubmit and
            !Permissions->new ($db)->permitted ($self->getUsername, 'Edit')) {
            $newEvent->isTentative (1);
            $self->{audit_tentative} = $thisCal;
        } else {
            $newEvent->isTentative (0);
            $self->{audit_tentative} = undef;
        }

        # Custom Fields - if there are multiple calendars, the field
        #   ID from the 'main' calendar determines the field. If there
        #   is a field w/the same *name* in any other calendars, that
        #   field is used there.
        if ($thisCal ne $self->calendarName) {
            my $this_cal_fields_lr = $prefs->get_custom_fields (system => 1);
            my $fields_by_name     = map {$_->name => $_} @$this_cal_fields_lr;
            my %fields_for_event;
            foreach my $field (values %event_custom_fields) {
                if (my $field_in_this_cal = $fields_by_name->{$field->name}) {
                    my $id_in_this_cal = $field_in_this_cal->id;
                    $fields_for_event{$id_in_this_cal}
                                          = $event_custom_fields{$field->id};
                }
            }
            $newEvent->set_custom_fields (\%fields_for_event);
        }
        else {
            # just in case mult. cals and 'main' calendar isn't first
            $newEvent->set_custom_fields (\%event_custom_fields);
        }

        $db->insertEvent ($newEvent, $eventDate);

        # Do auditing for `other' calendars
        if ($thisCal ne $self->calendarName) {
            my @auditTypes = $db->getAuditing ('Add');
            foreach (@auditTypes) {
                AuditFactory->create ($_)->perform ($self, $db);
            }
        }
    }

    # maybe send email notifications, including to subscribers as BCCs
    my $to  = $newEvent->mailTo;
    my $cc  = $newEvent->mailCC;
    my $bcc = $newEvent->mailBCC;

    if (Defines->mailEnabled and $notifySubscribers) {
        my @bccList;
        foreach my $thisCal (@whichCals) {
            my $prefs = Preferences->new ($thisCal);
            my @toAll = $prefs->getRemindAllAddresses;
            my $byCat = $prefs->getRemindByCategory;
            my @addresses = @toAll;
            if ($newEvent->getCategoryList) {
                foreach my $cat (keys %$byCat) {
                    push @addresses, @{$byCat->{$cat}}
                        if $newEvent->inCategory ($cat);
                }
            }
            my %adrs;
            @adrs{@addresses} = undef;
            push @bccList, keys %adrs;
        }
        $bcc .= ',' if $bcc;
        $bcc .= join (',', @bccList);
    }
    if ($to or $cc or $bcc) {
        my $evCopy = $newEvent->copy; # since send() might adjust times
        require Calendar::Mail::MailNotifier;
        MailNotifier->send (op    => $self,
                            event => $evCopy,
                            date  => $eventDate,
                            TO    => $to,
                            CC    => $cc,
                            BCC   => $bcc);
    }
    # maybe remember to remind
    if (Defines->mailEnabled and $newEvent->reminderTimes) {
        require Calendar::Mail::MailReminder;
        MailReminder->add ($newEvent, $self->calendarName, $eventDate);
    }

    my $showDate = $newEvent->getDisplayDate ($eventDate,
                                              $self->prefs->Timezone);

    # And redirect to the page to display.
    if ($form->getValue ('FromPopupWindow')) {
        print GetHTML->reloadOpener ('closeMe');
        return;
    }

    my $theURL;
    my $nextOp = $form->getValue ('NextOp');
    if ($nextOp and $nextOp ne 'ShowDay') {
        $theURL = $nextOp;
    } else {
        $theURL = $self->makeURL ({Op      => 'ShowDay',
                                   Date    => $showDate,
                                   CalendarName => $form->getValue
                                                            ('DisplayCal'),
                                   ViewCal      => $form->getValue ('ViewCal'),
                                   IsTentative  => $newEvent->isTentative
                                                   || undef,
                                   Splunge => time}); # needed as workaround
    }
    print $self->redir ($theURL);
}

sub _errorExit {
    my ($self, $form, @errors) = @_;
    $self->{audit_errors} = \@errors;
    my $message = join '</p><hr width="10%" align="left"><p>',
                        map {$form->errorMessage ($_, 'new')} @errors;
    $message = "<p>$message</p>";
    my $x;
    if ($form->isOnlyWarning) {
        $x = @errors > 1 ? 'Warnings while' : 'Warning while';
    } else {
        $x = @errors > 1 ? 'Errors' : 'Error';
    }
    my $title = "$x Adding New Event";
    GetHTML->errorPage ($self->I18N,
                        header    => $self->I18N->get ($title),
                        message   => $message);
    return;
}

# If doing a multi-calendar add, need to authenticate against all of them.
sub authenticate {
    my $self = shift;
    require CGI;
    my @whichCals = CGI->new->param ('WhichCalendars');
    return $self->SUPER::authenticate
        unless @whichCals;
    my $userName = $self->getUsername;
    foreach (@whichCals) {
        next if (Permissions->new ($_)->permitted ($userName, 'Add'));
        $userName ||= '';
        GetHTML->errorPage ($self->I18N,
                            header  => $self->I18N->get('Error adding events'),
                            message => "User $userName does not have " .
                                       "permission to Add to $_.");
        return;
    }
    return 1;
}

# Override audit, since we need to handle special AddTentative case
sub auditType {
    my $self = shift;
    my $type = $self->{audit_tentative} ? 'AddTentative' : 'Add';
    return $type;
}

sub auditString {
    my ($self, $short) = @_;
    return if $self->{audit_formcancelled};

    my $line = $self->SUPER::auditString ($short);
    return ($line . ' ERROR - ' . join (',', @{$self->{audit_errors}}))
        if $self->{audit_errors};

    my $event = $self->{audit_event};

    if ($short) {
        my $text;
        if ($event) {
            $text = $event->text;
            $text =~ s/\n/\\n/g;
            $text = $self->{audit_eventDate} . ' ' . $text;
            $text .= ' [tentative]' if $self->{audit_tentative};
        }
        return $line . ' ' . $text;
    }

    my ($text, $extra);
    ($text     = $event->text)                        =~ s/\r//g;
    ($extra    = $event->popup || $event->link || '') =~ s/\r//g;
    $extra = "Popup text: $extra" if ($event->popup);
    $extra = "URL:\t$extra"       if ($event->link);

    # make a string
    my $message;
    if ($self->{audit_calendars} and @{$self->{audit_calendars}} > 1) {
        $message = "Calendar Names:\t" .
                   join (', ', @{$self->{audit_calendars}}) . "\n";
    } else {
        $message = "Calendar Name:\t" . $self->calendarName . "\n";
    }
    $message .= "Date:\t$self->{audit_eventDate}\n";
    if (defined $event->startTime) {
        $message .= "Time:\t" . $event->getTimeString ('both', $self->prefs)
                    . "\n";
    }

    $message .= "Type:\t" . $event->export . "\n\n"
        if (defined $event->export);

    $message .= "Text:\t$text\n" . $extra . "\n\n";

    if (my @cats = $event->getCategoryList) {
        $message .= "Categories:  \t" . join (',', @cats) . "\n";
    }

    $message .= "Border:    \t" . ($event->drawBorder ? 'yes' : 'no') . "\n";
    $message .= "Foreground:\t" . ($event->fgColor || 'Default')      . "\n" .
                "Background:\t" . ($event->bgColor || 'Default')      . "\n";

    if ($event->isRepeating) {
        my $rep = $event->repeatInfo;
        $message .= "\nThis is a Repeating Event\n";
        $message .= "Start Date:\t" .  $rep->startDate . "\n";
        $message .= "End Date:  \t" . ($rep->endDate == Date->openFuture ?
                                                      'None' : $rep->endDate);
        $message .= "\n";
        if ($rep->period) {
            $message .= 'Every ';
            # period is either single amount, or ref to list of days of week
            if (!ref ($rep->period)) {
                my $period = $rep->period;
                $period = 'day' if ($period eq 'dayBanner');
                if ($rep->frequency == 1) {
                    $message .= $period . "\n";
                } else {
                    $message .= $rep->frequency . ' ' . $period . "s\n";
                }
            }
            else {
                my @days = map {Date->dayName ($_)} @{$rep->period};
                my @nth = (' ', 'st', 'nd', 'rd', 'th');
                my $nth = ' ';
                if ($rep->frequency > 1) {
                    $nth = $nth[$rep->frequency];
                    $nth = 'th' unless defined ($nth);
                    $nth = $rep->frequency . $nth . ' ';
                }
                $message .= $nth . (join ', ', @days) . "\n";
            }
        } else {
            my %text = (1 => '1st',
                        2 => '2nd',
                        3 => '3rd',
                        4 => '4th',
                        5 => 'last',
                        6 => 'fifth (if there is a fifth)');
            my $mw = join ', ', map {$text{$_}} @{$rep->monthWeek};

            my $day = Date->dayName ($rep->monthDay);
            my $mm = ($rep->monthMonth || 1) != 1 ? ' ' . $rep->monthMonth
                                                  : '';
            $message .= "$mw $day of every$mm month\n";
        }
        $message .= "  (Skip Weekends)\n" if $rep->skipWeekends;
    }

    my $to  = $event->mailTo;
    my $cc  = $event->mailCC;
    my $bcc = $event->mailBCC;
    $message .= "\nNotification To:  $to\n"  if $to;
    $message .= "\nNotification CC:  $cc\n"  if $cc;
    $message .= "\nNotification BCC: $bcc\n" if $bcc;

    if (my $text = $event->mailText) {
        $text =~ s/\r//g;
        $message .= "\nNotification Comments: " . $text . "\n";
    }

    my $tent = '';
    if ($self->{audit_tentative}) {
        my $owner = $event->owner || 'an anonymous user';
        $tent .= "A Event requiring approval was added by $owner.\n";
        $tent .= "Calendar: " . $self->{audit_tentative} . "\n\n";
        my $url = $self->makeURL ({FullURL      => 1,
                                   CalendarName => $self->{audit_tentative},
                                   Op           => 'ApproveEvents'});
        $tent .= "Follow this link for the approval form:\n    $url\n\n\n";
    }

    return $tent . $message . "\n\n$line";
}

1;
