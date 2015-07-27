# Copyright 2004-2006, Fred Steinberg, Brown Bear Software

package UserGroup;
use Calendar::MasterDB;

sub new {
    my ($class, %args) = @_;
    my $self = {name        => '',
                description => '',
                %args};
    bless $self, $class;
}

sub name {
    my $self = shift;
    $self->{name} = shift if (@_);
    return $self->{name};
}
sub description {
    my $self = shift;
    $self->{description} = shift if (@_);
    return $self->{description};
}

sub id {
    my $self = shift;
    $self->{id} = shift if (@_);
    return $self->{id};
}

sub getGroup {
    my ($class, $id) = @_;
    return unless defined $id;
    my @groups = MasterDB->getUserGroups;
    foreach (@groups) {
        return $_ if ($id eq $_->id);
    }
    return undef;
}

sub getAll {
    my $class = shift;
    return MasterDB->getUserGroups;
}

sub getByName {
    my ($class, $name) = @_;
    return unless defined $name;
    my @groups = MasterDB->getUserGroups;
    foreach (@groups) {
        return $_ if ($name eq $_->name);
    }
    return undef;

}

# Return map of all groupIDs => [users]
sub getMemberMap {
    my ($class) = @_;
    require Calendar::User;
    my %h;
    foreach my $user (User->getUsers) {
        foreach my $gid ($user->groupIDs) {
            $h{$gid} ||= [];
            push @{$h{$gid}}, $user;
        }
    }
    return \%h;
}

sub serialize {
    my $self = shift;
    join $;, %$self;
}

sub unserialize {
    my ($classname, $string) = @_;
    my @values = split $;, $string;
    push @values, '' if (int(@values/2)*2 != @values);
    $classname->new (@values);
}

1;
