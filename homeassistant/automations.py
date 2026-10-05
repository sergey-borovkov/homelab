# Home Assistant automations (household Telegram alerts + the air logic). Creates/updates them through HA's API,
# so they show up (and stay editable) in Settings > Automations. Run on the host: HA_TOKEN=... python3 automations.py
import json, os, urllib.request
C = 'chunmi_cn_830836452_cmwy3'; H = 'xiaomi_sg_2093825569_600ek'
PB, PO = 'zhimi_sg_918448847_rmb1', 'zhimi_cn_918897100_rmb1'  # bedroom / office purifier
ROOMS = {'bedroom': PB, 'office': PO}
TG = {'action': 'notify.send_message', 'target': {'entity_id': 'notify.telegram_household'}}
def msg(t): return {**TG, 'data': {'message': t}}
def trig(id_): return {'condition': 'trigger', 'id': id_}
def is_on(e): return {'condition': 'state', 'entity_id': e, 'state': 'on'}
def turn(on, e): return {'action': f'input_boolean.turn_{"on" if on else "off"}', 'target': {'entity_id': e}}
def rh(room): return f'sensor.{ROOMS[room]}_relative_humidity_p_3_1'
def pm(room): return f'sensor.{ROOMS[room]}_pm2_5_density_p_3_4'
def purifier_on(P): return {'action': 'switch.turn_on', 'target': {'entity_id': f'switch.{P}_on_p_2_1'}}
def purifier_auto_unless_sleep(P):  # don't wake anyone: a purifier already in Sleep stays in Sleep
    return {'if': [{'condition': 'not', 'conditions': [{'condition': 'state', 'entity_id': f'select.{P}_mode_p_2_4', 'state': 'Sleep'}]}],
            'then': [{'action': 'select.select_option', 'target': {'entity_id': f'select.{P}_mode_p_2_4'}, 'data': {'option': 'Auto'}}]}
MODERATE, BAD = 'input_boolean.outdoor_air_moderate_alert', 'input_boolean.smog_alert_active'
AIR = '{{ states("sensor.outdoor_air") }}'

AUTOS = {
'rice_ready': {'alias': 'Rice is ready', 'description': 'Telegram both of us when the rice cooker finishes', 'mode': 'single',
  'triggers': [{'trigger': 'state', 'entity_id': f'event.{C}_cooking_finished_e_2_1', 'not_from': ['unavailable'], 'not_to': ['unavailable', 'unknown']},
               {'trigger': 'state', 'entity_id': f'sensor.{C}_status_p_2_1', 'to': 'CookFinish'},
               {'trigger': 'state', 'entity_id': f'sensor.{C}_status_p_2_1', 'from': 'Busy', 'to': 'KeepWarm'}],
  'actions': [msg('🍚 Rice is ready!'), {'delay': '00:05:00'}]},  # delay: one message even if several triggers fire

'humidifier_water': {'alias': 'Humidifier out of water', 'description': 'Telegram when the bedroom humidifier runs dry', 'mode': 'single',
  'triggers': [{'trigger': 'state', 'entity_id': f'sensor.{H}_fault_p_2_2', 'to': 'Lack Of Water'},
               {'trigger': 'state', 'entity_id': f'event.{H}_low_water_level_e_2_1', 'not_from': ['unavailable'], 'not_to': ['unavailable', 'unknown']}],
  'actions': [msg('💧 Bedroom humidifier is out of water, please refill it.'), {'delay': '00:30:00'}]},

'filter_reminders': {'alias': 'Filter reminders', 'description': 'Purifier filters nearly used up, humidifier filter needs a rinse', 'mode': 'queued',
  'triggers': [{'trigger': 'numeric_state', 'entity_id': f'sensor.{PB}_filter_life_level_p_4_1', 'below': 10, 'id': 'Bedroom'},
               {'trigger': 'numeric_state', 'entity_id': f'sensor.{PO}_filter_life_level_p_4_1', 'below': 10, 'id': 'Office'},
               {'trigger': 'state', 'entity_id': f'sensor.{H}_filter_clean_p_11_2', 'to': 'Clean', 'id': 'humidifier'}],
  'actions': [{'choose': [{'conditions': [trig('humidifier')],
                           'sequence': [msg('🧽 Bedroom humidifier filter needs a rinse (cool water, no chemicals).')]}],
               'default': [msg('🌀 {{ trigger.id }} air purifier filter is at {{ trigger.to_state.state }}%, time to order a new one (Xiaomi 4 Lite filter).')]}]},

# Outdoor: worst of station dust (WAQI) and modelled ozone/NO2 (Open-Meteo) as a US AQI. Two levels, one all-clear.
'outdoor_smog': {'alias': 'Outdoor air alerts', 'mode': 'queued',
  'description': 'Moderate (index > 75) heads-up, bad (> 100) alert with purifiers on, all-clear below 50 after an alert',
  'triggers': [{'trigger': 'numeric_state', 'entity_id': 'sensor.outdoor_air_index', 'above': 75, 'for': '00:30:00', 'id': 'moderate'},
               {'trigger': 'numeric_state', 'entity_id': 'sensor.outdoor_air_index', 'above': 100, 'for': '00:30:00', 'id': 'bad'},
               {'trigger': 'numeric_state', 'entity_id': 'sensor.outdoor_air_index', 'below': 50, 'for': '01:00:00', 'id': 'clear'}],
  'actions': [{'choose': [
     {'conditions': [trig('bad'), {'condition': 'not', 'conditions': [is_on(BAD)]}], 'sequence': [
        turn(True, BAD), turn(True, MODERATE),
        msg(f'😷 Outdoor air: {AIR}. Keep the windows closed, purifiers are on. (Over 100 = bad for sensitive people)'),
        purifier_on(PB), purifier_on(PO), purifier_auto_unless_sleep(PB), purifier_auto_unless_sleep(PO)]},
     {'conditions': [trig('moderate'), {'condition': 'not', 'conditions': [is_on(MODERATE)]}], 'sequence': [
        turn(True, MODERATE),
        msg(f'🌫 Outdoor air: {AIR}. OK for a quick airing, but keep windows closed otherwise; purifiers are on.'),
        purifier_on(PB), purifier_on(PO)]},
     {'conditions': [trig('clear'), {'condition': 'or', 'conditions': [is_on(BAD), is_on(MODERATE)]}], 'sequence': [
        turn(False, BAD), turn(False, MODERATE), msg(f'🌤 Outdoor air: {AIR} again, fine to open the windows.')]}]}]},

# Indoor humidity: dry below 35% for an hour, humid above 65% for 3 hours. The bedroom humidifier reacts.
'indoor_humidity': {'alias': 'Indoor humidity alerts', 'mode': 'queued',
  'description': 'Too dry / too humid in the bedroom or office; bedroom humidifier switches on (Auto) or off',
  'triggers': [*[{'trigger': 'numeric_state', 'entity_id': rh(r), 'below': 35, 'for': '01:00:00', 'id': f'{r}_dry'} for r in ROOMS],
               *[{'trigger': 'numeric_state', 'entity_id': rh(r), 'above': 65, 'for': '03:00:00', 'id': f'{r}_humid'} for r in ROOMS]],
  'actions': [{'choose': [
     {'conditions': [trig('bedroom_dry')], 'sequence': [
        {'action': 'humidifier.turn_on', 'target': {'entity_id': f'humidifier.{H}'}},
        {'action': 'humidifier.set_mode', 'target': {'entity_id': f'humidifier.{H}'}, 'data': {'mode': 'auto'}},
        msg('🏜 Bedroom air is dry ({{ trigger.to_state.state }}%). Humidifier is on (Auto). Below 35% dries skin, eyes and throat.')]},
     {'conditions': [trig('office_dry')], 'sequence': [
        msg('🏜 Office air is dry ({{ trigger.to_state.state }}%). No humidifier there: a bowl of water on the radiator or a shorter heating burst helps.')]},
     {'conditions': [trig('bedroom_humid')], 'sequence': [
        {'action': 'humidifier.turn_off', 'target': {'entity_id': f'humidifier.{H}'}},
        msg('💦 Bedroom is humid ({{ trigger.to_state.state }}%) for 3 hours, humidifier off. Air it out; above 65% risks mould.')]},
     {'conditions': [trig('office_humid')], 'sequence': [
        msg('💦 Office is humid ({{ trigger.to_state.state }}%) for 3 hours. Air it out; above 65% risks mould.')]}]}]},

# Indoor dust (cooking, cleaning, smoke): make sure that room's purifier is running; tell us only if it had been off.
'indoor_dust': {'alias': 'Indoor dust', 'mode': 'queued',
  'description': 'PM2.5 above 35 for 10 min in a room: switch its purifier on; message if it was off',
  'triggers': [{'trigger': 'numeric_state', 'entity_id': pm(r), 'above': 35, 'for': '00:10:00', 'id': r} for r in ROOMS],
  'actions': [{'choose': [{'conditions': [trig(r)], 'sequence': [
     {'if': [{'condition': 'state', 'entity_id': f'switch.{P}_on_p_2_1', 'state': 'off'}],
      'then': [purifier_on(P), msg(f'🍳 {r.title()} PM2.5 is {{{{ trigger.to_state.state }}}} µg/m³ (cooking? smoke?), switched its purifier on.')]},
     purifier_auto_unless_sleep(P)]} for r, P in ROOMS.items()]}]},

# UV: morning heads-up on high-UV days (6+ = high on the WHO scale)
'uv_high': {'alias': 'High UV today', 'mode': 'single', 'description': '9:00 heads-up when today\'s UV index peaks at 6 or more',
  'triggers': [{'trigger': 'time', 'at': '09:00:00'}],
  'conditions': [{'condition': 'numeric_state', 'entity_id': 'sensor.uv_index_today_max', 'above': 5.9}],
  'actions': [msg('☀️ UV will reach {{ states("sensor.uv_index_today_max") | round(0) | int }} today (high). Sunscreen/hat if you are out around midday.')]},
}

def api(method, path, body=None):
    r = urllib.request.Request(f'http://127.0.0.1:8123{path}', data=json.dumps(body).encode() if body is not None else None, method=method,
                               headers={'Authorization': f'Bearer {os.environ["HA_TOKEN"]}', 'Content-Type': 'application/json'})
    return json.load(urllib.request.urlopen(r))

if __name__ == '__main__':
    have = {s['entity_id'] for s in api('GET', '/api/states')}
    if 'input_boolean.outdoor_air_moderate_alert' not in have:  # helper flag; creating it needs the websocket API
        print('create input_boolean "Outdoor air moderate alert" first (Settings > Helpers)')
    for k, v in AUTOS.items():
        print(k, api('POST', f'/api/config/automation/config/{k}', v)['result'])
