# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Edit or Delete an existing Event

package EventEditDelete;
use strict;
use CGI;

use Calendar::Date;
use Calendar::GetHTML;
use Calendar::EventEditForm;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($edit, $delete, $theDate, $eventID, $allOrOne, $displayCal, $viewCal)
             = $self->getParams (qw (Edit Delete Date EventID AllOrOne
                                     DisplayCal ViewCal));

    my $i18n = $self->I18N;
    my $db   = $self->db;
    my $cgi  = new CGI;
    my $date = Date->new ($theDate);
    my $event = $db->getEvent ($date, $eventID);

    $displayCal ||= $self->calendarName;

    unless ($event) {
        my $title = $delete ? 'Error Deleting Event' : 'Error Editing Event';
#        warn "Bad Event Id: $eventID on $date";
        GetHTML->errorPage ($i18n,
                            header  => $i18n->get ($title),
                            message => $i18n->get ("Sorry, it appears that " .
                                                   "this event has already " .
                                                   "been deleted!<hr>"));
        $self->{audit_error} = 'bad event id';
        return;
    }

    # Don't let edit/delete of past events if we're not allowing that
    if ($self->prefs->NoPastEditing and
        !$self->permission->permitted ($self->getUsername, 'Admin')) {
        my $earliest = $date;
        my $extra = '';
        if ($event->isRepeating and $allOrOne =~ /all|past/i) {
            $earliest = $event->repeatInfo->startDate;
            if ($date >= Date->new) {
                $extra = '<br>' .
                         $self->I18N->get ('(This is a repeating event with ' .
                                           'past instances.)');
            }
        }
        if ($earliest < Date->new) {
            my $title = $delete ? 'Error Deleting Event'
                                : 'Error Editing Event';
            GetHTML->errorPage ($i18n,
                                header  => $i18n->get ($title),
                                message => $self->I18N->get
                                            ('This calendar does not allow ' .
                                             'editing or deleting events '   .
                                             'which occur in the past.')     .
                                            $extra . '<br>');
            $self->{audit_error} = 'event in the past';
            return;
        }
    }

    # Don't let edit/delete if we're enforcing event ownership
    my $owner = $event->owner;
    if ($self->prefs->EventOwnerOnly and defined ($owner) and
        ($self->getUsername || '') ne $owner and
        !$self->permission->permitted ($self->getUsername, 'Admin')) {
        my $title = $delete ? 'Error Deleting Event' : 'Error Editing Event';
        GetHTML->errorPage ($i18n,
                            header  => $i18n->get ($title),
                            message => $i18n->get ('Sorry, you are not '    .
                                                   'allowed to edit or '    .
                                                   'delete this event.<br>' .
                                                   'It is owned by ') .
                                       "<b>$owner</b>.<br><hr>");
        $self->{audit_error} = 'not event owner';
        return;
    }

    my $displayDate = $event->getDisplayDate ($date, $self->prefs->Timezone);

    # Delete if Deleting
    if ($delete) {
        $self->{audit_deletedEvent}     = $event;
        $self->{audit_deletedEventDate} = $date;

        $allOrOne ||= '';

        # if doing a normal delete, just delete it.
        if ($allOrOne !~ /past|future/i) {
            $db->deleteEvent ($date, $eventID, $allOrOne);
        }
        # But, if deleting all past or future for a Repeating Event, modify
        # the start or end date, and replace it.
        else {
            if (lc ($allOrOne) eq 'past') {
                $event->repeatInfo->startDate ($date - 1);
            }
            if (lc ($allOrOne) eq 'future') {
                $event->repeatInfo->endDate ($date - 1);
            }
            $db->replaceEvent ($event);
        }

        my $url = $self->makeURL ({Op      => 'ShowDay',
                                   Date    => $displayDate,
                                   CalendarName => $displayCal,
                                   ViewCal => $viewCal,
                                   Splunge => time}); # needed as workaround
        print $self->redir ($url);
        return;
    }

    # OK, not deleting; we're editing an existing event.

    my $html = GetHTML->startHTML (title => $i18n->get ('Edit Event'),
                                   op    => $self);

#    $html .= GetHTML->dateHeader ($i18n, $self->prefs->Title, $displayDate);

    my $headerString;
    if ($event->isRepeating) {
        my $repeat18 = $i18n->get ('Edit Repeating Event');
        my %which = (only   => 'Single Occurrence',
                     all    => 'All Occurrences',
                     past   => 'Past Occurrences',
                     future => 'Future Occurrences');
        $headerString = $repeat18 . ' - ' . $i18n->get ($which{lc($allOrOne)});

        # Set dates if only past/future specified
        if (lc ($allOrOne) eq 'past') {
            $event->repeatInfo->endDate ($displayDate);
        }
        if (lc ($allOrOne) eq 'future') {
            $event->repeatInfo->startDate ($displayDate);
        }
    } else {
        $headerString = $i18n->get ('Edit Event');
    }

    # And print out the event editing widgets, set appropriately
    my %params;
    $params{event}      = $event;
    $params{date}       = $date;
    $params{allOrOne}   = $allOrOne;
    $params{mainHeader} = $self->calendarName . ' - ' .
                                   $i18n->get ($headerString);
    $params{newOrEdit}  = 'edit';
    $params{displayCal} = $displayCal;
    $params{viewCal}    = $viewCal;

    $html .= EventEditForm->eventEdit ($self, \%params);

    print $html;
    print $cgi->end_html;
}

sub auditString {
    my ($self, $short) = @_;
    return unless $self->{audit_deletedEvent};     # don't do edit form

    my $summary = $self->SUPER::auditString ($short);
    return ($summary . ' ' . $self->{audit_error}) if $self->{audit_error};

    if ($short) {
        return ($summary . ' ' . $self->{audit_deletedEventDate} . ' ' .
                                 $self->{audit_deletedEvent}->text);
    }

    my $message = "An event was deleted from the '" . $self->calendarName .
                  "' calendar.\n";

    $message .= "\nDate:  " . $self->{audit_deletedEventDate};
    $message .= "\nText:  " . $self->{audit_deletedEvent}->text;
    $message .= ("\nPopup: " . $self->{audit_deletedEvent}->popup)
        if $self->{audit_deletedEvent}->popup;
    $message .= ("\nURL:   " . $self->{audit_deletedEvent}->link)
        if $self->{audit_deletedEvent}->link;

    $message .= "\n\n\n$summary";
    return $message;
}

1;
