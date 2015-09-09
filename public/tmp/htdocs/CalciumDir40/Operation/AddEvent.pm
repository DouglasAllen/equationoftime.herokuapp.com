# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Display form to add an event; typically for popup window

package AddEvent;
use strict;
use CGI;
use Calendar::Date;
use Calendar::GetHTML;
use Calendar::EventEditForm;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($date, $startTime, $endTime, $isPopup) =
                       $self->getParams (qw /Date StartTime EndTime PopupWin/);

    my $name        = $self->calendarName;
    my $db          = $self->db;
    my $preferences = $self->prefs;
    my $i18n        = $self->I18N;

    unless (defined $name) {
        print GetHTML->errorPage ($i18n,
                                  message => 'Error: Missing calendar name.');
        return;
    }

    my $header = "$name - " . $i18n->get ('Add New Event');

    if ($preferences->TentativeSubmit and
        !$self->permission->permitted ($self->getUsername, 'Edit')) {
        $header .= '<center><i>';
        $header .= $i18n->get ('Note: new events will not appear on the ' .
                               'calendar until they are approved.');
        $header .= '</i></center>';
    }

    if ($startTime < 0) {
        $startTime = undef;
        $endTime   = undef;
    }

    # Print out the event editing widgets
    my %params;
    $params{date}       = Date->new ($date);
    $params{allOrOne}   = 'all'; # so repeat stuff shows; fix this
    $params{mainHeader} = $header;
    $params{newOrEdit}  = 'new';
    $params{cancelOnClick} = "window.close()" if ($isPopup);
    $params{fromPopupWindow} = $isPopup;
    $params{defaultStartTime} = $startTime;
    $params{defaultEndTime}   = $endTime;

    my $onLoad   = 'document.EventEditForm.EventText.focus()';
    my $onUnload = 'cleanUpPopups();';

    print GetHTML->startHTML (title    => $i18n->get ('Add an Event:') .
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
