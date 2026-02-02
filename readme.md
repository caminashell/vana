
# Vana

`Vana` is an assistant that provides helpful event alerts and reminders to enhance experience in Final Fantasy XI. This addon is a purposefully stripped-down alternate (spin) of the orginal `Helper (v2.3.2)` addon by Keylesta (see [History of Helper](#history-of-helper)), optimised for performance and stability.

>
> [!CAUTION]
> This project is currently in a development state and is not ready for reliable use.
> You may download and use it, but it is not recommended until I have actually created a release.

## Core Features

- <ins>**Automated Notifications & Alerts**</ins>
  - **Ability Ready Alerts** → Notifies you when an ability is ready to use.
  - **Job Points & Merit Points Capped** → Alerts you when you reach the max.
  - **Party & Alliance Updates** → Get messages when members join or leave.
  - **Key Item Reminders** → Never forget to pickup a Mystical Canteen, Moglophone, or Shiny Ra'Kaznarian Plate again.
  - **Sublimation Charged** → Tells you when Sublimation is fully charged.
  - **Vorseal Wearing** → Notifies you when your Vorseal buff is about to expire.
  - **Mireu Pop Alerts** → Notifies you when the NM Mireu is mentioned.
  - **Mog Locker Expiring** → Don't let your Mog Locker lease expire.
  - **Reraise Check** → A safety awareness check.
  - **Sparks Reminder** → Reminds you to spend your Sparks and Accolades.
- <ins>**Enhanced Party Awareness**</ins>
  - **Low MP Warnings** → Alerts you if a party member needs Refresh.
  - **Party & Alliance Updates** → Get messages when members join or leave.
  - **You Became Party/Alliance Leader** → Tells you when you’re promoted to leader.

## Differences to Helper

- <ins>**Features**</ins>
  - **The "Vana" helper profile is the only one available.**
  - **There is minimal customization available.**
  - **You cannot create, load, or unload helpers.**
  - **There is no "flavor text" feature.**
  - **There is no "voices" feature.**
- <ins>**Runtime**</ins>
  - **Main process runs on the `time change` (every ~3s) and not `prerender` (every frame) event.**
  - **Group tracking is only active when a party is active.**
  - **Operates using data from an internal table namespace.**
  - **Uses event listeners to process notifications.**
  - **Refined checks for various flags and statuses.**
  - **Never calls the internet to pull down resources.**
  - **Debug and performance monitoring options are available.**

## History of Helper

> _The Helper addon acts as a customizable in-game assistant that provides alerts, notifications, and flavor text to enhance the player's experience. The addon features a system of "Helpers"—virtual companions that deliver messages in chat, track important gameplay events, and provide reminders. The default Helper, Vana, offers encouragement, alerts players about key game mechanics (such as abilities becoming ready or capped job/merit points), and notifies them of party-related events like members joining or leaving._
>
> _Players can load different Helpers, each with its own personality and dialogue, and cycle between them. The addon also supports sound effects for key notifications and reminders for gameplay mechanics like Sublimation being fully charged or Vorseal effects nearing expiration. With its blend of functionality and personality, Helper adds both utility and charm to the FFXI experience._

For more info, see the [original Helper addon](https://github.com/iLVL-Key/FFXI/tree/main/addons/Helper).

## How To Setup

1. Download the latest release from the [Releases](https://github.com/caminashell/vana/releases) page.

## Commands

All commands must be preceded with  `//vana`
`<required>` `[optional]`

| Command | Description |
|---------|-------------|
| *(blank, no command)* | Cycle to the next loaded Helper. |
| `help` | Display a list of commands and addon info. |
| `sound/s` | Switch sounds between Custom Helper, Default, or off. |

## Options

Open the `./data/settings.xml` file to adjust these settings.

| Option | Description |
|--------|-------------|
| `ability_ready` | Alerts you when specific Job Abilities are ready to use again. Includes all SP abilities and abilities with recasts 10 minutes or longer. |
| `after_zone_party_check_delay_seconds` | Amount of time to pause watching for party structure changes after zoning. Adjust this higher if you get a notification about leaving then immediately joining a party after you zone. |
| `check_party_for_low_mp` | If you are on BRD or RDM, will keep an eye on your party members' MP levels.<br> - Only watches party members with Max MP over 1,000. |
| `check_party_for_low_mp_delay_minutes` | Amount of time after alerting you to a party member with low MP to start watching again. |
| `introduce_on_load` | Plays the Vana introduction text when the addon is loaded. |
| `key_item_reminders` | Alerts you when specific Key Items are ready to be picked up again from their respective NPCs.<br> - Tracks Mystical Canteen, Moglophone, and Shiny Ra'Kaznarian Plate.<br> - Sub-settings for turning tracking off for each individually.<br> - Sub-settings for adjusting the amount of time between additional repeat reminders after the first for each individually. |
| `notifications` | Alerts you about certain events happening.<br> - Alerts for Capped Job Points, Capped Merit Points, Mireu popping, Mog Locker lease expiring, Reraise wearing off, Signet (includes all "region" buffs) wearing off, Sublimation fully charged, and Vorseal wearing off.<br> - Sub-settings for turning alerts off for each individually. |
| `party_announcements` | Alerts for any party structure updates.<br> - Alerts for party/alliance members joining or leaving, parties joining or leaving alliance, and you becoming party or alliance leader.<br> - Sub-settings for turning alerts off for each individually. |
| `reraise_check` | Alert letting you know that you are missing Reraise. |
| `reraise_check_delay_minutes` | Amount of time between each Reraise check. |
| `reraise_check_not_in_town` | Will not alert you of Reraise missing if in a town zone. |
| `sound_effects` | Play sound effects for alerts and notifications. |
| `sparks_reminder` | A weekly reminder to use your Sparks and Accolades. Will play at login if the day/time passes while logged out. |
| `sparks_reminder_day` | Day of the week the Sparks reminder will run.<br> - Is not case-sensitive and accepts full day names and common abbreviations such as `tu`, `tue`, and `tues`.<br> - Defaults to Saturday if unable to determine the day. |
| `sparks_reminder_time` | Time the Sparks reminder will run.<br> - Time must be a number in military time, i.e., `1730` instead of `5:30 PM`.<br> - Defaults to `1200` if unable to determine time. |

------

## Motivations

After initial testing of the original Helper, within a full-alliance DynamisD session, significant performance impact was observed just by having Helper loaded versus unloaded - resulting with consistant lag spikes, stuttering, and what translated to a poor combat experience.

After the DynaD session concluded, an investigation of the code was conducted to figure out what could have been the issue - and was shocked to find that the addon was doing a lot of unnecessary and unconditioned work.

The original Helper addon contained many (fancy) sections of logic that as a result block the Windower Lua thread (which runs on the same thread that feeds data to the game). Frequent IO operations (disk read/write), repetitive global function calls; requests to remote destinations on the internet; causing lag spikes, stuttering, and IO process overhead. I was overly concerned about the performance impact of the addon, and wanted to make sure it wasn't a problem.

Furthermore, a lot of heavy function calls being made from the prerender event, which runs every frame (60) per second, regardless of interval, was causing the addon to stress the Lua thread (and system as a whole).

There are a lot of things that can be done to improve the addon's performance, but I wanted to keep it as simple as possible, and not add too many features that would make it more complex.

- Garbage collection (GC) spikes are a problem.
- Heavy use of os.clock() to determine time, which is CPU time, not wall time.
- Expensive processing for party structure updates and recast checks.
- Heavy use of Lua functions that are called frequently, such as get_party(), get_player(), get_info(), etc.
- Not much use of coroutines or caching.
- Overly large local functions and tables.
- String.gsub in hot paths causing GC pressure.

The result was this version that focuses on core (KISS) features only;

- **introduction of a file cache** - Initialised once at load time and used for reference to negate frequest filesystem operations.
- **added debouncing/throttling** - to reduce the impact to performance by triggering IO operations less frequently.
- **complete removal of curl** (calls to internet), which are generally not a good thing to be doing in a Lua thread.
- **removal of the helper extensions** - they aren't needed, as Vana does the job.
- ... and a few more logic optimisations to minimize performance impact.

>
> [!NOTE]
> It is not my intention to suggest that this version is better than the original, but it is a good alternative to the original.
> The original Helper addon is a masterpiece of work and I commend its creator for the work they put into it.
> But for my own personal use, I wanted to make a simpler, more performant, and more stable addon.

## Feature Ideas

- Low ninjutsu tool alerts.
- Bazaar state purchase notifications & command list.
- Monster agression intel on check (exclude battle arenas).
- Notorious Monsters (NM) appearance alerts.
- Doze/AFK message alert when in group.. e.g. every 10 minutes.
- Implement Besieged message alert.
- Implement current job checks for chat alerts (e.g., Looking for WHM, etc).
- Daily/Weekly task reset notices (Oseem, ROE, Monberaux, Sortie, Odyssey, Domain, etc).
- Integrate Domain Invasion (DI) notifications (if addon is loaded).
- Mogolphone & Amp buff check (every 5 minutes, if in Rabeo).
- Seal buff check (every 5 minutes, if in Mhaura).
- Language support (EN, JP, etc).

## Changelog

Version 2.6.2-2b

- Refined Party MP check logic.
  - Now only runs once per minute.
- Added Stealth wearing alerts.
- Removed unused code.
- Cleaned up push notification processing.

Version 2.6.1-31b

- FFXI info, player, party, key items, and ability recasts now cached in local namespace.
  - Vana will refer to data stored in cache rather than continually querying the game.

Version 2.6.1-30b

- Renamed addon (and command) to Vana.
- Updated readme.
- Moved all transactional definitions to vana data object.
  - This could come in handy for dumping dataset to a file or log if needed.
  - Also reduces definition clutter.
    - If vana's data is corrupted or misconfigured, it will break - expected.
    - Risk: arguably a single point of failure.
    - Garbage collection memory consumption appears unaffected.
  - Some functionality tests look okay:
    - Party/alliance structure tracking is still functional.
    - Ability ready notifications are still functional.
    - Region buffs (Signet, Sanction, Sigil, Ionis) are still functional.
  - Untested:
    - Merit points capped notifications.
    - Mog locker lease expiring notifications.
    - Reraise check notifications.
    - Mireu popped notifications.
    - Party leader change notifications.
    - Alliance leader change notifications.
    - Loot rules change notifications.
- Additional debug logging added for party/alliance structure tracking.
- Some code cleanup.
- Party leader check fixed.
  - Needs further refinement.
- Removed data folder from repo.
- Added debug logging for heartbeat (time change) event.
- Refined checks for heartbeat (time change) event.
- Vana factory data dump added (on command).
- Moved Vorseal, Reraise, and Mireu checks to every minute.

Version 2.6.1-29b

- Added debug & performance monitoring.
- Moved some logic from heartbeat (time change) event to function calls.
- Refactored party/alliance structure tracking.
  - Now only tracks only if there is a party/alliance active.
  - Uses event listeners to process notifications (reduced code repetition).
- Removed redundant base code.

Version 2.6.1-26b

- Localised definitions.
- Checks for zoned state.
- Checks for low mp state.
- Textual amendments.
- Minor housekeeping.
- Correct event misconcept (dev notes).
- Memory usage appears to be stable and acceptable.
- Continued performance testing & optimisation.

Version 2.6.1-25b

- Further performance optimisation of the addon to reduce impact to Windower Lua thread (system):
  - Moved prerender event body to time change event (prerender runs every frame, time change runs every second).
- Removed helpers extension mappings as Vana is now a single-Helper addon.
- Moved media folder to addon root location.
- Removed custom sounds option.
- Removed voices option.
- Removed random helper on load option.
- Removed redundant xml files.
- Removed lingering TODOs.

Version 2.6.1-22b

- Regression of core features and options (logic).
- Peformance optimisation of the addon to reduce impact to Windower Lua thread (system).

Version 2.3.2

- Pulled from the original Helper addon.
