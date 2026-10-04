# Xiaomi Home devices: English names, areas + the "Home" dashboard (live vacuum map with room air readings,
# controls, details view). Run inside the HA container (needs aiohttp; imports the room list from dashboard.py):
#   docker cp dashboard.py homeassistant:/tmp/ && docker cp dashboard_xiaomi.py homeassistant:/tmp/ &&
#   docker exec -e HA_TOKEN=... homeassistant python3 /tmp/dashboard_xiaomi.py
import asyncio, os, struct, aiohttp
from dashboard import rooms, V
TOKEN = os.environ['HA_TOKEN']
C = 'chunmi_cn_830836452_cmwy3'; T = 'xiaomi_cn_blt_3_1ovhu8nvh0o00_p002'; H = 'xiaomi_sg_2093825569_600ek'
PB, PO = 'zhimi_sg_918448847_rmb1', 'zhimi_cn_918897100_rmb1'  # bedroom / office purifier
MAP = 'camera.x50_ultra_complete_map'
# Xiaomi Home device id -> (English name, area). China account (cn_*) + Singapore account (sg_*).
DEVICES = {'cn_830836452': ('Rice Cooker', None), 'cn_blt_3_1ovhu8nvh0o00': ('Toothbrush', None),
           'cn_918897100': ('Office Air Purifier', 'sergey_s_office'), 'sg_918448847': ('Bedroom Air Purifier', 'bedroom'),
           'sg_2093825569': ('Bedroom Humidifier', 'bedroom')}
DISABLED = {'cn_134753795', 'cn_287779593'}  # Yeelight bulbs still on the Xiaomi account, not in the house

# Colour bands: PM2.5 (µg/m³) and relative humidity (%)
GOOD, OK, BAD, DRY, WET = '#2e7d32', '#f9a825', '#c62828', '#ef6c00', '#1565c0'
PM_BANDS = [(None, 12, GOOD), (12, 35, OK), (35, None, BAD)]
RH_BANDS = [(None, 35, DRY), (35, 60, GOOD), (60, None, WET)]
def gauge(entity, name, mx, bands):
    return {'type': 'gauge', 'entity': entity, 'name': name, 'min': 0, 'max': mx, 'needle': True, 'grid_options': {'columns': 6},
            'segments': [{'from': lo or 0, 'color': c} for lo, _, c in bands]}

def pill(entity, x, y, icon, bands):
    """Coloured reading on the map: one conditional state-label per band."""
    style = {'left': f'{x:.1f}%', 'top': f'{y:.1f}%', 'color': 'white', 'border-radius': '12px', 'padding': '1px 8px',
             'font-size': '12px', 'font-weight': '600', 'white-space': 'nowrap', 'box-shadow': '0 1px 4px rgba(0,0,0,.5)'}
    out = []
    for lo, hi, c in bands:
        cond = {'condition': 'numeric_state', 'entity': entity, **({'above': lo} if lo is not None else {}), **({'below': hi} if hi is not None else {})}
        out.append({'type': 'conditional', 'conditions': [cond],
                    'elements': [{'type': 'state-label', 'entity': entity, 'prefix': icon, 'style': {**style, 'background': c}}]})
    return out

def map_card(attrs, w, h):
    """Vacuum map as a floor plan; positions come from the map's room centres + calibration (rerun if the map changes)."""
    cal = {(p['vacuum']['x'], p['vacuum']['y']): p['map'] for p in attrs['calibration_points']}
    o, ax, ay = cal[(0, 0)], cal[(1000, 0)], cal[(0, 1000)]
    def pos(vx, vy):  # vacuum mm -> % of the image
        px = o['x'] + (ax['x'] - o['x']) * vx / 1000 + (ay['x'] - o['x']) * vy / 1000
        py = o['y'] + (ax['y'] - o['y']) * vx / 1000 + (ay['y'] - o['y']) * vy / 1000
        return 100 * px / w, 100 * py / h
    room = {r['room_id']: pos(r['x'], r['y']) for r in attrs['rooms'].values()}
    els = []
    for rid, (ent_pm, ent_rh) in {1: (f'sensor.{PB}_pm2_5_density_p_3_4', f'sensor.{PB}_relative_humidity_p_3_1'),
                                  4: (f'sensor.{PO}_pm2_5_density_p_3_4', f'sensor.{PO}_relative_humidity_p_3_1')}.items():
        x, y = room[rid]
        els += pill(ent_pm, x, y + 4, 'PM2.5 ', PM_BANDS) + pill(ent_rh, x, y + 8, '💧 ', RH_BANDS)
    x, y = room[6]  # kitchen: rice cooker status while it's doing something
    els.append({'type': 'conditional', 'conditions': [{'condition': 'state', 'entity': f'sensor.{C}_status_p_2_1', 'state_not': 'Idle'}],
                'elements': [{'type': 'state-label', 'entity': f'sensor.{C}_status_p_2_1', 'prefix': '🍚 ',
                              'style': {'left': f'{x:.1f}%', 'top': f'{y + 4.5:.1f}%', 'color': 'white', 'background': '#6a1b9a',
                                        'border-radius': '12px', 'padding': '1px 8px', 'font-size': '12px', 'font-weight': '600'}}]})
    return {'type': 'picture-elements', 'camera_image': MAP, 'camera_view': 'auto', 'elements': els, 'grid_options': {'columns': 'full'},
            'tap_action': {'action': 'navigate', 'navigation_path': '/vacuum-x50/x50'}}

def cook(name, mode):
    return {'action': 'perform-action', 'perform_action': 'notify.send_message',
            'target': {'entity_id': f'notify.{C}_start_cook_a_2_1'}, 'data': {'message': str(mode)},
            'confirmation': {'text': f'Start {name}? Rice and water must be in the pot.'}}
def cook_row(name, mode, icon):
    return {'type': 'button', 'name': name, 'icon': icon, 'action_name': 'Start', 'tap_action': cook(name, mode)}
def purifier_controls(P):
    return [{'type': 'tile', 'entity': f'switch.{P}_on_p_2_1', 'name': 'Air purifier', 'icon': 'mdi:air-purifier', 'color': 'teal'},
            {'type': 'tile', 'entity': f'sensor.{P}_filter_life_level_p_4_1', 'name': 'Filter', 'icon': 'mdi:air-filter'},
            {'type': 'tile', 'entity': f'select.{P}_mode_p_2_4', 'name': 'Purifier mode', 'features': [{'type': 'select-options'}],
             'grid_options': {'columns': 'full'}}]
def purifier_details(name, P):
    return [{'type': 'heading', 'heading': name, 'heading_style': 'subtitle'}, {'type': 'entities', 'entities': [
      {'entity': f'sensor.{P}_filter_life_level_p_4_1', 'name': 'Filter life'},
      {'entity': f'sensor.{P}_filter_left_time_p_4_4', 'name': 'Filter days left'},
      {'entity': f'sensor.{P}_temperature_p_3_7', 'name': 'Temperature'},
      {'entity': f'switch.{P}_physical_controls_locked_p_8_1', 'name': 'Child lock'},
      {'entity': f'select.{P}_brightness_p_13_2', 'name': 'Display brightness'}]}]

# Top row: who's home (phones on Wi-Fi + Companion app), outdoor air, internet
BADGES = [{'type': 'entity', 'entity': 'person.sergey', 'show_name': True, 'show_icon': True},
          {'type': 'entity', 'entity': 'person.kristina', 'show_name': True, 'show_icon': True},
          {'type': 'entity', 'entity': 'sensor.outdoor_aqi', 'name': 'Outdoor AQI', 'show_name': True, 'icon': 'mdi:weather-hazy'},
          {'type': 'entity', 'entity': 'sensor.outdoor_temperature', 'name': 'Outside', 'show_name': True},
          {'type': 'entity', 'entity': 'binary_sensor.archer_ax55_wan_status', 'name': 'Internet', 'show_name': True, 'icon': 'mdi:web'}]
def config(map_attrs, w, h):
    home = [
      {'type': 'grid', 'column_span': 2, 'cards': [
        {'type': 'heading', 'heading': 'Home', 'icon': 'mdi:floor-plan'}, map_card(map_attrs, w, h)]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Air', 'icon': 'mdi:weather-windy'},
        gauge(f'sensor.{PB}_pm2_5_density_p_3_4', 'Bedroom PM2.5', 75, PM_BANDS),
        gauge(f'sensor.{PB}_relative_humidity_p_3_1', 'Bedroom humidity', 100, RH_BANDS),
        gauge(f'sensor.{PO}_pm2_5_density_p_3_4', 'Office PM2.5', 75, PM_BANDS),
        gauge(f'sensor.{PO}_relative_humidity_p_3_1', 'Office humidity', 100, RH_BANDS),
        {'type': 'weather-forecast', 'entity': 'weather.forecast_home', 'forecast_type': 'daily', 'grid_options': {'columns': 'full'}},
        {'type': 'history-graph', 'title': 'PM2.5 today', 'hours_to_show': 24, 'grid_options': {'columns': 'full'}, 'entities': [
          {'entity': f'sensor.{PB}_pm2_5_density_p_3_4', 'name': 'Bedroom'}, {'entity': f'sensor.{PO}_pm2_5_density_p_3_4', 'name': 'Office'}]}]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Bedroom', 'icon': 'mdi:bed'},
        {'type': 'conditional', 'conditions': [{'condition': 'state', 'entity': f'sensor.{H}_fault_p_2_2', 'state_not': 'No Faults'}],
         'card': {'type': 'tile', 'entity': f'sensor.{H}_fault_p_2_2', 'name': 'Humidifier problem', 'icon': 'mdi:water-alert', 'color': 'red'}},
        {'type': 'tile', 'entity': f'humidifier.{H}', 'name': 'Humidifier', 'color': 'blue', 'grid_options': {'columns': 'full'},
         'features': [{'type': 'target-humidity'}, {'type': 'humidifier-modes', 'style': 'icons', 'modes': ['auto', 'sleep', 'boost']}]},
        *purifier_controls(PB)]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Vacuum', 'icon': 'mdi:robot-vacuum'},
        {'type': 'tile', 'entity': V, 'name': 'X50 Ultra', 'grid_options': {'columns': 'full'},
         'features': [{'type': 'vacuum-commands', 'commands': ['start_pause', 'stop', 'return_home', 'locate']}]},
        {'type': 'tile', 'entity': 'sensor.x50_ultra_complete_battery_level', 'name': 'Battery'},
        {'type': 'tile', 'entity': 'sensor.x50_ultra_complete_current_room', 'name': 'Room', 'icon': 'mdi:map-marker'},
        *[{'type': 'tile', 'entity': V, 'name': n, 'icon': i, 'hide_state': True, 'color': 'purple',
           'tap_action': (a := {'action': 'perform-action', 'perform_action': 'dreame_vacuum.vacuum_clean_segment',
                                'target': {'entity_id': V}, 'data': {'segments': [sid]}, 'confirmation': {'text': f'Clean {n}?'}}),
           'icon_tap_action': a} for sid, n, i in rooms]]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Office', 'icon': 'mdi:desk'}, *purifier_controls(PO),
        {'type': 'heading', 'heading': 'Kitchen', 'icon': 'mdi:rice'},
        {'type': 'tile', 'entity': f'sensor.{C}_status_p_2_1', 'name': 'Rice cooker'},
        {'type': 'tile', 'entity': f'sensor.{C}_left_time_p_3_3', 'name': 'Time left'},
        {'type': 'button', 'name': 'Fine cook', 'icon': 'mdi:rice', 'show_state': False, 'grid_options': {'columns': 'full', 'rows': 2},
         'tap_action': cook('Fine cook', 1)}]}]
    details = [
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Rice cooker', 'icon': 'mdi:rice'},
        {'type': 'entities', 'entities': [
          cook_row('Quick cook', 2, 'mdi:clock-fast'), cook_row('Congee', 3, 'mdi:bowl-mix'), cook_row('Keep warm', 4, 'mdi:heat-wave'),
          {'type': 'button', 'name': 'Cancel cooking', 'icon': 'mdi:stop-circle', 'action_name': 'Cancel',
           'tap_action': {'action': 'perform-action', 'perform_action': 'button.press', 'target': {'entity_id': f'button.{C}_cancel_cooking_a_2_2'},
                          'confirmation': {'text': 'Cancel cooking?'}}},
          {'type': 'divider'},
          {'entity': f'sensor.{C}_cook_total_time_p_3_2', 'name': 'Total cook time'},
          {'entity': f'sensor.{C}_keepwarm_time_p_3_4', 'name': 'Keeping warm for'},
          {'entity': f'sensor.{C}_no_pan_flag_p_3_21', 'name': 'Inner pot'},
          {'entity': f'sensor.{C}_fault_p_2_2', 'name': 'Fault'},
          {'entity': f'event.{C}_cooking_finished_e_2_1', 'name': 'Last finished'}]},
        {'type': 'heading', 'heading': 'Bathroom', 'icon': 'mdi:toothbrush-electric'},
        {'type': 'entities', 'entities': [
          {'entity': f'sensor.{T}_battery_level_p_5_1003', 'name': 'Toothbrush battery'},
          {'entity': f'sensor.{T}_brush_head_left_level_p_4_1041', 'name': 'Brush head left'},
          {'entity': 'sensor.mi_body_composition_scale_1513_weight_non_stabilized', 'name': 'Scale (last weight)'}]}]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Air devices', 'icon': 'mdi:air-filter'},
        {'type': 'heading', 'heading': 'Bedroom humidifier', 'heading_style': 'subtitle'},
        {'type': 'entities', 'entities': [
          {'entity': f'sensor.{H}_fault_p_2_2', 'name': 'Water / status'},
          {'entity': f'sensor.{H}_filter_clean_p_11_2', 'name': 'Filter needs cleaning'},
          {'entity': f'sensor.{H}_self_clean_p_10_1', 'name': 'Self-clean'},
          {'entity': f'button.{H}_start_self_clean_a_10_1', 'name': 'Start self-clean (needs water)'},
          {'entity': f'switch.{H}_overwet_protect_p_2_11', 'name': 'Overwet protection'},
          {'entity': f'switch.{H}_on_p_6_1', 'name': 'Display'},
          {'entity': f'switch.{H}_physical_controls_locked_p_8_1', 'name': 'Child lock'}]},
        *purifier_details('Bedroom purifier', PB), *purifier_details('Office purifier', PO)]},
      {'type': 'grid', 'cards': [
        {'type': 'heading', 'heading': 'Last 24 hours', 'icon': 'mdi:chart-line'},
        {'type': 'history-graph', 'title': 'PM2.5', 'hours_to_show': 24, 'entities': [
          {'entity': f'sensor.{PB}_pm2_5_density_p_3_4', 'name': 'Bedroom'}, {'entity': f'sensor.{PO}_pm2_5_density_p_3_4', 'name': 'Office'}]},
        {'type': 'history-graph', 'title': 'Humidity', 'hours_to_show': 24, 'entities': [
          {'entity': f'sensor.{PB}_relative_humidity_p_3_1', 'name': 'Bedroom'}, {'entity': f'sensor.{PO}_relative_humidity_p_3_1', 'name': 'Office'}]},
        {'type': 'heading', 'heading': 'Network', 'icon': 'mdi:router-wireless'},
        {'type': 'entities', 'entities': [
          {'entity': 'binary_sensor.archer_ax55_wan_status', 'name': 'Internet'},
          {'entity': 'sensor.archer_ax55_download_speed', 'name': 'Download now'},
          {'entity': 'sensor.archer_ax55_upload_speed', 'name': 'Upload now'},
          {'entity': 'sensor.archer_ax55_external_ip', 'name': 'External IP'},
          {'entity': 'device_tracker.screenly_player_143', 'name': 'Screenly player .143'},
          {'entity': 'device_tracker.screenly_player_230', 'name': 'Screenly player .230'}]},
        {'type': 'heading', 'heading': 'Homelab PC', 'icon': 'mdi:server'},
        *[{'type': 'tile', 'entity': f'sensor.system_monitor_{k}', 'name': n} for k, n in
          [('processor_use', 'CPU'), ('processor_temperature', 'CPU temp'), ('memory_usage', 'RAM'), ('disk_usage', 'Disk')]]]}]
    details[0]['cards'] += [  # short first column; a 4th section would start below the tallest one
        {'type': 'heading', 'heading': 'Media & internet', 'icon': 'mdi:television-play'},
        {'type': 'tile', 'entity': 'sensor.seerr_pending_requests', 'name': 'Requests to approve', 'icon': 'mdi:inbox-arrow-down'},
        {'type': 'tile', 'entity': 'sensor.sonarr_upcoming', 'name': 'Upcoming episodes'},
        {'type': 'tile', 'entity': 'sensor.qbittorrent_download_speed', 'name': 'Downloading'},
        {'type': 'tile', 'entity': 'switch.qbittorrent_alternative_speed', 'name': 'Slow torrents', 'icon': 'mdi:speedometer-slow'},
        {'type': 'tile', 'entity': 'sensor.speedtest_download', 'name': 'Speedtest down'},
        {'type': 'tile', 'entity': 'sensor.speedtest_upload', 'name': 'Speedtest up'},
        {'type': 'calendar', 'entities': ['calendar.sonarr', 'calendar.radarr'], 'initial_view': 'listWeek', 'grid_options': {'columns': 'full'}}]
    return {'title': 'Home', 'views': [
      {'title': 'Home', 'path': 'home', 'icon': 'mdi:home', 'type': 'sections', 'max_columns': 3, 'badges': BADGES, 'sections': home},
      {'title': 'Details', 'path': 'details', 'icon': 'mdi:tune-variant', 'type': 'sections', 'max_columns': 3, 'sections': details}]}

async def main():
    async with aiohttp.ClientSession() as s, s.ws_connect('http://127.0.0.1:8123/api/websocket') as ws:
        await ws.receive_json(); await ws.send_json({'type': 'auth', 'access_token': TOKEN}); await ws.receive_json()
        n = 0
        async def call(msg):
            nonlocal n; n += 1; msg['id'] = n; await ws.send_json(msg)
            while True:
                r = await ws.receive_json()
                if r.get('id') == n: return r
        for d in (await call({'type': 'config/device_registry/list'}))['result']:
            ids = [i[1] for i in d['identifiers'] if i[0] == 'xiaomi_home']
            if ids and ids[0] in DISABLED and not d.get('disabled_by'):
                r = await call({'type': 'config/device_registry/update', 'device_id': d['id'], 'disabled_by': 'user'}); print('disabled', d['name'], r['success'])
            if ids and ids[0] in DEVICES:
                name, area = DEVICES[ids[0]]
                upd = {'name_by_user': name, **({'area_id': area} if area else {})}
                if any(d.get(k) != v for k, v in upd.items()):
                    r = await call({'type': 'config/device_registry/update', 'device_id': d['id'], **upd}); print('updated', name, r['success'])
        attrs = next(e['attributes'] for e in (await call({'type': 'get_states'}))['result'] if e['entity_id'] == MAP)
        async with s.get(f'http://127.0.0.1:8123/api/camera_proxy/{MAP}', headers={'Authorization': f'Bearer {TOKEN}'}) as r:
            w, h = struct.unpack('>II', (await r.read())[16:24])  # PNG IHDR
        if not any(x['url_path'] == 'xiaomi-home' for x in (await call({'type': 'lovelace/dashboards/list'}))['result']):
            r = await call({'type': 'lovelace/dashboards/create', 'url_path': 'xiaomi-home', 'title': 'Home', 'icon': 'mdi:home',
                            'show_in_sidebar': True, 'require_admin': False, 'mode': 'storage'}); print('dashboard', r['success'], r.get('error'))
        r = await call({'type': 'lovelace/config/save', 'url_path': 'xiaomi-home', 'config': config(attrs, w, h)}); print('config saved', r['success'], r.get('error'))
asyncio.run(main())
