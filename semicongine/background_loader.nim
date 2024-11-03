import std/syncio
import std/tables

type
  LoaderThreadArgs[T] =
    (ptr Channel[string], ptr Channel[LoaderResponse[T]], proc(f: string): T {.gcsafe.})
  LoaderResponse[T] = object
    file: string
    data: T
    error: string

  BackgroundLoader[T] = object
    loadRequestCn: Channel[string] # used for sending load requests
    responseCn: Channel[LoaderResponse[T]] # used for sending back loaded data
    worker: Thread[LoaderThreadArgs[T]] # does the actual loading from the disk
    responseTable: Table[string, LoaderResponse[T]] # stores results

proc loader[T](args: LoaderThreadArgs[T]) {.thread.} =
  while true:
    let file = args[0][].recv()
    try:
      args[1][].send(LoaderResponse[T](file: file, data: args[2](file)))
    except Exception as e:
      args[1][].send(LoaderResponse[T](file: file, error: e.msg))

proc fetchAll*(ld: var BackgroundLoader) =
  var (hasData, response) = ld.responseCn.tryRecv()
  while hasData:
    ld.responseTable[response.file] = response
    (hasData, response) = ld.responseCn.tryRecv()

proc requestLoading*(ld: var BackgroundLoader, file: string) =
  ld.loadRequestCn.send(file)

proc isLoaded*(ld: var BackgroundLoader, file: string): bool =
  ld.fetchAll * ()
  file in ld.responseTable

proc getLoaded*[T](ld: var BackgroundLoader[T], file: string): T =
  var item: LoaderResponse[T]
  doAssert ld.responseTable.pop(file, item)
  if item.error != "":
    raise newException(Exception, item.error)
  result = item.data

proc initBackgroundLoader*[T](
    loadFn: proc(f: string): T {.gcsafe.}
): ptr BackgroundLoader[T] =
  result = cast[ptr BackgroundLoader[T]](allocShared0(sizeof(BackgroundLoader[T])))
  open(result.loadRequestCn)
  open(result.responseCn)
  createThread[LoaderThreadArgs[T]](
    result.worker,
    loader[T],
    (addr result.loadRequestCn, addr result.responseCn, loadFn),
  )

# threaded background loaders

proc rawLoaderFunc(f: string): seq[byte] {.gcsafe.} =
  cast[seq[byte]](toSeq(f.readFile()))

proc audioLoaderFunc(f: string): seq[byte] {.gcsafe.} =
  cast[seq[byte]](toSeq(f.readFile()))

var rawLoader = initBackgroundLoader(rawLoaderFunc)
var rawLoader = initBackgroundLoader(rawLoaderFunc)
