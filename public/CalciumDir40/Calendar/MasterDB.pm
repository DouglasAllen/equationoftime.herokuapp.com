# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# MasterDB.pm - a special Database of information not specific to any one
#               database

# Inherits from Database, of course.
# Class Methods:
#  - new
# Object Methods:

package MasterDB;

use strict;
use File::Basename;

use Calendar::Defines;
use Calendar::Database;
use Calendar::Preferences;
use vars ('@ISA');
@ISA = ("Database");


sub new {
    my $classname = shift;
    $classname->_instance (@_);
}

# Users of MasterDB should not be calling this. This is a singleton.
{
    my $self;
    sub _instance {
        my $classname = shift;
        $self = $classname->SUPER::new ('This_is_the_Master_Database_xyzzyx')
            unless $self;
        $self;
    }
}

# Return full path of MasterDB DBM datafile name.
# It's separate directory from regular data files, so a calendar named
# 'MasterDB' will be ok.
sub _getBaseFilename {
    my $classname = shift;
    return Defines->baseDirectory . '/data/Master/MasterDB';
}

# Open the Master Database.
# Not for public consumption.
# Must create the datafile if it doesn't exist. Shouldn't ever actually
# have to do this, except for the very first run (at which time we also
# create the Default Calendar.)
sub _openDatabase {
    my $classname = shift;

    my $self = $classname->_instance;

    # If the file doesn't exist, create it.
    if (!$$self->{'Imp'}->dbExists) {
        $self->createDatabase;
        $self->setPreferencesToDefault;
        $self->description ('No Description');
        MasterDB->createNewCalendar ('Calendar1',
                                     'Default name - rename it if you like',
                                     undef);
    }

    return $self->SUPER::openDatabase (@_);
}

# Not for public consumption.
sub _closeDatabase {
    my $classname = shift;
    my $self = $classname->_instance;
    $self->SUPER::closeDatabase (@_);
}

sub openDatabase {
    my $self = shift;
    return MasterDB->_openDatabase (@_);
}

sub _addNewCalendar {
    my $classname = shift;
    my ($newCalendar) = @_;

    # store list of calendars in the Master db Includes pref item
    my $incHash = MasterDB->new->getPreferences ('Includes');
    $incHash->{$newCalendar} = {'Included' => 1};
    MasterDB->new->setPreferences ({'Includes' => $incHash});
}

sub deleteCalendar {
    my $classname = shift;
    my ($deleteMe) = shift;

    # Delete the database
    my $db = Database->new ($deleteMe);
    $db->deleteDatabase;

    # rename this cal's AddIn directory
    AddIn->removeCalendarDir ($db);

    # Delete entries in reminder file
    if (Defines->mailEnabled) {
        require Calendar::Mail::MailReminder;
        MailReminder->deleteAllForCalendar ($deleteMe);
    }

    # And remove our knowledge of it
    my $incHash = MasterDB->new->getPreferences ('Includes');
    delete $incHash->{$deleteMe};
    MasterDB->new->setPreferences ({'Includes' => $incHash});
}

sub renameCalendar {
    my $classname = shift;
    my ($oldName, $newName) = @_;

    my $incHash = MasterDB->new->getPreferences ('Includes');
    return if ($incHash->{$newName} or !$incHash->{$oldName});

    # do implementation specific things (e.g. rename datafiles)
    my $db = Database->new ($oldName);
    $db->renameDatabase ($newName)
        or die "Rename failed - bad name: $newName!\n";

    # rename in our hash
    delete $incHash->{$oldName};
    $incHash->{$newName} = {'Included' => 1};
    MasterDB->new->setPreferences ({'Includes' => $incHash});

    # go fix all calendars which might have included the oldname, oy.
    Database->renameInIncludeLists ($oldName, $newName);

    # fix any users that have this set as their default
    my @users = MasterDB->getUsers;
    foreach (@users) {
        next unless (($_->defaultCalendar || '') eq $oldName);
        $_->setDefaultCalendar ($newName);
    }

    # rename this cal's AddIn directory
    AddIn->renameCalendarDir ($oldName, $newName);

    # and rename reminders, if we're reminding
    if (Defines->mailEnabled) {
        require Calendar::Mail::MailReminder;
        MailReminder->calendarRenamed ($oldName, $newName);
    }

    return $newName;
}

sub getAllCalendars {
    my $classname = shift;
    my $self = $classname->new;
    my $prefs = Preferences->new ($self);
    my @calendars = $prefs->getIncludedCalendarNames ('all');
    return @calendars;
}

sub getGroups {
    my $classname = shift;
    my $self = $classname->new;
    my $prefs = Preferences->new ($self);
    my @groups = $prefs->getGroups;
    return @groups;
}

# Pass group or list of groups
# Return 2 listrefs; cals in that group, and cals in no groups
sub getCalendarsInGroup {
    my $classname = shift;
    my $self = $classname->new;
    my @theseGroups = @_;

    my (@retCals, @noGroupCals);
    foreach my $calName ($self->getAllCalendars) {
        my @calGroups = Preferences->new ($calName)->getGroups;

        # if this cal not in any groups, add it to "no group" list, 
        push @noGroupCals, $calName unless @calGroups;

        # if no group passed in
#        (push (@retCals, $calName), next) unless (@theseGroups or @calGroups);

        foreach my $g (@calGroups) {
            (push (@retCals, $calName), last) if grep {$g eq $_} @theseGroups;
        }
    }

    return (\@retCals, \@noGroupCals);
}

# Return hashref of {user_group => perm_level} for specified calendar group
# Stored as e.g. CalGroup1;usersA,none,usersB,admin;CalGroup2;usersA,view
sub get_cal_group_perms {
    my ($class, $calendar_group) = @_;
    my $raw_string = $class->new->getPreferences ('CalGroupPerms') || '';
    my %group_to_user_strings = split ';', $raw_string;
    my $user_string = $group_to_user_strings{$calendar_group} || '';
    my %perms = split ',', $user_string;
    return \%perms;
}
# Pass hashref of {user group => perm_level} to set for specified calendar group
sub set_cal_group_perms {
    my ($class, $calendar_group, $settings) = @_;
    return unless $calendar_group and $settings;
    my $raw_string = $class->new->getPreferences ('CalGroupPerms') || '';
    my %group_to_user_strings = split ';', $raw_string;
    my $user_string = join ',', %$settings;
    $group_to_user_strings{$calendar_group} = $user_string;
    $raw_string = join ';', %group_to_user_strings;
    MasterDB->new->setPreferences ({'CalGroupPerms' => $raw_string});
}

# $defaultsFrom should be a Database name to initialize the prefs from. Use
# undef to use prefs from MasterDB.
sub createNewCalendar {
    my $classname = shift;
    my ($name, $description, $owner, $defaultsFromDB) = @_;

    my $newDB = Database->new ($name);
    $newDB->createDatabase;

    # Insert it into the Master List
    MasterDB->_addNewCalendar ($name);

    my $fromDB = $defaultsFromDB ? Database->new ($defaultsFromDB)
                                 : MasterDB->new;

    # Copy Prefs
    $newDB->setPreferencesToDefault ($fromDB);
    $newDB->description ($description);

    # Copy Perms
    $newDB->setPermittedUsers ($fromDB->getPermittedUsers);

    # Copy Auditing settings (should be in prefs, but it's not.)
    $newDB->auditingFile  ($fromDB->auditingFile);
    $newDB->auditingEmail ($fromDB->auditingEmail);
    foreach (qw (View Add Edit Admin)) {
        $newDB->setAuditing ($_, $fromDB->getAuditing ($_));
    }
    foreach (qw (SysAdmin UserLogin UserOptions)) {
        $newDB->setAuditing ($_, ());
    }

    # If copied from Master Perms, finagle the hacked usernames. Oy. See
    #  AdminSecurity.pm.
    # Also, clear Groups, else we get all groups.
    # Also, clear Categories, else we get System Categories.
    unless ($defaultsFromDB) {
        my $perms = $newDB->getPermittedUsers;
        foreach (keys %$perms) {
            next unless /^SysDefault-(.+)/;
            $perms->{$1} = $perms->{$_};
            delete $perms->{$_};
        }
        $newDB->setPermittedUsers ($perms);

        $newDB->setPreferences ({Groups => '',         # clear them
                                 Categories => {}});   # and them
    }

    # Get rid of Included included cals which aren't Add-Ins. Silly.
    my $prefs = $newDB->getPreferences;
    my $includes = $prefs->Includes;
    my @wronglyIncluded = $prefs->getIncludedCalendarNames ('All');
    foreach my $incName (keys %$includes) {
        delete $includes->{$incName} if grep (/$incName/, @wronglyIncluded);
    }
    $newDB->setPreferences ({Includes => $includes});

    # And set Admin permissions for the owner, if one was specified
    if ($owner) {
        $newDB->setPermission ($owner, 'Admin');
    } else {
        Permissions->new ($newDB)->setAnonymous ('Admin');
    }
}

sub getPassword {
    my $classname = shift;
    my $username = shift;
    my $self = $classname->_instance;
    $$self->{'Imp'}->getPassword ($username);
}

sub setPassword {
    my ($classname, $user) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->setPassword ($user);
}

sub setUserEmail {
    my ($classname, $user) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->setUserEmail ($user);
}

sub replaceUser {
    my ($classname, $user) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->replaceUser ($user);
}

sub getUsers {
    my $classname = shift;
    my $self = $classname->_instance;
    $$self->{'Imp'}->getUsers;   # return list of User objs
}

sub getUser {
    my ($classname, $uname) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->getUser ($uname);
}

sub addUser {
    my ($classname, $user) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->addUser ($user);
}

sub removeUser {
    my ($classname, $username) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->removeUser ($username);
}


sub getUserGroups {
    my $classname = shift;
    my $self = $classname->_instance;
    $$self->{'Imp'}->getUserGroups;   # return list of objs
}
sub removeUserGroup {
    my ($classname, $group) = @_;
    my $self = $classname->_instance;
    # remove from eay user
    foreach ($self->getUsers) {
        $_->removeFromGroup ($group->id);
    }
    $$self->{'Imp'}->removeUserGroup ($group);
}
sub replaceUserGroup {
    my ($classname, $group) = @_;
    my $self = $classname->_instance;
    $$self->{'Imp'}->replaceUserGroup ($group);
}
sub addUserGroup {
    my ($classname, $group) = @_;
    my $self = $classname->_instance;
    my $id = Preferences->new ($self)->_nextID ('UserGroup');
    $group->id ($id);
    $$self->{'Imp'}->addUserGroup ($group);
}


# If renaming system category, must call for every calendar. Ack.
sub renameCategory {
    my ($self, $oldName, $newName) = @_;

    # First, rename the system preference, don't bother with events
    $self->SUPER::renameCategory ($oldName, $newName, 'prefs');

    # Then, rename in each event for each calendar, don't do prefs
    foreach my $calName ($self->getAllCalendars) {
        my $db = Database->new ($calName);
        $db->renameCategory ($oldName, $newName, 'events');
    }
}

1;
