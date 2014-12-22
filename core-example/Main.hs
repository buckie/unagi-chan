module Main (main) where

import Control.Monad
import System.Environment
import Control.Concurrent.MVar
import Control.Concurrent
import qualified Control.Concurrent.Chan.Unagi as U
import qualified Control.Concurrent.Chan.Unagi.Unboxed as UU
import qualified Control.Concurrent.Chan.Unagi.Bounded as UB
import qualified Control.Concurrent.Chan.Unagi.NoBlocking as UN
import qualified Control.Concurrent.Chan.Unagi.NoBlocking.Unboxed as UNU

import qualified Control.Concurrent.Chan as C
import qualified Control.Concurrent.STM.TQueue as S
import Control.Concurrent.STM

import Debug.Trace

-- This is a copy of the "async 100 writers 100 readers" from chan-benchmarks
 {-
main = do 
    (nm:other) <- getArgs
    let n = 1000000
        (r,w) = case other of
                     [rS,wS] -> (read rS, read wS)
                     _       -> (100,100)
    putStrLn $ "Running with "++show r++" readers, and "++ show w++" writers."
    case nm of
         "unagi" -> runU w r n
         "chan" -> runC w r n
         "stm"  -> runS w r n
-}

main = do
    [n] <- getArgs
    -- runU (read n)
    -- runUU (read n)
    -- runUB (read n)
    -- runUN (read n)
    -- runUNStream (read n)
    runUNUStream (read n)
{-
runU :: Int -> IO ()
runU n = do
  (i,o) <- U.newChan
  let n1000 = n `quot` 1000
  replicateM_ 1000 $ do
    replicateM_ n1000 $ U.writeChan i ()
    replicateM_ n1000 $ U.readChan o
 -}
{-
runUU :: Int -> IO ()
runUU n = do
  (i,o) <- UU.newChan
  let n1000 = n `quot` 1000
  replicateM_ 1000 $ do
    replicateM_ n1000 $ UU.writeChan i (0::Int)
    replicateM_ n1000 $ UU.readChan o

runUB :: Int -> IO ()
runUB n = do
  let n1000 = n `quot` 1000
  (i,o) <- UB.newChan n1000
  replicateM_ 1000 $ do
    replicateM_ n1000 $ UB.writeChan i (0::Int)
    replicateM_ n1000 $ UB.readChan o


tryReadChanErrUN :: UN.OutChan a -> IO a
{-# INLINE tryReadChanErrUN #-}
tryReadChanErrUN oc = UN.tryReadChan oc 
                    >>= UN.peekElement 
                    >>= maybe (error "A read we expected to succeed failed!") return

runUN n = do
  (i,o) <- UN.newChan
  let n1000 = n `quot` 1000
  replicateM_ 1000 $ do
    replicateM_ n1000 $ UN.writeChan i ()
    replicateM_ n1000 $ tryReadChanErrUN o

runUNStream n = do
  (i,o) <- UN.newChan
  [ oStream ] <- UN.streamChan 1 o
  let n1000 = n `quot` 1000
  let eat str = do
          x <- UN.tryNext str
          case x of
               UN.Pending -> return str
               UN.Cons _ str' -> eat str'
      writeAndEat iter str = unless (iter <=0) $ do
          replicateM_ n1000 $ UN.writeChan i ()
          eat str >>= writeAndEat (iter-1)
        
  writeAndEat (1000::Int) oStream
 -}
tryReadChanErrUNU :: UNU.UnagiPrim a=> UNU.OutChan a -> IO a
{-# INLINE tryReadChanErrUNU #-}
tryReadChanErrUNU oc = UNU.tryReadChan oc 
                    >>= UNU.peekElement 
                    >>= maybe (error "A read we expected to succeed failed!") return

runUNU n = do
  (i,o) <- UNU.newChan
  let n1000 = n `quot` 1000
  replicateM_ 1000 $ do
    replicateM_ n1000 $ UNU.writeChan i (0::Int)
    replicateM_ n1000 $ tryReadChanErrUNU o

runUNUStream n = do
  (i,o) <- UNU.newChan
  [ oStream ] <- UNU.streamChan 1 o
  let n1000 = n `quot` 1000
  let eat str = do
          x <- UNU.tryNext str
          case x of
               UNU.Pending -> return str
               UNU.Cons _ str' -> eat str'
      writeAndEat iter str = unless (iter <=0) $ do
          replicateM_ n1000 $ UNU.writeChan i (0::Int)
          eat str >>= writeAndEat (iter-1)
        
  writeAndEat (1000::Int) oStream

{-
runU :: Int -> Int -> Int -> IO ()
runU writers readers n = do
  let nNice = n - rem n (lcm writers readers)
      perReader = nNice `quot` readers
      perWriter = (nNice `quot` writers)
  vs <- replicateM readers newEmptyMVar
  (i,o) <- U.newChan
  let doRead = replicateM_ perReader $ theRead
      theRead = U.readChan o
      doWrite = replicateM_ perWriter $ theWrite
      theWrite = U.writeChan i (1 :: Int)
  mapM_ (\v-> forkIO (traceEventIO "READER START" >> doRead >> putMVar v ())) vs

  wWaits <- replicateM writers newEmptyMVar
  mapM_ (\v-> forkIO $ (takeMVar v >> traceEventIO "WRITER START" >> doWrite)) wWaits
  mapM_ (\v-> putMVar v ()) wWaits

  mapM_ takeMVar vs -- await readers

-- ------------------------------------------------
-- FOR COMPARISON:

runS :: Int -> Int -> Int -> IO ()
runS writers readers n = do
  let nNice = n - rem n (lcm writers readers)
      perReader = nNice `quot` readers
      perWriter = (nNice `quot` writers)
  vs <- replicateM readers newEmptyMVar
  tq <- S.newTQueueIO
  let doRead = replicateM_ perReader $ theRead
      theRead = (atomically . S.readTQueue) tq
      doWrite = replicateM_ perWriter $ theWrite
      theWrite = atomically $ S.writeTQueue tq (1 :: Int)
  mapM_ (\v-> forkIO (traceEventIO "READER START" >> doRead >> putMVar v ())) vs

  wWaits <- replicateM writers newEmptyMVar
  mapM_ (\v-> forkIO $ (takeMVar v >> traceEventIO "WRITER START" >> doWrite)) wWaits
  mapM_ (\v-> putMVar v ()) wWaits

  mapM_ takeMVar vs -- await readers

runC :: Int -> Int -> Int -> IO ()
runC writers readers n = do
  let nNice = n - rem n (lcm writers readers)
      perReader = nNice `quot` readers
      perWriter = (nNice `quot` writers)
  vs <- replicateM readers newEmptyMVar
  c <- C.newChan
  let doRead = replicateM_ perReader $ theRead
      theRead = C.readChan c
      doWrite = replicateM_ perWriter $ theWrite
      theWrite = C.writeChan c (1 :: Int)
  mapM_ (\v-> forkIO (traceEventIO "READER START" >> doRead >> putMVar v ())) vs

  wWaits <- replicateM writers newEmptyMVar
  mapM_ (\v-> forkIO $ (takeMVar v >> traceEventIO "WRITER START" >> doWrite)) wWaits
  mapM_ (\v-> putMVar v ()) wWaits

  mapM_ takeMVar vs -- await readers
-}
