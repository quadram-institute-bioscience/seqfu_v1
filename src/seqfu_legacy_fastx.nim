import readfx
import readfx/nimklib as fxio
import streams

export fxio.GzFile
export fxio.Bufio
export fxio.xopen
export fxio.open
export fxio.close
export fxio.readLine

type
  FastxRecord* = tuple[seq, qual, name, comment: string, status, lastChar: int]
  SeqfuGzStream = ref object of StreamObj
    handle: fxio.Bufio[fxio.GzFile]
    closed: bool
    eof: bool

proc seqfuStreamReadData(s: Stream; buffer: pointer; bufLen: int): int
    {.nimcall, gcsafe, tags: [ReadIOEffect], raises: [IOError].} =
  let stream = SeqfuGzStream(s)
  if stream.closed:
    raise newException(IOError, "input stream is closed")
  var tmp = newString(bufLen)
  let n =
    try:
      {.cast(tags: [ReadIOEffect]).}:
        fxio.read(stream.handle, tmp, bufLen)
    except Exception as e:
      raise newException(IOError, e.msg)
  if n < 0:
    raise newException(IOError, "error reading input stream")
  if n > 0:
    copyMem(buffer, addr tmp[0], n)
  if n == 0:
    stream.eof = true
  result = n

proc seqfuStreamReadDataStr(s: Stream; buffer: var string; slice: Slice[int]): int
    {.nimcall, gcsafe, tags: [ReadIOEffect], raises: [IOError].} =
  if slice.b < slice.a:
    return 0
  if buffer.len <= slice.b:
    buffer.setLen(slice.b + 1)
  result = seqfuStreamReadData(s, addr buffer[slice.a], slice.b - slice.a + 1)

proc seqfuStreamAtEnd(s: Stream): bool
    {.nimcall, gcsafe, tags: [], raises: [].} =
  let stream = SeqfuGzStream(s)
  stream.eof or fxio.eof(stream.handle)

proc seqfuStreamReadLine(s: Stream; line: var string): bool
    {.nimcall, gcsafe, tags: [ReadIOEffect], raises: [IOError].} =
  let stream = SeqfuGzStream(s)
  if stream.closed:
    raise newException(IOError, "input stream is closed")
  try:
    {.cast(tags: [ReadIOEffect]).}:
      result = fxio.readLine(stream.handle, line)
  except Exception as e:
    raise newException(IOError, e.msg)
  if not result:
    stream.eof = true

proc seqfuStreamClose(s: Stream)
    {.nimcall, gcsafe, tags: [WriteIOEffect], raises: [IOError].} =
  let stream = SeqfuGzStream(s)
  if not stream.closed:
    try:
      {.cast(tags: [WriteIOEffect]).}:
        discard fxio.close(stream.handle)
    except Exception as e:
      raise newException(IOError, e.msg)
    stream.closed = true
    stream.eof = true

proc seqfuStreamUnsupportedSetPosition(s: Stream; pos: int)
    {.nimcall, gcsafe, tags: [], raises: [IOError].} =
  raise newException(IOError, "seeking is not supported")

proc seqfuStreamUnsupportedGetPosition(s: Stream): int
    {.nimcall, gcsafe, tags: [], raises: [IOError].} =
  raise newException(IOError, "seeking is not supported")

proc seqfuStreamUnsupportedPeek(s: Stream; buffer: pointer; bufLen: int): int
    {.nimcall, gcsafe, tags: [ReadIOEffect], raises: [IOError].} =
  raise newException(IOError, "peeking is not supported")

proc seqfuStreamUnsupportedWrite(s: Stream; buffer: pointer; bufLen: int)
    {.nimcall, gcsafe, tags: [WriteIOEffect], raises: [IOError].} =
  raise newException(IOError, "stream is read-only")

proc seqfuStreamFlush(s: Stream)
    {.nimcall, gcsafe, tags: [WriteIOEffect], raises: [].} =
  discard

proc openSeqfuGzStream*(filename: string): Stream =
  var handle: fxio.Bufio[fxio.GzFile]
  discard fxio.open(handle, filename)
  result = SeqfuGzStream(handle: handle)
  result.readDataImpl = seqfuStreamReadData
  result.readDataStrImpl = seqfuStreamReadDataStr
  result.readLineImpl = seqfuStreamReadLine
  result.atEndImpl = cast[typeof(result.atEndImpl)](seqfuStreamAtEnd)
  result.closeImpl = seqfuStreamClose
  result.setPositionImpl = cast[typeof(result.setPositionImpl)](seqfuStreamUnsupportedSetPosition)
  result.getPositionImpl = cast[typeof(result.getPositionImpl)](seqfuStreamUnsupportedGetPosition)
  result.peekDataImpl = seqfuStreamUnsupportedPeek
  result.writeDataImpl = seqfuStreamUnsupportedWrite
  result.flushImpl = seqfuStreamFlush

proc toFastxRecord(record: FQRecord): FastxRecord =
  result.seq = record.sequence
  result.qual = record.quality
  result.name = record.name
  result.comment = record.comment
  result.status = record.status
  result.lastChar = record.lastChar

proc toReadfxRecord(record: FastxRecord): FQRecord =
  result.sequence = record.seq
  result.quality = record.qual
  result.name = record.name
  result.comment = record.comment
  result.status = record.status
  result.lastChar = record.lastChar

proc readFastx*[T](f: var fxio.Bufio[T], record: var FastxRecord): bool {.discardable.} =
  var readfxRecord = record.toReadfxRecord()
  result = fxio.readFastx(f, readfxRecord)
  record = readfxRecord.toFastxRecord()

proc readIlv*[T](r1: var fxio.Bufio[T], r: var FastxRecord): bool {.discardable.} =
  var sq: FastxRecord

  if r1.readFastx(sq):
    r.seq = sq.seq
    r.name = sq.name & "/1"
    r.qual = sq.qual

  if r1.readFastx(sq):
    r.seq = r.seq & "N" & sq.seq
    r.name = r.name & "+" & sq.name & "/2"
    r.qual = r.qual & "!" & sq.qual
    return true
  else:
    return false

proc readPe*[T](r1, r2: var fxio.Bufio[T], r: var FastxRecord): bool {.discardable.} =
  var sq: FastxRecord

  if r1.readFastx(sq):
    r.seq = sq.seq
    r.name = sq.name & "/1"
    r.qual = sq.qual
  else:
    return false

  if r2.readFastx(sq):
    r.seq = r.seq & "N" & sq.seq
    r.name = r.name & "+" & sq.name & "/2"
    r.qual = r.qual & "!" & sq.qual
    return true
  else:
    return false
