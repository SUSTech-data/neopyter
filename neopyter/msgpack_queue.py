
from tornado.queues import Queue
# from asyncio.queues import Queue

# jupyter lab frontend extension => labextension_queue => client(neovim)
labextension_queue = Queue()

# client(neovim) => client_queue => jupyter lab frontend extension
client_queue = Queue()


def clear_queue():
    while labextension_queue.qsize()> 0:
        labextension_queue.get()
    while client_queue.qsize()> 0:
        client_queue.get()

