-- Production test mocks: 20 complete, tagged accounts.
--
-- Tag: email mockNN@palturo.dev, auth metadata mock=true + mock_batch,
-- bio prefix [MOCK]. Remove with remove_mock_accounts.sql.
--
-- Auth users are created first by seed_mock_accounts.ps1. This file fills in
-- profiles, every skill card with an approved note, and one showcase per
-- teaching card.

begin;

with data(email, bio, langs, styles, tstyles, avail) as (values
  ('mock01@palturo.dev', '[MOCK] Home cook and baker. Kakanin and heirloom adobo are my specialties.',
   array['English','Filipino'], array['Hands-on Practice','Demonstration'], array['Demonstration','Hands-on Practice'],
   '["Mon 09:00-12:00","Thu 09:00-12:00"]'::jsonb),
  ('mock02@palturo.dev', '[MOCK] Weekend cook who wants to learn the rondalla.',
   array['Filipino','English'], array['Hands-on Practice','Discussion'], array['Demonstration','Discussion'],
   '["Tue 18:00-21:00","Sat 14:00-17:00"]'::jsonb),
  ('mock03@palturo.dev', '[MOCK] Dessert maker and urban gardener.',
   array['Filipino','Ilocano'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Wed 08:00-11:00","Sun 09:00-12:00"]'::jsonb),
  ('mock04@palturo.dev', '[MOCK] Sewing teacher who loves heirloom recipes.',
   array['Filipino','English'], array['Hands-on Practice','Reading/Writing'], array['Demonstration','Hands-on Practice'],
   '["Mon 14:00-17:00","Fri 14:00-17:00"]'::jsonb),
  ('mock05@palturo.dev', '[MOCK] Kitchen basics and dessert techniques.',
   array['English','Filipino'], array['Discussion','Reading/Writing'], array['Demonstration','Discussion'],
   '["Tue 09:00-12:00","Thu 14:00-17:00"]'::jsonb),
  ('mock06@palturo.dev', '[MOCK] Home decorating and Filipino cooking.',
   array['Filipino','Bicolano'], array['Visual','Hands-on Practice'], array['Demonstration','Visual'],
   '["Wed 15:00-18:00","Sat 09:00-12:00"]'::jsonb),
  ('mock07@palturo.dev', '[MOCK] Painter learning traditional music.',
   array['Filipino','English'], array['Visual','Auditory'], array['Demonstration','Auditory'],
   '["Mon 18:00-21:00","Wed 18:00-21:00"]'::jsonb),
  ('mock08@palturo.dev', '[MOCK] Vocal coach and music teacher.',
   array['English','Filipino'], array['Auditory','Demonstration'], array['Demonstration','Auditory'],
   '["Tue 19:00-21:00","Sun 10:00-13:00"]'::jsonb),
  ('mock09@palturo.dev', '[MOCK] Folk dancer and music teacher.',
   array['Filipino','English'], array['Kinesthetic','Auditory'], array['Demonstration','Kinesthetic'],
   '["Wed 17:00-20:00","Sat 10:00-13:00"]'::jsonb),
  ('mock10@palturo.dev', '[MOCK] Singer who wants to learn traditional music.',
   array['English','Filipino'], array['Auditory','Demonstration'], array['Demonstration','Auditory'],
   '["Thu 19:00-21:00","Sun 14:00-17:00"]'::jsonb),
  ('mock11@palturo.dev', '[MOCK] Martial arts coach who wants to cook for family.',
   array['Filipino','English'], array['Hands-on Practice','Kinesthetic'], array['Demonstration','Hands-on Practice'],
   '["Mon 07:00-10:00","Sat 15:00-18:00"]'::jsonb),
  ('mock12@palturo.dev', '[MOCK] Startup analyst learning Filipino cooking.',
   array['English','Filipino'], array['Reading/Writing','Discussion'], array[]::text[],
   '["Tue 20:00-22:00","Thu 20:00-22:00"]'::jsonb),
  ('mock13@palturo.dev', '[MOCK] Rooftop farmer learning desserts.',
   array['Filipino','Ilocano'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Wed 07:00-10:00","Sun 09:00-12:00"]'::jsonb),
  ('mock14@palturo.dev', '[MOCK] Music fan learning cooking and rondalla.',
   array['English','Filipino'], array['Auditory','Hands-on Practice'], array[]::text[],
   '["Mon 19:00-21:00","Sat 16:00-18:00"]'::jsonb),
  ('mock15@palturo.dev', '[MOCK] Programmer learning home cooking.',
   array['English','Cebuano'], array['Reading/Writing','Discussion'], array['Demonstration','Discussion'],
   '["Tue 21:00-22:00","Fri 21:00-22:00"]'::jsonb),
  ('mock16@palturo.dev', '[MOCK] Dessert lover and music hobbyist.',
   array['Filipino','English'], array['Visual','Auditory'], array[]::text[],
   '["Wed 18:00-20:00","Sun 15:00-18:00"]'::jsonb),
  ('mock17@palturo.dev', '[MOCK] Calligrapher learning traditional music.',
   array['Filipino','Spanish'], array['Visual','Hands-on Practice'], array['Demonstration','Visual'],
   '["Mon 14:00-17:00","Thu 14:00-17:00"]'::jsonb),
  ('mock18@palturo.dev', '[MOCK] Woodworker and choir member.',
   array['Filipino','English'], array['Hands-on Practice','Auditory'], array['Demonstration','Hands-on Practice'],
   '["Tue 08:00-11:00","Sat 13:00-16:00"]'::jsonb),
  ('mock19@palturo.dev', '[MOCK] Nail artist and food lover.',
   array['Filipino','Cebuano'], array['Hands-on Practice','Visual'], array['Demonstration','Hands-on Practice'],
   '["Mon 10:00-13:00","Fri 15:00-18:00"]'::jsonb),
  ('mock20@palturo.dev', '[MOCK] Mechanic learning to cook.',
   array['Filipino','English'], array['Hands-on Practice','Demonstration'], array['Demonstration','Hands-on Practice'],
   '["Tue 08:00-11:00","Thu 08:00-11:00"]'::jsonb)
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

-- Reset mock cards first: the teach cap trigger counts existing rows before the
-- conflict check, so a rerun would otherwise fail for two-teach accounts.
delete from public.user_skills us
using auth.users u
where us.user_id = u.id and u.email like 'mock%@palturo.dev';

with data(email, kind, path, note) as (values
  ('mock01@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Heirloom adobo, kakanin, and market prep.'),
  ('mock01@palturo.dev', 'teach', 'cooking_culinary.filipino_dessert_making', 'Leche flan, bibingka, and cassava cake.'),
  ('mock01@palturo.dev', 'learn', 'language_writing.calligraphy', 'I want to letter my recipe cards.'),
  ('mock02@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Home-style Filipino meals, one pot at a time.'),
  ('mock02@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn the bandurria.'),
  ('mock03@palturo.dev', 'teach', 'cooking_culinary.filipino_dessert_making', 'Kakanin and rice cakes for gatherings.'),
  ('mock03@palturo.dev', 'learn', 'agriculture_livelihood.farming', 'I want to grow herbs and vegetables.'),
  ('mock04@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Family recipes and batch cooking.'),
  ('mock04@palturo.dev', 'learn', 'modern_practical_skills.sewing', 'I want to repair and alter clothes.'),
  ('mock05@palturo.dev', 'teach', 'cooking_culinary.filipino_dessert_making', 'Dessert techniques and plating.'),
  ('mock05@palturo.dev', 'teach', 'household_skills.kitchen_basics', 'Knife skills, prep, and kitchen safety.'),
  ('mock05@palturo.dev', 'learn', 'modern_practical_skills.graphic_design', 'I want a clean menu layout.'),
  ('mock06@palturo.dev', 'teach', 'cooking_culinary.filipino_cooking', 'Everyday Filipino cooking for busy homes.'),
  ('mock06@palturo.dev', 'learn', 'household_skills.home_decorating', 'I want to restyle my living room.'),
  ('mock07@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Rondalla repertoire by ear and tab.'),
  ('mock07@palturo.dev', 'learn', 'visual_arts_design.painting', 'I want to paint stage backdrops.'),
  ('mock08@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Bandurria and octavina fundamentals.'),
  ('mock08@palturo.dev', 'teach', 'performing_arts.vocal_music', 'Breathing and harmony for groups.'),
  ('mock08@palturo.dev', 'learn', 'visual_arts_design.painting', 'I want to paint portraits.'),
  ('mock09@palturo.dev', 'teach', 'performing_arts.traditional_music', 'Folk songs and ensemble timing.'),
  ('mock09@palturo.dev', 'teach', 'performing_arts.folk_dance', 'Regional dances and partner work.'),
  ('mock09@palturo.dev', 'learn', 'traditional_crafts.costume_making', 'I want to make performance costumes.'),
  ('mock10@palturo.dev', 'teach', 'performing_arts.vocal_music', 'Pop and choral singing fundamentals.'),
  ('mock10@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn traditional songs.'),
  ('mock11@palturo.dev', 'teach', 'martial_arts.filipino_martial_arts', 'Footwork, sticks, and safe sparring.'),
  ('mock11@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook for my family.'),
  ('mock11@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to make kakanin.'),
  ('mock12@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook simple Filipino meals.'),
  ('mock13@palturo.dev', 'teach', 'agriculture_livelihood.farming', 'Container gardening and compost.'),
  ('mock13@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to bake for the holidays.'),
  ('mock14@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to learn adobo and sinigang.'),
  ('mock14@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to play the guitar parts.'),
  ('mock15@palturo.dev', 'teach', 'modern_practical_skills.programming', 'Programming fundamentals and debugging.'),
  ('mock15@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to meal-prep for the week.'),
  ('mock16@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to learn leche flan.'),
  ('mock16@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to join a rondalla.'),
  ('mock17@palturo.dev', 'teach', 'language_writing.calligraphy', 'Broad-pen strokes and Filipino scripts.'),
  ('mock17@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to letter lyric sheets.'),
  ('mock18@palturo.dev', 'teach', 'modern_practical_skills.woodworking', 'Hand tools and simple joinery.'),
  ('mock18@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn folk songs.'),
  ('mock18@palturo.dev', 'learn', 'performing_arts.vocal_music', 'I want to sing in a choir.'),
  ('mock19@palturo.dev', 'teach', 'modern_practical_skills.nail_art', 'Gel basics and hand-painted art.'),
  ('mock19@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook for my family.'),
  ('mock19@palturo.dev', 'learn', 'cooking_culinary.filipino_dessert_making', 'I want to make kakanin.'),
  ('mock19@palturo.dev', 'learn', 'performing_arts.traditional_music', 'I want to learn the bandurria.'),
  ('mock20@palturo.dev', 'teach', 'modern_practical_skills.motorcycle_maintenance', 'Carburetors, chain care, and roadside fixes.'),
  ('mock20@palturo.dev', 'learn', 'cooking_culinary.filipino_cooking', 'I want to cook after work.')
)
insert into public.user_skills (user_id, skill_id, kind, note, note_approved, visibility)
select u.id, n.id, d.kind::public.skill_kind, d.note, true, 'discoverable'
from data d
join auth.users u on lower(u.email) = d.email
join public.skill_nodes n on n.path = d.path::extensions.ltree
on conflict (user_id, skill_id, kind) do update
set note = excluded.note,
    note_approved = true,
    visibility = 'discoverable';

with data(email, path, media, kind, thumb, caption) as (values
  ('mock01@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock01-cooking.jpg', 'image', null, 'Adobo and kakanin spread'),
  ('mock01@palturo.dev', 'cooking_culinary.filipino_dessert_making', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock01-dessert.jpg', 'image', null, 'Leche flan tray'),
  ('mock02@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock02-cooking.jpg', 'image', null, 'Weeknight Filipino meal'),
  ('mock03@palturo.dev', 'cooking_culinary.filipino_dessert_making', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock03-dessert.jpg', 'image', null, 'Kakanin platter'),
  ('mock04@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock04-cooking.jpg', 'image', null, 'Batch cooking prep'),
  ('mock05@palturo.dev', 'cooking_culinary.filipino_dessert_making', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock05-dessert.jpg', 'image', null, 'Plated dessert'),
  ('mock05@palturo.dev', 'household_skills.kitchen_basics', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock05-kitchen.jpg', 'image', null, 'Knife skills station'),
  ('mock06@palturo.dev', 'cooking_culinary.filipino_cooking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock06-cooking.jpg', 'image', null, 'Family-style table'),
  ('mock07@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock07-music.jpg', 'image', null, 'Bandurria practice'),
  ('mock08@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock08-music.jpg', 'image', null, 'Rondalla section'),
  ('mock08@palturo.dev', 'performing_arts.vocal_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock08-vocal.mp4', 'video', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock08-vocal-thumb.jpg', 'Choir warm-up'),
  ('mock09@palturo.dev', 'performing_arts.traditional_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock09-music.jpg', 'image', null, 'Folk song rehearsal'),
  ('mock09@palturo.dev', 'performing_arts.folk_dance', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock09-dance.mp4', 'video', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock09-dance-thumb.jpg', 'Folk dance rehearsal'),
  ('mock10@palturo.dev', 'performing_arts.vocal_music', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock10-vocal.jpg', 'image', null, 'Vocal session'),
  ('mock11@palturo.dev', 'martial_arts.filipino_martial_arts', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock11-arnis.jpg', 'image', null, 'Stick drills'),
  ('mock13@palturo.dev', 'agriculture_livelihood.farming', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock13-farming.jpg', 'image', null, 'Rooftop containers'),
  ('mock15@palturo.dev', 'modern_practical_skills.programming', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock15-code.jpg', 'image', null, 'Debugging walkthrough'),
  ('mock17@palturo.dev', 'language_writing.calligraphy', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock17-calligraphy.jpg', 'image', null, 'Script specimen'),
  ('mock18@palturo.dev', 'modern_practical_skills.woodworking', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock18-wood.jpg', 'image', null, 'Joinery detail'),
  ('mock19@palturo.dev', 'modern_practical_skills.nail_art', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock19-nails.jpg', 'image', null, 'Gel set'),
  ('mock20@palturo.dev', 'modern_practical_skills.motorcycle_maintenance', 'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock-2026-11/mock20-bike.jpg', 'image', null, 'Carburetor rebuild')
)
insert into public.skill_showcases (user_id, skill_id, media_url, media_kind, thumbnail_url, caption)
select u.id, n.id, d.media, d.kind::public.media_kind, d.thumb, d.caption
from data d
join auth.users u on lower(u.email) = d.email
join public.skill_nodes n on n.path = d.path::extensions.ltree
on conflict (user_id, skill_id) do update
set media_url = excluded.media_url,
    media_kind = excluded.media_kind,
    thumbnail_url = excluded.thumbnail_url,
    caption = excluded.caption;

commit;

select count(*) as mock_accounts,
       count(*) filter (where p.has_completed_onboarding) as onboarded
from auth.users u join public.profiles p on p.id = u.id
where u.email like 'mock%@palturo.dev';
