{-# OPTIONS_GHC -fno-warn-type-defaults #-}
{-# LANGUAGE NoImplicitPrelude #-}

module Course.StateTTest where

import qualified Prelude               as P ((++))

import           Test.QuickCheck       (forAllShrink)
import           Test.Tasty            (TestTree, testGroup)
import           Test.Tasty.HUnit      (testCase, (@?=))
import           Test.Tasty.QuickCheck (testProperty)

import           Course.Applicative    (pure, (<*>))
import           Course.Core
import           Course.ExactlyOne     (ExactlyOne (..))
import           Course.Functor        ((<$>))
import           Course.List           (List (..), flatMap, listh)
import           Course.ListTest       (genIntegerList, shrinkList)
import           Course.Monad          ((=<<), (>>=))
import           Course.Optional       (Optional (..))
import           Course.State          (put, runState)
import           Course.StateT         (OptionalT (..), StateT (..), distinct',
                                        distinctF, getT, putT, runOptionalT,
                                        runState', state')

test_StateT :: TestTree
test_StateT =
  testGroup "StateT" [
    functorTest
  , applicativeTest
  , monadTest
  , state'Test
  , runState'Test
  , getTTest
  , putTTest
  , distinct'Test
  , distinctFTest
  , optionalTFunctorTest
  ]

functorTest :: TestTree
functorTest =
  testCase "<$>" $
    runStateT ((+1) <$> (pure 2) :: StateT Int List Int) 0 @?= ((3,0) :. Nil)

applicativeTest :: TestTree
applicativeTest =
  testGroup "Applicative" [
    testCase "List (pure)" $ runStateT ((pure 2) :: StateT Int List Int) 0 @?= ((2,0) :. Nil)
  , testCase "List (<*>)" $ runStateT (pure (+2) <*> ((pure 2) :: StateT Int List Int)) 0 @?= ((4,0) :. Nil)
  , testCase "Optional" $
      let st = StateT (\s -> Full ((+2), s P.++ [1])) <*> (StateT (\s -> Full (2, s P.++ [2])))
       in runStateT st [0] @?= Full (4,[0,1,2])
  , testCase "List" $
      let st =     StateT (\s -> ((+2), s P.++ [1]) :. ((+3), s P.++ [1]) :. Nil)
               <*> (StateT (\s -> (2, s P.++ [2]) :. Nil))
       in runStateT st [0] @?= ((4,[0,1,2]) :. (5,[0,1,2]) :. Nil)
  ]

monadTest :: TestTree
monadTest =
  testGroup "Monad" [
    testCase "bind const" $
      runStateT (const (putT 2) =<< putT 1) 0 @?= (((), 2) :. Nil)
  , testCase "modify" $
      let modify f = StateT (\s -> pure ((), f s))
       in runStateT (modify (+1) >>= \() -> modify (*2)) 7 @?= (((), 16) :. Nil)
  ]

state'Test :: TestTree
state'Test =
  testCase "state'" $
    runStateT (state' $ runState $ put 1) 0 @?= ExactlyOne ((), 1)

runState'Test :: TestTree
runState'Test =
  testCase "runState'" $
    runState' (state' $ runState $ put 1) 0 @?= ((),1)

getTTest :: TestTree
getTTest =
  testCase "getTTest" $
    runStateT (getT :: StateT Int List Int) 3 @?= ((3,3) :. Nil)

putTTest :: TestTree
putTTest =
  testCase "putTTest" $
    runStateT (putT 2 :: StateT Int List ()) 0 @?= (((),2) :. Nil)

distinct'Test :: TestTree
distinct'Test =
  testProperty "distinct'" $
    forAllShrink genIntegerList shrinkList (\xs ->
      distinct' xs == distinct' (flatMap (\x -> x :. x :. Nil) xs))

distinctFTest :: TestTree
distinctFTest =
  testGroup "distinctF" [
    testCase "Full case" $ distinctF (listh [1,2,3,2,1]) @?= Full (listh [1,2,3])
  , testCase "Empty case" $ distinctF (listh [1,2,3,2,1,101]) @?= Empty
  ]

optionalTFunctorTest :: TestTree
optionalTFunctorTest =
  testCase "(<$>) for OptionalT" $
    runOptionalT ((+1) <$> OptionalT (Full 1 :. Empty :. Nil)) @?= (Full 2 :. Empty :. Nil)
