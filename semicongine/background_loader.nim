import std/syncio
import std/tables

import ./core

proc loader[T](args: LoaderThreadArgs[T]) {.thread.} =
  while true:
    let (path, package) = args[0][].recv()
    try:
      args[1][].send(
        LoaderResponse[T](path: path, package: package, data: args[2](path, package))
      )
    except Exception as e:
      args[1][].send(LoaderResponse[T](path: path, package: package, error: e.msg))

proc fetchAll*(ld: var BackgroundLoader) =
  var (hasData, response) = ld.responseCn.tryRecv()
  while hasData:
    ld.responseTable[response.package & ":" & response.path] = response
    (hasData, response) = ld.responseCn.tryRecv()

proc requestLoading*(ld: var BackgroundLoader, path, package: string) =
  ld.loadRequestCn.send((path, package))

proc isLoaded*(ld: var BackgroundLoader, path, package: string): bool =
  fetchAll(ld)
  (package & ":" & path) in ld.responseTable

proc getLoadedData*[T](ld: var BackgroundLoader[T], path, package: string): T =
  var item: LoaderResponse[T]
  doAssert ld.responseTable.pop(package & ":" & path, item)
  if item.error != "":
    raise newException(Exception, item.error)
  result = item.data

proc initBackgroundLoader*[T](
    loadFn: proc(path, package: string): T {.gcsafe.}
): ptr BackgroundLoader[T] =
  result = createShared(BackgroundLoader[T])
  open(result.loadRequestCn)
  open(result.responseCn)
  createThread[LoaderThreadArgs[T]](
    result.worker,
    loader[T],
    (addr result.loadRequestCn, addr result.responseCn, loadFn),
  )
