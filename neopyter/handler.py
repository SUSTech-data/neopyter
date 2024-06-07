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


settings = None
# {"mode": "proxy", "host": "127.0.0.1", "port": 9001}


class ForwardWebsocketHandler(WebSocketHandler):
    def open(self, *args: str, **kwargs: str) -> Optional[Awaitable[None]]:
        print("Websocket opened for lab extension")
        if settings and settings["mode"] == "direct":
            print("mode is direct, cann't connect jupyter server websocket")
            self.write("mode is direct, cann't connect jupyter server websocket")
            self.close()
            return

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
        if not tcpServer.is_running:
            return self.finish(
                {"code": 1, "message": "tcp server not start, please check server port"}
            )

        addrs = []
        for sock in tcpServer.server.sockets:
            ip, port = sock.getsockname()
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
        global settings
        settings = tornado.escape.json_decode(self.request.body)
        mode = settings.get("mode", "proxy")

        host = (settings.get("ip", "") or "").strip().split(",")
        while "" in host:
            host.remove("")

        port = settings.get("port", 9001)

        print("-------------debug-------------------")
        settings["mode"] = mode
        settings["host"] = host
        settings["port"] = port
        print(mode, host, port, tcpServer.is_running)
        if mode == "direct":
            if tcpServer.is_running:
                print("tcp server is running, will shutdown")
                asyncio.create_task(tcpServer.stop())
                return self.finish(
                    {
                        "code": 0,
                        "message": "success, tcp server is running, will shutdown",
                    }
                )
            print(" tcp server is closed")
            return self.finish(
                {
                    "code": 0,
                    "message": "success, tcp server is shutdown",
                }
            )

        if host == tcpServer.host and port == tcpServer.port and tcpServer.is_running:
            print("there are not update, ignore")
            return self.finish(
                {
                    "code": 0,
                    "message": "no update, don't restart server",
                }
            )

        tcpServer.host = host
        tcpServer.port = port
        print("will start tcpserver")
        asyncio.create_task(tcpServer.start())
        return self.finish(
            {
                "code": 0,
                "message": "start/restart tcpserver",
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
