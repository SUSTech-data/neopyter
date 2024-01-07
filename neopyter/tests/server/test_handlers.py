from tornado.websocket import WebSocketClientConnection
from neopyter.msgpack_queue import labextension_queue


# Teardown code
async def clear():
    while labextension_queue.qsize() > 0:
        await labextension_queue.get()


async def test_call_push(jp_ws_fetch):
    await clear()

    connection: WebSocketClientConnection = await jp_ws_fetch("neopyter", "channel")
    assert isinstance(connection, WebSocketClientConnection)
    await connection.write_message("Hello")
    assert labextension_queue.qsize() == 1
    assert labextension_queue.get() == "Hello"
