# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Edit a single event

package EditEvent;
use strict;
use CGI;
use Calendar::Date;
use Calendar::GetHTML;
use Calendar::EventEditForm;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($id, $isPopup) = $self->getParams (qw /EventID PopupWin/);

    my $name        = $self->calendarName;
    my $db          = $self->db;
    my $preferences = $self->prefs;
    my $i18n        = $self->I18N;
    my $theDate     = $self->getParams (qw /Date/); # for sing. inst. repeat

    unless (defined $id and $name) {
        GetHTML->errorPage ($i18n,
                            message => 'Error: Missing Event ID ' .
                                       'or calendar name.');
        return;
    }

    # Get the event
    my ($event, $date) = $db->getEventById ($id);

    unless ($event) {
        GetHTML->errorPage ($i18n,
                            message => 'Warning! This Event has ' .
                                       'been Deleted.');
        return;
    }

    # If EventOwnerOnly, make sure this is the event owner!
    if ($preferences->EventOwnerOnly) {
        my $owner = $event->owner;
        if (defined $owner and
            ($self->getUsername || '') ne $owner and
            !$self->userPermitted ('Admin')) {
            my %args = (message => $i18n->get ('Sorry, you are not '    .
                                               'allowed to edit or '    .
                                               'delete this event.<br>' .
                                               'It is owned by ') .
                                   "<b>$owner</b>.<br><hr>");
            if ($isPopup) {
                $args{onClick} = 'window.close()';
                $args{button}  = $i18n->get ('Close');
            }
            $args{isWarning} = 1;
            GetHTML->errorPage ($i18n, %args);
            return;
        }
    }

    my $header = "$name - " . $i18n->get ('Edit Event');

    # If it's a repeating event, see if we default to editing all
    # instances, or just one
    my $allOrOne = 'all';
    if ($event->isRepeating) {
        # For bannered events in popup, always do 'all', since we
        # can't get a specific date
        unless ($isPopup and $event->repeatInfo->bannerize) {
            $allOrOne = $self->prefs->RepeatEditWhich || 'all';
        }

        my %labels = (all    => $i18n->get ('Editing entire series'),
                      only   => $i18n->get ('Editing only this instance'),
                past   => $i18n->get ('Editing this instance, and all before'),
                future => $i18n->get ('Editing this instance, and all after'));
        $header = "$name - " . $i18n->get ('Edit Repeating Event');
        $header .= ' <br><b>' . $labels{lc($allOrOne)} || '' . '</b>';
        $date = $theDate if ($allOrOne !~ /all/i);
    }

    $self->{audit_eventID} = $id;

    # Print out the event editing widgets
    my %params;
    $params{event}      = $event;
    $params{date}       = Date->new ($date);
    $params{allOrOne}   = $allOrOne;
    $params{mainHeader} = $header;
    $params{newOrEdit}  = 'edit';
    $params{cancelOnClick} = "window.close()" if ($isPopup);
    $params{fromPopupWindow} = $isPopup;
    $params{showDelete} = $i18n->get ('Delete Event');

    my $onLoad   = 'document.EventEditForm.EventText.focus()';
    my $onUnload = 'cleanUpPopups();';

    print GetHTML->startHTML (title    => $i18n->get ('Edit an Event:') .
                                          " $name",
                              op       => $self,
                              onLoad   => $onLoad,
                              onUnload => $onUnload);

    print EventEditForm->eventEdit ($self, \%params);
    print CGI->new ('')->end_html;
}

# This just displays the form, don't bother auditing
sub audit {
    return undef;
}

sub cssDefaults {
    my $self = shift;
    my $prefs = $self->prefs;

    my $css = $self->SUPER::cssDefaults;
    return $css;
}

1;
