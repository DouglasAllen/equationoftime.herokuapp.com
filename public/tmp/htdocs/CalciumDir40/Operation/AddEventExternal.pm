# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Add event; somewhat special, doesn't use CalendarName
# If no calendar specified, use user's default calendar

package AddEventExternal;
use strict;

use CGI;
use Calendar::EventValidator;

use vars ('@ISA');
@ISA = ('Operation');

# Override Operation::new to set the CalendarName param
sub new {
    my $class = shift;
    my ($paramHash, $authLevel, $user) = @_;

    my $calName = $paramHash->{Calendar} || $paramHash->{CalendarName};

    # If new default calendar submitted from error page, set it
    my $newDefault = $paramHash->{NewDefaultCalendar};
    if (defined $newDefault and $user) {
        $user->setDefaultCalendar ($newDefault);

        # And get the stuff they submitted
        my %params = $class->unmungeParams ($paramHash->{DesiredParams});
        while (my ($k, $v) = each %params) {
            $paramHash->{$k} = $v;
        }
        delete $paramHash->{DesiredParams};
    }

    # If calendar not specified, use user's default cal
    if (!$calName and $user) {
        $calName = $user->defaultCalendar;
    }

    $paramHash->{CalendarName} = $calName; # might still be undef

    $class->SUPER::new (@_);
}

sub perform {
    my $self = shift;

    my ($calName, $date, $day, $month, $year,
        $text, $details, $startTime, $endTime, $timePeriod, $category) =
        $self->getParams (qw (Calendar Date Day Month Year
                              Text Details StartTime EndTime TimePeriod
                              Category Timezone));

    my %params = (Date       => $date,     # either Date...
                  Day        => $day,      # ...or Day, Month, Year
                  Month      => $month,    # But not both. (Date overrides)
                  Year       => $year,
                  Text       => $text,
                  StartTime  => $startTime,
                  EndTime    => $endTime,
                  TimePeriod => $timePeriod);

    my $db = $self->_checkCalendar ($calName); # return undef on error
    return unless $db;

    $calName = $db->name;       # might be using user default

    my $prefs = Preferences->new ($db);
    my $perms = Permissions->new ($db);
    my $i18n  = I18N->new ($prefs->Language);
    my $cgi   = new CGI;
    my @errors;
    my ($event, $repeatObject);

    # Can be multiple categories
    if (defined $category) {
        my @categories;
        foreach ($cgi->param ('MoreCategories')) {
            next if ($_ eq '-' or $_ eq $category);
            push @categories, $_;
        }
        $category = [$category, @categories] if @categories;
    }

    CHECKS: {

          # First, check for Add Permission
          if (!$perms->permitted ($self->getUsername, 'Add')) {
              push @errors, $i18n->get ("You don't have Add Permission in " .
                                        'this calendar');
              push @errors, '<b>' . $i18n->get ('Username') . ': ' . '</b>' .
                            $self->getUsername || $i18n->get ('Anonymous');
              push @errors, '<b>' . $i18n->get ('Calendar') . ': ' . '</b>' .
                            $calName;
              last CHECKS;
          }

          last CHECKS
              if (@errors = $self->_checkParams (\%params, $prefs));

          my ($isRepeating, $endDate, $period, $frequency, $monthWeek,
              $monthMonth, $skipWeekends, $exclusions) =
                  $self->getParams (qw (Repeat EndDate Period Frequency
                                        MonthWeek MonthMonth SkipWeekends
                                        Exclusions));
          if ($isRepeating) {
              my $endDate = Date->new ($endDate);
              if (!$endDate->valid) {
                  push @errors, ('EndDate: '. $i18n->get ('Invalid date'));
                  last CHECKS;
              }
              if ($monthWeek and $monthMonth) {
                  $period = $frequency = undef;
              } else {
                  $period    ||= 'day';
                  $frequency ||= 1;
              }

              $repeatObject = RepeatInfo->new ($date, $endDate, $period,
                                               $frequency, $monthWeek,
                                               $monthMonth, $skipWeekends);
              if ($exclusions) {
                  my @exText = split /\s/, $exclusions;
                  my @exDates = map {Date->new ($_)} @exText;
                  $repeatObject->exclusionList (\@exDates);
              }
          }

          my ($popup, $link) = Event->textToPopupOrLink ($details);

          $event = Event->new (text       => $params{Text},
                               link       => $link,
                               popup      => $popup,
                               startTime  => $params{StartTime},
                               endTime    => $params{EndTime},
                               timePeriod => $params{TimePeriod},
                               repeatInfo => $repeatObject,
                               category   => $category,
                               owner      => $self->getUsername);

          # Validate time conflicts, no future events, no past
          my %errData = $db->validateEvent (event           => $event,
                                            op              => $self,
                                            dateObj         =>$params{DateObj},
                                            ignoreFuture    => 1,
                                            ignoreConflicts => 1);
          while (my ($errName, $data) = each %errData) {
              next unless defined $data;
              if ($errName eq 'blank event') {
                  push @errors, $i18n->get ('You cannot create a blank event');
                  next;
              }

              if ($errName eq 'invalid date') {
                  push @errors, ($i18n->get ('Invalid date') .
                                 ": $params{DateObj}");
                  next;
              }
              if ($errName eq 'invalid repeat until date') {
                  push @errors, ($i18n->get ('Invalid "repeat until" date') .
                                 ": $endDate");
                  next;
              }
              if ($errName eq 'start date after end date') {
                  push @errors, $i18n->get ('<b>Repeat Until Date</b> ' .
                                            'cannot be before the first ' .
                                            'date of the event.');
                  next;
              }
              if ($errName eq 'past event') {
                  push @errors, $i18n->get ('This calendar does not allow ' .
                                            'creating or editing events ' .
                                            "before today's date.");
                  next;
              }
              if ($errName eq 'future limit') {
                  push @errors, $i18n->get ('This calendar is set to not ' .
                                            'permit adding or editing ' .
                                            'events that far in the future.');
                  next;
              }
              if ($errName eq 'time conflict') {
                  push @errors, $i18n->get ('The time of the event conflicts' .
                                            ' with an existing event');
                  next;
              }
              if ($errName eq 'repeating w/no instances') {
                  push @errors, $i18n->get ('The specified repeat options ' .
                                            "don't define any actual " .
                                            'instances.');
                  next;
              }
              warn "Unknown error in AddEventExternal: $errName\n";
              push @errors,  $i18n->get ('Unknown error creating/editing ' .
                                         'event');
          }
          last CHECKS if @errors;
    }

    if (@errors) {
        my $message = '<ul><li>' .
                        (join '</li><li>', (map {$i18n->get ($_)} @errors)) .
                      '</li></ul>';
        GetHTML->errorPage ($i18n,
                            header  => 'Add Event Error',
                            message => $message);
        return;
    }

    # Might be tentative
    if ($prefs->TentativeSubmit and
        !$perms->permitted ($self->getUsername, 'Edit')) {
        $event->isTentative (1);
    }

    $db->insertEvent ($event, $params{DateObj});

    my $url = $self->makeURL ({Op            => 'ShowIt',
                               CalendarName  => $calName},
                               Date          => $date);

    print GetHTML->startHTML (title  => $i18n->get ('Add Event'),
                              op     => $self,
                              Refresh => "2; URL=$url");
    print '<center>';
    print $cgi->h1 ($i18n->get ('Event Added') . ' - ' .
                    $i18n->get ('Calendar')    . " '$calName'");
    print $cgi->p ($i18n->get ('Click') . ' ' .
                   $cgi->a ({href => $url}, $i18n->get ('here')) . ' '.
                   $i18n->get ('to continue, or just ' .
                               'wait a second...'));
    print '</center>';
    print $cgi->end_html;
}


sub _checkCalendar {
    my ($self, $calName) = @_;

    my $user = $self->getUser;
    my $i18n = $self->I18N;

    # If not logged in and no calendar specified, go to login page
    unless ($user or $calName) {
        my $url = $self->makeURL ({Op            => 'UserLogin',
                                   DesiredOp     => $self->opName,
                                   DesiredParams => $self->mungeParams
                                                          ($self->rawParams)});
        print $self->redir ($url);
        return;
    }

    # If no calendar, get user's default calendar. If none set, let them
    # pick one.
    if (!$calName) {
        $calName = $user->defaultCalendar;
        if (!$calName) {
            my $more;
            my @theCals = sort {lc ($a) cmp lc ($b)}
                grep {Permissions->new ($_)->permitted ($user, 'Add')}
                    MasterDB->getAllCalendars;
            if (@theCals) {
                my $cgi = CGI->new;
                $more = $cgi->startform;
                $more .= $i18n->get ('Select a calendar');
                $more .= '<br>';
                $more .= $cgi->scrolling_list (-name   => 'NewDefaultCalendar',
                                               -Values => \@theCals,
                                               -size   => 5);
                $more .= '<p>';
                $more .= $cgi->submit (-name  => 'SetDefault',
                                       -value => $i18n->get ('Set Default'));
                $more .= $cgi->hidden (-name  => 'Op',
                                       -value => $self->opName);
                $more .= $cgi->hidden (-name  => 'DesiredParams',
                                       -value => $self->mungeParams
                                                           ($self->rawParams));
                $more .= '</p>';
                $more .= $cgi->endform;
                $more .= '<hr align="left" width="50%">';
            } else {
                $more = $i18n->get ("Sorry, you don't have Add permission " .
                                    'in any calendars');
            }

            GetHTML->errorPage ($i18n,
                                header   => $i18n->get ('Add Event Error'),
                                message  => $i18n->get ('User') . ' "' .
                                            $user->name . '" ' .
                                            $i18n->get ('has no default ' .
                                                        'calendar'),
                                moreStuff => $more);
            return;
        }
    }

    # Make sure calendar exists
    my $db = Database->new ($calName);
    unless ($$db->{Imp}->dbExists) {
            GetHTML->errorPage ($i18n,
                                header  => 'Add Event Error',
                                message => 'Calendar does not exist: ' .
                                           $calName);
            return;
    }
    return $db;
}

# Validate and sanitize parameters
sub _checkParams {
    my ($self, $params, $prefs) = @_;

    my @messages;

    if (!$params->{Text}) {
        push @messages, 'You cannot create a blank event';
    }

    # Times must be between 0 and 24*60-1 (i.e. midnight --> 11:59pm)
    if (defined $params->{StartTime} and
        ($params->{StartTime} < 0 or $params->{StartTime} > 24*60-1)) {
        push @messages, 'Invalid start time';
    }
    if (defined $params->{EndTime} and
        ($params->{EndTime} < 0 or $params->{EndTime} > 24*60-1)) {
        push @messages, 'Invalid end time';
    }

    # Check Date, or Year, Month, Day
    my $date;
    if ($params->{Date}) {
        $date = Date->new ($params->{Date});
    } else {
        $date = Date->new ($params->{Year}, $params->{Month}, $params->{Day});
    }
    if ($date->valid) {
        $params->{DateObj} = $date;
    } else {
        push @messages, 'Invalid date';
    }

    return @messages;
}

1;
