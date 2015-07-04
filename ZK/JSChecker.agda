{-# OPTIONS --without-K #-}
module ZK.JSChecker where

open import Type.Eq
open import Function         using (case_of_)
open import Data.Two.Base    using (_∧_)
open import Data.List.Base   using ([]; _∷_)

open import FFI.JS
open import FFI.JS.Check
-- open import FFI.JS.Proc using (URI; JSProc; showURI; server)
-- open import Control.Process.Type
import FFI.JS.Console as Console
import FFI.JS.Process as Process
import FFI.JS.FS as FS

import FFI.JS.BigI as BigI
open BigI using (BigI; bigI)

import Crypto.JS.BigI.FiniteField as Zq
import Crypto.JS.BigI.CyclicGroup as Zp
open import Crypto.JS.BigI.Params using (Params; module Params)
open import Crypto.JS.BigI.Checks using (check-params!)

-- TODO dynamise me
primality-test-probability-bound : Number
primality-test-probability-bound = readNumber "10"

-- TODO: check if this is large enough
min-bits-q : Number
min-bits-q = 256N

min-bits-p : Number
min-bits-p = 2048N

bigdec : JSValue → BigI
bigdec v = bigI (castString v) "10"

-- PoK: (Zero-Knowledge) Proof of Knowledge
-- CP: Chaum-Pedersen
-- EG: ElGamal
-- rnd: Knowledge of the secret, random exponent used in ElGamal encryption
record PoK-CP-EG-rnd (ℤq ℤp★ : Set) : Set where
  inductive -- NO_ETA
  field
    g y α β A B : ℤp★
    m c s : ℤq

verify-PoK-CP-EG-rnd :
  (p q : BigI)
  (pok : PoK-CP-EG-rnd Zq.ℤ[ q ] Zp.ℤ[ p ]★) → Bool
verify-PoK-CP-EG-rnd p q pok = gˢ==αᶜ·A ∧ yˢ==⟨β/M⟩ᶜ·B
  module verify-PoK-CP-EG-rnd where
    open module ℤq  = Zq q
    open module ℤp★ = Zp p
    open module ^-h = ^-hom {q}
    open module pok = PoK-CP-EG-rnd pok
    M = g ^ m
    gˢ==αᶜ·A     = g ^ s == (α ^ c) ** A
    yˢ==⟨β/M⟩ᶜ·B = y ^ s == ((β // M) ^ c) ** B

zk-check! : JSValue → JS!
zk-check! arg =
  check! "type of statement" (typ === fromString cpt)
         (λ _ → "Expected type of statement: " ++
                cpt ++ " not " ++ toString typ) >>
  BigI▹ℤp★ gI >>= λ g →
  BigI▹ℤp★ (bigdec (dat ·« "y"         »)) >>= λ y →
  BigI▹ℤp★ (bigdec (enc ·« "alpha"     »)) >>= λ α →
  BigI▹ℤp★ (bigdec (enc ·« "beta"      »)) >>= λ β →
  BigI▹ℤp★ (bigdec (com ·« "A"         »)) >>= λ A →
  BigI▹ℤp★ (bigdec (com ·« "B"         »)) >>= λ B →
  BigI▹ℤq  (bigdec (prf ·« "challenge" »)) >>= λ c →
  BigI▹ℤq  (bigdec (prf ·« "response"  »)) >>= λ s →
  BigI▹ℤq  (bigdec (dat ·« "plain"     »)) >>= λ m →
  check-params! gpq >>
  -- Console.log ("pok=" ++ JSON-stringify (fromAny pok)) >>
  check! "PoK-CP-EG-rnd" (verify-PoK-CP-EG-rnd pI qI
    (record
       { g = g
       ; y = y
       ; α = α
       ; β = β
       ; A = A
       ; B = B
       ; c = c
       ; s = s
       ; m = m
       }))
    (λ _ → "Invalid transcript")
 module zk-check where
    cpt = "chaum-pedersen-pok-elgamal-rnd"
    stm = arg ·« "statement" »
    typ = stm ·« "type" »
    dat = stm ·« "data" »
    enc = dat ·« "enc" »
    prf = arg ·« "proof" »
    com = prf ·« "commitment" »
    gI  = bigdec (dat ·« "g" »)
    pI  = bigdec (dat ·« "p" »)
    qI  = bigdec (dat ·« "q" »)
    gpq = record
            { primality-test-probability-bound = primality-test-probability-bound
            ; min-bits-q = min-bits-q
            ; min-bits-p = min-bits-p
            ; qI = qI
            ; pI = pI
            ; gI = gI
            }
    open module ℤq  = Zq qI using (BigI▹ℤq)
    open module ℤp★ = Zp pI using (BigI▹ℤp★)
    -- open module [ℤq]ℤp★ = ZqZp gpq

{-
srv : URI → JSProc
srv d =
  recv d λ q →
  send d (fromBool (zk-check q))
  end
-}

-- Working around Agda.Primitive.lsuc being undefined
-- case_of_ : {A : Set} {B : Set} → A → (A → B) → B
-- case x of f = f x

main : JS!
main =
  Process.argv >>= λ args →
  case JSArray▹ListString args of λ {
    (_node ∷ _run ∷ _test ∷ args') →
      case args' of λ {
        [] →
        Console.log "usage: No arguments"
        {- server "127.0.0.1" "1337" srv >>= λ uri →
           Console.log (showURI uri)
         -}
      ; (arg ∷ args'') →
          case args'' of λ {
            [] →
              Console.log ("Reading input file: " ++ arg) >>
              FS.readFile arg nullJS >>== λ err dat →
                check! "reading input file" (is-null err)
                       (λ _ → "readFile error: " ++ toString err) >>
                zk-check! (JSON-parse (toString dat))
          ; _ →
              Console.log "usage: Too many arguments"
          }
      }
  ; _ →
      Console.log "usage"
  }
-- -}
-- -}
-- -}
-- -}
