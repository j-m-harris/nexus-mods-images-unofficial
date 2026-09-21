# Growth

How to grow the audience for Nexus Mods Images Unofficial. Written September 2026 against v1.4.2 and the live Play
Store listing. It replaces the July 2026 version, which was written before the app had a public audience. Product
features referenced below live in `IDEAS.md`.

## Where the app stands

The app is a Flutter viewer for the public Nexus Mods image feed: infinite feed, search, game and category filters,
five sort orders, a lightbox with zoom and swipe, local favourites, share, and a 3D planetarium layout built on
Flutter GPU. Adult-flagged images sit behind a blur by default with a one-time 18+ confirmation. Nothing is tracked
and there are no ads.

The Play Store listing on 21 September 2026:

| Item | Live value |
| --- | --- |
| Title | Nexus Mods Images Unofficial |
| Downloads | 1K+ (the tier covers 1,000 to 4,999) |
| Rating | None displayed (too few ratings to show one) |
| Content rating | Everyone |
| Category | Entertainment |
| Short description | Browse the latest images on Nexus Mods. |
| Full description | One further sentence. The feature list stored in the repo's Play listing folder is not live. |
| Screenshots | 8, no video |
| Data safety | No data collected, no data shared |
| Privacy policy | Linked (hosted on GitHub) |
| Last update | 20 July 2026 (v1.4.2) |

The installs arrived with no promotion anywhere. Web searches for the app name find only the Play listing and an APK
mirror. So the 1K+ is organic Play search traffic, mostly people typing "nexus mods" into the store and finding an
app with the name in its title. That is the baseline every idea below has to beat.

## What happened to the July plan

Done since July: the adult content gate and 18+ confirmation, the one-time in-app review request, layout persistence,
lightbox swiping, a privacy policy on the listing, and the data safety form.

Not done: the share message still sends a bare title and page URL, the listing copy was never expanded, no retention
hook shipped, no community post was made, the Nexus Mods conversation did not happen, there is no licence, and iOS
and localisation are untouched.

## Protect the audience before growing it

Two policy exposures could remove the listing. A removed listing resets the count to zero, so they come first.

**Play user-generated content policy.** The policy covers "apps which are specialized browsers or clients to direct
users to a UGC platform", which describes this app exactly. It requires "an in-app system for reporting and blocking
objectionable UGC and users". The app has neither. Add a Report action to the lightbox that opens the image's Nexus
Mods report flow in the browser, and a local hide-this-author option. Both are small. Sexual content in a UGC app
must be "hidden by default behind filters that require at least two user actions" to disable; the current settings
change plus confirmation dialog meets that, so document it in the Play content questionnaire.

**Content rating.** The listing is rated Everyone while the feed carries adult-flagged images behind a blur. Redo
the rating questionnaire truthfully, declaring user-generated content and the adult filter. Expect Teen or Mature
17+. A higher rating costs some discoverability to under-17 accounts but survives a policy review. Everyone does not.

**Nexus Mods API acceptable use policy.** The policy says that once "a public-facing application has left the
testing stage" the developer should contact support@nexusmods.com to register it. It also requires an
`Application-Version` header on every request; the app sends `Application-Name` only. Add the header in
`lib/services/nexus_api.dart` and register the app. Registration is also the natural opening for the promotion
conversation below. The policy says Nexus Mods "strongly encourage" open-source licensing and that including source
speeds approval, which strengthens the case for a licence.

**Naming.** The title carries the Nexus Mods trademark with "Unofficial" appended. That is the right defensive
posture. It is also what makes the app rank for the store search that produced every install so far. Get
explicit written permission for the name during registration. Do not spend on promoting the name until that
answer is in.

## Levers, in order of expected return

### 1. Fix the listing

The listing converts store search into installs and is the cheapest lever by far.

- **Publish the full description.** The repo already holds a feature list that never reached the store. Rewrite it
  around what people search for: nexus mods, mod screenshots, Skyrim, Fallout, Cyberpunk, Baldur's Gate, game
  art, wallpapers. Mention the planetarium, favourites, no ads and no tracking. Name the top games explicitly,
  because Play indexes the description.
- **Short description.** Replace the current sentence with one that carries keywords, for example "Browse Nexus
  Mods screenshots and artwork from thousands of modded games. No ads, no tracking."
- **Add a video.** A 20 second capture of the planetarium gliding, cut to the grid and lightbox. It is the one
  visual no other app on the store has. The `generate-screenshots` skill already drives the emulator; the same
  approach records the video.
- **Screenshots with captions.** The current eight are raw captures. Add one-line captions on the first three
  (feed, sphere, favourites) so they read in the store carousel.
- **Localise the listing.** Modding has large communities in Germany, France, Brazil, Poland, Russia, Japan and
  China. Translating the title suffix, short and full description is a day's work and widens store search reach
  without touching the app.
- **Get a rating displayed.** A listing with no star rating converts worse than one with 4.5. See lever 2.

### 2. Get ratings

The review prompt fires once, after the fifth favourite. Most users never save five favourites, so most users are
never asked. The listing still has no visible rating after two months and 1K+ installs. Widen the trigger while
keeping it to one request per install:

- Ask after the fifth favourite, or after the third session on a different day, or after the first share, whichever
  comes first.
- Keep using the Play In-App Review API. Google throttles it, so this cannot become spam.

The `ReviewService` already tracks the one-shot state; the change is adding triggers.

### 3. Make sharing carry the app

Every share currently sends a title and a URL that opens nexusmods.com. Nobody who receives it learns the app
exists. Change the share text to the image title, the Nexus Mods page URL, then a second line with the Play link.
Add a "share image" option that sends the file itself via `share_plus`, since chat apps render images inline and a
rendered image gets forwarded. Keep the image link first and the plug last.

### 4. Distribute inside Nexus Mods

The whole target audience is already on nexusmods.com, its forums and its Discord. The author has a direct line to
the Nexus Mods team, which makes these channels cheaper than for any outside developer.

- **List the app on Nexus Mods itself.** The Modding Tools section already hosts a browser extension for previewing
  Nexus media (site mod 2149). An Android app that browses Nexus images fits the same section. A mod page gets the
  app in front of users searching Nexus for tools. Every Nexus mod page is also indexed by Google.
- **Forums and Discord.** One post each: the tools forum, and the Nexus Mods Discord, which had about 124,000
  members in July 2026. Lead with the planetarium clip and the "no ads, no tracking" line.
- **Screenshot community events.** Nexus Mods runs screenshot events with their own news posts. The app is the
  natural way to browse entries on a phone. Time a post to the next event and ask whether the event write-up can
  mention it.
- **Social accounts.** Nexus Mods posts on Bluesky and X. One post of the planetarium video from an official account
  would outdo everything else in this document combined. This is the ask to make during API registration, once the
  UGC and rating fixes are in place so the app can withstand the attention.
- **Deep links.** Register the app for nexusmods.com image URLs so links shared in Discord and Reddit open in the
  lightbox. On Android 12 and later this only works by default when nexusmods.com hosts an `assetlinks.json` naming
  the app, which needs Nexus Mods cooperation. Add it to the registration conversation. Until then, unverified
  deep links still appear in the "open with" chooser.

### 5. Ship one retention hook

Play ranks apps partly on retention. A promotion spike with nothing to come back for decays within days.
Retention features in `IDEAS.md`, in order of return:

- **Set as wallpaper.** Game screenshots are exactly what wallpaper apps sell. This one action opens the wallpaper
  niche, where store searches for "skyrim wallpaper" and similar are large and the incumbents are ad-heavy
  catalogues of scraped images. The app has a live, credited, searchable source they cannot match.
- **Daily wallpaper rotation** from favourites or a saved search. This is the hook that made Backdrops and Muzei
  daily-use apps. A Muzei provider is a cheap extra integration for that audience.
- **Followed games** with a Following feed. Most users care about two or three games. It is also the foundation for
  an opt-in "new images from your games" notification, which is the only re-engagement notification worth
  sending.
- **Home screen widget** showing a random favourite.

Ship wallpaper before any promotion push. Once it exists the listing can target wallpaper keywords truthfully.

### 6. Developer-story content

The planetarium is a Goldberg sphere of recycling GPU textures built on flutter_scene and flutter_gpu. That is
unusual enough to carry a post on its own.

- A short write-up with clips for r/FlutterDev and the Flutter community Discord. Flutter GPU is new and the team
  and community look for apps that use it, so this can travel further than a gaming post.
- The same clip, framed as "I built a 3D planetarium of Nexus Mods images", for r/skyrimmods, r/nexusmods and the
  per-game modding subreddits. Read each subreddit's self-promotion rule first and post once.
- YouTube Shorts and TikTok take the raw clip with no editing. Cost is minutes.

### 7. Open the source

There is no licence, so the repo is all rights reserved. Opening it does three things: satisfies the Nexus Mods API
policy's preference, makes the developer-story posts credible, and enables direct APK distribution through GitHub
releases, which this audience installs via Obtainium. F-Droid is a poorer fit than the July plan assumed, because
the app builds on the Flutter master channel for flutter_gpu, which makes F-Droid's reproducible builds
impractical until that lands in stable. Pick a licence, add a contributing note, and publish.

### 8. Later: iOS and app localisation

The iOS project exists but has no signing. Every channel above reaches iPhone users who bounce. Hold iOS until
Android retention is measured and healthy, because the Apple developer fee and review process are a fixed cost that
only pays back once the channels are producing. App localisation follows listing localisation only if the
translated listings show installs.

## Marketing with the app unchanged

Everything in this section brings the current build to more people without a release. The store listing counts as
marketing here, since it is not the app, but its changes are covered under lever 1 and are not repeated.

One caveat carries through the whole section. Attention raises the chance of a Play policy review. The gaps in
"Protect the audience before growing it" stay unfixed until a release ships. Anything that could go large, such as
an official Nexus Mods post or a front-page Reddit thread, is better held until that release is out. Everything
else can start today.

Install figures below are estimates from the channel sizes and typical conversion for a free niche app. They are
not measurements. Check them against the Play Console acquisition report after each action and revise.

### Owned channels

**Landing page.** A one-page site (GitHub Pages is free) with the planetarium video, three screenshots and the Play
button. Google searches for "nexus mods app android" currently return a look-alike app and APK mirrors, so a page
with that phrase in its title has an open field.
Pros: permanent. It gives every post below a link that is not a raw Play URL and collects search traffic for years.
Cons: slow to rank. A page alone brings few installs.
Effort: half a day. Return: tens of installs a month, compounding. Worth doing first because it multiplies
everything else.

**Third-party listings already out there.** Softonic and Kotaku's download pages already list unofficial Nexus Mods
apps. A Softonic page for this app exists. Claim the developer entries, correct the descriptions and add the
Play link.
Pros: an hour, no ongoing cost.
Cons: these pages mostly serve people avoiding Play, so few of them convert.
Return: low, but positive and free.

**Alternative Android stores.** Submit the existing release bundle to Uptodown, APKPure, Aptoide, the Samsung
Galaxy Store and the Amazon Appstore, and to Huawei AppGallery and RuStore for regions where Play is weak.
Pros: submit once, installs continue. Reaches devices without Play services.
Cons: separate developer accounts and review queues. Updates have to be pushed to each store. Installs do not
count towards the Play tier. One indie-marketing writeup (ShippedSolo) puts the uplift at 5 to 30 percent of Play
installs; treat the low end as realistic for a niche app.
Effort: a day for the first round, an hour per release after. Return: moderate and steady.

### Community posts

**Reddit.** The relevant subreddits and their sizes: r/skyrimmods (532k), r/androidapps (573k), r/FalloutMods (66k),
r/nexusmods (34k), r/FlutterDev (179k), plus the per-game subreddits for Cyberpunk, Baldur's Gate 3, Stardew Valley
and Starfield. One post per subreddit, tailored, spaced over weeks, with the planetarium clip as the media.
Pros: the largest concentration of the target audience anywhere, for free. A post that lands brings a same-day
spike in the hundreds.
Cons: self-promotion rules are strict on the modding subreddits and moderators remove posts that read as adverts.
Installs decay within days. A failed post costs the option to post again for months.
Effort: two hours per post. Return: a landed post on r/skyrimmods or r/androidapps is worth an estimated 200 to
2,000 installs. Most posts do not land. Expected value is still the best of any free channel.

**Nexus Mods forums and a Modding Tools page.** Covered in lever 4. Neither needs an app change. The Modding Tools
page is the one listing on the internet that puts the app in front of people already browsing Nexus for tools.
Return: moderate and permanent, at a couple of hours' cost.

**Discord.** The Nexus Mods server had about 124,000 members in July 2026. Large per-game modding servers exist for
every major title.
Pros: direct reach to the most engaged modders. A pinned mention in a tools channel persists.
Cons: messages scroll away in minutes. Most servers forbid unsolicited promotion. Installs from a single
message are in the tens.
Effort: an hour. Return: low per server unless a moderator pins it or the Nexus team adopts it.

**Hacker News and the Flutter community.** A Show HN post about building a recycling Goldberg-sphere renderer on
flutter_gpu, cross-posted to r/FlutterDev and the Flutter Discord.
Pros: zero cost, with a long ceiling if it reaches the front page. Flutter GPU is new enough that the Flutter team
and newsletters (Flutter Weekly, Android Weekly) pick up showcase apps.
Cons: the audience is developers, not modders. A front-page thread produces reads and stars, not many installs.
Effort: half a day to write it well. Return: an estimated 100 to 500 installs from a front-page hit, plus the
credibility and backlinks that help the landing page rank. Do it, but for the second-order effects.

**Product Hunt and launch directories.** Product Hunt, AlternativeTo, SaaSHub, Uneed and similar.
Pros: near-zero effort each, permanent backlinks.
Cons: an Android image viewer for a modding site is far outside their audiences. Expect single-digit installs.
Return: low. Do AlternativeTo and Product Hunt for the links and skip the rest.

**Answering the question where it is asked.** Steam community threads, Quora and Reddit searches for "is there a
Nexus Mods app for Android" already exist. A short, factual answer with the Play link in each.
Pros: evergreen, each answer keeps converting the exact search intent for years.
Cons: looks like spam if done in bulk. Limit to threads where the question is asked plainly.
Effort: an hour a month. Return: low volume, high intent, very high return per minute spent.

### Content

**Short video.** Ten to twenty second captures of the planetarium gliding through Skyrim or Cyberpunk art, posted to
TikTok, YouTube Shorts and Instagram Reels with the game hashtags. No editing beyond a caption.
Pros: the sphere is the one visual nobody else has. Capture costs minutes. The platforms distribute to
non-followers by default. The clips are reusable across every other channel here.
Cons: reach is a lottery. Links are awkward on TikTok and Instagram. Viewers of a Skyrim clip do not
necessarily own an Android phone. Conversion from view to install is well under one percent.
Effort: an afternoon for a batch of ten clips. Return: highly variable, from nothing to several hundred installs
per clip that catches. Cheap enough to run continuously.

**Image of the day account.** A Bluesky, X or Mastodon account posting one striking community image daily with
the author credited and the Play link in the profile. Pinterest is the strongest fit of the four: it is an image
search engine, pins are evergreen and "skyrim wallpaper" style searches are exactly its traffic.
Pros: minutes a day. It compounds. A script against the same API the app uses can automate it without
touching the app.
Cons: slow to build. Reposting images needs care over author credit and adult flags.
Effort: an hour to set up, minutes a day after. Return: near zero for months, then a steady trickle. Pinterest
is the version most likely to pay.

**A written build story.** A blog post on the landing page or dev.to about the planetarium, the recycling texture
pool and shipping on Flutter master.
Pros: the same post feeds Show HN, r/FlutterDev and newsletter pickups. It also ranks for Flutter GPU searches.
Cons: developer readers, few installs.
Effort: a day. Return: low in installs, moderate in reach and links.

### Outreach

**Nexus Mods official channels.** Covered in lever 4. One post from an official Bluesky or X account, or a line in
a Nexus news roundup, is the highest-return action available at any price.
Pros: the entire target audience, with the trust of the platform behind the mention.
Cons: depends on someone else's decision and on the app being in a state they are happy to endorse. Hold until
the compliance release is out.
Return: an estimated 1,000 to 10,000 installs from a single post.

**Mod authors and screenshot artists.** Prolific image uploaders on Nexus have followings on Nexus, Reddit and
social media. Send each a clip of their own gallery in the sphere.
Pros: the app flatters their work, so a good share of them post it unprompted. Their audiences are exactly the
target.
Cons: manual, one person at a time. Some will object to their images appearing in a third-party app.
Effort: fifteen minutes per author. Return: unpredictable per author, moderate in aggregate over twenty or thirty
contacts.

**YouTubers and streamers who showcase mods.** Send the clip and the Play link to channels that make "Skyrim in
2026 looks insane" style videos and mod-list showcases.
Pros: a single mention in a large channel outperforms months of posting. The sphere works as B-roll, which makes it
easy for them to use.
Cons: low hit rate, since most never reply. An image browser is a weak story for a video about mods.
Effort: a couple of hours for a list of thirty channels. Return: low probability, high payoff.

**Tech press.** Android Police, XDA, 9to5Google and Android Authority run app roundups. PC Gamer, Rock Paper Shotgun
and Kotaku cover modding.
Pros: one article beats every other channel here. Articles rank in search for years.
Cons: an unofficial image browser is a hard pitch. The hook is the planetarium and the "no ads, no tracking"
posture. Expect most pitches to be ignored.
Effort: half a day for a press page and ten emails. Return: low probability, very high payoff. Send the pitches
once the Nexus permission answer is in, since that is what makes the story safe to print.

### Paid

**Google Ads app campaigns.** Cost per install for a free entertainment app is roughly fifty pence to two pounds.
Pros: precise and instant. Play counts the installs.
Cons: the app earns nothing, so every install is pure cost. Paid installs also retain worse than organic ones.
Return: negative in money. Only worth a small fixed budget as an experiment to measure listing conversion.

**Reddit ads.** Targeted at r/skyrimmods and r/androidapps.
Pros: cheaper impressions than Google and the targeting is exactly the audience.
Cons: the same absence of revenue. Reddit users are hostile to ads for hobby-adjacent apps.
Return: negative in money, though a small test would show whether the audience converts before committing effort to
organic Reddit posts.

**Sponsoring a modding newsletter or YouTuber.** Priced from tens to thousands of pounds per placement.
Pros: borrowed trust and a guaranteed slot.
Cons: expensive for a free app. The free outreach above reaches the same people at zero cost with a lower hit
rate.
Return: negative unless the goal is reach regardless of cost.

### Summary

| Channel | Effort | Ongoing cost | Estimated installs | Confidence |
| --- | --- | --- | --- | --- |
| Nexus Mods official post | Ask, once compliant | None | 1,000 to 10,000 | Medium |
| Reddit posts | 2 hours each | None | 200 to 2,000 per landed post | Medium |
| Store listing changes (lever 1) | 1 day | None | Lifts conversion on all traffic | High |
| Landing page | Half a day | None | Tens a month, compounding | High |
| Alternative stores | 1 day, then 1 hour per release | Low | 5 to 30 percent uplift | Medium |
| Modding Tools page and forum | 2 hours | None | Moderate, permanent | Medium |
| Short video clips | Afternoon per batch | None | 0 to hundreds per clip | Low |
| Mod author outreach | 15 minutes each | None | Moderate in aggregate | Low |
| Answering "is there an app" threads | 1 hour a month | None | Low volume, high intent | High |
| Show HN and Flutter community | Half a day | None | 100 to 500, plus links | Medium |
| Image of the day (Pinterest) | 1 hour, then minutes daily | None | Trickle after months | Low |
| YouTubers and press | Half a day | None | Low probability, high payoff | Low |
| Discord | 1 hour | None | Tens per server | Medium |
| Product Hunt and directories | 1 hour | None | Single digits, backlinks | High |
| Paid ads | Minutes | Per install | Whatever the budget buys | High |

Reading the table: do the landing page, listing changes and the evergreen answers first because they lift every
later channel. Then the Modding Tools page and the first Reddit post. Run video clips continuously in the
background. Hold the Nexus Mods ask and press pitches until the compliance release ships.

## Measure

Play Console provides everything needed without adding tracking, so "no tracking" stays a listing claim.

Watch weekly:

- Store listing conversion rate, before and after the listing changes in lever 1.
- Day 1, day 7 and day 30 retention, before and after the wallpaper hook.
- Ratings count and average.
- Acquisition by source, to see whether any community post moved the needle beyond Play search.

Target: the 10K+ download tier. At the current organic rate that would take years. Levers 1 to 4 should reach it
inside six months if the conversion rate and the Nexus Mods channels perform as expected.

## What not to do

- Paid installs. The audience is narrow and the app earns nothing.
- Cross-posting the same text to many subreddits. Modding subreddits ban for it.
- More than one review request per install, or any request outside the Play API.
- Notifications beyond an opt-in "new images from followed games".
- Promoting the name before Nexus Mods has confirmed it is acceptable.

## Order of work

1. Compliance: Report action, hide-author option, content rating questionnaire, `Application-Version` header, API
   registration with the name permission ask. One release.
2. Listing pass: full and short description, captioned screenshots, planetarium video, localised listings. No
   release needed.
3. Ratings and share attribution. One small release.
4. Set-as-wallpaper, then daily rotation. One or two releases.
5. Distribution: Nexus Mods Modding Tools page, forum and Discord posts, developer-story posts, the ask for an
   official social post and the `assetlinks.json`.
6. Longer burns: followed games, widget, open source and Obtainium, listing translations that show traction, iOS.
