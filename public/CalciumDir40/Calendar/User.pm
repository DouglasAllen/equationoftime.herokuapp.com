# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# new
# name
# _getUsername
# internallyAuthenticated
# makeNewCookie
# clearCookie
# checkPassword
# setPassword
# getUsers
# addUser
# defaultCalendar

package User;

use strict;
use CGI (':standard');

use Calendar::MasterDB;
use Calendar::Session;

sub new {
    my $class = shift;
    my $cgi = shift;
    my $self = {};
    bless $self, $class;

    $self->{internalAuthentication} = undef;
    $self->{name} = undef;

    # If we've been authenticated by the web server, use that username.
    # Otherwise, if we've got a SessionID cookie, use it to get the name.
    # Otherwise, return undef.
    if ($ENV{'REMOTE_USER'} and $ENV{'REMOTE_USER'} ne '-') {
        $self->{name} = $ENV{'REMOTE_USER'};
    } else {
        my $id = $cgi->cookie ('-name' => 'CalciumSessionID');
        if ($id) {
            my ($name, $ip) = Session->getUsernameAndIP ($id);
#            if ($ip && $ip eq $ENV{'REMOTE_ADDR'}) {
                $self->{name} = $name;
                $self->{internalAuthentication} = 1;
#            }
        }
        # If still not authenticated, check for Username/PW in query string
        elsif (my $uname = $cgi->param ('User')) {
            my $pw = $cgi->param ('Password');
            if (User->checkPassword ($uname, $pw)) {
                $self->{internalAuthentication} = 1;
                $self->{name} = $uname;
            }
        }
    }

    return undef unless $self->{name};
    $self;
}

# Create a new user, but don't bother with the cookie.
# Only name is required.
sub create {
    my $class = shift;
    my %args = (name       => undef,
                email      => '',
                defaultCal => undef,
                zoneOffset => 0,
                password   => undef,
                isLocked   => 0,
                confirmDel => undef,
                @_);

    return undef unless $args{name};

    my $self = {name => $args{name}};
    $self->{password}   = $args{password}   if $args{password}; # uncrypted
    $self->{email}      = $args{email};
    $self->{defaultCal} = $args{defaultCal};
    $self->{timezone}   = $args{zoneOffset};
    $self->{isLocked}   = $args{isLocked} ? 1 : 0;
    if ($args{confirmDel} and $args{confirmDel} =~ /^(all|repeat)$/) {
        $self->{confirmDel} = $args{confirmDel};
    }
    bless $self, $class;
    $self;
}

sub name {
    my $self = shift;
    return $self->{name};
}
sub password {
    my $self = shift;
    return $self->{crypted};
}
sub email {
    my $self = shift;
    return $self->{email};
}
sub timezone {
    return shift->{timezone};
}

sub defaultCalendar {
    return shift->{defaultCal};
}

# One of 'all', 'repeat' (only for repeating); otherwise, no confirm
sub confirm_delete {
    return shift->{confirmDel};
}

sub isLocked {
    return shift->{isLocked};
}

# Return list of UserGroup ids that this user is in
sub groupIDs {
    my $self = shift;
    return @{$self->{groups} || []};
}
sub addToGroup {
    my ($self, $groupID) = @_;
    $self = $self->getUser ($self->name); # make sure we've got complete object
    my $glist = $self->{groups} || [];
    return if (grep {$groupID == $_} @$glist); # not if already member
    $self->{groups} = [@$glist, $groupID];
    MasterDB->replaceUser ($self);
}
sub removeFromGroup {
    my ($self, $groupID) = @_;
    $self = $self->getUser ($self->name); # make sure we've got complete object
    my $glist = $self->{groups} || [];
    return unless grep {$_ == $groupID} @$glist; # not if already member
    my @newList;
    foreach (@$glist) {
        next if ($_ == $groupID);
        push @newList, $_;
    }
    $self->{groups} = \@newList;
    MasterDB->replaceUser ($self);
}

sub internallyAuthenticated {
    my $self = shift;
    $self->{internalAuthentication};
}

sub makeNewCookie {
    my $classname = shift;
    my ($cgi, $user) = @_;
    my $cookie = $cgi->cookie ('-name'  => 'CalciumSessionID',
                               '-value' => Session->newID ($user));
    return ($cookie, 'CalciumSessionID');
}

sub clearCookie {
    my $classname = shift;
    my $cgi = shift;
    my $cookie = $cgi->cookie ('-name'    => 'CalciumSessionID',
                               '-value'   => '');
    return $cookie;
}

# true if ok, false if bad, undef if user not found ?
sub checkPassword {
    my $classOrObject = shift;
    my ($username, $password);
    if (ref $classOrObject) {
        $password = shift;
        $username = $classOrObject->name;
    } else {
        ($username, $password) = @_;
    }

    my $storedPW = MasterDB->getPassword ($username);
    return undef unless $storedPW;
    return (crypt ($password, $storedPW) eq $storedPW);
}

# set password to crypted version of passed in string
sub setPassword {
    my ($self, $password) = @_;

    my @saltchars = ('a'..'z','A'..'Z',0..9,'.','/');
    my $storedPW = crypt ($password, "$saltchars[int(rand(64))]" .
                                     "$saltchars[int(rand(64))]");
    $self->{password} = $password;
    $self->{crypted}  = $storedPW;
    MasterDB->setPassword ($self);
}

sub setEmail {
    my ($self, $email) = @_;
    $self->{email} = $email;
    MasterDB->setUserEmail ($self);
}

sub setTimezone {
    my ($self, $zone) = @_;
    $self = $self->getUser ($self->name);
    $self->{timezone} = $zone;
    MasterDB->replaceUser ($self);
}

sub setDefaultCalendar {
    my ($self, $cal) = @_;
    # Make sure we've got the whole user first!
    $self = $self->getUser ($self->name);
    $self->{defaultCal} = $cal;
    MasterDB->replaceUser ($self);
}

sub setLocked {
    my ($self, $lock) = @_;
    # Make sure we've got the whole user first!
    $self = $self->getUser ($self->name);
    $self->{isLocked} = $lock ? 1 : 0;
    MasterDB->replaceUser ($self);
}

sub setConfirmDelete {
    my ($self, $confirm) = @_;
    # Make sure we've got the whole user first!
    $self = $self->getUser ($self->name);
    if ($confirm and $confirm !~ /^(all|repeat)$/) {
        $confirm = undef;
    }
    $self->{confirmDel} = $confirm;
    MasterDB->replaceUser ($self);
}

sub setGroups {
    my ($self, @groupIDs) = @_;
    # remove invalid group IDs
    my @ids;
    foreach (@groupIDs) {
        next unless defined;
        next unless ($_ =~ /^\d+$/);
        push @ids, $_;
    }
    $self->{groups} = \@ids;
    MasterDB->replaceUser ($self);
}

# Return a user object
sub getUser {
    my ($classname, $name) = @_;
    return MasterDB->getUser ($name);  # yes it is blessed via unserialize
}

# Return list of (all) user objects
sub getUsers {
    my $classname = shift;
    my @users = MasterDB->getUsers;
    return @users;
}

# Return list of (all) user names
sub getUserNames {
    my $classname = shift;
    my @users = $classname->getUsers;
    return map {$_->name} @users;
}

# Add a user to the DB
sub addUser {
    my $self = shift;
    my $alreadyCrypted = shift;    # for migrating users

    return undef unless $self->{name};

    # don't allow 'AnonymousUser' or 'AuthenticatedUser', need them for perms
    return undef if ($self->{name} eq 'AuthenticatedUser');
    return undef if ($self->{name} eq 'AnonymousUser');

    return undef if User->getUser ($self->{name}); # already exists

    $self->{password} ||= '';

    if ($alreadyCrypted) {
        $self->{crypted} = $self->{password};
    } else {
        my @saltchars = ('a'..'z','A'..'Z',0..9,'.','/');
        $self->{crypted} = crypt ($self->{password},
                                  "$saltchars[int(rand(64))]" .
                                  "$saltchars[int(rand(64))]");
    }
    MasterDB->addUser ($self);
    return 1;
}

# Return User obj that matches email address (or undef if no match)
sub userFromAddress {
    my ($class, $address) = @_;
    my @users = $class->getUsers;
    my %map = map {($_->email || 0) => $_} @users;
    return $map{$address};
}


{
    my %map = (a => 'name',
               b => 'crypted',  # crypted password, of course
               c => 'email',
               d => 'timezone',
               e => 'defaultCal',
               f => 'isLocked',
               g => 'groups',
               h => 'confirmDel');
     sub serialize {
        my $self = shift;
        my @list;

        foreach ('a'..'f','h') {
            my $val = $self->{$map{$_}};
            push @list, ($_, $val) if (defined $val);
        }
        # Groups are special, stored as listref
        if ($self->{groups} and defined ($self->{groups}->[0])) {
            my $groups = join ' ', @{$self->{groups}};
            push @list, ('g', $groups);
        }
        @list;
     }

     sub unserialize {
        my $classname = shift;
        my %values;
        {
         local $^W = undef;
         (%values) = @_;
        }

        my $self = {};
        bless $self, $classname;

        my $val;
        foreach ('a'..'f','h') {
            next unless defined ($val = $values{$_});
            $self->{$map{$_}} = $val;
        }
        # Groups are special, stored as listref
        if ($val = $values{g}) {
            my @groups = split / /, $val;
            $self->{groups} = \@groups;
        }
        $self;
     }
}

1;
