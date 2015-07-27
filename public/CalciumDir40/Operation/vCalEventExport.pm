# Copyright 2001-2006, Fred Steinberg, Brown Bear Software

# send an event back in vEVENT format

package vCalEventExport;
use strict;
use CGI (':standard');

use Calendar::Date;
use Calendar::EventvEvent;
use Calendar::vCalendar::vCalendar;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;
    my ($date, $id) = $self->getParams (qw (Date ID));

    unless (defined ($date) && defined ($id)) {
        warn "Bad Params to vCalEventExport";
        return;
    }

    my $cgi  = CGI->new;
    my $name  = $self->calendarName();
    my $i18n  = $self->I18N;
    my $prefs = $self->prefs;
    my $db    = $self->db;

    my $addIn = $self->getParams ('AddInName');
    if (defined $addIn) {
        $db = AddIn->new ($addIn, $self->db);
    }

    # Get the Event
    my $event = $db->getEvent ($date, $id);
    unless (defined $event) {
        warn 'vCalEventExport: event has been deleted.';
        return;
    }

    # Get as vEvent
    my $vEvent = $event->vEvent ($date);

    # Set time to UTC (so it works w/Outlook)
    use Time::Local;
    my $now = time;
    my $utc   = timegm (gmtime ($now));
    my $local = timegm (localtime ($now));
    my $hours = int (($local - $utc) / 3600);

    # Check for different DST for now, and event date. Will miss some edge
    # cases (e.g. 1am on day of change.) And repeating events are still
    # problematic.
    my ($y, $m, $d) = Date->new ($date)->ymd;
    my $nowDST   = (localtime ($now))[-1];
    my $eventDST = (localtime (timegm (0, 0, 0, $d, $m-1, $y)))[-1];
#    $hours += ($eventDST - $nowDST);    # actually they're 'true'/'false'
    if ($nowDST != $eventDST) {
        $hours++ if $eventDST;
        $hours-- if $nowDST;
    }

#    $vEvent->convertToUTC ($hours - ($prefs->Timezone || 0));
    $vEvent->convertToUTC ($hours); # don't modify for user timezone! Doh!

    # Set organizer
    my $user = User->getUser ($self->getUsername); # must re-get from DB
    my $address = $user ? $user->email
                        : MasterDB->new->getPreferences ('MailFrom');
    $vEvent->setOrganizer ("MAILTO:$address");

    # Get a vCalendar
    my $vCal = vCalendar->new (events => [$vEvent]);

    my $type = 'text/calendar; method=PUBLISH';
#    my $type = 'text/x-vCalendar; method=PUBLISH';
    my $alltext = $vEvent->summary . $vEvent->description;
    if ($alltext =~ /mime:\s*([a-z\/]+)/i) {
        $type = $1;
    }
    # And display everything
    print $cgi->header (-type                  => $type,
                        '-Content-disposition' => 'filename=event.ics');
#                        -nph  => 1);

    print $vCal->textDump (METHOD => 'PUBLISH');
}

# If event is from an included calendaer, we might be able to view it even
# if we don't have 'view' permission in that calendar
sub authenticate {
    my $self = shift;
    my $incInto = $self->getParams ('IncludedInto');

    my $canView = $self->SUPER::authenticate (@_);
    return $canView if ($canView or !defined $incInto);

    # We're trying to export an included event and we don't have "View"
    # permission in the included calendar. So, make sure the calendar is
    # actually included, and then make sure we can 'view' the including
    # calendar.
    my $incHash = Preferences->new ($incInto)->getIncludedCalendarInfo;
    return undef unless $incHash->{$self->calendarName};
    return Permissions->new ($incInto)->permitted ($self->getUsername, 'View')
}

1;
