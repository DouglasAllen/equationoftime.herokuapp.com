# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

# Dates for fiscal years
# This is a virtual class; don't instantiate it. Use one of the subclasses.
#  Date::Fiscal::Fixed, or Date::Fiscal::Floating

# Two types of Fiscal Year supported:

#  - Fixed     years start/end on set dates, e.g. Oct 1 --> Sep. 30
#              365 or 366 days long (366 for leap years)
#  - Floating  years are _always_ 364 days long, and thus each year
#              starts/ends on different days (TYPE B)

# Epoch
#  - Fixed    - first day of year
#  - Floating - first day of year for some particular year

# Quarters, Periods
#  - Fixed     quarters are always 3 months; periods are single months
#  - Floating  all quarters always exactly 91 days (13 weeks)
#              periods in quarter are 4 weeks, 4 weeks, 5 weeks

package Date::Fiscal;
use strict;

use Calendar::Date;
use vars ('@ISA');
@ISA = ('Date');

sub new {
    my $this = shift;
    my $class = ref ($this) || $this;
    my $self = $class->SUPER::new (@_);
    bless $self, $class;
    if (ref $this) {
        $self->epoch ($this->epoch);
    }
    $self;
}

# Set and/or Return Date (not Date::Fiscal) of first day of fiscal year.
# Epoch determines start of year. It should be a plain "Date".
# If not set, return self
sub epoch {
    my ($self, $epoch) = @_;
    if ($epoch) {
        $self->{fiscalEpoch} = ref ($epoch) ? $epoch : Date->new ($epoch);
    }
    return $self->{fiscalEpoch} || $self;
}

# Returns num days since epoch
sub daysSinceEpoch {
    my $self = shift;
    return ($self->epoch->deltaDays ($self));
}

# Return Date::Fiscal of first day of the fiscal year self is in.
sub startOfYear {
    warn "startOfYear() must be implemented in subclass!";
    return undef;
}

sub endOfYear {
    my $self = shift;
    my $start = $self->startOfYear;
    return $start->addYears (1) - 1;
}

# Return Date::Fiscal of first day of the quarter self is in
# Pass arg to get 1st, 2nd, 3rd, or 4th Quarter of year self is in.
sub startOfQuarter {
    warn "startOfQuarter() must be implemented in subclass!";
    return undef;
}

sub endOfQuarter {
    warn "endOfQuarter() must be implemented in subclass!";
    return undef;
}

# Return Date::Fiscal of first day of the period (month) self is in.
# Pass arg to get 1st, 2nd, or 3rd period of quarter self is in.
sub startOfPeriod {
    warn "startOfPeriod() must be implemented in subclass!";
    return undef;
}

sub endOfPeriod {
    my ($self, $which) = @_;
    my $start = $self->startOfPeriod ($which);
    my $nextP = $start + 40;    # always in next period
    return $nextP->startOfPeriod - 1;
}

# Return int in range 1..12
sub periodNumber {
    warn "periodNumber() must be implemented in subclass!";
    return undef;
}

# Return something like "August [Period 3]"
# Month name is the month first day of 3rd week is in. (For now...)
# If 'includeYear' param, it's something like "August 2003 [Period 3]"
sub periodName {
    my ($self, $i18n, $includeYear) = @_;
    my $day = $self->startOfPeriod + 14;
    my $pNum = $self->periodNumber;
    my $year = $includeYear ? $day->year . ' ' : '';
    if ($i18n) {
        my $m = $i18n->get ($day->monthName);
        my $p = $i18n->get ('Period');
        return  "$m $year\[$p $pNum\]";
    } else {
        return $day->monthName . " $year\[Period $pNum\]";
    }
}

# Int in range 1..366 (fixed) or 1..364 (floating)
sub dayNumber {
    my ($self) = @_;
    return $self->startOfYear->deltaDays ($self) + 1;
}

sub addQuarters {
    warn "addQuarters() must be implemented in subclass!";
    return undef;
}

# Periods not always same number days; we return first day of next period.
sub addPeriods {
    my ($self, $numPeriods) = @_;
    my $count = abs $numPeriods;
    my $first = $self->new ($self);
    while ($count--) {
        if ($numPeriods > 0) {
            $first = $first->endOfPeriod + 1;
        } else {
            $first = ($first->startOfPeriod - 1)->startOfPeriod;
        }
    }
    return $first;
}

# Ignore the "which week is first week" preference
sub weekNumber {
    my $self = shift;
    my $day = $self->dayNumber;     # 1..366 (fixed) or 1..364 (floating)
    return int (($day / 7) + 1);
}

1;
