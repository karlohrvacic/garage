-- Nobody who is not signed in may call a function in this schema.
--
-- Every function migration here ends the same way, `revoke execute ... from
-- public` and `grant execute ... to authenticated`, on the understanding that
-- PUBLIC was how the anonymous role reached a function. It was one way. The
-- project's default privileges grant every function the migrations create to
-- `anon` by name as well, and a revoke from PUBLIC leaves that grant where it
-- is, so every function below answered anybody holding the key that ships in
-- the app. `describe_code` told them which garage or car a code belonged to.
-- The rest refused them one way or another, since nothing a stranger can reach
-- has an `auth.uid()` to act for, but that was each function's own care, not
-- the schema's.
--
-- Nothing legitimate is lost. Every policy is for `authenticated`, the app
-- calls no function before sign-in, the edge functions call theirs with the
-- service role, and a trigger function is not checked against the role whose
-- write fired it. `test_rls/rls_test.dart` reads the API's own list of what the
-- anonymous role may call, and fails if it names anything.
--
-- The default is changed too, so the next function is closed to `anon` from
-- the start. PUBLIC's own default grant is Postgres's and stays, which is what
-- the existing `revoke ... from public` convention is for, and for `anon` it
-- now suffices. The same default grants `authenticated` every function by name
-- as well, so a function only the server calls also needs a revoke from
-- `authenticated`; the two that are meant that way get one below.

revoke execute on function public.user_household_ids() from anon, public;
revoke execute on function public.user_vehicle_ids() from anon, public;
revoke execute on function public.guest_vehicle_ids(text) from anon, public;
revoke execute on function public.is_household_admin(uuid) from anon, public;
revoke execute on function public.ensure_household_has_admin(uuid, uuid) from anon, public;
revoke execute on function public.generate_invite_code() from anon, public;

revoke execute on function public.create_household(text) from anon, public;
revoke execute on function public.create_invite(uuid, text) from anon, public;
revoke execute on function public.join_household_with_code(text) from anon, public;
revoke execute on function public.merge_households(uuid, uuid) from anon, public;
revoke execute on function public.household_for_api_key(text) from anon, public;

revoke execute on function public.create_vehicle_transfer(uuid) from anon, public;
revoke execute on function public.redeem_vehicle_transfer(text, uuid) from anon, public;

revoke execute on function public.create_guest_pass(
  uuid, integer, text, timestamptz, boolean, boolean, boolean, boolean
) from anon, public;
revoke execute on function public.create_guest_pass_between(
  uuid, timestamptz, timestamptz, text, boolean, boolean, boolean, boolean,
  boolean
) from anon, public;
revoke execute on function public.redeem_guest_pass(text) from anon, public;
revoke execute on function public.return_guest_pass(uuid) from anon, public;
revoke execute on function public.describe_code(text) from anon, public;
revoke execute on function public.guest_vehicles() from anon, public;
revoke execute on function public.guest_vehicle_briefing(uuid) from anon, public;
revoke execute on function public.guest_service_history(uuid) from anon, public;

-- Trigger functions cannot be called directly, so these were never a way in.
-- Closed anyway, so that with `run_due_reminders_push`, which 0076 closed,
-- this is the whole schema and not a selection.
revoke execute on function public.handle_new_user() from anon, public;
revoke execute on function public.delete_empty_household() from anon, public;
revoke execute on function public.pin_created_by() from anon, public;
revoke execute on function public.dispatch_entry_webhook() from anon, public;
revoke execute on function public.enforce_household_rename_is_admin() from anon, public;
revoke execute on function public.promote_after_member_left() from anon, public;
revoke execute on function public.promote_after_role_changed() from anon, public;
revoke execute on function public.clear_guest_pass_redemption() from anon, public;

alter default privileges for role postgres in schema public
  revoke execute on functions from anon;

-- Two were only ever meant for the server. `household_for_api_key` turns an API
-- key's hash into a garage for the public API, which calls it with the service
-- role (0017 granted it to that role alone and meant it); any signed-in user
-- could call it with a hash. `ensure_household_has_admin` is called by the
-- triggers that keep a garage with an admin (0056, 0058), never by the app.
revoke execute on function public.household_for_api_key(text) from authenticated;
revoke execute on function public.ensure_household_has_admin(uuid, uuid) from authenticated;
