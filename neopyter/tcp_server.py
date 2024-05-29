import socket
from typing import Optional
import asyncio
from asyncio import StreamReader, StreamWriter, Server
from jupyter_server.serverapp import ServerApp
# from jupyterlab_server.app import JupyterLabAp


from .msgpack_queue import clear_queue, labextension_queue, client_queue


async def check_port(host, port):
    try:
        _, w = await asyncio.open_connection(host, port)
        w.close()
        await w.wait_closed()
        return True
    except OSError:
        return False


async def find_empty_port(start_idx):
    idx = start_idx
    while await check_port("127.0.0.1", idx):
        idx = idx + 1
    return idx


def get_all_ip():
    hostname = socket.gethostname()
    ip_addresses = set()
    ip_addresses.add("127.0.0.1")
    for info in socket.getaddrinfo(hostname, None, family=socket.AF_INET):
        ip_addresses.add(info[4][0])
    return ip_addresses


class TcpServer(object):
    def __init__(self) -> None:
        self.server: Optional[Server] = None
        self.builtinHost = get_all_ip()
        self.host = []
        self.port = 9001

    @property
    def is_running(self) -> bool:
        return self.server is not None

    async def start(self):
        # support update?
        if self.server:
            print("stop old server")
            await self.stop()
        host = set.union(self.builtinHost, self.host)
        print("resolved host:", host)
        self.server = await asyncio.start_server(
            lambda r, w: self.client_connected(r, w), list(host), self.port
        )
        addrs = ", ".join(str(sock.getsockname()) for sock in self.server.sockets)
        print(f"Serving on {addrs}")

    async def client_connected(self, reader: StreamReader, writer: StreamWriter):
        if self.server is None:
            writer.close()
            await writer.wait_closed()
            return
        print("New client connected ")
        await clear_queue()
        await asyncio.gather(
            asyncio.create_task(self.start_reader_loop(reader, writer)),
            asyncio.create_task(self.start_writer_loop(writer)),
        )
        print("client disconnected")

    async def start_reader_loop(self, reader: StreamReader, writer: StreamWriter):
        print("Client reader loop start")
        server = self.server
        while not reader.at_eof() and server.sockets:
            buf = await reader.read(512)
            if len(buf) == 0:
                continue
            # print("put client_queue", buf)
            await client_queue.put(buf)
        writer.close()
        await writer.wait_closed()
        print("client reader loop end")

    async def start_writer_loop(self, writer: StreamWriter):
        print("Client writer loop start")
        server = self.server
        while not writer.is_closing() and server.sockets:
            while labextension_queue.qsize() > 0:
                buf = await labextension_queue.get()
                # print("get labextension_queue", buf)
                writer.write(buf)
            await asyncio.sleep(0.3)
        print("client writer loop end")

    async def stop(self):
        # maybe repeat check, whatever
        if self.server:
            self.server.close()
            await self.server.wait_closed()
            self.server = None


# global variable?
tcpServer = TcpServer()


def setup_tcp_server(app: ServerApp):
    global tcpServer
