-- Production experiment wave 2: 10 tagged users (mock21..mock30).
--
-- Tag: email mock%@palturo.dev, auth metadata mock=true, mock_batch
-- "2026-11-22-wave2", bio prefix [MOCK]. Removed by remove_mock_accounts.ps1.
--
-- Skills are chosen to compete for existing cooking, dessert, music, and
-- calligraphy demand so rank shifts are observable.

begin;

delete from public.user_skills us
using auth.users u
where us.user_id = u.id
  and u.email in (
    'mock21@palturo.dev','mock22@palturo.dev','mock23@palturo.dev','mock24@palturo.dev',
    'mock25@palturo.dev','mock26@palturo.dev','mock27@palturo.dev','mock28@palturo.dev',
    'mock29@palturo.dev','mock30@palturo.dev'
  );

with data(email, bio, langs, styles, tstyles, avail) as (values
  ('mock21@palturo.dev', '[MOCK] Rondalla player and music teacher.',
   array['Filipino','English'], array['Auditory','Demonstration'], array['Demonstration','Auditory'],
   '["Tue 18:00-21:00","Sun 09:00-12:00"]'::jsonb),
  ('mock22@palturo.dev', '[MOCK] Traditional singer learning desserts.',
   array['Filipino','Cebuano'], array['Auditory','Hands-on Practice'], array['Demonstration','Auditory'],
   '["Mon 19:00-21:00","Thu 19:00-21:00"]'::jsonb),
  ('mock23@palturo.dev', '[MOCK] Music teacher and choir leader.',
   array['English','Filipino'], array['Auditory','Demonstration'], array['Demonstration','Auditory'],
   '["Wed 17:00-20:00","Sat 10:00-13:00"]'::jsonb),
  ('mock24@palturo.dev', '[MOCK] Home cook and music fan.',
   array['Filipino','English'], array['Hands-on Practice','Discussion'], array['Demonstration','Hands-on Practice'],
   '["Mon 09:00-12:00","Fri 09:00-12:00"]'::jsonb),
  ('mock25@palturo.dev', '[MOCK] Cooking teacher and letterer.',
   array['English','Filipino'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Tue 13:00-16:00","Sat 13:00-16:00"]'::jsonb),
  ('mock26@palturo.dev', '[MOCK] Dessert baker learning savory cooking.',
   array['Filipino','Ilocano'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Wed 08:00-11:00","Sun 14:00-17:00"]'::jsonb),
  ('mock27@palturo.dev', '[MOCK] Calligrapher learning cooking and music.',
   array['Filipino','Spanish'], array['Visual','Hands-on Practice'], array['Demonstration','Visual'],
   '["Mon 14:00-17:00","Thu 14:00-17:00"]'::jsonb),
  ('mock28@palturo.dev', '[MOCK] Food lover learning cooking and desserts.',
   array['English','Filipino'], array['Hands-on Practice','Discussion'], array[]::text[],
   '["Tue 20:00-22:00","Sat 16:00-18:00"]'::jsonb),
  ('mock29@palturo.dev', '[MOCK] Baker and music hobbyist.',
   array['Filipino','English'], array['Visual','Auditory'], array[]::text[],
   '["Wed 18:00-20:00","Sun 15:00-18:00"]'::jsonb),
  ('mock30@palturo.dev', '[MOCK] Nail artist learning cooking and music.',
   array['Filipino','Cebuano'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Fri 10:00-13:00","Sat 15:00-18:00"]'::jsonb)
)
update public.profiles p
set bio = d.bio,
    languages = d.langs,
    learning_styles = d.styles,
    teaching_styles = d.tstyles,
    availability = d.avail,
    timezone = 'Asia/Manila',
    is_profile_completed = true
from data d
join auth.users u on lower(u.email) = d.email
where p.id = u.id;

with data(email, kind, path, note) as (values
  ('mock21@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Rondalla and bandurria for beginners.'),
  ('mock21@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook for family nights.'),
  ('mock22@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Traditional songs by ear and harmony.'),
  ('mock22@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to bake kakanin.'),
  ('mock23@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Ensemble timing and repertoire.'),
  ('mock23@palturo.dev', 'teach', 'performing_arts.vocal_music', 'Breathing and choral blend.'),
  ('mock23@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want quick Filipino meals.'),
  ('mock24@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Everyday Filipino meals and prep.'),
  ('mock24@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn the bandurria.'),
  ('mock25@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Home cooking and knife skills.'),
  ('mock25@palturo.dev', 'learn', 'language_writing.calligraphy', 'I want to letter menu boards.'),
  ('mock26@palturo.dev', 'teach', 'cooking_culinary.filipino_dessert_making', 'Leche flan and cassava cake.'),
  ('mock26@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook savory dishes.'),
  ('mock27@palturo.dev', 'teach', 'language_writing.calligraphy', 'Broad-pen and brush lettering.'),
  ('mock27@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook for myself.'),
  ('mock27@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn folk songs.'),
  ('mock28@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook adobo and sinigang.'),
  ('mock28@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to make leche flan.'),
  ('mock29@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to bake for family.'),
  ('mock29@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to join a rondalla.'),
  ('mock30@palturo.dev', 'teach', 'modern_practical_skills.nail_art', 'Gel and hand-painted nail art.'),
  ('mock30@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to meal prep.'),
  ('mock30@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn the bandurria.')
)
insert into public.user_skills (user_id, skill_id, kind, note, note_approved, visibility)
select u.id, n.id, d.kind::public.skill_kind, d.note, true, 'discoverable'
from data d
join auth.users u on lower(u.email) = d.email
join public.skill_nodes n on n.path = d.path::extensions.ltree;

with data(email, path, media, caption) as (values
  ('mock21@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-21-music.jpg', 'Rondalla rehearsal'),
  ('mock22@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-22-music.jpg', 'Vocal and bandurria'),
  ('mock23@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-23-music.jpg', 'Ensemble session'),
  ('mock23@palturo.dev', 'performing_arts.vocal_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-23-vocal.jpg', 'Choir blend'),
  ('mock24@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-24-cooking.jpg', 'Family table'),
  ('mock25@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-25-cooking.jpg', 'Knife skills'),
  ('mock26@palturo.dev', 'cooking_culinary.filipino_dessert_making', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-26-dessert.jpg', 'Leche flan'),
  ('mock27@palturo.dev', 'language_writing.calligraphy', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-27-calligraphy.jpg', 'Brush lettering'),
  ('mock30@palturo.dev', 'modern_practical_skills.nail_art', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/wave2-30-nails.jpg', 'Gel set')
)
insert into public.skill_showcases (user_id, skill_id, media_url, media_kind, caption)
select u.id, n.id, d.media, 'image', d.caption
from data d
join auth.users u on lower(u.email) = d.email
join public.skill_nodes n on n.path = d.path::extensions.ltree
on conflict (user_id, skill_id) do update
set media_url = excluded.media_url, caption = excluded.caption;

commit;

select count(*) as wave2_accounts,
       count(*) filter (where p.has_completed_onboarding) as onboarded
from auth.users u join public.profiles p on p.id = u.id
where u.email in (
  'mock21@palturo.dev','mock22@palturo.dev','mock23@palturo.dev','mock24@palturo.dev',
  'mock25@palturo.dev','mock26@palturo.dev','mock27@palturo.dev','mock28@palturo.dev',
  'mock29@palturo.dev','mock30@palturo.dev'
);
