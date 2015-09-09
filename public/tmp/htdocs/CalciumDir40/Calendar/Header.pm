# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Header for calendar displays (i.e mainly "ShowIt")

package Header;
use strict;

sub new {
    my $class = shift;
    my %args = (title  => '',
                op     => undef,
                cookie => undef,
                @_);

    my $self = {};
    bless $self, $class;

    my $refresh;
    if ($args{op}) {
        $refresh = $args{op}->prefs->AutoRefresh || 0;
        undef $refresh if ($refresh <= 0);
    }
    $self->{html} = GetHTML->startHTML (title  => $args{title},
                                        class  => $args{op} ?
                                                    $args{op}->opName : undef,
                                        cookie        => $args{cookie},
                                        Refresh       => $refresh,
                                        head_elements => $args{head_elements},
                                        op            => $args{op});
    $self;
}

sub getHTML {
    my $self = shift;
    $self->{html};
}

1;
