{-# LANGUAGE CPP #-}
import Control.Applicative (Const(..))
import Data.Bits ((.&.), popCount)
import Data.Word (Word)
import Data.IntSet
import Data.List (nub,sort)
import qualified Data.List as List
import Data.Monoid (mempty)
import qualified Data.Set as Set
import IntSetValidity (valid)
import Prelude hiding (lookup, null, map, filter, foldr, foldl)
import Test.Tasty
import Test.Tasty.HUnit
import Test.Tasty.QuickCheck hiding ((.&.))

main :: IO ()
main = defaultMain $ testGroup "intset-properties"
                   [ testCase "lookupLT" test_lookupLT
                   , testCase "lookupGT" test_lookupGT
                   , testCase "lookupLE" test_lookupLE
                   , testCase "lookupGE" test_lookupGE
                   , testCase "split" test_split
                   , testProperty "prop_Valid" prop_Valid
                   , testProperty "prop_EmptyValid" prop_EmptyValid
                   , testProperty "prop_SingletonValid" prop_SingletonValid
                   , testProperty "prop_InsertIntoEmptyValid" prop_InsertIntoEmptyValid
                   , testProperty "prop_instanceEqIntSet" prop_instanceEqIntSet
                   , testProperty "prop_instanceOrdIntSet" prop_instanceOrdIntSet
                   , testProperty "prop_Single" prop_Single
                   , testProperty "prop_Member" prop_Member
                   , testProperty "prop_NotMember" prop_NotMember
                   , testProperty "prop_LookupLT" prop_LookupLT
                   , testProperty "prop_LookupGT" prop_LookupGT
                   , testProperty "prop_LookupLE" prop_LookupLE
                   , testProperty "prop_LookupGE" prop_LookupGE
                   , testProperty "prop_InsertDelete" prop_InsertDelete
                   , testProperty "prop_MemberFromList" prop_MemberFromList
                   , testProperty "prop_UnionInsert" prop_UnionInsert
                   , testProperty "prop_UnionAssoc" prop_UnionAssoc
                   , testProperty "prop_UnionComm" prop_UnionComm
                   , testProperty "prop_Diff" prop_Diff
                   , testProperty "prop_Int" prop_Int
                   , testProperty "prop_Ordered" prop_Ordered
                   , testProperty "prop_List" prop_List
                   , testProperty "prop_DescList" prop_DescList
                   , testProperty "prop_AscDescList" prop_AscDescList
                   , testProperty "prop_fromList" prop_fromList
                   , testProperty "prop_MaskPow2" prop_MaskPow2
                   , testProperty "prop_Prefix" prop_Prefix
                   , testProperty "prop_LeftRight" prop_LeftRight
                   , testProperty "prop_isProperSubsetOf" prop_isProperSubsetOf
                   , testProperty "prop_isProperSubsetOf2" prop_isProperSubsetOf2
                   , testProperty "prop_isSubsetOf" prop_isSubsetOf
                   , testProperty "prop_isSubsetOf2" prop_isSubsetOf2
                   , testProperty "prop_disjoint" prop_disjoint
                   , testProperty "prop_size" prop_size
                   , testProperty "prop_findMax" prop_findMax
                   , testProperty "prop_findMin" prop_findMin
                   , testProperty "prop_ord" prop_ord
                   , testProperty "prop_readShow" prop_readShow
                   , testProperty "prop_foldR" prop_foldR
                   , testProperty "prop_foldR'" prop_foldR'
                   , testProperty "prop_foldL" prop_foldL
                   , testProperty "prop_foldL'" prop_foldL'
                   , testProperty "prop_map" prop_map
                   , testProperty "prop_maxView" prop_maxView
                   , testProperty "prop_minView" prop_minView
                   , testProperty "prop_split" prop_split
                   , testProperty "prop_splitMember" prop_splitMember
                   , testProperty "prop_splitRoot" prop_splitRoot
                   , testProperty "prop_partition" prop_partition
                   , testProperty "prop_filter" prop_filter
                   , testProperty "prop_bitcount" prop_bitcount
                   , testProperty "prop_alterF_list" prop_alterF_list
                   , testProperty "prop_alterF_const" prop_alterF_const
                   ]

----------------------------------------------------------------
-- Unit tests
----------------------------------------------------------------

test_lookupLT :: Assertion
test_lookupLT = do
    lookupLT 3 (fromList [3, 5]) @?= Nothing
    lookupLT 5 (fromList [3, 5]) @?= Just 3

test_lookupGT :: Assertion
test_lookupGT = do
   lookupGT 4 (fromList [3, 5]) @?= Just 5
   lookupGT 5 (fromList [3, 5]) @?= Nothing

test_lookupLE :: Assertion
test_lookupLE = do
   lookupLE 2 (fromList [3, 5]) @?= Nothing
   lookupLE 4 (fromList [3, 5]) @?= Just 3
   lookupLE 5 (fromList [3, 5]) @?= Just 5

test_lookupGE :: Assertion
test_lookupGE = do
   lookupGE 3 (fromList [3, 5]) @?= Just 3
   lookupGE 4 (fromList [3, 5]) @?= Just 5
   lookupGE 6 (fromList [3, 5]) @?= Nothing

test_split :: Assertion
test_split = do
   split 3 (fromList [1..5]) @?= (fromList [1,2], fromList [4,5])

{--------------------------------------------------------------------
  Arbitrary, reasonably balanced trees
--------------------------------------------------------------------}
instance Arbitrary IntSet where
  arbitrary = do{ xs <- arbitrary
                ; return (fromList xs)
                }

{--------------------------------------------------------------------
  Valid IntMaps
--------------------------------------------------------------------}
forValid :: Testable a => (IntSet -> a) -> Property
forValid f = forAll arbitrary $ \t ->
    classify (size t == 0) "empty" $
    classify (size t > 0 && size t <= 10) "small" $
    classify (size t > 10 && size t <= 64) "medium" $
    classify (size t > 64) "large" $ f t

forValidUnitTree :: Testable a => (IntSet -> a) -> Property
forValidUnitTree f = forValid f

prop_Valid :: Property
prop_Valid = forValidUnitTree $ \t -> valid t

{--------------------------------------------------------------------
  Construction validity
--------------------------------------------------------------------}

prop_EmptyValid :: Property
prop_EmptyValid =
    valid empty

prop_SingletonValid :: Int -> Property
prop_SingletonValid x =
    valid (singleton x)

prop_InsertIntoEmptyValid :: Int -> Property
prop_InsertIntoEmptyValid x =
    valid (insert x empty)

{--------------------------------------------------------------------
  Instances for Eq and Ord
--------------------------------------------------------------------}

prop_instanceEqIntSet :: IntSet -> IntSet -> Bool
prop_instanceEqIntSet x y = (x == y) == (toAscList x == toAscList y)

prop_instanceOrdIntSet :: IntSet -> IntSet -> Bool
prop_instanceOrdIntSet x y = (compare x y) == (compare (toAscList x) (toAscList y))

{--------------------------------------------------------------------
  Single, Member, Insert, Delete, Member, FromList
--------------------------------------------------------------------}
prop_Single :: Int -> Bool
prop_Single x
  = (insert x empty == singleton x)

prop_Member :: [Int] -> Int -> Bool
prop_Member xs n =
  let m  = fromList xs
  in all (\k -> k `member` m == (k `elem` xs)) (n : xs)

prop_NotMember :: [Int] -> Int -> Bool
prop_NotMember xs n =
  let m  = fromList xs
  in all (\k -> k `notMember` m == (k `notElem` xs)) (n : xs)

test_LookupSomething :: (Int -> IntSet -> Maybe Int) -> (Int -> Int -> Bool) -> [Int] -> Bool
test_LookupSomething lookup' cmp xs =
  let odd_sorted_xs = filter_odd $ nub $ sort xs
      t = fromList odd_sorted_xs
      test x = case List.filter (`cmp` x) odd_sorted_xs of
                 []             -> lookup' x t == Nothing
                 cs | 0 `cmp` 1 -> lookup' x t == Just (last cs) -- we want largest such element
                    | otherwise -> lookup' x t == Just (head cs) -- we want smallest such element
  in all test xs

  where filter_odd [] = []
        filter_odd [_] = []
        filter_odd (_ : o : xs) = o : filter_odd xs

prop_LookupLT :: [Int] -> Bool
prop_LookupLT = test_LookupSomething lookupLT (<)

prop_LookupGT :: [Int] -> Bool
prop_LookupGT = test_LookupSomething lookupGT (>)

prop_LookupLE :: [Int] -> Bool
prop_LookupLE = test_LookupSomething lookupLE (<=)

prop_LookupGE :: [Int] -> Bool
prop_LookupGE = test_LookupSomething lookupGE (>=)

prop_InsertDelete :: Int -> IntSet -> Property
prop_InsertDelete k t
  = not (member k t) ==>
      case delete k (insert k t) of
        t' -> valid t' .&&. t' === t

prop_MemberFromList :: [Int] -> Bool
prop_MemberFromList xs
  = all (`member` t) abs_xs && all ((`notMember` t) . negate) abs_xs
  where abs_xs = [abs x | x <- xs, x /= 0]
        t = fromList abs_xs

{--------------------------------------------------------------------
  Union, Difference and Intersection
--------------------------------------------------------------------}
prop_UnionInsert :: Int -> IntSet -> Property
prop_UnionInsert x t =
  case union t (singleton x) of
    t' ->
      valid t' .&&.
      t' === insert x t

prop_UnionAssoc :: IntSet -> IntSet -> IntSet -> Bool
prop_UnionAssoc t1 t2 t3
  = union t1 (union t2 t3) == union (union t1 t2) t3

prop_UnionComm :: IntSet -> IntSet -> Bool
prop_UnionComm t1 t2
  = (union t1 t2 == union t2 t1)

prop_Diff :: [Int] -> [Int] -> Property
prop_Diff xs ys =
  case difference (fromList xs) (fromList ys) of
    t ->
      valid t .&&.
      toAscList t === List.sort ((List.\\) (nub xs)  (nub ys))

prop_Int :: [Int] -> [Int] -> Property
prop_Int xs ys =
  case intersection (fromList xs) (fromList ys) of
    t ->
      valid t .&&.
      toAscList t === List.sort (nub ((List.intersect) (xs)  (ys)))

prop_disjoint :: IntSet -> IntSet -> Bool
prop_disjoint a b = a `disjoint` b == null (a `intersection` b)

{--------------------------------------------------------------------
  Lists
--------------------------------------------------------------------}
prop_Ordered
  = forAll (choose (5,100)) $ \n ->
    let xs = concat [[i-n,i-n]|i<-[0..2*n :: Int]]
    in fromAscList xs == fromList xs

prop_List :: [Int] -> Bool
prop_List xs
  = (sort (nub xs) == toAscList (fromList xs))

prop_DescList :: [Int] -> Bool
prop_DescList xs = (reverse (sort (nub xs)) == toDescList (fromList xs))

prop_AscDescList :: [Int] -> Bool
prop_AscDescList xs = toAscList s == reverse (toDescList s)
  where s = fromList xs

prop_fromList :: [Int] -> Property
prop_fromList xs
  = case fromList xs of
      t -> valid t .&&.
           t === fromAscList sort_xs .&&.
           t === fromDistinctAscList nub_sort_xs .&&.
           t === List.foldr insert empty xs
  where sort_xs = sort xs
        nub_sort_xs = List.map List.head $ List.group sort_xs

{--------------------------------------------------------------------
  Bin invariants
--------------------------------------------------------------------}
powersOf2 :: IntSet
powersOf2 = fromList [2^i | i <- [0..63]]

-- Check the invariant that the mask is a power of 2.
prop_MaskPow2 :: IntSet -> Bool
prop_MaskPow2 (Bin _ msk left right) = member msk powersOf2 && prop_MaskPow2 left && prop_MaskPow2 right
prop_MaskPow2 _ = True

-- Check that the prefix satisfies its invariant.
prop_Prefix :: IntSet -> Bool
prop_Prefix s@(Bin prefix msk left right) = all (\elem -> match elem prefix msk) (toList s) && prop_Prefix left && prop_Prefix right
prop_Prefix _ = True

-- Check that the left elements don't have the mask bit set, and the right
-- ones do.
prop_LeftRight :: IntSet -> Bool
prop_LeftRight (Bin _ msk left right) = and [x .&. msk == 0 | x <- toList left] && and [x .&. msk == msk | x <- toList right]
prop_LeftRight _ = True

{--------------------------------------------------------------------
  IntSet operations are like Set operations
--------------------------------------------------------------------}
toSet :: IntSet -> Set.Set Int
toSet = Set.fromList . toList

-- Check that IntSet.isProperSubsetOf is the same as Set.isProperSubsetOf.
prop_isProperSubsetOf :: IntSet -> IntSet -> Bool
prop_isProperSubsetOf a b = isProperSubsetOf a b == Set.isProperSubsetOf (toSet a) (toSet b)

-- In the above test, isProperSubsetOf almost always returns False (since a
-- random set is almost never a subset of another random set).  So this second
-- test checks the True case.
prop_isProperSubsetOf2 :: IntSet -> IntSet -> Bool
prop_isProperSubsetOf2 a b = isProperSubsetOf a c == (a /= c) where
  c = union a b

prop_isSubsetOf :: IntSet -> IntSet -> Bool
prop_isSubsetOf a b = isSubsetOf a b == Set.isSubsetOf (toSet a) (toSet b)

prop_isSubsetOf2 :: IntSet -> IntSet -> Bool
prop_isSubsetOf2 a b = isSubsetOf a (union a b)

prop_size :: IntSet -> Property
prop_size s = sz === foldl' (\i _ -> i + 1) (0 :: Int) s .&&.
              sz === List.length (toList s)
  where sz = size s

prop_findMax :: IntSet -> Property
prop_findMax s = not (null s) ==> findMax s == maximum (toList s)

prop_findMin :: IntSet -> Property
prop_findMin s = not (null s) ==> findMin s == minimum (toList s)

prop_ord :: IntSet -> IntSet -> Bool
prop_ord s1 s2 = s1 `compare` s2 == toList s1 `compare` toList s2

prop_readShow :: IntSet -> Bool
prop_readShow s = s == read (show s)

prop_foldR :: IntSet -> Bool
prop_foldR s = foldr (:) [] s == toList s

prop_foldR' :: IntSet -> Bool
prop_foldR' s = foldr' (:) [] s == toList s

prop_foldL :: IntSet -> Bool
prop_foldL s = foldl (flip (:)) [] s == List.foldl (flip (:)) [] (toList s)

prop_foldL' :: IntSet -> Bool
prop_foldL' s = foldl' (flip (:)) [] s == List.foldl' (flip (:)) [] (toList s)

prop_map :: IntSet -> Bool
prop_map s = map id s == s

-- Note: we could generate an arbitrary strictly monotonic function by
-- restricting f using @\x y -> x < y ==> f x < f y@
-- but this will be inefficient given the probability of actually finding
-- a function that meets the criteria.
-- For now we settle on identity function and arbitrary linear functions
-- f x = a*x + b (with a being positive).
-- This might be insufficient to support any fancier implementation.
prop_mapMonotonicId :: IntSet -> Property
prop_mapMonotonicId s = mapMonotonic id s === map id s

prop_mapMonotonicLinear :: Positive Int -> Int -> IntSet -> Property
prop_mapMonotonicLinear (Positive a) b s = mapMonotonic f s === map f s
  where
    f x = a*x + b

prop_maxView :: IntSet -> Bool
prop_maxView s = case maxView s of
    Nothing -> null s
    Just (m,s') -> m == maximum (toList s) && s == insert m s' && m `notMember` s'

prop_minView :: IntSet -> Bool
prop_minView s = case minView s of
    Nothing -> null s
    Just (m,s') -> m == minimum (toList s) && s == insert m s' && m `notMember` s'

prop_split :: IntSet -> Int -> Property
prop_split s i = case split i s of
    (s1,s2) -> valid s1 .&&.
               valid s2 .&&.
               all (<i) (toList s1) .&&.
               all (>i) (toList s2) .&&.
               i `delete` s === union s1 s2

prop_splitMember :: IntSet -> Int -> Property
prop_splitMember s i = case splitMember i s of
    (s1,t,s2) -> valid s1 .&&.
                 valid s2 .&&.
                 all (<i) (toList s1) .&&.
                 all (>i) (toList s2) .&&.
                 t === i `member` s .&&.
                 i `delete` s === union s1 s2

prop_splitRoot :: IntSet -> Bool
prop_splitRoot s = loop ls && (s == unions ls)
 where
  ls = splitRoot s
  loop [] = True
  loop (s1:rst) = List.null
                  [ (x,y) | x <- toList s1
                          , y <- toList (unions rst)
                          , x > y ]

prop_partition :: IntSet -> Int -> Property
prop_partition s i = case partition odd s of
    (s1,s2) -> valid s1 .&&.
               valid s2 .&&.
               all odd (toList s1) .&&.
               all even (toList s2) .&&.
               s === s1 `union` s2

prop_filter :: IntSet -> Int -> Property
prop_filter s i =
  let parts = partition odd s
      odds = filter odd s
      evens = filter even s
  in valid odds .&&.
     valid evens .&&.
     parts === (odds, evens)

prop_bitcount :: Int -> Word -> Bool
prop_bitcount a w = bitcount_orig a w == bitcount_new a w
  where
    bitcount_orig a0 x0 = go a0 x0
      where go a 0 = a
            go a x = go (a + 1) (x .&. (x-1))
    bitcount_new a x = a + popCount x

prop_alterF_list
    :: Fun Bool [Bool]
    -> Int
    -> IntSet
    -> Property
prop_alterF_list f k s =
        fmap toSet (alterF     (applyFun f) k s)
    ===             Set.alterF (applyFun f) k (toSet s)

prop_alterF_const
    :: Fun Bool Bool
    -> Int
    -> IntSet
    -> Property
prop_alterF_const f k s =
        getConst (alterF     (Const . applyFun f) k s        )
    === getConst (Set.alterF (Const . applyFun f) k (toSet s))
