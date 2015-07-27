# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Entry point for client synchronization

package TripleSync;
use strict;

use CGI;
use Calendar::Database;
use Calendar::Event;
use Calendar::Permissions;
use Calendar::Preferences;
use Calendar::User;
use Calendar::SyncInfo;

use vars ('@ISA', '$TS_VERSION_SUPPORTED', '$DEBUGFILE');
@ISA = ('Operation');

$TS_VERSION_SUPPORTED = 3;

my %ops = (StartSync     => 'StartSync',
           EndSync       => 'EndSync',
           GetAll        => 'GetAll',
           GetModified   => 'GetModified',
           DeleteAll     => 'DeleteAll',
           Delete        => 'DeleteIt', # conflicts w/CGI? odd
           AddOrModify   => 'AddOrModify',
           GetCategories => 'GetCategories',
           SetActiveCal  => 'SetActiveCal',
           ResetFlags    => 'ResetFlags',
           PurgeDeleted  => 'PurgeDeleted',
          );

sub perform {
    my $self = shift;
    $|++;

    eval {alarm 0};    # rely on TripleSync's timeout

    my $cgi = CGI->new;
    $self->{_cgi} = $cgi;

    # Debug logging is disabled for security; otherwise, any TS could turn
    # it on, and fill up your disk. To allow logging, change the 0 to 1 in
    # the 'if' statement a few lines below. Note that this does _not_ turn
    # on logging, it just allows TS users to turn it on for their sync, by
    # adding the 'Logging=1' param to the URL they sync against.
    my $logit = $cgi->url_param ('Logging');
    if (0 and $logit) {         # change 0 to 1 to allow logging
        $DEBUGFILE = $cgi->url_param ('Logfile') || '/tmp/tsync.log';
        open (DEBUG, ">>$DEBUGFILE")
            || die "Can't open sync log file '$DEBUGFILE': $!\n";
        print DEBUG scalar (localtime), "\n";
        print DEBUG "---- Start ----\n";
        foreach ($cgi->param) {
            my $val = $cgi->param ($_);
            $val = '********' if ($_ eq 'Password');
            print DEBUG "Param: $_: --> ", $val, "\n";
        }
        print DEBUG "\n";
        close DEBUG;
    }

    my $operation = $cgi->param ('Operation');
    $self->errorResponse ("Hey, no operation specified!")
        if  !defined $operation;
    $self->errorResponse ("Hey, bad operation! `$operation'")
        if (!exists $ops{$operation});

    my %params = map {$_ => $cgi->param ($_)} $cgi->param;

    # Hack - undefine the stuff that's used to see whether or not to spit
    # an HTML error page out when we die.
    delete $ENV{HTTP_HOST};
    delete $ENV{GATEWAY_INTERFACE};
    delete $ENV{USER_AGENT};
    delete $ENV{REQUEST_METHOD};

    my $method = $ops{$operation};
    $self->$method (\%params);
}


#############################################################################
#     Sync Ops follow
#############################################################################

sub StartSync {
    my ($self, $params) = @_;
    my $username = $params->{User};
    my $password = $params->{Password};
    my $calendar = $params->{Calendar};
    my $timeOut  = $params->{Timeout} || 60;
    my $rmid     = $params->{RMID};
    my $tsVersion = $params->{Version} || 1; # not defined in TS 1.0
    my $includes  = $params->{IncCal};        # want events from included cals?

    # if server authenticated, use that username and ignore pw
    my $authenticated;
    if ($ENV{REMOTE_USER} and $ENV{REMOTE_USER} ne '-') {
        $username = $ENV{REMOTE_USER};
        $authenticated = 1;
    }

    # if special 'internal' for LDAP user, fix username
    my $LDAPinternal;
    if ($username and
        $username =~ /^internal (.*)/i) { # check for LDAP special case
        $username = $1;
        $LDAPinternal++;
    }

    my $sync = SyncStuff->new (MainCal   => $calendar,
                               Username  => $username,
                               Timeout   => $timeOut,
                               TSVersion => $tsVersion);

    # Calendar exists, or die
    if (!defined $sync or !defined $sync->calendarDB) {
        my $name = defined $calendar ? $calendar : '<undefined>';
        $self->errorResponse ("Calendar not found '$name'");
    }

    # Authenticate or die
    if (!$authenticated and defined $username) {

        my $ok;
        if (!$LDAPinternal) {
            $ok = User->checkPassword ($username, $password);
        } else {
            require Calendar::User::CalciumAuth; # only w/LDAP extension
            $ok = User::CalciumAuth->checkPassword ($username, $password);
        }

        if (!$ok) {
            $self->errorResponse("Authentication failed for user '$username'");
        }
    }

    # Calendar must be syncable
    unless ($sync->calendarDB->getPreferences ('IsSyncable')) {
        $self->errorResponse ("Calendar '$calendar' is configured to " .
                              "prevent syncing.");
    }

    # User must have at least View permission
    if (!$sync->userPermitted ('View')) {
        $username ||= '[anonymous]';
        $self->errorResponse ("User '$username' must have at least View " .
                              "permission in '$calendar'");
    }

    # Lock and backup main calendar (to revert on error), or die
    {
        local $! = undef;
        unless ($sync->calendarDB->lockForSync ($timeOut)) {
            my $mess = "$!" || "Sync already in process";
            $self->errorResponse ("Can't lock $calendar, $mess")
        }
        $sync->calendarDB->backupForSync
            or $self->errorResponse ("Can't make backup copy of web calendar");
    }

    my @retArgs;

    if ($tsVersion > 1) {
        # Get info on each included calendar; AddIns are special.
        if ($includes) {
            my @writables;
            my $prefs = $sync->calendarDB->getPreferences;
            my $includes = $prefs->getIncludedCalendarInfo ('all');
            my @names = keys %$includes;
            push @retArgs, scalar (@names);
            foreach my $calName (@names) {
                my ($db, $edit, $override, $theName);
                if ($calName !~ /^ADDIN /) {
                    $db = Database->new ($calName);
                    $edit = Permissions->new ($db)->permitted ($username,
                                                               'Edit') ? 1 : 0;
                    $override = $includes->{$calName}->{Override};
                    $theName = $calName;
                } else {
                    my $addInName = $calName;
                    $addInName =~ s/^ADDIN //;
                    $db = AddIn->new ($addInName, $sync->calendarDB);
                    $edit = 0;
                    $override = 1;
                    $theName = $addInName;
                }
                my $lastRMID = $db->getPreferences ('LastRMSyncID') || 0;
                $db->setPreferences ({LastRMSyncID => $rmid});

                my $fg     = $includes->{$calName}->{FG};
                my $bg     = $includes->{$calName}->{BG};
                my $border = $includes->{$calName}->{Border};
                my $text   = escapeIt ($includes->{$calName}->{Text});

                my $line = "$theName,$lastRMID,$edit,$override,$fg,$bg," .
                           "$border,$text";

                if ($tsVersion > 2) {
                    my $cats = $includes->{$calName}->{Categories} || [];
                    $cats = join ';', @$cats;
                    $line .= ",$cats";
                }

                push @retArgs, $line;

                # if we can edit it, lock and save for revert
                if ($edit) {
                    push @writables, $calName;
                    local $! = undef;
                    unless ($db->lockForSync ($timeOut)) {
                        my $mess = "$!" || "Sync already in process";
                        $self->errorResponse ("Can't lock $calName, $mess")
                    }
                    $db->backupForSync
                        or $self->errorResponse ("Can't make backup copy of " .
                                                 "included calendar: " .
                                                 "$calName");
                }
            }

            $sync->setWriteableCalendars (@writables);
        }
    }

    # If logging, dump sync info, and ALL events
    if (defined $DEBUGFILE) {
        my $syncInfo = SyncInfo->new ($sync->calendar);
        my @added    = sort {$a <=> $b} @{$syncInfo->getAdded};
        my @modified = sort {$a <=> $b} @{$syncInfo->getModified};
        my @deleted  = sort {$a <=> $b} @{$syncInfo->getDeleted};
        open (DEBUG, ">>$DEBUGFILE")
            || die "Can't open sync log file '$DEBUGFILE': $!\n";
        print DEBUG "---- Changes since Last Sync ----\n";
        print DEBUG 'Added:    ' . join (' ', @added), "\n";
        print DEBUG 'Modified: ' . join (' ', @modified), "\n";
        print DEBUG 'Deleted:  ' . join (' ', @deleted), "\n";
        print DEBUG "\n";
        close DEBUG;
        _dumpAllEvents ($sync->calendarDB,
                        "---- All Events @ StartSync ----\n");
    }

    my $lastRemindMeID = $sync->calendarDB->getPreferences ('LastRMSyncID');
    $sync->calendarDB->setPreferences ({LastRMSyncID => $rmid});

    # must do this _after_ setWriteableCalendars() call
    my $sessionID = $sync->createSessionID;

    my $supported = $tsVersion > $TS_VERSION_SUPPORTED ? $TS_VERSION_SUPPORTED
                                                       : $tsVersion;
    unshift @retArgs, ($sessionID,
                       $lastRemindMeID || 0,
                       $supported);

    $self->successResponse (@retArgs);
}

sub EndSync {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};
    my $success   = $params->{Success};
    my $timedOut  = $params->{TimedOut};

    my $sync = SyncStuff->newFromID ($sessionID) or
                 $timedOut ? exit
                           : $self->errorResponse ("EndSync - bad SessionID");

    # Set back to Main cal, in case we had included ones.
    $sync->setActiveCalendar ($sessionID, $sync->mainCalendar);

    if ($timedOut) {
        warn 'Sync timed out; ' .
             'Calendar: ' . $sync->calendar .
             ', User: '   . $sync->username . "\n";
    }

    # User must have at least View permission
    if (!$sync->userPermitted ('View')) {
        $self->errorResponse ("EndSync - User cannot Sync `" .
                              $sync->calendar . "'");
    }

    $sync->removeSessionID ($sessionID);

    # unlock and maybe revert. This does the main calendar, and all
    # writeable included calendars
    my $message;
    if (!$success) {
        $sync->revertCalendars
            or $self->errorResponse ("EndSync - can't revert calendar");
        $message = "Sync failed  - calendar reverted";
    }

    # Dump ALL events to log file
    if (defined $DEBUGFILE) {
        _dumpAllEvents ($sync->calendarDB,
                        "---- All Events @ EndSync ----\n");
    }

    $sync->unlockCalendars
        or $self->errorResponse ("EndSync - can't unlock calendar! " .
                                 $sync->{error});

    $self->successResponse ($message);
}


sub GetAll {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("GetAll - bad SessionID");

    # User must have at least View permission, or calendar must be in
    # include list
    if (!$sync->userPermitted ('View') and !$sync->isIncluded) {
        $self->errorResponse ("GetAll - User cannot View `" .
                              $sync->calendar . "'");
    }

    my $db = $sync->calendarDB;

    my $regulars  = $db->getAllRegularEvents;    # hashref, keyed on date
    my $repeaters = $db->getAllRepeatingEvents;  # listref

    # Filter out tentative events, if we don't have Edit perm
    if (!$sync->userPermitted ('Edit')) {
        my @r = grep {!$_->isTentative} @$repeaters;
        $repeaters = \@r;

        foreach my $date (keys %$regulars) {
            my $eventList = $regulars->{$date};
            my @reg = grep {!$_->isTentative} @$eventList;
            $regulars->{$date} = \@reg;
        }
    }

    my $prefs;

    # Filter out events we don't actually want, based on main including cal
    if ($sync->calendar ne $sync->mainCalendar) {
        my $mainDB = Database->new ($sync->mainCalendar);
        eval {$prefs = $mainDB->getPreferences;};
        return undef if $@;     # shouldn't happen

        my $incInfo = $prefs->getIncludedCalendarInfo;
        my $theCats = $incInfo->{$sync->calendar}->{Categories};
        if ($theCats and (@$theCats > 0)) {         # if limited by categories
            my $noCats = grep {$_ eq '<- - - ->'} @$theCats;
            my @r = grep {($noCats and !$_->getCategoryList) or
                          ($_->inCategory ($theCats))} @$repeaters;
            $repeaters = \@r;

            foreach my $date (keys %$regulars) {
                my $eventList = $regulars->{$date};
                my @reg = grep {($noCats and !$_->getCategoryList) or
                                ($_->inCategory ($theCats))} @$eventList;
                $regulars->{$date} = \@reg;
            }
        }
    }

    # If included, remove 'Private' events and/or set text for non-publics
    if ($sync->calendar ne $sync->mainCalendar) {
        my @reps = grep $_, map {_checkIt ($_)} @$repeaters;
        $repeaters = \@reps;

        require Calendar::I18N;
        my $i18n = I18N->new ($prefs->Language);

        foreach my $date (keys %$regulars) {
            my $eventList = $regulars->{$date};
            my @regs = grep $_, map {_checkIt ($_, $i18n)} @$eventList;
            $regulars->{$date} = \@regs;
        }
        sub _checkIt {
            my ($ev, $i18n) = @_;
            return $ev   if $ev->public;
            return undef if $ev->private;           # don't display at all
            # otherwise, omit details
            $ev->link (undef);
            $ev->popup (undef);
            # And set the text (unless it's just private popup)
            if (!$ev->privatePopup) {
                my $x = $ev->displayString ($i18n);  # e.g. 'Unavailable'
                $ev->text ($x) if $x;
            }
            return $ev;
        }
    }

    my $eventCount = 0;
    foreach (keys %$regulars) {
        $eventCount += @{$regulars->{$_} || []};
    }
    $eventCount += @$repeaters;

    my $offset = $sync->userTimezone;    # might need to adjust for timezone

    my @eventStrings;
    foreach my $date (keys %$regulars) {
        my $eventList = $regulars->{$date};
        foreach (@$eventList) {
            my $theDate = $date;
            if ($offset) {
                $theDate = adjustEvent ($_, Date->new ($date), $offset);
            }
            push @eventStrings, eventString ($theDate, $_, syncObj => $sync);
        }
    }

    foreach (@$repeaters) {
        my $date = $_->repeatInfo->startDate;
        if ($offset) {
            $date = adjustEvent ($_, $date, $offset);    # $date is a Date
        }
        push @eventStrings, eventString ($_->repeatInfo->startDate, $_,
                                         syncObj => $sync);
    }


    $self->successResponse ($eventCount, @eventStrings);
}

# Return list of modified, deleted, and newly added events
sub GetModified {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("GetModified - bad SessionID");

    # User must have at least View permission, or calendar must be in
    # include list
    if (!$sync->userPermitted ('View') and !$sync->isIncluded) {
        $self->errorResponse ("GetModified - User cannot View `" .
                              $sync->calendar . "'");
    }

    my @eventStrings;

    my $offset = $sync->userTimezone;    # might need to adjust for timezone

    my $syncInfo = SyncInfo->new ($sync->calendar);

    foreach my $id (@{$syncInfo->getAdded}) {
        my ($event, $date) = $sync->findEvent ($id);
        next unless $event;     # skip if can't find it
        if ($offset) {
            $date = adjustEvent ($event, Date->new ($date), $offset);
        }
        push @eventStrings, eventString ($date, $event,
                                         modified => 1,
                                         syncObj  => $sync);
    }
    foreach my $id (@{$syncInfo->getModified}) {
        my ($event, $date) = $sync->findEvent ($id);
        next unless $event;     # skip if can't find it
        if ($offset) {
            $date = adjustEvent ($event, Date->new ($date), $offset);
        }
        push @eventStrings, eventString ($date, $event,
                                         modified => 1,
                                         syncObj  => $sync);
    }
    foreach my $id (@{$syncInfo->getDeleted}) {
        push @eventStrings, "$id,0,1";
    }

    $self->successResponse (scalar @eventStrings, @eventStrings);
}


sub DeleteAll {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("DeleteAll - bad SessionID");

    # User must have at Edit permission
    if (!$sync->userPermitted ('Edit')) {
        $self->errorResponse ("DeleteAll - User cannot Edit `" .
                              $sync->calendar . "'");
    }

    my $db = $sync->calendarDB;
    $db->deleteAllEvents;
    $self->successResponse;
    return;
}


sub DeleteIt {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};
    my $data      = $params->{Data}; # count and ids of events to delete

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("Delete - bad SessionID");

    # User must have at Edit permission
    if (!$sync->userPermitted ('Edit')) {
        $self->errorResponse ("Delete - User cannot Edit `" .
                              $sync->calendar . "'");
    }

    my @records = split "\r\n", $data;

    my $count = shift @records || 0;

    my (@ids, @badIDs);
    foreach my $id (@records) {
        $id =~ s/\W//g;         # for \r crap,
        next if ($id eq '');
        my $event = $sync->findEvent ($id);
        if (!$event) {
            push @badIDs, $id;
            next;
        }
        push @ids, $id;
        my $text = $sync->deleteEvent ($id);
    }

    if ($count != @ids) {
        my $num = @ids;
        warn "Hey, count ($count) != num items ($num) in Delete!\n";
    }

    if (@badIDs) {
        $self->errorResponse ("Could not delete events: " .
                              join (',', @badIDs));
    } else {
        $self->successResponse ('deleted ' . scalar @ids, @ids);
    }
}


sub AddOrModify {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};
    my $data      = $params->{Data};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("AddOrModify - bad SessionID");
    my $db = $sync->calendarDB;

    # User must have at least Add permission
    if (!$sync->userPermitted ('Add')) {
        $self->errorResponse ("AddOrModify - User cannot Add to `" .
                              $sync->calendar . "'");
    }
    my $canEdit = $sync->userPermitted ('Edit');
    my $username = $sync->username;
    my %map = (id         => 0,
               modified   => 1,
               deleted    => 2,
               isTimed    => 3,
               startHour  => 4,
               startMin   => 5,
               endHour    => 6,
               endMin     => 7,
               year       => 8,
               month      => 9,
               day        => 10,
               text       => 11,
               extraText  => 12,
               repeatType => 13,
               frequency  => 14,
               hasEnd     => 15,
               endYear    => 16,
               endMonth   => 17,
               endDay     => 18,
               repeatOn   => 19,
               exceptions => 20,
              );

    my @responseLines;
    my (@newRepeaters, @newRegulars);

    # data is long string; split on newlines
    my ($numRecords, @records) = split "\r\n", $data;
    foreach (@records) {

        # Fields are comma separated; nested commas are backslashed
        s/\\,/$;/g;
        my @fields = map {s/$;/,/g; $_} split /,/;

        if  (@fields < 11) {
            warn "Bad record: $_\n";
            next;
        }

        my $date = Date->new ($fields[$map{year}],
                              $fields[$map{month}],
                              $fields[$map{day}]);

        my ($startTime, $endTime, $dateChange);
        if ($fields[$map{isTimed}]) {
            $startTime = 60*$fields[$map{startHour}] + $fields[$map{startMin}];
            $endTime   = 60*$fields[$map{endHour}]   + $fields[$map{endMin}];
            undef $endTime if ($startTime == $endTime);

            # If we have a timezone offset, adjust accordingly
            if (my $offset = $sync->userTimezone) {
                $startTime -= $offset * 60;     # $offset is in hours
                $endTime   -= $offset * 60 if (defined $endTime);
                # and see if we changed days
                if ($startTime < 0) {
                    $date -= int ($startTime/-1440) + 1;     # 1440 = 24 * 60
                    $dateChange = -1;
                } elsif ($startTime >= 24*60) {
                    $date += int ($startTime/1440);
                    $dateChange = 1;
                }

                $startTime %= 1440;
                $endTime   %= 1440 if (defined $endTime);
            }
        }

        my $lorp = unEscapeIt ($fields[$map{extraText}]);
        my ($popup, $link) = Event->textToPopupOrLink ($lorp);

        my $repeatObject;
        my $repType = $fields[$map{repeatType}];
        if ($repType) {
            my $endDate;
            if ($fields[$map{hasEnd}]) {
                $endDate = "$fields[$map{endYear}]/$fields[$map{endMonth}]/" .
                           "$fields[$map{endDay}]";
            } else {
                $endDate = Date->openFuture;
            }

            my ($period, $frequency);
            if    ($repType == 5) {$period = 'year'}
            elsif ($repType == 4) {$period = 'month'}
            elsif ($repType == 2) {$period = 'week'}
            elsif ($repType == 1) {$period = 'day'}
            $frequency = $fields[$map{frequency}] if ($period);

            my $repeatOn = $fields[$map{repeatOn}];

            # If, e.g. "M,W,F"
            if ($repType == 2 and $repeatOn) {
                my @days;
                push (@days, 1) if ($repeatOn & 0x02);    # Monday
                push (@days, 2) if ($repeatOn & 0x04);    # Tuesday
                push (@days, 3) if ($repeatOn & 0x08);    # Wednesday
                push (@days, 4) if ($repeatOn & 0x10);    # Thursday
                push (@days, 5) if ($repeatOn & 0x20);    # Friday
                push (@days, 6) if ($repeatOn & 0x40);    # Saturday
                push (@days, 7) if ($repeatOn & 0x01);    # Sunday

                # If timezone adjust moved to different day, adjust these
                if ($dateChange) {
                    foreach my $day (@days) {
                        $day += $dateChange;     # 1-7
                        if ($day < 1 or $day > 7) {
                            $day = $day % 7;
                            $day ||= 7;
                        }
                    }
                }

                $period = join ' ', sort @days;

                # If only a single day, handle appropriately; find first
                # - set period back to 'week'
                # - set date to first occurrence of that day on or after
                #   start date
                if (@days == 1) {
                    $period = 'week';
                    my $dateOrig = $date;
                    my $i = 0;    # just for inf. loop safeguard
                    while ($date->dayOfWeek != $days[0] and $i++ < 7) {
                        $date++;
                    }
                    $date = $dateOrig if $i > 6;
                } # else, we don't have this combination of days on our edit
                  # form, we're out of luck
            }

            # If, e.g. "3rd Monday of month"
            my ($monthWeek, $monthMonth);
            if ($repType == 3) {
                my ($week, $day) = (int ($repeatOn / 7), $repeatOn % 7);
                $monthWeek = $week + 1;
                $day ||= 7;  # rm has sun==0, we need 7
                $monthMonth = $fields[$map{frequency}] || 1; # every N months
                # Must set start date to occur on the day of week
                $date++ while ($date->dayOfWeek != $day);
            }

            my @exList;
            my $exceptCount = $fields[$map{exceptions}];
            if ($exceptCount) {
                for (0..$exceptCount-1) {
                    my $yIndex = $map{exceptions} + ($_ * 3) + 1;
                    my ($y, $m, $d) = @fields[$yIndex..$yIndex+2];
                    push @exList, "$y/$m/$d";
                }
            }
            unless ($date and $endDate and
                    (($period and $frequency) or
                     ($monthWeek and $monthMonth))) {
                $self->errorResponse ("AddOrModify - bad Repeating " .
                                      "Information - '" .
                                      unEscapeIt ($fields[$map{text}]) . "'");
            }

            $repeatObject = RepeatInfo->new ($date, $endDate, $period,
                                             $frequency, $monthWeek,
                                             $monthMonth, undef); # no skip w.e
            $repeatObject->exclusionList (\@exList) if @exList;
        }

        # Get TS v2 fields; color, border, category
        my ($fgColor, $bgColor, $border, $category);
        if ($sync->tsVersion > 1) {
            my $index = $map{exceptions} + $fields[$map{exceptions}] * 3 + 1;
            $fgColor  = unEscapeIt ($fields[$index++]);
            $bgColor  = unEscapeIt ($fields[$index++]);
            $border   = unEscapeIt ($fields[$index++]);
            $category = unEscapeIt ($fields[$index++]);
            undef $category if (defined ($category) and $category eq '-');
        }

        my $event = Event->new (text       => unEscapeIt ($fields[$map{text}]),
                                link       => $link,
                                popup      => $popup,
                                startTime  => $startTime,
                                endTime    => $endTime,
                                repeatInfo => $repeatObject,
                                owner      => $username,
                                bgColor    => $bgColor,
                                fgColor    => $fgColor,
                                drawBorder => $border,
                                category   => $category,
                               );


        my $id = $fields[$map{id}];
        if ($id) {
            # replacing existing event
            if (!$canEdit) {
                push @responseLines, ("-1 AddOrModify - User cannot Modify `" .
                                      $sync->calendar . "'");
                next;
            }

            # Since there are lots of Calcium-only fields, lets get the
            # old event, set the fields we know about, and replace it.
            my ($oldEvent, $oldDate) = $sync->findEvent ($id);

            if (!$oldEvent) {
                push @responseLines, ("-1 cannot find event with ID $id in '" .
                                      $sync->calendar . "'");
                next;
            }

            my @fields = qw (text link popup startTime endTime
                             repeatInfo owner);
            if ($sync->tsVersion > 1) {
                push @fields, qw (bgColor fgColor drawBorder category)
            }
            foreach (@fields) {
                $oldEvent->$_ ($event->$_());
            }
            $event = $oldEvent;
            $event->id ($id);

            # Need to delete here, since replaceEvent needs date to find event
            # to delete - and date may have been modified in TS!
            $sync->deleteEvent ($id, 'no sync entry');

            $db->replaceEvent ($event, $date, 'no delete');
            push @responseLines, $id;
        } else {
            # Must keep track of order of events, so we can return new IDs
            # in the same order. Note that bulk inserts mixes the order up
            # if there are both regular and repeating events! (And we don't
            # get the ids until they're actually inserted.)
            push @responseLines, ($repeatObject ? 'repnew' : 'regnew');

            # save event for bulk insertion
            if ($event->isRepeating) {
                push @newRepeaters, $event;
            } else {
                push @newRegulars, ($event, $date);
            }
        }
    }

    # insert new events; NOTE! insertEvents() consumes the lists it gets
    my $newRegs = $db->insertEvents (\@newRegulars);
    my $newReps = $db->insertEvents (\@newRepeaters);

    # bulk insertEvents must return events in same order as passed in
    my @realResponse;
    foreach my $id (@responseLines) {
        my $event;
        if ($id eq 'repnew') {
            my $event = shift @$newReps;
            push @realResponse, $event->id;
        } elsif ($id eq 'regnew') {
            my $event = shift @$newRegs;
            push @realResponse, $event->id;
        } else {
            push @realResponse, $id;
        }
    }
    @responseLines = @realResponse;

#     foreach my $event (@$newRegs, @$newReps) {
#         next unless ref ($event) and $event->isa ('Event'); # unneeded?
#         push @responseLines, $event->id;
#     }

    if ($numRecords != @responseLines) {
        warn "Warning: inserted count != sent count.\n";
    }

    $self->successResponse (scalar @responseLines, @responseLines);
    return;
}

# Get Categories for active calendar.
sub GetCategories {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("GetCategories - bad SessionID");
    my $db = $sync->calendarDB;

    # User must have at least View permission
    if (!$sync->userPermitted ('View')) {
        $self->errorResponse ("GetCategories - User cannot View `" .
                              $sync->calendar . "'");
    }

    my @retLines;
    my $catHash = Preferences->new ($db)->getCategories ('masterToo');
    push @retLines, scalar (keys %$catHash);

    # now get settings for these categories in the master calendar
#   my $cats;
#   if ($sync->calendar eq $sync->mainCalendar) {
#       $cats = $catHash;
#   } else {
#       $cats = Preferences->new ($sync->mainCalendar)->getCategories ('mtoo');
#   }

#     foreach my $name (keys %$catHash) {
#         my @info = ($name, '','','','');
#         if ($cats->{$name}) {
#             @info = ($name,
#                      $cats->{$name}->fg || '',
#                      $cats->{$name}->bg || '',
#                      $cats->{$name}->border   ? 1 : 0,
#                      $cats->{$name}->showName ? $name : '');
#         }
#         push @retLines, join (',', @info);
#     }

    while (my ($name, $cat) = each %$catHash) {
        my @info = ($name,
                    $cat->fg || '',
                    $cat->bg || '',
                    $cat->border   ? 1 : 0,
                    $cat->showName || '');
        push @retLines, join (',', @info);
    }
    $self->successResponse (@retLines);
}

sub SetActiveCal {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};
    my $activeCal = $params->{ActiveCalendar};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("SetActiveCal - bad SessionID");

    $sync->setActiveCalendar ($sessionID, $activeCal)
        or $self->errorResponse ('SetActiveCal - ' . $sync->error);

    $self->successResponse;
}

sub ResetFlags {
    my ($self, $params) = @_;
    my $sessionID = $params->{SessionID};

    my $sync = SyncStuff->newFromID ($sessionID)
        or $self->errorResponse ("ResetFlags - bad SessionID");
    my $db = $sync->calendarDB;

    # User must have at least View permission, or calendar must be in
    # include list
    if (!$sync->userPermitted ('View') and !$sync->isIncluded) {
        $self->errorResponse ("User not permitted. " .
                              "  Username: '" .
                                    ($sync->username || '<anonymous>') .
                              "' Calendar: '" . $sync->calendar .
                              "' Operation: ResetFlags");
    }

    my $syncInfo = SyncInfo->new ($sync->calendar);
    $syncInfo->clearAll ? $self->successResponse : $self->errorResponse;
}

sub PurgeDeleted {
    shift->successResponse;
}


sub eventString {
    my ($date, $event, %args) = @_;
    return unless $event;       # in Sync file, but doesn't exist in DB

    my $modifiedFlag = $args{modified} || 0;
    my $deletedFlag  = $args{deleted} || 0;
    my $syncObj      = $args{syncObj};

    my @fields;
    push @fields, $event->id;
    push @fields, ($modifiedFlag || 0, $deletedFlag || 0);    # each is 0 or 1
    if (defined $event->startTime) {
        push @fields, 1;
        my ($start, $end) = ($event->startTime, $event->endTime);
        $end = $start unless $end; # TS, Palm require end time
        foreach my $time ($start, $end) {
            $time ||= 0;
            my ($hour, $minute) = (int ($time / 60), $time % 60);
            push @fields, ($hour, $minute);
        }
    } else {
        push @fields, (0,0,0,0,0);
    }

    my ($year, $month, $day) = split '/', $date;
    push @fields, ($year, $month, $day);

    my $text = escapeIt ($event->text) || ' ';
    $text = substr $text, 0, 255 if (length $text > 255); # max Palm size
    push @fields, $text;

    $text = escapeIt ($event->link || $event->popup);
    $text = '' unless defined $text;
    $text = substr $text, 0, 65535 if (length $text > 65536); # max Palm size
    push @fields, $text;

    if (!$event->isRepeating) {
        push @fields, (0,0,0,0,0,0,0,0);     # repeat info
    } else {
        my $rInfo = $event->repeatInfo;
        my $period    = $rInfo->period || '';
        my $frequency = $rInfo->frequency;
        my ($rmType, $rmRepeatOn);

        #                    Mon   Tue   Wed   Thu   Fri   Sat   Sun
        my @bitVals = (0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x01);

        if    (lc ($period) eq 'year')  {$rmType = 5;}
        elsif (lc ($period) eq 'month') {$rmType = 4;}
        elsif (lc ($period) eq 'week')  {$rmType = 2;}
        elsif (lc ($period) eq 'day')   {$rmType = 1;}
        elsif (lc ($period) eq 'daybanner') {$rmType = 1;}
        elsif (ref $period) { # repeating every e.g. M,W,F
            $rmType = 2;
            my @days = @$period;
            $rmRepeatOn = 0;
            foreach (@days) {   # 5.004 doesn't like trailing foreach()...
                $rmRepeatOn += $bitVals[$_];
            }
            $period = '';
        }

        # special case if daily repeat and skipping weekends
        if ($period =~ /day/i and $rInfo->skipWeekends) {
            $rmType = 2;
            $rmRepeatOn = 0;
            foreach (1..5) {
                $rmRepeatOn += $bitVals[$_];
            }
        }

        if (lc ($period) eq 'week') {
            $rmRepeatOn = $bitVals[$rInfo->startDate->dayOfWeek];
        }

        if ($rInfo->monthWeek) {
            $rmType = 3;
            my $day = $rInfo->monthDay % 7; # map to rm, sun==0
            $rmRepeatOn = ($rInfo->monthWeek->[0] - 1) * 7 + $day;
            $frequency = $rInfo->monthMonth;
        }

        push @fields, ($rmType, $frequency);

        if ($rInfo->endDate == Date->openFuture()) {
            push @fields, (0, 0, 0, 0);
        } else {
            my ($endY, $endM, $endD) = split '/', $rInfo->endDate;
            push @fields, (1, $endY, $endM, $endD);
        }

        push @fields, $rmRepeatOn || 0;

        my $exceptionList = $rInfo->exclusionList || [];
        push @fields, scalar @$exceptionList;

        foreach my $date (@$exceptionList) {
            push @fields, split ('/', $date);
        }
    }

    if ($syncObj->tsVersion > 1) {
        my $border = $event->drawBorder ? 1 : 0;

        push @fields, $event->fgColor || '';
        push @fields, $event->bgColor || '';
        push @fields, ($event->drawBorder ? 1 : 0);

        if ($syncObj->tsVersion == 2) {
            my $category = $event->primaryCategory;
            $category = '-' if (!defined $category);
            push @fields, $category;
        } else {
            my @categories = $event->getCategoryList;
            push @fields, scalar (@categories); # num cats
            foreach (@categories) {
                next unless defined;
                push @fields, $_;
            }
        }
    }
    return join ',', @fields;
}

# Adjust event for timezone, return new date as string
sub adjustEvent {
    my ($event, $date, $offset) = @_; # $date is Date obj, $offset is hours
    my $theDate = $date;
    if ($event->adjustForTimezone ($date, $offset)) {
        $theDate = $event->Date->stringify; # got changed by offset
        if ($event->isRepeating) {
            $event->repeatInfo->startDate ($event->Date);
        }
    }
    return $theDate;
}

# Escape commas and backslashes, and convert newlines to '\r','\n' sequences
# (i.e. '\r\n' is 4 characters, not two)
sub escapeIt {    # from CGI.pm 2.xx
    my $arg = shift;
    return unless defined $arg;
    $arg =~ s/([,\\])/\\$1/g;
    $arg =~ s{\n}{\\r\\n}g;
    return $arg;
}
# Same as above, and convert %xx to from hex to ascii char
sub unEscapeIt {
    my $arg = shift;
    return unless defined $arg;
    $arg =~ s/%([0-7a-f][\da-f])/chr hex $1/ige;
    $arg =~ s{\\r\\n}{\n}g;
    $arg =~ s/\\([,\\])/$1/g;
    return $arg;
}

sub errorResponse {
    my $self = shift;
    $self->_response (0, @_);
}
sub successResponse {
    my $self = shift;
    $self->_response (1, @_);
}
sub _response {
    my ($self, $code, @lines) = @_;

    if (defined $DEBUGFILE) {
        #warn "Response: $code\n", join ("\n", @lines), "\n";
        open (DEBUG, ">>$DEBUGFILE")
            || die "Can't open sync log file '$DEBUGFILE': $!\n";
        print DEBUG scalar (localtime), "\n";
        print DEBUG "Response: $code\n";
        print DEBUG join ("\n", @lines) . "\n" if (defined $lines[0]);
        print DEBUG "---- END ----\n\n";
        close DEBUG;
    }

    print $self->{_cgi}->header (-type => 'text/plain');
    print "$code\r\n";
    print join ("\r\n", @lines) if (defined $lines[0]);
    print "\r\n";
    exit (1);
}

# For debug logging
sub _dumpAllEvents {
    my ($db, $header) = @_;
    return unless defined $DEBUGFILE;

    open (DEBUG, ">>$DEBUGFILE")
        || die "Can't open sync log file '$DEBUGFILE': $!\n";

    print DEBUG scalar (localtime), "\n";
    print DEBUG $header if $header;

    my $regs = $db->getAllRegularEvents;
    my $reps = $db->getAllRepeatingEvents;

    my @eventList = @$reps;
    foreach my $date (keys %$regs) {
        foreach my $event (@{$regs->{$date}}) {
            $event->Date ($date);
            push @eventList, $event;
        }
    }

    my (%allEvents, @duplicates);

    foreach (@eventList) {
        if ($allEvents{$_->id}) {
            push @duplicates, $_;
            next;
        }
        $allEvents{$_->id} = $_;
    }

    if (@duplicates) {
        my $count = @duplicates;
        print DEBUG "  --> $count DUPLICATES! <--\n";
        foreach (@duplicates) {
            my $text = $_->text;
            $text =~ s/\n/\\n/g;
            printf DEBUG (" %4d %s\n", $_->id, $text);
        }
        print DEBUG "\n";
    }

    my $count = keys %allEvents;
    print DEBUG "Found $count Events\n";
    foreach my $id (sort {$a <=> $b} keys %allEvents) {
        my $event = $allEvents{$id};
        my $text = $event->text;
        $text =~ s/\n/\\n/g;
        printf DEBUG (" %4d %s %-10s %s\n", $event->id,
                                         $event->isRepeating ? 'R' : ' ',
                                         $event->isRepeating ?
                                              $event->repeatInfo->startDate
                                                             : $event->Date,
                                         $text);
    }

    print DEBUG "\n\n";
    close DEBUG;
}

###########################################################################
#
# SyncStuff
#
###########################################################################

package SyncStuff;

use strict;

sub new {
    my ($class, %args) = @_;
    return undef unless defined $args{MainCal};
    bless {MainCal      => $args{MainCal},     # the Main Calendar
           Username     => $args{Username},
           TSVersion    => $args{TSVersion},
           Timeout      => $args{Timeout},
           ActiveCal    => $args{ActiveCal} || $args{MainCal},
           Writeables   => [],
#           IncludedCals => [],
          }, $class;
}
sub calendar {
    $_[0]->{ActiveCal} || '[none]';
}
sub username {
    $_[0]->{Username} || '';
}
sub tsVersion {
    $_[0]->{TSVersion} || 1;
}
sub mainCalendar {
    $_[0]->{MainCal} || '';
}
sub timeout {
    $_[0]->{Timeout} || '';
}
sub error {
    $_[0]->{error} || '';
}
sub isIncluded {
    my ($self, $cal) = @_;
    $cal ||= $self->calendar;

    # Get list of all includes, if we haven't got it already
    if (!exists $self->{IncludedCals}) {
        my $prefs = Database->new ($self->mainCalendar)->getPreferences;
        my @includes = $prefs->getIncludedCalendarNames ('all');
        my @addIns   = $prefs->getIncludedAddInNames ('all');
        $self->{IncludedCals} = [@includes, @addIns];
    }

    foreach (@{$self->{IncludedCals}}) {
        return 1 if ($_ eq $cal);
    }
    return;
}

# keep track of which calendars we need to unlock or revert
sub setWriteableCalendars {
    my ($self, @calendars) = @_;
    $self->{Writeables} = \@calendars;
}

sub newFromID {
    my ($class, $sessionID) = @_;
    return undef unless defined $sessionID;
    my $idHash = $class->_getIDHash;
    return unless ($idHash and $idHash->{$sessionID});
    my ($username, $calendar, $activeCal, $timeout, $writeables, $tsVersion) =
                             _unserialize ($idHash->{$sessionID});

    my @writeables = split ',', $writeables;

    # Check and untaint calendar names; used in filenames
    foreach ($calendar, $activeCal, @writeables) {
        if (/^(\w+)$/) {
            $_ = $1;
        } else {
            $_ = undef;
        }
    }

    bless {MainCal    => $calendar,
           Username   => $username,
           ActiveCal  => $activeCal,
           Timeout    => $timeout,
           Writeables => \@writeables,
           TSVersion  => $tsVersion}, $class;
}

# Generate random ID, making sure it's not already in use.
sub createSessionID {
    my ($self) = @_;

    my $idHash = $self->_getIDHash;

    # If we're getting too big, delete anything that's over, say, 1 day
    # old.
    if (keys %$idHash > 100) {
        my $time = time - (60 * 60 * 24);
        foreach (sort {$a <=> $b} keys %$idHash) {
            last if $_ > $time;
            delete $idHash->{$_};
        }
    }

    my $id = time . '.' . int (rand 1234567);
    while (exists $idHash->{$id}) {
        $id .= int (rand 1234567);
    }

    $idHash->{$id} = $self->_serialize;
    $self->_setIDHash ($idHash);
    $id;
}
# Get rid of this session.
sub removeSessionID {
    my ($self, $id) = @_;
    my $idHash = $self->_getIDHash;
    delete $idHash->{$id};
    $self->_setIDHash ($idHash);
}

# Change the active calendar for this session
sub setActiveCalendar {
    my ($self, $sessionID, $newCalendar) = @_;

    # If already the Active cal, don't bother
    if ($self->calendar eq $newCalendar) {
        return 1;
    }

    my $idHash = $self->_getIDHash;

    $self->{ActiveCal} = $newCalendar;
    delete $self->{Database};
    $idHash->{$sessionID} = $self->_serialize;
    $self->_setIDHash ($idHash);
}

# Return Database object, which should be locked for sync (i.e. only this sync
#  operation can use it.)
# Always use the "active" calendar.
sub calendarDB {
    my ($self) = @_;
    if (!exists $self->{Database}) {
        # if included, it might be an AddIn. (Note that this is still a
        # problem if an included cal has same name as an AddIn!)
        my $db;
        if ($self->{ActiveCal} ne $self->mainCalendar) {
            my $mainDB = Database->new ($self->mainCalendar);

            my $prefs;
            eval {$prefs = $mainDB->getPreferences;};
            return undef if $@;
            my @addIns = $prefs->getIncludedAddInNames ('all'); # no 'ADDIN '
            foreach (@addIns) {
                if ($self->{ActiveCal} eq $_) {
                    $db = AddIn->new ($self->{ActiveCal}, $mainDB);
                    last;
                }
            }
        }
        $self->{Database} = $db || Database->new ($self->{ActiveCal});
        # Check existence...
        eval {$self->{Database}->getPreferences};
        return undef if $@;
    }
    $self->{Database}->isSyncing (1);
    return $self->{Database};
}

# Return Event and Date (as string) for specified ID
sub findEvent {
    my ($self, $id) = @_;
    $self->_buildEventDateMap if (!defined $self->{eventMap});
    my $event = $self->calendarDB->getEvent ($self->{eventMap}->{$id}, $id);
    ($event, $self->{eventMap}->{$id});
}

sub deleteEvent {
    my ($self, $id, $noSync) = @_;
    $self->_buildEventDateMap if (!defined $self->{eventMap});
    $self->calendarDB->deleteEvent ($self->{eventMap}->{$id}, $id,
                                    'all', $noSync);
}

# Calcium 3.6 needs id AND date to find an event. Very silly of it!
# So, we need to build the map if we don't have it yet
sub _buildEventDateMap {
    my ($self) = @_;
    my $regHash = $self->calendarDB->getAllRegularEvents;
    my $repList = $self->calendarDB->getAllRepeatingEvents;
    $self->{eventMap} = {};
    while (my ($date, $eventList) =  each %$regHash) {
        foreach (@$eventList) {
            $self->{eventMap}->{$_->id} = $date;
        }
    }
    foreach (@$repList) {
        $self->{eventMap}->{$_->id} = $_->repeatInfo->startDate;
    }
}

sub userPermitted {
    my ($self, $level) = @_;
    return Permissions->new ($self->calendarDB)->permitted ($self->{Username},
                                                            $level);
}

sub userTimezone {
    my ($self) = @_;
    return $self->{TimezoneOffset} if (defined $self->{TimezoneOffset});

    my $offset = 0;
    my $user;
    if ($self->username) {
        $user = User->getUser ($self->username); # get from DB
    }
    if ($user) {                # might not exist if using external Auth.
        $offset = $user->timezone;
    } else {
        # check for tz cookie, else get from cal defaults
        my $zoneOffset = CGI->new->cookie ('CalciumAnonOffset');
        if (!defined $zoneOffset) {
            my $prefs = Preferences->new ($self->mainCalendar);
            $offset = $prefs->DefaultTimezone;
        }
    }
    $self->{TimezoneOffset} = $offset;
    return $offset;
}


# Unlock, including all included calendars we had write permission for
sub unlockCalendars {
    my ($self) = @_;
    my $calendars = $self->{Writeables};
    my $ok = 1;
    $self->{error} ||= '';
    foreach my $name (@$calendars, $self->mainCalendar) {
        my $db = Database->new ($name);
        $ok &&= $db->lockForSync (undef);
        $self->{error} .= $db->error
          unless $ok;
    }
    return $ok;
}

# Revert, including all included calendars we had write permission for
sub revertCalendars {
    my ($self) = @_;
    my $calendars = $self->{Writeables};
    my $ok = 1;
    foreach my $name (@$calendars, $self->mainCalendar) {
        my $db = Database->new ($name);
        $ok &&= $db->revertForSync;
    }
    return $ok;
}


sub _serialize {
    my $self = shift;
    my $incCals = join ',', @{$self->{Writeables}};
    return join $;, ($self->username, $self->mainCalendar,
                     $self->calendar, $self->timeout, $incCals,
                     $self->tsVersion);
}
# uname, calName, activeCal, timeout, incCals, tsVersion
sub _unserialize {
    my $line = shift;
    return split $;, $line;
}

{
use Fcntl qw(:DEFAULT :flock);

# Retrun ref to hash; empty hash if error
sub _getIDHash {
    my ($selfOrClass) = @_;
    my $filename = Defines->baseDirectory . '/data/Master/SyncSessions';

    open (SESSIONS, $filename)
        or warn "Couldn't open '$filename': $!\n", return {};
    flock (SESSIONS, LOCK_SH)
        or warn "Couldn't lock '$filename': $!\n", return {};

    my %theHash;
    local $_;
    while (<SESSIONS>) {
        my ($id, $value) = split $;, $_, 2;
        chomp $value;
        $theHash{$id} = $value;
    }
    close SESSIONS;
    \%theHash;
}

sub _setIDHash {
    my ($selfOrClass, $theHash) = @_;
    my $filename = Defines->baseDirectory . '/data/Master/SyncSessions';
    sysopen (SESSIONS, $filename, O_RDWR|O_CREAT)
                 or die "Couldn't open Sync Session ID file '$filename'! $!\n";
    flock (SESSIONS, LOCK_EX) or die "Couldn't lock '$filename'! $!\n";
    seek (SESSIONS, 0, 0)     or die "Couldn't seek '$filename'! $!\n";
    truncate (SESSIONS, 0)    or die "Couldn't truncate '$filename'! $!\n";
    while (my ($id, $value) = each %$theHash) {
        print SESSIONS "$id$;$value\n";
    }
    close SESSIONS            or die "Couldn't close '$filename'! $!\n";
}

}
1;
