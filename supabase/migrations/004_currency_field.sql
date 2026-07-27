-- Add currency field to records table for per-record currency tracking
alter table public.records add column if not exists currency text not null default '¥';
