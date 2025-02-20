{-# LANGUAGE TypeOperators #-}
module Behaviour where

import Rattus
import Rattus.Stream
import Rattus.Event hiding (map)
import Prelude hiding ((<*>),zip,map,scan,zipWith)


data Input = Input {addBall :: !Bool, removeBall :: !Bool, move :: !Move, time :: !Float}
data Move = StartLeft | EndLeft | StartRight | EndRight | NoMove

{-# ANN module Rattus #-}

type Vel = (Float:* Float)
type Pos = (Float:* Float)

size_x', size_y' :: Int
size_x' = 500
size_y' = 500

size_x = fromIntegral size_x'
size_y = fromIntegral size_y'

-- | vector addtition
(.+.) :: Pos -> Pos -> Pos
(x1:*y1) .+. (x2:*y2) = (x1+x2:*y1+y2)

-- | scalar multiplication
(.*.) :: Float -> Pos -> Pos
s .*. (x:*y) = (s*x:*s*y)


type Normal = (Float:* Float)


-- | Objects may cause collissions. Given a position, an object checks
-- whether a collusion occurred and if so returns the normal vector of
-- the surface
type Object = Pos -> Maybe' Normal

-- | List of all static objects in the game (i.e. the walls and the
-- ceiling)
staticObjects :: List Object
staticObjects =
  (\(x:*y) -> if size_x/2-5 <= x then Just' (-1:*0) else Nothing') :!
  (\(x:*y) -> if size_y/2-5 <= y then Just' (0:* -1) else Nothing') :!
  (\(x:*y) -> if x <= -size_x/2+5 then Just' (1:*0) else Nothing') :! Nil
  


checkCollision :: List Object -> Pos -> Maybe' Normal
checkCollision objs p =
  listToMaybe' $ mapMaybe' (\f -> f p) (objs +++ staticObjects)


applyCollision :: Normal -> Vel -> Vel
applyCollision (nx:*ny) (vx:*vy)
  | nx > 0 && vx < 0 = (-vx:*vy)
  | nx < 0 && vx > 0 = (-vx:*vy)
  | ny > 0 && vy < 0 = (vx:* -vy)
  | ny < 0 && vy > 0 = (vx:* -vy)
  | otherwise = (vx:*vy)

velTrans :: List Object -> Pos -> Vel -> Float -> Vel
velTrans objs p v t = (x:* y)
  where (x:*y) = maybe' v (`applyCollision` v) (checkCollision objs p)



movePadD :: Input -> Float -> Float
movePadD Input{move = StartRight} _ = 10
movePadD Input{move = StartLeft} _ = -10
movePadD Input{move = EndLeft} delta | delta < 0 = 0
movePadD Input{move = EndRight} delta | delta > 0 = 0
movePadD _ delta = if delta < 100 && delta > -100 then delta * 1.3 else delta


padStep :: (Float :* Float) -> Input -> (Float :* Float)
padStep (delta :* pos) inp = (delta' :* pos')
  where delta' = movePadD inp delta
        pos' = min (max (-size_x/2+20) (pos + delta' * time inp)) (size_x/2-20)

padPos :: Str (Input) -> Str Float
padPos xs = map (box snd') (scan (box padStep) (0:* 0) xs)


padObj :: Float -> Object
padObj p (x :* y) =
  if y <= -size_y/2+13 && y >= -size_y/2+5  && x >= p-20 && x <= p+20
  then Just' (0 :* 1)
  else Nothing'

-- ballPos :: Str (Float :* Input) -> Str (List Pos)
-- ballPos xs = map (box (fmap fst')) (scan (box ballStep') Nil xs)


-- ballStep :: (Pos :* Vel) -> (Float :* Input) -> (Pos :* Vel)
-- ballStep (p :* v) (pad :* inp) = (p .+. (time inp .*. v') :* v')
--   where v' = velTrans (padObj pad :! Nil) p v (time inp)

-- ballStep' :: List (Pos :* Vel) -> Float :* Input -> List (Pos :* Vel)
-- ballStep' bs inp = fmap (\ b -> ballStep b inp) bs


ballPos :: Str (Float :* Input) -> Str Pos
ballPos xs = map (box fst') (scan (box ballStep) ((0:*0):*(20:*50)) xs)


ballStep :: (Pos :* Vel) -> (Float :* Input) -> (Pos :* Vel)
ballStep (p :* v) (pad :* inp) = (p .+. (time inp .*. v') :* v')
  where v' = velTrans (padObj pad :! Nil) p v (time inp)


data ObjAction a b = Remove | Add ! (Str a -> Str b)

objTrans :: Event (ObjAction a b) -> List (Str b) -> Str a -> Str (List b)
objTrans (e ::: es) os xs = heads ::: delay (objTrans (adv es) (adv tails) (adv (tl xs)))
  where os' =
          case e of
            Nothing'         -> os
            Just' (Remove) -> init' os
            Just' (Add obj)  -> obj xs :! os
        tails = listDelay (fmap tl os')
        heads = fmap hd os'


ballTrig :: Input -> Maybe' (ObjAction (Float :* Input) Pos)
ballTrig inp 
  | addBall inp = Just' (Add ballPos)
  | removeBall inp = Just' (Remove)
  | otherwise   = Nothing'

pong :: Str Input -> Str (List Pos :* Float)
pong inp = zip ball pad  where
  pad = padPos inp
  ball = objTrans (map (box ballTrig) inp) Nil (zip pad inp)
