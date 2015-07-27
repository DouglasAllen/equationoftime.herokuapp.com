# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# FreeTimeSearch - search for free Time Slots in multiple calendars

package FreeTimeSearch;
use strict;
use CGI;

use Calendar::Date;
use Calendar::EventEditForm;
use Calendar::EventFormProcessor;
use Calendar::Javascript;
use Calendar::MasterDB;

use vars ('@ISA');
@ISA = ('Operation');

sub perform {
    my $self = shift;

    my ($doIt, $done, $isPopupWindow,
        $start_hour, $start_minute, $start_ampm,
        $end_hour, $end_minute, $end_ampm)
          = $self->getParams (qw (DoIt Cancel IsPopup
                                  StartHourPopup StartMinutePopup StartHourRadio
                                  EndHourPopup EndMinutePopup EndHourRadio));

    if ($done) {
        print $self->redir ($self->makeURL ({Op => 'AdminPageUser'}));
        return;
    }

    my $cgi  = new CGI;
    my $i18n = $self->I18N;
    my $cal_name = $self->calendarName;
    my $prefs    = $self->prefs;

    my $results = '';
    my $message;

  RESULTS: {
    if ($doIt) {
        my $efp = EventFormProcessor->new ($self);

        my $date                  = $efp->_parseDate ('Date');
        my ($startTime, $endTime) = $efp->_parseTimes; # get time in minutes

        my @groups = $cgi->param ('CalendarGroups');

        if (!@groups) {
            $message = $i18n->get ('You must select at least one group');
            last RESULTS;
        }

        my ($calendars, $cals_in_no_groups)
                  = MasterDB->getCalendarsInGroup (@groups);

        if (grep /-no group-/, @groups) {
            push @$calendars, @$cals_in_no_groups;
        }

        my $fake_event = Event->new (startTime => $startTime,
                                     endTime   => $endTime);

        my @open_cals;
        my %descriptions;
        my %permissions;
        foreach my $cal (sort {lc $a cmp lc $b} @$calendars) {
            my $db    = Database->new ($cal);
            my $perms = Permissions->new ($db);
            $permissions{$cal} = $perms;     # save; need for making links below

            if (!$perms->permitted ($self->getUser, 'View')) {
                next;
            }

            if ($fake_event->conflicts ($db, $date)) {
                next;
            }
            push @open_cals, $cal;
            $descriptions{$cal} = $db->description;
        }

        $results = '<b>' . $i18n->get ('Calendars with this time slot open')
                   . ':</b><br/>';

        if (@open_cals) {
            my @rows;
            foreach my $open_cal_name (@open_cals) {
                my $can_add = $permissions{$open_cal_name}->permitted
                                  ($self->getUser, 'Add');
                my $link_or_name;
                if ($can_add) {
                    my $url = $self->makeURL ({Op           => 'AddEvent',
                                               Date         => $date,
                                               StartTime    => $startTime,
                                               EndTime      => $endTime,
                                               IsPopup      => undef,
                                               CalendarName => $open_cal_name});
                    if ($isPopupWindow) {
                        $url = "Javascript:SetLocation (window.opener, '$url')";
                    }
                    $link_or_name = $cgi->a ({-href => $url}, $open_cal_name);
                } else {
                    $link_or_name = $open_cal_name;
                }

                push @rows, $cgi->Tr ($cgi->td ($link_or_name),
                                      $cgi->td ($descriptions{$open_cal_name}));
            }
            $results .= $cgi->table (@rows);
        } else {
            $results .= $i18n->get ('No open time slot found in any calendars');
        }
    }
    }

    print GetHTML->startHTML (title  => $i18n->get('Search for Free Time Slot'),
                              op     => $self);

    # redisplay calendar, if we're a popup
    print Javascript->SetLocation;

    # and display the search form
    print GetHTML->PageHeader    ($i18n->get ('Search for Free Time Slot'));
    print GetHTML->SectionHeader ($cal_name) if $cal_name;

    if ($message) {
        print '<center>' . $cgi->h3 ($message) . '</center>';
    }

    my $date = Date->new;
    my $datePopups = GetHTML->datePopup ($i18n, {name    => 'Date',
                                                 id      => 'the_date',
                                                 start   => $date - 750,
                                                 default => $date,
#                                                 style   => 'font-size: 90%',
#                                                 noSelector => 1,
                                                 op      => $self});
    my $milTime = $prefs->MilitaryTime;
    my $none18  = $i18n->get ('None');
    my ($startTimeHourPopup,
        @startTimeRadio) = EventEditForm->_hourPopup
                                              ('nameBase'     => 'StartHour',
                                               'default'      => 9,
                                               'militaryTime' => $milTime,
                                               'None'         => $none18);
    my ($endTimeHourPopup,
        @endTimeRadio)  = EventEditForm->_hourPopup
                                             ('nameBase'      => 'EndHour',
                                              'default'      => 10,
                                              'militaryTime' => $milTime,
                                              'None'         => $none18);
    print $cgi->startform;
    print '<div align="center">';
    print $cgi->table
              ($cgi->Tr
               ($cgi->td ({-align => 'right'}, $i18n->get ('Date:')),
                $cgi->td ({-align => 'right',
                           -colspan => 4}, '&nbsp;' . $datePopups)));

    print '<br/>';

    print $cgi->table
              ($cgi->Tr
               ($cgi->td ({-align => 'right'}, $i18n->get ('Start Time:')),
                $cgi->td ({-align => 'right'}, $startTimeHourPopup),
                $cgi->td ({-align => 'left'},
                   EventEditForm->_minutePopup ('name'    => 'StartMinutePopup',
                                                'default' => 0)),
                $cgi->td (@startTimeRadio)),

               $cgi->Tr
               ($cgi->td ({-align => 'right'},
                          $i18n->get ('End Time:')),
                $cgi->td ({-align => 'right'}, $endTimeHourPopup),
                $cgi->td ({'-align' => 'left'},
                      EventEditForm->_minutePopup ('name'    => 'EndMinutePopup',
                                                   'default' => 0)),
                $cgi->td (@endTimeRadio)));

    print '<hr width="25%">';

    print <<END_JS;
<script language="JavaScript">
<!--
function SetAllTo (on_or_off) {
   var list = document.getElementById('group_list');
   var groups = list.options;
   for (i=0; i<groups.length; i++) {
     groups[i].selected = on_or_off;
   }
}
//-->
</script>
END_JS

    print '<b>' . $i18n->get ('Select Calendar Groups') . '</b><br/>';
    my @groups = sort {lc $a cmp lc $b} MasterDB->getGroups;
    unshift @groups, '-no group-';     # for cals not in any group
    print $cgi->scrolling_list (-name     => 'CalendarGroups',
                                -id       => 'group_list',
                                -values   => \@groups,
                                -size     => 6,
                                -multiple => 'true');
    print '<br/><small><small>';
    print $cgi->a ({-href => "javascript:SetAllTo(1)"},
                   $i18n->get ('Select All'));
    print '&nbsp;&nbsp;';
    print $cgi->a ({-href => "javascript:SetAllTo(0)"},
                   $i18n->get ('Clear All'));
    print '</small></small>';

    print '</div>';
    print '<br/>';

    if ($results) {
        print '<hr/>';
        print "<center>$results</center>";
    }

    print '<hr>';
    print $cgi->submit (-name => 'DoIt',   -value => 'Search');
    print '&nbsp;';
    print $cgi->submit (-name => 'Cancel', -value => $i18n->get ('Done'));
    print $cgi->hidden (-name => 'Op',     -value => __PACKAGE__);
    print $cgi->hidden (-name => 'CalendarName',
                        -value => $cal_name || '');
    print $self->hiddenDisplaySpecs;
    print $cgi->endform;
    print $cgi->end_html;
}

1;
