# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# SyncInfo.pm - Keep track of event stuff needed for Syncing a calendar

package SyncInfo;

use strict;
use Fcntl qw (:DEFAULT :flock);

use Calendar::Defines;

sub new {
    my ($class, $calendarName) = @_;
    bless {calendar => $calendarName}, $class;
}

sub _filename {
    my ($self) = @_;
    return undef unless defined $self->{calendar};
    return Defines->baseDirectory . "/data/$self->{calendar}.SyncInfo";
}

# Add "added $id" line to sync file. Return undef on error
sub eventAdded {
    my ($self, $id) = @_;
    $self->_writeLine ('added', $id);
}

# Add "deleted $id" line to sync file. Return undef on error
sub eventDeleted {
    my ($self, $id) = @_;
    $self->_writeLine ('deleted', $id);
}

# Add "modified $id" line to sync file. Return undef on error
sub eventModified {
    my ($self, $id) = @_;
    $self->_writeLine ('modified', $id);
}

# Return ref to list of ids for Modified events
sub getAdded {
    my ($self) = @_;
    return $self->_getSpecifiedLines ('added') || [];
}
# Return ref to list of ids for Modified events, undef on error
sub getModified {
    my ($self) = @_;
    return $self->_getSpecifiedLines ('modified') || [];
}
# Return ref to list of Deleted events, undef on error
sub getDeleted {
    my ($self) = @_;
    return $self->_getSpecifiedLines ('deleted') || [];
}

# Clear added/deleted/modified info for all events. Return undef on error.
sub clearAll {
    my ($self) = @_;
    $self->_deleteFile;
}

sub backupForSync {
    my ($self) = @_;
    my $filename = $self->_filename;
    use File::Copy;
    File::Copy::copy ($filename, $filename . 'Backup') or return 0;
}
sub revertForSync {
    my ($self) = @_;
    my $filename = $self->_filename;
    use File::Copy;
    File::Copy::copy ($filename . 'Backup', $filename) or return 0;
}

# Return undef on error
sub _getSpecifiedLines {
    my ($self, $which) = @_;    # which: 'added', 'modified', or 'deleted'
    my $hash = $self->_parseLines;
    return undef unless $hash;
    my @ids;
    while (my ($id, $action) = each %$hash) {
        push @ids, $id if ($action eq $which);
    }
    \@ids;
}


# Return undef on error
sub _writeLine {
    my ($self, $action, $id) = @_;
    my $handle = $self->_openFile ('append');
    return undef unless $handle;
    print $handle "$action $id\n";
    $self->_closeFile || undef;
}

# Expects items in the file to be ordered oldest --> newest
# Return undef on error, e.g. if no sync info file exists.
sub _parseLines {
    my ($self) = @_;
    $self->{eventHash} = {};

    my $handle = $self->_openFile ('read');
    return undef unless $handle;

    while (<$handle>) {
        my ($action, $id) = split;

        if (!exists $self->{eventHash}->{$id}) {
            $self->{eventHash}->{$id} = $action;
            next;
        }

        # if already present as added...
        if ($self->{eventHash}->{$id} eq 'added') {
            # ...and then deleted, ignore
            if ($action eq 'deleted') {
                delete $self->{eventHash}->{$id};
                next;
            }
            # ...and then modified, leave as added
            if ($action eq 'modified') {
                next;
            }
            # ...and then added again, error
            if ($action eq 'added') {
                $self->{eventHash}->{$id} = 'error - duplicate event?';
                next;
            }
        }

        # if already present as modified...
        if ($self->{eventHash}->{$id} eq 'modified' ) {
            # ...and then added, error
            if ($action eq 'added') {
                $self->{eventHash}->{$id} = 'error - duplicate event?';
                next;
            }
            # modified-->modified or modified-->deleted are fine
        }

        # if already present as deleted...
        if ($self->{eventHash}->{$id} eq 'deleted' ) {
            # ...and then modified, error
            if ($action eq 'modified') {
                $self->{eventHash}->{$id} = 'error - missing event?';
                next;
            }
            # ...and then deleted, error
            if ($action eq 'deleted') {
                $self->{eventHash}->{$id} = 'error - missing event?';
                next;
            }
            # deleted-->added ok
        }

        # otherwise, leave it as is
        $self->{eventHash}->{$id} = $action;
    }
    $self->_closeFile;
    return $self->{eventHash};
}


# File can only be read, appeneded to or deleted.
# All locking is exclusive; in normal operation, it's always just appended to.
# The only reader is the sync process, during which nobody else should
# be doing anything anyway. The sync process also deletes the file.
# Returns filehandle, or undef if error.
sub _openFile {
    my ($self, $which) = @_;
    return undef unless ($which =~ /read|append/i);

    # open for read, or for append/create.
    my $mode = ($which =~ /read/i) ? O_RDONLY : O_WRONLY | O_APPEND | O_CREAT;

    # don't report error if reading and file doesn't exist.
    return undef if ($mode == O_RDONLY and !-f $self->_filename);

    local *SYNCFILE;
    unless (sysopen (SYNCFILE, $self->_filename, $mode)) {
        warn "Couldn't open Sync file: " . $self->_filename .
                " for $which: $!\n";
        return;
    }
    unless (flock (SYNCFILE, LOCK_EX | LOCK_NB)) {
        warn "Sync file is locked; waiting...\n";
        unless (flock (SYNCFILE, LOCK_EX)) {
            warn "Couldn't lock Sync file: " . $self->_filename . ": $!\n";
            return;
        }
    }
    $self->{fileHandle} = *SYNCFILE;
    return $self->{fileHandle};
}

# Return undef if error
sub _closeFile {
    my ($self) = @_;
    my $fh = $self->{fileHandle};
    (close $fh) || undef;
}

# Return undef if error. Not an error if file doesn't exist.
sub _deleteFile {
    my ($self) = @_;
    my $fname = $self->_filename;
    return 1 if (!-e $fname);
    unlink $self->_filename and return 1;
    warn "Couldn't delete Sync file: ", $self->_filename, ": $!\n";
    return undef;
}

1;
