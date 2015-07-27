# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Permissions.pm

# set - pass username, perm level
# get - pass username
# (get|set)UserHash
# (get|set)Anonymous
# (get|set)AuthenticatedUser
# permitted - username, level

my %levelValues = (None       => 0,
                   View       => 1,
                   Add        => 2,
                   Edit       => 3,
                   Admin      => 4,
                   Administer => 4);

package Permissions;

use strict;

# Pass in a Database object, or the name of the database.
sub new {
    my $class = shift;
    my ($theArg) = @_;

    my ($self, $db);

    $db = $theArg if (ref ($theArg) && $theArg->isa ('Database'));
    $db = Database->new ($theArg) unless $db;

    $self = {};
    $self->{'db'} = $db;

    bless $self, $class;
    $self;
}

# Pass username and permission level.
sub set {
    my $self = shift;
    my ($userName, $level) = @_;

    die "Someone screwed up - permission $level not recognized.\n"
        unless (defined $levelValues{$level});

    if ($userName) {
        $self->{'db'}->setPermission ($userName, $level);
    } else {
        $self->setAnonymous ($level);
    }
}

# Pass username; returns current permission level. If permission for
# a user is not specified, return greater perm of Anonymous and
# Authenticated User. Does NOT check groups.
sub get {
    my $self = shift;
    my ($userName) = @_;
    return $self->getAnonymous unless $userName;
    my ($user) = $self->{'db'}->getPermission ($userName);
    return $user if ($user && $levelValues{$user}); # so 'None' doesn't count
    my ($anon, $auth) = ($self->getAnonymous, $self->getAuthenticatedUser);
    return ($levelValues{$auth} > $levelValues{$anon} ? $auth : $anon);
}

sub getUserHash {
    my $self = shift;
    $self->{'db'}->getPermittedUsers || {};
}

sub setUserHash {
    my $self = shift;
    my $hashRef = shift;
    $self->{'db'}->setPermittedUsers ($hashRef);
}

sub getAnonymous {
    my $self = shift;
    $self->{'db'}->getPermission ('AnonymousUser') || 'None';
}

sub getAuthenticatedUser {
    my $self = shift;
    $self->{'db'}->getPermission ('AuthenticatedUser') || 'None';
}

sub setAnonymous {
    my $self = shift;
    my ($level) = @_;
    $self->{'db'}->setPermission ('AnonymousUser', $level);
}

sub setAuthenticatedUser {
    my $self = shift;
    my ($level) = @_;
    $self->{'db'}->setPermission ('AuthenticatedUser', $level);
}

# Pass group; returns permission level. Return 'none' if permission for
# a group is not specified.
sub getGroup {
    my ($self, $groupOrID) = @_;
    return 'None' unless defined $groupOrID;
    my $id = ref $groupOrID ? $groupOrID->id : $groupOrID;
    return $self->{db}->getGroupPermission ($id) || 'None';
}
sub setGroup {
    my ($self, $groupOrID, $level) = @_;
    return unless (defined $groupOrID);
    die "Permission level '$level' not recognized.\n"
        unless (defined $levelValues{$level});
    my $id = ref $groupOrID ? $groupOrID->id : $groupOrID;
    $self->{db}->setGroupPermission ($id, $level);
}

# Pass username and access level; return undef if access denied.
# If $userName is undef, check for Anonymous
# If $userName is AnonymousUser, check for Anonymous
# If $userName is AuthenticatedUser, check for AuthenticatedUser
# Note that Add implies View, Edit imples Add, Admin implies Edit
# Anyone with Sys Admin permission can do anything.
sub permitted {
    my $self = shift;
    my ($userOrName, $requested) = @_;

    die "Someone screwed up - permission $requested not found.\n"
        unless (defined $levelValues{$requested});

    my ($user, $userName);
    if (defined $userOrName) {
        if (ref ($userOrName) eq 'User') {
            $user     = $userOrName;
            $userName = $user->name;
        } else {
            $user     = User->getUser ($userOrName);
            $userName = $userOrName;
        }
    }

    my $have;
    if (!$userName || $userName eq 'AnonymousUser') {
        $have = $self->getAnonymous;
    } elsif ($userName eq 'AuthenticatedUser') {
        $have = $self->getAuthenticatedUser;
    } else {
        $have = $self->get ($userName);
    }

    return 1 if ($levelValues{$have} >= $levelValues{$requested});

    # Check user group perms
    my @user_group_ids;
    if ($user) {
        @user_group_ids = $user->groupIDs;
        foreach (@user_group_ids) {
            my $have = $self->getGroup ($_);
            return 1 if ($levelValues{$have} >= $levelValues{$requested});
        }
    }

    return undef if $self->{db}->isa ('MasterDB');

    # OK, now see if any User Group the user is in has permission in any
    #  Calendar group this calendar is in
    if (@user_group_ids) {
        my @cal_groups = $self->{db}->getPreferences->getGroups;
        my $master = MasterDB->new;
        foreach my $cal_group (@cal_groups) {
            # Get hashref of {user group IDs => perm in cal group}
            my $calgroup_perms = MasterDB->get_cal_group_perms ($cal_group);
            foreach my $ugroup_id (@user_group_ids) {
                my $have = $calgroup_perms->{$ugroup_id} || 'None';
                return 1 if ($levelValues{$have} >= $levelValues{$requested});
            }
        }
    }

    return Permissions->new (MasterDB->new)->permitted ($userName, 'Admin');
}

sub userPermitted {
    my ($self, $userOrName, $requested) = @_;
    my $uname = ref ($userOrName) ? $userOrName->name : $userOrName;
    my $have;
    if (!$uname || $uname eq 'AnonymousUser') {
        $have = $self->getAnonymous;
    } else {
        $have = $self->get ($uname);
    }
    return 1 if ($levelValues{$have} >= $levelValues{$requested});
}

sub groupPermitted {
    my ($self, $group_or_id, $requested) = @_;
    my $have = $self->getGroup ($group_or_id);
    return 1 if ($levelValues{$have} >= $levelValues{$requested});
}

1;
