-- NOTE with-K
module circuits.circuit where

open import Type
open import Function
open import Data.Nat.NP hiding (_≟_; compare)
open import Data.Bit renaming (_==_ to _==ᵇ_)
open import Data.Bits hiding (rewire; rewireTbl; map)
open import Data.Bits.Bits2
open import Data.Bool hiding (_≟_)
open import Data.Product hiding (swap; map)
import Data.Fin.NP as Fin
open Fin using (Fin; zero; suc; inject+; raise; #_)
open import Data.List using (List; []; _∷_)
import Data.Vec.NP as Vec
open Vec using (Vec; []; _∷_; foldr; _[_]≔_; lookup; _++_; splitAt; tabulate; allFin; concat; ++-decomp;
                tabulate-∘)
         renaming (map to vmap)
import Data.Vec.Properties as VecProps
open VecProps using (tabulate∘lookup)
open import Relation.Nullary.Decidable hiding (map)
open import Relation.Binary.PropositionalEquality
open import Composition.Horizontal
open import Composition.Vertical
open import Composition.Forkable

CircuitType : ★₁
CircuitType = (i o : ℕ) → ★

RunCircuit : CircuitType → ★
RunCircuit C = ∀ {i o} → C i o → i →ᵇ o

RewireFun : CircuitType
RewireFun i o = Fin o → Fin i

record RewiringBuilder (C : CircuitType) : ★₁ where
  constructor mk

  field
    isHComposable : HComposable C
    isVComposable : VComposable _+_ C
  open HComposable isHComposable
  open VComposable isVComposable

  field
    rewire : ∀ {i o} → RewireFun i o → C i o

  field
    idC : ∀ {i} → C i i

  field
    _=[_]=_ : ∀ {i o} → Bits i → C i o → Bits o → ★

    rewire-spec : ∀ {i o} (r : RewireFun i o) is → is =[ rewire r ]= Vec.rewire r is

{-
    _>>>-spec_ : ∀ {i m o} {c₀ : C i m} {c₁ : C m o} {is ms os} →
                 is =[ c₀ ]= ms → ms =[ c₁ ]= os → is =[ c₀ >>> c₁ ]= os

    _***-spec_ : ∀ {i₀ i₁ o₀ o₁} {c₀ : C i₀ o₀} {c₁ : C i₁ o₁} {is₀ is₁ os₀ os₁} →
                 is₀ =[ c₀ ]= os₀ → is₁ =[ c₁ ]= os₁ → (is₀ ++ is₁) =[ c₀ *** c₁ ]= (os₀ ++ os₁)

-}
    idC-spec : ∀ {i} (bs : Bits i) → bs =[ idC ]= bs
{-
  rewireWithTbl-spec : ∀ {i o} (t : RewireTbl i o) is
                       → is =[ rewireWithTbl t ]= Vec.rewireTbl t is
  rewireWithTbl-spec t is = {!rewire-spec ? ?!}
-}

  rewireWithTbl : ∀ {i o} → RewireTbl i o → C i o
  rewireWithTbl = rewire ∘ flip lookup

  idCDefault : ∀ {i} → C i i
  idCDefault = rewire id

  idCDefault-spec : ∀ {i} (bs : Bits i) → bs =[ idCDefault ]= bs
  idCDefault-spec bs
    = subst (λ bs' → bs =[ idCDefault ]= bs') (tabulate∘lookup bs) (rewire-spec id bs)

  sink : ∀ i → C i 0
  sink _ = rewire (λ())
-- sink-spec : bs =[ sink i ]= []

  dup₁ : ∀ o → C 1 o
  dup₁ _ = rewire (const zero)
-- dup₁-spec : (b ∷ []) =[ dup o ]= replicate o

  dup₁² : C 1 2
  dup₁² = dup₁ 2
-- dup₁²-spec : (b ∷ []) =[ dup₁² ]= (b ∷ b ∷ [])

  vcat : ∀ {i o n} → Vec (C i o) n → C (n * i) (n * o)
  vcat []       = idC
  vcat (x ∷ xs) = x *** vcat xs

  coerce : ∀ {i o} → i ≡ o → C i o
  coerce refl = idC

{-
  coerce-spec : ∀ {i o} {i≡o : i ≡ o} {is} →
                  is =[ coerce i≡o ]= subst Bits i≡o is
  coerce-spec = {!!}
-}

  {-
    Sends inputs 0,1,2,...,n to outputs 0,1,2,...,n,0,1,2,...,n,0,1,2,...,n,...
  -}
  dupⁿ : ∀ {i} k → C i (k * i)
  dupⁿ {i} k = rewireWithTbl (concat (replicate {n = k} (allFin i)))

{-
  dupⁿ-spec : ∀ {i} {is : Bits i} k → is =[ dupⁿ k ]= concat (replicate {n = k} is)
  dupⁿ-spec {i} {is} k = {!rewireWithTbl-spec (concat (replicate {n = k} (allFin _))) ?!}
-}

  {-
    Sends inputs 0,1,2,...,n to outputs 0,0,0,...,1,1,1,...,2,2,2,...,n,n,n,...
  -}
  dupⁿ′ : ∀ {i} k → C i (i * k)
  dupⁿ′ {i} k = rewireWithTbl (concat (vmap replicate (allFin i)))
{-
  dupⁿ′ {i} k = coerce (proj₂ ℕ°.*-identity i) >>>
                      (vcat {n = i} (replicate (dup₁ _)))
-}

  dup² : ∀ {i} → C i (i + i)
  dup² {i} = dupⁿ 2 >>> coerce (cong (_+_ i) (sym (ℕ°.+-comm 0 i)))

{-
  dup²-spec : ∀ {n} {is : Bits n} → is =[ dup² ]= (is ++ is)
  dup²-spec = coerce-spec (rewireWithTbl-spec {!!} {!!})
-}

  _&&&_ : ∀ {i o₀ o₁} → C i o₀ → C i o₁ → C i (o₀ + o₁)
  c₀ &&& c₁ = dup² >>> c₀ *** c₁

{-
  _&&&-spec_ : ∀ {i o₀ o₁} {c₀ : C i o₀} {c₁ : C i o₁} {is os₀ os₁}
               → is =[ c₀ ]= os₀ → is =[ c₁ ]= os₁ → is =[ c₀ &&& c₁ ]= (os₀ ++ os₁)
  pf₀ &&&-spec pf₁ = dup²-spec >>>-spec (pf₀ ***-spec pf₁)
-}

  ext-before : ∀ {k i o} → C i o → C (k + i) (k + o)
  ext-before {k} c = idC {k} *** c

  ext-after : ∀ {k i o} → C i o → C (i + k) (o + k)
  ext-after c = c *** idC

  commC : ∀ m n → C (m + n) (n + m)
  commC m n = rewireWithTbl (vmap (raise m) (allFin n) ++ vmap (inject+ n) (allFin m))

  dropC : ∀ {i} k → C (k + i) i
  dropC k = sink k *** idC

  takeC : ∀ {i} k → C (k + i) k
  takeC {i} k = commC k _ >>> dropC i

  swap : ∀ {i} (x y : Fin i) → C i i
  -- swap x y = arr (λ xs → (xs [ x ]≔ (lookup y xs)) [ y ]≔ (lookup x xs))
  swap x y = rewire (Fin.swap x y)

  rev : ∀ {i} → C i i
  rev = rewire Fin.reverse

  swap₂ : C 2 2
  swap₂ = rev
  -- swap₂ = swap (# 0) (# 1)

  Perm : ℕ → ★
  Perm n = List (Fin n × Fin n)

  perm : ∀ {i} → Perm i → C i i
  perm [] = idC
  perm ((x , y) ∷ π) = swap x y >>> perm π

  headC : ∀ {i} → C (1 + i) 1
  headC = takeC 1

  tailC : ∀ {i} → C (1 + i) i
  tailC = dropC 1

  open HComposable isHComposable public
  open VComposable isVComposable public

record CircuitBuilder (C : CircuitType) : ★₁ where
  constructor mk
  field
    isRewiringBuilder : RewiringBuilder C
    arr : ∀ {i o} → i →ᵇ o → C i o
    leafC : ∀ {o} → Bits o → C 0 o
    isForkable : Forkable suc C

  open RewiringBuilder isRewiringBuilder
  open Forkable isForkable renaming (fork to forkC)

{-
  field
    leafC-spec : ∀ {o} (os : Bits o) → [] =[ leafC os ]= os
    forkC-left-spec : ∀ {i o} {c₀ c₁ : C i o} {is os}
                      → is =[ c₀ ]= os → (0∷ is) =[ forkC c₀ c₁ ]= os
    forkC-right-spec : ∀ {i o} {c₀ c₁ : C i o} {is os}
                       → is =[ c₁ ]= os → (1∷ is) =[ forkC c₀ c₁ ]= os
-}
  bit : Bit → C 0 1
  bit b = leafC (b ∷ [])

{-
  bit-spec : ∀ b → [] =[ bit b ]= (b ∷ [])
  bit-spec b = leafC-spec (b ∷ [])
-}

  0ʷ : C 0 1
  0ʷ = bit 0b

  0ʷⁿ : ∀ {o} → C 0 o
  0ʷⁿ = leafC 0ⁿ

{-
  0ʷ-spec : [] =[ 0ʷ ]= 0∷ []
  0ʷ-spec = bit-spec 0b
-}

  1ʷ : C 0 1
  1ʷ = bit 1b

  1ʷⁿ : ∀ {o} → C 0 o
  1ʷⁿ = leafC 1ⁿ

{-
  1ʷ-spec : [] =[ 1ʷ ]= 1∷ []
  1ʷ-spec = bit-spec 1b
-}

  padL : ∀ {i} k → C i (k + i)
  padL k = 0ʷⁿ {k} *** idC

  padR : ∀ {i} k → C i (i + k)
  padR k = padL k >>> commC k _

  arr' : ∀ {i o} → i →ᵇ o → C i o
  arr' {zero}  f = leafC (f [])
  arr' {suc i} f = forkC (arr' {i} (f ∘ 0∷_)) (arr' (f ∘ 1∷_))

  unOp : (Bit → Bit) → C 1 1
  unOp op = arr (λ { (x ∷ []) → (op x) ∷ [] })

  notC : C 1 1
  notC = unOp not

  binOp : (Bit → Bit → Bit) → C 2 1
  binOp op = arr (λ { (x ∷ y ∷ []) → (op x y) ∷ [] })

  terOp : (Bit → Bit → Bit → Bit) → C 3 1
  terOp op = arr (λ { (x ∷ y ∷ z ∷ []) → (op x y z) ∷ [] })

  xorC : C 2 1
  xorC = binOp _xor_

  eqC : C 2 1
  eqC = binOp _==ᵇ_

  orC : C 2 1
  orC = binOp _∨_

  andC : C 2 1
  andC = binOp _∧_

  norC : C 2 1
  norC = binOp (λ x y → not (x ∨ y))

  nandC : C 2 1
  nandC = binOp (λ x y → not (x ∧ y))

  if⟨head=0⟩then_else_ : ∀ {i o} (c₀ c₁ : C i o) → C (1 + i) o
  if⟨head=0⟩then_else_ = forkC

  -- Base addition with carry:
  --   * Any input can be used as the carry
  --   * First output is the carry
  --
  -- This can also be seen as the addition of
  -- three bits which result is between 0 and 3
  -- and thus fits in two bit word in binary
  -- representation.
  --
  -- Alternatively you can see it as counting the
  -- number of 1s in a three bits vector.
  add₂ : C 3 2
  add₂ = carry &&& result
    where carry  : C 3 1
          carry  = terOp (λ x y z → x xor (y ∧ z))
          result : C 3 1
          result = terOp (λ x y z → x xor (y xor z))

  open RewiringBuilder isRewiringBuilder public

_→ᶠ_ : CircuitType
i →ᶠ o = Fin o → Fin i

finFunRewiringBuilder : RewiringBuilder _→ᶠ_
finFunRewiringBuilder = mk (opHComp (ixFunHComp Fin)) finFunOpVComp id id _=[_]=_ rewire-spec idC-spec
  where
    C = _→ᶠ_

    _=[_]=_ : ∀ {i o} → Bits i → C i o → Bits o → ★
    input =[ f ]= output = Vec.rewire f input ≡ output

    rewire-spec : ∀ {i o} (r : RewireFun i o) bs → bs =[ r ]= Vec.rewire r bs
    rewire-spec r bs = refl

    idC-spec : ∀ {i} (bs : Bits i) → bs =[ id ]= bs
    idC-spec = tabulate∘lookup

tblRewiringBuilder : RewiringBuilder RewireTbl
tblRewiringBuilder = mk (mk _>>>_) (mk _***_) tabulate (allFin _) _=[_]=_ rewire-spec idC-spec
  where
    C = RewireTbl

    _=[_]=_ : ∀ {i o} → Bits i → C i o → Bits o → ★
    input =[ tbl ]= output = Vec.rewireTbl tbl input ≡ output

    rewire-spec : ∀ {i o} (r : RewireFun i o) bs → bs =[ tabulate r ]= Vec.rewire r bs
    rewire-spec r bs = sym (tabulate-∘ (flip lookup bs) r)

    idC-spec : ∀ {i} (bs : Bits i) → bs =[ allFin _ ]= bs
    -- idC-spec = map-lookup-allFin
    idC-spec bs rewrite rewire-spec id bs = tabulate∘lookup bs

    _>>>_ : ∀ {i m o} → C i m → C m o → C i o
    c₀ >>> c₁ = Vec.rewireTbl c₁ c₀
    -- c₀ >>> c₁ = tabulate (flip lookup c₀ ∘ flip lookup c₁)
    -- c₀ >>> c₁ = vmap (flip lookup c₀) c₁

    _***_ : ∀ {i₀ i₁ o₀ o₁} → C i₀ o₀ → C i₁ o₁ → C (i₀ + i₁) (o₀ + o₁)
    _***_ {i₀} c₀ c₁ = vmap (inject+ _) c₀ ++ vmap (raise i₀) c₁

bitsFunRewiringBuilder : RewiringBuilder _→ᵇ_
bitsFunRewiringBuilder = mk bitsFunHComp bitsFunVComp Vec.rewire id _=[_]=_ rewire-spec idC-spec
  where
    C = _→ᵇ_

    _=[_]=_ : ∀ {i o} → Bits i → C i o → Bits o → ★
    input =[ f ]= output = f input ≡ output

    rewire-spec : ∀ {i o} (r : RewireFun i o) bs → bs =[ Vec.rewire r ]= Vec.rewire r bs
    rewire-spec r bs = refl

    idC-spec : ∀ {i} (bs : Bits i) → bs =[ id ]= bs
    idC-spec bs = refl

bitsFunCircuitBuilder : CircuitBuilder _→ᵇ_
bitsFunCircuitBuilder = mk bitsFunRewiringBuilder id (λ { bs [] → bs }) bitsFunFork

module BitsFunExtras where
  open CircuitBuilder bitsFunCircuitBuilder
  C = _→ᵇ_
  >>>-spec : ∀ {i m o} (c₀ : C i m) (c₁ : C m o) xs → (c₀ >>> c₁) xs ≡ c₁ (c₀ xs)
  >>>-spec _ _ _ = refl
  ***-spec : ∀ {i₀ i₁ o₀ o₁} (c₀ : C i₀ o₀) (c₁ : C i₁ o₁) xs {ys}
             → (c₀ *** c₁) (xs ++ ys) ≡ c₀ xs ++ c₁ ys
  ***-spec {i₀} c₀ c₁ xs {ys} with splitAt i₀ (xs ++ ys)
  ... | pre , post , eq with ++-decomp {xs = xs} {pre} {ys} {post} eq
  ... | eq1 , eq2 rewrite eq1 | eq2 = refl

open import FunUniverse.BinTree as BinTree hiding (_>>>_; _***_)

treeBitsRewiringBuilder : RewiringBuilder _→ᵗ_
treeBitsRewiringBuilder = mk BinTree.hcomposable BinTree.vcomposable rewire (rewire id) _=[_]=_ rewire-spec idC-spec
  where
    C = _→ᵗ_

    rewire : ∀ {i o} → RewireFun i o → C i o
    rewire f = fromFun (Vec.rewire f)

    _=[_]=_ : ∀ {i o} → Bits i → C i o → Bits o → ★
    input =[ tree ]= output = toFun tree input ≡ output

    rewire-spec : ∀ {i o} (r : RewireFun i o) bs → bs =[ rewire r ]= Vec.rewire r bs
    rewire-spec r = toFun∘fromFun (tabulate ∘ flip (Vec.lookup ∘ r))

    idC-spec : ∀ {i} (bs : Bits i) → bs =[ rewire id ]= bs
    idC-spec bs rewrite toFun∘fromFun (tabulate ∘ flip Vec.lookup) bs | tabulate∘lookup bs = refl

treeBitsCircuitBuilder : CircuitBuilder _→ᵗ_
treeBitsCircuitBuilder = mk treeBitsRewiringBuilder fromFun leaf BinTree.forkable

RewiringTree : CircuitType
RewiringTree i o = Tree (Fin i) o

module RewiringWith2^Outputs where
    C_⟨2^_⟩ = RewiringTree

    rewire : ∀ {i o} → RewireFun i (2^ o) → C i ⟨2^ o ⟩
    rewire f = fromFun (f ∘ toFin)

    lookupFin : ∀ {i o} → C i ⟨2^ o ⟩ → Fin (2^ o) → Fin i
    lookupFin c x = BinTree.lookup (fromFin x) c

    _>>>_ : ∀ {i m o} → C i ⟨2^ m ⟩ → C (2^ m) ⟨2^ o ⟩ → C i ⟨2^ o ⟩
    f >>> g = rewire (lookupFin f ∘ lookupFin g)

    _***_ : ∀ {i₀ i₁ o₀ o₁} → C i₀ ⟨2^ o₀ ⟩ → C i₁ ⟨2^ o₁ ⟩ → C (i₀ + i₁) ⟨2^ (o₀ + o₁) ⟩
    f *** g = f >>= λ x → map (Fin._+′_ x) g

module Test where
  open import Data.Bits.Bits4

  tbl : RewireTbl 4 4
  tbl = # 1 ∷ # 0 ∷ # 2 ∷ # 2 ∷ []

  fun : RewireFun 4 4
  fun zero = # 1
  fun (suc zero) = # 0
  fun (suc (suc zero)) = # 2
  fun (suc (suc (suc x))) = # 2

-- swap x y ≈ swap y x
-- reverse ∘ reverse ≈ id

  abs : ∀ {C} → RewiringBuilder C → C 4 4
  abs builder = swap₂ *** dup₁² *** sink 1
    where open RewiringBuilder builder

  tinytree : Tree (Fin 4) 2
  tinytree = fork (fork (leaf (# 1)) (leaf (# 0))) (fork (leaf (# 2)) (leaf (# 2)))

  bigtree : Tree (Bits 4) 4
  bigtree = fork (fork (fork (same 0000b) (same 0011b)) (fork (same 1000b) (same 1011b)))
                 (fork (fork (same 0100b) (same 0111b)) (fork (same 1100b) (same 1111b)))
    where same : ∀ {n} {A : ★} → A → Tree A (suc n)
          same x = fork (leaf x) (leaf x)

  test₁ : tbl ≡ tabulate fun
  test₁ = refl

  test₂ : tbl ≡ abs tblRewiringBuilder
  test₂ = refl

  test₃ : tabulate fun ≡ tabulate (abs finFunRewiringBuilder)
  test₃ = refl

  test₄ : bigtree ≡ abs treeBitsRewiringBuilder
  test₄ = refl

  open RewiringWith2^Outputs
  test₅ : tabulate (lookupFin tinytree) ≡ tbl
  test₅ = refl

  -- -}
  -- -}
  -- -}
