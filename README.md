# Badminton Courtside

Ladder and stats for our singles and doubles group: ratings, weekly form, player profiles and a full match log.
Anyone with the link can view. Logging or editing matches and adding players needs the team PIN.

- `index.html` – the whole site
- `logo.svg` – logo and browser icon
- `config.js` – your Supabase URL and anon key
- `supabase/schema.sql` – tables, access rules and save functions
- `supabase/set-pin.sql` – sets or changes the team PIN

## Setup (about 10 minutes)

### 1. Create the database
1. In Supabase, click **New project**. Pick a name (e.g. `rally-ladder`), a database password and the region closest to you. Wait for it to finish starting.
2. Open **SQL Editor** → **New query**, paste all of `supabase/schema.sql`, and click **Run**. You should see "Success. No rows returned".
3. New query again, paste `supabase/set-pin.sql`, replace `CHANGE-ME` with your team PIN, and click **Run**.

### 2. Connect the site
1. In Supabase, go to **Project Settings → API** (or **Data API**).
2. Copy the **Project URL** and the **anon public** key into `config.js`.
   Never use the `service_role` key here: it bypasses every rule.

### 3. Put it online with Netlify
Easiest: go to <https://app.netlify.com/drop> and drag the whole `rally-ladder` folder onto the page.
Netlify gives you a link like `https://something-random.netlify.app`. Rename it under **Site configuration → Change site name**.

To update the site later, open the site in Netlify → **Deploys** → drag the folder in again.

Or with the Netlify CLI:

```bash
npx netlify-cli deploy --prod --dir .
```

### 4. Share
Send the link and the PIN in your team chat. On phones, open the link and use **Add to Home Screen**.

## Day to day
- **+ Log match** (the page opens here): pick players, enter the score, tap **Save match**, check the summary (winner, score, rating change), then **Confirm & save**. **Reset** clears the form. Unusual scores such as 21–20 get a warning before saving.
- **Matches**: every game grouped by week. Unlock, then **Edit** to fix players, score or date, or delete it.
- **Players**: tap anyone for their profile: rating, streak, who they beat most, best partners and toughest opponents.
  **Performance** has three views: **Week** (split by day), **Month** and **Lifetime** (split by week). Each shows rating change, record, points and a trend (rising, steady or falling, from the slope of their rating over that period). Use ‹ › to step back through earlier weeks or months.
- Unlock once per phone with the PIN; it's remembered on that device. **Lock** forgets it.
- To change the PIN, run `set-pin.sql` again. Everyone re-enters the new one.

## Upgrading from Rally Ladder / Courtside
Editing matches needs one new database function. In Supabase → **SQL Editor**, paste all of `supabase/schema.sql` again and **Run**. It keeps your data.

## Notes
- Ratings are Elo-based: everyone starts at 1000 and ratings are recalculated from the full match history on every load. Bigger winning margins and upsets move ratings more. Deuce games (22–20, 25–23, 30–29) count as the closest possible result.
- Supabase pauses free projects after about a week with no activity. Opening the site normally keeps it awake; if it does pause, click **Restore** in the Supabase dashboard.
- Backup: Supabase → **Table Editor** → `matches` / `players` → **Export to CSV**.
