import asyncio
import tornado
from tornado.websocket import WebSocketHandler
from jupyter_server.utils import url_path_join
from jupyter_server.serverapp import ServerWebApplication
from jupyter_server.base.handlers import APIHandler
from typing import Union, Optional, Awaitable
import base64

from .msgpack_queue import labextension_queue, client_queue
from .tcp_server import tcpServer


class ForwardWebsocketHandler(WebSocketHandler):
    def open(self, *args: str, **kwargs: str) -> Optional[Awaitable[None]]:
        print("Websocket opened for lab extension")
        self.task = asyncio.create_task(self.start_loop())

        if not tcpServer.is_running:
            asyncio.create_task(tcpServer.start())

    def on_message(self, message: Union[str, bytes]) -> Optional[Awaitable[None]]:
        buf = message
        buf = base64.standard_b64decode(message)
        # print("put labextension_queue", buf)
        labextension_queue.put(buf)
        # print("write labextension_queue complete")

    def on_close(self) -> None:
        print("Websocket closed for lab extension")
        self.task = None

    async def start_loop(self):
        while self.task:
            while client_queue.qsize() > 0:
                buf = await client_queue.get()
                # print("get client_queue", buf)
                await self.write_message(base64.standard_b64encode(buf))
                # await self.write_message(buf)
            await asyncio.sleep(0.2)


class TcpServerInfoHandler(APIHandler):
    @tornado.web.authenticated
    def get(self):
        if not tcpServer.server:
            return self.finish(
                {"code": 1, "message": "tcp server not start, please check server port"}
            )

        addrs = []
        for sock in tcpServer.server.sockets:
            ip,port = sock.getsockname()
            addrs.append(f"{ip}:{port}")

        return self.finish(
            {
                "code": 0,
                "message": "success",
                "data": {"addrs": addrs},
            }
        )


class UpdateSettingsHandler(APIHandler):
    @tornado.web.authenticated
    def post(self):
        settings = tornado.escape.json_decode(self.request.body)
        host = (settings.get("ip", "") or "").strip().split(",")
        while "" in host:
            host.remove("")

        port = settings["port"]
        if host == tcpServer.host and port == tcpServer.port:
            return self.finish(
                {
                    "code": 0,
                    "message": "success, don't restart server",
                }
            )

        tcpServer.host = host
        tcpServer.port = port
        asyncio.create_task(tcpServer.start())
        return self.finish(
            {
                "code": 0,
                "message": "success",
            }
        )


def setup_handlers(web_app: ServerWebApplication):
    base_url = web_app.settings["base_url"]
    host_pattern = ".*$"

    def url(sub_route):
        return url_path_join(base_url, "neopyter", sub_route)

    handlers = [
        (url("channel"), ForwardWebsocketHandler),
        (url("get_server_info"), TcpServerInfoHandler),
        (url("update_settings"), UpdateSettingsHandler),
    ]
    web_app.add_handlers(host_pattern, handlers)
