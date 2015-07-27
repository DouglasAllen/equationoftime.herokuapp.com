# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Calendar::Date::Calc;
require Exporter;
@ISA = qw(Exporter);

@EXPORT_OK = qw (Today
                 Add_Delta_Days
                 Day_of_Week
                 Date_to_Days
                 Add_Delta_YMD
                 Days_in_Month
                 check_date
                 Delta_Days
                 Nth_Weekday_of_Month_Year);

use Time::Local;
#use Time::localtime;

sub _YMDtoSecs {
    my ($y, $m, $d) = @_;
#    $y = 1970 if $y < 1970;
#    $y = 2037 if $y > 2037;
    # If we say 1904, we mean 1904, dammit! Silly timegm.
    # Just use year as is; ok for years > 999.
#    timegm (0, 0, 0, $d, $m-1, $y-1900);
    if (defined $Time::Local::VERSION) { # old versions different...ew
        Time::Local::timegm_nocheck (0, 0, 0, $d, $m-1, $y);
    } else {
        timegm (0, 0, 0, $d, $m-1, $y);
    }
}

sub _secsToYMD {
    my $secs = shift;
    my @date = gmtime ($secs);
    ($date[5] + 1900, $date[4] + 1, $date[3]);
}

sub _isLeapYear {
    my $y = shift;
    return 0 if ($y % 4);      # not div. by 4, not leap year
    return 1 if ($y % 100);    # is by 4, but not by 100, is leap year
    return 0 if ($y % 400);    # is by 4, is by 100, but not by 400 isn't
    return 1;                  # is by 400, is!
}

sub Today {
    # we don't use _secsToYMD since we want localtime, not gmtime
    my @date = localtime (time);
    ($date[5] + 1900, $date[4] + 1, $date[3]);
}

sub Add_Delta_Days {
    my ($y, $m, $d, $numDays) = @_;
    _secsToYMD (_YMDtoSecs ($y, $m, $d) + ($numDays * 86400));
}

# Monday = 1, Sunday = 7 (because that's how Date::Calc does it.)
sub Day_of_Week {
    my ($y, $m, $d) = @_;
    (gmtime (_YMDtoSecs ($y, $m, $d)))[6] || 7;
}

# actually number of seconds since epoch; just used for comparisons
sub Date_to_Days {
    my ($y, $m, $d) = @_;
    _YMDtoSecs ($y, $m, $d);
}

# see doc in the real Date::Calc (this (did!) need better testing!)
sub Add_Delta_YMD {
    my ($y, $m, $d, $dy, $dm, $dd) = @_;
    (($y, $m, $d) = Add_Delta_Days ($y, $m, $d, $dd)) if $dd;
    $m += $dm;
    if ($dm > 0) {
        $y += int(($m-1) / 12);
        $m = ($m % 12) || 12;
    } else {
        if ($m <= 0) {
            $y -= 1 + int($m / -12);
            $m = ($m % 12) || 12;
        }
    }
    $y += $dy;
    # if not valid date, go to last day in that month
    $d = Days_in_Month ($y, $m) if ($d > 28 && !check_date ($y, $m, $d));
    ($y, $m, $d);
}

sub Days_in_Month {
    my ($y, $m) = @_;
    return ('x', 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$m]
        unless $m == 2;
    return _isLeapYear ($y) ? 29 : 28;
}

sub check_date {
    my ($y, $m, $d) = @_;
    my ($y2, $m2, $d2) = _secsToYMD (_YMDtoSecs ($y, $m, $d));
    return ($y == $y2 && $m == $m2 && $d == $d2);
}

sub Delta_Days {
    my ($y, $m, $d, $y2, $m2, $d2) = @_;
    $secs =  _YMDtoSecs ($y2, $m2, $d2) - _YMDtoSecs ($y, $m, $d);
    return ($secs / 86400);
}

# $n is 1-5; return empty list if no 5th in this month
# loop can be eliminated...
sub Nth_Weekday_of_Month_Year {
    my ($y, $m, $dayOfWeek, $n) = @_;

    # Find first dayOfWeek in month
    $date = 1;
    $dow = Day_of_Week ($y, $m, $date);
    while ($dow != $dayOfWeek) {
        $date++;
        $dow++;
        $dow = 1 if $dow > 7;
    }

    $date += 7 * ($n - 1);
    return check_date ($y, $m, $date) ? ($y, $m, $date) : ();
}

1;
