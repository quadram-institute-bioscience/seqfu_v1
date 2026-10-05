import math


type
  RepeatOptions* = object
    maxUnit*: int
    minFraction*: float
    minIdentity*: float
    minCopies*: int

  RepeatHit* = object
    found*: bool
    period*: int
    start*: int
    stop*: int
    identity*: float
    motif*: string


const defaultRepeatOptions* = RepeatOptions(
  maxUnit: 6,
  minFraction: 0.75,
  minIdentity: 0.90,
  minCopies: 4
)


func baseCode*(c: char): int {.inline.} =
  case c
  of 'A', 'a': 0
  of 'C', 'c': 1
  of 'G', 'g': 2
  of 'T', 't', 'U', 'u': 3
  else: -1


func codeBase(code: int): char {.inline.} =
  case code
  of 0: 'A'
  of 1: 'C'
  of 2: 'G'
  of 3: 'T'
  else: 'N'


func phaseBest(counts: array[4, int]): int {.inline.} =
  max(max(counts[0], counts[1]), max(counts[2], counts[3]))


func phaseBestCode(counts: array[4, int]): int {.inline.} =
  result = 0
  var best = counts[0]
  for i in 1 .. 3:
    if counts[i] > best:
      best = counts[i]
      result = i


func periodicMatches*(counts: openArray[array[4, int]], period: int): int =
  for phase in 0 ..< period:
    result += phaseBest(counts[phase])


func periodicIdentity*(counts: openArray[array[4, int]], period, span: int): float =
  if span <= 0:
    return 0.0
  periodicMatches(counts, period).float / span.float


func motifFromCounts*(counts: openArray[array[4, int]], period: int): string =
  result = newString(period)
  for phase in 0 ..< period:
    result[phase] = codeBase(phaseBestCode(counts[phase]))


proc validateRepeatOptions*(opts: RepeatOptions) =
  if opts.maxUnit < 1:
    raise newException(ValueError, "--max-unit must be >= 1")
  if opts.minCopies < 1:
    raise newException(ValueError, "--min-copies must be >= 1")
  if opts.minFraction <= 0.0 or opts.minFraction > 1.0:
    raise newException(ValueError, "--min-fraction must be > 0 and <= 1")
  if opts.minIdentity <= 0.0 or opts.minIdentity > 1.0:
    raise newException(ValueError, "--min-identity must be > 0 and <= 1")


proc scanPeriodSpan(sequence: string, period, span: int,
                    minIdentity: float): RepeatHit =
  let n = sequence.len
  if span > n:
    return

  var counts = newSeq[array[4, int]](period)

  for pos in 0 ..< span:
    let base = baseCode(sequence[pos])
    if base >= 0:
      inc counts[pos mod period][base]

  var identity = periodicIdentity(counts, period, span)
  if identity >= minIdentity:
    return RepeatHit(
      found: true,
      period: period,
      start: 0,
      stop: span,
      identity: identity,
      motif: motifFromCounts(counts, period)
    )

  if span < n:
    for start in 1 .. n - span:
      let
        oldPos = start - 1
        newPos = start + span - 1
        oldBase = baseCode(sequence[oldPos])
        newBase = baseCode(sequence[newPos])

      if oldBase >= 0:
        dec counts[oldPos mod period][oldBase]
      if newBase >= 0:
        inc counts[newPos mod period][newBase]

      identity = periodicIdentity(counts, period, span)
      if identity >= minIdentity:
        return RepeatHit(
          found: true,
          period: period,
          start: start,
          stop: start + span,
          identity: identity,
          motif: motifFromCounts(counts, period)
        )


proc findShortTandemRepeat*(sequence: string, opts: RepeatOptions = defaultRepeatOptions): RepeatHit =
  validateRepeatOptions(opts)

  let n = sequence.len
  if n == 0:
    return

  let fractionSpan = int(ceil(opts.minFraction * n.float))
  let maxPeriod = min(opts.maxUnit, n div opts.minCopies)

  for period in 1 .. maxPeriod:
    let minSpan = max(fractionSpan, period * opts.minCopies)
    if minSpan > n:
      continue

    result = scanPeriodSpan(sequence, period, minSpan, opts.minIdentity)
    if result.found:
      return

    if minSpan != n:
      result = scanPeriodSpan(sequence, period, n, opts.minIdentity)
      if result.found:
        return


proc isShortTandemRepeat*(sequence: string, opts: RepeatOptions = defaultRepeatOptions): bool {.inline.} =
  findShortTandemRepeat(sequence, opts).found
