-- B11: stop anon/authenticated from holding ALL on service-only tables, and
-- reduce client-read tables to SELECT where the app queries them directly.

-- Service-only (Edge Functions / SECURITY DEFINER / owner only).
revoke all on public.pipeline_config from anon, authenticated;
revoke all on public.profile_embeddings from anon, authenticated;
revoke all on public.match_cache from anon, authenticated;
revoke all on public.skill_moderation_log from anon, authenticated;
revoke all on public.user_weight_overrides from anon, authenticated;
revoke all on public.availability_slots from anon, authenticated;

-- No direct client access; all reads/writes go through SECURITY DEFINER RPCs.
revoke all on public.notifications from anon, authenticated;
revoke all on public.blocks from anon, authenticated;
revoke all on public.reports from anon, authenticated;
revoke all on public.feedback from anon, authenticated;
revoke all on public.skill_showcases from anon, authenticated;

-- Direct client reads used by the chat/pals screens. Writes stay in RPCs.
revoke all on public.connections from anon, authenticated;
grant select on public.connections to authenticated;

revoke all on public.messages from anon, authenticated;
grant select on public.messages to authenticated;
