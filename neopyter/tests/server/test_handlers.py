import asyncio
from tornado.websocket import WebSocketClientConnection
from neopyter.msgpack_queue import clear_queue, labextension_queue
from neopyter.handler import settings
import base64


async def test_call_push(jp_ws_fetch):
    settings["mode"] = "proxy"
    await clear_queue()

    connection: WebSocketClientConnection = await jp_ws_fetch("neopyter", "channel")
    assert isinstance(connection, WebSocketClientConnection)
    await connection.write_message(base64.standard_b64encode("Hello".encode()))
    await asyncio.sleep(1)
    assert labextension_queue.qsize() == 1

    settings["mode"] = "direct"
