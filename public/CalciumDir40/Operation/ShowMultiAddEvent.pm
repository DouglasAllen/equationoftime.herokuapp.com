# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# Display a form for adding a new event to multiple calendars.

package ShowMultiAddEvent;
use strict;
use CGI (':standard');
use Calendar::Date;
use Calendar::GetHTML;
use Calendar::EventEditForm;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my $i18n = $self->I18N;
    my $cgi = new CGI;
    my ($date, @calendars);

    # Get params; they're like "AddEvent-2001/03/23", "Cal-MyCal", "Cal-Blah"
    foreach my $param (keys %{$self->{params}}) {
        my ($left, $right) = split /-/, $param;
        if ($left eq 'AddEvent') {
            $date = $right;
        } elsif ($left eq 'Cal') {
            push @calendars, $right;
        }
    }

    $date = Date->new ($date);
    $self->{audit_date} = $date;

    unless (@calendars) {
        GetHTML->errorPage ($i18n,
                            header  => $i18n->get ('Error adding events'),
                            message => "No calendars specified!");
        return;
    }

    # Validate date
    if (!$date->valid) {
        GetHTML->errorPage ($i18n,
                            header  => $i18n->get ('Error adding events'),
                            message => "Invalid date: $date");
        return;
    }

    # Validate permissions
    my $userName = $self->getUsername;
    foreach (@calendars) {
        if (!Permissions->new ($_)->permitted ($userName, 'Add')) {
            $userName ||= '';
            GetHTML->errorPage ($i18n,
                                header  => $i18n->get ('Error adding events'),
                                message => "User $userName does not have " .
                                           "permission to Add to $_.");
            return;
        }
    }


    print GetHTML->startHTML (title  => $i18n->get ('Add Event'),
                              op     => $self,
                              onLoad =>
                                 "document.EventEditForm.EventText.focus()");

#    print GetHTML->dateHeader ($i18n, $self->prefs->Title, $date);

    print '<div class="EventAddMessage">' .
          '<center>The event will be added to these calendars:<br><b>' .
        join (', ', sort {lc($a) cmp lc($b)} @calendars) .
          '</b></center></div>';

    # And print out the event editing widgets
    my %params;
    $params{date}       = $date;
    $params{mainHeader} = $i18n->get ('Add New Event');
    $params{newOrEdit}  = 'new';
    $params{calList}    = \@calendars;
    $params{nextOp}     = $cgi->param ('NextOp');

    # edit a *new* event
    print EventEditForm->eventEdit ($self, \%params);

    print $cgi->end_html;
}


sub auditString {
    my ($self, $short) = @_;
    my $line =  $self->SUPER::auditString ($short);
    $line .= ' ' . $self->{audit_date};
}

1;
