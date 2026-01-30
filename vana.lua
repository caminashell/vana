-- TODO: Clean up Vana push notification processing.
-- TODO: Feature Idea: Low ninjutsu tool alerts.
-- TODO: Feature Idea: Stealth wearing alerts.
-- TODO: Feature Idea: Bazaar state purchase notifications & command list.
-- TODO: Feature Idea: Monster agression intel on check (exclude battle arenas).
-- TODO: Feature Idea: Notorious Monsters (NM) appearance alerts.
-- TODO: Feature Idea: Doze/AFK message alert when in group.. e.g. every 10 minutes.
-- TODO: Feature Idea: Implement Besieged message alert.
-- TODO: Feature Idea: Implement current job checks for chat alerts (e.g., Looking for WHM, etc).
-- TODO: Feature Idea: Daily/Weekly task reset notices (Oseem, ROE, Monberaux, Sortie, Odyssey, Domain, etc).

--[[ === THIS PROJECT IS IN DEVELOPMENT, NOT READY FOR USE === ]]--

_addon = {
  name = 'Vana',
  version = '2.6.1-30b',
  author = 'key (keylesta@valefor), caminashell (avestara@asura)',
  commands = {'vana'},
  description = 'An assistant that provides helpful event alerts and reminders to enhance experience in Final Fantasy XI. See README for details.',
}

config = require('config')
packets = require('packets')
res = require('resources')
images = require('images')
require 'chat'
math.randomseed(os.time())

--[[ === DEFINITIONS === ]]---

local _w = windower
local addon_path = _w.addon_path
local add_to_chat = _w.add_to_chat
local get_ability_recasts = _w.ffxi.get_ability_recasts
local get_dir = _w.get_dir
local get_info = _w.ffxi.get_info
local get_key_items = _w.ffxi.get_key_items
local get_party = _w.ffxi.get_party
local get_player = _w.ffxi.get_player
local register_event = _w.register_event
local play_sound = _w.play_sound

local defaults = {
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
    sparks = 0,
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
    sparks_reminder = true,
    sparks_reminder_day = "Saturday",
    sparks_reminder_time = 1200,
  },
}

local settings = config.load(defaults)
local options = settings.options
local notifications = options.notifications

local vana = {
  _save_scheduled = false,
  abilities = {
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
  },
  alive = false,
  cap_points = 0,
  capped_jps = true,
  capped_merits = true,
  check_party_for_low_mp_toggle = true,
  countdowns = {
    check_party_for_low_mp = 0,
    mireu = 0,
    vorseal = -1,
    reraise = math.floor(options.reraise_check_delay_minutes * 60),
  },
  debug_mode = false,
  events = {
    ability_ready = "${ability} is ready to use again.",
    capped_job_points = "Your Job Points are now capped.",
    capped_merit_points = "Your Merit Points are now capped.",
    food_wears_off = "Your food has worn off.",
    loot_rules_changed = "Looting rules have changed.",
    member_joined_alliance = "${member} has joined the alliance.",
    member_joined_party = "${member} has joined the party.",
    member_left_alliance = "${member} has left the alliance.",
    member_left_party = "${member} has left the party.",
    mireu_popped = "Mireu was just mentioned in ${zone}.",
    mog_locker_expiring = "Your Mog Locker lease is expiring soon.",
    other_party_joined_alliance = "A party has joined the alliance.",
    other_party_left_alliance = "A party has left the alliance.",
    party_low_mp = "It looks like ${member} could use a ${refresh}.",
    reminder_canteen = "Another Mystical Canteen should be available now.",
    reminder_moglophone = "Another Moglophone should be available now.",
    reminder_plate = "Another Shiny Ra'Kaznarian Plate should be available now.",
    reraise_check = "You do not have Reraise on.",
    reraise_wears_off = "Your Reraise effect has worn off.",
    signet_wears_off = "Your ${signet} effect has worn off.",
    sparks_reminder = "Don't forget to spend your Sparkss.",
    sublimation_charged = "Sublimation is now fully charged and ready to use.",
    vorseal_wearing = "You have about 10 minutes left on your Vorseal effect.",
    you_are_now_alliance_leader = "You are now the alliance leader.",
    you_are_now_party_leader = "You are now the party leader.",
    you_joined_alliance = "You have joined an alliance.",
    you_joined_party = "You have joined a party.",
    you_left_alliance = "You have left the alliance.",
    you_left_party = "You have left the party.",
    your_party_joined_alliance = "Your party has joined an alliance.",
    your_party_left_alliance = "Your party has left the alliance.",
  },
  group_state = {},
  heartbeat = 0,
  info = {
    introduction = "I'll inform you of events and reminders to help enhance your experience!",
    name = "Vana",
    name_color = 39,
    text_color = 220,
  },
  job_points = 500,
  limit_points = 0,
  listeners = {},
  max_merit_points = 0,
  media_folder = addon_path.."media/",
  merit_points = 0,
  monitor_mode = false,
  paused = false,
  placeholder_cache = {},
  prev_state = {},
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
  },
  recast = {},
  settings = {
    ability_ready = options.ability_ready,
    after_zone_party_check_delay_seconds = math.floor(options.after_zone_party_check_delay_seconds),
    capped_job_points = notifications.capped_job_points,
    capped_merit_points = notifications.capped_merit_points,
    check_party_for_low_mp = options.check_party_for_low_mp,
    check_party_for_low_mp_delay_minutes = math.floor(options.check_party_for_low_mp_delay_minutes * 60),
    first_run = settings.first_run,
    food_wears_off = notifications.food_wears_off,
    have_key_item = settings.have_key_item,
    introduce_on_load = options.introduce_on_load,
    key_item_ready = settings.key_item_ready,
    key_item_reminders = options.key_item_reminders,
    mireu_popped = notifications.mireu_popped,
    mog_locker_expiring = notifications.mog_locker_expiring,
    party_announcements = options.party_announcements,
    reraise_check = options.reraise_check,
    reraise_check_delay_minutes = math.floor(options.reraise_check_delay_minutes * 60),
    reraise_check_not_in_town = options.reraise_check_not_in_town,
    reraise_wears_off = notifications.reraise_wears_off,
    signet_wears_off = notifications.signet_wears_off,
    sound_effects = options.media.sound_effects,
    sparks_reminder = options.sparks_reminder,
    sparks_reminder_day = options.sparks_reminder_day,
    sparks_reminder_time = options.sparks_reminder_time,
    sublimation_charged = notifications.sublimation_charged,
    timestamps = settings.timestamps,
    vorseal_wearing = notifications.vorseal_wearing,
  },
  sound_cache = {},
  suppress_until = 0,
  zoned = false,
}

-- !! START PROTOTYPE: State driven Group Event Listener
-- https://github.com/Windower/Lua/wiki/

-- Utility function to count table length
-- local function tablelength(T)
--   local count = 0
--   for _ in pairs(T) do count = count + 1 end
--   return count
-- end

function vana_dump()
  print_debug('Dumping vana data state...')

  local function dump_data(table, file)
    local function write_out(object, count)
        count = count or 0

        if type(object) == "table" then
          io.write("{\n")
          count = count + 1

          local first = true

          for key, value in pairs(object) do
              if not first then
                io.write(",\n")
              end
              first = false

              if type(key) == "string" or type(key) == "number" then
                io.write(string.rep("\t",count), '"'..key..'"', ': ')
              end

              write_out(value, count)
          end

          io.write("\n")
          count = count - 1
          io.write(string.rep("\t", count), "}")

        elseif type(object) == "string" then
          io.write(string.format("%q", object))

        else
          io.write('"'..tostring(object)..'"')
        end
    end

    if file == nil then
        write_out(table)
    else
        io.output(addon_path.."data/"..file)
        io.write("")
        write_out(table)
        io.output(io.stdout)
    end
    print_debug('Data dumped to: ./data/'..file)
  end

  dump_data(vana, 'debug_vana.json')
end

local function notify(msg,sfx)
  if not msg then return end
  add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
  playSound(sfx)
end

local function on(event, fn)
  vana.listeners[event] = vana.listeners[event] or {}
  table.insert(vana.listeners[event], fn)
end

if vana.settings.party_announcements then

  on('alliance_joined', function()
      notify(vana.events.you_joined_alliance, 'you_joined_alliance')
  end)

  on('party_joined', function()
      notify(vana.events.you_joined_party, 'you_joined_party')
  end)

  on('alliance_left', function()
      notify(vana.events.you_left_alliance, 'you_left_alliance')
  end)

  on('party_left', function()
      notify(vana.events.you_left_party, 'you_left_party')
  end)

  -- ! Double-check event
  on('party_moved', function()
      -- notify(vana.events.your_party_joined_alliance, 'your_party_joined_alliance')
      notify('check: party_moved event', 'notification')
  end)

  on('member_joined_party', function(name)
      notify(memberPlaceholder(vana.events.member_joined_party, name), 'member_joined_party')
  end)

  on('member_joined_alliance', function(name)
      notify(memberPlaceholder(vana.events.member_joined_alliance, name), 'member_joined_alliance')
  end)

  on('member_left_party', function(name)
      notify(memberPlaceholder(vana.events.member_left_party, name), 'member_left_party')
  end)

  on('member_left_alliance', function(name)
      notify(memberPlaceholder(vana.events.member_left_alliance, name), 'member_left_alliance')
  end)

  on('party_leader_changed', function(name)
      notify(vana.events.you_are_now_party_leader, 'you_are_now_party_leader')
  end)

  on('alliance_leader_changed', function(name)
      notify(vana.events.you_are_now_alliance_leader, 'you_are_now_alliance_leader')
  end)

  on('loot_rules_changed', function(name)
      notify(vana.events.loot_rules_changed, 'loot_rules_changed')
  end)

end

local function emit(event, ...)
  if vana.listeners[event] then
    for _, fn in ipairs(vana.listeners[event]) do
      fn(...)
    end
  end
end

local function build_state(player, party)
  if debug_mode then print_debug('Building group state...') end

  local party_positions = {
    'p0','p1','p2','p3','p4','p5',
    'a10','a11','a12','a13','a14','a15',
    'a20','a21','a22','a23','a24','a25'
  }

  vana.group_state = {
    in_party = false,
    in_alliance = false,
    party_leader = nil,
    alliance_leader = nil,
    alliance_count = 0,
    members = {},
    loot = {
      method = nil,
      lotting = nil
    },
    position = nil
  }

  -- Scan slots
  for _, position in ipairs(party_positions) do
    local member = party[position]

    if member and member.name then
      vana.group_state.members[member.name] = { position = position }

      if vana.debug_mode then
        print_debug(
          'Member: '..tostring(member.name)..
          ', hp: '..tostring(member.hp)..' ('..tostring(member.hpp)..'%)'..
          ', mp: '..tostring(member.mp)..' ('..tostring(member.mpp)..'%)'..
          ', tp: '..tostring(member.tp)..
          ', position: '..tostring(position)
        )
      end

      -- Detect if you are in this party
      if member.name == player.name then
        vana.group_state.my_position = position
        vana.group_state.in_alliance = position:sub(1,1) ~= 'p'
        if party.party1_count > 1 then vana.group_state.in_party = position:sub(1,1) == 'p' end
      end
    end
  end

  if vana.debug_mode then
    print_debug(
      'My position: '..vana.group_state.my_position..
      ', in party: '..tostring(vana.group_state.in_party)..
      ', party leader: '..tostring(party.party1_leader)..
      ', party counts: '..party.party1_count..
      ', '..party.party2_count..
      ', '..party.party3_count..
      ', in alliance: '..tostring(vana.group_state.in_alliance)..
      ', alliance leader: '..tostring(vana.group_state.alliance_leader)..
      ', alliance count: '..party.alliance_count
    )
  end

  vana.group_state.alliance_count = party.alliance_count

  -- Party leader
  -- !! These do not necessarily check that the YOU ARE the leader...
  -- !! Further refinement is needed to determine it.
  if party.party1_leader then vana.group_state.party_leader = party.party1_leader end
  -- Alliance leader (usually a10)
  if party.a10 and party.a10.name then vana.group_state.alliance_leader = party.a10.name end

  -- Loot info
  if party.party1_loot then vana.group_state.loot.method = party.party1_loot end
  if party.party1_lot then vana.group_state.loot.lotting = party.party1_lot end

  return vana.group_state
end

local function group_tracker(info, player, party)
  if vana.debug_mode then print_debug('Checking group structure...') end

  -- Exit if in a zone or player is not logged in
  if info and info.zoning or not player then return end

  local now = os.clock()
  local curr_state = monitor('build_state()', build_state, player, party)

  -- Self join / leave suppression
  if vana.prev_state.my_position ~= curr_state.my_position then
    vana.suppress_until = now + 0.3
    vana.prev_state = curr_state
    return
  end

  if now < vana.suppress_until then return end

  -- group_state diff logic
  -- Self events
  if not vana.prev_state.in_party and curr_state.in_party then
    emit('party_joined')
  elseif vana.prev_state.in_party and not curr_state.in_party then
    emit('party_left')
  end

  if not vana.prev_state.in_alliance and curr_state.in_alliance then
    emit('alliance_joined')
  elseif vana.prev_state.in_alliance and not curr_state.in_alliance then
    emit('alliance_left')
  end

  -- Party <-> Alliance move
  if vana.prev_state.in_alliance and curr_state.in_alliance
    and vana.prev_state.my_position ~= curr_state.my_position then
    emit('party_moved', vana.prev_state.my_position, curr_state.my_position)
  end

  -- Members join/leave party or alliance
  for member_name, member_info in pairs(curr_state.members) do
    local prev_info = vana.prev_state.members[member_name]
    if not prev_info then
      if member_info.position:sub(1,1) == 'p' then
        emit('member_joined_party', member_name)
      else
        emit('member_joined_alliance', member_name)
      end
    elseif prev_info.position ~= member_info.position then
      emit('member_moved', member_name, prev_info.position, member_info.position)
    end
  end

  for member_name, member_info in pairs(vana.prev_state.members) do
    if not curr_state.members[member_name] then
      if member_info.position:sub(1,1) == 'p' then
        emit('member_left_party', member_name)
      else
        emit('member_left_alliance', member_name)
      end
    end
  end

  -- Leadership
  if vana.prev_state.party_leader ~= curr_state.party_leader
  and curr_state.alliance_count > 1 then
    emit('party_leader_changed', curr_state.party_leader)
  end

  if vana.prev_state.alliance_leader ~= curr_state.alliance_leader then
    emit('alliance_leader_changed', curr_state.alliance_leader)
  end

  -- Loot rules
  if vana.prev_state.loot.method ~= curr_state.loot.method
    or vana.prev_state.loot.lotting ~= curr_state.loot.lotting then
    emit('loot_rules_changed', curr_state.loot)
  end

  -- Update previous group_state
  vana.prev_state = curr_state

end

--!! END PROTOTYPE: (refactored functional) group tracking

--[[ === CORE FUNCTIONS === ]]---

-- Print debug messages to console if debug mode is enabled (default: false)
function print_debug(msg)
  if vana.debug_mode then
    print('[DEBUG] '..msg)
  end
end

-- Print rough profiling to console if monitor mode is enabled (default: false)
function monitor(name, fn, ...)
  if not vana.monitor_mode then
    return fn(...)
  else
    local start = os.clock()
    local results = { fn(...) }
    local mem_usage = collectgarbage("count")
    print('[MONITOR] '..name.." took "..os.clock() - start.."s."..string.format(" Memory usage: %.2f KB", mem_usage))
    return unpack(results)
  end
end

-- Debounced settings save, replacing immediate saves.
-- Reduces IO load and CPU load.
function schedule_settings_save(delay)
  print_debug( 'Scheduling settings save...') -- Debug line, can be removed later
  if vana._save_scheduled then return end
  vana._save_scheduled = true
  delay = delay or 5
  coroutine.schedule(function()
    settings:save('all')
    vana._save_scheduled = false
  end, delay)
end

-- Sound / file cache (built once, at load time)
-- Reduces filesystem reads and CPU load.
function build_sound_cache()
  print_debug( 'Building sound cache...') -- Debug line, can be removed later
  vana.sound_cache = {}
  -- scan media_folder and helper folders once
  local files = get_dir(vana.media_folder) or {}
  for _, f in ipairs(files) do
    vana.sound_cache[f:lower()] = vana.media_folder..f
  end
end

-- TODO: Optimize placeholder replacement with caching (unfinished/unused)
-- function format_message(template, key)
--   print_debug( 'Formatting message...') -- Debug line, can be removed later
--   local cache_key = template .. (key or '')
--   if vana.placeholder_cache[cache_key] then return vana.placeholder_cache[cache_key] end
--   local result = template:gsub('%${member}', key or '') -- expand as needed
--   vana.placeholder_cache[cache_key] = result
--   return result
-- end

function firstRun()
  print_debug( 'Checking first run...') -- Debug line, can be removed later
  -- Exit if this isn't the first run
  if not vana.settings.first_run then return end

  vana.settings.first_run = false
  settings.first_run = false
  schedule_settings_save()

  add_to_chat(8,('[Vana] '):color(220)..('Initialising Vana (Helper)...'):color(8))
  coroutine.sleep(1)

  add_to_chat(8,('[Vana] '):color(220)..('Type '):color(8)..('//helper help '):color(1)..('at any time to view the list of commands.'):color(8))
  coroutine.sleep(1)

end

-- Play the correct sound
function playSound(sound_name)
  print_debug( 'Playing sound...') -- Debug line, can be removed later
  if not vana.settings.sound_effects then return end

  local file_name = sound_name..".wav"
  local last_sound = 0

  if os.time() - last_sound > 0.2 then
    if vana.sound_cache[file_name:lower()] then
      play_sound(vana.sound_cache[file_name:lower()])

    elseif vana.sound_cache[addon_path..file_name:lower()] then
      play_sound(addon_path..file_name)

    elseif vana.sound_cache[("notification.wav"):lower()] then
      play_sound(vana.sound_cache[("notification.wav"):lower()])

    elseif vana.sound_cache[(addon_path.."notification.wav"):lower()] then
      play_sound(addon_path.."notification.wav")

    end
    last_sound = os.time()
  end

end

-- Set the Sparks reminder timestamp
function setSparksReminderTimestamp()
  print_debug( 'Setting Sparks reminder timestamp...') -- Debug line, can be removed later
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
  local day_input = (vana.settings.sparks_reminder_day or "Saturday"):lower()
  local time_input = tonumber(vana.settings.sparks_reminder_time) or 1200

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

  -- Check if type is a table to protect conversion to timestamp
  if type(reminder_table) ~= "table" then
    return
  end

  -- Set the exact reminder time
  reminder_table.hour = hour
  reminder_table.min = minute
  reminder_table.sec = 0

  -- Convert back to a timestamp
  local reminder_time = os.time(reminder_table)

  -- Save the new timestamp
  vana.settings.timestamps = vana.settings.timestamps or {}
  vana.settings.timestamps.sparks = reminder_time
  schedule_settings_save()

end

-- Check if the Sparks reminder should be triggered (called once per minute)
function checkSparksReminder()
  print_debug( 'Checking Sparks reminder...') -- Debug line, can be removed later
  if not vana.settings.sparks_reminder or not vana.settings.timestamps or not vana.settings.timestamps.sparks then
    return
  end

  local current_time = os.time()

  --Check if the reminder time has passed
  if current_time >= vana.settings.timestamps.sparks then

    if vana.settings.timestamps.sparks ~= 0 then

      local msg = vana.events.sparks_reminder
      if msg then
        add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
        playSound('sparks_reminder')
      end

    end

    --Set the next reminder
    setSparksReminderTimestamp()

  end
end

-- Save the time of the last check
function saveLastCheckTime()
  print_debug( 'Saving last check time...') -- Debug line, can be removed later
  vana.settings.timestamps.last_check = os.time()
  schedule_settings_save()
end

-- Save the current timestamp for a key item
function saveReminderTimestamp(key_item, key_item_reminder_repeat_hours)
  print_debug( 'Saving reminder timestamp...') -- Debug line, can be removed later
  if not key_item then
    return
  end

  local hours = 20
  if key_item_reminder_repeat_hours then
    hours = key_item_reminder_repeat_hours
  end

  --Save the timestamp for X hours into the future
  local player = get_player()
  vana.settings.timestamps[key_item][string.lower(player.name)] = os.time() + (hours * 60 * 60)
  schedule_settings_save()
end

-- Check if the player has a key item
function haveKeyItem(key_item_id)
  print_debug( 'Checking for key item...') -- Debug line, can be removed later
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
  print_debug( 'Checking key item reminders...') -- Debug line, can be removed later
  --List of tracked key items
  local tracked_items = { canteen = 3137, moglophone = 3212, plate = 3300 }

  --Get the current time
  local current_time = os.time()

  --Loop through each tracked KI
  for key_item, id in pairs(tracked_items) do

    if vana.settings.key_item_reminders[key_item] then

      local player = get_player()
      local reminder_time = vana.settings.timestamps[key_item][string.lower(player.name)] or 0
      local have_ki = vana.settings.have_key_item[key_item][string.lower(player.name)] or false

      --We just used the KI
      if have_ki and not haveKeyItem(id) then
        vana.settings.have_key_item[key_item][string.lower(player.name)] = false
        schedule_settings_save()
        saveReminderTimestamp(key_item) --Set the reminder time for 20 hours from now

      --We just received the KI again
      elseif not have_ki and haveKeyItem(id) then
        vana.settings.have_key_item[key_item][string.lower(player.name)] = true
        vana.settings.key_item_ready[key_item][string.lower(player.name)] = false
        schedule_settings_save()

      --We do not yet have the KI
      elseif not have_ki and not haveKeyItem(id) then

        --Not the first run (first run = reminder timestamp of 0) and the reminder timestamp has pased
        if reminder_time and reminder_time ~= 0 and current_time >= reminder_time then

          --KI is now ready
          vana.settings.key_item_ready[key_item][string.lower(player.name)] = true
          schedule_settings_save()

          local msg = vana['reminder_'..key_item]
          if msg then
            add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('reminder_'..key_item)
          end

          --Reset the reminder time to repeat
          saveReminderTimestamp(key_item, vana.settings.key_item_reminders[key_item..'_repeat_hours'])

        end
      end
    end
  end
end

-- Check if the Mog Locker expiration reminder should be triggered (called once per hour)
function checkMogLockerReminder()
  print_debug( 'Checking Mog Locker reminder...') -- Debug line, can be removed later
  if not vana.settings.mog_locker_expiring then
    return
  end

  local current_time = os.time()
  local one_week = 7 * 24 * 60 * 60  --7 days in seconds
  local one_day = 24 * 60 * 60  --24 hours in seconds

  local player = get_player()
  local expiration_time = vana.settings.timestamps.mog_locker_expiration[string.lower(player.name)] or 0
  local reminder_time = vana.settings.timestamps.mog_locker_reminder[string.lower(player.name)] or 0

  --Expiration is more than a week away, clear reminder timestamp
  if expiration_time - current_time > one_week then
    vana.settings.timestamps.mog_locker_reminder[string.lower(player.name)] = 0
    schedule_settings_save()

  --Expiration is under a week away
  elseif expiration_time - current_time < one_week then

    if current_time >= reminder_time then

      local msg = vana.events.mog_locker_expiring
      if msg then
        add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
        playSound('mog_locker_expiring')
      end

      --Update the reminder timestamp to trigger again in 24 hours
      vana.settings.timestamps.mog_locker_reminder[string.lower(player.name)] = current_time + one_day
      schedule_settings_save()

    end
  end
end

-- Check if the player is in a town zone
function isInTownZone()
  print_debug( 'Checking if in town zone...') -- Debug line, can be removed later
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
  print_debug( 'Capitalizing string...') -- Debug line, can be removed later
  str = string.gsub(str, "(%w)(%w*)", function(firstLetter, rest)
    return string.upper(firstLetter)..string.lower(rest)
  end)

  return str

end

-- Introduce the Helper
function introduceHelper()
  print_debug( 'Introducing helper...') -- Debug line, can be removed later
  local introduction = vana.info.introduction

  if introduction then
    add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(introduction):color(vana.info.text_color))
  else
    add_to_chat(8,('[Vana] '):color(220)..('Current Helper:'):color(8)..(capitalize(vana.info.name)):color(1)..('.'):color(8))
  end

end

-- Update recast timers (called every heartbeat (1s))
function updateRecasts()
  print_debug( 'Updating recasts...') -- Debug line, can be removed later

  local ability_recast = get_ability_recasts()

  vana.recast.sp1 = ability_recast[0] and math.floor(ability_recast[0]) or 0
  vana.recast.sp2 = ability_recast[254] and math.floor(ability_recast[254]) or 0
  vana.recast.bestial_loyalty = ability_recast[94] and math.floor(ability_recast[94]) or 0
  vana.recast.blaze_of_glory = ability_recast[247] and math.floor(ability_recast[247]) or 0
  vana.recast.call_wyvern = ability_recast[163] and math.floor(ability_recast[163]) or 0
  vana.recast.chivalry = ability_recast[79] and math.floor(ability_recast[79]) or 0
  vana.recast.convergence = ability_recast[183] and math.floor(ability_recast[183]) or 0
  vana.recast.convert = ability_recast[49] and math.floor(ability_recast[49]) or 0
  vana.recast.crooked_cards = ability_recast[96] and math.floor(ability_recast[96]) or 0
  vana.recast.dematerialize = ability_recast[351] and math.floor(ability_recast[351]) or 0
  vana.recast.devotion = ability_recast[28] and math.floor(ability_recast[28]) or 0
  vana.recast.diffusion = ability_recast[184] and math.floor(ability_recast[184]) or 0
  vana.recast.divine_seal = ability_recast[26] and math.floor(ability_recast[26]) or 0
  vana.recast.elemental_seal = ability_recast[38] and math.floor(ability_recast[38]) or 0
  vana.recast.enmity_douse = ability_recast[34] and math.floor(ability_recast[34]) or 0
  vana.recast.entrust = ability_recast[93] and math.floor(ability_recast[93]) or 0
  vana.recast.fealty = ability_recast[78] and math.floor(ability_recast[78]) or 0
  vana.recast.flashy_shot = ability_recast[128] and math.floor(ability_recast[128]) or 0
  vana.recast.formless_strikes = ability_recast[20] and math.floor(ability_recast[20]) or 0
  vana.recast.life_cycle = ability_recast[246] and math.floor(ability_recast[246]) or 0
  vana.recast.mana_wall = ability_recast[39] and math.floor(ability_recast[39]) or 0
  vana.recast.manawell = ability_recast[35] and math.floor(ability_recast[35]) or 0
  vana.recast.marcato = ability_recast[48] and math.floor(ability_recast[48]) or 0
  vana.recast.martyr = ability_recast[27] and math.floor(ability_recast[27]) or 0
  vana.recast.nightingale = ability_recast[109] and math.floor(ability_recast[109]) or 0
  vana.recast.random_deal = ability_recast[196] and math.floor(ability_recast[196]) or 0
  vana.recast.restraint = ability_recast[9] and math.floor(ability_recast[9]) or 0
  vana.recast.sacrosanctity = ability_recast[33] and math.floor(ability_recast[33]) or 0
  vana.recast.spontaneity = ability_recast[37] and math.floor(ability_recast[37]) or 0
  vana.recast.tame = ability_recast[99] and math.floor(ability_recast[99]) or 0
  vana.recast.troubadour = ability_recast[110] and math.floor(ability_recast[110]) or 0

end

-- Party MP checks (called every heartbeat (1s))
function checkPartyForLowMP()
  print_debug( 'Checking party MP...') -- Debug line, can be removed later
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

        local msg = vana.events.party_low_mp
        if msg then
          msg = refreshPlaceholder(msg,member.name,player_job)
          add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
          playSound('party_low_mp')
        end

        --Turn the toggle off so this can't be triggered again until it's turned back on
        vana.check_party_for_low_mp_toggle = false
        --Reset the countdown timer so we don't check again until ready
        vana.countdowns.check_party_for_low_mp = vana.settings.check_party_for_low_mp_delay_minutes

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
  print_debug( 'Replacing ability placeholders...') -- Debug line, can be removed later
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

  -- local ability_name

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
  print_debug( 'Getting member names...') -- Debug line, can be removed later
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
  print_debug( 'Finding differences between member lists...') -- Debug line, can be removed later
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

function checkAbilityReadyNotifications()
  print_debug( 'Checking abilities...') -- Debug line, can be removed later

  -- Check if abilities are ready
  for ability, enabled in pairs(vana.settings.ability_ready) do
    if enabled then
      if vana.recast[ability]
      and vana.recast[ability] > 0
      and vana.ready[ability] then
        vana.ready[ability] = false
      elseif vana.recast[ability] == 0
      and not vana.ready[ability] then
        local msg = vana.events.ability_ready
        if msg then
          msg = abilityPlaceholders(msg, vana.abilities[ability])
          add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
          playSound('ability_ready')
          vana.ready[ability] = true
        end
      end
    end
  end
end

function countdownForPartyLowMPChecks(player_job)
  print_debug( 'Checking party MP...') -- Debug line, can be removed later

  -- Coutdown for checking party for low mp
  if vana.settings.check_party_for_low_mp
  and (player_job == 'RDM' or player_job == 'BRD') then
    if vana.countdowns.check_party_for_low_mp > 0 then
      vana.countdowns.check_party_for_low_mp = vana.countdowns.check_party_for_low_mp - 1
    elseif vana.countdowns.check_party_for_low_mp == 0
    and not vana.check_party_for_low_mp_toggle then
      vana.check_party_for_low_mp_toggle = true
      checkPartyForLowMP()
    end
  end
end

function countdownForVorsealChecks()
  print_debug( 'Checking Vorseal...') -- Debug line, can be removed later

  -- Coutdown for checking Vorseal
  if check_vorseal_reminder
  and vana.settings.vorseal_wearing then
    if vana.countdowns.vorseal > 0 then
      vana.countdowns.vorseal = vana.countdowns.vorseal - 1
    elseif vana.countdowns.vorseal == 0
    and not vana.settings.vorseal_wearing then
      vana.settings.vorseal_wearing = true
      checkVorsealReminder()
    end
  end
end

function countdownForReraiseChecks(player)
  print_debug( 'Checking Reraise...') -- Debug line, can be removed later

  -- Countdown for Reraise Check
  if vana.settings.reraise_check
  and player.vitals.hp ~= 0 then
    if vana.countdowns.reraise > 0 then
      vana.countdowns.reraise = vana.countdowns.reraise - 1
    elseif vana.countdowns.reraise == 0 then
      vana.countdowns.reraise = vana.settings.reraise_check_delay_minutes

      -- Check if we have reraise active
      local function reraiseActive()
        local buffs = player.buffs
        for _, buffId in ipairs(buffs) do
          if buffId == 113 then
            return true
          end
        end
        return false
      end

      -- Only inform if reraise is not active and we are not in town
      -- !! This might be a gotcha due to DynamisD might need reraise to be active
      if not reraiseActive()
      and (
        not vana.settings.reraise_check_not_in_town
        or (
          vana.settings.reraise_check_not_in_town
          and not isInTownZone()
        )
      ) then
        local msg = vana.events.reraise_check
        if msg then
          add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
          playSound('reraise_check')
        end
      end
    end
  end
end

-- Determine starting states on load / login
function initialize(player, party)
  print_debug('Initializing...') -- Debug line, can be removed later

  if not player then return end

  -- Reset states on load / login
  vana.limit_points = 0
  vana.merit_points = 0
  vana.max_merit_points = 0
  vana.capped_merits = true
  vana.cap_points = 0
  vana.job_points = 500
  vana.capped_jps = true
  vana.prev_state = monitor('build_state()', build_state, player, party)
  vana.suppress_until = 0
  vana.paused = false

  -- Check if we've passed the Sparks reminder timestamp while logged out
  coroutine.schedule(function()
    checkSparksReminder()
  end, 5)

end

--[[ === WINDOWER EVENTS === ]]--

-- Load / Reload
register_event('load', function()
  print_debug('=== Re/Load Event === ') -- Debug line, can be removed later

  if get_info().logged_in then

    initialize(get_player(), get_party())
    build_sound_cache()
    updateRecasts()
    firstRun()

    if vana.settings.introduce_on_load then
      introduceHelper()
    end

  end

end)

-- Login
register_event('login', function()
  print_debug('=== Login Event ===') -- Debug line, can be removed later

  vana.paused = true

  -- Wait 5 seconds to let game values load
  coroutine.schedule(function()

    initialize(get_player(), get_party())

    vana.paused = false

    updateRecasts()
    firstRun()

    if vana.settings.introduce_on_load then
      introduceHelper()
    end

  end, 5)

  -- Wait 6 seconds before auto check/update
  coroutine.schedule(function()
  end, 6)

end)

-- Logout (reset starting states)
register_event('logout', function()
  print_debug('=== Logout Event ===') -- Debug line, can be removed later

  party_structure = {}
  in_party = false
  in_alliance = false
  party_leader = false
  alliance_leader = false
  vana.paused = false
end)

-- Parse incoming packets
register_event('incoming chunk', function(id, original, modified, injected, blocked)
  -- !! This floods the console, uncomment only for packet debugging
  -- print_debug('=== Incoming Chunk Event ===') -- Debug line, can be removed later

  if injected or blocked then return end

  local packet = packets.parse('incoming', original)

  if vana.debug_mode then
    -- !! This floods the console, uncomment only for packet debugging
    -- print_debug('Incoming Packet: ['..id..']')
  end

  -- Menu/zone update packet
  if id == 0x063 then

    -- local player = get_player()

    if player then
      vana.limit_points = packet['Limit Points'] or vana.limit_points
      vana.merit_points = packet['Merit Points'] or vana.merit_points
      vana.max_merit_points = packet['Max Merit Points'] or vana.max_merit_points
      local job = player.main_job_full
      vana.cap_points = packet[job..' Capacity Points'] or vana.cap_points
      vana.job_points = packet[job..' Job Points'] or vana.job_points

      if vana.debug_mode then
        print_debug(
          'Limit Points: '..vana.limit_points..
          ', Merit Points: '..vana.merit_points..
          '/'..vana.max_merit_points..
          ', '..job..
          ' Capacity Points: '..vana.cap_points..
          ', '..job..
          ' Job Points: '..vana.job_points
        )
      end
    end

  -- Killed a monster packet
  elseif id == 0x02D then

    local msg = packet['Message']

    if msg == 371 or msg == 372 then
      local lp_gained = packet['Param 1']
      vana.limit_points = vana.limit_points + lp_gained
      local merits_gained = math.floor(vana.limit_points / 10000)
      vana.limit_points = vana.limit_points - (merits_gained * 10000)
      vana.merit_points = vana.merit_points + merits_gained >= vana.max_merit_points
      and vana.max_merit_points or vana.merit_points + merits_gained

    elseif msg == 718 or msg == 735 then
      local cp_gained = packet['Param 1']
      vana.cap_points = vana.cap_points + cp_gained
      local jp_gained = math.floor(vana.cap_points / 30000)
      vana.cap_points = vana.cap_points - (jp_gained * 30000)
      vana.job_points = vana.job_points + jp_gained >= 500 and 500 or vana.job_points + jp_gained

    end

  elseif id == 0xB then -- Zone start
    if get_info().logged_in and not vana.zoned then
      vana.zoned = true
      vana.paused = true
    end

  elseif id == 0xA then -- Zone finish
    if get_info().logged_in and vana.zoned then
      vana.zoned = false
      -- Short delay after zoning to prevent "left...joined" messages after every zone.
      coroutine.schedule(function()
        vana.paused = false
      end, vana.settings.after_zone_party_check_delay_seconds)
    end
  end

  if vana.paused then return end

  if vana.settings.capped_merit_points
  and vana.merit_points == vana.max_merit_points
  and not vana.capped_merits then
    vana.capped_merits = true
    local msg = vana.events.capped_merit_points
    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('capped_merit_points')
    end

  elseif vana.merit_points < vana.max_merit_points and vana.capped_merits then
    vana.capped_merits = false
  end

  if vana.settings.capped_job_points
  and vana.job_points == 500
  and not vana.capped_jps then
    vana.capped_jps = true
    local msg = vana.events.capped_job_points
    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('capped_job_points')
    end

  elseif vana.job_points < 500 and vana.capped_jps then
    vana.capped_jps = false
  end

end)

-- Parses incoming text for Mog locker lease messages and Mireu pop messages
register_event("incoming text", function(original,modified,original_mode)
  print_debug('=== Incoming Text Event ===') -- Debug line, can be removed later

  if original_mode == 148 then

    -- Match the lease expiration message and extract the date/time
    local year, month, day, hour, minute, second =
    original:match("Your Mog Locker lease is valid until (%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+), kupo%.")

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
      vana.settings.timestamps.mog_locker_expiration[string.lower(player.name)] = lease_expiry_time
      schedule_settings_save()

    end
  end

  if original_mode == 212
  and vana.settings.mireu_popped
  and vana.countdowns.mireu == 0 then

    local dragons = { 'Azi Dahaka', 'Naga Raja', 'Quetzalcoatl' }
    local zones = { "Reisenjima", "Ru'Aun", "Zi'Tah" }
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
          local msg = vana.events.mireu_popped
          if msg then
            if zone == "Zi'Tah" then
              msg = mireuPlaceholder(msg, "Escha - Zi'Tah")
            elseif zone == "Ru'Aun" then
              msg = mireuPlaceholder(msg, "Escha - Ru'Aun")
            else
              msg = mireuPlaceholder(msg, zone)
            end
            add_to_chat(vana.info.text_color, ('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
            playSound('mireu_popped')
          end

          vana.countdowns.mireu = 3900
          return

        end

        return
      end
    end
  end

end)

-- Player gains a buff
register_event('gain buff', function(buff)
  print_debug('=== Gain Buff Event ===') -- Debug line, can be removed later

  if buff == 188 and vana.settings.sublimation_charged and not vana.paused then -- Sublimation: Complete
    local msg = vana.events.sublimation_charged
    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('ability_ready')
    end

  elseif buff == 602 and vana.settings.vorseal_wearing then -- Vorseal
    -- Set the countdown to 110 minutes (Vorseal lasts 2 hours)
    vana.countdowns.vorseal = 6600
  end
end)

-- Player loses a buff
register_event('lose buff', function(buff)
  print_debug('=== Lose Buff Event ===') -- Debug line, can be removed later

  if buff == 602 and vana.settings.vorseal_wearing then -- Vorseal
    -- Turn the countdown off
    vana.countdowns.vorseal = -1
  end

  if vana.paused or not vana.alive then return end

  -- Food
  if buff == 251 and vana.settings.food_wears_off then
    local msg = vana.events.food_wears_off
    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('food_wears_off')
    end

  -- Reraise
  elseif buff == 113 and vana.settings.reraise_wears_off then
    local msg = vana.events.reraise_wears_off
    if msg then
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('reraise_wears_off')
    end

  -- Signet, Sanction, Sigil, Ionis
  elseif (buff == 253 or buff == 256 or buff == 268 or buff == 512) and vana.settings.signet_wears_off then
    local function regionBuffActive()
      local buffs = get_player().buffs
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

    local msg = vana.events.signet_wears_off
    if msg then
      msg = regionBuffType(msg)
      add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..(msg):color(vana.info.text_color))
      playSound('signet_wears_off')
    end

  end

end)

-- Player changes job
register_event('job change', function()
  print_debug('=== Job Change Event ===') -- Debug line, can be removed later

  -- Prevents job changing from triggerring ability ready notifications
  vana.paused = true
  coroutine.sleep(3)
  vana.paused = false
end)

-- Heartbeat (time change) event
-- TODO: This could still mean hitching experienced every 3 seconds...
-- TODO: Investigate performance of processes in this event.
register_event('time change', function(new, old)
  local info = get_info()
  local player = get_player()

  -- Exit if player is non-existant, or vana is paused.
  if not info.logged_in
  or not player then
    print_debug('Player does not exist.')
    return
  elseif vana.paused then
    print_debug('Vana is paused.')
    return
  else
    local party = get_party()
    vana.heartbeat = os.time()

    print_debug('=== Time Change Event (Heartbeat) === ['..vana.heartbeat..']') -- Debug line, can be removed later
    print_debug(
      'ServerID: '..tostring(info.server)..', '..
      'PlayerID: '..tostring(player.id)..', '..
      'Index: '..tostring(player.index)..', '..
      'Status: '..tostring(player.status)..', '..
      'Name: '..tostring(player.name)..', '..
      'Alive: '..tostring(vana.alive):upper()
    )

    -- The alive flag prevents a few things from happening when knocked out
    if player.vitals.hp > 0 then
      vana.alive = true
    else
      vana.alive = false
    end

    -- Update recast timers
    monitor("updateRecasts()", updateRecasts)

    -- Check abilities are ready
    monitor("checkAbilityReadyNotifications()", checkAbilityReadyNotifications)

    -- Check Mog Locker lease expiration time every hour
    if vana.heartbeat % 3600 == 0 then
      monitor("checkMogLockerReminder()", checkMogLockerReminder)
    end

     -- Check Sparks reminder + Key Items reminder every 10 minutes
    if vana.heartbeat % 600 == 0 then
      monitor("checkSparksReminder()", checkSparksReminder)
      monitor("checkKIReminderTimestamps()", checkKIReminderTimestamps)
    end

     -- Check Vorseal, Reraise, and Mireu every minute
    if vana.heartbeat % 60 == 0 then
      monitor("countdownForVorsealChecks()", countdownForVorsealChecks)
      monitor("countdownForReraiseChecks()", countdownForReraiseChecks, player)
      if vana.settings.mireu_popped and vana.countdowns.mireu > 0 then
        -- ... so we don't call "Mireu popped" when the battle is over
        vana.countdowns.mireu = vana.countdowns.mireu - 1
      end
    end

     -- Party only executions: Track group structure + Countdown for checking party for low MP
    if vana.group_state.in_party or party.party1_count > 1 then
      monitor("group_tracker()", group_tracker, info, player, party)
      monitor("countdownForPartyLowMPChecks()", countdownForPartyLowMPChecks, player.main_job)
    end

  end

end)

-- Addon command event
register_event('addon command',function(addcmd, ...)

  if addcmd == 'help' or addcmd == nil then
    player = player or get_player()

    local function getLastCheckDate()
      if not vana.settings.timestamps.last_check or vana.settings.timestamps.last_check == 0 then
        return "Never"
      end
      -- Convert the timestamp into a readable date
      return os.date("%a, %b %d, %I:%M %p", vana.settings.timestamps.last_check)
    end

    local function getKeyItemReady(ki)

      if vana.settings.have_key_item[ki][string.lower(player.name)] then
        local response = {text = "Have KI", color = 6}
        return response
      elseif vana.settings.key_item_ready[ki][string.lower(player.name)] then
        local response = {text = "Ready to pickup!", color = 2}
        return response
      end

      -- Convert the timestamp into a readable date
      local response = {text = os.date("%a, %b %d, %I:%M %p", vana.settings.timestamps[ki][string.lower(player.name)]), color = 28}
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
    if vana.settings.sound_effects then
      vana.settings.sound_effects = false
      add_to_chat(8,('[Vana] '):color(220)..('Sound Mode: '):color(8)..('Off'):color(1):upper())
    else
      vana.settings.sound_effects = true
      add_to_chat(8,('[Vana] '):color(220)..('Sound Mode: '):color(8)..('On'):color(1):upper())
    end

    schedule_settings_save()

  elseif addcmd == "debug" then
    vana.debug_mode = not vana.debug_mode

    if vana.debug_mode then
      add_to_chat(8,('[Vana] '):color(220)..('Debug Mode: '):color(8)..('On'):color(1):upper())
    else
      add_to_chat(8,('[Vana] '):color(220)..('Debug Mode: '):color(8)..('Off'):color(1):upper())
    end

  elseif addcmd == "monitor" then
    vana.monitor_mode = not vana.monitor_mode

    if vana.monitor_mode then
      add_to_chat(8,('[Vana] '):color(220)..('Monitor Mode: '):color(8)..('On'):color(1):upper())
    else
      add_to_chat(8,('[Vana] '):color(220)..('Monitor Mode: '):color(8)..('Off'):color(1):upper())
    end

  elseif addcmd == "dump" then

    if vana.debug_mode then
      add_to_chat(8,('[Vana] '):color(220)..('Process may take a few seconds to complete...'))
      vana_dump()
      add_to_chat(8,('[Vana] '):color(220)..('Vana data dumped to: ../vana/data/debug_vana.json'):color(8))
    else
      add_to_chat(8,('[Vana] '):color(220)..('"Debug Mode" must be active to dump data! No action taken.'))
    end

  elseif addcmd == "test" then
    add_to_chat(vana.info.text_color,('['..vana.info.name..'] '):color(vana.info.name_color)..('This is a test notification!'):color(vana.info.text_color))
    playSound('notification')

  else
    add_to_chat(8,('[Vana] '):color(220)..('Unrecognized command. Type'):color(8)..(' //helper help'):color(1)..(' for a list of commands.'):color(8))
  end
end)

--[[

Copyright (c) 2025, Key
Copyright (c) 2026, Caminashell

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Helper nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL Key BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

]]--
