# Copyright 2002-2006, Fred Steinberg, Brown Bear Software

package Subscribe;
use strict;

sub removeFromAll {
    my ($prefs, @addrs) = @_;
    return unless $prefs;
    my $all = [$prefs->getRemindAllAddresses];
    foreach (@addrs) {
        $all = _removeFromList ($all, $_);
    }
    $prefs->setRemindAllAddresses (@$all);
}

sub removeFromCategory {
    my ($prefs, $addrs, $notThese) = @_;
    return unless $prefs;
    my $catHash = $prefs->getRemindByCategory;

    my %leaveIt = $notThese ? map {$_ => 1} @$notThese : ();

    foreach my $cat (keys %$catHash) {
        next if $leaveIt{$cat};
        my $adders = $catHash->{$cat} || [];
        foreach (@$addrs) {
            $catHash->{$cat} = $adders = _removeFromList ($adders, $_);
        }
    }
    $prefs->setRemindByCategory ($catHash);
}

# Remove one or more addresses from 'all' list, from category lists, and
# from all individual events.
# Slow.
sub removeCompletely {
    my ($db, $prefs, @addrs) = @_;
    removeFromAll ($prefs, @addrs);
    removeFromCategory ($prefs, \@addrs);

    my $repList = $db->getAllRepeatingEvents;
    foreach my $event (@$repList) {
        my $subs = $event->getSubscribers ($db->name);
        next unless $subs;
        my $list = [split /,/, $subs];
        foreach my $adr (@addrs) {
            $list = _removeFromList ($list, $adr);
        }

        my $newSubs = join ',', @$list;
        if ($newSubs ne $subs) {
            $event->subscriptions ($newSubs);
            $db->replaceEvent ($event);
        }
    }

    my $regHash = $db->getAllRegularEvents;
    foreach my $date (keys %$regHash) {
        foreach my $event (@{$regHash->{$date}}) {
            my $subs = $event->subscriptions || '';
            next unless $subs;
            my $list = [split /[\s,]/, $subs];
            foreach my $address (@addrs) {
                $list = _removeFromList ($list, $address);
            }
            my $newSubs = join ',', @$list;
            if ($newSubs ne $subs) {
                $event->subscriptions ($newSubs);
                $db->replaceEvent ($event, $date);
            }
        }
    }
}

sub _removeFromList {
    my ($list, $removeMe) = @_;
    my @addrs = grep {lc($_) ne lc($removeMe)} @$list;
    return \@addrs;
}

1;
