# Hides a callback from the UI if no checkin in the last 2 hours
# Runs once a minute
# If the callback checks back in, it will reappear in the UI
#
# Note: It's not a great idea to use this if you are using P2P comms
# or push-based C2 profiles since check-ins may not occur at all or
# very infrequently.

from mythic import mythic
from datetime import datetime as dt
import time

mythic_client = await mythic.login(
    username="a",
    password="a",
    server_ip="192.168.230.42",
    server_port=7443,
    timeout=5
)

def is_callback_dead(c):
    date_time_obj = dt.fromisoformat(c['last_checkin'])
    time_difference = dt.now() - date_time_obj
    
    seconds_ago = time_difference.seconds
    minutes_ago = seconds_ago / 60
    hours_ago = minutes_ago / 60

    return minutes_ago > 120

while True:
    callbacks = await mythic.get_all_active_callbacks(
        mythic=mythic_client, 
        custom_return_attributes='id,display_id,last_checkin,host,description'
    )
    dead_callbacks = list(filter(is_callback_dead, callbacks))
    
    for c in dead_callbacks:
        await mythic.update_callback(
            mythic=mythic_client,
            callback_display_id=c['display_id'],
            active=False
        )
    
        print(f"{dt.now()} Hiding callback: {c['id']:<4} {c['display_id']:<4} {c['host']:<30} {c['description']:<20}")

    time.sleep(60)
