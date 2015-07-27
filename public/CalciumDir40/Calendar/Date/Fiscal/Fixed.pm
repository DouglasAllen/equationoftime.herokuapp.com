# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Dates for Fixed Fiscal years
# All years start and end on the same day of the year, e.g. Oct 1 --> Sep. 31

# Quarters are always 3 calendar months
# Periods are calendar months

package Date::Fiscal::Fixed;
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

# Return Date::Fiscal::Fixed of first day of the fiscal year self is in
sub startOfYear {
    my $self = shift;
    my ($y, $m, $d) = $self->epoch->ymd;

    # Year is this year, unless start is after me which makes it last year
    $y = $self->year;
    if ($self->month < $m  or
        ($self->month == $m and $self->day < $d)) {
        $y = $self->year - 1;
    }
    return $self->new ($y, $m, $d);
}

# Return Date::Fiscal::Fixed of first day of the quarter self is in
# Pass arg to get 1st, 2nd, 3rd, or 4th Quarter of year self is in.
sub startOfQuarter {
    my ($self, $which) = @_;

    my $yearStart = $self->startOfYear;

    if (!$which) {
        my $months = $yearStart->deltaMonths ($self) + 1; # 1..12
        $which = int ($months / 3) + 1;
    }

    $which = 4 if $which > 4;
    $which = 1 if $which < 1;

    return $yearStart->addMonths (($which - 1) * 3);

}

sub endOfQuarter {
    my ($self, $which) = @_;
    my $start = $self->startOfQuarter ($which);
    my $nextQ = $start->addMonths (3);
    return $nextQ - 1;
}

# Return Date::Fiscal::Fixed of first day of the period (month) self is in.
# Pass arg to get 1st, 2nd, or 3rd period of quarter self is in.
sub startOfPeriod {
    my ($self, $which) = @_;
    if (!$which) {
        return $self->firstOfMonth;
    }

    $which = 3 if $which > 3;
    $which = 1 if $which < 1;

    return $self->startOfQuarter->addPeriods ($which - 1);
}

# Return int in range 1..12
sub periodNumber {
    my ($self) = @_;
    return $self->startOfYear->deltaMonths ($self) + 1;
}

# Return int in range 1..4
sub quarterNumber {
    my ($self) = @_;
    return (int ($self->startOfYear->deltaMonths ($self) / 3) + 1);
}

# Quarters always 3 periods
sub addQuarters {
    my ($self, $numQuarters) = @_;
    $self->addPeriods ($numQuarters * 3);
}

1;
