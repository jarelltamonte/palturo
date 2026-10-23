-- B9: profile-media had no server-side size or MIME limit. Avatars,
-- profile-photos and skill-showcases already have limits; align the bucket used
-- by profile photos and proof images.

update storage.buckets
set file_size_limit = 5242880, -- 5 MiB
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'profile-media';

-- Proof media is private: it is stored as an object path in
-- profiles.teaching_skill_images and signed for the owner on read.
insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values (
  'skill-proofs',
  'skill-proofs',
  false,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Users manage own skill proofs" on storage.objects;
create policy "Users manage own skill proofs"
  on storage.objects
  for all
  to authenticated
  using (
    bucket_id = 'skill-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'skill-proofs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

