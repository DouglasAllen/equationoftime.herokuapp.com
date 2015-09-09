# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# AddIn.pm - a special Database of pre-defined events

# Inherits from Database

package AddIn;

use strict;
use File::Basename;

use Calendar::Defines;
use Calendar::Database;
use Calendar::Date;
use Calendar::Event;
use Calendar::RepeatInfo;
use vars ('@ISA');
@ISA = ("Database");

sub new {
    my ($class, $name, $db) = @_;
    my $self = $class->SUPER::new ($name);
    my $dir = $class->_getDir ($db);
    $$self->{_AddInData} = {dir => $dir,
                             db => $db};   # i.e. cal we're associated with.
                                           # Note that SUPER/Database is ref to
                                           # hashref, hence $$
    bless $self, $class;
}

sub _myData {
    my ($self, $key) = @_;
    $self = $$self if ($self->isa ('REF')); # oh dear; see Database.pm
    return $self->{_AddInData}->{$key};
}
sub _setMyData {
    my ($self, $key, $value) = @_;
    $self = $$self if ($self->isa ('REF')); # oh dear; see Database.pm
    $self->{_AddInData}->{$key} = $value;
}

# Return list of all the available AddIn objects for specified cal, or system
sub getAddIns {
    my ($classname, $db) = @_;
    my @names = $classname->getAddInFilenames ($db);
    my @addIns;
    foreach (@names) {
        push @addIns, $classname->new ($_, $db);
    }
    return @addIns;
}

# Return list of all AddIns, by scanning filesystem. For efficiency,
#  so we don't need to open each calendar's data file when refreshing subscrips
sub get_all_AddIns {
    my $class = shift;

    # Get directories in the Add-Ins dir, and read add-ins from each
    my $base_dir = $class->_getDir;
    return undef unless (-d $base_dir);
    opendir (DIR, $base_dir)
      or die "Error; Can't open Add-In dir $base_dir: $!\n";
    my @dir_entries = readdir(DIR);
    closedir DIR;
    my @cal_dirs = grep { -d }             # just directories
                   grep { -r }             # only ones we can read
                   map  { "$base_dir/$_"}  # get full pathname
                   grep {!/W/}             # only w/valid calendar names
                   grep {!/^\.\.?$/}       # ignore . and ..
                   @dir_entries;

    my @addins = $class->getAddIns; # first, get Master Add-Ins

    # Then, get for each calendar (i.e. each sub-dir)
    foreach my $cal_dir (@cal_dirs) {
        # We need to clear the Database cache for each new dir, since
        # otherwise different AddIns w/the same name will get the same object!
        Database->clearCache;

        my $cal_name = basename $cal_dir;
        push @addins, $class->getAddIns (Database->new ($cal_name));
    }
    return @addins;
}

# Return list of add-in filenames for specified calendar, or system
sub getAddInFilenames {
    my ($class, $db) = @_;
    my $dir = $class->_getDir ($db);
    return unless (-d $dir);    # if no dir, no files

    opendir (DIR, $dir) or die "Oopsie; Can't open AddIn dir $dir: $!\n";
    my @files = readdir(DIR);
    closedir DIR;
    my @addIns = grep { -f }             # we only want files
                 grep { -r }             # ignore those we can't read
                 map  { "$dir/$_"}       # get full pathname
                 grep {!/\W/}            # only files w/valid calendar names
                 grep {!/^\.\.?$/}       # ignore . and ..
                 @files;                 # get all files in directory
    @addIns = map {basename $_} @addIns;
    return @addIns;
}

# $lines can be string or array ref of lines
# return false on success, message on error
sub writeNewFile {
    my ($class, $db, $fname, $lines) = @_;
    my $dir = $class->_getDir ($db);

    # Create main AddIn dir if it doesn't exist
    if (!-d $class->_getDir) {
        my $main = $class->_getDir;
        warn "Creating main AddIn directory $main\n";
        if (!mkdir ($main, 0777)) {
            warn "Error: can't create directory $main: $!\n";
            return "create dir '$main' failed";
        }
    }

    # Create dir if it doesn't exist
    if (!-d $dir) {
        warn "Creating AddIn directory $dir\n";
        if (!mkdir ($dir, 0777)) {
            warn "Error: can't create directory $dir: $!\n";
            return "create dir '$dir' failed";
        }
    }
    unless (-d $dir and -w $dir) {
        warn "Can't open new Add-In file: $dir not a writable directory\n";
        return "$dir not a writeable directory";
    }
    my $theFile = "$dir/$fname";
    $theFile =~ /(.*)/; $theFile = $1;  # untaint
    if (-e "$dir/$fname") {
        warn "new Add-In file $dir/$fname already exists\n";
        return "'$fname' already exists";
    }
    if (!open (ADDIN, "> $theFile")) {
        warn "Can't open new Add-In file $dir/$fname for writing: $!\n";
        return "Can't write to $dir/$fname";
    }
    $lines = join '', @$lines if (ref ($lines) eq 'ARRAY');
    print ADDIN $lines;
    print ADDIN "\n";
    close ADDIN;
    return;
}
sub deleteFiles {
    my ($class, $db, $name, $datOnly) = @_;

    return 1 unless defined ($name);

    my $dir = $class->_getDir ($db);
    my $datDir = "$dir/dat";

    my @datFiles;
    if (opendir (DIR, $datDir)) {
        @datFiles = readdir(DIR);
        closedir DIR;
    } else {
        warn "opendir failed: $!\n";
        return undef;
    }

    # First, remove any dat files
    my @myDatFiles = grep {/^$name\./} @datFiles;
    foreach my $name (@myDatFiles) {
        $name =~ /(.*)/;
        $name = $1;           # untaint it
        unlink "$datDir/$name";
    }

    return 1 if $datOnly;

    # Remove source AddIn file
    if ($name =~ /^(\w+)$/) {
        $name = $1;             # untaint it
        return unlink "$dir/$name";
    }
    return undef;
}
sub replaceSourceFile {
    my ($self, $lines) = @_;
    my $tempName = $self->_sourceFilename . '.temp';
    rename ($self->_sourceFilename, $tempName);
    my $err = $self->writeNewFile ($self->_myData ('db'), $self->name, $lines);
    if ($err) {
        rename ($tempName, $self->_sourceFilename);
        return $err;
    }
    $self->openDatabase ('read'); # compile new version
    $self->closeDatabase;
    if ($self->getType eq 'unknown') {
        rename ($tempName, $self->_sourceFilename);
        $self->deleteFiles ($self->_myData ('db'), $self->name, 'datOnly');
        return 'bad file type';
    }
    return;
}

sub renameCalendarDir {
    my ($class, $oldName, $newName) = @_;
    return unless (defined $oldName and defined $newName);
    foreach ($oldName, $newName) {
        /^(\w+)$/;    # untaint
        $_ = $1;      #        it
    }
    my $oldDir = Defines->baseDirectory . '/data/AddIns/' . $oldName;
    my $newDir = Defines->baseDirectory . '/data/AddIns/' . $newName;
    return unless -d $oldDir;
    return if     -d $newDir;
    rename ($oldDir, $newDir) ||
        warn "Couldn't rename $oldDir to $newDir: $!\n";
}
sub removeCalendarDir {
    my ($class, $db) = @_;
    return if ($db->isa ('MasterDB'));
    my $dir = $class->_getDir ($db);
    return unless (-d $dir);
    require File::Path;
    return File::Path::rmtree ($dir);     # Remove it!
}


# Return full filesystem path to Master AddIn dir, or calendar specific one
sub _getDir {
    my ($classOrObj, $db) = @_;
    if (ref $classOrObj) {
        return $classOrObj->_myData ('dir');
    }
    my $dir = Defines->baseDirectory . '/data/AddIns';
    if (defined $db and !$db->isa ('MasterDB')) {
        $dir .= '/' . $db->name;
    }
    $dir =~ /(.*)/; $dir = $1;  # untaint it
    return $dir;
}


# Return path of AddIn compiled datafile basename.
sub _getBaseFilename {
    my $self = shift;
    return $self->_getDir . '/dat/' . $self->name;
}

# Return full path of the actual Add-In file ("source code")
sub _sourceFilename {
    my $self = shift;
    return $self->_getDir . '/' . $self->name;
}

# Create the datafile if it doesn't exist or is older than the source file.
# Then, call openDatabase in the parent to actually open the database.
sub openDatabase {
    my $self = shift;

    my $sourcefile = $self->_sourceFilename;

    # If source doesn't exist in cal-specific dir, use system dir
    if (!-e $sourcefile) {
        $self->_setMyData ('dir', Defines->baseDirectory . '/data/AddIns');
        $sourcefile = $self->_sourceFilename;
    }

    my $filename = $self->_getFilename;

    # See if we need to parse and build the AddIns
    my $ok = 1;
    if (!-e $filename or (-M $filename > -M $sourcefile)) {
        $ok = $self->_compileSource;
    }

    if ($ok) {
        $self->SUPER::openDatabase (@_);
    }
}

# Convert the Add-In text 'sourcefile' into a datafile with the structure
# we expect.
sub _compileSource {
    my $self = shift;

    open (ADDIN, '<' . $self->_sourceFilename)
        or die "Error: Can't open Add-In file!\n    " .
                                           $self->_sourceFilename . ": $!\n";

#   warn "Compiling AddIn " . $self->name . "\n";

    # Create the dat dir, if it doesn't exist
    my $datDir = $self->_getDir . '/dat';
    mkdir ($datDir, 0777) || die "Error: can't create directory $datDir: $!\n"
        unless (-d $datDir);

    # Create the data file; don't use openDatabase, or we'll loop
    $self->createDatabase ('overwrite');

    # Grab all the lines
    my @lines = <ADDIN>;
    close ADDIN;

    # See if it's a iCalendar/vCalendar addin; else Calcium format
    my $type = 'unknown';
    foreach (@lines) {
        if (/BEGIN:V/) {
            $type = 'vCal';
            last;
        }
        if (/\|/) {
            # looks like a Calcium Addin, make sure
            next if /^\s*\#/;
            my ($text, $date) = split /\|/;
            $date =~ s/^\s+//;
            $date =~ s/\s+$//;
            if ($date =~ m{\d+/\d+(/\d+)?$}) { # make sure it's valid
                $type = 'Calcium';
            } else {
                $type = 'unknown';
            }
            last;
        }
    }

    my ($repeats, $regulars);
    if ($type eq 'vCal') {
        ($repeats, $regulars) = $self->_compilevCalendarFile (\@lines);
        $type = 'iCalendar';
    } elsif ($type eq 'Calcium') {
        ($repeats, $regulars) = $self->_compileCalciumFile (\@lines);
        $type = 'Calcium AddIn';
    } else {
        warn "Unknown AddIn file format: " . $self->_sourceFilename . "\n";
        $self->_setMyData ('type', $type);
        $self->_setMyData ('badLines', [@lines[0..4]]);
        $self->last_loaded_date (time);
        $self->last_load_status (0);
        return;
    }

    $self->_setMyData ('type', $type);
    $self->_setMyData ('repeatCount',  scalar (@$repeats));
    $self->_setMyData ('regularCount', scalar (@$regulars / 2));;

    $self->insertEvents ($repeats);
    $self->insertEvents ($regulars);

    $self->last_loaded_date (time);
    $self->last_load_status (1);
    return 1;
}

sub _compileCalciumFile {
    my ($self, $lines) = @_;

    # Read and set the description from the first non-comment, non-blank
    # line
    while (@$lines) {
        my $line = shift @$lines;
        next if ($line =~ /^\#/ or $line =~ /^$/);
        chomp $line;
        $self->description ($line);
        last;
    }

    my (@repeaterList, @regularList);
    my $future = Date->openFuture;

    # Continue with the events
    local $_;
    foreach (@$lines) {
        # this, of course, needs help!
        next if /^\#/ or /^$/;

        my ($text, $date);
        ($text, $date) = split /\|/;
        $text =~ s/^\s+//;
        $text =~ s/\s+$//;
        $date =~ s/^\s+//;
        $date =~ s/\s+$//;

        my $start  = Date->openPast;

        my (@fields, $repeat);
        (@fields) = split /\//, $date;
        if (@fields == 2) {
            $start->month ($fields[0]);
            $start->day   ($fields[1]);
            $repeat = RepeatInfo->new ($start, $future, 'year', '1');
        } elsif (@fields == 3) {
            if ($fields[0] > 999) {
                $start->year  ($fields[0]);
                $start->month ($fields[1]);
                $start->day   ($fields[2]);
            } else {
                my ($nth, $dow, $month) = @fields;
                $start = Date->getNthWeekday ($start->year, $month, $dow,$nth);
                $repeat = RepeatInfo->new ($start, $future, undef, undef,
                                           $nth, 12);
            }
        }

        my $newEvent = Event->new (text       => $text,
                                   export     => 'Public',
                                   repeatInfo => $repeat);
        if ($repeat) {
            push @repeaterList, $newEvent;
        } else {
            push @regularList, ($newEvent, $start);
        }
    }

    return (\@repeaterList, \@regularList);
}

sub _compilevCalendarFile {
    my ($self, $lines) = @_;

    my (@repeaterList, @regularList);

    require Calendar::EventvEvent;
    require Calendar::vCalendar::vCalendar;
    my $vcal = vCalendar->new (lines => $lines);

    my $name = $vcal->getName;
    $self->description ($name) if defined $name;

    my $vEvents = $vcal->events;
    foreach (@$vEvents) {
        my ($event, $date) = Event->newFromvEvent ($_);
        next unless $event;
        if ($event->isRepeating) {
            push @repeaterList, $event;
        } else {
            push @regularList, ($event, $date);
        }
    }

    return (\@repeaterList, \@regularList);
}

# Return Database obj of owner; either a calendar or MasterDB
sub getOwner {
    return shift->_myData ('db');
}

sub getType {
    my $self = shift;
    return $self->_myData ('type');
}
sub getCounts {
    my $self = shift;
    return ($self->_myData ('regularCount'), $self->_myData ('repeatCount'));
}
sub getBadLines {
    my $self = shift;
    return $self->_myData ('badLines'); # ref to array of some lines
}

# Save stuff for keeping track of iCalendar subscriptions. Need:
#  - URL/Location
#  - how often to refresh
#  - last loaded date, status
# (Store using various overloaded unused preferences)

# Store a URL so we can refresh (we overload/reuse pref named 'MailSignature')
sub sourceLocation {
    shift->_get_or_set ('MailSignature', @_);
}

sub refresh_interval {
    shift->_get_or_set ('MailFormat', @_);
}

# Store last time this Add-In was loaded; for automatic updating
#  (we overload/reuse pref named 'MailFrom')
# Typically a unix timestamp - let's do it in UTC!
sub last_loaded_date {
    shift->_get_or_set ('MailFrom', @_);
}

# Status of last load; simply good (true) or bad (false or undef)
sub last_load_status {
    shift->_get_or_set ('MailSMTP', @_);
}

sub _get_or_set {
    my $self = shift;
    my $pref_name = shift;
    if (@_) {
        $self->setPreferences ({$pref_name => shift});
    } else {
        return $self->getPreferences ($pref_name);
    }
}

sub normalize_URL {
    my ($class, $url) = @_;
    return undef unless $url;
    $url =~ s/^\s*//;
    $url =~ s/\s*$//;
    $url =~ s/^webcal:/http:/;      # Convert "webcal" to "http"
    if ($url and $url !~ /^http/) {
        $url = "http://$url";            # Stick an http on front if not there
    }
    return $url;
}

1;
