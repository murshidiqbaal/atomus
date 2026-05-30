-- Alter parents table to include secondary/emergency contact fields
ALTER TABLE public.parents 
ADD COLUMN IF NOT EXISTS secondary_contact_name text,
ADD COLUMN IF NOT EXISTS secondary_contact_phone text,
ADD COLUMN IF NOT EXISTS secondary_contact_email text,
ADD COLUMN IF NOT EXISTS secondary_contact_relationship text;

-- Alter students table to include medical, safety, and dob fields
ALTER TABLE public.students 
ADD COLUMN IF NOT EXISTS blood_group text,
ADD COLUMN IF NOT EXISTS allergies text,
ADD COLUMN IF NOT EXISTS medical_conditions text,
ADD COLUMN IF NOT EXISTS dob date;

-- Seed parent emergency contact details for existing parents
UPDATE public.parents
SET 
  secondary_contact_name = 'Sarah Smith',
  secondary_contact_phone = '+15550199',
  secondary_contact_email = 'sarah.smith@example.com',
  secondary_contact_relationship = 'Mother'
WHERE id = 'c0a6d959-1420-4ab7-be7b-a5daf3c2d053';

UPDATE public.parents
SET 
  secondary_contact_name = 'Manoj Kumar',
  secondary_contact_phone = '+918547821995',
  secondary_contact_email = 'manoj.kumar@example.com',
  secondary_contact_relationship = 'Father'
WHERE id = 'bc484262-5571-4546-84c7-cdbdbd1ffb7e';

-- Seed student medical, safety, and DOB details for existing students
UPDATE public.students
SET 
  blood_group = 'A+',
  allergies = 'Penicillin',
  medical_conditions = 'Mild Asthma',
  dob = '2008-04-12'
WHERE id = '59a0e20d-039e-464d-982c-e5161bd96a64';

UPDATE public.students
SET 
  blood_group = 'O+',
  allergies = 'None',
  medical_conditions = 'None',
  dob = '2007-09-15'
WHERE id = 'd978fb66-f456-465e-93c8-af644d22db0b';

