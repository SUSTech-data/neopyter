from .handler import setup_handlers
from .tcp_server import setup_tcp_server

try:
    from ._version import __version__
except ImportError:
    # Fallback when using the package in dev mode without installing
    # in editable mode with pip. It is highly recommended to install
    # the package from a stable release or in editable mode: https://pip.pypa.io/en/stable/topics/local-project-installs/#editable-installs
    import warnings

    warnings.warn("Importing 'neopyter' outside a proper installation.")
    __version__ = "dev"


__all__ = [
    "_jupyter_server_extension_points",
    "_jupyter_labextension_paths",
    "_load_jupyter_server_extension",
]


def _jupyter_server_extension_points():
    return [{"module": "neopyter"}]


def _jupyter_labextension_paths():
    return [{"src": "labextension", "dest": "neopyter"}]


def _load_jupyter_server_extension(serverapp):
    """
    This function is called when the extension is loaded.
    """
    # print("load jupyter server extension")
    setup_handlers(serverapp.web_app)
    setup_tcp_server(serverapp)
