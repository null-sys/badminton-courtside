-- Set or change the team PIN. Replace the text between the quotes, then Run.
-- Use 6+ characters; anyone who knows it can log and delete matches.
-- Only a hash is stored, so if you forget it, just run this again with a new one.

insert into public.team_secret (id, pin_hash)
values (1, extensions.crypt('CHANGE-ME', extensions.gen_salt('bf')))
on conflict (id) do update set pin_hash = excluded.pin_hash;
