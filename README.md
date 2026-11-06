# Run to Heaven

A Bible runner game in one HTML file. Run through the land of the Bible, pick up all 66 books, and reach heaven.

- `index.html` is the whole game. It is the web build of the game source.
- The leaderboard is a Supabase database (`setup.sql`). Anyone can read it. Scores go in only through the
  `submit_score` function, which checks each score. No player account is needed: each browser keeps a random
  player id, and the board shows only a hash of it.
- The page holds the project URL and the publishable key. That key is meant to be public. Never put a secret or
  service-role key in the page.

To remove a score: Supabase dashboard → Table Editor → `scores` → delete the row.
