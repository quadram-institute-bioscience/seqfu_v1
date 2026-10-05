import readfx
import strformat
import strutils
import tables
from os import fileExists
import docopt
import ./repeat_utils
import ./seqfu_utils


type
  TandustStats = object
    totalReads: int
    passedReads: int
    discardedReads: int
    totalPairs: int
    passedPairs: int
    discardedPairs: int
    mate1Repeats: int
    mate2Repeats: int
    bothRepeats: int


proc tandustParsePositiveInt(value, name: string): int =
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(ValueError, name & " must be an integer")
  if result < 1:
    raise newException(ValueError, name & " must be >= 1")


proc tandustParseUnitFloat(value, name: string): float =
  try:
    result = parseFloat(value)
  except ValueError:
    raise newException(ValueError, name & " must be a number")
  if result <= 0.0 or result > 1.0:
    raise newException(ValueError, name & " must be > 0 and <= 1")


proc parseRepeatOptions(args: Table[string, Value]): RepeatOptions =
  result = RepeatOptions(
    maxUnit: tandustParsePositiveInt($args["--max-unit"], "--max-unit"),
    minFraction: tandustParseUnitFloat($args["--min-fraction"], "--min-fraction"),
    minIdentity: tandustParseUnitFloat($args["--min-identity"], "--min-identity"),
    minCopies: tandustParsePositiveInt($args["--min-copies"], "--min-copies")
  )
  validateRepeatOptions(result)


proc openOutput(filename: string): File =
  if filename == "nil" or filename == "-":
    return stdout
  open(filename, fmWrite)


proc closeOutput(f: File, filename: string) =
  if filename != "nil" and filename != "-" and f != nil:
    f.close()


proc writeReport(report: File, input, mate, name: string, hit: RepeatHit) =
  if report == nil or not hit.found:
    return
  report.writeLine(input, "\t", mate, "\t", name, "\t",
                   hit.period, "\t", hit.motif, "\t",
                   hit.start + 1, "\t", hit.stop, "\t",
                   hit.stop - hit.start, "\t",
                   fmt"{hit.identity:.4f}")


proc writeFastx(record: FQRecord, output: File) =
  print_seq(record, output)


proc writeFastx(record: FastxRecord, output: File) =
  print_seq(record, output)


proc processSingle(input: string, output: File, report: File, opts: RepeatOptions,
                   invert, verbose: bool): TandustStats =
  for record in readFQ(input):
    result.totalReads += 1
    let hit = findShortTandemRepeat(record.sequence, opts)
    if hit.found:
      result.discardedReads += 1
      writeReport(report, input, "SE", record.name, hit)
    else:
      result.passedReads += 1

    if hit.found == invert:
      writeFastx(record, output)

  if verbose:
    stderr.writeLine("Reads processed:  ", result.totalReads)
    stderr.writeLine("Reads passed:     ", result.passedReads)
    stderr.writeLine("Reads repetitive: ", result.discardedReads)


proc processPaired(inputR1, inputR2: string, outputR1, outputR2: File, report: File,
                   opts: RepeatOptions, pairPolicy: string, invert, verbose: bool): TandustStats =
  var
    fq1 = xopen[GzFile](inputR1)
    fq2 = xopen[GzFile](inputR2)
    r1: FastxRecord
    r2: FastxRecord

  defer: fq1.close()
  defer: fq2.close()

  while fq1.readFastx(r1):
    result.totalPairs += 1
    if not fq2.readFastx(r2):
      stderr.writeLine("ERROR: R2 ended prematurely after ", result.totalPairs - 1, " pairs")
      quit(1)

    let
      hit1 = findShortTandemRepeat(r1.seq, opts)
      hit2 = findShortTandemRepeat(r2.seq, opts)
      rep1 = hit1.found
      rep2 = hit2.found
      discardPair = if pairPolicy == "both": rep1 and rep2 else: rep1 or rep2

    if rep1:
      result.mate1Repeats += 1
      writeReport(report, inputR1, "R1", r1.name, hit1)
    if rep2:
      result.mate2Repeats += 1
      writeReport(report, inputR2, "R2", r2.name, hit2)
    if rep1 and rep2:
      result.bothRepeats += 1

    if discardPair:
      result.discardedPairs += 1
    else:
      result.passedPairs += 1

    if discardPair == invert:
      writeFastx(r1, outputR1)
      writeFastx(r2, outputR2)

  if fq2.readFastx(r2):
    stderr.writeLine("ERROR: R1 ended prematurely after ", result.totalPairs, " pairs")
    quit(1)

  result.totalReads = result.totalPairs * 2
  result.passedReads = result.passedPairs * 2
  result.discardedReads = result.discardedPairs * 2

  if verbose:
    stderr.writeLine("Pairs processed:      ", result.totalPairs)
    stderr.writeLine("Pairs passed:         ", result.passedPairs)
    stderr.writeLine("Pairs discarded:      ", result.discardedPairs)
    stderr.writeLine("Repetitive R1 reads:  ", result.mate1Repeats)
    stderr.writeLine("Repetitive R2 reads:  ", result.mate2Repeats)
    stderr.writeLine("Repetitive in both:   ", result.bothRepeats)


proc tandust*(argv: var seq[string]): int =
  let doc = """
Usage: tandust [options] [<input>]
       tandust [options] -1 <R1> [-2 <R2>]

Discard reads dominated by short tandem repeats.

The detector searches for a contiguous minimum-span window, and also checks the
whole read, for a periodic consensus motif. Ambiguous bases count against
identity but are never treated as motif matches.

Input:
  <input>                  Single-end FASTA/FASTQ input (or stdin with -)
  -1 --r1 FILE             R1 file for paired-end input
  -2 --r2 FILE             R2 file for paired-end input (auto-detected if omitted)
  --for-tag TAG            Pattern for R1 files [default: auto]
  --rev-tag TAG            Pattern for R2 files [default: auto]

Output:
  -o --output FILE/BASE    Output file (SE) or basename (PE)
  --r1-suffix SUFFIX       R1 output suffix in PE mode [default: _R1.fastq]
  --r2-suffix SUFFIX       R2 output suffix in PE mode [default: _R2.fastq]
  --invert                 Print discarded reads/pairs instead of passing reads/pairs
  --report FILE            Write repetitive-hit report as TSV

Repeat criteria:
  --max-unit N             Maximum repeat unit length [default: 6]
  --min-fraction F         Minimum read fraction covered by one repeat window [default: 0.75]
  --min-identity F         Minimum periodic consensus identity [default: 0.90]
  --min-copies N           Minimum repeat copies [default: 4]
  --pair-policy POLICY     PE discard policy: any or both [default: any]

Other:
  -v --verbose             Print summary statistics to stderr
  -h --help                Show this help

Examples:
  seqfu tandust reads.fq > clean.fq
  seqfu tandust -1 sample_R1.fq -o clean
  seqfu tandust reads.fq --invert --report repeats.tsv > repeats.fq
"""

  let args = docopt(doc, argv=argv, version="SeqFu " & version())

  var opts: RepeatOptions
  try:
    opts = parseRepeatOptions(args)
  except ValueError:
    stderr.writeLine("ERROR: ", getCurrentExceptionMsg())
    return 1

  let
    pairPolicy = $args["--pair-policy"]
    invert = bool(args["--invert"])
    verbose = bool(args["--verbose"])

  if pairPolicy != "any" and pairPolicy != "both":
    stderr.writeLine("ERROR: --pair-policy must be one of: any, both")
    return 1

  var
    inputR1: string
    inputR2: string
    isPaired = false

  if args["--r1"]:
    isPaired = true
    inputR1 = $args["--r1"]
    if args["--r2"]:
      inputR2 = $args["--r2"]
    else:
      inputR2 = guessR2(inputR1, $args["--for-tag"], $args["--rev-tag"], verbose)
      if inputR2 == "":
        stderr.writeLine("ERROR: Could not auto-detect R2 file for: ", inputR1)
        stderr.writeLine("Please specify -2 explicitly")
        return 1
  elif args["<input>"]:
    inputR1 = $args["<input>"]
  else:
    inputR1 = "-"

  if inputR1 != "-" and not fileExists(inputR1):
    stderr.writeLine("ERROR: Input file not found: ", inputR1)
    return 1
  if isPaired and inputR2 != "-" and not fileExists(inputR2):
    stderr.writeLine("ERROR: R2 file not found: ", inputR2)
    return 1
  if isPaired and inputR1 == inputR2:
    stderr.writeLine("ERROR: R1 and R2 inputs are the same file")
    return 1

  var report: File
  if args["--report"]:
    try:
      report = open($args["--report"], fmWrite)
      report.writeLine("input\tmate\trecord\tperiod\tmotif\tstart\tend\tspan\tidentity")
    except IOError:
      stderr.writeLine("ERROR: Cannot open report file: ", $args["--report"])
      return 1

  var outputR1, outputR2: File
  let outputBase = $args["--output"]

  try:
    if isPaired:
      if outputBase == "nil" or outputBase == "-":
        stderr.writeLine("ERROR: Output basename required for paired-end mode (-o)")
        return 1
      outputR1 = openOutput(outputBase & $args["--r1-suffix"])
      outputR2 = openOutput(outputBase & $args["--r2-suffix"])
    else:
      outputR1 = openOutput(outputBase)
  except IOError:
    stderr.writeLine("ERROR: Cannot open output file(s)")
    if report != nil:
      report.close()
    return 1

  if verbose:
    stderr.writeLine("SeqFu tandust v", version())
    stderr.writeLine("Mode: ", if isPaired: "paired-end" else: "single-end")
    stderr.writeLine("Repeat criteria: max-unit=", opts.maxUnit,
                     " min-fraction=", opts.minFraction,
                     " min-identity=", opts.minIdentity,
                     " min-copies=", opts.minCopies)

  discard if isPaired:
    processPaired(inputR1, inputR2, outputR1, outputR2, report,
                  opts, pairPolicy, invert, verbose)
  else:
    processSingle(inputR1, outputR1, report, opts, invert, verbose)

  if report != nil:
    report.close()
  if isPaired:
    closeOutput(outputR1, outputBase & $args["--r1-suffix"])
    closeOutput(outputR2, outputBase & $args["--r2-suffix"])
  else:
    closeOutput(outputR1, outputBase)

  return 0
