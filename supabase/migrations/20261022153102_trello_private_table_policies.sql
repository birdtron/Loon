create policy no_direct_access on private.actor_checkins for all to authenticated using(false) with check(false);
create policy no_direct_access on private.production_messages for all to authenticated using(false) with check(false);
create policy no_direct_access on private.production_message_likes for all to authenticated using(false) with check(false);
