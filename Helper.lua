-- TODO: Localise repeated global patterns at the top of the file for performance.
-- TODO: Localise functions that are called frequently.
-- TODO: Move function calls out of prerender, even with interval, checks every frame (60), spiking CPU every ~1s for GC.
-- TODO: Feature: Implement Besieged message alert.
-- TODO: Feature: Implement current job checks for chat alerts (e.g., Looking for WHM, etc).
-- TODO: Feature: Daily/Weekly task reset notices (Oseem, ROE, Monberaux, Sortie, Odyssey, Domain, etc).

--[[

NOTES: ------ THIS PROJECT IS IN DEVELOPMENT, NOT READY FOR USE ------

]]--

_addon = {
  name = 'Vana (Helper)',
  version = '2.6.1-25b',
  author = 'key (keylesta@valefor), caminashell (avestara@asura)',
  commands = {'helper', 'vana'},
  description = 'An in-game notification assistant that provides helpful alerts, prompts, and reminders to enhance your gameplay experience in Final Fantasy XI. See README for details.',
}

config = require('config')
packets = require('packets')
res = require('resources')
images = require('images')
require 'chat'
math.randomseed(os.time())

-- [[ === DEFINITIONS === ]] ---

_w = windower
addon_path = _w.addon_path
add_to_chat = _w.add_to_chat
get_ability_recasts = _w.ffxi.get_ability_recasts
get_dir = _w.get_dir
get_info = _w.ffxi.get_info
get_key_items = _w.ffxi.get_key_items
get_party = _w.ffxi.get_party
get_player = _w.ffxi.get_player
register_event = _w.register_event
play_sound = _w.play_sound

defaults = {
  first_run = true,
  have_key_item = {
    canteen = {},
    moglophone = {},
    plate = {},
  },
  key_item_ready = {
    canteen = {},
    moglophone = {},
    plate = {},
  },
  timestamps = {
    canteen = {},
    last_check = 0,
    moglophone = {},
    mog_locker_expiration = {},
    mog_locker_reminder = {},
    plate = {},
    sparkolades = 0,
  },
  options = {
    ability_ready = {
      bestial_loyalty = true,
      blaze_of_glory = true,
      call_wyvern = true,
      chivalry = true,
      convergence = true,
      convert = true,
      crooked_cards = true,
      dematerialize = true,
      devotion = true,
      diffusion = true,
      divine_seal = true,
      elemental_seal = true,
      embolden = true,
      enmity_douse = true,
      entrust = true,
      fealty = true,
      flashy_shot = true,
      formless_strikes = true,
      life_cycle = true,
      mana_wall = true,
      manawell = true,
      marcato = true,
      martyr = true,
      nightingale = true,
      random_deal = true,
      restraint = true,
      sacrosanctity = true,
      sp1 = true,
      sp2 = true,
      spontaneity = true,
      tame = true,
      troubadour = true,
    },
    after_zone_party_check_delay_seconds = 8,
    check_party_for_low_mp = true,
    check_party_for_low_mp_delay_minutes = 15,
    introduce_on_load = true,
    key_item_reminders = {
      canteen = true,
      canteen_repeat_hours = 12,
      moglophone = true,
      moglophone_repeat_hours = 6,
      plate = true,
      plate_repeat_hours = 6,
    },
    media = {
      sound_effects = true,
    },
    notifications = {
      capped_job_points = true,
      capped_merit_points = true,
      food_wears_off = true,
      mireu_popped = true,
      mog_locker_expiring = true,
      reraise_wears_off = true,
      signet_wears_off = true,
      sublimation_charged = true,
      vorseal_wearing = true,
    },
    party_announcements = {
      member_joined_party = true,
      member_left_party = true,
      member_joined_alliance = true,
      member_left_alliance = true,
      you_joined_party = true,
      you_left_party = true,
      you_joined_alliance = true,
      you_left_alliance = true,
      your_party_joined_alliance = true,
      your_party_left_alliance = true,
      other_party_joined_alliance = true,
      other_party_left_alliance = true,
      you_are_now_alliance_leader = true,
      you_are_now_party_leader = true,
    },
    reraise_check = true,
    reraise_check_delay_minutes = 60,
    reraise_check_not_in_town = true,
    sparkolade_reminder = true,
    sparkolade_reminder_day = "Saturday",
    sparkolade_reminder_time = 1200,
  },
}

vana = {
  info = {
    name = "Vana",
    introduction = "I'll inform you of events and reminders to help enhance your experience!",
    name_color = 39,
    text_color = 220,
  },
  ability_ready = "${ability} is ready to use again.",
  capped_job_points = "Your Job Points are now capped.",
  capped_merit_points = "Your Merit Points are now capped.",
  food_wears_off = "Your food has worn off.",
  mog_locker_expiring = "Your Mog Locker lease is expiring soon.",
  reminder_canteen = "Another Mystical Canteen should be available now.",
  reminder_moglophone = "Another Moglophone should be available now.",
  reminder_plate = "Another Shiny Ra'Kaznarian Plate should be available now.",
  party_low_mp = "It looks like ${member} could use a ${refresh}.",
  reraise_check = "You do not have Reraise on.",
  reraise_wears_off = "Your Reraise effect has worn off.",
  signet_wears_off = "Your ${signet} effect has worn off.",
  sparkolade_reminder = "Don't forget to spend your Sparkolades.",
  sublimation_charged = "Sublimation is now fully charged and ready to use.",
  mireu_popped = "Mireu was just mentioned in ${zone}.",
  member_joined_party = "${member} has joined the party.",
  member_left_party = "${member} has left the party.",
  member_joined_alliance = "${member} has joined the alliance.",
  member_left_alliance = "${member} has left the alliance.",
  vorseal_wearing = "You have about 10 minutes left on your Vorseal effect.",
  you_joined_party = "You have joined a party.",
  you_left_party = "You have left the party.",
  you_joined_alliance = "You have joined an alliance.",
  you_left_alliance = "You have left the alliance.",
  your_party_joined_alliance = "Your party has joined an alliance.",
  your_party_left_alliance = "Your party has left the alliance.",
  other_party_joined_alliance = "A party has joined the alliance.",
  other_party_left_alliance = "A party has left the alliance.",
  you_are_now_alliance_leader = "You are now the alliance leader.",
  you_are_now_party_leader = "You are now the party leader.",
}

settings = config.load(defaults)

first_run = settings.first_run
have_key_item = settings.have_key_item
key_item_ready = settings.key_item_ready
timestamps = settings.timestamps

ability_ready = settings.options.ability_ready
after_zone_party_check_delay_seconds = math.floor(settings.options.after_zone_party_check_delay_seconds)
capped_job_points = settings.options.notifications.capped_job_points
capped_merit_points = settings.options.notifications.capped_merit_points
check_party_for_low_mp = settings.options.check_party_for_low_mp
check_party_for_low_mp_delay_minutes = math.floor(settings.options.check_party_for_low_mp_delay_minutes * 60)
food_wears_off = settings.options.notifications.food_wears_off
introduce_on_load = settings.options.introduce_on_load
key_item_reminders = settings.options.key_item_reminders
mireu_popped = settings.options.notifications.mireu_popped
mog_locker_expiring = settings.options.notifications.mog_locker_expiring
party_announcements = settings.options.party_announcements
reraise_check = settings.options.reraise_check
reraise_check_delay_minutes = math.floor(settings.options.reraise_check_delay_minutes * 60)
reraise_check_not_in_town = settings.options.reraise_check_not_in_town
reraise_wears_off = settings.options.notifications.reraise_wears_off
signet_wears_off = settings.options.notifications.signet_wears_off
sound_effects = settings.options.media.sound_effects
sparkolade_reminder = settings.options.sparkolade_reminder
sparkolade_reminder_day = settings.options.sparkolade_reminder_day
sparkolade_reminder_time = settings.options.sparkolade_reminder_time
sublimation_charged = settings.options.notifications.sublimation_charged
vorseal_wearing = settings.options.notifications.vorseal_wearing

countdowns = {
  check_party_for_low_mp = 0,
  mireu = 0,
  vorseal = -1,
  reraise = reraise_check_delay_minutes,
}

ready = {
  bestial_loyalty = true,
  blaze_of_glory = true,
  call_wyvern = true,
  chivalry = true,
  convergence = true,
  convert = true,
  crooked_cards = true,
  dematerialize = true,
  devotion = true,
  diffusion = true,
  divine_seal = true,
  elemental_seal = true,
  embolden = true,
  enmity_douse = true,
  entrust = true,
  fealty = true,
  flashy_shot = true,
  formless_strikes = true,
  life_cycle = true,
  mana_wall = true,
  manawell = true,
  marcato = true,
  martyr = true,
  nightingale = true,
  random_deal = true,
  restraint = true,
  sacrosanctity = true,
  sp1 = true,
  sp2 = true,
  spontaneity = true,
  tame = true,
  troubadour = true,
}

ability_name = {
  bestial_loyalty = "Bestial Loyalty",
  blaze_of_glory = "Blaze of Glory",
  call_wyvern = "Call Wyvern",
  chivalry = "Chivalry",
  convergence = "Convergence",
  convert = "Convert",
  crooked_cards = "Crooked Cards",
  dematerialize = "Dematerialize",
  devotion = "Devotion",
  diffusion = "Diffusion",
  divine_seal = "Divine Seal",
  elemental_seal = "Elemental Seal",
  embolden = "Embolden",
  enmity_douse = "Enmity Douse",
  entrust = "Entrust",
  fealty = "Fealty",
  flashy_shot = "Flashy Shot",
  formless_strikes = "Formless Strikes",
  life_cycle = "Life Cycle",
  mana_wall = "Mana Wall",
  manawell = "Manawell",
  marcato = "Marcato",
  martyr = "Martyr",
  nightingale = "Nightingale",
  random_deal = "Random Deal",
  restraint = "Restraint",
  sacrosanctity = "Sacrosanctity",
  sp1 = "SP1",
  sp2 = "SP2",
  spontaneity = "Spontaneity",
  tame = "Tame",
  troubadour = "Troubadour",
}

recast = {}
party_structure = {}
heartbeat = 0
in_party = false
in_alliance = false
party_leader = false
alliance_leader = false
limit_points = 0
merit_points = 0
max_merit_points = 0
capped_merits = true
cap_points = 0
job_points = 500
capped_jps = true
check_party_for_low_mp_toggle = true
zoned = false
paused = false
alive = true
media_folder = addon_path.."media/"

_save_scheduled = false
sound_cache = {}
placeholder_cache = {}
last_party_check = 0
party_check_interval = 1.0 -- seconds

-- [[ === CORE FUNCTIONS === ]] ---

-- Debounced settings save, replacing immediate saves.
-- Reduces IO load and CPU load.
local function schedule_settings_save(delay)
  if _save_scheduled then return end
  _save_scheduled = true
  delay = delay or 5
  coroutine.schedule(function()
    settings:save('all')
    _save_scheduled = false
  end, delay)
end

-- Sound / file cache (built once, at load time)
-- Reduces filesystem reads and CPU load.
local function build_sound_cache()
  sound_cache = {}
  -- scan media_folder and helper folders once
  local files = get_dir(media_folder) or {}
  for _, f in ipairs(files) do
    sound_cache[f:lower()] = media_folder..f
  end
end

-- TODO: Optimize placeholder replacement with caching (unfinished/unused)
local function format_message(template, key)
  local cache_key = template .. (key or '')
  if placeholder_cache[cache_key] then return placeholder_cache[cache_key] end
  local result = template:gsub('%${member}', key or '') -- expand as needed
  placeholder_cache[cache_key] = result
  return result
end

-- Determine starting states
function initialize()
  -- Localise repeated global patterns
  -- Should not be calling get_abc() multiple times.
  local party = get_party()
  local player = get_player()

  if not player then return end

  limit_points = 0
  merit_points = 0
  max_merit_points = 0
  capped_merits = true
  cap_points = 0
  job_points = 500
  capped_jps = true

  --Update the party/alliance structure
  party_structure = updatePartyStructure()
  in_alliance = false
  if party.alliance_leader then
    in_alliance = true
    in_party = true
    if party.alliance_leader == player.id then
      alliance_leader = true
      party_leader = true
    end
  end
  if not in_alliance then
    in_party = false
    if party.party1_leader then
      in_party = true
      if party.party1_leader == player.id then
        party_leader = true
      end
    end
  end
  paused = false

  --Check if we've passed the Sparkolade reminder timestamp while logged out
  coroutine.schedule(function()
    checkSparkoladeReminder()
  end, 5)

end

-- Update the party/alliance structure
-- !! This function creates a new table every time and therefore triggers GC a lot.
-- !! Examine reusing the same table over time.
function updatePartyStructure()

	-- Get the current party data
	local current_party = get_party()

	local new_party_structure = new_party_structure or {
		alliance_leader = nil,
		party1_leader = nil,
		party2_leader = nil,
		party3_leader = nil,
		party1_count = nil,
		party2_count = nil,
		party3_count = nil,
		p0 = nil, p1 = nil, p2 = nil, p3 = nil, p4 = nil, p5 = nil,
		a10 = nil, a11 = nil, a12 = nil, a13 = nil, a14 = nil, a15 = nil,
		a20 = nil, a21 = nil, a22 = nil, a23 = nil, a24 = nil, a25 = nil
	}

	-- List of positions to iterate over in the current_party table
	local all_positions = all_positions or {
		'p0', 'p1', 'p2', 'p3', 'p4', 'p5',
		'a10', 'a11', 'a12', 'a13', 'a14', 'a15',
		'a20', 'a21', 'a22', 'a23', 'a24', 'a25',
	}

	-- Fill the new_party_structure table with player names
	for _, position in ipairs(all_positions) do
		local name = current_party[position] and current_party[position].name or nil
		if name then
			new_party_structure[position] = name
		end
	end

	-- Fill leader positions in new_party_structure
	new_party_structure.alliance_leader = current_party.alliance_leader
	new_party_structure.party1_leader = current_party.party1_leader
	new_party_structure.party2_leader = current_party.party2_leader
	new_party_structure.party3_leader = current_party.party3_leader
	new_party_structure.party1_count = current_party.party1_count
	new_party_structure.party2_count = current_party.party2_count
	new_party_structure.party3_count = current_party.party3_count

	return new_party_structure

end

function firstRun()

  -- Exit if this isn't the first run
  if not first_run then return end

  first_run = false
  settings.first_run = false
  schedule_settings_save()

  add_to_chat(8,('[Vana] '):color(220)..('Initialising Vana (Helper)...'):color(8))
  coroutine.sleep(1)

  add_to_chat(8,('[Vana] '):color(220)..('Type '):color(8)..('//helper help '):color(1)..('at any time to view the list of commands.'):color(8))
  coroutine.sleep(1)

end

-- Play the correct sound
-- !! Added Debouncing to prevent sound spamming & hitching due to IO load
function playSound(sound_name)

  if not sound_effects then return end

  local file_name = sound_name..".wav"
  local last_sound = 0

  if os.time() - last_sound > 0.2 then
    if sound_cache[file_name:lower()] then
      play_sound(sound_cache[file_name:lower()])

    elseif sound_cache[addon_path..file_name:lower()] then
      play_sound(addon_path..file_name)

    elseif sound_cache[("notification.wav"):lower()] then
      play_sound(sound_cache[("notification.wav"):lower()])

    elseif sound_cache[(addon_path.."notification.wav"):lower()] then
      play_sound(addon_path.."notification.wav")

    end
    last_sound = os.time()
  end

end

-- Set the Sparkolade reminder timestamp
function setSparkoladeReminderTimestamp()

  local days_of_week = {
    sunday = 1, sun = 1, su = 1,
    monday = 2, mon = 2, mo = 2,
    tuesday = 3, tue = 3, tues = 3, tu = 3,
    wednesday = 4, wed = 4, weds = 4, we = 4,
    thursday = 5, thurs = 5, thu = 5, th = 5,
    friday = 6, fri = 6, fr = 6,
    saturday = 7, sat = 7, sa = 7,
  }

  -- Get user-configured day and time, default to "Saturday 12:00"
  local day_input = (sparkolade_reminder_day or "Saturday"):lower()
  local time_input = tonumber(sparkolade_reminder_time) or 1200

  -- Convert the input day to a numeric day of the week
  local target_day = days_of_week[day_input]

  -- Ensure time_input is in valid military time format (HHMM)
  local hour = math.floor(time_input / 100)  -- Extract hours
  local minute = time_input % 100  -- Extract minutes
  if hour < 0 or hour > 23 then
    hour = 12
  end
  if minute < 0 or minute > 59 then
    minute = 0
  end

  -- Convert to number
  hour = tonumber(hour) or 0
  minute = tonumber(minute) or 0

  -- Get current date/time
  local now = os.time()
  local now_table = os.date("*t", now)
  local today = now_table.wday  -- Lua weeks start on Sunday (1)

  -- Correct the day adjustment logic
  local days_until_next = (target_day - today + 7) % 7

  -- If today is the target day but the time has passed, move to next week
  if days_until_next == 0 and (now_table.hour > hour or (now_table.hour == hour and now_table.min >= minute)) then
    days_until_next = 7
  end

  -- Use `os.time()` to properly roll over months and years
  local future_time = now + (days_until_next * 86400)  -- Add days in seconds
  local reminder_table = os.date("*t", future_time)  -- Get the correct date

  -- Set the exact reminder time
  reminder_table.hour = hour
  reminder_table.min = minute
  reminder_table.sec = 0

  -- Convert back to a timestamp
  local reminder_time = os.time(reminder_table)

  -- Save the new timestamp
  settings.timestamps = settings.timestamps or {}
  settings.timestamps.sparkolades = reminder_time
  schedule_settings_save()

end

-- Check if the Sparkolade reminder should be triggered (called once per minute)
function checkSparkoladeReminder()

  if not sparkolade_reminder or not settings.timestamps or not settings.timestamps.sparkolades then
    return
  end

  local current_time = os.time()

  --Check if the reminder time has passed
  if current_time >= settings.timestamps.sparkolades then

    if settings.timestamps.sparkolades ~= 0 then

      local text = vana.sparkolade_reminder
      if text then

        add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

        playSound('sparkolade_reminder')

      end

    end

    --Set the next reminder
    setSparkoladeReminderTimestamp()

  end
end

-- Save the time of the last check
function saveLastCheckTime()
  timestamps.last_check = os.time()
  schedule_settings_save()
end

-- Save the current timestamp for a key item
function saveReminderTimestamp(key_item, key_item_reminder_repeat_hours)
  if not key_item then
    return
  end

  local hours = 20
  if key_item_reminder_repeat_hours then
    hours = key_item_reminder_repeat_hours
  end

  --Save the timestamp for X hours into the future
  local player = get_player()
  timestamps[key_item][string.lower(player.name)] = os.time() + (hours * 60 * 60)
  schedule_settings_save()
end

-- Check if the player has a key item
function haveKeyItem(key_item_id)
  if not key_item_id then
    return false
  end

  --Get the player's key items
  local key_items = get_key_items()

  --Check if the given key_item_id exists in the player's key items
  for _, id in ipairs(key_items) do
    if id == key_item_id then
      return true
    end
  end

  return false
end

-- Check if a key item reminder should be triggered (called every heartbeat (1s))
function checkKIReminderTimestamps()

  --List of tracked key items
  local tracked_items = { canteen = 3137, moglophone = 3212, plate = 3300 }

  --Get the current time
  local current_time = os.time()

  --Loop through each tracked KI
  for key_item, id in pairs(tracked_items) do

    if key_item_reminders[key_item] then

      local player = get_player()
      local reminder_time = timestamps[key_item][string.lower(player.name)] or 0
      local have_ki = have_key_item[key_item][string.lower(player.name)] or false

      --We just used the KI
      if have_ki and not haveKeyItem(id) then
        have_key_item[key_item][string.lower(player.name)] = false
        schedule_settings_save()
        saveReminderTimestamp(key_item) --Set the reminder time for 20 hours from now

      --We just received the KI again
      elseif not have_ki and haveKeyItem(id) then
        have_key_item[key_item][string.lower(player.name)] = true
        key_item_ready[key_item][string.lower(player.name)] = false
        schedule_settings_save()

      --We do not yet have the KI
      elseif not have_ki and not haveKeyItem(id) then

        --Not the first run (first run = reminder timestamp of 0) and the reminder timestamp has pased
        if reminder_time and reminder_time ~= 0 and current_time >= reminder_time then

          --KI is now ready
          key_item_ready[key_item][string.lower(player.name)] = true
          schedule_settings_save()

          local text = vana['reminder_'..key_item]
          if text then

            add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

            playSound('reminder_'..key_item)

          end

          --Reset the reminder time to repeat
          saveReminderTimestamp(key_item, key_item_reminders[key_item..'_repeat_hours'])

        end
      end
    end
  end
end

-- Check if the Mog Locker expiration reminder should be triggered (called once per hour)
function checkMogLockerReminder()

  if not mog_locker_expiring then
    return
  end

  local current_time = os.time()
  local one_week = 7 * 24 * 60 * 60  --7 days in seconds
  local one_day = 24 * 60 * 60  --24 hours in seconds

  local player = get_player()
  local expiration_time = timestamps.mog_locker_expiration[string.lower(player.name)] or 0
  local reminder_time = timestamps.mog_locker_reminder[string.lower(player.name)] or 0

  --Expiration is more than a week away, clear reminder timestamp
  if expiration_time - current_time > one_week then
    timestamps.mog_locker_reminder[string.lower(player.name)] = 0
    schedule_settings_save()

  --Expiration is under a week away
  elseif expiration_time - current_time < one_week then

    if current_time >= reminder_time then

      local text = vana.mog_locker_expiring
      if text then

        add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

        playSound('mog_locker_expiring')

      end

      --Update the reminder timestamp to trigger again in 24 hours
      timestamps.mog_locker_reminder[string.lower(player.name)] = current_time + one_day
      schedule_settings_save()

    end
  end
end

-- Check if the player is in a town zone
function isInTownZone()

  local current_zone = res.zones[get_info().zone].name
  local town_zones = {
    'Western Adoulin','Eastern Adoulin','Celennia Memorial Library','Silver Knife','Bastok Markets','Bastok Mines','Metalworks','Port Bastok','Chateau d\'Oraguille','Northern San d\'Oria','Port San d\'Oria','Southern San d\'Oria','Heavens Tower','Port Windurst','Windurst Walls','Windurst Waters','Windurst Woods','Lower Jeuno','Port Jeuno','Ru\'Lude Gardens','Upper Jeuno','Aht Urhgan Whitegate','The Colosseum','Tavnazian Safehold','Southern San d\'Oria [S]','Bastok Markets [S]','Windurst Waters [S]','Mhaura','Selbina','Rabao','Kazham','Norg','Nashmau','Mog Garden','Leafallia','Chocobo Circuit'
    }

  --If in a mog house, return true (mostly just for Al Zahbi MH)
  if get_info().mog_house then
    return true
  end

  for _, town in ipairs(town_zones) do
    if current_zone == town then
      return true
    end
  end

  return false

end

-- Capitalize first letter
function capitalize(str)

  str = string.gsub(str, "(%w)(%w*)", function(firstLetter, rest)
    return string.upper(firstLetter)..string.lower(rest)
  end)

  return str

end

-- Introduce the Helper
function introduceHelper()

  local introduction = vana.info.introduction

  if introduction then
    add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(introduction):color(vana.info.text_color))
  else
    add_to_chat(8,('[Vana] '):color(220)..('Current Helper:'):color(8)..(capitalize(vana.info.name)):color(1)..('.'):color(8))
  end

end

-- Update recast timers (called every heartbeat (1s))
function updateRecasts()

  local ability_recast = get_ability_recasts()

  recast.sp1 = ability_recast[0] and math.floor(ability_recast[0]) or 0
  recast.sp2 = ability_recast[254] and math.floor(ability_recast[254]) or 0
  recast.bestial_loyalty = ability_recast[94] and math.floor(ability_recast[94]) or 0
  recast.blaze_of_glory = ability_recast[247] and math.floor(ability_recast[247]) or 0
  recast.call_wyvern = ability_recast[163] and math.floor(ability_recast[163]) or 0
  recast.chivalry = ability_recast[79] and math.floor(ability_recast[79]) or 0
  recast.convergence = ability_recast[183] and math.floor(ability_recast[183]) or 0
  recast.convert = ability_recast[49] and math.floor(ability_recast[49]) or 0
  recast.crooked_cards = ability_recast[96] and math.floor(ability_recast[96]) or 0
  recast.dematerialize = ability_recast[351] and math.floor(ability_recast[351]) or 0
  recast.devotion = ability_recast[28] and math.floor(ability_recast[28]) or 0
  recast.diffusion = ability_recast[184] and math.floor(ability_recast[184]) or 0
  recast.divine_seal = ability_recast[26] and math.floor(ability_recast[26]) or 0
  recast.elemental_seal = ability_recast[38] and math.floor(ability_recast[38]) or 0
  recast.enmity_douse = ability_recast[34] and math.floor(ability_recast[34]) or 0
  recast.entrust = ability_recast[93] and math.floor(ability_recast[93]) or 0
  recast.fealty = ability_recast[78] and math.floor(ability_recast[78]) or 0
  recast.flashy_shot = ability_recast[128] and math.floor(ability_recast[128]) or 0
  recast.formless_strikes = ability_recast[20] and math.floor(ability_recast[20]) or 0
  recast.life_cycle = ability_recast[246] and math.floor(ability_recast[246]) or 0
  recast.mana_wall = ability_recast[39] and math.floor(ability_recast[39]) or 0
  recast.manawell = ability_recast[35] and math.floor(ability_recast[35]) or 0
  recast.marcato = ability_recast[48] and math.floor(ability_recast[48]) or 0
  recast.martyr = ability_recast[27] and math.floor(ability_recast[27]) or 0
  recast.nightingale = ability_recast[109] and math.floor(ability_recast[109]) or 0
  recast.random_deal = ability_recast[196] and math.floor(ability_recast[196]) or 0
  recast.restraint = ability_recast[9] and math.floor(ability_recast[9]) or 0
  recast.sacrosanctity = ability_recast[33] and math.floor(ability_recast[33]) or 0
  recast.spontaneity = ability_recast[37] and math.floor(ability_recast[37]) or 0
  recast.tame = ability_recast[99] and math.floor(ability_recast[99]) or 0
  recast.troubadour = ability_recast[110] and math.floor(ability_recast[110]) or 0

end

-- Party MP checks (called every heartbeat (1s))
function checkPartyForLowMP()

  local player_job = get_player().main_job

  --Replace redresh placeholders
  local function refreshPlaceholder(text, member, job)
    if job == "BRD" then
      text = text:gsub("%${refresh}", "ballad")
    elseif job == "RDM" then
      text = text:gsub("%${refresh}", "refresh")
    end
    return text:gsub("%${member}", member)
  end

  --Loop through party members 2 through 6
  local positions = {'p1','p2','p3','p4','p5'}
  for _, position in ipairs(positions) do

    local member = get_party()[position]

    if member and member.mp and member.mpp then

      --Calculate estimated max MP based on current MP and mpp
      local estimated_max_mp = math.floor(member.mp / (member.mpp / 100))

      --Check for high max MP, low mpp, and no existing Ballad or Refresh buff
      if estimated_max_mp > 1000 and member.mpp <= 25 then

            local text = vana.party_low_mp
        if text then

          text = refreshPlaceholder(text,member.name,player_job)

          add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

          playSound('party_low_mp')

        end

        --Turn the toggle off so this can't be triggered again until it's turned back on
        check_party_for_low_mp_toggle = false
        --Reset the countdown timer so we don't check again until ready
        countdowns.check_party_for_low_mp = check_party_for_low_mp_delay_minutes

      end
    end
  end
end

-- Replace Mireu zone placeholder
function mireuPlaceholder(text, zone)
  return text:gsub("%${zone}", zone)
end

-- Replace party/alliance member names placeholder
function memberPlaceholder(text, name)
  return text:gsub("%${member}", name)
end

-- Replace the ability placeholders (potential call every heartbeat (1s))
function abilityPlaceholders(text, ability)

  local player_job = get_player().main_job

  local SP1 = {
    WAR = "Mighty Strikes", MNK = "Hundred Fists", WHM = "Benediction",
    BLM = "Manafont", RDM = "Chainspell", THF = "Perfect Dodge",
    PLD = "Invincible", DRK = "Blood Weapon", BST = "Familiar",
    BRD = "Soul Voice", RNG = "Eagle Eye Shot", SMN = "Astral Flow",
    SAM = "Meikyo Shisui", NIN = "Mijin Gakure", DRG = "Spirit Surge",
    BLU = "Azure Lore", COR = "Wild Card", PUP = "Overdrive",
    DNC = "Trance", SCH = "Tabula Rasa", GEO = "Bolster",
    RUN = "Elemental Sforzo"
  }

  local SP2 = {
    WAR = "Brazen Rush", MNK = "Inner Strength", WHM = "Asylum",
    BLM = "Subtle Sorcery", RDM = "Stymie", THF = "Larceny",
    PLD = "Intervene", DRK = "Soul Enslavement", BST = "Unleash",
    BRD = "Clarion Call", RNG = "Overkill", SMN = "Astral Conduit",
    SAM = "Yaegasumi", NIN = "Mikage", DRG = "Fly High",
    BLU = "Unbridled Wisdom", COR = "Cutting Cards", PUP = "Heady Artifice",
    DNC = "Grand Pas", SCH = "Caper Emissarius", GEO = "Widened Compass",
    RUN = "Odyllic Subterfuge"
  }

  local ability_name

  if ability == "SP1" then
    ability_name = SP1[player_job]
  elseif ability == "SP2" then
    ability_name = SP2[player_job]
  else
    ability_name = ability
  end

  return text:gsub("%${ability}", ability_name)

end

-- Helper function to create a table of member names for a given set of positions
function getMemberNames(structure, positions)

  local members = members or {}

  for _, position in ipairs(positions) do
    if structure[position] then
      table.insert(members, structure[position])
    end
  end

  return members

end

-- Helper function to find the difference between two tables of member names
function findDifferences(old_members, new_members)

  local changes = changes or {}
  changes.added = {}
  changes.removed = {}

  -- Convert tables to sets for comparison
  local old_set = old_set or {}
  for _, name in ipairs(old_members) do
    old_set[name] = true
  end

  local new_set = new_set or {}
  for _, name in ipairs(new_members) do
    new_set[name] = true
  end

  -- Find added members
  for _, name in ipairs(new_members) do
    if not old_set[name] then
      table.insert(changes.added, name)
    end
  end

  -- Find removed members
  for _, name in ipairs(old_members) do
    if not new_set[name] then
      table.insert(changes.removed, name)
    end
  end

  return changes

end

-- Compare party/alliance structure
function trackPartyStructure()
  -- Debounce/Throttle heavy handler
  local now = os.clock()
  if now - last_party_check < party_check_interval then return end
  last_party_check = now

  -- Initialize the new_party_structure table
  local new_party_structure = updatePartyStructure()
  local previously_in_party = in_party
  local previously_in_alliance = in_alliance
  local previously_party_leader = party_leader
  local previously_alliance_leader = alliance_leader
  local now_in_party = false
  local now_in_alliance = false
  local now_party_leader = false
  local now_alliance_leader = false
  local announce = party_announcements
  local old_p1_count = party_structure.party1_count
  local old_p2_count = party_structure.party2_count
  local old_p3_count = party_structure.party3_count
  local new_p1_count = new_party_structure.party1_count
  local new_p2_count = new_party_structure.party2_count
  local new_p3_count = new_party_structure.party3_count
  local old_p2_leader = party_structure.party2_leader
  local old_p3_leader = party_structure.party3_leader
  local new_p2_leader = new_party_structure.party2_leader
  local new_p3_leader = new_party_structure.party3_leader

  -- Get the current party data
  local party = get_party()
  local player = get_player()

  -- Check if player is in alliance group
  if party.alliance_leader then
    now_in_alliance = true
    now_in_party = true
    if party.alliance_leader == player.id then
      now_alliance_leader = true
      now_party_leader = true
    end
  end

  if not now_in_alliance then
    -- Check if player is in a party group
    if party.party1_leader then
      now_in_party = true
      if party.party1_leader == player.id then
        now_party_leader = true
      end
    end
  end

  local msg = nil

  -- Player joins a party that is in an alliance
  if announce.you_joined_alliance and not previously_in_party and now_in_party and now_in_alliance then

    msg = vana.you_joined_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('you_joined_alliance')
    end

  -- Player joins a party that is not in an alliance
  elseif announce.you_joined_party and not previously_in_party and now_in_party and not now_party_leader then

    msg = vana.you_joined_party

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('you_joined_party')
    end

  -- Player leaves a party that is part of an alliance
  elseif announce.you_left_alliance and previously_in_alliance and not now_in_party then

    msg = vana.you_left_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('you_left_alliance')
    end

  -- Player leaves a party that is not part of an alliance
  elseif announce.you_left_party and previously_in_party and not now_in_party then

    msg = vana.you_left_party

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('you_left_party')
    end

  -- Player's party joined an alliance
  elseif announce.your_party_joined_alliance and previously_in_party and now_in_alliance and not previously_in_alliance then

    msg = vana.your_party_joined_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('your_party_joined_alliance')
    end

  -- Player's party left an alliance
  elseif announce.your_party_left_alliance and previously_in_alliance and not now_in_alliance then

    msg = vana.your_party_left_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('your_party_left_alliance')
    end

  -- Another party joined the alliance
  elseif announce.other_party_joined_alliance and previously_in_alliance and now_in_alliance and
         ((not old_p2_leader and new_p2_leader) or (not old_p3_leader and new_p3_leader)) then

    msg = vana.other_party_joined_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('other_party_joined_alliance')
    end

  -- Another party left the alliance
  elseif announce.other_party_left_alliance and previously_in_alliance and now_in_alliance and
         ((old_p2_leader and not new_p2_leader) or (old_p3_leader and not new_p3_leader)) then

    msg = vana.other_party_left_alliance

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('other_party_left_alliance')
    end

  -- Member joined/left your party
  elseif not msg and new_party_structure and party_structure and
         new_p1_count and old_p1_count and new_p1_count ~= old_p1_count then

    -- Compare member names for changes in party 1
    local party1_positions = {'p0', 'p1', 'p2', 'p3', 'p4', 'p5'}
    local old_party1_members = getMemberNames(party_structure, party1_positions)
    local new_party1_members = getMemberNames(new_party_structure, party1_positions)
    local party1_changes = findDifferences(old_party1_members, new_party1_members)

    -- Member joined your party
    if announce.member_joined_party and new_p1_count > old_p1_count then

      for _, member in ipairs(party1_changes.added) do
        if member ~= '' then
          msg = vana.member_joined_party
          if msg then
            msg = memberPlaceholder(msg, member)
            add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('member_joined_party')
          end
        else
          -- If the name of the member hasn't loaded yet and thus comes back nil/empty,
          -- set the party count back to it's original state to try again
          new_party_structure.party1_count = party_structure.party1_count
        end
      end

    -- Member left your party
    elseif announce.member_left_party and new_p1_count < old_p1_count then

      for _, member in ipairs(party1_changes.removed) do
        if member ~= '' then
          msg = vana.member_left_party
          if msg then
            msg = memberPlaceholder(msg, member)
            add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('member_left_party')
          end
        else
          -- If the name of the member hasn't loaded yet and thus comes back nil/empty,
          -- set the party count back to it's original state to try again
          new_party_structure.party1_count = party_structure.party1_count
        end
      end

    end

  -- Member joined/left an alliance party
  elseif not msg and new_party_structure and party_structure and
         new_p2_count and old_p2_count and new_p3_count and old_p3_count and
         (new_p2_count ~= old_p2_count or new_p3_count ~= old_p3_count) then

    -- Compare member names for changes in party 2 and 3 combined (alliance parties)
    local alliance_positions = {
      'a10', 'a11', 'a12', 'a13', 'a14', 'a15',
      'a20', 'a21', 'a22', 'a23', 'a24', 'a25'
    }

    local old_alliance_members = getMemberNames(party_structure, alliance_positions)
    local new_alliance_members = getMemberNames(new_party_structure, alliance_positions)
    local alliance_changes = findDifferences(old_alliance_members, new_alliance_members)

    -- Member joined an alliance party
    if announce.member_joined_alliance and (new_p2_count > old_p2_count or new_p3_count > old_p3_count) then

      for _, member in ipairs(alliance_changes.added) do
        if member ~= '' then
          msg = vana.member_joined_alliance
          if msg then
            msg = memberPlaceholder(msg, member)
            add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('member_joined_alliance')
          end
        else
          -- If the name of the member hasn't loaded yet and thus comes back nil/empty,
          -- set the party count back to it's original state to try again
          new_party_structure.party2_count = party_structure.party2_count
          new_party_structure.party3_count = party_structure.party3_count
        end
      end

    -- Member left an alliance party
    elseif announce.member_left_alliance and (new_p2_count < old_p2_count or new_p3_count < old_p3_count) then

      for _, member in ipairs(alliance_changes.removed) do
        if member ~= '' then
          msg = vana.member_left_alliance
          if msg then
            msg = memberPlaceholder(msg, member)
            add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('member_left_alliance')
          end
        else
          -- If the name of the member hasn't loaded yet and thus comes back nil/empty,
          -- set the party count back to it's original state to try again
          new_party_structure.party2_count = party_structure.party2_count
          new_party_structure.party3_count = party_structure.party3_count
        end
      end
    end

  -- Player becomes the alliance leader
  elseif announce.you_are_now_alliance_leader and previously_in_alliance and not previously_alliance_leader and now_alliance_leader then

    msg = vana.you_are_now_alliance_leader

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('now_alliance_leader')
    end

  -- Player becomes the party leader
  elseif announce.you_are_now_party_leader and previously_in_party and not previously_party_leader and now_party_leader then

    msg = vana.you_are_now_party_leader

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('now_party_leader')
    end

  end

  -- Save current states for future comparison
  in_party = now_in_party
  in_alliance = now_in_alliance
  party_leader = now_party_leader
  alliance_leader = now_alliance_leader
  party_structure = new_party_structure

end

-- [[ === WINDOWER EVENTS === ]] --

-- Load
register_event('load', function()

  if get_info().logged_in then

    initialize()
    build_sound_cache()
    updateRecasts()
    firstRun()

    if introduce_on_load then
      introduceHelper()
    end

  end

end)

-- Login
register_event('login', function()

  paused = true

  -- Wait 5 seconds to let game values load
  coroutine.schedule(function()

    initialize()

    paused = false

    updateRecasts()
    firstRun()

    if introduce_on_load then
      introduceHelper()
    end

  end, 5)

  -- Wait 6 seconds before auto check/update
  coroutine.schedule(function()
  end, 6)

end)

-- Logout (reset starting states)
register_event('logout', function()
  party_structure = {}
  in_party = false
  in_alliance = false
  party_leader = false
  alliance_leader = false
  paused = false
end)

-- Parse incoming packets
register_event('incoming chunk', function(id, original, modified, injected, blocked)

  if injected or blocked then return end

  local packet = packets.parse('incoming', original)

  -- Menu/zone update packet
  if id == 0x063 then

    local player = get_player()

    if player then
      limit_points = packet['Limit Points'] or limit_points
      merit_points = packet['Merit Points'] or merit_points
      max_merit_points = packet['Max Merit Points'] or max_merit_points
      local job = player.main_job_full
      cap_points = packet[job..' Capacity Points'] or cap_points
      job_points = packet[job..' Job Points'] or job_points
    end

  -- Killed a monster packet
  elseif id == 0x02D then

    local msg = packet['Message']

    if msg == 371 or msg == 372 then
      local lp_gained = packet['Param 1']
      limit_points = limit_points + lp_gained
      local merits_gained = math.floor(limit_points / 10000)
      limit_points = limit_points - (merits_gained * 10000)
      merit_points = merit_points + merits_gained >= max_merit_points and max_merit_points or merit_points + merits_gained

    elseif msg == 718 or msg == 735 then
      local cp_gained = packet['Param 1']
      cap_points = cap_points + cp_gained
      local jp_gained = math.floor(cap_points / 30000)
      cap_points = cap_points - (jp_gained * 30000)
      job_points = job_points + jp_gained >= 500 and 500 or job_points + jp_gained

    end

  elseif id == 0xB then -- Zone start
    if get_info().logged_in then
      zoned = true
      paused = true
    end

  elseif id == 0xA then -- Zone finish
    if get_info().logged_in then
      zoned = false
      -- Short delay after zoning to prevent "left...joined" messages after every zone.
      coroutine.schedule(function()
        paused = false
      end, after_zone_party_check_delay_seconds)
    end
  end

  if paused then return end

  if capped_merit_points and merit_points == max_merit_points and not capped_merits then

    capped_merits = true

    local text = vana.capped_merit_points
    if text then

      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

      playSound('capped_merit_points')

    end

  elseif merit_points < max_merit_points and capped_merits then

    capped_merits = false

  end

  if capped_job_points and job_points == 500 and not capped_jps then

    capped_jps = true

    local text = vana.capped_job_points
    if text then

      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

      playSound('capped_job_points')

    end

  elseif job_points < 500 and capped_jps then

    capped_jps = false

  end

end)

-- Parses incoming text for Mog locker lease messages and Mireu pop messages
register_event("incoming text", function(original,modified,original_mode)

  if original_mode == 148 then

    -- Match the lease expiration message and extract the date/time
    local year, month, day, hour, minute, second = original:match("Your Mog Locker lease is valid until (%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+), kupo%.")

    -- Enforce number type of above variables
    year = tonumber(year) or 0
    month = tonumber(month) or 0
    day = tonumber(day) or 0
    hour = tonumber(hour) or 0
    minute = tonumber(minute) or 0
    second = tonumber(second) or 0

    -- If a match is found, convert it to a timestamp
    if year and month and day and hour and minute and second then
      local lease_expiry_time = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = minute,
        sec = second
      })

      -- Store the timestamp in the timestamps table
      local player = get_player()
      timestamps.mog_locker_expiration[string.lower(player.name)] = lease_expiry_time
      schedule_settings_save()

    end
  end

  if original_mode == 212 and mireu_popped and countdowns.mireu == 0 then

    local dragons = {
      'Azi Dahaka',
      'Naga Raja',
      'Quetzalcoatl',
    }

    local unity_leaders = {
      '{Aldo}',
      '{Apururu}',
      '{Ayame}',
      '{Flaviria}',
      '{Invincible Shield}',
      '{Jakoh Wahcondalo}',
      '{Maat}',
      '{Naja Salaheem}',
      '{Pieuje}',
      '{Sylvie}',
      '{Yoran-Oran}',
    }

    local zones = {
      "Reisenjima",
      "Ru'Aun",
      "Zi'Tah",
    }

    -- Extract all names enclosed in curly brackets
    local function extract_bracketed_names(str)
      local names = {}
      for name in str:gmatch("%b{}") do
        table.insert(names, name)
      end
      return names
    end

    for _, zone in ipairs(zones) do
      -- Check if the zone is found in the unity message
      if original:find(zone) then

        local bracketed_names = extract_bracketed_names(original)
        local leader_count = 0

        -- Check how many bracketed names are valid unity leaders
        for _, name in ipairs(bracketed_names) do
          for _, leader in ipairs(unity_leaders) do
            if name == leader then
              leader_count = leader_count + 1
              break
            end
          end
        end

        -- Proceed only if exactly one unity leader is found, and no extra names are enclosed in brackets
        if leader_count == 1 and #bracketed_names == 1 then

          -- Check if any dragon name is found
          for _, dragon in ipairs(dragons) do
            if original:find(dragon) then
              return
            end
          end

          -- No dragon name is found, so therefore is Mireu
          local text = vana.mireu_popped

          if text then

            if zone == "Zi'Tah" then
              text = mireuPlaceholder(text, "Escha - Zi'Tah")
            elseif zone == "Ru'Aun" then
              text = mireuPlaceholder(text, "Escha - Ru'Aun")
            else
              text = mireuPlaceholder(text, zone)
            end

            add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))

            playSound('mireu_popped')

          end

          countdowns.mireu = 3900
          return

        end

        return
      end
    end
  end

end)

-- Player gains a buff
register_event('gain buff', function(buff)

  if buff == 188 and sublimation_charged and not paused then -- Sublimation: Complete

    local msg = vana.sublimation_charged

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('ability_ready')
    end

  elseif buff == 602 and vorseal_wearing then -- Vorseal
    -- Set the countdown to 110 minutes (Vorseal lasts 2 hours)
    countdowns.vorseal = 6600
  end
end)

-- Player loses a buff
register_event('lose buff', function(buff)

  if buff == 602 and vorseal_wearing then -- Vorseal
    -- Turn the countdown off
    countdowns.vorseal = -1
  end

  if paused or not alive then return end

  -- Food
  if buff == 251 and food_wears_off then

    local msg = vana.food_wears_off

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('food_wears_off')
    end

  -- Reraise
  elseif buff == 113 and reraise_wears_off then

    local msg = vana.reraise_wears_off

    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('reraise_wears_off')
    end

  -- Signet, Sanction, Sigil, Ionis
  elseif (buff == 253 or buff == 256 or buff == 268 or buff == 512) and signet_wears_off then

    local function regionBuffActive()
      local buffs = _w.ffxi.get_player().buffs
      local regionBuffs = { [253] = true, [256] = true, [268] = true, [512] = true }

      for _, buffId in ipairs(buffs) do
        if regionBuffs[buffId] then
          return true
        end
      end

      return false
    end

    -- Replace Signet with appropriate region buff type
    local function regionBuffType(text)
      local region_buffs = {
        [253] = "Signet",
        [256] = "Sanction",
        [268] = "Sigil",
        [512] = "Ionis"
      }
      return text:gsub("%${signet}", region_buffs[buff] or "Signet")
    end

    if regionBuffActive() then
      return
    end

    local msg = vana.signet_wears_off

    if msg then
      msg = regionBuffType(msg)
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('signet_wears_off')
    end

  end

end)

-- Player changes job
register_event('job change', function()

  -- Prevents job changing from triggerring ability ready notifications
  paused = true
  coroutine.sleep(3)
  paused = false

end)

-- Main time change event (1 second heartbeat)
register_event('time change', function(new, old)

  local logged_in = get_info().logged_in
  local player = get_player()

  -- The alive flag prevents a few things from happening when knocked out
  if logged_in and player.vitals.hp == 0 and alive then
    alive = false
  elseif logged_in and player.vitals.hp > 0 and not alive then
    alive = true
  end

  if not paused and logged_in then

    heartbeat = os.time()

    local player_job = player.main_job

    trackPartyStructure()
    updateRecasts()


    -- Check if abilities are ready
    for ability, enabled in pairs(ability_ready) do
      if enabled then
        if recast[ability] and recast[ability] > 0 and ready[ability] then
          ready[ability] = false
        elseif recast[ability] == 0 and not ready[ability] then
                local text = vana.ability_ready
          if text then
            text = abilityPlaceholders(text, ability_name[ability])
            add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(text):color(vana.info.text_color))
            playSound('ability_ready')
            ready[ability] = true
          end
        end
      end
    end

    -- Check if any Key Items are ready
    checkKIReminderTimestamps()

    -- Check on Mog Locker lease expiration time once per hour
    if heartbeat % 3600 == 0 then
      checkMogLockerReminder()
    end

    -- Check Sparkolade reminder every 1 minute
    if heartbeat % 60 == 0 then
      checkSparkoladeReminder()
    end

    -- Coutdown for checking party for low mp
    if check_party_for_low_mp and (player_job == 'RDM' or player_job == 'BRD') then

      if countdowns.check_party_for_low_mp > 0 then

        countdowns.check_party_for_low_mp = countdowns.check_party_for_low_mp - 1

      elseif countdowns.check_party_for_low_mp == 0 then

        check_party_for_low_mp_toggle = true
        checkPartyForLowMP()

      end
    end

    -- Countdown for Vorseal Reminder
    if vorseal_wearing then

      if countdowns.vorseal > 0 then

        countdowns.vorseal = countdowns.vorseal - 1

      elseif countdowns.vorseal == 0 then

        countdowns.vorseal = -1
        local vorseal_text = vana.vorseal_wearing

        if vorseal_text then

          add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(vorseal_text):color(vana.info.text_color))
          playSound('vorseal_wearing')

        end

      end

    end

    -- Countdown for Mireu (so we don't call "Mireu popped" when the battle is over)
    if mireu_popped and countdowns.mireu > 0 then
      countdowns.mireu = countdowns.mireu - 1
    end

    -- Countdown for Reraise Check
    if reraise_check and player.vitals.hp ~= 0 then

      if countdowns.reraise > 0 then

        countdowns.reraise = countdowns.reraise - 1

      elseif countdowns.reraise == 0 then

        countdowns.reraise = reraise_check_delay_minutes

        -- Check if we have reraise active
        local function reraiseActive()
          local buffs = get_player().buffs
          for _, buffId in ipairs(buffs) do
            if buffId == 113 then
              return true
            end
          end
          return false
        end

        -- Only inform if reraise is not active and we are not in town
        -- !! This might be a gotcha due to DynamisD might need reraise to be active
        if not reraiseActive() and (not reraise_check_not_in_town or (reraise_check_not_in_town and not isInTownZone())) then

          local msg = vana.reraise_check

          if msg then

            add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('reraise_check')

          end

        end
      end
    end
  end
--   end
end)

-- Addon command event
register_event('addon command',function(addcmd, ...)

  if addcmd == 'help' or addcmd == nil then

    local player = get_player()

    local function getLastCheckDate()

      if not timestamps.last_check or timestamps.last_check == 0 then
        return "Never"
      end

      -- Convert the timestamp into a readable date
      return os.date("%a, %b %d, %I:%M %p", timestamps.last_check)

    end

    local function getKeyItemReady(ki)

      if have_key_item[ki][string.lower(player.name)] then

        local response = {text = "Have KI", color = 6}
        return response

      elseif key_item_ready[ki][string.lower(player.name)] then

        local response = {text = "Ready to pickup!", color = 2}
        return response

      end

      -- Convert the timestamp into a readable date
      local response = {text = os.date("%a, %b %d, %I:%M %p", timestamps[ki][string.lower(player.name)]), color = 28}
      return response

    end

    local last_check_date = getLastCheckDate()
    local canteen_ready = getKeyItemReady('canteen')
    local moglophone_ready = getKeyItemReady('moglophone')
    local plate_ready = getKeyItemReady('plate')

    add_to_chat(8,('[Vana] '):color(220)..('Version '):color(8)..(_addon.version):color(220))
    add_to_chat(8,('         Developed by '):color(8)..(_addon.author):color(220))
    add_to_chat(8,' ')
    add_to_chat(8,('         Last update check: '):color(8)..(last_check_date):color(1))
    add_to_chat(8,('         Mystical Canteen: ')..(canteen_ready.text):color(canteen_ready.color))
    add_to_chat(8,('         Moglophone: ')..(moglophone_ready.text):color(moglophone_ready.color))
    add_to_chat(8,('         Ra\'Kaznarian Plate: ')..(plate_ready.text):color(plate_ready.color))
    add_to_chat(8,' ')
    add_to_chat(8,('         Command '):color(36)..('[optional] '):color(53)..('<required> '):color(2)..('- Description'):color(8))
    add_to_chat(8,' ')
    add_to_chat(8,('         sound/s '):color(36)..('- Toggle sounds on/off.'):color(8))

  elseif addcmd == "sounds" or addcmd == "sound" or addcmd == "s" then

    if sound_effects then

      settings.options.sound_effects = false
      sound_effects = false
      add_to_chat(8,('[Vana] '):color(220)..('Sound Mode: '):color(8)..('Off'):color(1):upper())

    else

      settings.options.sound_effects = true
      sound_effects = true
      add_to_chat(8,('[Vana] '):color(220)..('Sound Mode: '):color(8)..('On'):color(1):upper())

    end

    schedule_settings_save()

  elseif addcmd == "test" then

    add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..('This is a test notification!'):color(vana.info.text_color))
    playSound('notification')

  else

    add_to_chat(8,('[Vana] '):color(220)..('Unrecognized command. Type'):color(8)..(' //helper help'):color(1)..(' for a list of commands.'):color(8))

  end
end)

--Copyright (c) 2025, Key
--Copyright (c) 2026, Caminashell
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of Helper nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL Key BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
