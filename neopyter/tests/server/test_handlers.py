import asyncio
from tornado.websocket import WebSocketClientConnection
from neopyter.msgpack_queue import clear_queue, labextension_queue
import base64
import json


async def test_call_push(jp_fetch, jp_ws_fetch):
    settings = {"mode": "proxy", "host": "127.0.0.1", "port": 9001}
    await clear_queue()
    r = await jp_fetch(
        "neopyter", "update_settings", method="POST", body=json.dumps(settings)
    )
    assert r.code == 200
    res = json.loads(r.body.decode())
    assert res["code"] == 0

    connection: WebSocketClientConnection = await jp_ws_fetch("neopyter", "channel")
    assert isinstance(connection, WebSocketClientConnection)
    await connection.write_message(base64.standard_b64encode("Hello".encode()))
    await asyncio.sleep(1)
    assert labextension_queue.qsize() == 1

    settings["mode"] = "direct"
