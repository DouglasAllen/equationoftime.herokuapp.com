# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

package Title;
use strict;

sub new {
  my $class = shift;
  my ($operation, $amount, $type, $startDate, $endDate) = @_;
  my $self = {};
  bless $self, $class;

  my $title;

  my $prefs = $operation->prefs;
  my $i18n  = $operation->I18N;

  my $comma = ' ';              # change to ', ' if you do want a comma

  # If condensed, always show something like "1 Jan 1999 - 28 Feb 1999"
  if ($type =~ /condensed/i) {
      $title = $startDate->day . ' ' . $i18n->get ($startDate->monthName)
               . ' ' . $startDate->year . ' - '
               . $endDate->day . ' ' . $i18n->get ($endDate->monthName)
               . ' ' . $endDate->year;
  # If Approval, no dates a'tall
  } elsif ($type =~ /approv/i) {
      $title = $i18n->get ('Events Pending Approval');
  } elsif ($amount =~ /year/i) {
      if ($amount !~ /fyear/i) {
          $title = $startDate->year;
      } else {
          my $start = $startDate->startOfYear;
          my $end   = $start + 364;
          if ($start->year eq $end->year) {
              $title = $start->year;
          } else {
              $title = $start->year . ' / ' . $end->year;
          }
      }
  } elsif ($amount =~ /day/i) {
      # just use the date
      $title = $startDate->day . ' ' . $i18n->get ($startDate->monthName) .
               ' ' . $startDate->year . '<br>' .
               $i18n->get ($startDate->dayName);
  } elsif ($amount =~ /week/i) {
      # If > 1 month visible, use something like "March/April, 1999"
      if ($startDate->month != $endDate->month) {
          my $start = $i18n->get ($startDate->monthName) .
                     ($startDate->year == $endDate->year ? ''
                         : $comma . $startDate->year);
          $title = $start . '/' . $i18n->get ($endDate->monthName) . $comma .
                   $endDate->year;
      } else {
          $title = $i18n->get ($endDate->monthName) . $comma . $endDate->year;
      }
  } elsif ($amount =~ /period/i) {
      $title = $startDate->periodName ($i18n, 'year'); # must be Date::Fiscal
  } elsif ($amount =~ /quarter/i) {
      $title = $startDate->quarterName ($i18n, 'year');
  } else {  # Month View
      # If the 1st of the month is in the first week, just use that month.
      # Otherwise, use something like "April/May, 1999"
      if ($startDate->day <= 7) {
          $title = $i18n->get($startDate->monthName) . $comma .
                                                          $startDate->year();
      } else {
          my $start = $i18n->get ($startDate->monthName) .
                             ($startDate->year == $endDate->year ? ''
                                 : $comma . $startDate->year);
          $title = $start . '/' . $i18n->get ($endDate->monthName) . $comma .
                   $endDate->year;
      }
  }

  $self->{html} = <<END_HTML;
    <table width="100%" align=center><tr align=center>
    <td align="left" class="DateHeader"><small><small>
       <a href=http://www.brownbearsw.com><nobr>Brown Bear Software</nobr</a>
       </small></small></td>
    <td class="DateHeader">$title</td>
    <td align="right" class="DateHeader"><small><small>
       <a href=http://www.brownbearsw.com><nobr>Brown Bear Software</nobr></a>
       </small></small></td>
    </tr></table>
END_HTML
  $self;
}

sub getHTML {
  my $self = shift;
  return qq (<div class="DateHeader">$self->{html}</div>);
}

sub cssDefaults {
    my ($self, $prefs) = @_;

    my $css;

    my $fg = $prefs->color ('MainPageFG') || 'black';
    my ($face, $size) = $prefs->font ('MonthYear');
    $size ||= '+3';
    $css .= Operation->cssString ('.DateHeader', {color => $fg,
                                                  'font-size'   => $size,
                                                  'font-family' => $face,
                                                  'font-weight' => 'bold',
                                                  'text-align'  => 'center'});
    $css;
}

1;
