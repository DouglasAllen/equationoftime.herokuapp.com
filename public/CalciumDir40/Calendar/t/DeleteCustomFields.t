#!/usr/bin/perl

use strict;
use warnings;

BEGIN {$Defines::calendar_root = '/Users/fred/Calcium/3.eleven/CalciumDir311';}
use lib "$Defines::calendar_root";
use lib "$Defines::calendar_root/redist";
use lib "$Defines::calendar_root/upgrades";

use lib '../..';
use Calendar::CustomField;
use Calendar::Database;
use Calendar::MasterDB;

my $cal_name = 'CustomFieldTest';

# Delete custom fields

my $db    = Database->new ($cal_name);
my $prefs = $db->getPreferences;

my $fields_lr = $prefs->get_custom_fields (system => undef,
                                           keys   => 'name');

foreach my $field (@$fields_lr) {
    my ($name, $id) = ($field->name, $field->id);
    print "Delete field '$name' ($id)? \n";
    my $yes_or_no = <>;
    if ($yes_or_no =~ /^y/) {
        $prefs->delete_custom_field ($field);
        print "Deleted.\n\n";
    }
    else {
        print "Kept.\n\n";
    }
}

$db->setPreferences ($prefs);
