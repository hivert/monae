(* monae: Monadic equational reasoning in Coq                                 *)
(* Copyright (C) 2020 monae authors, license: LGPL-2.1-or-later               *)
From mathcomp Require Import all_ssreflect.
From mathcomp Require boolp.
Require Import monae_lib.
From HB Require Import structures.
Require Import hierarchy monad_lib fail_lib.
From infotheo Require Import ssrZ.
Require Import ZArith.

(******************************************************************************)
(*                Definitions and lemmas about the array monad                *)
(*                                                                            *)
(*           aswap i j == swap the cells at addresses i and j; this is a      *)
(*                        computation of type (M unit)                        *)
(*       writeList i s == write the list s at address i; this is a            *)
(*                        computation of type (M unit)                        *)
(*          writeL i s := writeList i s >> Ret (size s)                       *)
(*    write2L i (s, t) := writeList i (s ++ t) >> Ret (size s, size t)        *)
(* write3L i (s, t, u) := writeList i (s ++ t ++ u) >>                        *)
(*                        Ret (size s, size t, size u)                        *)
(*        readList i n == read the list of values of size n starting at       *)
(*                        address i; it is a computation of type (M (seq E))  *)
(*                        where E is the type of stored elements              *)
(*                                                                            *)
(******************************************************************************)

Local Open Scope monae_scope.
Local Open Scope zarith_ext_scope.

Section marray.
Context {d : unit} {E : porderType d} {M : plusArrayMonad E Z_eqType}.
Implicit Type i j : Z.

Definition aswap i j : M unit :=
  aget i >>= (fun x => aget j >>= (fun y => aput i y >> aput j x)).

Lemma aswapxx i : aswap i i = skip.
Proof.
rewrite /aswap agetget.
under eq_bind do rewrite aputput.
by rewrite agetputskip.
Qed.

Fixpoint writeList i (s : seq E) : M unit :=
  if s isn't x :: xs then Ret tt else aput i x >> writeList (i + 1) xs.

Lemma aput_writeListC i j (x : E) (xs : seq E) : (i < j)%Z ->
  aput i x >> writeList j xs = writeList j xs >> aput i x.
Proof.
elim: xs i j => [|h tl ih] i j ij.
  by rewrite bindretf bindmskip.
rewrite /= -bindA aputC; last by left; apply/eqP/ltZ_eqF.
rewrite !bindA; bind_ext => -[].
by rewrite ih// ltZadd1; apply/ltZW.
Qed.

Lemma writeListC i j (ys zs : seq E) : (i + (size ys)%:Z <= j)%Z ->
  writeList i ys >> writeList j zs = writeList j zs >> writeList i ys.
Proof.
elim: ys zs i j => [|h t ih] zs i j hyp.
  by rewrite bindretf bindmskip.
rewrite /= aput_writeListC; last by rewrite ltZadd1; exact: leZZ.
rewrite bindA aput_writeListC; last first.
  apply: (ltZ_leZ_trans _ hyp).
  by apply: ltZ_addr => //; exact: leZZ.
rewrite -!bindA ih => [//|].
by rewrite /= natZS -add1Z addZA in hyp.
Qed.

Lemma aput_writeListCR i j (x : E) (xs : seq E) : (j + (size xs)%:Z <= i)%Z ->
  aput i x >> writeList j xs = writeList j xs >> aput i x.
Proof.
move=> ?.
have -> : aput i x = writeList i [:: x].
  by rewrite /= bindmskip.
by rewrite writeListC.
Qed.

Lemma writeList_cons i (x : E) (xs : seq E) :
  writeList i (x :: xs) = aput i x >> writeList (i + 1) xs.
Proof. by []. Qed.

Lemma writeList_cat i (s t : seq E) :
  writeList i (s ++ t) = writeList i s >> writeList (i + (size s)%:Z) t.
Proof.
elim: s i => [|h tl ih] i /=; first by rewrite bindretf addZ0.
by rewrite ih bindA -addZA add1Z natZS.
Qed.

Lemma writeList_rcons i (x : E) (xs : seq E) :
  writeList i (rcons xs x) = writeList i xs >> aput (i + (size xs)%:Z)%Z x.
Proof. by rewrite -cats1 writeList_cat /= -bindA bindmskip. Qed.

Definition writeL i (s : seq E) := writeList i s >> Ret (size s).

Definition write2L i '(s, t) := writeList i (s ++ t) >> Ret (size s, size t).

Definition write3L i '(s, t, u) :=
  writeList i (s ++ t ++ u) >> Ret (size s, size t, size u).

Lemma write_read i p : aput i p >> aget i = aput i p >> Ret p :> M _.
Proof. by rewrite -[RHS]aputget bindmret. Qed.

Lemma write_readC i j p : i != j ->
  aput i p >> aget j = aget j >>= (fun v => aput i p >> Ret v) :> M _.
Proof. by move => ?; rewrite -aputgetC // bindmret. Qed.

(* see postulate introduce-read in the Agda code *)
Lemma writeListRet i (p : E) (s : seq E) :
  writeList i (p :: s) >> Ret p = writeList i (p :: s) >> aget i.
Proof.
rewrite /=.
elim/last_ind: s p i => [|h t ih] /= p i.
  by rewrite bindmskip write_read.
transitivity ((aput i p >> writeList (i + 1) h >>
               aput (i + 1 + (size h)%:Z)%Z t) >> aget i); last first.
  by rewrite writeList_rcons !bindA.
rewrite ![RHS]bindA write_readC; last first.
  apply/eqP/gtZ_eqF; rewrite addZC; apply/ltZ_addl; first exact/leZ0n.
  exact/ltZadd1/leZZ.
rewrite -2![RHS]bindA -ih [RHS]bindA.
transitivity ((aput i p >> writeList (i + 1) h >>
               aput (i + 1 + (size h)%:Z)%Z t) >> Ret p).
  by rewrite writeList_rcons !bindA.
rewrite !bindA; bind_ext => -[].
by under [in RHS]eq_bind do rewrite bindretf.
Qed.

Lemma writeList_aswap i x h (t : seq E) :
  writeList i (rcons (h :: t) x) =
  writeList i (rcons (x :: t) h) >> aswap i (i + (size (rcons t h))%:Z).
Proof.
rewrite /aswap -!bindA writeList_rcons /=.
rewrite aput_writeListC; last by apply/ltZ_addr => //; exact: leZZ.
rewrite bindA.
rewrite aput_writeListC; last by apply/ltZ_addr => //; exact: leZZ.
rewrite writeList_rcons !bindA; bind_ext => -[].
under [RHS] eq_bind do rewrite -bindA.
rewrite aputget -bindA size_rcons -addZA natZS -add1Z.
under [RHS] eq_bind do rewrite -!bindA.
rewrite aputgetC; last first.
  apply/eqP/ltZ_eqF; rewrite addZA addZC; apply/ltZ_addl.
    exact/leZ0n.
  by apply/ltZ_addr => //; exact: leZZ.
rewrite -!bindA aputget aputput aputC; last by right.
by rewrite bindA aputput.
Qed.

Lemma aput_writeList_rcons i x h (t : seq E) :
  aput i x >> writeList (i + 1) (rcons t h) =
  aput i h >>
      ((writeList (i + 1) t >> aput (i + 1 + (size t)%:Z)%Z x) >>
        aswap i (i + (size t).+1%:Z)).
Proof.
rewrite /aswap -!bindA writeList_rcons -bindA.
rewrite aput_writeListC; last by rewrite ltZadd1; exact: leZZ.
rewrite aput_writeListC; last by rewrite ltZadd1; exact: leZZ.
rewrite !bindA; bind_ext => -[].
under [RHS] eq_bind do rewrite -bindA.
rewrite aputgetC; last first.
  apply/eqP/gtZ_eqF; rewrite addZC; apply/ltZ_addl; first exact: leZ0n.
  by apply/ltZ_addr => //; exact: leZZ.
rewrite -bindA -addZA natZS -add1Z aputget.
under [RHS] eq_bind do rewrite -!bindA.
rewrite aputget aputC; last by right.
by rewrite -!bindA aputput bindA aputput.
Qed.

(* TODO: rename *)
(* NB: used in the proof of writeList_ipartl *)
Lemma introduce_read_sub i (p : E) (xs : seq E) (f : E -> M (nat * nat)%type):
  writeList i (p :: xs) >> Ret p >> f p =
  writeList i (p :: xs) >> aget i >>= f.
Proof.
rewrite writeListRet 2!bindA /=.
rewrite aput_writeListC; last by apply/ltZ_addr => //; exact: leZZ.
rewrite 2!bindA.
under [LHS] eq_bind do rewrite -bindA aputget.
by under [RHS] eq_bind do rewrite -bindA aputget.
Qed.

Fixpoint readList i (n : nat) : M (seq E) :=
  if n isn't k.+1 then Ret [::] else liftM2 cons (aget i) (readList (i + 1) k).

End marray.