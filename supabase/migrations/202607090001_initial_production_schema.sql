begin;

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'moderator'),
    false
  );
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username extensions.citext unique,
  display_name text not null default '',
  bio text not null default '' check (char_length(bio) <= 500),
  avatar_path text,
  external_url text,
  is_teen boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint teen_has_no_external_url check (not is_teen or external_url is null)
);

create table public.user_safety (
  user_id uuid primary key references auth.users(id) on delete cascade,
  age_band text not null default 'unknown' check (age_band in ('unknown', 'teen', 'adult')),
  community_eligible boolean not null default false,
  requires_manual_review boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.devices (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('ios')),
  apns_token text not null unique,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index devices_owner_id_idx on public.devices(owner_id);

create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  challenge_reminders boolean not null default false,
  comment_notifications boolean not null default false,
  moderation_updates boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  template_id text not null,
  template_schema_version integer not null check (template_schema_version > 0),
  title text not null check (char_length(title) <= 200),
  revision integer not null default 0 check (revision >= 0),
  sync_enabled boolean not null default false,
  local_created_at timestamptz not null,
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index projects_owner_updated_idx on public.projects(owner_id, updated_at desc);

create table public.project_shots (
  id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  template_shot_id text not null,
  position integer not null check (position >= 0),
  target_seconds integer,
  completed boolean not null default false,
  revision integer not null default 0 check (revision >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, template_shot_id),
  unique (project_id, position)
);

create index project_shots_owner_idx on public.project_shots(owner_id, project_id);

create table public.media_assets (
  id uuid primary key,
  project_id uuid not null references public.projects(id) on delete cascade,
  shot_id uuid references public.project_shots(id) on delete set null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  storage_path text not null,
  checksum_sha256 text not null check (checksum_sha256 ~ '^[a-f0-9]{64}$'),
  byte_count bigint not null check (byte_count >= 0),
  content_type text not null check (content_type in ('video/mp4', 'video/quicktime', 'audio/mp4', 'audio/x-m4a')),
  duration_seconds numeric check (duration_seconds is null or duration_seconds > 0),
  upload_state text not null default 'pending' check (upload_state in ('pending', 'uploading', 'uploaded', 'failed', 'deleted')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, storage_path)
);

create index media_assets_owner_project_idx on public.media_assets(owner_id, project_id);

create table public.sync_operations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key uuid not null,
  operation text not null,
  request_hash text not null check (request_hash ~ '^[a-f0-9]{64}$'),
  status text not null check (status in ('processing', 'completed', 'failed')),
  response jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (owner_id, idempotency_key, operation)
);

create index sync_operations_owner_created_idx on public.sync_operations(owner_id, created_at desc);

create table public.challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(title) between 1 and 150),
  prompt text not null check (char_length(prompt) between 1 and 1000),
  template_id text not null,
  cadence text not null check (cadence in ('daily', 'weekly')),
  status text not null default 'draft' check (status in ('draft', 'active', 'ended', 'archived')),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);

create index challenges_status_dates_idx on public.challenges(status, starts_at, ends_at);

create table public.publications (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  challenge_id uuid references public.challenges(id) on delete set null,
  published_asset_id uuid references public.media_assets(id) on delete set null,
  visibility text not null check (visibility in ('private', 'unlisted', 'public')),
  moderation_status text not null default 'draft' check (moderation_status in ('draft', 'pending_review', 'approved', 'rejected', 'removed')),
  processing_status text not null default 'pending' check (processing_status in ('pending', 'uploading', 'processing', 'ready', 'failed')),
  caption text not null default '' check (char_length(caption) <= 500),
  comments_enabled boolean not null default true,
  mux_upload_id text unique,
  mux_playback_id text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id)
);

create index publications_discovery_idx on public.publications(challenge_id, created_at desc)
where visibility = 'public' and moderation_status = 'approved';
create index publications_owner_idx on public.publications(owner_id, created_at desc);

create table public.challenge_submissions (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenges(id) on delete cascade,
  publication_id uuid not null references public.publications(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (challenge_id, publication_id),
  unique (challenge_id, owner_id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  publication_id uuid not null references public.publications(id) on delete cascade,
  author_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(body) between 0 and 1000),
  feedback_prompt_id text,
  moderation_status text not null default 'approved' check (moderation_status in ('pending_review', 'approved', 'rejected', 'removed')),
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create index comments_publication_created_idx on public.comments(publication_id, created_at);
create index comments_author_idx on public.comments(author_id);

create table public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index blocks_blocked_id_idx on public.blocks(blocked_id, blocker_id);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  publication_id uuid references public.publications(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  reason text not null check (reason in ('harassment', 'hate', 'sexual_content', 'violence', 'self_harm', 'privacy', 'spam', 'other')),
  status text not null default 'open' check (status in ('open', 'reviewing', 'actioned', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(publication_id, comment_id) = 1)
);

create index reports_status_created_idx on public.reports(status, created_at);

create table public.moderation_jobs (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('publication_review', 'comment_review', 'account_deletion', 'appeal')),
  status text not null default 'queued' check (status in ('queued', 'processing', 'manual_review', 'awaiting_external_cleanup', 'completed', 'failed')),
  publication_id uuid references public.publications(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  report_id uuid references public.reports(id) on delete cascade,
  subject_user_id uuid references auth.users(id) on delete cascade,
  failure_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index moderation_jobs_publication_kind_idx
on public.moderation_jobs(kind, publication_id) where publication_id is not null;
create index moderation_jobs_queue_idx on public.moderation_jobs(status, created_at);

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  moderator_id uuid not null references auth.users(id) on delete restrict,
  publication_id uuid references public.publications(id) on delete set null,
  comment_id uuid references public.comments(id) on delete set null,
  report_id uuid references public.reports(id) on delete set null,
  action text not null check (action in ('approved', 'rejected', 'removed', 'restored', 'warned', 'suspended', 'dismissed')),
  reason_code text not null check (char_length(reason_code) between 1 and 100),
  evidence_path text,
  created_at timestamptz not null default now(),
  check (num_nonnulls(publication_id, comment_id, report_id) >= 1)
);

create index moderation_actions_created_idx on public.moderation_actions(created_at desc);

create table public.critique_requests (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  consented_at timestamptz not null,
  status text not null default 'queued' check (status in ('queued', 'processing', 'completed', 'failed', 'provider_unconfigured')),
  frame_count integer check (frame_count is null or frame_count between 0 and 24),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index critique_requests_owner_idx on public.critique_requests(owner_id, created_at desc);

create table public.critique_results (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique references public.critique_requests(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  project_id uuid not null references public.projects(id) on delete cascade,
  result jsonb not null,
  model_snapshot text not null,
  created_at timestamptz not null default now()
);

create table public.feature_flags (
  key text primary key,
  enabled boolean not null default false,
  rollout_percentage integer not null default 0 check (rollout_percentage between 0 and 100),
  configuration jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

insert into public.feature_flags (key, enabled, rollout_percentage) values
  ('community', false, 0),
  ('ai_coach', false, 0)
on conflict (key) do nothing;

create table public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  device_id uuid,
  name text not null check (char_length(name) between 1 and 100),
  properties jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (not (properties ?| array['filename', 'prompt', 'caption', 'comment', 'media_url', 'freeform']))
);

create index analytics_events_name_occurred_idx on public.analytics_events(name, occurred_at desc);

create or replace function public.is_blocked_with(other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.blocks b
    where (b.blocker_id = (select auth.uid()) and b.blocked_id = other_user_id)
       or (b.blocker_id = other_user_id and b.blocked_id = (select auth.uid()))
  );
$$;

create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger user_safety_set_updated_at before update on public.user_safety for each row execute function public.set_updated_at();
create trigger projects_set_updated_at before update on public.projects for each row execute function public.set_updated_at();
create trigger project_shots_set_updated_at before update on public.project_shots for each row execute function public.set_updated_at();
create trigger media_assets_set_updated_at before update on public.media_assets for each row execute function public.set_updated_at();
create trigger challenges_set_updated_at before update on public.challenges for each row execute function public.set_updated_at();
create trigger publications_set_updated_at before update on public.publications for each row execute function public.set_updated_at();
create trigger reports_set_updated_at before update on public.reports for each row execute function public.set_updated_at();
create trigger moderation_jobs_set_updated_at before update on public.moderation_jobs for each row execute function public.set_updated_at();
create trigger critique_requests_set_updated_at before update on public.critique_requests for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_age_band text := coalesce(new.raw_user_meta_data ->> 'age_band', 'unknown');
begin
  if requested_age_band = 'under_13' then
    raise exception 'Accounts are available only to people age 13 or older';
  end if;
  if requested_age_band not in ('teen', 'adult') then
    requested_age_band := 'unknown';
  end if;
  insert into public.profiles (id, display_name, is_teen)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''), requested_age_band = 'teen');
  insert into public.user_safety (user_id, age_band, community_eligible, requires_manual_review)
  values (new.id, requested_age_band, requested_age_band in ('teen', 'adult'), requested_age_band <> 'adult');
  insert into public.notification_preferences (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.user_safety enable row level security;
alter table public.devices enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.projects enable row level security;
alter table public.project_shots enable row level security;
alter table public.media_assets enable row level security;
alter table public.sync_operations enable row level security;
alter table public.challenges enable row level security;
alter table public.publications enable row level security;
alter table public.challenge_submissions enable row level security;
alter table public.comments enable row level security;
alter table public.blocks enable row level security;
alter table public.reports enable row level security;
alter table public.moderation_jobs enable row level security;
alter table public.moderation_actions enable row level security;
alter table public.critique_requests enable row level security;
alter table public.critique_results enable row level security;
alter table public.feature_flags enable row level security;
alter table public.analytics_events enable row level security;

create policy profiles_select on public.profiles for select to authenticated
using (
  id = (select auth.uid())
  or not (select public.is_blocked_with(profiles.id))
);
create policy profiles_update_own on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy user_safety_select_own on public.user_safety for select to authenticated
using (user_id = (select auth.uid()));
create policy user_safety_admin_all on public.user_safety for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy devices_owner_all on public.devices for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy notification_preferences_owner_all on public.notification_preferences for all to authenticated
using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy projects_owner_all on public.projects for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy project_shots_owner_all on public.project_shots for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy media_assets_owner_all on public.media_assets for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy sync_operations_owner_select on public.sync_operations for select to authenticated
using (owner_id = (select auth.uid()));

create policy challenges_active_select on public.challenges for select to authenticated
using (status = 'active' and starts_at <= now() and ends_at > now());
create policy challenges_admin_all on public.challenges for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy publications_owner_all on public.publications for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy publications_approved_public_select on public.publications for select to authenticated
using (
  visibility = 'public' and moderation_status = 'approved'
  and not (select public.is_blocked_with(publications.owner_id))
);
create policy publications_admin_all on public.publications for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy challenge_submissions_visible_select on public.challenge_submissions for select to authenticated
using (
  owner_id = (select auth.uid())
  or exists (
    select 1 from public.publications p
    where p.id = publication_id and p.visibility = 'public' and p.moderation_status = 'approved'
      and not (select public.is_blocked_with(p.owner_id))
  )
);
create policy challenge_submissions_owner_insert on public.challenge_submissions for insert to authenticated
with check (owner_id = (select auth.uid()));
create policy challenge_submissions_owner_delete on public.challenge_submissions for delete to authenticated
using (owner_id = (select auth.uid()));

create policy comments_visible_select on public.comments for select to authenticated
using (
  deleted_at is null and moderation_status = 'approved'
  and exists (
    select 1 from public.publications p
    where p.id = publication_id and p.visibility = 'public' and p.moderation_status = 'approved'
      and not (select public.is_blocked_with(p.owner_id))
      and not (select public.is_blocked_with(comments.author_id))
  )
);
create policy comments_author_insert on public.comments for insert to authenticated
with check (author_id = (select auth.uid()));
create policy comments_author_delete on public.comments for delete to authenticated
using (author_id = (select auth.uid()));
create policy comments_admin_all on public.comments for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy blocks_owner_all on public.blocks for all to authenticated
using (blocker_id = (select auth.uid())) with check (blocker_id = (select auth.uid()));

create policy reports_reporter_insert on public.reports for insert to authenticated
with check (reporter_id = (select auth.uid()));
create policy reports_reporter_select on public.reports for select to authenticated
using (reporter_id = (select auth.uid()));
create policy reports_admin_all on public.reports for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy moderation_jobs_admin_all on public.moderation_jobs for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));
create policy moderation_actions_admin_all on public.moderation_actions for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy critique_requests_owner_select on public.critique_requests for select to authenticated
using (owner_id = (select auth.uid()));
create policy critique_requests_owner_insert on public.critique_requests for insert to authenticated
with check (owner_id = (select auth.uid()));
create policy critique_results_owner_select on public.critique_results for select to authenticated
using (owner_id = (select auth.uid()));

create policy feature_flags_read on public.feature_flags for select to anon, authenticated using (true);
create policy feature_flags_admin_all on public.feature_flags for all to authenticated
using ((select public.is_admin())) with check ((select public.is_admin()));

create policy analytics_events_owner_insert on public.analytics_events for insert to authenticated
with check (owner_id is null or owner_id = (select auth.uid()));
create policy analytics_events_admin_select on public.analytics_events for select to authenticated
using ((select public.is_admin()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('private-drafts', 'private-drafts', false, 5368709120, array['video/mp4', 'video/quicktime', 'audio/mp4', 'audio/x-m4a']),
  ('moderation-evidence', 'moderation-evidence', false, 104857600, array['image/jpeg', 'text/plain', 'application/json'])
on conflict (id) do update set public = false;

create policy private_drafts_owner_select on storage.objects for select to authenticated
using (bucket_id = 'private-drafts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy private_drafts_owner_insert on storage.objects for insert to authenticated
with check (bucket_id = 'private-drafts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy private_drafts_owner_update on storage.objects for update to authenticated
using (bucket_id = 'private-drafts' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'private-drafts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy private_drafts_owner_delete on storage.objects for delete to authenticated
using (bucket_id = 'private-drafts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy moderation_evidence_admin_all on storage.objects for all to authenticated
using (bucket_id = 'moderation-evidence' and (select public.is_admin()))
with check (bucket_id = 'moderation-evidence' and (select public.is_admin()));

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
revoke all on function public.is_blocked_with(uuid) from public;
grant execute on function public.is_blocked_with(uuid) to authenticated;

commit;
