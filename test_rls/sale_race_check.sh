#!/bin/bash
# A car sold while a pass for it is being minted keeps no live pass.
#
# Two real database sessions, because the bug this guards (decision 165,
# migration 0074) only exists between two transactions and nothing in the
# Dart suite can hold one open: a buyer redeeming a transfer, and the seller
# minting a pass for the same car at the same moment, in both orders and
# through both mint functions.
#
# Each leg holds the first transaction open, starts the second, and checks
# from a third session that the second is waiting on a lock before the first
# commits. Then it checks how each ended: a sale always goes through, a mint
# that came second is refused, and a pass that came first is withdrawn.
#
# Run it against the LOCAL stack, after `dart test test_rls/rls_test.dart`
# (it borrows the two newest users that suite created). Needs `psql`.
# Exits non-zero if any of that did not happen.
set -u
DB=${DB:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

q() { psql "$DB" -v ON_ERROR_STOP=1 -At -q "$@"; }
as() { # user, sql
  q <<SQL
begin;
select set_config('request.jwt.claims', json_build_object('sub', '$1', 'role', 'authenticated')::text, true);
select set_config('request.jwt.claim.sub', '$1', true);
set local role authenticated;
$2
commit;
SQL
}

SELLER=$(q -c "select id from auth.users order by created_at desc limit 1")
BUYER=$(q -c "select id from auth.users where id <> '$SELLER' order by created_at desc limit 1")
if [ -z "$SELLER" ] || [ -z "$BUYER" ]; then
  echo "no users to borrow: run the RLS suite first" >&2
  exit 2
fi
SELLER_G=$(as "$SELLER" "select public.create_household('Race seller');" | tail -1)
BUYER_G=$(as "$BUYER" "select public.create_household('Race buyer');" | tail -1)

car() { as "$SELLER" "insert into public.vehicles (household_id, nickname, fuel_type_key, created_by) values ('$SELLER_G', 'Race car', 'fuel_petrol', '$SELLER') returning id;" | tail -1; }
offer() { as "$SELLER" "select public.create_vehicle_transfer('$1');" | tail -1; }
passes() { q -c "select count(*) from public.vehicle_guest_passes where vehicle_id = '$1' $2"; }
garage_of() { q -c "select household_id from public.vehicles where id = '$1'"; }
# Sessions blocked on a lock whose statement names $1. The observer's own
# statement names it too, and is running rather than waiting.
waiting() { q -c "select count(*) from pg_stat_activity where wait_event_type = 'Lock' and query like '%$1%' and pid <> pg_backend_pid()"; }

failed=0
fail() {
  echo "FAIL: $*" >&2
  failed=1
}

# user, sql, name: the first transaction, held open for three seconds.
hold() { as "$1" "$2 select pg_sleep(3);" >"$TMP/$3.out" 2>"$TMP/$3.err"; }
# user, sql, name: the second, started a second into the first.
contend() { as "$1" "$2" >"$TMP/$3.out" 2>"$TMP/$3.err"; }

for mint in "public.create_guest_pass('%s', 7)" "public.create_guest_pass_between('%s', now() + interval '7 days')"; do
  name=${mint%%(*}

  # The sale first, holding its transaction open while the seller mints.
  car1=$(car)
  code1=$(offer "$car1")
  hold "$BUYER" "select public.redeem_vehicle_transfer('$code1', '$BUYER_G');" sale1 &
  sale=$!
  sleep 1
  contend "$SELLER" "select $(printf "$mint" "$car1");" mint1 &
  minting=$!
  sleep 1
  [ "$(waiting "$car1")" = "1" ] || fail "$name did not wait for a sale under way"
  wait $sale || fail "the sale did not go through: $(cat "$TMP/sale1.err")"
  if wait $minting; then
    fail "$name minted a pass on a car its garage had just sold"
  elif ! grep -q "not a member of the garage" "$TMP/mint1.err"; then
    fail "$name was refused for another reason: $(cat "$TMP/mint1.err")"
  fi
  [ "$(garage_of "$car1")" = "$BUYER_G" ] || fail "the first car was not sold"
  [ "$(passes "$car1" "")" = "0" ] || fail "$name left a pass on a car sold first"

  # The mint first, holding its transaction open while the buyer redeems.
  car2=$(car)
  code2=$(offer "$car2")
  hold "$SELLER" "select $(printf "$mint" "$car2");" mint2 &
  minting=$!
  sleep 1
  contend "$BUYER" "select public.redeem_vehicle_transfer('$code2', '$BUYER_G');" sale2 &
  sale=$!
  sleep 1
  [ "$(waiting "$code2")" = "1" ] || fail "a sale did not wait for $name under way"
  wait $minting || fail "$name was refused before any sale: $(cat "$TMP/mint2.err")"
  wait $sale || fail "the sale did not go through: $(cat "$TMP/sale2.err")"
  [ "$(garage_of "$car2")" = "$BUYER_G" ] || fail "the second car was not sold"
  [ "$(passes "$car2" "")" = "1" ] || fail "$name did not leave the one pass it minted"
  [ "$(passes "$car2" "and revoked_at is null")" = "0" ] ||
    fail "$name left a live pass on a car sold after it"
done
[ "$failed" = 0 ] && echo "ok: each sale waited for a mint or a mint for the sale, and no sold car kept a live pass"
exit $failed
