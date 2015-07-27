# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# DB_DBM.pm - Use simple object serialization to write/read a DBM file
#
# Inherits from abstract class DBImplementation

# On openDatabase(), we tie the DBM file to a hash:
#   $self->{tiedHash}
#
# $self->{tiedHash}->{CreationDate}   why not store it...
# $self->{tiedHash}->{Version}        something a la '2.1'
# $self->{tiedHash}->{LastID}         Id to use for next new event
# $self->{tiedHash}->{Preferences}    Serialized Preferences Object
# $self->{tiedHash}->{Permissions}    Serialized Permissions Hash
# $self->{tiedHash}->{Auditing}       Serialized Auditing Hash (opname keys)
# $self->{tiedHash}->{AuditFile}      Full path to log file 
# $self->{tiedHash}->{AuditEmails}    Space sep. string of email address
# $self->{tiedHash}->{"$date"}     Serialized list of serialized regular Events
# $self->{tiedHash}->{Repeaters}     Serialized list of all repeating Event ids
# $self->{tiedHash}->{id}            Serialized repeating Event with that id

# Only in MasterDB
# $self->{tiedHash}->{Users}      Serialized hash, username => serialized User
# $self->{tiedHash}->{UserGroups} Serialized hash, id => serialized UserGroup
#
# And then write it out on closeDatabase (if necessary)

package DB_DBM;

use strict;
use Fcntl qw(:DEFAULT :flock);
use File::Basename;
use DB_File;
use FileHandle;

use Calendar::DBImplementation;
use Calendar::Date;
use Calendar::Event;
use Calendar::Preferences;
use Calendar::User;

use vars ('@ISA');
@ISA = ('DBImplementation');

# Return extension to use on database filename
sub _getFilenameExtension {
    my $self = shift;
    return ".dbm";
}

# Called from Database object. Pass arg if you want to overwrite an
# existing db of the same name.
sub createDatabase {
    my $self = shift;
    my ($overwrite) = @_;

    my $filename = $self->_getFilename;

    # First, check for existance, and act appropriately
    if (-e $filename) {
        if ($overwrite) {
            unlink $filename 
        } else {
            die "$filename already exists, quitting.\n";
        }
    }

    my %dbFile;
    my $success = tie %dbFile, 'DB_File', $filename, O_CREAT|O_RDWR, 0644;
    if (!$success) {
        die "Can't create data file " . $filename . ": $!\n";
        return;
    }

    my $date = localtime;
    $dbFile{'CreationDate'} = $date;

    undef $success;
    untie %dbFile;
}

sub deleteDatabase {
    my $self = shift;
    my $filename = $self->_getFilename;
    unlink $filename or die "Couldn't remove " . $filename . ": $!\n";
}

sub renameDatabase {
    my $self = shift;
    my $newName = shift;
    return unless $newName;
    my $oldName = $self->{db}->name;
    my $oldFilename = $self->_getFilename;
    my $newFilename;
    my $ext = $self->_getFilenameExtension;
    ($newFilename = $oldFilename) =~ s/$oldName$ext/$newName$ext/;
    rename ($oldFilename, $newFilename) ||
        die "Couldn't rename $oldFilename to $newFilename: $!\n";
}

# Tie ourselves into the DBM file
sub openDatabase {
    my $self = shift;
    my ($readWrite) = @_;

    my ($status, $lock, %dbFile);

    if ($readWrite =~ /^(rw|rdwr|o_rdwr)$|write/i) {
        $status = O_CREAT|O_RDWR;
        $lock   = LOCK_EX;
    } else {
        $status = O_RDONLY;
        $lock   = LOCK_SH;
    }

    # Cache - don't untie/retie if we've already got it
    if ($self->{currentLock} and $self->{currentLock} == $lock) {
        return 1;
    } elsif (exists $self->{tiedHash}) {
        $self->closeDatabase (1);
    }
    $self->{currentLock} = $lock;

    my $db = tie %dbFile, 'DB_File', $self->_getFilename, $status, 0644;
    unless ($db) {
         my $message;
         if ($self->dbExists) {
             $message = "Can't open " . $self->_getFilename . ": $!\n";
         } else {
             $message = "Calendar does not exist: <b>" . $self->{db}->name .
                        '</b>';
         }
         if ($ENV{HTTP_HOST}         ||
             $ENV{GATEWAY_INTERFACE} ||
             $ENV{USER_AGENT}        ||
             $ENV{REQUEST_METHOD}) {
             require Calendar::GetHTML;
             GetHTML->errorPage (undef, # i18n
                                 header    => 'Database error',
                                 message   => $message,
                                 backCount => 0);
         }
         warn "Can't open " . $self->_getFilename . ": $!\n";
         die "\n";
#         exit (-1);
    }

    # OK, we opened it; now lock that puppy
    my $fd = $db->fd;
    my $handle = FileHandle->new;
    if ($lock == LOCK_SH) {
        open ($handle, "<&=$fd") || die "couldn't dup fd for lock! $!\n";
    } else {
        open ($handle, "+<&=$fd") || die "couldn't dup fd for lock! $!\n";
    }
    unless (flock ($handle, $lock | LOCK_NB)) {
        warn ('DB Locked; waiting to ' . (($lock == LOCK_EX) ? 'write.'
                                                             : 'read.'));
        unless (flock ($handle, $lock)) { die "couldn't lock database! $!" }
    }

    $self->{'filehandle'} = $handle;
    $self->{'tiedHash'} = \%dbFile;

    return 1;
}

sub closeDatabase {
    my $self = shift;
    my $force = shift;

    return unless $force;       # we're holding on to this stuff now

    untie %{$self->{'tiedHash'}};
    delete $self->{'tiedHash'};
    close ($self->{'filehandle'}) if $self->{'filehandle'}; #  unlock the flock
}

sub DESTROY {
     my $self = shift;
     $self->closeDatabase (1);  # untie, release lock
}

sub getVersion {
    my $self = shift;
    $self->{db}->openDatabase ('read');
    my $version = $self->{tiedHash}->{'Version'};
    $self->{db}->closeDatabase;
    $version;
}

sub setVersion {
    my $self = shift;
    my $version = shift;
    $self->{db}->openDatabase ('readwrite');
    $self->{tiedHash}->{'Version'} = $version;
    $self->{db}->closeDatabase;
    $version;
}

# -- IDs --------------------------------------------------
sub nextID {
    my $self = shift;

    $self->{db}->openDatabase ('readwrite');

    $self->{tiedHash}->{'LastID'} ||= 1;
    my $id = $self->{tiedHash}->{'LastID'};
    $self->{tiedHash}->{'LastID'}++;

    $self->{db}->closeDatabase;
    $id;
}

sub reserveNextIDs {
    my $self   = shift;
    my $numIDs = shift;

    $self->{db}->openDatabase ('readwrite');
    $self->{tiedHash}->{'LastID'} ||= 1;
    my $id = $self->{tiedHash}->{'LastID'};
    $self->{tiedHash}->{'LastID'} += $numIDs;
    $self->{db}->closeDatabase;
    $id;
}

# -- Preferences --------------------------------------------------
sub getPreferences {
    my $self = shift;

    $self->{db}->openDatabase ('readonly');

    my $prefs = $self->{'tiedHash'}->{'Preferences'};

    $self->{db}->closeDatabase;

    return Preferences->unserialize ($prefs);     # a Preferences Object
}

sub savePreferences {
    my $self = shift;
    my $prefsObj = shift;

    my $prefs = $prefsObj->serialize;

    $self->{db}->openDatabase ('readwrite');
    $self->{'tiedHash'}->{Preferences} = $prefs;
    $self->{db}->closeDatabase;

    return $prefs;
}

# -- Events --------------------------------------------------
sub insertRegularEvent {
    my $self = shift;
    my ($date, $event) = @_;

    my $eventString = join $;, $event->serialize;

    $self->{db}->openDatabase ('readwrite');

    my $eventList = $self->{'tiedHash'}->{"$date"};
    $self->{'tiedHash'}->{"$date"} = _serializeList ($eventList, $eventString);

    $self->{db}->closeDatabase;
}

sub insertRepeatingEvent {
    my $self = shift;
    my ($event) = @_;

    my $eventString = join $;, $event->serialize;

    # each repeating event just gets hashed on its id. We also keep a list
    # of all repeating event ids
    my $key = $event->id;

    $self->{db}->openDatabase ('readwrite');

    $self->{tiedHash}->{$key} = $eventString;
    $self->{tiedHash}->{Repeaters} ||= ' ';
    $self->{tiedHash}->{Repeaters} .= "$key ";

    $self->{db}->closeDatabase;
}

# Stick a whole list of events in the db
# List looks like (event, date, event, date, ...)
# Return list of new events (w/IDs set)
sub insertRegularEvents {
    my $self = shift;
    my ($eventList, $nextID) = @_;

    $self->{db}->openDatabase ('readwrite');

    my @newEvents;

    while (@$eventList) {
        my $event = shift @$eventList;
        my $date  = shift @$eventList;
        $event->id ($nextID++);
        my $eventString = join $;, $event->serialize;
        my $eventList = $self->{'tiedHash'}->{"$date"};
        $self->{'tiedHash'}->{"$date"} =
                                  _serializeList ($eventList, $eventString);
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

    $self->{db}->openDatabase ('readwrite');

    my @newEvents;

    foreach my $event (@$eventList) {
        $event->id ($nextID++);
        my $eventString = join $;, $event->serialize;

        # each repeating event just gets hashed on its id. We also keep a
        # list of all repeating event ids
        my $key = $event->id;

        $self->{tiedHash}->{$key} = $eventString;
        $self->{tiedHash}->{Repeaters} ||= ' ';
        $self->{tiedHash}->{Repeaters} .= "$key ";

        push @newEvents, $event;
    }

    $self->{db}->closeDatabase;
    return \@newEvents;
}

# Return an event, given ID and/or Date. Works for regular or repeating
# events. Date is ignored for repeaters.
sub getEvent {
    my $self = shift;
    my ($date, $eventID) = @_;

    my $event;

    $self->{db}->openDatabase ('readonly');

    my $eventString = $self->{tiedHash}->{$eventID};

    # If it's a repeating event, we find it right away
    if ($eventString) {
        $event = Event->unserialize (split $;, $eventString)
    } else {
        # Otherwise, it lives on the list for a date
        my @eventList = $self->_getRegularEvents ($date);

        foreach (@eventList) {
            if ($_->id == $eventID) {
                $event = $_;
                last;
            }
        }
    }

    $self->{db}->closeDatabase;

    $event;
}

# Return a ref to a hash of regular events in the specified date range, and
# a ref to an array of ALL repeating events. Date range has already been
# checked.
sub getEvents {
    my $self = shift;
    my ($fromDate, $toDate) = (@_);

    $self->{db}->openDatabase ('readonly');

    my (%returnHash);

    # Get the regular events for the dates in the range
    while ($fromDate <= $toDate) {
        my @events = $self->_getRegularEvents ($fromDate);
        $returnHash{"$fromDate"} = \@events if @events;
        $fromDate++;
    }

    # Get all repeaters
    my @repeaters = $self->_getRepeatingEvents;

    $self->{db}->closeDatabase;

    return (\%returnHash, \@repeaters);
}

# Delete an event on the list for a certain date.
sub deleteEvent {
    my $self = shift;
    my ($date, $eventID, $allOrOne) = @_;

    $self->{db}->openDatabase ('readwrite');

    my $eventString = $self->{tiedHash}->{$eventID};

    # If it's a repeating event, we get right to it
    if ($eventString) {
        if ($allOrOne =~ /^all/i) {
            delete $self->{tiedHash}->{$eventID};
            $self->{tiedHash}->{Repeaters} =~ s/ $eventID / /;
        } else {
            my $event = Event->unserialize (split $;, $eventString);
            $event->excludeThisInstance ($date);
            $self->{tiedHash}->{$eventID} = join $;, $event->serialize;
        }
    } else {
        my @eventList = $self->_getRegularEvents ($date);
        my $i;
        for ($i=0; $i<@eventList; $i++) {
            last if ($eventList[$i]->id == $eventID);
        }

        # If we found it, delete it
        if ($i < @eventList) {
            splice @eventList, $i, 1;
            $self->_setRegularEvents ($date, @eventList);
        }
    }

    $self->{db}->closeDatabase;
}

# Delete all events in a specified date range. Repeating events will be
# deleted if their start and end specs are within the specified range.
# Return ref to list of deleted event ids.
sub deleteEventsInRange {
    my $self = shift;
    my ($fromDate, $toDate, $categories) = @_;
    my $doCats = $categories && @$categories;

    $self->{db}->openDatabase ('readwrite');

    my @deletedIDs;

    # Much faster to iterate through events, not date range, for large ranges.
    foreach (keys %{$self->{'tiedHash'}}) {
        my @seps = m[/]g;
        next unless (@seps == 2);
        if (Date->new ($_)->inRange ($fromDate, $toDate)) {
            # need to save ids to return for deleting MailReminders. Oy.
            my @eventList = $self->_getRegularEvents ($_);
            my @notDeleted;
            foreach (@eventList) {
                if ($doCats and !$_->inCategory ($categories)) {
                    push @notDeleted, $_;
                } else {
                    push @deletedIDs, $_->id;
                }
            }
            if (@notDeleted) {
                $self->_setRegularEvents ($_, @notDeleted);
            } else {
                delete $self->{'tiedHash'}->{"$_"};
            }
        }
    }

    # And now do repeating events.
    my @repeatIDs = split ' ', $self->{tiedHash}->{Repeaters};
    foreach (@repeatIDs) {
        my $event = Event->unserialize (split $;, $self->{tiedHash}->{$_});
        if ($event->repeatInfo->startDate->inRange ($fromDate, $toDate) &&
            $event->repeatInfo->endDate->inRange   ($fromDate, $toDate)) {
            my $id = $event->id;
            delete $self->{tiedHash}->{$id};
            $self->{tiedHash}->{Repeaters} =~ s/ $id / /;
            push @deletedIDs, $id;
        }
    }

    $self->{db}->closeDatabase;
    \@deletedIDs;
}

sub deleteAllEvents {
    my $self = shift;
    $self->{db}->openDatabase ('readwrite');
    # All event keys start with a digit, e.g. "2002/12/22", "322" (repeater)
    foreach (keys %{$self->{'tiedHash'}}) {
        next unless /$\d/;
        delete $self->{tiedHash}->{$_};
    }
    $self->{tiedHash}->{Repeaters} = '';
    delete $self->{tiedHash}->{LastID};
    $self->{db}->closeDatabase;
}

sub _getRegularEvents {
    my $self = shift;
    my $date = shift;
    my @eventStrings = _unserializeList ($self->{'tiedHash'}->{"$date"});
    map {Event->unserialize (split $;, $_)} @eventStrings;
}

sub _setRegularEvents {
    my $self = shift;
    my ($date, @eventList) = @_;
    my @eventStrings = map {join $;, $_->serialize} @eventList;
    $self->{'tiedHash'}->{"$date"} = join "\035", @eventStrings;
}

sub _getRepeatingEvents {
    my $self = shift;
    my @repeatIDs = split ' ', ($self->{tiedHash}->{Repeaters} || '');
    map {Event->unserialize (split $;, $self->{tiedHash}->{$_})} @repeatIDs;
}

sub getAllRegularEvents {
    my $self = shift;
    my %returnHash;

    $self->{db}->openDatabase ('readonly');

    foreach my $key (keys %{$self->{'tiedHash'}}) {
        next unless $key =~ m-^\d\d\d\d/-;
        my @eventList = $self->_getRegularEvents ($key);
        $returnHash{$key} = \@eventList if @eventList;
    }

    $self->{db}->closeDatabase;
    \%returnHash;
}

sub getAllRepeatingEvents {
    my $self = shift;
    $self->{db}->openDatabase ('readonly');
    my @repeaters = $self->_getRepeatingEvents;
    $self->{db}->closeDatabase;
    \@repeaters;
}


# -- Permissions --------------------------------------------------

# Pass username and permission level.
#   (currently expect 'Remove, 'None', 'View', 'Add', 'Edit', 'Admin')
sub setPermission {
    my $self = shift;
    my ($userName, $permission) = @_;

    $self->{db}->openDatabase ('readwrite');

    my $string = $self->{'tiedHash'}->{'Permissions'} || '';
    my (%perms) = split $;, $string;

    if ($permission =~ /Remove/i) {
        delete $perms{$userName};
    } else {
        $perms{$userName} = $permission;
    }

    $self->{'tiedHash'}->{'Permissions'} = join $;, %perms;

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
    my %perms = $self->_getHash ('Permissions');
    return (\%perms);
}

sub setPermittedUsers {
    my $self = shift;
    my $hashRef = shift;

    $self->{db}->openDatabase ('write');

    my $string = join $;, %$hashRef;

    $self->{'tiedHash'}->{'Permissions'} = $string;

    $self->{db}->closeDatabase;
}

sub getGroupPermission {
    my ($self, $groupID) = @_;
    my %perms = $self->_getHash ('GroupPermissions');
    return ($perms{$groupID});
}
sub setGroupPermission {
    my ($self, $groupID, $level) = @_;
    my %perms = $self->_getHash ('GroupPermissions');
    $self->{db}->openDatabase ('readwrite');
    if ($level =~ /remove/i) {
        delete $perms{$groupID};
    } else {
        $perms{$groupID} = $level;
    }
    my $string = join $;, %perms;
    $self->{tiedHash}->{GroupPermissions} = $string;
    $self->{db}->closeDatabase;
}


# -- Users --------------------------------------------------

sub getPassword {
    my $self = shift;
    my $username = shift;
    $self->{db}->openDatabase ('read');
    my @users = _unserializeList ($self->{'tiedHash'}->{'Users'});
    $self->{db}->closeDatabase;
    foreach (@users) {
        my $user = User->unserialize (split $;, $_);
        return $user->password if ($user->name eq $username);     # crypted
    }
    return undef;               # user not found
}

sub setPassword {
    my ($self, $user) = @_;
    $self->replaceUser ($user); # just replace the whole thing
}

sub setUserEmail {
    my ($self, $user) = @_;
    $self->replaceUser ($user); # just replace the whole thing
}

sub getUsers {                  # return User objects
    my $self = shift;
    $self->{db}->openDatabase ('read');
    my @userStrings = _unserializeList ($self->{'tiedHash'}->{'Users'});
    $self->{db}->closeDatabase;
    map {User->unserialize (split $;, $_)} @userStrings;
}

sub getUser {
    my ($self, $name) = @_;
    return undef unless defined $name;
    $self->{db}->openDatabase ('read');
    my @userStrings = _unserializeList ($self->{'tiedHash'}->{'Users'});
    $self->{db}->closeDatabase;
    foreach (@userStrings) {
        my $user = User->unserialize (split $;, $_);
        return $user if ($user->name eq $name);
    }
    return undef;
}

sub addUser {
    my ($self, $user) = @_;
    my $string = join $;, $user->serialize;
    $self->{db}->openDatabase ('readwrite');
    my $userList = $self->{'tiedHash'}->{'Users'};
    $self->{'tiedHash'}->{'Users'} = _serializeList ($userList, $string);
    $self->{db}->closeDatabase;
}

sub removeUser {
    my $self = shift;
    my ($username) = @_;

    $self->{db}->openDatabase ('readwrite');

    my @userStrings = _unserializeList ($self->{'tiedHash'}->{'Users'});
    my @newStrings;
    foreach (@userStrings) {
        my $user = User->unserialize (split $;, $_);
        push @newStrings, $_ unless ($user->name eq $username);
    }

    $self->{'tiedHash'}->{'Users'} = join "\035", @newStrings;
    $self->{db}->closeDatabase;
}

sub replaceUser {
    my ($self, $theUser) = @_;
    $self->removeUser ($theUser->name);
    $self->addUser ($theUser);
}

# -- UserGroups --------------------------------------------------
sub getUserGroups {
    my $self = shift;
    $self->{db}->openDatabase ('read');
    my @groupStrings = _unserializeList ($self->{tiedHash}->{UserGroups});
    $self->{db}->closeDatabase;
    map {UserGroup->unserialize ($_)} @groupStrings;
}
sub addUserGroup {
    my ($self, $group) = @_;
    my $string = join $;, $group->serialize;

    # Ack, need to increment max id for group here too, since we lose the
    # pref from MasterDB. Silly.
    my $prefs = $self->getPreferences;
    my $foo = $prefs->_nextID ('UserGroup');

    $self->savePreferences ($prefs);

    $self->{db}->openDatabase ('readwrite');
    my $groupList = $self->{tiedHash}->{UserGroups};
    $self->{tiedHash}->{UserGroups} = _serializeList ($groupList, $string);
    $self->{db}->closeDatabase;
}
sub removeUserGroup {
    my ($self, $group) = @_;
    $self->{db}->openDatabase ('readwrite');
    my @groupStrings = _unserializeList ($self->{tiedHash}->{UserGroups});
    my @newStrings;
    foreach (@groupStrings) {
        my $thisGroup = UserGroup->unserialize ($_);
        push @newStrings, $_ unless ($group->id eq $thisGroup->id);
    }

    $self->{tiedHash}->{UserGroups} = join "\035", @newStrings;
    $self->{db}->closeDatabase;
}
sub replaceUserGroup {
    my ($self, $group) = @_;
    $self->removeUserGroup ($group);
    $self->addUserGroup ($group);
}


# -- Auditing --------------------------------------------------

# Pass opname and string to store
sub setAuditing {
    my $self = shift;
    my ($opName, $auditString) = @_;

    $self->{db}->openDatabase ('readwrite');

    my $string = $self->{'tiedHash'}->{'Auditing'} || '';
    my (%audit) = split $;, $string;

    $audit{$opName} = $auditString;
    delete $audit{$opName} unless $auditString;
    $self->{'tiedHash'}->{'Auditing'} = join $;, %audit;
    $self->{db}->closeDatabase;
}

# Pass opname; return string for that op
sub getAuditing {
    my $self = shift;
    my ($opName) = @_;
    my %audit = $self->_getHash ('Auditing');
    return $audit{$opName};
}

sub getAuditFile {
    my $self = shift;
    $self->{db}->openDatabase ('read');
    my $filename = $self->{tiedHash}->{'AuditFile'};
    $self->{db}->closeDatabase;
    $filename;
}

sub setAuditFile {
    my $self = shift;
    my $filename = shift;
    $self->{db}->openDatabase ('readwrite');
    $self->{tiedHash}->{'AuditFile'} = $filename;
    $self->{db}->closeDatabase;
    $filename;
}

sub getAuditEmailAddresses {
    my $self = shift;
    $self->{db}->openDatabase ('read');
    my $string = $self->{tiedHash}->{'AuditEmails'} || '';
    $self->{db}->closeDatabase;
    $string;
}

sub setAuditEmailAddresses {
    my $self = shift;
    my ($addresses) = @_;
    $self->{db}->openDatabase ('readwrite');
    $self->{tiedHash}->{'AuditEmails'} = $addresses;
    $self->{db}->closeDatabase;
    $addresses;
}


# -------------------------------------------------------------------

sub _getHash {
    my $self = shift;
    my $hashName = shift;
    $self->{db}->openDatabase ('readonly');
    my $string = $self->{tiedHash}->{$hashName} || '';
    my (%hash) = split $;, $string;
    $self->{db}->closeDatabase;
    return (%hash);
}

# Add a string to a possibly existing serialized string. We can't use $; as
# a separator, since it's used in each string in the list.
sub _serializeList {
    my ($eventList, $eventString) = @_;
    if ($eventList) {
        return $eventList . "\035" . $eventString;
    }
    return $eventString;
}

sub _unserializeList {
    my ($eventList) = @_;
    return unless $eventList;
    split "\035", $eventList;
}


# For making/reverting from backups (e.g. failed sync).
# Return 1 on success, 0 on failure
sub backupForSync {
    my ($self) = @_;
    require File::Copy;
    my $filename = $self->_getFilename;
    File::Copy::copy ($filename, $filename . 'SyncBack') or return 0;
    return 1;
}
sub revertForSync {
    my ($self) = @_;
    my $filename = $self->_getFilename;
    File::Copy::copy ($filename . 'SyncBack', $filename) or return 0;
    return 1;
}

1;
