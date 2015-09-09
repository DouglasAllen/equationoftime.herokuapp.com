# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Dates for "Floating" Fiscal years

# Years are _always_ 364 days long, and thus each year starts/ends on
# different days

# Epoch is first day of year for some particular year

# Quarters, Periods
#  All quarters always exactly 91 days (13 weeks)
#  Periods in quarter are 4 weeks, 4 weeks, 5 weeks

package Date::Fiscal::Floating;
use strict;

use Calendar::Date::Fiscal;
use vars ('@ISA');
@ISA = ('Date::Fiscal');

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = $this->SUPER::new (@_);
    bless $self, $class;
}

# Return Date::Fiscal::Floating of first day of the fiscal year self is in
sub startOfYear {
    my $self = shift;
    my $days = $self->daysSinceEpoch;
    return $self - ($days % 364);
}

# Return Date::Fiscal::Floating of first day of the quarter self is in
# Pass arg to get 1st, 2nd, 3rd, or 4th Quarter of year self is in.
sub startOfQuarter {
    my ($self, $which) = @_;
    if ($which) {
        $which = 4 if $which > 4;
        $which = 1 if $which < 1;
    } else {
        $which = 0;
    }

    if ($which) {
        my $yearStart = $self->startOfYear;
        return $yearStart + ($which - 1) * 91;
    }

    my $days = $self->daysSinceEpoch;
    return $self - ($days % 91);
}

sub endOfQuarter {
    my ($self, $which) = @_;
    my $start = $self->startOfQuarter ($which);
    my $nextQ = $start + 92;    # always in next period
    return $nextQ->startOfQuarter - 1;
}

# Return Date::Fiscal::Floating of first day of the period (month) self is in.
# Pass arg to get 1st, 2nd, or 3rd period of quarter self is in.
# In any case, always either the 1st, 5th, or 9th Sunday
sub startOfPeriod {
    my ($self, $which) = @_;
    if ($which) {
        $which = 3 if $which > 3;
        $which = 1 if $which < 1;
    } else {
        $which = 0;
    }

    my $qstart = $self->startOfQuarter;

    if ($which) {
        return $qstart + ($which - 1) * 28;
    }

    my $days = $qstart->deltaDays ($self);

    return $qstart if ($days < 28);
    return $qstart + 28 if ($days < 56);
    return $qstart + 56;
}

# Return int in range 1..12
sub periodNumber {
    my ($self) = @_;
    my $days = $self->startOfYear->deltaDays ($self);
    my $x = ($days / 28);
    return int ($x) + 1;
    return ($x == int ($x) ? $x : int $x + 1);
}

# Return int in range 1..4
sub quarterNumber {
    my ($self) = @_;
    my $days = $self->startOfYear->deltaDays ($self);
    return (int ($days / 91) + 1);
}

# Years always 364 days
sub addYears {
    my ($self, $numYears) = @_;
    $self->addDays ($numYears * 364);
}
# Quarters always 91 days
sub addQuarters {
    my ($self, $numQuarters) = @_;
    $self->addDays ($numQuarters * 91);
}

1;
