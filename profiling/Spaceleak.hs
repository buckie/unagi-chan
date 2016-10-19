{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import Control.Monad
import Control.Concurrent (threadDelay, forkIO)
import Control.Concurrent.Chan.Unagi
import System.Random
import qualified Data.ByteString.Char8 as BS8
import System.Mem (performMajorGC)

main :: IO ()
main =  do
  let numMsgs = 10000
  (i,o) <- newChan
  createAndWriteMsgs numMsgs i
  -- drain half and GC
  getLengthTotal 5000 0 Nothing o >>= print
  performMajorGC
  threadDelay 500000
  -- drain half and GC
  getLengthTotal 5000 0 Nothing o >>= print
  performMajorGC
  threadDelay 500000
  -- now for threaded
  createAndWriteMsgs' numMsgs i
  -- drain half and GC
  getLengthTotal 5000 0 Nothing o >>= print
  performMajorGC
  threadDelay 500000
  -- drain half and GC
  getLengthTotal 5000 0 Nothing o >>= print
  performMajorGC
  threadDelay 500000
  putStrLn "Done"

createAndWriteMsgs' :: Int -> InChan BS8.ByteString -> IO ()
createAndWriteMsgs' numMsgs i = void $ forkIO $ do
  !msgs <- replicateM numMsgs mkMsg
  mapM_ (writeChan i) msgs
  putStrLn "Writes Completed"

createAndWriteMsgs :: Int -> InChan BS8.ByteString -> IO ()
createAndWriteMsgs numMsgs i = do
  !msgs <- replicateM numMsgs mkMsg
  mapM_ (writeChan i) msgs
  putStrLn "Writes Completed"

getLengthTotal :: Int -> Int -> Maybe (Element BS8.ByteString) -> OutChan BS8.ByteString -> IO Int
getLengthTotal numMsgs cnt prevElem o = do
  elem' <- case prevElem of
    Nothing -> fst <$> tryReadChan o
    Just pe -> return pe
  e <- tryRead elem'
  case e of
    Nothing -> getLengthTotal numMsgs cnt (Just elem') o
    Just !b -> do
      newCnt <- return $! cnt + BS8.length b
      if numMsgs == 1
      then return newCnt
      else getLengthTotal (numMsgs - 1) newCnt Nothing o

mkMsg :: IO BS8.ByteString
mkMsg = do
  (i::Int) <- getStdRandom (randomR (1,10))
  return $! BS8.pack $ concat $ show <$> take 10000 (repeat i)
