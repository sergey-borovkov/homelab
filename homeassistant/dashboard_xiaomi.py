# Xiaomi Home devices: English device names + "Xiaomi" dashboard. Run inside the HA container (needs aiohttp).
import asyncio, os, aiohttp
TOKEN = os.environ['HA_TOKEN']
C = 'chunmi_cn_830836452_cmwy3'; P = 'zhimi_cn_918897100_rmb1'; T = 'xiaomi_cn_blt_3_1ovhu8nvh0o00_p002'
NAMES = {'米家智能微压IH电饭煲3L': 'Rice Cooker', '小米空气净化器 4 Lite': 'Air Purifier', '米家多向扫振电动牙刷Pro': 'Toothbrush',
         'Yeelight Color Bulb   kitchen 1': 'Kitchen Light 1', 'Yeelight Color Bulb   kitchen 2': 'Kitchen Light 2'}
def cook(name, mode, icon):
    return {'type': 'button', 'name': name, 'icon': icon, 'show_state': False,
            'tap_action': {'action': 'perform-action', 'perform_action': 'notify.send_message',
                           'target': {'entity_id': f'notify.{C}_start_cook_a_2_1'}, 'data': {'message': str(mode)},
                           'confirmation': {'text': f'Start {name}? Rice and water must be in the pot.'}}}
cfg = {'title': 'Home', 'views': [{'title': 'Xiaomi', 'path': 'home', 'icon': 'mdi:rice', 'type': 'sections', 'max_columns': 3, 'sections': [
  {'type': 'grid', 'cards': [
    {'type': 'heading', 'heading': 'Shopping & meals', 'icon': 'mdi:cart'},
    {'type': 'todo-list', 'entity': 'todo.mealie_shopping', 'title': 'Shopping list', 'grid_options': {'columns': 'full'}},
    {'type': 'calendar', 'initial_view': 'listWeek', 'title': 'Meal plan', 'grid_options': {'columns': 'full'},
     'entities': ['calendar.mealie_breakfast', 'calendar.mealie_lunch', 'calendar.mealie_dinner']}]},
  {'type': 'grid', 'cards': [
    {'type': 'heading', 'heading': 'Rice cooker', 'icon': 'mdi:rice'},
    {'type': 'tile', 'entity': f'sensor.{C}_status_p_2_1', 'name': 'Status', 'grid_options': {'columns': 6}},
    {'type': 'tile', 'entity': f'sensor.{C}_left_time_p_3_3', 'name': 'Time left', 'grid_options': {'columns': 6}},
    cook('Fine cook', 1, 'mdi:rice'), cook('Quick cook', 2, 'mdi:clock-fast'),
    cook('Congee', 3, 'mdi:bowl-mix'), cook('Keep warm', 4, 'mdi:heat-wave'),
    {'type': 'button', 'entity': f'button.{C}_cancel_cooking_a_2_2', 'name': 'Cancel', 'icon': 'mdi:stop-circle',
     'tap_action': {'action': 'perform-action', 'perform_action': 'button.press', 'target': {'entity_id': f'button.{C}_cancel_cooking_a_2_2'},
                    'confirmation': {'text': 'Cancel cooking?'}}},
    {'type': 'entities', 'entities': [
      {'entity': f'sensor.{C}_cook_total_time_p_3_2', 'name': 'Total cook time'},
      {'entity': f'sensor.{C}_keepwarm_time_p_3_4', 'name': 'Keeping warm for'},
      {'entity': f'sensor.{C}_taste_p_3_9', 'name': 'Taste'},
      {'entity': f'sensor.{C}_no_pan_flag_p_3_21', 'name': 'Inner pot'},
      {'entity': f'sensor.{C}_fault_p_2_2', 'name': 'Fault'},
      {'entity': f'event.{C}_cooking_finished_e_2_1', 'name': 'Last finished'}]}]},
  {'type': 'grid', 'cards': [
    {'type': 'heading', 'heading': 'Air purifier', 'icon': 'mdi:air-purifier'},
    {'type': 'tile', 'entity': f'switch.{P}_on_p_2_1', 'name': 'Power'},
    {'type': 'tile', 'entity': f'select.{P}_mode_p_2_4', 'name': 'Mode', 'features': [{'type': 'select-options'}]},
    {'type': 'entities', 'entities': [
      {'entity': f'sensor.{P}_pm2_5_density_p_3_4', 'name': 'PM2.5'},
      {'entity': f'sensor.{P}_temperature_p_3_7', 'name': 'Temperature'},
      {'entity': f'sensor.{P}_relative_humidity_p_3_1', 'name': 'Humidity'},
      {'entity': f'sensor.{P}_filter_life_level_p_4_1', 'name': 'Filter life'},
      {'entity': f'sensor.{P}_filter_left_time_p_4_4', 'name': 'Filter days left'},
      {'entity': f'switch.{P}_physical_controls_locked_p_8_1', 'name': 'Child lock'}]}]},
  {'type': 'grid', 'cards': [
    {'type': 'heading', 'heading': 'Kitchen lights', 'icon': 'mdi:lightbulb-group'},
    *[{'type': 'tile', 'entity': f'light.yeelink_cn_{i}_color1_s_2_light', 'name': f'Kitchen light {k}',
       'features': [{'type': 'light-brightness'}]} for k, i in ((1, 134753795), (2, 287779593))]]},
  {'type': 'grid', 'cards': [
    {'type': 'heading', 'heading': 'Bathroom', 'icon': 'mdi:toothbrush-electric'},
    {'type': 'entities', 'entities': [
      {'entity': f'sensor.{T}_battery_level_p_5_1003', 'name': 'Toothbrush battery'},
      {'entity': f'sensor.{T}_brush_head_left_level_p_4_1041', 'name': 'Brush head left'},
      {'entity': 'sensor.mi_body_composition_scale_1513_weight_non_stabilized', 'name': 'Scale (last weight)'}]}]}]}]}
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
            if d.get('name') in NAMES and not d.get('name_by_user'):
                r = await call({'type': 'config/device_registry/update', 'device_id': d['id'], 'name_by_user': NAMES[d['name']]})
                print('renamed', d['name'], '->', NAMES[d['name']], r['success'])
        if not any(x['url_path'] == 'xiaomi-home' for x in (await call({'type': 'lovelace/dashboards/list'}))['result']):
            r = await call({'type': 'lovelace/dashboards/create', 'url_path': 'xiaomi-home', 'title': 'Home', 'icon': 'mdi:rice',
                            'show_in_sidebar': True, 'require_admin': False, 'mode': 'storage'}); print('dashboard', r['success'], r.get('error'))
        dash = next(x for x in (await call({'type': 'lovelace/dashboards/list'}))['result'] if x['url_path'] == 'xiaomi-home')
        await call({'type': 'lovelace/dashboards/update', 'dashboard_id': dash['id'], 'title': 'Home', 'icon': 'mdi:home'})
        r = await call({'type': 'lovelace/config/save', 'url_path': 'xiaomi-home', 'config': cfg}); print('config saved', r['success'], r.get('error'))
asyncio.run(main())
