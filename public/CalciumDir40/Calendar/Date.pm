# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Do a bunch of date thingees

# We currently use the Date::Calc package, it's rather handy. But can be
# replaced, if necessary. (And it was, since it's not standard.)

# We support overloaded operators:  <=>, +, -, ""

# Class Methods:
#  constructors
#    new
#    openPast
#    openFuture
#    getNthWeekday
#    today

# Class AND Object Methods:
#  monthName
#  dayName

# Object Methods:
#  overloadeds
#    <=> spaceship
#    ""  stringify
#    +   overloadAdd      - returns new object
#    -   overloadSubtract - returns new object
#  sets/gets
#    day, month, year
#  ymd
#  inRange
#  isWeekend    - return undef unless Sat. or Sun.
#  dayNumber    - returns 1 - 366
#  weekNumer    - returns 1 - 53
#  daysInMonth
#  dayOfWeek  - Monday is 1, Sunday is 7
#  firstOfWeek  - returns new object
#  firstOfMonth - returns new object
#  addDaysNew   - returns new object
#  addDays        these
#  addYears         don't
#  addWeeks           create
#  addMonths            new objects
#  deltaDays
#  deltaWeeks
#  deltaMonths
#  deltaYears

# Internal Methods
#   _toInt

package Date;
use strict;

use Calendar::Date::Calc qw (Add_Delta_Days Day_of_Week Date_to_Days
                             Add_Delta_YMD check_date Today Delta_Days
                             Nth_Weekday_of_Month_Year Days_in_Month);

use overload (
    '<=>' => 'spaceship',
    '""'  => 'stringify',
    '+'   => 'overloadAdd',
    '-'   => 'overloadSubtract',
             );

# Constructor: takes
#  no args; defaults to today
#   1 args: "yyyy/mm/dd" -or-  an existing date object -or- a relative date
#   3 args: $year, $month, $day
sub new {
  my $this = shift;
  my $class = ref $this || $this;

  my $self = {};
  bless $self, $class;

  if (@_ == 1 and ref($_[0]) and $_[0]->isa ("Date")) {
      $self->{year}  = $_[0]->{year};
      $self->{month} = $_[0]->{month};
      $self->{day}   = $_[0]->{day};
  } elsif (@_ == 1 and $_[0] and $_[0] ne '') {
      my ($dateString) = @_;
      ($self->{year}, $self->{month}, $self->{day}) = split '/', $dateString;
      if (!defined $self->{month}) {
          my $offset = $self->{year};
          return $class->today + $offset;
      }
  } elsif (@_ == 3) {
      ($self->{year}, $self->{month}, $self->{day}) = @_;
  } else {
      return $class->today();
  }

  # Do some error checking
#  return undef if !check_date ($self->{year}, $self->{month}, $self->{day});

  $self;
}

sub valid {
    my $classOrObj = shift;
    my ($y, $m, $d);
    if (ref ($classOrObj)) {
        ($y, $m, $d) = $classOrObj->ymd;
    } else {
        ($y, $m, $d) = @_;
    }
    return undef unless ($y && $m && $d);
    return undef if ($m < 1 or $m > 12 or $d < 1 or $d > 31);
    return check_date ($y, $m, $d);
}

sub openPast {
    my $class = shift;
    my $self = {};
    bless $self, $class;
#    ($self->{year}, $self->{month}, $self->{day}) = (1, 1, 1);
    ($self->{year}, $self->{month}, $self->{day}) = (1970, 1, 1);
    $self;
}

sub openFuture {
    my $class = shift;
    my $self = {};
    bless $self, $class;
#    ($self->{year}, $self->{month}, $self->{day}) = (9999, 12, 31);
    ($self->{year}, $self->{month}, $self->{day}) = (2037, 1, 1);
    $self;
}

# Return the date of the nth day (e.g. Tuesday) in a month. Specifying 5
# for n means the LAST occurence in the month, which may be the fourth.
# Specifying 6 for n means "5th, but only if there is a 5th". (Returns undef
# if there isn't a 5th.)
sub getNthWeekday {
    my $class = shift;
    my ($year, $month, $dayOfWeek, $nthOccurence) = @_;
    my $self = {};
    bless $self, $class;

    my $onlyFifth = $nthOccurence == 6;
    $nthOccurence = 5 if $onlyFifth;

    ($self->{year}, $self->{month}, $self->{day})
        = Nth_Weekday_of_Month_Year ($year, $month, $dayOfWeek, $nthOccurence);

    return undef if ($onlyFifth and !$self->{year});

    # Get the 4th occurrence if we want the last but didn't get it
    if ($nthOccurence == 5 && !$self->{year}) {
        ($self->{year}, $self->{month}, $self->{day})
            = Nth_Weekday_of_Month_Year ($year, $month, $dayOfWeek, 4);
    }
    $self;
}

sub today {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    ($self->{year}, $self->{month}, $self->{day}) = Today();
    $self;
}

sub todayForTimezone {
    my ($class, $offsetHours) = @_;
    my $time = ($offsetHours || 0) * 3600 + time();
    my @date = localtime ($time);
    $class->new ($date[5] + 1900, $date[4] + 1, $date[3]);
}

# Get/Set methods
sub day {
    my $self = shift;
    $self->{day} = shift if (@_);
    $self->{day}+0;
}
sub month {
    my $self = shift;
    $self->{month} = shift if (@_);
    $self->{month}+0;
}
sub year {
    my $self = shift;
    $self->{year} = shift if (@_);
    $self->{year}+0;
}

sub inRange {
    my $self = shift;
    my ($from, $to) = @_;
    return if ($from > $to);
    return if ($self < $from || $self > $to);
    return 1;
}

sub isWeekend {
    my $self = shift;
    return 1 if ($self->dayOfWeek > 5);
}

# rather slow and silly, mind you
sub dayNumber {
    my $self = shift;
    my $dayNum = 0;
    foreach (1..($self->month-1)) {
        $dayNum += Days_in_Month ($self->year, $_);
    }
    $dayNum += $self->day;
}

# First week of year can be determined on 1 of 3 ways:
#    - week containing Jan. 1         type = 1
#    - week w/at least 4 days         type = 4
#    - first 7 day wek                type = 7
# (ISO 8601 says 1st week contains Jan. 4)
# Note that this won't work for days other than Sun., Mon.
sub weekNumber {
    my $self = shift;
    my $type  = shift || 4;
    my $first = shift || 1;    # first d.o.w.; typically  Mon. (1) or Sun. (7)

    # find first FirstDayOfWeek of the year
    my $firstDay = $self->new ($self->year, 1, $type); # 1, 4, or 7
    my $firstFirst = $firstDay->firstOfWeek ($first);

    my $delta = $firstFirst->deltaDays ($self);
    return int (($delta / 7) + 1);
}

# Here are the overloaded ops
sub stringify {
    my ($self, $format) = @_;
    my $sep = '/';
    if ($format and $format eq 'iso8601') {
        $sep = '-';
    }
    $self->year . $sep . $self->month . $sep . $self->day;
}

sub spaceship {
    my ($d1, $d2, $backwards) = @_;
    return $backwards ? ($d2->_toInt() <=> $d1->_toInt())
                      : ($d1->_toInt() <=> $d2->_toInt());
}

sub overloadAdd {
    my ($d1, $d2, $backwards) = @_;
    return $d1->addDaysNew ($d2);
}

sub overloadSubtract {
    my ($d1, $d2, $backwards) = @_;
    return $backwards ? undef : $d1->addDaysNew (-$d2);
}

# If arg[0] isn't a ref to a Date object, just look up arg[1] as a month index
#  (e.g. 3 => March)
# If there is an arg[2], use abbrev. name
# We always return English, so don't bother with Date::Calc
sub monthName {
    my $self = shift;
    my $month = ref($self) ? $self->{'month'} : shift;
    my $abbrev = shift;
    my $name = ('January',   'February', 'March',    'April',
                'May',       'June',     'July',     'August',
                'September', 'October',  'November', 'December')[$month-1];
    return $abbrev ? substr ($name, 0, 3) : $name;
}

# Pass any arg to get the abbreviated name
# If arg[0] isn't a ref to a Date object, just look up arg[1] as a day index
#  (e.g. 1 => Monday)
# If there's another arg, use abbrev. name.
sub dayName {
    my $self = shift;
    my $dayNum = ref($self) ? Day_of_Week ($self->ymd()) : shift;
    my $abbrev = shift;
    my $name = ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday',
                'Saturday', 'Sunday') [$dayNum-1];
    return $abbrev ? substr ($name, 0, 3) : $name;
}

# Return number of days in the specified month
sub daysInMonth {
    my $self = shift;
    Days_in_Month ($self->year(), $self->month);
}

# Return 1 for Monday, 2 for Tuesday, ..., 7 for Sunday
sub dayOfWeek {
    my $self = shift;
    Day_of_Week ($self->ymd()); # Monday = 1, Sunday = 7
}

# Pass a day of week (7, 1-6), it returns a date for the previous occurence
# of that day. (or same day if, e.g. we ask for Monday, and self is a
# Monday).
sub firstOfWeek {
    my $self = shift;
    my $startDay = shift;
    my $weekStart;
    my $delta = $self->dayOfWeek() - $startDay;
    if ($delta >= 0) {
        $weekStart = $self - $delta;
    } else {
        $weekStart = $self - 7 - $delta;
    }
    $weekStart;                 # new Date obj, since overloadSub constructs
}

sub firstOfMonth {
    my $self = shift;
    $self->new ($self->{'year'}, $self->{'month'}, 1);
}

sub ymd {
    my $self = shift;
    ($self->{'year'}, $self->{'month'}, $self->{'day'});
}

sub addDaysNew {
    my $self = shift;
    my $numDays = shift;
    my ($year, $month, $day) = Add_Delta_Days ($self->{'year'},
                                               $self->{'month'},
                                               $self->{'day'}, $numDays);
    $self->new ($year, $month, $day);
}

sub addDays {
    my $self = shift;
    my $numDays = shift;
    ($self->{'year'},
     $self->{'month'},
     $self->{'day'})   = Add_Delta_Days ($self->{'year'},
                                         $self->{'month'},
                                         $self->{'day'}, $numDays);
    $self;
}

sub addYears {
    my $self = shift;
    my $numYears = shift;
    ($self->{'year'},
     $self->{'month'},
     $self->{'day'})   = Add_Delta_YMD ($self->{'year'},
                                        $self->{'month'},
                                        $self->{'day'}, $numYears, 0, 0);
    $self;
}

sub addWeeks {
    my $self = shift;
    my $numWeeks = shift;
    ($self->{'year'},
     $self->{'month'},
     $self->{'day'})   = Add_Delta_Days ($self->{'year'},
                                         $self->{'month'},
                                         $self->{'day'}, $numWeeks * 7);
    $self;
}

sub addMonths {
    my $self = shift;
    my $numMonths = shift;
    ($self->{'year'},
     $self->{'month'},
     $self->{'day'})   = Add_Delta_YMD ($self->{'year'},
                                        $self->{'month'},
                                        $self->{'day'},0, $numMonths, 0);
    $self;
}

# Return num days between two dates.
#   0 if dates are the same
#   positive if self < date2
#   negative if self > date2
sub deltaDays {
    my $self = shift;
    my ($d2) = @_;
    Delta_Days ($self->ymd(), $d2->ymd());
}

# Return num weeks between two dates.
# If the dates are on different days of the week, also pass in an int in
#  range 1-7, which specifies the first day of the week (usually Monday (1)
#  or Sunday (7). The delta will then be computed between the first day of
#  the week each date is in. (So, the delta for Friday the 1st and Tuesday
#  the 12th will be correctly returned as 2, not 1.)
# Returns 0 if dates are in same week.
# (positive if self < date2, negative if self > date2)
sub deltaWeeks {
    my $self = shift;
    my ($d2, $firstOfWeek) = @_;
    my $fracDelta = (Delta_Days ($self->ymd(), $d2->ymd())) / 7;
    my $deltaWeeks = int ($fracDelta);
    return $deltaWeeks if ($deltaWeeks == $fracDelta); # same day of week

# This doesn't work; $self in firstOfWeek loses op overloading? Very odd.
#    my $selfFirst = $self->firstOfWeek ($firstOfWeek);
#    my $d2First = $d2->firstOfWeek ($firstOfWeek);
    my $selfFirst = $self->new ($self)->firstOfWeek ($firstOfWeek);
    my $d2First   = $self->new ($d2)->firstOfWeek ($firstOfWeek);
    return (Delta_Days ($selfFirst->ymd(), $d2First->ymd())) / 7;
}

# Return num months between two dates.
#   0 if dates are in same month,
#   positive if self < date2
#   negative if self > date2
# Note that 1999/11/01 and 1999/11/31 produce a delta of 0
# Assumes there are 12 months in every year, which I believe is true, no?
sub deltaMonths {
    my $self = shift;
    my ($d2) = @_;
    return (12 * $d2->year() + $d2->month()) -
           (12 * $self->{'year'} + $self->{'month'});
}

# Return difference in the year portion of two dates.
#   0 if years are the same
#   positive if self < date2
#   negative if self > date2
# Note that 1999/02/01 and 1999/11/31 produce a delta of 0
sub deltaYears {
    my $self = shift;
    my ($d2) = @_;
    return ($d2->year() - $self->{'year'});
}

# Note that Date_to_Days will probably return # of secs since epoch if
# we're not actually using Date::Calc
{
my %cache;
sub _toInt {
    my $self = shift;
    my $key = join $;, ($self->{'year'}, $self->{'month'}, $self->{'day'});
    return $cache{$key} if (exists $cache{$key});
    $cache{$key} =
        Date_to_Days ($self->{'year'}, $self->{'month'}, $self->{'day'});
}
}

# Call via object: $date->pretty ($i18n)
# Return string like "Monday, September 28, 2002"
#    (or "Sept. 28" if $fmt = 'abbrev';)
sub pretty {
    my ($self, $i18n, $fmt) = @_;
    $fmt ||= '';
    my $dayName   = $i18n->get ($self->dayName);
    my $monthName = $i18n->get ($self->monthName ($fmt eq 'abbrev'));

    if ($i18n->getLanguage ne 'English') {
        return $self->day . " $monthName" if ($fmt eq 'abbrev');
        return "$dayName, " . $self->day . " $monthName  " . $self->year;
    } else {
        return "$monthName " . $self->day if ($fmt eq 'abbrev');
        return "$dayName, $monthName " . $self->day . ' ' . $self->year;
    }
}

# Return new Date of first day of the quarter self is in.
# Qs are [J,F,M],[A,M,J],[J,A,S],[O,N,D]
# Pass arg to get 1st, 2nd, 3rd, or 4th Quarter of year self is in.
sub startOfQuarter {
    my ($self, $which) = @_;
    my $month;
    if ($which) {
        $which = 4 if $which > 4;
        $which = 1 if $which < 1;
        $month = ($which - 1) * 3 + 1;
    } else {
        $month = (1,1,1,1,4,4,4,7,7,7,10,10,10)[$self->month];
    }
    return $self->new ($self->year, $month, 1);
}
sub endOfQuarter {
    my ($self, $which) = @_;
    my $start = $self->startOfQuarter ($which);
    my $nextQ = $start->addMonths (3);
    return $nextQ - 1;
}
# Quarters always 3 months
sub addQuarters {
    my ($self, $numQuarters) = @_;
    $self->addMonths ($numQuarters * 3);
}

# Return int in range 1..4
sub quarterNumber {
    my ($self) = @_;
    return int (($self->month - 1) / 3) + 1;
}

# Return something like "3rd Quarter"
# If 'includeYear' param, it's something like "2nd Quarter, 2003"
sub quarterName {
    my ($self, $i18n, $includeYear) = @_;
    my $quarter = $self->quarterNumber;
    my $name = $i18n->get ((qw /First First Second Third Fourth/)[$quarter]) .
               ' ' . $i18n->get ('Quarter');
    $name .= ' ' . $self->year if ($includeYear);
    return $name;
}

1;
