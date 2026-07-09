begin;

alter table public.publications
  add column mux_asset_id text unique;

alter table public.moderation_jobs
  drop constraint moderation_jobs_subject_user_id_fkey;

alter table public.moderation_jobs
  add constraint moderation_jobs_subject_user_id_fkey
  foreign key (subject_user_id) references auth.users(id) on delete set null;

create unique index moderation_jobs_account_deletion_user_idx
on public.moderation_jobs(subject_user_id)
where kind = 'account_deletion' and subject_user_id is not null;

commit;
