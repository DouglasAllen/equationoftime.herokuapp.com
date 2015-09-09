# Copyright 2003-2006, Fred Steinberg, Brown Bear Software

package iCalSubscribe;
use strict;

# Dump events as iCalendar, suitable for subscription from Apple's iCal
# If no dates specified, do everything.
#
# Expected params:
#   CalendarName - required
#   FromDate     - optional; e.g. 2002/01/01   (YYYY/MM/DD)
#   ToDate       - optional; e.g. 2002/12/31   (if either, must have both)
#   Include      - optional; if true, use events from included/AddIn calendars
#   Timeshift    - optional; timezone offset, in hours

use Calendar::DisplayFilter;
use Calendar::EventvEvent;
use Calendar::GetHTML;
use Calendar::vCalendar::vCalendar;
use Operation::Operation;
use Time::Local;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    unless ($self->calendarName) {
        GetHTML->errorPage ($self->I18N,
                            header    => 'Subscribe failed',
                            message   => 'No calendar specified.');
        return;
    }

    my $cgi   = CGI->new;
    my $db    = $self->db;
    my $prefs = $self->prefs;

    my ($fromDate, $toDate, $includes, $addins, $timeshift) =
        $self->getParams (qw (FromDate ToDate Includes AddIns Timeshift));

    $fromDate = $fromDate ? Date->new ($fromDate) : Date->openPast;
    $toDate   = $toDate   ? Date->new ($toDate)   : Date->openFuture;

    my ($regHash, $repeats);
    if ($includes or $addins) {
        ($regHash, $repeats) = $db->getEventLists ($prefs, $fromDate, $toDate);
        # If we don't want BOTH includes and addins, remove unwanted ones
        if ($includes xor $addins) {
            my @repeats;
            foreach (@$repeats) {
                my $inc = $_->includedFrom;
                next if ($includes and $inc =~ /^ADDIN/);
                next if ($addins   and $inc !~ /^ADDIN/);
                push @repeats, $_;
            }
            $repeats = \@repeats;

            my %regs;
            foreach my $date (_dateSort ([keys %$regHash])) {
                my @regList;
                foreach (@{$regHash->{$date}}) {
                    my $inc = $_->includedFrom || '';
                    next if ($includes and $inc =~ /^ADDIN/);
                    next if ($addins   and $inc !~ /^ADDIN/);
                    push @regList, $_;
                }
                $regs{$date} = \@regList;
            }
            $regHash = \%regs;
        }
    } else {
        ($regHash, $repeats) = $db->getEvents ($fromDate, $toDate);
    }

    # To remove events we shouldn't see
    my $filter = DisplayFilter->new (operation => $self);

    my @vEvents;
    foreach my $date (_dateSort ([keys %$regHash])) {
        my $dateObj = Date->new ($date);
        my @days_events = $filter->filterTentative ($regHash->{$date});
        @days_events    = $filter->filterPrivate (\@days_events);
        @days_events    = $filter->filter_from_params (\@days_events);
        push @vEvents, map {$_->vEvent ($dateObj)} @days_events;
    }

    my @repeaters = $filter->filterTentative ($repeats);
    @repeaters    = $filter->filterPrivate (\@repeaters);
    @repeaters    = $filter->filter_from_params (\@repeaters);
    push @vEvents, map {$_->vEvent} @repeaters;

    my $now = time;
    my $utc   = timegm (gmtime ($now));
    my $local = timegm (localtime ($now));
    my $hours = int (($local - $utc) / 3600) - ($timeshift || 0);
    if ($hours) {
        foreach (@vEvents) {
            $_->convertToUTC ($hours);
        }
    }

    my $vCal = vCalendar->new (events => \@vEvents);
    my $type     = 'text/calendar';
    my $filename = 'CalciumEvents.ics';
    print $cgi->header (-type   => $type,
                        '-Content-disposition' => "filename=$filename");
    print $vCal->textDump (METHOD => 'PUBLISH');
}

# Return sorted list of date strings passed as listref
# (might get things like 2002/01/22, 2002/1/6)
sub _dateSort {
    my $dates = shift;
    return map  {$_->[0]}
           sort {$a->[1] <=> $b->[1]}
           map  {[$_, Date->new ($_)->_toInt]}
               @$dates;
}

1;
