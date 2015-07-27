# Copyright 2005-2006, Fred Steinberg, Brown Bear Software
# Spit out an RSS file for a calendar
use strict;
use warnings;
package RSS;

use vars ('@ISA');
@ISA = ('Operation');

use Calendar::Date;
use Calendar::DisplayFilter;

sub perform {
    my $self = shift;

    my $cal_name = $self->calendarName;
    my $db       = $self->db;

    unless ($cal_name) {
        GetHTML->errorPage ($self->I18N,
                            message => $self->I18N->get
                              ("Calendar required - use 'CalendarName' param"));
    }

    my ($format, $days_in_advance) = $self->getParams (qw (Format Days));
    $days_in_advance ||= 30;       # how many days in advance to get events for

    if (!$format =~ /^(atom|rss|rdf|0.9|0.91|1.0|2.0)$/i) {
        $format = '';           # use XML::RSS default
    }

    my $rss = RSS::generic->new ($format); # see package below

    # Get event instances, sorted by epoch
    my @events = get_upcoming_events (calendar => $db,
                                      days     => $days_in_advance,
                                      prefs    => $self->prefs);
    # Remove events we shouldn't see
    my $filter = DisplayFilter->new (operation => $self);
    @events = $filter->filterTentative (\@events);
    @events = $filter->filterPrivate (\@events);
    @events = $filter->filter_from_params (\@events);

    # And sort on date & time
    @events = map {$_->[0]}
                 sort {$a->[1] <=> $b->[1] or $a->[2] <=> $b->[2]}
                     map {[$_, $_->Date, $_->startTime || -1]}
               @events;

    $rss->channel (title       => "$cal_name calendar events",
                   link        => $self->makeURL ({FullURL => 1}),
                   description => $db->description
                                 || 'Brown Bear Software Calcium Web Calendar');

    my $i18n = $self->I18N;

    my $template;
    if (Defines->has_feature ('custom fields')) {
        require Calendar::Template;
        $template = Template->new (name     => 'RSS',
                                   cal_name => $cal_name,
                                   convert_newlines => 1);
    }

    foreach my $event (@events) {
        my $date = $event->Date;
        my $link = $self->makeURL ({FullURL => 1,
                                    Date    => $date,
                                    EventID => $event->id});
        my $text        = $event->text;
        my $description = $event->popup || $event->link || '';
        if (my $custom_html =
            $event->custom_fields_display (template => $template,
                                           prefs    => $self->prefs,
                                           escape   => undef,
                                           format   => 'text')) {
            $description .= "\n$custom_html";
        }

        if ($event->hide_details) {
            undef $description;
        }
        if ($event->display_privacy_string) {
            undef $description;
            if (!$event->privatePopup) {
                $text = $event->displayString ($i18n);
            }
        }
        $rss->add_item (title       => $date->pretty ($i18n, 'abbrev')
                                       . ' - ' . $text,
                        link        => $link,
                        description => $description,
                        date        => $date); # Date obj
    }

    print "Content-Type: text/xml;charset=utf-8\n\n";
    print $rss->as_string;
    return 1;
}

# ---------------------------------

# Return list of events
# Pass hash w/args:
#  days - number of days worth of events to get
sub get_upcoming_events {
    my %args = (days     => 1,
                calendar => undef, # a Database object
                prefs    => undef,
                @_);
    my $calendar = $args{calendar};
    my $days     = $args{days};
    my $prefs    = $args{prefs};

    my $from = Date->today;
    my $to   = $from->addDaysNew ($days);

    my @events = $calendar->get_instances_in_range ($from, $to, $prefs);
    return @events;
}


# ----------------------------------------


package RSS::generic;
sub new {
    my ($class, $format) = @_;
    if (!$format or $format =~ /^(0.9|0.91|1.0|2.0)$/) {
        return RSS::generic::XMLRSS->new ($format);
    }
    elsif ($format =~ /^(atom|rss|rdf)$/i) {
        return RSS::generic::FeedPP->new ($format);
    }
    else {
        return RSS::generic::XMLRSS->new;   # default
    }
    die "unknown RSS format: $format\n";
}

# --------
package RSS::generic::XMLRSS;
use base 'RSS::generic';
sub new {
    my ($class, $format) = @_;
    require XML::RSS;
    my %args;
    $args{version} = $format if ($format);
    my %self = (rss => XML::RSS->new (%args));
    return bless \%self, $class;
}
sub channel {
    my ($self, %args) = @_;
    $self->{rss}->channel (%args);
    return $self;
}
sub add_item {
    my ($self, %args) = @_;
    $args{dc} = {date => $args{date}->stringify ('iso8601')};
    delete $args{date};
    return $self->{rss}->add_item (%args);
}
sub as_string {
    my $self = shift;
    return $self->{rss}->as_string;
}

# --------
package RSS::generic::FeedPP;
use base 'RSS::generic';
sub new {
    my ($class, $format) = @_;
    require XML::FeedPP;
    my $rss;
    if (lc $format eq 'atom') {
        $rss = XML::FeedPP::Atom->new;
    }
    elsif (lc $format eq 'rss') {
        $rss = XML::FeedPP::RSS->new;
    }
    elsif (lc $format eq 'rdf') {
        $rss = XML::FeedPP::RDF->new;
    }
    else {
        die "unknown FeedPP RSS format: $format\n";
    }
    return bless {rss => $rss}, $class;
}
sub channel {
    my ($self, %args) = @_;
    $args{link}        && $self->{rss}->link        ($args{link});
    $args{description} && $self->{rss}->description ($args{description});
    $args{title}       && $self->{rss}->title       ($args{title});
    return $self;
}

sub add_item {
    my ($self, %args) = @_;
    return unless $args{link};
    my $item = $self->{rss}->add_item ($args{link});
    $args{description} && $item->description($args{description});
    $args{title}       && $item->title      ($args{title});
    $args{date}        && $item->pubDate    ($args{date}->stringify ('iso8601'));
    return $item;
}

sub as_string {
    my $self = shift;
    return $self->{rss}->to_string;
}

1;
