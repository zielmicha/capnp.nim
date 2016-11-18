## Sending/receiving capn'p messages over stream in a same format as C++ RPC implementation.
import capnp, reactor

proc readSegments*(stream: Stream[byte]): Future[string] {.async.} =
  let segmentCount = int(await stream.readItem(uint32, littleEndian))
  if segmentCount > 512:
    raise newException(CapnpFormatError, "too many segments")

  var s = pack(segmentCount.uint32, littleEndian)

  var dataLength = 0
  for i in 0..segmentCount:
    let words = int(await stream.readItem(uint32, littleEndian))
    s &= pack(words.uint32, littleEndian)
    # FIXME: can this lead to DoS due to abort during overflow?
    dataLength += words * 8

  if segmentCount mod 2 == 1:
    discard (await stream.readItem(uint32, littleEndian))
    s &= "\0\0\0\0"

  if dataLength > capnp.bufferLimit:
    raise newException(CapnpFormatError, "message too long")

  s &= await stream.read(dataLength)
  return s

proc wrapStream*[T](stream: Stream[byte], t: typedesc[T]): Stream[T] {.asynciterator.} =
  ## Create a stream for receiving capn'p messages from byte stream.
  while true:
    let packed = await readSegments(stream)
    let val = newUnpacker(packed).unpackPointer(0, T)
    asyncYield val

#[
proc wrapProvider*[T](stream: Provider[byte]): Provider[T] =
  ## Create a provider for sending messages over byte provider.
  let (stream, provider) = newStreamProviderPair()

  proc pipe() {.async.} =
    asyncFor msg in stream:
      await stream.write(packStruct(msg))

  pipe().onErrorClose(stream)
  return provider
]#
