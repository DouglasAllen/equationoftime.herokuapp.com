# Copyright 1999-2006, Fred Steinberg, Brown Bear Software

# Filter out Events that shouldn't be displayed
# E.g.
#     Tentative events  (if we shouldn't see them)
#     Private events    (if we shouldn't see them)
#     Not in specified Category or matching Text (via params supplied to op)

package DisplayFilter;
use strict;

# Pass operation
sub new {
    my $class = shift;
    my %self = (operation => undef,
                _canEdit  => {},     # map cal name to 'edit' perm
                @_);
    if ($self{operation}) {
        $self{prefs} = $self{operation}->prefs;
    }
    bless \%self, $class;
}

# Planner views can need different prefs for each calendar, oy.
sub prefs {
    my ($self, $prefs_obj) = @_;
    $self->{prefs} = $prefs_obj if $prefs_obj;
    return $self->{prefs};
}

# Pass ref to list of events; return a list of kept events.
sub filterTentative {
    my ($self, $events) = @_;

    my @keepers;
    my $calName = $self->{operation}->calendarName;

    # See who is allowed to view Tentatives
    my $tentViewers = $self->{operation}->prefs->TentativeViewers || 'edit';

    return @$events if (lc ($tentViewers) eq 'all');

    my $username = $self->{operation}->getUsername || ' anon ';

    my $ownerView = ($tentViewers =~ /owner/i);
    my $editors   = ($tentViewers =~ /edit/i);
    my $admins    = ($tentViewers =~ /admin/i);

    foreach (@$events) {
        if (!$_->isTentative) {
            push @keepers, $_;
            next;
        }
        if ($ownerView and ((!$_->owner) or $_->owner eq $username)) {
            push @keepers, $_;
            next;
        }
        # _canEdit, _canAdmin play tricks with op->calName for Planner view
        if ($editors) {
            my $cal = $_->includedFrom || $calName;
            if (!exists $self->{_canEdit}->{$cal}) {
                $self->{_canEdit}->{$cal} =
                  $self->{operation}->permission->permitted ($username, 'Edit');
            }
            if ($self->{_canEdit}->{$cal}) {
                push @keepers, $_;
                next;
            }
        }
        if ($admins) {
            my $cal = $_->includedFrom || $calName;
            if (!exists $self->{_canAdmin}->{$cal}) {
                $self->{_canAdmin}->{$cal} =
                 $self->{operation}->permission->permitted ($username, 'Admin');
            }
            if ($self->{_canAdmin}->{$cal}) {
                push @keepers, $_;
                next;
            }
        }
    }
    return @keepers;
}

# Pass ref to list of events; return a list of kept events.
#  (And/or set disposition flag on some kept events)
sub filterPrivate {
    my ($self, $events) = @_;

    my @keepers;
    my $calName = $self->{operation}->calendarName;

    # See who is allowed to view Private Events and/or Popup/Details
    my $owner_only   = $self->{prefs}->PrivacyOwner;
    my $do_include   = !$self->{prefs}->PrivacyNoInclude;
    my $hide_details = $self->{prefs}->HideDetails;

    # If not enforcing any privacy, just return all events
    return @$events if (!$owner_only and !$do_include and !$hide_details);

    my $username = $self->{operation}->getUsername || ' anon ';

    foreach my $event (@$events) {

        # If hiding details and we don't have "Edit" perm...keep track
        if ($hide_details) {
            my $cal = $event->includedFrom || $calName;
            if (!exists $self->{_canEdit}->{$cal}) {
                $self->{_canEdit}->{$cal} =
                  $self->{operation}->permission->permitted ($username, 'Edit');
            }
            if (!$self->{_canEdit}->{$cal}) {
                $event->hide_details (1);
            }
        }

        # public events always included
        if ($event->public) {
            push @keepers, $event;
            next;
        }

        # if either included or not event owner (and assuming we care,
        # depending on prefs) then...
        if (   ($do_include and $event->includedFrom)
            or ($owner_only and $event->owner
                            and ($event->owner ne $username))) {

            # ...skip "private" events completely
            if ($event->private) {
                next;
            }

            # or, remember to use special string/disposition when displaying
            $event->display_privacy_string (1);
        }

        push @keepers, $event;
    }
    return @keepers;
}

# Maybe match against Category and/or Text
sub filter_from_params {
    my ($self, $events) = @_;
    my ($categories, $text, $filter_in) = $self->{operation}->ParseFilterSpecs;
    if (!$categories and !$text) {
        return @$events;
    }
    my @keepers;
    foreach my $event (@$events) {
        next unless defined $event;     # shouldn't be needed, but.
        if ($categories) {
            next unless $event->inCategory ($categories);
        }
        if ($text) {
            next unless $event->matchesText ($text, $filter_in);
        }
        push @keepers, $event;
    }
    return @keepers;
}

1;
