-- Add currency field to expenses table for per-record currency tracking
alter table public.expenses add column if not exists currency text not null default '¥';

-- Update RLS policies to include the new column (existing policies already cover all columns)
