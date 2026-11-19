-- Bound client-writable profile and feedback fields so a direct PostgREST
-- PATCH cannot store megabytes per row or ship huge payloads to every card.
-- `not valid` keeps existing rows untouched while enforcing new writes.
alter table public.profiles
  add constraint profiles_bio_len check (bio is null or length(bio) <= 2000) not valid,
  add constraint profiles_photos_len check (photos is null or array_length(photos, 1) <= 6) not valid,
  add constraint profiles_learning_styles_len check (learning_styles is null or array_length(learning_styles, 1) <= 20) not valid,
  add constraint profiles_teaching_styles_len check (teaching_styles is null or array_length(teaching_styles, 1) <= 20) not valid,
  add constraint profiles_languages_len check (languages is null or array_length(languages, 1) <= 20) not valid,
  add constraint profiles_skill_images_size check (teaching_skill_images is null or pg_column_size(teaching_skill_images) <= 16384) not valid,
  add constraint profiles_availability_size check (availability is null or pg_column_size(availability) <= 8192) not valid,
  add constraint profiles_display_name_len check (display_name is null or length(display_name) <= 80) not valid,
  add constraint profiles_first_name_len check (first_name is null or length(first_name) <= 80) not valid,
  add constraint profiles_last_name_len check (last_name is null or length(last_name) <= 80) not valid;

alter table public.skill_showcases
  add constraint skill_showcases_caption_len check (caption is null or length(caption) <= 200) not valid,
  add constraint skill_showcases_media_len check (media_url is null or length(media_url) <= 2048) not valid,
  add constraint skill_showcases_thumb_len check (thumbnail_url is null or length(thumbnail_url) <= 2048) not valid;

alter table public.app_feedback
  add constraint app_feedback_payload_size check (payload is null or pg_column_size(payload) <= 8192) not valid;
