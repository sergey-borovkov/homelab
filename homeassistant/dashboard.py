import asyncio, json, os, aiohttp
TOKEN=os.environ['HA_TOKEN']; V='vacuum.x50_ultra_complete'; P='x50_ultra_complete'
rooms=[(1,'Primary Bedroom','mdi:bed-king-outline'),(4,'Sergey Cabinet','mdi:desk'),(6,'Kitchen','mdi:stove'),
       (7,'Living Room','mdi:sofa'),(8,"Kristina's Office",'mdi:desk-lamp'),(9,'Corridor','mdi:foot-print'),(3,'Bathroom','mdi:toilet'),(2,'Bathroom 2','mdi:shower')]
room_btns=[{'type':'button','name':n,'icon':i,'show_state':False,
  'tap_action':{'action':'perform-action','perform_action':'dreame_vacuum.vacuum_clean_segment','target':{'entity_id':V},'data':{'segments':[sid]},
                'confirmation':{'text':f'Clean {n}?'}}} for sid,n,i in rooms]
cfg={'title':'Vacuum','views':[{'title':'X50 Ultra','path':'x50','icon':'mdi:robot-vacuum','type':'sections','max_columns':3,'sections':[
 {'type':'grid','cards':[
   {'type':'heading','heading':'Map'},
   {'type':'custom:xiaomi-vacuum-map-card','entity':V,'vacuum_platform':'Tasshack/dreame-vacuum',
    'map_source':{'camera':f'camera.{P}_map'},'calibration_source':{'camera':True},'grid_options':{'columns':'full'}},
   {'type':'tile','entity':V,'grid_options':{'columns':'full'},'features':[{'type':'vacuum-commands','commands':['start_pause','stop','return_home','locate']}]}]},
 {'type':'grid','cards':[{'type':'heading','heading':'Clean a room'}]+room_btns},
 {'type':'grid','cards':[
   {'type':'heading','heading':'Settings'},
   {'type':'entities','entities':[f'select.{P}_cleangenius',f'select.{P}_cleangenius_mode',f'select.{P}_suction_level',f'select.{P}_cleaning_mode',
      f'select.{P}_mop_pad_humidity',f'select.{P}_water_temperature',f'select.{P}_washing_mode',f'select.{P}_auto_empty_mode',f'switch.{P}_carpet_boost',f'switch.{P}_dnd']}]},
 {'type':'grid','cards':[
   {'type':'heading','heading':'Station'},
   {'type':'entities','entities':[f'sensor.{P}_state',f'sensor.{P}_battery_level',f'sensor.{P}_self_wash_base_status',f'sensor.{P}_low_water_warning',
      f'sensor.{P}_clean_water_tank_status',f'sensor.{P}_dirty_water_tank_status',f'sensor.{P}_dust_bag_status',f'sensor.{P}_detergent_status',
      f'sensor.{P}_drying_progress',f'sensor.{P}_error']}]},
 {'type':'grid','cards':[
   {'type':'heading','heading':'Consumables'},
   *[{'type':'gauge','entity':f'sensor.{P}_{k}','name':n,'min':0,'max':100,'severity':{'green':40,'yellow':15,'red':0}} for k,n in
     [('main_brush_left','Main brush'),('side_brush_left','Side brush'),('filter_left','Filter'),('sensor_dirty_left','Sensors'),('scale_inhibitor_left','Scale inhibitor')]]]},
 {'type':'grid','cards':[
   {'type':'heading','heading':'Stats'},
   {'type':'entities','entities':[f'sensor.{P}_current_room',f'sensor.{P}_cleaned_area',f'sensor.{P}_cleaning_time',f'sensor.{P}_cleaning_count',
      f'sensor.{P}_total_cleaned_area',f'sensor.{P}_total_cleaning_time',f'sensor.{P}_cleaning_history']}]}]}]}
async def main():
    async with aiohttp.ClientSession() as s, s.ws_connect('http://127.0.0.1:8123/api/websocket') as ws:
        await ws.receive_json(); await ws.send_json({'type':'auth','access_token':TOKEN}); print('auth', (await ws.receive_json())['type'])
        n=0
        async def call(msg):
            nonlocal n; n+=1; msg['id']=n; await ws.send_json(msg)
            while True:
                r=await ws.receive_json()
                if r.get('id')==n: return r
        res=await call({'type':'lovelace/resources'})
        if not any(x['url'].startswith('/local/xiaomi-vacuum-map-card.js') for x in res.get('result',[])):
            r=await call({'type':'lovelace/resources/create','res_type':'module','url':'/local/xiaomi-vacuum-map-card.js?v=2.4.1'}); print('resource', r['success'], r.get('error'))
        d=await call({'type':'lovelace/dashboards/list'})
        if not any(x['url_path']=='vacuum-x50' for x in d.get('result',[])):
            r=await call({'type':'lovelace/dashboards/create','url_path':'vacuum-x50','title':'Vacuum','icon':'mdi:robot-vacuum','show_in_sidebar':True,'require_admin':False,'mode':'storage'})
            print('dashboard', r['success'], r.get('error'))
        r=await call({'type':'lovelace/config/save','url_path':'vacuum-x50','config':cfg}); print('config saved', r['success'], r.get('error'))
asyncio.run(main())
