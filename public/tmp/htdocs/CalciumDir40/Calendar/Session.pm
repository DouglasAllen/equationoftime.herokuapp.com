# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Session.pm - Keep track of Session Info


package Session;

use Calendar::Defines;

use strict;

sub getUsername {
    my $class = shift;
    my ($username, $ip) = $class->getUsernameAndIP (@_);
    $username;
}

sub getUsernameAndIP {
    my $class = shift;
    my $id = shift;
    my $idHash = $class->_getIDHash;
    return unless ($id and $idHash and $idHash->{$id});
    split $;, $idHash->{$id};
}


sub newID {
    my $class = shift;
    my $username = shift;

    my $idHash = $class->_getIDHash;

    # If we're getting too big, delete anything that's over, say, 1 day
    # old. Silly, but good enough.
    if (keys %$idHash > 200) {
        my $time = time - (60 * 60 * 24);
        foreach (sort {$a <=> $b} keys %$idHash) {
            last if $_ > $time;
            delete $idHash->{$_};
        }
    }

    # Make sure it's unique. Silly, but good enough, and probably never used.
    # We stick a decimal in there so the sort & compare above still works
    my $id = time . '.' . int (rand 1234567);
    while (exists $idHash->{$id}) {
        $id .= int (rand 1234567);
    }

    $idHash->{$id} = "$username$;$ENV{'REMOTE_ADDR'}";

    $class->_setIDHash ($idHash);
    $id;
}

{
use Fcntl qw(:DEFAULT :flock);
my $filename = Defines->baseDirectory . '/data/Master/sessionIDs';

sub _getIDHash {
    my $class = shift;
    my %theHash;
    open (SESSIONS, $filename) or return {};
    flock (SESSIONS, LOCK_SH) or die "Couldn't lock '$filename'! $!\n";
    local $_;
    while (<SESSIONS>) {
        my ($id, $username, $ip) = split $;, $_;
        chomp $ip;
        $theHash{$id} = "$username$;$ip";
    }
    close SESSIONS;
    \%theHash;
}

sub _setIDHash {
    my $class = shift;
    my $theHash = shift;
    sysopen (SESSIONS, $filename, O_RDWR|O_CREAT)
                     or die "Couldn't open Session ID file '$filename'! $!\n";
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
