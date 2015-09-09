# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Database.pm - non-implementation specific database stuff.
#
# Each Database object contains a DBImplementation object to handle the
# implementation specific things. (current implementations include:
# DBM, DB_Serialize)

# Warning: finagling was patched on to avoid leaking memory (which matters for
#          mod_perl/Apache::Registry type systems.)

# new
# name, description
# openDatabase, closeDatabase
# createDatabase, deleteDatabase, renameDatabase
# version
# description
# _getBaseFilename
# _getFilename
# setPreferencesToDefault
# setPreferences, getPreferences
# insertEvent
# _insertRegularEvent, _insertRepeatingEvent
# getEvent, getEvents
# deleteEvent
# deleteEventsInRange
# getApplicableEvents
# getEventDateHash
# getEventLists
# setPermission, getPermission
# getPermittedUsers, setPermittedUsers
# removeFromIncludeLists
# findEventsMatching
# findRepeatingEventsMatching
# getAllRegularEvents, getAllRepeatingEvents
# renameCategory

package Database;

use strict;
use Calendar::Date;
use Calendar::Defines;
use Calendar::Permissions;
use Calendar::Preferences;
use Calendar::AddIn;
use Fcntl;

my %imps = (Serialize   => 'DB_Serialize',
            DBM         => 'DB_DBM');

# Pass in the name of the database, and an optional Implementation to use.
# If no implementation specified, we get it from the Defines.

{
    # Cache Database objects - if we've already got one w/same name & imp,
    # just return it.
    my %objCache;

sub new {
    my $class = shift;
    my ($dbName, $imp) = @_;

    $imp ||= Defines->databaseType;
    die "Don't know how to do a $imp database!" unless $imps{$imp};

    return $objCache{$dbName.$imp} if (defined $objCache{$dbName.$imp});

    eval "require Calendar::$imps{$imp}";
    die "Couldn't find Calendar::$imps{$imp}" if $@;

    my $okName;
    die "Bad Calendar or Database name! '$dbName' \n"
        unless ($dbName =~ /^(\w+)$/ and $okName = $1); # untaint and check

    my $self = {};
    bless $self, $class;

    $self->{'name'} = $okName;
    $self->{'Imp'} = $imps{$imp}->new ($self);

    my $selfRef = \$self;
    bless $selfRef, $class;     # so we can avoid memory leak

    $objCache{$dbName.$imp} = $selfRef;
    $selfRef;
}

sub clearCache {
    foreach my $ook (values %objCache) {
        $ook->closeDatabase (1);
    }
    %objCache = ();
}

sub END {
    foreach my $ook (values %objCache) {
        $ook->closeDatabase (1);
    }
}
}

sub DESTROY {
     my $self = shift;
     return unless ($self->isa ('REF')); # oh dear
     delete $$self->{Imp};       # all to patch leak from circular refs...oy
}

sub name {
    my $self = shift;
    $self = $$self if ($self->isa ('REF')); # oh dear (called from Imps)
    return $self->{'name'};
}

# Optionally pass version string to set it
sub version {
    my $self = shift;
    my $version = shift;
    $self = $$self if ($self->isa ('REF')); # oh my
    $self->{'Imp'}->setVersion ($version) if $version;
    $self->{'Imp'}->getVersion ();
}

sub description {
    my $self = shift;
    my $description = shift;

    if (defined $description) {
        $self->setPreferences ({Description => $description});
    } else {
        $description = $self->getPreferences ('Description') || '';
    }

    return $description;
}

# Pass readwrite flag
sub openDatabase {
    my $self = shift;
    $self = $$self if ($self->isa ('REF')); # oh dear

    my $readWrite = $_[0];
    if ($readWrite =~ /^(rw|rdwr|o_rdwr)$|write/i and
        !$self->isSyncing                         and
        $self->isLockedForSync) {
         require Calendar::GetHTML;
         GetHTML->errorPage (undef, # i18n
                             header    => 'Calendar `' . $self->name .
                                          "' is Locked",
                             message   => 'This Calendar is currently being ' .
                                          'Synchronized. Please try again ' .
                                          'in a few moments');
         warn "Error: Sync in progress on " . $self->name . "\n";
         die "\n";
     }

    $self->{'Imp'}->openDatabase (@_);
}

sub closeDatabase {
    my $self = shift;
    $self = $$self if ($self->isa ('REF')); # gosh
    $self->{'Imp'}->closeDatabase (@_);
}

# Delete a database altogether, i.e. remove it's data files or purge its DB
# tables
sub deleteDatabase {
    my $self = shift;
    $$self->{'Imp'}->deleteDatabase (@_);
}

sub renameDatabase {
    my ($self, $newName) = @_;
    return unless $newName =~ /^(\w+)$/;     # untaint and check it
    $newName = $1;
    $$self->{'Imp'}->renameDatabase ($newName);
    1;
}

# Pass an arg if you want to overwrite an existing db of the same name.
# This is used when a new Database object has been created but the database
# itself does not yet exist.
sub createDatabase {
    my $self = shift;
    $self = $$self if ($self->isa ('REF'));
    $self->{'Imp'}->createDatabase (@_);

    $self->version (Defines->version);

    # default permission is 'anybody can do anything' (!?)
    my $perm = Permissions->new ($self);
    $perm->setAnonymous ('Admin');
}

# Return full path of datafile name, sans extension, (DBImplementation adds
# it) Derived classes override this to put files in weird places. Unused
# for real database implementations.
sub _getBaseFilename {
    my $self = shift;
    $self = $$self if ($self->isa ('REF'));
    return Defines->baseDirectory . "/data/$self->{'name'}";
}

# Return full path of datafile name
sub _getFilename {
    my $self = shift;
    $self = $$self if ($self->isa ('REF'));
    $self->{'Imp'}->_getFilename;
}

sub setPreferencesToDefault {
    my $self = shift;
    my $db = shift;
    my $prefs = ($db && $db->isa ('Database')) ? Preferences->new ($db)
                                               : Preferences->new ();
    # Title defaults to calendar name
    $prefs->Title ($self->name);
    $self->setPreferences ($prefs);
}

# Set preferences, i.e. write to the database
# Pass a ref to a hash of key/value pairs, or a Preferences object
sub setPreferences {
    my $self = shift;
    $self = $$self if ($self->isa ('REF'));
    my ($argHash) = (@_);

    my $prefs;

    if (ref ($argHash) eq 'Preferences') {
        $prefs = $argHash;
    } else {
        $prefs = $self->{'Imp'}->getPreferences || Preferences->new;
        $prefs->setValues ($argHash);
    }
    $self->{'Imp'}->savePreferences ($prefs);
}

# If called w/no args, return the whole Prefs object.
# If called w/ 1 arg, return just the specified value.
sub getPreferences {
    my $self = shift;
    my $key = shift;

    my $prefs = $$self->{'Imp'}->getPreferences;

    return $prefs->{$key} if ($prefs && $key);
    return $prefs;
}

# Insert an event. It can be regular or repeating.
sub insertEvent {
    my $self = shift;
    my ($event, $date) = @_;

    $event->id ($$self->{'Imp'}->nextID);

    if ($event->isRepeating()) {
        $self->_insertRepeatingEvent ($event);
    } else {
        $self->_insertRegularEvent ($date, $event);
    }

    # keep track for syncing, maybe
    if ($self->getPreferences ('IsSyncable') and
        $self->getPreferences ('LastRMSyncID')) {
        require Calendar::SyncInfo;
        SyncInfo->new ($self->name)->eventAdded ($event->id);
    }
}

# Delete event w/the specified id, and re-insert the new version
sub replaceEvent {
    my ($self, $event, $date, $noDelete) = @_;
    return unless defined $event->id;
    if (!defined $noDelete) {
        $self->deleteEvent ($date, $event->id, 'all', 'noSyncEntry');
    }
    if ($event->isRepeating()) {
        $self->_insertRepeatingEvent ($event);
    } else {
        $self->_insertRegularEvent ($date, $event);
    }

    # deleteEvent removes reminders; let's add them back.
    if (Defines->mailEnabled and $event->reminderTimes) {
        require Calendar::Mail::MailReminder;
        MailReminder->add ($event, $self->name, $date);
    }

    if ($self->getPreferences ('IsSyncable') and
        $self->getPreferences ('LastRMSyncID')) {
        require Calendar::SyncInfo;
        SyncInfo->new ($self->name)->eventModified ($event->id);
    }
}

# Pass list of events, which are all expected to be the same type!
# Return ref to new list of event objects (w/id set.)
# (used for compiling AddIns, bulk loading, TripleSync)
sub insertEvents {
    my $self = shift;
    my ($eventList) = @_;
    return $self->insertEvent ($eventList) unless (ref $eventList eq 'ARRAY');
    return unless @$eventList;

    my $imp = $self->isa ('REF') ? $$self->{Imp} : $self->{Imp};

    my $numEvents = @$eventList;
    $numEvents /= 2 unless ($eventList->[0]->isRepeating());     # gross
    my $nextID = $imp->reserveNextIDs ($numEvents);

    my $newEvents;

    if ($eventList->[0]->isRepeating()) {
        $newEvents = $imp->insertRepeatingEvents ($eventList, $nextID);
    } else {
        $newEvents = $imp->insertRegularEvents ($eventList, $nextID);
    }
    return $newEvents;
}

# Stick an event on the list for a certain date
sub _insertRegularEvent {
    my $self = shift;
    $$self->{'Imp'}->insertRegularEvent (@_);
}

sub _insertRepeatingEvent {
    my $self = shift;
    $$self->{'Imp'}->insertRepeatingEvent (@_);
}

# Return an event, identified by date and id.
# Repeating events don't have dates, just ids.
# Return undef if event not found
sub getEvent {
    my $self = shift;
    my ($date, $eventID) = @_;
    my $ev = $$self->{'Imp'}->getEvent ($date, $eventID);
    $ev->Prefs ($self->getPreferences) if $ev;
    return $ev;
}

# Return event and date; pass in only ID (i.e. no date)
# Return StartDate for repeating events
# Return nada if not found.
sub getEventById {
    my ($self, $id) = @_;
    my $repeats = $self->getAllRepeatingEvents (noPrefs => 1);
    foreach (@$repeats) {
        if ($_->id == $id) {
            $_->Prefs ($self->getPreferences);
            return ($_, $_->repeatInfo->startDate);
        }
    }

    my $regHash = $self->getAllRegularEvents (noPrefs => 1);
    foreach my $date (keys %$regHash) {
        foreach my $event (@{$regHash->{$date}}) {
            if ($event->id == $id) {
                $event->Prefs ($self->getPreferences);
                return ($event, $date);
            }
        }
    }
    return;
}

# Return a ref to a hash of regular events in the specified date range, and
# a ref to an array of ALL repeating events. (Unless the date range is
# bad.) Don't use a large date range, as DB implementations are not very
# smart...
sub getEvents {
    my $self = shift;
    my ($fromDate, $toDate) = @_;
    return if ($fromDate > $toDate);
    my @ret;
    eval {
        @ret = $$self->{'Imp'}->getEvents ($fromDate, $toDate);
    };
    return @ret unless $@;
    warn "Problem with " . $self->name . ": $@";
    return ({}, [], 1);   # if DB error, return empty event lists and err flag
}

# Delete an event for a certain date. If the event isn't found for that
# date (or the date is undef), maybe it's a repeating event. The third
# param only applies for repeating events. And if there are mail reminders,
# delete them. Return deleted event text.
sub deleteEvent {
    my $self = shift;
    my ($date, $eventID, $allOrOne, $noSyncEntry) = @_;
    my $event = $self->getEvent ($date, $eventID);
    return undef unless $event;

    if (Defines->mailEnabled and $event and $event->reminderTimes) {
        my $justOne = ($allOrOne and ($allOrOne =~ /all/i ? undef : $date));
        require Calendar::Mail::MailReminder;
        MailReminder->deleteEventReminders ($eventID, $self->name, $justOne);
    }
    $$self->{'Imp'}->deleteEvent ($date, $eventID, $allOrOne);

    # keep track for syncing, maybe (not if we're doing a "replace", though)
    if (!$noSyncEntry and
        $self->getPreferences ('IsSyncable') and
        $self->getPreferences ('LastRMSyncID')) {
        require Calendar::SyncInfo;
        if ($allOrOne and $allOrOne !~ /all/i) {
            SyncInfo->new ($self->name)->eventModified ($eventID);
        } else {
            SyncInfo->new ($self->name)->eventDeleted ($eventID);
        }
    }

    return ($event && $event->text);
}

# Delete all events in a specified date range. Repeating events will be
# deleted if their start and end specs are within the specified range.
# Don't forget about the MailReminders, too.
# Return ref to list of deleted ids
sub deleteEventsInRange {
    my $self = shift;
    my %args = (from       => undef,
                to         => undef,
                categories => undef,
                @_);
    my $fromDate   = $args{from};
    my $toDate     = $args{to};
    my $categories = $args{categories};

    return if ($fromDate > $toDate);
    my $ids = $$self->{'Imp'}->deleteEventsInRange ($fromDate, $toDate,
                                                    $categories);
    if (Defines->mailEnabled) {
        require Calendar::Mail::MailReminder;
        MailReminder->deleteEventReminders ($ids, $self->name);
    }
    return $ids;
}

# Delete ALL events for the calendar. (Used for syncing.)
# Also resets last id.
sub deleteAllEvents {
    my $self = shift;
    $$self->{Imp}->deleteAllEvents;
    if (Defines->mailEnabled) {
        require Calendar::Mail::MailReminder;
        MailReminder->deleteAllForCalendar ($self->name);
    }
}

# Return a list of all (regular & repeating) events which apply for a
# certain date. Due to timezone offsets, we may need to check previous and
# next day too. Also, events which start yesterday and extend into today
# can be returned.
#
# $flags specifies whether to not adjust event times ("noadjust") for
# timezone, and whether to get "yesterday"s events as well.
#
# So: EVENTS ARE ADJUSTED for TIMEZONE unless 'noadjust' passed in flags
sub getApplicableEvents {
    my $self = shift;
    my ($date, $prefs, $flags) = @_;

    $flags ||= '';
    my $noAdjust  = $flags =~ /noadjust/;
    my $yesterday = $flags =~ /yesterday/;

    my ($startDate, $endDate);
    my $offset = $noAdjust ? 0 : $prefs->Timezone || 0;
    if ($offset < 0) {
        $startDate = $date;
        $endDate = $date + 1;
    } elsif ($offset > 0) {
        $startDate = $date - 1;
        $endDate = $date;
    } else {
        $startDate = $endDate = $date;
    }

    # Events might start yesterday and extend into today
    if ($yesterday) {
        $startDate--;
    }

    my $hash = $self->getEventDateHash ($startDate, $endDate, $prefs,
                                        $noAdjust);

    my @theEvents = @{$hash->{"$date"} || []};

    # for repeating events, make sure Date is right
    # set Date for events; important for repeating events
    if (!$noAdjust) {
        foreach (@theEvents) {
            next unless $_->isRepeating;
            $_->Date ($date);
        }
    }

    # add events that start yesterday, but extend into today. (Need for
    # TimePlan, DayPlanner views, as well as conflict checking.)
    if ($yesterday) {
        my $yesterday = $date - 1;
        foreach (@{$hash->{"$yesterday"} || []}) {
            next unless ($_->endTime and $_->endTime < $_->startTime);

            # save actual date it's on. If repeating, we need a copy! (In
            # case on both days.)
            my $copy = $_->copy;
            $copy->Date ($yesterday);
            push @theEvents, $copy;
        }
    }

    return @theEvents;
}

# Return a ref to a hash of lists of applicable events, keyed on dates.
# Pass in a from and to date, and prefs, and flag to not adjust for tz.
# We'll grab the single events from the Database, and ask each repeating
# event to fill the hash with its repeating fellows.
# Events included from other cals aren't included unless they should be.
# EVENTS ARE ADJUSTED for TIMEZONE unless 'noadjust' passed
sub getEventDateHash {
    my $self = shift;
    my ($fromDate, $toDate, $prefs, $noAdjust) = @_;

    my ($regs, $repeats) = $self->getEventLists ($prefs, $fromDate, $toDate);

    my $origTZ = $prefs->Timezone;
    $prefs->Timezone (0)        # TZ used to get skipweekends right in addto...
        if $noAdjust;

    foreach (@$repeats) {
        $_->addToDateHash ($regs, $fromDate, $toDate, $prefs);
    }

    $prefs->Timezone ($origTZ)
        if $noAdjust;

    return $regs if $noAdjust;

    my $offset = $prefs->Timezone;
    if (!$offset) {
        return $regs;
    }

    # Timezone Offset specified, adjust
    my %adjusted;
    while (my ($date, $list) = each %$regs) {
        foreach my $event (@$list) {
            my $dateObj = Date->new ($date);
            my $newDate;
            my $copy = $event->copy;
            # be careful, it may have already been adjusted
            if (defined $copy->TZoffset) {
                $newDate = $dateObj + $copy->TZoffset;
            } else {
                # we need to make a copy first, in case orig is cached
                $copy->adjustForTimezone ($dateObj, $offset);
                $newDate = $copy->Date;
            }
            $newDate = "$newDate";  # must stringify Date obj
            $adjusted{$newDate} ||= [];
            push @{$adjusted{$newDate}}, $copy;
        }
    }
    return \%adjusted;
}

# Return list of event instances, each with Date set
sub get_instances_in_range {
    my ($self, $from_date, $to_date, $prefs) = @_;
    my $hash = $self->getEventDateHash ($from_date, $to_date, $prefs);
    my @events;
    while (my ($date_string, $ev_list) = each %$hash) {
        my $date_obj = Date->new ($date_string);
        foreach my $event (@$ev_list) {
            my $copy = $event->copy;
            $copy->Date ($date_obj);
            push @events, $copy;
        }
    }
    return @events;
}


# Return a ref to a hash of lists of tentative events, keyed on dates.
# Repeating events are NOT EXPANDED; they're only added to the list for
# their start date. (But the start date is adjusted to be first date event
# actually occurs on.)
sub getTentativeEvents {
    my ($self) = @_;

    my $regHash = $self->getAllRegularEvents;
    my $repeats = $self->getAllRepeatingEvents;

    foreach my $date (keys %$regHash) {
        $regHash->{$date} = [grep {$_->isTentative} @{$regHash->{$date}}];
        delete $regHash->{$date} unless $regHash->{$date}->[0];
    }
    my $prefs;
    foreach (@$repeats) {
        next unless $_->isTentative;
        my $startDate = $_->repeatInfo->startDate;

        # need to find first date event actually occurs
        if (!$_->repeatInfo->applies ($startDate)) {
            $prefs ||= $self->getPreferences; # only get first time
            my $hash = $_->repeatInfo->nextNOccurrences ($_, 1, $startDate,
                                                         $prefs);
            my ($date) = keys %$hash;
            $startDate = $date || $startDate;
        }

        $startDate = "$startDate"; # in case it's a Date
        $regHash->{$startDate} ||= [];
        push @{$regHash->{$startDate}}, $_;
    }
    $regHash;
}

# Add tentative events from all included calendars user has 'Edit' perm in
# to existing eventHash ref
sub addIncludedTentativeEvents {
    my ($self, $userName, $eventHash) = @_;
    my $prefs = $self->getPreferences;
    my @includedNames = $prefs->getIncludedCalendarNames;
    foreach my $incName (@includedNames) {
        my $incDb = Database->new ($incName);
        next unless Permissions->new ($incDb)->permitted ($userName, 'Edit');
        my $thisHash = $incDb->getTentativeEvents;
        while (my ($date, $events) = each %$thisHash) {
            map {$_->includedFrom ($incName)} @$events;
            $eventHash->{$date} ||= [];
            push @{$eventHash->{$date}}, @$events;
        }
    }
}

# Return a hash of lists of regular events, keyed on date, and a list of
# repeating events. Pass 1 arg for a single day, or a from date and to date.
# Add-Ins are handled through the 'included calendar' stuff.
sub getEventLists {
    my $self = shift;
    my ($prefs, $fromDate, $toDate) = @_;

    $toDate = $fromDate unless $toDate;
    return (undef, undef) if ($fromDate > $toDate);

    my (%regularEvents, @repeatingEvents);

    # Get events from each calendar we include, including ourselves.
    my @includeNames = $prefs->getIncludedCalendarNames;
    my @dbList       = map {Database->new ($_)} @includeNames;
    unshift @dbList, $self;

    # Keep track of which categories to include for each included calendar
    my $incInfo = $prefs->getIncludedCalendarInfo;
    my %catLists;
    while (my ($calName, $incHash) = each %$incInfo) {
        $catLists{$calName} = $incHash->{Categories};
    }

    # And don't forget to stick the Add-Ins on there
    my @addInNames = $prefs->getIncludedAddInNames;
    push @dbList, map {AddIn->new ($_, $self)} @addInNames;

    foreach my $db (@dbList) {
        # First, regular (i.e. not repeating) events
        my ($eventHash, $repeaters, $error, $key, $value);
        ($eventHash, $repeaters, $error) = $db->getEvents ($fromDate, $toDate);
        # if problem w/AddIn or included calendar, un-include it
        if ($error) {
            if ($db->isa ('AddIn')) {
                $self->removeAddIns ($db->name);
            } else {
                $self->removeFromIncludeLists ($db->name);
            }
            next;
        }

        # See if "include" privacy applies for this one
        my $this_ones_prefs = Preferences->new ($db);
        my $inc_is_private = !$this_ones_prefs->PrivacyNoInclude;

        while (($key, $value) = (each %$eventHash)) {
            foreach (@$value) {
                next if ($inc_is_private && ($db != $self) && $_->private);

                if ($db != $self) {
                    my $dbname = $db->name;

                    # If we don't want this category, skip it
                    next unless _wantedCategory ($_, $dbname, \%catLists);

                    $dbname = "ADDIN $dbname" if (ref ($db) eq 'AddIn');
                    $_->includedFrom ($dbname);
                }

                # Have each event keep track of the preferences for its DB
                if (ref ($db) eq 'AddIn') {
                    $_->Prefs ($prefs);
                } else {
                    # hmm...does each event really need it's own new Pref obj?
                    $_->Prefs (Preferences->new ($db));
                }

                push @{$regularEvents{$key}}, $_;
            }
        }

        # Then repeating events
        foreach (@$repeaters) {
            # skip if private and it's included (and we're enforcing that)
            next if ($inc_is_private && ($db != $self) && $_->private);

            # skip it if completely outside date range
            next if ($_->repeatInfo->startDate > $toDate or
                     $_->repeatInfo->endDate   < $fromDate);

            if ($db != $self) {
                my $dbname = $db->name;
                next unless _wantedCategory ($_, $dbname, \%catLists);
                $dbname = "ADDIN $dbname" if (ref ($db) eq 'AddIn');
                # Keep track of where this event was included from
                $_->includedFrom ($dbname);
            }
            # Have each event keep track of the preferences for its DB
            if (ref ($db) eq 'AddIn') {
                $_->Prefs ($prefs);
            } else {
                $_->Prefs (Preferences->new ($db));
            }

            push @repeatingEvents, $_;
        }
    }

    sub _wantedCategory {
        my ($event, $dbname, $catLists) = @_;
        my $theseCats = $catLists->{$dbname};
        return 1 unless ($theseCats and @$theseCats);

        return 1 if $event->inCategory ($theseCats);

        my $noCats;
        foreach (@$theseCats) {
            if ($_ eq '<- - - ->') {
                $noCats = 1;
                last;
            }
        }
        return 1 if ($noCats and !$event->getCategoryList);
        return undef;
    }

    return (\%regularEvents, \@repeatingEvents);
}

# Pass username and permission level.
sub setPermission {
    my $self = shift;
    my ($userName, $permission) = @_;
    $self = $$self if ($self->isa ('REF'));
    $self->{'Imp'}->setPermission ($userName, $permission);
}

# Pass username; returns current permission level, or undef.
sub getPermission {
    my $self = shift;
    my ($userName) = @_;
    $$self->{'Imp'}->getPermission ($userName);
}

# Return hash of username->perms
sub getPermittedUsers {
    my $self = shift;
    $$self->{'Imp'}->getPermittedUsers;
}

# Set the hash of username->perms
sub setPermittedUsers {
    my $self = shift;
    my $hashRef = shift;
    $$self->{'Imp'}->setPermittedUsers ($hashRef);
}

# Return perm level or undef
sub getGroupPermission {
    my ($self, $groupID) = @_;
    $$self->{Imp}->getGroupPermission ($groupID);
}

sub setGroupPermission {
    my ($self, $groupID, $level) = @_;
    $$self->{Imp}->setGroupPermission ($groupID, $level);
}

sub _removeOrRenameInIncludeLists {
    my $classname = shift;
    my ($name1, $name2) = @_;   # if $name2 defined, we rename, else delete
    my @calendars = MasterDB->getAllCalendars;

    foreach (@calendars) {
        my $db = Database->new ($_);
        my $prefs = $db->getPreferences;
        my $includes = $prefs->{Includes};
        if ($includes && defined $includes->{$name1}) {
            $includes->{$name2} = $includes->{$name1} if ($name2);
            delete $includes->{$name1};
            $db->setPreferences ({Includes => $includes});
        }
    }
}

sub removeFromIncludeLists {
    my $classname = shift;
    my ($dbNameToDelete) = @_;
    $classname->_removeOrRenameInIncludeLists ($dbNameToDelete);
}

sub renameInIncludeLists {
    my $classname = shift;
    my ($oldName, $newName) = @_;
    $classname->_removeOrRenameInIncludeLists ($oldName, $newName);
}

sub removeAddIns {
    my ($self, @addInNames) = @_;
    my $includes = $self->getPreferences ('Includes');
    foreach (@addInNames) {
        delete $includes->{"ADDIN $_"};
    }
    $self->setPreferences ({Includes => $includes});
}

sub findEventsMatching {
    my $self = shift;
    my ($text, $fromDate, $toDate, $ignoreCase, $quoteRegex) = @_;
    my %returnHash;
    my $eventHash = $self->getAllRegularEvents;
    $text = quotemeta ($text) unless $quoteRegex;
    $text = "(?i)$text" if $ignoreCase;
    while (my ($date, $list) = each %$eventHash) {
        next unless (Date->new ($date))->inRange ($fromDate, $toDate);
        foreach my $event (@$list) {
            next unless $event->text =~ /$text/;
            $returnHash{$date} = [] unless $returnHash{$date};
            push @{$returnHash{$date}}, $event;
        }
    }
    \%returnHash;
}

sub findRepeatingEventsMatching {
    my $self = shift;
    my ($text, $fromDate, $toDate, $ignoreCase, $quoteRegex) = @_;
    my @returnList;
    my $eventList = $self->getAllRepeatingEvents;
    $text = quotemeta ($text) unless $quoteRegex;
    $text = "(?i)$text" if $ignoreCase;
    foreach my $event (@$eventList) {
        next unless $event->text =~ /$text/;
        next unless ($event->repeatInfo->startDate->inRange ($fromDate,
                                                             $toDate)   ||
                     $event->repeatInfo->endDate->inRange   ($fromDate,
                                                             $toDate));
        push @returnList, $event;
    }
    \@returnList;
}

sub getAllRegularEvents {
    my $self = shift;
    my %args = @_;
    my $hash = $$self->{'Imp'}->getAllRegularEvents (@_);
    unless ($args{noPrefs}) {    # keep prefs for each event...for Time Periods
        my $prefs = $self->getPreferences;
        foreach my $date (keys %$hash) {
            foreach my $event (@{$hash->{$date}}) {
                $event->Prefs ($prefs);
            }
        }
    }
    return $hash;
}

sub getAllRepeatingEvents {
    my $self = shift;
    my %args = @_;
    my $list = $$self->{'Imp'}->getAllRepeatingEvents (@_);
    unless ($args{noPrefs}) {    # keep prefs for each event...for Time Periods
        my $prefs = $self->getPreferences;
        foreach my $event (@$list) {
            $event->Prefs ($prefs);
        }
    }
    return $list;
}

# set/get file to log events to
sub auditingFile {
    my $self = shift;
    my $filename = shift;
    return $$self->{'Imp'}->getAuditFile unless $filename;
    $$self->{'Imp'}->setAuditFile ($filename);
}
# set/get list of email addresses to log events to
sub auditingEmail {
    my $self = shift;
    my (@emails) = @_;
    unless (@emails) {
        my $string = $$self->{'Imp'}->getAuditEmailAddresses || '';
        return (wantarray ? split /\s/, $string : $string);
    }
    my $emailString = join ' ', @emails;
    $$self->{'Imp'}->setAuditEmailAddresses ($emailString);
}

# Pass op and list of Auditing types ('file', 'email')
sub setAuditing {
    my $self = shift;
    my ($opName, @auditList) = @_;
    my $auditString = join ' ', @auditList;
    $$self->{'Imp'}->setAuditing ($opName, $auditString);
}

# Pass op type or name; returns list of Auditing types (current types:
# 'file' 'email')
sub getAuditing {
    my $self = shift;
    my ($opName) = @_;
    my $auditString = $$self->{'Imp'}->getAuditing ($opName) || '';
    split /\s/, $auditString;
}

# Ug. In addition to modifying prefs, have to find and modify all events in
# this category.
# "Flags" arg controls what to do. If:
#     undef     change in preferences and events
#     /prefs/   change prefs
#     /events/  change events
sub renameCategory {
    my ($self, $oldName, $newName, $flags) = @_;
    return unless ($oldName and $newName);

    if (!$flags or ($flags =~ /prefs/)) {
        my $prefs = $self->getPreferences;
        my $newCat = $prefs->category ($oldName);
        return unless $newCat;
        $newCat->name ($newName);
        $prefs->category ($newName, $newCat);
        $prefs->deleteCategory ($oldName);
        $self->setPreferences ($prefs);
    }

    return if ($flags and ($flags !~ /events/));

    my $regHash = $self->getAllRegularEvents;
    my $repeats = $self->getAllRepeatingEvents;

    foreach my $date (keys %$regHash) {
        foreach my $event (@{$regHash->{$date}}) {
            if (_renameCatInEvent ($event, $oldName, $newName)) {
                $self->replaceEvent ($event, $date);
            }
        }
    }
    foreach my $event (@$repeats) {
        if (_renameCatInEvent ($event, $oldName, $newName)) {
            $self->replaceEvent ($event);
        }
    }
    return;

    sub _renameCatInEvent {
        my ($event, $oldName, $newName) = @_;
        return unless $event->inCategory ($oldName);
        my @evCats = $event->getCategoryList;
        my $saveIt;
        foreach my $thisCat (@evCats) {
            if ($thisCat eq $oldName) {
                $thisCat = $newName;
                $saveIt = 1;
                last;
            }
        }
        return unless $saveIt;
        $event->setCategoryList (@evCats);
        return 1;
    }
}

sub isSyncing {
    my $self = shift;
    $self = $$self if ($self->isa ('REF')); # urg
    $self->{isSyncing} = shift if (@_);
    $self->{isSyncing};
}
sub isLockedForSync {
    my ($self) = @_;
    return undef if $self->isa ('MasterDB'); # Master can't be synced.
    return undef unless -d $self->syncLockDirName;

    # lock dir exists, see if expired
    my $expireTime = $self->_getLockExpiration;
    return 1 if ($expireTime > time); # lock still good

    # lock expired; remove lock dir and file, return undef - we're not locked
    $self->lockForSync;
    return undef;
}
sub syncLockDirName {
    my ($self) = @_;
    return $self->_getBaseFilename . '.SyncLock';
}
sub syncLockExpiryFileName {
    my ($self) = @_;
    my $expireFile = $self->syncLockDirName . "/expireTime";
}
sub _getLockExpiration {
    my ($self) = @_;
    my $lockDir = 
    my $expireFile = $self->syncLockExpiryFileName;
    open (TIMEOUT, "< $expireFile") or return -1;
    my $expiry = <TIMEOUT>;
    return $expiry + 0;
}

# Pass number of seconds to lock for; undef to unlock.
# Return undef if lock or unlock fails
sub lockForSync {
    my ($self, $lockTime) = @_;

    # For now, just create or test for existence of a lockfile.
    my $lockDir = $self->syncLockDirName;
    my $expireFile = $self->syncLockExpiryFileName;

    # if locking, create dir and file containing expire time
    if (defined $lockTime) {

        return undef if $self->isLockedForSync;

        mkdir ($lockDir, 0777) or return undef;
        sysopen (TIMEOUT, $expireFile, O_WRONLY|O_CREAT|O_EXCL)
            or return undef;
        my $expiry = time + $lockTime;
        print TIMEOUT "$expiry\n";
        close TIMEOUT or return undef;
        return 1;
    } else {                    # otherwise, unlock; remove file and dir
        $self = $$self if ($self->isa ('REF')); # urg
        $self->{_error} = '';
        my $unlink_count = unlink $expireFile;
        unless ($unlink_count) {
            $self->{_error} .= "Removing file '$expireFile' failed: $!\n";
        }
        my $rmdir_ok = rmdir ($lockDir);
        unless ($rmdir_ok) {
            $self->{_error} .= "Removing sync lock dir '$lockDir' failed: $!\n";
        }
        return $unlink_count && $rmdir_ok;
    }
}

# Make copy of event data which we can revert to if necessary.
# Return 1 on success, 0 on failure.
sub backupForSync {
    my ($self) = @_;
    require Calendar::SyncInfo;
    SyncInfo->new ($self->name)->backupForSync;
    $$self->{'Imp'}->backupForSync;
}

# Return 1 on success, 0 on failure.
sub revertForSync {
    my ($self) = @_;
    SyncInfo->new ($self->name)->revertForSync;
    $$self->{'Imp'}->revertForSync;
}

sub error {
    my $self = shift;
    return $$self->{_error};
}

1;
