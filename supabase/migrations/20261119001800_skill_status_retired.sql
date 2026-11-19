-- Admin merge/retire needs a distinct terminal state. Add it to the enum.
alter type public.skill_status add value if not exists 'retired';
