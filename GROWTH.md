# Growth

How to grow the userbase for an unofficial Nexus Mods image browser. Companion to `IDEAS.md`: several features
there (wallpapers, widgets, sharing, adult gate) are really growth features, and they are cross-referenced below.

The honest starting point: this is a niche app serving an existing community. Growth will not come from broad
consumer channels; it comes from (1) being findable where modders already are, (2) giving existing users reasons
to show the app to others, and (3) converting the app's genuinely novel surface (the planetarium) into shareable
marketing material.

## Prerequisites before pushing for users

Things that cap growth until they are done, roughly in order:

- **Store readiness.** The adult-content gate (IDEAS Tier 1) is the blocker for a clean Play Store content
  rating and for any promotion at all. Alongside it: a privacy policy page, the Play data-safety form (easy,
  since the app stores nothing off-device today), and a completed rating questionnaire.
- **Listing quality (ASO).** The store listing is the landing page for every channel below. Title and short
  description should carry the search phrases people actually type: "nexus mods", "skyrim wallpapers",
  "game screenshots", "modding". Screenshots exist via the `generate-screenshots` skill; add a 15 to 30 second
  video, led by the planetarium, which is the one visual no competing app has.
- **A share loop that credits the app.** Sharing currently sends a bare Nexus page URL. Append a light
  "shared from ..." line with the Play Store link so every shared image is a small ad. Keep it tasteful: the
  image link first, the plug second.
- **Naming and trademark posture.** "Unofficial" in the name is the right defensive move, but decide the
  relationship with Nexus Mods explicitly (see the partnership item below) before spending effort promoting a
  name that might have to change.

## General approaches

Standard mobile growth mechanics, filtered for what fits a free niche utility:

- **In-app review prompt.** Use the Play In-App Review API at a moment of demonstrated value, for example after
  the fifth favourite is saved or the first wallpaper is set. Ratings feed the store ranking loop directly.
- **Retention is the multiplier.** Installs from a Reddit post decay in days; the IDEAS Tier 3 items are what
  bring people back: daily wallpaper rotation, the home screen widget, followed games. Prioritise one retention
  hook before any big promotion push so a spike of installs has something to stick to.
- **Measure the funnel, minimally.** Play Console gives installs, retention and crash rates for free. Decide
  deliberately whether to add any in-app analytics; "no tracking at all" is itself a marketable feature to this
  privacy-conscious audience, and can be stated on the listing. If added, keep it to anonymous counts of a few
  key events (search, favourite, wallpaper set).
- **Localisation.** Modding is big in Germany, France, Brazil, Poland, Russia, China. The UI has few strings;
  localising the store listing alone (cheap) widens search reach, and localising the app can follow if listing
  translations show traction.
- **iOS later.** The project already targets iOS. Every channel below reaches iPhone users who currently bounce.
  Treat it as a growth lever to pull once Android retention looks healthy, not before.

## Specific to this app and community

- **The planetarium is the marketing asset.** A slowly gliding sphere of game art is inherently clip-able.
  Produce a few 10 to 20 second screen recordings (Skyrim sphere, Cyberpunk sphere) and use them everywhere: the
  store video, Reddit posts, YouTube Shorts / TikTok. "I built a 3D planetarium of Nexus Mods images" is a
  strong r/SkyrimModding or r/FlutterDev post title; developer-story framing does numbers on both gaming and dev
  subreddits and doubles as recruitment of contributors.
- **Go where modders are, respecting self-promo rules.** One well-made post each, not a spam campaign: the
  Nexus Mods forums (app-and-tools section), r/nexusmods and per-game modding subreddits (r/skyrimmods,
  r/FalloutMods and similar have strict promo rules, so lead with the tool's usefulness), and the large modding
  Discords. Time these to moments when modding interest spikes: a big game release, a major mod launch, a Nexus
  event.
- **Court mod authors.** Authors are the influencers of this ecosystem, and the app literally showcases their
  work. The author-view feature (IDEAS Tier 2) is the hook: reach out to prolific image posters, show them their
  own gallery in the sphere, and many will mention it to their followings unprompted. Consider a "featured
  author" rotation in-app once author view exists.
- **Pursue a blessing from Nexus Mods.** The single highest-leverage move available. Options in ascending
  order: explicit written permission for the name and API use (removes existential risk), a mention in a Nexus
  blog post or community roundup (their reach is the entire target market), or adoption as an official companion
  app. Even the minimal version changes what promotion is safe to invest in.
- **Own the wallpaper niche.** "Skyrim wallpaper", "Fallout wallpaper" and similar are high-volume, evergreen
  searches with weak, ad-stuffed incumbents. Once set-as-wallpaper and daily rotation ship (IDEAS Tier 3), the
  listing can honestly target those keywords, and wallpaper-focused subreddits and roundup articles become
  channels. This is the likeliest source of users from outside the modding community.
- **Consider open-sourcing.** There is currently no license (all rights reserved). Opening the repo enables an
  F-Droid listing (a real distribution channel for this audience), makes the "I built this" developer posts more
  credible, invites contributors, and fits the modding community's ethos. The cost is mainly the decision itself
  plus a small cleanup pass.
- **An "image of the day" social presence.** A low-effort account (Bluesky/X/Mastodon, where modding communities
  live) posting one striking community image daily with credit to the author and a link. It compounds slowly,
  costs minutes a day, and could later be automated.

## What not to do

- Paid install campaigns: the audience is too niche for broad UA to pay back on a free app with no monetisation.
- Aggressive cross-posting: modding subreddits ban for it, and the community has a long memory.
- Notification spam as "re-engagement": one well-chosen hook (new images from followed games, opt-in) is the
  ceiling.

## Suggested order

1. Store readiness: adult gate, privacy policy, ASO pass on the listing with planetarium video.
2. Share-loop attribution and the in-app review prompt: tiny changes that make all later traffic compound.
3. One retention hook (daily wallpaper or widget), so promotion spikes convert to weekly actives.
4. The launch push: developer-story posts with planetarium clips, timed to a modding news moment, plus the
   Nexus Mods conversation about permission or promotion.
5. Longer burns afterwards: author outreach, wallpaper-niche ASO, open-source and F-Droid, image-of-the-day
   account, iOS.
