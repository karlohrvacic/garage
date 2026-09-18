-- Two things the production linter found the morning after 0077.
--
-- `generate_invite_code` was the one function in the schema with no
-- `search_path` of its own: written in 0002 before the convention, and
-- harmless, since it is SECURITY INVOKER and touches nothing but string
-- functions and `random()`. Pinned anyway, so that the schema has one rule
-- and `test/ci/function_privileges_test.dart` can hold every function to it.
alter function public.generate_invite_code() set search_path = public;

-- The eight trigger functions were still granted to `authenticated`, as the
-- default privileges grant every function. Postgres checks EXECUTE on a
-- trigger function when the trigger is *created*, not when a write fires it,
-- so the grant did nothing for the app: 0077 revoked them from `anon` and
-- PUBLIC, and sign-up, which fires `handle_new_user` as the auth admin with
-- no grant of its own, kept working. All the grant did was list each of them
-- in the API's description for every signed-in user. `test_rls/rls_test.dart`
-- is the proof that writes still fire them: every insert it makes runs
-- `pin_created_by`, and every sign-up `handle_new_user`.
revoke execute on function public.handle_new_user() from authenticated;
revoke execute on function public.delete_empty_household() from authenticated;
revoke execute on function public.pin_created_by() from authenticated;
revoke execute on function public.dispatch_entry_webhook() from authenticated;
revoke execute on function public.enforce_household_rename_is_admin() from authenticated;
revoke execute on function public.promote_after_member_left() from authenticated;
revoke execute on function public.promote_after_role_changed() from authenticated;
revoke execute on function public.clear_guest_pass_redemption() from authenticated;
