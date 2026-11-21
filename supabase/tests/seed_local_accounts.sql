-- Local integration fixtures: 20 complete accounts.
--
-- Auth users are created first with the Auth Admin API (see
-- seed_local_accounts.ps1); this file fills in the profile, every skill with an
-- approved note, and mock showcases on the trusted storage origin.
--
-- Run against the local stack:
--   docker exec -i supabase_db_palturo psql -U postgres -d postgres \
--     -v ON_ERROR_STOP=1 < supabase/tests/seed_local_accounts.sql

begin;

-- ---------- profiles ----------
with data(email, bio, langs, styles, tstyles, avail) as (values
  ('marisol.rivera@example.test',
   'Self-taught web developer who builds community tools. Happy to walk beginners through their first site.',
   array['English','Filipino'], array['Hands-on Practice','Discussion'],
   array['Demonstration','Hands-on Practice'],
   '["Mon 18:00-21:00","Wed 18:00-21:00","Sat 09:00-12:00"]'::jsonb),
  ('diego.santos@example.test',
   'Folk musician learning the kubing and the bandurria, looking for a patient teacher.',
   array['Filipino','English'], array['Auditory','Hands-on Practice'],
   array[]::text[],
   '["Tue 19:00-21:00","Sun 14:00-17:00"]'::jsonb),
  ('althea.cruz@example.test',
   'Backend engineer who automates small businesses. Teaching Python one project at a time.',
   array['English','Cebuano'], array['Hands-on Practice','Reading/Writing'],
   array['Demonstration','Discussion'],
   '["Mon 20:00-22:00","Thu 20:00-22:00"]'::jsonb),
  ('rafael.mendoza@example.test',
   'Brand and layout designer. I like teaching design systems through real client briefs.',
   array['English','Filipino'], array['Visual','Discussion'],
   array['Demonstration','Discussion'],
   '["Tue 18:00-20:00","Fri 18:00-20:00"]'::jsonb),
  ('lourdes.bautista@example.test',
   'Home cook from Pampanga. Kakanin and heirloom adobo are my specialties.',
   array['Filipino','English'], array['Hands-on Practice','Demonstration'],
   array['Demonstration','Hands-on Practice'],
   '["Wed 09:00-12:00","Sat 15:00-18:00"]'::jsonb),
  ('emilio.garcia@example.test',
   'Calligrapher and sign painter. I teach strokes before scripts.',
   array['Filipino','Spanish'], array['Visual','Hands-on Practice'],
   array['Demonstration','Visual'],
   '["Mon 14:00-17:00","Thu 14:00-17:00"]'::jsonb),
  ('bianca.reyes@example.test',
   'Folk dancer with a provincial troupe. I want to learn to sing while I dance.',
   array['Filipino','Ilocano'], array['Kinesthetic','Discussion'],
   array['Demonstration','Kinesthetic'],
   '["Tue 17:00-19:00","Sat 10:00-12:00"]'::jsonb),
  ('marco.villanueva@example.test',
   'Choral singer and vocal coach. Breathing first, repertoire second.',
   array['English','Filipino'], array['Auditory','Demonstration'],
   array['Demonstration','Auditory'],
   '["Mon 19:00-21:00","Wed 19:00-21:00"]'::jsonb),
  ('carmela.delacruz@example.test',
   'Tailor and seamstress. I can teach you to read a pattern and finish a hem.',
   array['Filipino','English'], array['Hands-on Practice','Reading/Writing'],
   array['Demonstration','Hands-on Practice'],
   '["Tue 10:00-13:00","Fri 10:00-13:00"]'::jsonb),
  ('nathaniel.ramos@example.test',
   'Weaver working with abaca and cotton. Interested in sewing my own finishes.',
   array['Filipino','Bicolano'], array['Hands-on Practice','Visual'],
   array['Demonstration','Hands-on Practice'],
   '["Wed 13:00-16:00","Sun 09:00-12:00"]'::jsonb),
  ('sofia.aquino@example.test',
   'Analyst moving into automation. Looking for a Python mentor who likes exercises.',
   array['English','Filipino'], array['Reading/Writing','Discussion'],
   array[]::text[],
   '["Mon 21:00-22:00","Thu 21:00-22:00"]'::jsonb),
  ('gabriel.navarro@example.test',
   'Nail technician and salon owner. I want to build my own booking site.',
   array['Filipino','English'], array['Hands-on Practice','Visual'],
   array['Demonstration','Hands-on Practice'],
   '["Tue 13:00-16:00","Sat 13:00-16:00"]'::jsonb),
  ('isabella.torres@example.test',
   'Print shop owner. Screen printing and heat transfer, mostly for school orgs.',
   array['English','Filipino'], array['Hands-on Practice','Discussion'],
   array['Demonstration','Hands-on Practice'],
   '["Mon 09:00-12:00","Thu 09:00-12:00"]'::jsonb),
  ('joaquin.castillo@example.test',
   'Embroidery hobbyist focused on barong details. Saving up for a costume project.',
   array['Filipino','English'], array['Visual','Hands-on Practice'],
   array['Demonstration','Visual'],
   '["Wed 18:00-20:00","Sun 15:00-18:00"]'::jsonb),
  ('camille.domingo@example.test',
   'Costume maker for school plays. I want to learn finer embroidery finishes.',
   array['Filipino','Cebuano'], array['Hands-on Practice','Visual'],
   array['Demonstration','Hands-on Practice'],
   '["Tue 14:00-17:00","Sat 09:00-12:00"]'::jsonb),
  ('elias.mercado@example.test',
   'Motorcycle mechanic. Small engines, carburetors, and roadside fixes.',
   array['Filipino','English'], array['Hands-on Practice','Demonstration'],
   array['Demonstration','Hands-on Practice'],
   '["Mon 08:00-11:00","Fri 08:00-11:00"]'::jsonb),
  ('teresa.salazar@example.test',
   'Urban farmer growing herbs and tomatoes on a rooftop. Want to maintain my own bike.',
   array['Filipino','Ilocano'], array['Hands-on Practice','Discussion'],
   array['Demonstration','Hands-on Practice'],
   '["Wed 07:00-10:00","Sat 16:00-18:00"]'::jsonb),
  ('miguel.ferrer@example.test',
   'Furniture maker. Hand tools and joinery, no shortcuts.',
   array['Filipino','English'], array['Hands-on Practice','Visual'],
   array['Demonstration','Hands-on Practice'],
   '["Tue 08:00-11:00","Thu 08:00-11:00"]'::jsonb),
  ('patricia.lim@example.test',
   'Printmaker and small-batch shirt printer. Learning woodworking for display frames.',
   array['English','Filipino'], array['Visual','Hands-on Practice'],
   array['Demonstration','Visual'],
   '["Mon 15:00-18:00","Sat 13:00-16:00"]'::jsonb),
  ('andres.velasco@example.test',
   'Bandurria player and music teacher. I teach traditional music by ear and by tab.',
   array['Filipino','English'], array['Auditory','Demonstration'],
   array['Demonstration','Auditory'],
   '["Tue 18:00-21:00","Sun 10:00-13:00"]'::jsonb)
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

-- ---------- skills + approved notes ----------
with data(email, kind, path, note, visibility) as (values
  ('marisol.rivera@example.test', 'teach', 'modern_practical_skills.programming.web_development', 'I teach HTML, CSS, and a little JavaScript by building a real page.', 'discoverable'),
  ('marisol.rivera@example.test', 'learn', 'cooking_culinary.filipino_cooking', 'I want to learn kakanin for family gatherings.', 'discoverable'),
  ('marisol.rivera@example.test', 'learn', 'modern_practical_skills.woodworking', 'Curious about building a small shelf.', 'paused'),
  ('diego.santos@example.test', 'learn', 'performing_arts.traditional_music', 'I want to learn the bandurria and the old Visayan songs.', 'discoverable'),
  ('althea.cruz@example.test', 'teach', 'modern_practical_skills.programming.python_programming', 'We start with scripts that automate spreadsheets, then small APIs.', 'discoverable'),
  ('althea.cruz@example.test', 'learn', 'modern_practical_skills.graphic_design', 'I want to understand layout and type for developer-facing docs.', 'discoverable'),
  ('rafael.mendoza@example.test', 'teach', 'modern_practical_skills.graphic_design', 'Design systems, grids, and typography with real briefs.', 'discoverable'),
  ('rafael.mendoza@example.test', 'learn', 'modern_practical_skills.programming.web_development', 'I want to prototype my own portfolio without a developer.', 'discoverable'),
  ('lourdes.bautista@example.test', 'teach', 'cooking_culinary.filipino_cooking', 'Hands-on kakanin, adobo, and market-to-table prep.', 'discoverable'),
  ('lourdes.bautista@example.test', 'learn', 'modern_practical_skills.programming.web_development', 'I want a simple site for my catering menu.', 'discoverable'),
  ('emilio.garcia@example.test', 'teach', 'language_writing.calligraphy', 'Broad-pen strokes, then Filipino script letterforms.', 'discoverable'),
  ('emilio.garcia@example.test', 'learn', 'performing_arts.traditional_music', 'I want to accompany my lettering demos with live music.', 'discoverable'),
  ('bianca.reyes@example.test', 'teach', 'performing_arts.folk_dance', 'Regional folk dances, counts, and partner work.', 'discoverable'),
  ('bianca.reyes@example.test', 'learn', 'performing_arts.vocal_music', 'I want to sing while dancing without running out of breath.', 'discoverable'),
  ('marco.villanueva@example.test', 'teach', 'performing_arts.vocal_music', 'Breathing, resonance, and harmony for small groups.', 'discoverable'),
  ('marco.villanueva@example.test', 'learn', 'performing_arts.folk_dance', 'I want to move better on stage during choral numbers.', 'discoverable'),
  ('carmela.delacruz@example.test', 'teach', 'modern_practical_skills.sewing', 'Pattern reading, seams, hems, and simple alterations.', 'discoverable'),
  ('carmela.delacruz@example.test', 'learn', 'traditional_crafts.philippine_handweaving', 'I want to understand woven structure before I cut.', 'discoverable'),
  ('nathaniel.ramos@example.test', 'teach', 'traditional_crafts.philippine_handweaving', 'Abaca preparation, loom setup, and plain weave.', 'discoverable'),
  ('nathaniel.ramos@example.test', 'learn', 'modern_practical_skills.sewing', 'I want to finish my woven cloth into bags and runners.', 'discoverable'),
  ('sofia.aquino@example.test', 'learn', 'modern_practical_skills.programming.python_programming', 'I want to automate reports and learn testing properly.', 'discoverable'),
  ('gabriel.navarro@example.test', 'teach', 'modern_practical_skills.nail_art', 'Gel basics, shaping, and simple hand-painted art.', 'discoverable'),
  ('gabriel.navarro@example.test', 'learn', 'modern_practical_skills.programming.web_development', 'I want a booking page and a small gallery.', 'discoverable'),
  ('isabella.torres@example.test', 'teach', 'modern_practical_skills.tshirt_printing', 'Screen prep, exposure, and one-color prints.', 'discoverable'),
  ('isabella.torres@example.test', 'learn', 'modern_practical_skills.graphic_design', 'I want stronger layouts for my print catalog.', 'discoverable'),
  ('joaquin.castillo@example.test', 'teach', 'traditional_crafts.filipino_embroidery', 'Barong embroidery, thread selection, and finishing.', 'discoverable'),
  ('joaquin.castillo@example.test', 'learn', 'traditional_crafts.costume_making', 'I want to build a full theatrical costume.', 'discoverable'),
  ('camille.domingo@example.test', 'teach', 'traditional_crafts.costume_making', 'Drafting, fitting, and finishing stage costumes.', 'discoverable'),
  ('camille.domingo@example.test', 'learn', 'traditional_crafts.filipino_embroidery', 'I want finer hand embroidery for collars and cuffs.', 'discoverable'),
  ('elias.mercado@example.test', 'teach', 'modern_practical_skills.motorcycle_maintenance', 'Carburetor cleaning, chain care, and safe roadside fixes.', 'discoverable'),
  ('elias.mercado@example.test', 'learn', 'agriculture_livelihood.farming', 'I want to grow vegetables on a small lot.', 'discoverable'),
  ('teresa.salazar@example.test', 'teach', 'agriculture_livelihood.farming', 'Soil prep, container herbs, and pest control without chemicals.', 'discoverable'),
  ('teresa.salazar@example.test', 'learn', 'modern_practical_skills.motorcycle_maintenance', 'I want to maintain my own bike and change a tire.', 'discoverable'),
  ('miguel.ferrer@example.test', 'teach', 'modern_practical_skills.woodworking', 'Hand-tool joinery, sharpening, and a simple stool build.', 'discoverable'),
  ('miguel.ferrer@example.test', 'learn', 'modern_practical_skills.tshirt_printing', 'I want to print my workshop logo on aprons.', 'discoverable'),
  ('patricia.lim@example.test', 'teach', 'modern_practical_skills.tshirt_printing', 'One-color prints, registration, and curing.', 'discoverable'),
  ('patricia.lim@example.test', 'learn', 'modern_practical_skills.woodworking', 'I want to build frames and a display shelf.', 'discoverable'),
  ('andres.velasco@example.test', 'teach', 'performing_arts.traditional_music', 'Bandurria and rondalla repertoire, taught by ear and tab.', 'discoverable'),
  ('andres.velasco@example.test', 'learn', 'language_writing.calligraphy', 'I want to letter my own lyric sheets and posters.', 'discoverable')
)
insert into public.user_skills (user_id, skill_id, kind, note, note_approved, visibility)
select u.id, n.id, d.kind::public.skill_kind, d.note, true, d.visibility
from data d
join auth.users u on lower(u.email) = d.email
join public.skill_nodes n on n.path = d.path::extensions.ltree
on conflict (user_id, skill_id, kind) do update
set note = excluded.note,
    note_approved = true,
    visibility = excluded.visibility;

-- ---------- mock showcases ----------
with data(email, path, media, kind, thumb, caption) as (values
  ('marisol.rivera@example.test', 'modern_practical_skills.programming.web_development',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/marisol-web-1.jpg',
   'image', null, 'Community site I shipped'),
  ('althea.cruz@example.test', 'modern_practical_skills.programming.python_programming',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/althea-python.jpg',
   'image', null, 'Automation script walkthrough'),
  ('rafael.mendoza@example.test', 'modern_practical_skills.graphic_design',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/rafael-brand.jpg',
   'image', null, 'Brand system for a cafe'),
  ('lourdes.bautista@example.test', 'cooking_culinary.filipino_cooking',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/lourdes-kakanin.jpg',
   'image', null, 'Kakanin tray for a fiesta'),
  ('emilio.garcia@example.test', 'language_writing.calligraphy',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/emilio-script.jpg',
   'image', null, 'Filipino script specimen'),
  ('bianca.reyes@example.test', 'performing_arts.folk_dance',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/bianca-dance.jpg',
   'image', null, 'Troupe rehearsal still'),
  ('marco.villanueva@example.test', 'performing_arts.vocal_music',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/marco-choir.jpg',
   'image', null, 'Choir warm-up session'),
  ('carmela.delacruz@example.test', 'modern_practical_skills.sewing',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/carmela-linen.jpg',
   'image', null, 'Finished linen set'),
  ('nathaniel.ramos@example.test', 'traditional_crafts.philippine_handweaving',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/nathaniel-loom.jpg',
   'image', null, 'Abaca runner on the loom'),
  ('gabriel.navarro@example.test', 'modern_practical_skills.nail_art',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/gabriel-gel.jpg',
   'image', null, 'Gel set close-up'),
  ('isabella.torres@example.test', 'modern_practical_skills.tshirt_printing',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/isabella-shirt.jpg',
   'image', null, 'School org shirt run'),
  ('joaquin.castillo@example.test', 'traditional_crafts.filipino_embroidery',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/joaquin-barong.jpg',
   'image', null, 'Barong collar detail'),
  ('camille.domingo@example.test', 'traditional_crafts.costume_making',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/camille-costume.jpg',
   'image', null, 'Stage costume fitting'),
  ('elias.mercado@example.test', 'modern_practical_skills.motorcycle_maintenance',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/elias-carb.jpg',
   'image', null, 'Carburetor rebuild'),
  ('teresa.salazar@example.test', 'agriculture_livelihood.farming',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/teresa-rooftop.jpg',
   'image', null, 'Rooftop herb beds'),
  ('miguel.ferrer@example.test', 'modern_practical_skills.woodworking',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/miguel-stool.jpg',
   'image', null, 'Stool build, hand tools'),
  ('patricia.lim@example.test', 'modern_practical_skills.tshirt_printing',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/patricia-print.jpg',
   'image', null, 'Two-color registration test'),
  ('andres.velasco@example.test', 'performing_arts.traditional_music',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/andres-rondalla.mp4',
   'video',
   'https://yjcrfgvenilptrnudvcb.supabase.co/storage/v1/object/public/skill-showcases/mock/andres-rondalla-thumb.jpg',
   'Rondalla rehearsal')
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

-- Verification helper: every account should be side-ready on the sides it has.
select u.email,
       p.role::text as role,
       public.side_ready(u.id, 'learn'::public.skill_kind) as learn_ready,
       public.side_ready(u.id, 'teach'::public.skill_kind) as teach_ready
from auth.users u
join public.profiles p on p.id = u.id
where u.email like '%@example.test'
order by u.email;
