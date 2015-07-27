# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Replace an event; result of submitting the Edit Form

package EventReplace;
use strict;

use Calendar::EventFormProcessor;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my $form = EventFormProcessor->new ($self);
    my $i18n = $self->I18N;

    my $date        = $form->getValue ('Date');
    my $displayDate = $form->getValue ('DisplayDate');

    my $nextURL = $self->makeURL ({Op   => 'ShowDay',
                                   Date => $displayDate || $date,
                                   CalendarName =>
                                           $form->getValue ('DisplayCal')});
    if ($form->cancelled) {
        $self->{audit_formcancelled}++;
        print $self->redir ($nextURL);
        return;
    }

    $self->{audit_formsaved}++;

    # if not copying event, clear any potential selected "other" calendars.
    # Other calendars enabled *only for copying*
    unless ($form->getValue ('CopyEvent')) {
        $form->{parsed}->{calendars} = [$self->calendarName]; # hackery
    }

    my $allOrOne ||= $form->getValue ('AllOrOne');

    # if deleting, just delete it!
    if ($form->getValue ('DeleteEvent')) {
        my $id = $form->getValue ('OldEventID');
        my $text = $self->db->deleteEvent ($date, $id, $allOrOne || 'all');
        if ($form->getValue ('FromPopupWindow')) {
            print GetHTML->reloadOpener ('closeMe');
        } else {
            print $self->redir ($nextURL);
        }
        $self->{audit_deleted_p}    = 1;
        $self->{audit_eventDate}    = $date;
        $self->{audit_deleted_text} = $text;
        return;
    }

    # parse dates, times, check for errors. Date and times are adjusted for
    # timezone offsets.
    my @errors = $form->validateFields;
    if (@errors) {
        $self->_errorExit ($form, @errors);
        return;
    }

    my $newEvent   = $form->makeEvent;
    my $oldEventID = $form->getValue ('OldEventID');

    # Get original version of the event; we need some info that's not on
    # the event edit form.
    my ($origEvent, $origDate) = $self->db->getEventById ($oldEventID);
    # Orig event might have been deleted by somebody else first!
    unless ($origEvent) {
        $self->_errorExit ($form, 'event no longer exists');
        return;
    }
    $origDate = Date->new ($origDate); # make sure it's a Date obj, not y/m/d

    # If any hidden fields, need to copy from existing event
    my $hideThese = $self->prefs->EditFormHide || '';
    my %hideIt = (repeat      => ($hideThese =~ /repeat/i)   || 0,
                  mail        => ($hideThese =~ /mail/i)     || 0,
                  details     => ($hideThese =~ /details/i)  || 0,
                  category    => ($hideThese =~ /category/i) || 0,
                  privacy     => ($hideThese =~ /whenInc/i)  || 0,
                  colors      => ($hideThese =~ /colors/i)   || 0,
                  border      => ($hideThese =~ /border/i)   || 0);
    $newEvent->link     ($origEvent->link)     if ($hideIt{details});
    $newEvent->popup    ($origEvent->popup)    if ($hideIt{details});
    $newEvent->category ($origEvent->category) if ($hideIt{category});
    $newEvent->export   ($origEvent->export)   if ($hideIt{privacy});
    $newEvent->bgColor  ($origEvent->bgColor)  if ($hideIt{colors});
    $newEvent->fgColor  ($origEvent->fgColor)  if ($hideIt{colors});
    $newEvent->drawBorder ($origEvent->drawBorder) if ($hideIt{border});
    $newEvent->timePeriod ($origEvent->timePeriod)
                         if ($self->prefs->TimeEditWhich and
                             $self->prefs->TimeEditWhich eq 'none');
    if ($hideIt{mail}) {
        $newEvent->reminderTimes ($origEvent->reminderTimes);
        $newEvent->reminderTo    ($origEvent->reminderTo);
    }

    my $doSubscribers = $hideIt{mail} ? $self->prefs->DefaultSubsNotify
                                      : $form->getValue ('NotifySubscribers');


    # Field values valid, and we have an Event object. Check for violations
    # of calendar settings, e.g. no past events, time conflicts, and for
    # invalid repeat settings.
    @errors = $form->validateEvent ($newEvent, $origEvent, $origDate);
    if (@errors) {
        $self->_errorExit ($form, @errors);
        return;
    }

    my $newDate = $form->getParsedValue ('date');

    $date     = Date->new ($date);

    $self->{audit_oldEvent}  = $origEvent;
    $self->{audit_oldDate}   = $origDate;
    $self->{audit_newEvent}  = $newEvent;
    $self->{audit_eventDate} = $newDate;

    # Copy the exclusion list (no-op unless it's repeating)
    $newEvent->exclusionList ($origEvent->exclusionList);

#    $newEvent->subscriptions ($origEvent->subscriptions);

    # if editing single instance of a repeating event, add to orig event's
    # exclusion list, and create a new event (can't copy to other cal)
    if ($allOrOne =~ /only/i) {
        $self->db->deleteEvent ($date, $oldEventID, 'one');
        $self->db->insertEvent ($newEvent, $newDate);
        $self->_doNotify ($newEvent, $newDate, $doSubscribers, 1);
        $self->_doRemind (event   => $newEvent,
                          date    => $newDate);
        if ($form->getValue ('FromPopupWindow')) {
            print GetHTML->reloadOpener ('closeMe');
        } else {
            print $self->redir ($nextURL);
        }
        return;
    }

    # if editing all past instances of repeater, set start date of original
    # to one day after this date, and end date of new one to this date
    # (can't copy to other cal)
    if ($allOrOne =~ /past/i) {
        my $repInfo   = $origEvent->repeatInfo;
        my $origStart = $repInfo->startDate;

        $repInfo->startDate ($date + 1);
        $self->db->replaceEvent ($origEvent); # from today on

        $repInfo->startDate ($origStart);     # reset for new event
        $repInfo->endDate ($date);            # new one ends today
        $newEvent->repeatInfo ($repInfo);
        $self->db->insertEvent ($newEvent);

        $self->_doNotify ($newEvent, $date, $doSubscribers, 1);
        $self->_doRemind (event   => $newEvent,
                          date    => $date);

        if ($form->getValue ('FromPopupWindow')) {
            print GetHTML->reloadOpener ('closeMe');
        } else {
            print $self->redir ($nextURL);
        }
        return;
    }

    # if editing all future instances of repeater, set end date of original
    # to one day before this date, and start date of new one to this date
    # (can't copy to other cal)
    if ($allOrOne =~ /future/i) {
        my $repInfo   = $origEvent->repeatInfo;
        my $origEnd = $repInfo->endDate;

        $repInfo->endDate ($date - 1);
        $self->db->replaceEvent ($origEvent); # up until yesterday

        $repInfo->endDate ($origEnd);         # reset for new event
        $repInfo->startDate ($date);          # new one starts today
        $newEvent->repeatInfo ($repInfo);
        $self->db->insertEvent ($newEvent);

        $self->_doNotify ($newEvent, $date, $doSubscribers, 1);
        $self->_doRemind (event   => $newEvent,
                          date    => $date);

        if ($form->getValue ('FromPopupWindow')) {
            print GetHTML->reloadOpener ('closeMe');
        } else {
            print $self->redir ($nextURL);
        }
        return;
    }

    # So, not special repeating editing - just replace or copy the event!
    if ($form->getValue ('CopyEvent')) {
        $self->{audit_copied_p} = 1;
        my @whichCals = $form->getParsedValue ('calendars');
        foreach my $thisCal (@whichCals) {
            my $db = Database->new ($thisCal);
            $db->insertEvent ($newEvent, $newDate);
            $self->_doRemind (event   => $newEvent,
                              date    => $newDate,
                              calName => $thisCal);
        }
        $self->_doNotify ($newEvent, $newDate, $doSubscribers);
    } else {
        # Replacing, so set ID
        $newEvent->id ($oldEventID);
        # If date was changed, we need to delete it here first. Bad design.
        if ($newDate == $origDate) {
            $self->db->replaceEvent ($newEvent, $newDate);
        } else {
            $self->db->deleteEvent ($origDate, $oldEventID, 'all',
                                    'noSyncEntry');
            $self->db->replaceEvent ($newEvent, $newDate, 'nodelete');
        }
        $self->_doNotify ($newEvent, $newDate, $doSubscribers, 1);
    }

    if ($form->getValue ('FromPopupWindow')) {
        print GetHTML->reloadOpener ('closeMe');
        return;
    }

    print $self->redir ($nextURL);
    return;
}

sub _doNotify {
    my ($self, $event, $date, $doSubscribers, $notCopying) = @_;

    my $to  = $event->mailTo;
    my $cc  = $event->mailCC;
    my $bcc = $event->mailBCC;

    if ($doSubscribers) {
        # add subscribers to this particular event
        $bcc .= ',' if $bcc;
        $bcc .= $event->getSubscribers ($self->calendarName);

        # and then subscribers to calendar, or categories
        my @toAll = $self->prefs->getRemindAllAddresses;
        my $byCat = $self->prefs->getRemindByCategory;
        my @addresses = @toAll;
        if ($event->getCategoryList) {
            foreach my $cat (keys %$byCat) {
                push @addresses, @{$byCat->{$cat}}
                    if $event->inCategory ($cat);
            }
        }
        my %adrs;
        @adrs{@addresses} = undef;
        $bcc .= ',' if $bcc;
        $bcc .= join (',', keys %adrs);
    }

    return unless ($to or $cc or $bcc);

    require Calendar::Mail::MailNotifier;
    # if not copying, we're modifying
    MailNotifier->send (op     => $self,
                        event  => $event,
                        date   => $date,
                        edited => $notCopying,
                        TO     => $to,
                        CC     => $cc,
                        BCC    => $bcc);
}
sub _doRemind {
    my $self = shift;
    my %args = @_;
    my $event   = $args{event};
    my $date    = $args{date};
    my $calName = $args{calName} || $self->calendarName;
    return unless (Defines->mailEnabled and $event->reminderTimes);
    require Calendar::Mail::MailReminder;
    MailReminder->add ($event, $calName, $date);
}

sub _errorExit {
    my ($self, $form, @errors) = @_;
    $self->{audit_errors} = \@errors;
    my $message = join '</p><hr width="10%" align="left"><p>',
                        map {$form->errorMessage ($_, 'replace')} @errors;
    $message = "<p>$message</p>";
    my $x;
    if ($form->isOnlyWarning) {
        $x = @errors > 1 ? 'Warnings while' : 'Warning while';
    } else {
        $x = @errors > 1 ? 'Errors' : 'Error';
    }
    my $y = $form->getValue ('CopyEvent') ? 'Copying' : 'Replacing';
    my $title = "$x $y Event";
    GetHTML->errorPage ($self->I18N,
                        header    => $self->I18N->get ($title),
                        message   => $message);
    return;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_formsaved};
    my $summary = $self->SUPER::auditString ($short);

    if ($self->{audit_errors}) {
        $summary .= ' ERROR - ';
        $summary .= join ',', @{$self->{audit_errors}};
        return $summary;
    }

    return $summary if $short;

    my $text;

    if ($self->{audit_deleted_p}) {
        $text = "Event Deleted\n";
        $text .= "$self->{audit_eventDate}\n";
        $text .= "$self->{audit_deleted_text}\n";
        return $summary . "\n\n" . $text;
    }

    $text = "Event Copied\n" if $self->{audit_copied_p};

    my $newEvent = $self->{audit_newEvent};
    my $oldEvent = $self->{audit_oldEvent};

    my $didText;
    my $changes = '';
    if ($oldEvent) {
        foreach (qw /text link popup export startTime endTime drawBorder
                 bgColor fgColor category timePeriod subscriptions/) {
            my $old = $oldEvent->$_() || '-';
            my $new = $newEvent->$_() || '-';
            $old =~ s/\r//g;
            $new =~ s/\r//g;
            if ($old ne $new) {
                if ($_ eq 'timePeriod') {
                    ($old) = $self->prefs->getTimePeriod ($old);
                    ($new) = $self->prefs->getTimePeriod ($new);
                    $old ||= '-';
                    $new ||= '-';
                } elsif ($_ =~ /Time/) {
                    $old = sprintf '%d:%.2d', (int ($old / 60), $old % 60)
                        unless ($old eq '-');
                    $new = sprintf '%d:%.2d', (int ($new / 60), $new % 60)
                        unless ($new eq '-');
                }
                $changes .= sprintf ("%10s: %10s --> %s\n", $_, $old, $new);
                if ($_ eq 'text') {
                    $changes .= "\n";
                    $didText++;
                }
            }
        }
    }

    unless ($didText) {
        ($text .= $newEvent->text) =~ s/\r//g;
        $text .= "\n\n";
    }
    $text .= $changes;

    $text = $self->{audit_eventDate} . "\n" . $text;
    return $summary . "\n\n" . $text;
}

1;
