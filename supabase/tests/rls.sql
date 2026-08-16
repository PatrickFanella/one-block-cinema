begin;

create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (
  id, email, aud, role, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('00000000-0000-0000-0000-000000000001', 'owner@example.invalid', 'authenticated', 'authenticated', '', now(), '{"role":"creator"}', '{"age_band":"adult"}', now(), now()),
  ('00000000-0000-0000-0000-000000000002', 'viewer@example.invalid', 'authenticated', 'authenticated', '', now(), '{"role":"creator"}', '{"age_band":"adult"}', now(), now()),
  ('00000000-0000-0000-0000-000000000003', 'moderator@example.invalid', 'authenticated', 'authenticated', '', now(), '{"role":"moderator"}', '{"age_band":"adult"}', now(), now());

insert into public.projects (
  id, owner_id, template_id, template_schema_version, title, local_created_at
) values (
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'first-block-story', 1, 'Private project', now()
);

insert into public.media_assets (
  id, project_id, owner_id, storage_path, checksum_sha256,
  byte_count, content_type, upload_state
) values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001/10000000-0000-0000-0000-000000000001/source.mov',
  repeat('a', 64), 100, 'video/quicktime', 'uploaded'
);

insert into public.publications (
  id, project_id, owner_id, visibility, moderation_status, processing_status,
  mux_playback_id
) values (
  '30000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'public', 'pending_review', 'ready', 'signed-playback-id'
);

insert into public.moderation_jobs (id, kind, status, publication_id) values (
  '40000000-0000-0000-0000-000000000001',
  'publication_review', 'manual_review',
  '30000000-0000-0000-0000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated","app_metadata":{"role":"creator"}}',
  true
);
select is((select count(*) from public.projects), 1::bigint, 'owner can read their private project');
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated","app_metadata":{"role":"creator"}}',
  true
);
select is((select count(*) from public.projects), 0::bigint, 'another user cannot read a private project');
select is((select count(*) from public.media_assets), 0::bigint, 'another user cannot read private media');
select is((select count(*) from public.publications), 0::bigint, 'unapproved publication has no client-visible playable record');
reset role;

update public.publications set moderation_status = 'approved' where id = '30000000-0000-0000-0000-000000000001';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated","app_metadata":{"role":"creator"}}',
  true
);
select is((select count(*) from public.publications), 1::bigint, 'approved public publication is discoverable');
reset role;

insert into public.blocks (blocker_id, blocked_id) values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000002","role":"authenticated","app_metadata":{"role":"creator"}}',
  true
);
select is((select count(*) from public.publications), 0::bigint, 'a reciprocal block removes publications');
select is((select count(*) from public.moderation_jobs), 0::bigint, 'creator cannot read moderation jobs');
reset role;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-0000-0000-000000000003","role":"authenticated","app_metadata":{"role":"moderator"}}',
  true
);
select is((select count(*) from public.moderation_jobs), 1::bigint, 'moderator can read moderation jobs');
reset role;

select * from finish();
rollback;
