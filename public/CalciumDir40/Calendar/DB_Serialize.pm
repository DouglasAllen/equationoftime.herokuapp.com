# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# DB_Serialize.pm - Use simple object serialization to write/read flat datafile
#
# Inherits from abstract class DBImplementation

# We keep the Preferences and Events in two separate files. We use
# $self->{WhichFile} to keep track of which is currently open.

# On openDatabase(), we fill a hash in $self->{Data} with these keys:
#   $self->{Data}->{LastID}
#   $self->{Data}->{Events}->{"$date"}    list of regular events on this date
#   $self->{Data}->{Repeating}  list of repeating events

# For Preferences file:
#   $self->{Data}->{Version}     => DB version id
#   $self->{Data}->{Permissions} => Permissions Hash
#   $self->{Data}->{GroupPermissions} => Permissions Hash
#   $self->{Data}->{Preferences} => Preferences Object
#   $self->{Data}->{Auditing}    => serialized hash of op => string
#   $self->{Data}->{AuditFile}   => Full path to log file
#   $self->{Data}->{AuditEmails} => List of email addresses
#
# Only in MasterDB Prefs:
#   $self->{Data}->{Users}      => hash, username => serialized User object
#   $self->{Data}->{UserGroups} => hash; group id => serialized UserGroup objs
#
# And then write it out on closeDatabase (if necessary)

package DB_Serialize;

use strict;
use Fcntl qw(:DEFAULT :flock);
use File::Basename;
use File::Copy;

use Calendar::DBImplementation;
use Calendar::Date;

use vars ('@ISA');
@ISA = ('DBImplementation');

# Return extension to use on database filename
sub _getFilenameExtension {
    my $self = shift;
    my $ext = $self->{WhichFile} || 'Events';
    return ".$ext";
}

# Called from Database object. Pass arg if you want to overwrite an
# existing db of the same name.
sub createDatabase {
    my $self = shift;
    my ($overwrite) = @_;

    foreach (qw (Preferences Events)) {
        $self->{WhichFile} = $_;
        my $filename = $self->_getFilename;

        # First, check for existence, and act appropriately
        if (-e $filename) {
            if ($overwrite) {
                unlink $filename;
            } else {
                die "$filename already exists, quitting.\n";
            }
        }

        sysopen (DBFH, $filename, O_CREAT|O_RDWR, 0644) ||
            die "Can't create data file " . $filename . ": $!\n";

        close DBFH;
    }
    delete $self->{WhichFile};
}

sub deleteDatabase {
    my $self = shift;
    foreach (qw (Preferences Events)) {
        $self->{WhichFile} = $_;
        my $filename = $self->_getFilename;
        unlink $filename or die "Couldn't remove " . $filename . ": $!\n";
    }
    delete $self->{WhichFile};
}

sub renameDatabase {
    my $self = shift;
    my $newName = shift;
    my $oldName = $self->{db}->name;
    foreach (qw (Preferences Events)) {
        $self->{WhichFile} = $_;
        my $ext = $self->_getFilenameExtension;
        my ($oldFilename, $newFilename);
        $oldFilename = $self->_getFilename;
        ($newFilename = $oldFilename) =~ s/$oldName$ext/$newName$ext/;
        rename ($oldFilename, $newFilename) ||
            die "Couldn't rename $oldFilename to $newFilename: $!\n";
    }
}


{
    # Cache - just store flag if we've already parsed file
    my %DBCache;

# Read everything in from the db, parse into our hash
sub openDatabase {
    my $self = shift;
    my ($readWrite, $whichFile) = @_;

    my ($status, $lock, $goingToWrite);

    $self->{WhichFile} = $whichFile || 'Events';

    if ($readWrite =~ /^(rw|rdwr|o_rdwr)$|write/i) {
        $goingToWrite = 1;
        $status = O_CREAT|O_RDWR;
        $lock   = LOCK_EX;
        $self->{WriteMe}{$whichFile} = 1;
        my $fname = $self->_getFilename;
        copy ($fname, $fname . 'backup');
    } else {
        $status = O_RDONLY;
        $lock   = LOCK_SH;
    }

    # We're now caching...
    my $cacheID = $self->{db}->name . $self->{WhichFile};

    my $dontBotherReading;

    my $isCached = exists $DBCache{$cacheID};

    # If mod_perl, we need to check the timestamp
    if ($isCached and exists $ENV{MOD_PERL}) {
        my $mtime = (stat $self->_getFilename)[9];
        $isCached = ($mtime <= $DBCache{$cacheID});
    }

    if ($isCached) {
        return unless $goingToWrite;
        $dontBotherReading = 1; # OK, we're just going to open and lock
    }

    my @lines;

    {local *DBFH;
     my $ok = sysopen (DBFH, $self->_getFilename, $status, 0644);
     if (!$ok) {
         my $message;
         if ($self->dbExists) {
             $message = "Can't open " . $self->_getFilename . ": $!\n";
         } else {
             $message = "Calendar does not exist: " . $self->{db}->name;
         }
#          if ($ENV{HTTP_HOST}         ||
#              $ENV{GATEWAY_INTERFACE} ||
#              $ENV{USER_AGENT}        ||
#              $ENV{REQUEST_METHOD}) {
#              require Calendar::GetHTML;
#              GetHTML->errorPage (undef, # i18n
#                                  header    => 'Database error',
#                                  message   => $message,
#                                  backCount => 0);
#          } else {
             warn "$message\n";
#          }
         $self->{WriteMe}{$whichFile} = undef; # don't try writing in close
         die "$message\n";
     }

    # OK, we opened it; now lock that puppy
    unless (flock (DBFH, $lock | LOCK_NB)) {
        warn ('DB Locked; waiting to ' . (($lock == LOCK_EX) ? "write.\n"
                                                             : "read.\n"));
        unless (flock (DBFH, $lock)) { die "couldn't lock database! $!\n" }
    }

    if ($goingToWrite) {
        $self->{filehandle}{$whichFile} = *DBFH;
    }

    return 1 if $dontBotherReading; # we just changed file status

    # And slurp everything in
    @lines = <DBFH>;
    chomp (@lines);
    }

    unless ($goingToWrite) {
        $DBCache{$cacheID} = (stat $self->_getFilename)[9]
            if (exists $ENV{MOD_PERL});
        close DBFH;
    }


    # Parse prefs
    if ($self->{WhichFile} eq 'Preferences') {
        my ($line);
        my %prefs;
        while ($line = shift @lines) {
            my ($key, $values) = split $;, $line, 2;
            if ($key eq 'Preferences') {
                $self->{'Data'}->{'Preferences'} =
                                       Preferences->unserialize ($values);
            } elsif ($key eq 'Version') {
                $self->{'Data'}->{'Version'} = $values;
            } elsif ($key eq 'Permissions') {
                my %perms = split $;, $values;
                $self->{'Data'}->{'Permissions'} = \%perms;
            } elsif ($key eq 'GroupPermissions') {
                my %perms = split $;, $values;
                $self->{'Data'}->{'GroupPermissions'} = \%perms;
            } elsif ($key =~ /^Audit/) { # Auditing, AuditFile, AuditEmails
                $self->{'Data'}->{$key} = $values;
            } elsif ($key eq 'Users' or $key eq 'UserGroups') {
                my @ulist = split "\035", $values; # oy
                my %uhash;
                foreach (@ulist) {
                    my ($id, $vals) = split $;, $_, 2;
                    $uhash{$id} = $vals;
                }
                $self->{Data}->{$key} = \%uhash;
            }
        }
        $self->{'Data'}->{'Preferences'} ||= Preferences->new;
    } elsif ($self->{WhichFile} eq 'Events') {
        $self->{Data}->{Repeating} = [];
        $self->{Data}->{Events} = {};
        my ($line, $key, @values);
        while ($line = shift @lines) {
            ($key, @values) = split $;, $line;
            if ($key eq 'LastID') {
                $self->{Data}->{LastID} = $values[0];
                next;
            }
            if ($key eq 'Repeat') {
                push @{$self->{Data}->{Repeating}},
                                            Event->unserialize (@values);
                next;
            }
            $self->{Data}->{Events}->{$key} ||= [];
            push @{$self->{Data}->{Events}->{$key}},
                                            Event->unserialize (@values);
        }
    }

    if (!exists $ENV{MOD_PERL}) {
        $DBCache{$cacheID}++;       # yes, we cached it
    }

    return 1;
}


sub closeDatabase {
    my ($self, $force) = @_;

    if ($self->{WriteMe}{Preferences}) {
        my (@lines, $line);
        my $prefs = $self->{'Data'}->{'Preferences'};
        $line = "Preferences$;" . $prefs->serialize;
        push @lines, $line;

        $line = "Version$;" . $self->{'Data'}->{'Version'};
        push @lines, $line;

        $line = "Permissions$;" .
            join $;, (%{$self->{'Data'}->{'Permissions'} || {}});
        push @lines, $line;

        $line = "GroupPermissions$;" .
            join $;, (%{$self->{Data}->{GroupPermissions} || {}});
        push @lines, $line;

        foreach (qw (Auditing AuditFile AuditEmails)) {
            next unless $self->{Data}->{$_};
            $line = "$_$;$self->{Data}->{$_}";
            push @lines, $line;
        }

        foreach (qw (Users UserGroups)) {
            my $uhash = $self->{Data}->{$_} || {};
            my @eachu;
            while (my ($id, $vals) = each %$uhash) {
                push @eachu, "$id$;$vals";
            }
            if (@eachu) {
                $line = "$_$;" . join "\035", @eachu;
                push @lines, $line;
            }
        }

        $self->_writeFile ('Preferences', \@lines);
    }
    if ($self->{WriteMe}{Events}) {
        my (@lines, $line);
        my $lastID = $self->{Data}->{LastID} || 1;
        push @lines, "LastID$;$lastID";
        foreach my $event (@{$self->{Data}->{Repeating}}) {
            push @lines, join $;, ('Repeat', $event->serialize);
        }
        foreach my $date (keys %{$self->{Data}->{Events}}) {
            foreach my $event (@{$self->{Data}->{Events}->{"$date"}}) {
                push @lines, join $;, ("$date", $event->serialize);
            }
        }
        $self->_writeFile ('Events', \@lines);
    }
    if ($force) {
        foreach (qw (Preferences Events)) {
            my $cacheID = $self->{db}->name . $_;
            delete $DBCache{$cacheID};
        }
    }
}
sub _writeFile {
    my $self = shift;
    my ($which, $lines) = @_;
    delete $self->{WriteMe}{$which};
    local *HANDLE = $self->{filehandle}{$which};
    seek (HANDLE, 0, 0);
    print HANDLE join "\n", @$lines;
    print HANDLE "\n";
    truncate (HANDLE, tell (HANDLE));
    close HANDLE;
    delete $self->{filehandle}{$which};

    my $cacheID = $self->{db}->name . $self->{WhichFile};
    delete $DBCache{$cacheID};
}
}


sub getVersion {
    my $self = shift;
    $self->{db}->openDatabase ('read', 'Preferences');
    my $version = $self->{Data}->{'Version'};
    $self->{db}->closeDatabase;
    $version;
}

sub setVersion {
    my $self = shift;
    my $version = shift;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{Data}->{'Version'} = $version;
    $self->{db}->closeDatabase;
    $version;
}

sub nextID {
    my $self = shift;
    $self->{db}->openDatabase ('readwrite', 'Events');
    $self->{Data}->{'LastID'} ||= 1;
    my $id = $self->{Data}->{'LastID'};
    $self->{Data}->{'LastID'}++;
    $self->{db}->closeDatabase;
    $id;
}

sub reserveNextIDs {
    my $self   = shift;
    my $numIDs = shift;
    $self->{db}->openDatabase ('readwrite', 'Events');
    $self->{Data}->{'LastID'} ||= 1;
    my $id = $self->{Data}->{'LastID'};
    $self->{Data}->{'LastID'} += $numIDs;
    $self->{db}->closeDatabase;
    $id;
}

sub getPreferences {
    my $self = shift;

    # open the db
    $self->{db}->openDatabase ('readonly', 'Preferences');

    my $prefs = $self->{'Data'}->{'Preferences'};

    $self->{db}->closeDatabase;

    return $prefs;              # a Preferences Object
}

sub savePreferences {
    my $self = shift;
    my $prefs = shift;

    $self->{db}->openDatabase ('readwrite', 'Preferences');

    $self->{Data}->{Preferences} = $prefs;

    $self->{db}->closeDatabase;

    return $prefs;
}

sub insertRegularEvent {
    my $self = shift;
    my ($date, $event) = @_;

    $self->{db}->openDatabase ('readwrite', 'Events');

    $self->{'Data'}->{'Events'}->{"$date"} ||= [];
    push @{$self->{'Data'}->{'Events'}->{"$date"}}, $event;

    $self->{db}->closeDatabase;
}

# Take one event, or a list of em
# (really only need the list so creating large AddIn files is tolerable)
sub insertRepeatingEvent {
    my $self = shift;
    my ($event) = @_;
    $self->{db}->openDatabase ('readwrite', 'Events');
    my $listRef = $self->{'Data'}->{'Repeating'} || [];
    push @$listRef, $event;     # who cares where in the list it is?
    $self->{db}->closeDatabase;
}

# Stick a whole list of events in the db
# List looks like (event, date, event, date, ...)
# Return list of new events (w/IDs set)
sub insertRegularEvents {
    my $self = shift;
    my ($eventList, $nextID) = @_;

    $self->{db}->openDatabase ('readwrite', 'Events');

    my @newEvents;

    while (@$eventList) {
        my $event = shift @$eventList;
        my $date  = shift @$eventList;
        $event->id ($nextID++);
        $self->{'Data'}->{'Events'}->{"$date"} ||= [];
        push @{$self->{'Data'}->{'Events'}->{"$date"}}, $event;
        push @newEvents, $event;
    }

    $self->{db}->closeDatabase;

    return \@newEvents;
}

# Stick a whole list of repeating events in the db
# Return list of new events (w/IDs set)
sub insertRepeatingEvents {
    my $self = shift;
    my ($eventList, $nextID) = @_;
    $self->{db}->openDatabase ('readwrite', 'Events');
    my $listRef = $self->{'Data'}->{'Repeating'} || [];

    my @newEvents;

    foreach my $event (@$eventList) {
        $event->id ($nextID++);
        push @$listRef, $event;
        push @newEvents, $event;
    }
    $self->{db}->closeDatabase;
    return \@newEvents;
}

# Return an event from a list for a certain date. Works for regular or
# repeating events.
sub getEvent {
    my $self = shift;
    my ($date, $eventID) = @_;

    $self->{db}->openDatabase ('readonly', 'Events');

    my $listRef = $date ? $self->{'Data'}->{'Events'}->{"$date"} || []
                        : [];

    my ($i, $event);

    for ($i=0; $i<@$listRef; $i++) {
        last if ($listRef->[$i]->id() == $eventID);
    }

    # If no list or not in list, it must be a repeater.
    if ($i < @$listRef) {
            $event = $listRef->[$i];
    } else {
        $listRef = $self->{'Data'}->{'Repeating'} || [];
        for ($i=0; $i<@$listRef; $i++) {
            last if ($listRef->[$i]->id() == $eventID);
        }
        if ($i <@$listRef) {
            $event = $listRef->[$i];
        }
    }

    $self->{db}->closeDatabase;

    $event;
}

# Return a ref to a hash of regular events in the specified date range, and
# a ref to an array of ALL repeating events. Date range has already been
# checked.
# If date range is large, get all events, throw away those outside range.
# Otherwise, check each date in range for events.
sub getEvents {
    my $self = shift;
    my ($fromDate, $toDate) = (@_);

    $self->{db}->openDatabase ('readonly', 'Events');

    my (%returnHash, $listRef);

    if ($fromDate == Date->openPast and $toDate == Date->openFuture) {
        %returnHash = %{$self->{'Data'}->{'Events'}};
    }
    elsif ($fromDate->deltaDays ($toDate) < 100) { # 100; arbitrary size
        # Get the regular events for the dates in the range
        while ($fromDate <= $toDate) {
            $listRef = $self->{'Data'}->{'Events'}->{"$fromDate"};
            $returnHash{"$fromDate"} = $listRef if $listRef;
            $fromDate++;
        }
    } else {
        # Get all regular events, throw out those outside range
        my $evHash = $self->getAllRegularEvents;
        foreach my $date (keys %$evHash) {
            my $dateObj = Date->new ($date);
            next if ($dateObj < $fromDate or $dateObj > $toDate);
            $listRef = $self->{'Data'}->{'Events'}->{$date};
            $returnHash{$date} = $listRef if $listRef;
        }
    }

    my $repeating = $self->{'Data'}->{'Repeating'} || [];

    $self->{db}->closeDatabase;

    return (\%returnHash, $repeating);
}

# Delete an event on the list for a certain date.
sub deleteEvent {
    my $self = shift;
    my ($date, $eventID, $allOrOne) = @_;

    $self->{db}->openDatabase ('readwrite', 'Events');

    my $listRef = $date ? $self->{'Data'}->{'Events'}->{"$date"} || []
                        : [];

    my $i;

    for ($i=0; $i<@$listRef; $i++) {
        last if ($listRef->[$i]->id() == $eventID);
    }

    # If we found it, delete it
    if ($i < @$listRef) {
        splice @$listRef, $i, 1;
        $self->{'Data'}->{'Events'}->{"$date"} = $listRef;
    } # otherwise, check the repeating events
    else {
        $listRef = $self->{'Data'}->{'Repeating'} || [];
        for ($i=0; $i<@$listRef; $i++) {
            last if ($listRef->[$i]->id() == $eventID);
        }
        if ($i <@$listRef) {
            # Delete all, or mark single instance as an exclusion
            if ($allOrOne =~ /all/i) {
                splice @$listRef, $i, 1;
            } else {
                $listRef->[$i]->excludeThisInstance ($date);
            }
            $self->{'Data'}->{'Repeating'} = $listRef;
        }
    }

    $self->{db}->closeDatabase;
}

# Delete all events in a specified date range. Repeating events will be
# deleted if their start and end specs are within the specified range.
# If categories specified, only delete event if in one of those cats.
sub deleteEventsInRange {
    my $self = shift;
    my ($fromDate, $toDate, $categories) = @_;
    my $doCats = $categories && @$categories;

    $self->{db}->openDatabase ('readwrite', 'Events');

    my @deletedIDs;

    # Much faster to iterate through events, not date range, for large ranges.
    foreach (keys %{$self->{'Data'}->{'Events'}}) {
        if (Date->new ($_)->inRange ($fromDate, $toDate)) {
            # need to save ids to return for deleting MailReminders.
            my $listRef = $self->{'Data'}->{'Events'}->{$_};
            my @notDeleted;
            foreach my $event (@$listRef) {
                if ($doCats and !$event->inCategory ($categories)) {
                    push @notDeleted, $event;
                } else {
                    push @deletedIDs, $event->id;
                }
            }
            if (@notDeleted) {
                $self->{'Data'}->{'Events'}->{"$_"} = \@notDeleted;
            } else {
                delete $self->{'Data'}->{'Events'}->{"$_"};
            }
        }
    }

    # And now do repeating events. We don't take advantage of the fact that
    # the list is ordered on start date, since this code is clearer. A bit
    # slower, mind you, but this isn't an operation that will be done often.
    my @newList;
    my $repeating = $self->{'Data'}->{'Repeating'} || [];
    foreach (@$repeating) {
        if ($_->repeatInfo->startDate->inRange ($fromDate, $toDate) &&
            $_->repeatInfo->endDate->inRange   ($fromDate, $toDate) &&
            (!$doCats or $_->inCategory ($categories))) {
            push @deletedIDs, $_->id;
        } else {
            push @newList, $_;
        }
    }

    $self->{'Data'}->{'Repeating'} = \@newList;

    $self->{db}->closeDatabase;
    \@deletedIDs;
}

sub deleteAllEvents {
    my $self = shift;
    $self->{db}->openDatabase ('readwrite', 'Events');
    $self->{Data}->{Events}    = {};
    $self->{Data}->{Repeating} = [];
    delete $self->{Data}->{LastID};
    $self->{db}->closeDatabase;
}


#
# Permissions
#

# Pass username and permission level.
#     (currently expect 'None', 'View', 'Add', 'Edit', 'Admin')
sub setPermission {
    my $self = shift;
    my ($userName, $permission) = @_;

    $self->{db}->openDatabase ('readwrite', 'Preferences');

    my $perms = $self->{'Data'}->{'Permissions'} || {};

    if ($permission =~ /Remove/i) {
        delete $perms->{$userName};
    } else {
        $perms->{$userName} = $permission;
    }

    $self->{'Data'}->{'Permissions'} = $perms;

    $self->{db}->closeDatabase;
}

# Pass username; return perm level for that user, or undef if not specified.
sub getPermission {
    my $self = shift;
    my ($userName) = @_;

    my $perms = $self->getPermittedUsers;
    return ($perms->{$userName});
}

sub getPermittedUsers {
    my $self = shift;
    $self->{db}->openDatabase ('read', 'Preferences');
    my $perms = $self->{'Data'}->{'Permissions'} || {};
    my (%returnHash);
    while (my ($name, $perm) = each %$perms) {
            $returnHash{$name} = $perm;
    }
    $self->{db}->closeDatabase;
    return (\%returnHash);
}

sub setPermittedUsers {
    my $self = shift;
    my $hashRef = shift;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{'Data'}->{'Permissions'} = $hashRef;
    $self->{db}->closeDatabase;
}

sub getGroupPermission {
    my ($self, $groupID) = @_;
    return $self->getGroupPermissionHash->{$groupID};
}
sub setGroupPermission {
    my ($self, $groupID, $level) = @_;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{Data}->{GroupPermissions} ||= {};
    if ($level =~ /remove/i) {
        delete $self->{Data}->{GroupPermissions}->{$groupID};
    } else {
        $self->{Data}->{GroupPermissions}->{$groupID} = $level;
    }
    $self->{db}->closeDatabase;
}
sub getGroupPermissionHash {
    my $self = shift;
    $self->{db}->openDatabase ('read', 'Preferences');
    my $perms = $self->{Data}->{GroupPermissions} || {};
    my %returnHash = %$perms;
    $self->{db}->closeDatabase;
    return (\%returnHash);
}

sub getAllRegularEvents {
    my $self = shift;
    my %returnHash;
    $self->{db}->openDatabase ('readonly', 'Events');

    while (my ($date, $eventList) = each %{$self->{Data}->{Events}}) {
        $returnHash{$date} = $eventList if $eventList;
    }

    $self->{db}->closeDatabase;
    \%returnHash;
}

sub getAllRepeatingEvents {
    my $self = shift;
    $self->{db}->openDatabase ('readonly', 'Events');
    my $repeaters = $self->{Data}->{Repeating} || [];
    $self->{db}->closeDatabase;
    $repeaters;
}

sub getPassword {
    my $self = shift;
    my $username = shift;
    $self->{db}->openDatabase ('readonly', 'Preferences');
    my $users = $self->{Data}->{Users} || {};
    $self->{db}->closeDatabase;
    return undef unless $users->{$username};
    my $user = User->unserialize (split $;, $users->{$username});
    return $user->password;
}

sub setPassword {
    my ($self, $user) = @_;
    $self->replaceUser ($user);
}

sub setUserEmail {
    my ($self, $user) = @_;
    $self->replaceUser ($user);
}

sub getUsers {                  # return User objects
    my $self = shift;
    my $users = $self->_getUsersSerialized;
    map {User->unserialize (split $;, $_)} values %$users;
}

sub getUser {
    my ($self, $name) = @_;
    return unless $name;
    my $users = $self->_getUsersSerialized;
    return unless $users->{$name};
    User->unserialize (split $;, $users->{$name});
}

sub _getUsersSerialized {
    my $self = shift;
    $self->{db}->openDatabase ('read', 'Preferences');
    my $users = $self->{Data}->{Users} || {};
    $self->{db}->closeDatabase;
    $users;
}

sub addUser {
    my ($self, $user) = @_;
    my $string = join $;, $user->serialize;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{Data}->{Users}->{$user->name} = $string;
    $self->{db}->closeDatabase;
}

sub removeUser {
    my $self = shift;
    my ($username) = @_;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    my $retval = delete $self->{Data}->{Users}->{$username};
    $self->{db}->closeDatabase;
    $retval;
}

sub replaceUser {
    my ($self, $user) = @_;
    $self->addUser ($user);     # happens to work here
}


# User Groups
sub getUserGroups {                  # return UserGroup objects
    my $self = shift;
    my $ghash = $self->_getFromPreferences ('UserGroups') || {};
    map {UserGroup->unserialize ($_)} values %$ghash;
}
sub addUserGroup {
    my ($self, $group) = @_;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{Data}->{UserGroups}->{$group->id} = $group->serialize;
    $self->{db}->closeDatabase;
}
sub removeUserGroup {
    my ($self, $group) = @_;
    return unless $group;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    delete $self->{Data}->{UserGroups}->{$group->id};
    $self->{db}->closeDatabase;
}
sub replaceUserGroup {
    my ($self, $group) = @_;
    $self->addUserGroup ($group); # happens to work
}


# Pass opname and string to store
sub setAuditing {
    my $self = shift;
    my ($opName, $auditString) = @_;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    my $string = $self->{Data}->{Auditing} || '';
    my (%audit) = split $;, $string;
    $audit{$opName} = $auditString;
    delete $audit{$opName} unless $auditString; # remove if empty
    $self->{Data}->{Auditing} = join $;, %audit;
    $self->{db}->closeDatabase;
}

sub getAuditing {
    my ($self, $opName) = @_;
    my $string = $self->_getFromPreferences ('Auditing') || '';
    my %audit  = split $;, $string;
    $audit{$opName};
}
sub getAuditFile {
    my $self = shift;
    $self->_getFromPreferences ('AuditFile');
}
sub setAuditFile {
    my ($self, $file) = @_;
    $self->_setInPreferences ('AuditFile', $file);
}
sub getAuditEmailAddresses {
    my $self = shift;
    $self->_getFromPreferences ('AuditEmails');
}
sub setAuditEmailAddresses {
    my ($self, $email) = @_;
    $self->_setInPreferences ('AuditEmails', $email);
}

sub _getFromPreferences {
    my ($self, $key) = @_;
    $self->{db}->openDatabase ('read', 'Preferences');
    my $value = $self->{Data}->{$key};
    $self->{db}->closeDatabase;
    $value;
}

sub _setInPreferences {
    my ($self, $key, $value) = @_;
    $self->{db}->openDatabase ('readwrite', 'Preferences');
    $self->{Data}->{$key} = $value;
    $self->{db}->closeDatabase;
    $value;
}

# For making/reverting from backups (e.g. failed sync).
# Return 1 on success, 0 on failure
sub backupForSync {
    my ($self) = @_;
    foreach (qw (Preferences Events)) {
        $self->{WhichFile} = $_;
        my $filename = $self->_getFilename;
        copy ($filename, $filename . 'SyncBack') or return 0;
    }
    return 1;
}
sub revertForSync {
    my ($self) = @_;
    foreach (qw (Preferences Events)) {
        $self->{WhichFile} = $_;
        my $filename = $self->_getFilename;
        copy ($filename . 'SyncBack', $filename) or return 0;
    }
    return 1;
}

1;
