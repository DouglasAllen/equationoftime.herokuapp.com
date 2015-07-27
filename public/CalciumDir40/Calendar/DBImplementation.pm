# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package DBImplementation;

# This is an abstract class, to handle all the implementation specific db
# stuff. It also defines the interface all the implementations must adhere to.

use vars qw ($AUTOLOAD);

# These fns (and more!) must be implemented for each subclass:
#     _getFilenameExtension
#     createDatabase         deleteDatabase
#     openDatabase           closeDatabase
#     setVersion             getVersion
#     nextID
#     getPreferences         savePreferences
#     insertRegularEvent     insertRepeatingEvent
#     insertRegularEvents    insertRepeatingEvents
#     getEvent               getEvents
#     deleteEvent            deleteEventsInRange
#     setPermission          getPermission
#     getPermittedUsers      setPermittedUsers
#     getAllRegularEvents    getAllRepeatingEvents
#     getPassword            setPassword
#     getUsers               addUser
#     removeUser

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    $name =~ s/.*://;           # get rid of package names, etc.
    return unless $name =~ /[^A-Z]/;  # ignore all cap methods; e.g. DESTROY 

    die "DBImplementation is abstract; $name should not be called!";
}

sub new {
    my $classname = shift;
    my $db = shift;
    my $self = {};
    bless $self, $classname;
    $self->{db} = $db;
    $self;
}

sub dbExists {
    my $self = shift;
    return (-e $self->_getFilename);
}

sub _getFilename {
    my $self = shift;
    $self->{db}->_getBaseFilename . $self->_getFilenameExtension;
}

1;
