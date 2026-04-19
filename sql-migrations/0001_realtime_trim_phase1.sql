-- ═══════════════════════════════════════════════════════════════════════════
-- Migration: 0001_realtime_trim_phase1
-- Applied:   2026-04-19 via Supabase MCP apply_migration
-- Author:    Phase 1 cost-cut (authorized by Dan)
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Purpose
-- -------
-- supabase_realtime publication had 109 tables. Every write to any of them
-- broadcasts a message to every subscribed realtime client, which bills
-- against the Supabase message quota. 78 of the 109 tables were fully empty,
-- and 30 of those were also NOT subscribed from any client code we could
-- find (grep across World Hub + Club Arena). This migration drops those 30
-- from the publication, taking us from 109 → 79.
--
-- Safety
-- ------
-- ALTER PUBLICATION ... DROP TABLE is instant and does NOT take row locks.
-- Rollback is a single ALTER PUBLICATION ... ADD TABLE (reversed).
--
-- Deferred to Phase 3/4 (high-volume tables — require client refactor first):
--   hand_histories       (5.1M rows, replace subscribe → query on demand)
--   wallet_transactions  (1.95M rows, replace with RPC return values)
--   rake_history         (1.37M rows, replace with RPC return values)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER PUBLICATION supabase_realtime DROP TABLE
  public.action_audit_logs,
  public.arcade_duel_queue,
  public.bbj_contributions,
  public.club_arena_messages,
  public.commander_seats,
  public.commission_history,
  public.geeves_missed_questions,
  public.hand_histories,
  public.live_sessions,
  public.messenger_call_signals,
  public.messenger_messages,
  public.messenger_reactions,
  public.poker_tables,
  public.rakeback_periods,
  public.sandbox_coach_results,
  public.sandbox_equity_history,
  public.sandbox_quiz_results,
  public.sandbox_weekly_spots,
  public.session_chat_messages,
  public.social_conversations,
  public.social_interactions,
  public.solution_bookmarks,
  public.study_rooms,
  public.time_bank,
  public.tournament_reminders_sent,
  public.trivia_pvp_matches,
  public.trivia_pvp_queue,
  public.union_leave_requests,
  public.union_wallet_transactions,
  public.user_progress;

-- Verification (run after apply):
--   SELECT count(*) FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
--   -- expect: 79
