import collections/iface
import caprpc/rpcschema, capnp
import reactor

type
  VatNetwork* = distinct Interface

  Connection* = object of Pipe[Message]

  CapServer* = distinct Interface

interfaceMethods VatNetwork:
  connect(vatId: AnyPointer): Connection
  ## Creates a Connection to a remote vat.
  ## If your connection is over TCP or other stream-based protocol,
  ## you may use wrapBytePipe to turn BytePipe into Pipe[Message].

  accept(): Future[Connection]
  ## Waits for connection from a remote vat.

interfaceMethods CapServer:
  call(capId: uint64, payload: Payload): Payload
