"""Short, safe descriptions of upstream failures for the server log.

The API turns a failed weather or place lookup into a friendly 503, which on
its own leaves nothing in the logs to say why. These helpers give each 503 a
log line without leaking anything: no request URL (provider URLs can carry
coordinates or keys) and no response body.
"""


def describe_error(exc: BaseException | None) -> str:
    """The exception's type and, for an HTTP error, its status code."""
    if exc is None:
        return "none"
    status = getattr(getattr(exc, "response", None), "status_code", None)
    return f"{type(exc).__name__} (HTTP {status})" if status else type(exc).__name__


def describe_place_error(exc: BaseException) -> str:
    """The place-data failure plus what caused it (usually the last Overpass error)."""
    return f"{exc}; cause: {describe_error(exc.__cause__)}"
