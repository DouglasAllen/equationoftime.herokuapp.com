#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 50;

BEGIN {$Defines::calendar_root = '/Users/fred/Calcium/3.eleven/CalciumDir311';}
use lib "$Defines::calendar_root";
use lib "$Defines::calendar_root/redist";
use lib "$Defines::calendar_root/upgrades";

use lib '../..';
use Calendar::CustomField;
use Calendar::Database;
use Calendar::MasterDB;

my $cal_name = 'CustomFieldTest';

# Make CustomField add to "CustomFieldTest" calendar

my @fields;
push @fields, CustomField->new (name       => 'Text Field',
                                input_type => 'textfield',
                                default    => 'hello - test',
                                required   => 1,
                                cols       => 20,
                                max_size   => 20,
                                label      => 'Text Field: ');
push @fields, CustomField->new (name       => 'Text Area',
                                input_type => 'textarea',
                                default    => "hello - test\nline two",
                                required   => 1,
                                cols       => 25,
                                rows       => 5,
                                label      => 'Text Area: ');
push @fields, CustomField->new (name       => 'Single Select',
                                input_type => 'select',
                                default    => 'third',
                              input_values => [qw /first second third fourth/],
                                required   => 1,
                                label      => 'Pick One: ');
push @fields, CustomField->new (name         => 'Multi Select',
                                input_type   => 'multiselect',
                                default      => [qw /third fourth ninth/],
                                input_values => [qw /first second third
                                                     fourth fifth sixth
                                                     seventh eighth ninth/],
                                max_size     => 6,
                                required     => 1,
                                label        => 'Pick Many: ');
push @fields, CustomField->new (name       => 'Checkbox',
                                input_type => 'checkbox',
                                default    => 1,
                                required   => 1,
                                label      => 'Yes/No: ');

# Add to preferences
my $db    = Database->new ($cal_name);
my $prefs = $db->getPreferences;

foreach my $field (@fields) {
    $prefs->new_custom_field ($field);
    my $id = $field->id;
    ok ($id > 0, 'id created by new_custom_field()');
}

my $field = $fields[0];
my $id    = $field->id;

$db->setPreferences ($prefs);

# Just append new IDs to field order
my $order = $prefs->CustomFieldOrder || '';
my (@id_order) = split /,/, $order;
push @id_order, map {$_->id} @fields;
$db->setPreferences ({CustomFieldOrder => join (',', @id_order)});

$order = $prefs->CustomFieldOrder;
print "Order now: $order\n";
