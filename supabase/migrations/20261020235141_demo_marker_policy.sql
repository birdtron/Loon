-- Explicitly deny direct access to server-owned read-only account markers.
create policy no_direct_demo_marker_access on private.read_only_users for all to authenticated using(false) with check(false);
