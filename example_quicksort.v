(* monae: Monadic equational reasoning in Coq                                 *)
(* Copyright (C) 2020 monae authors, license: LGPL-2.1-or-later               *)
From mathcomp Require Import all_ssreflect.
From mathcomp Require boolp.
Require Import monae_lib.
(* From HB Require Import structures. *)
Require Import hierarchy monad_lib fail_lib state_lib.
From infotheo Require Import ssr_ext.

(******************************************************************************)
(*                            Quicksort example                               *)
(*                                                                            *)
(* This file provides a formalization of quicksort on lists as proved in      *)
(* [1, Sect. 4]. The main lemmas is quicksort_slowsort.                       *)
(*                                                                            *)
(*           qperm s == permute the list s                                    *)
(*                      type: seq A -> M (seq A) with M : plusMonad           *)
(* is_partition p (s, t) == elements of s are smaller or equal to p, and      *)
(*                          elements of t are greater of equal to p           *)
(*     partition p s == partitions s into a partition w.r.t. p                *)
(*                      type: T -> seq T -> seq T * seq T                     *)
(*        slowsort s == choose a sorted list among all permutations of s      *)
(*           qsort s == sort s by quicksort                                   *)
(*                      type: seq T -> seq T                                  *)
(* functional_qsort.fqsort == same as qsort but defined with Function         *)
(*                                                                            *)
(* Reference:                                                                 *)
(* - [1] Shin-Cheng Mu, Tsung-Ju Chiang, Declarative Pearl: Deriving Monadic  *)
(*       Quicksort, FLOPS 2020                                                *)
(******************************************************************************)

(* TODO: shouldn't prePlusMonad be plusMonad (like list monad) and
    plusMonad be plusCIMonad (like set monad)? *)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Import Order.TTheory.
Local Open Scope order_scope.

Section sorted.
Variables (d : unit) (T : porderType d).

Let sorted_cons (r : rel T) (r_trans : transitive r) x (xs : seq T) :
  sorted r (x :: xs) = sorted r xs && all (r x) xs.
Proof.
apply/idP/idP => [ /= xxs |/andP[ _ /path_min_sorted /= ->//]].
rewrite (order_path_min r_trans xxs) ?andbT//.
exact: path_sorted xxs.
Qed.

Let sorted_rcons (r : rel T) (r_trans : transitive r) x (xs : seq T) :
  sorted r (rcons xs x) = sorted r xs && all (r^~ x) xs.
Proof.
rewrite -rev_sorted rev_rcons sorted_cons.
  by rewrite rev_sorted all_rev.
by apply /rev_trans /r_trans.
Qed.

Local Notation sorted := (sorted <=%O).

Let sorted_cons' x (xs : seq T) :
  sorted (x :: xs) = sorted xs && all (<=%O x) xs.
Proof. by rewrite sorted_cons //; exact le_trans. Qed.

Let sorted_rcons' x (xs : seq T) :
  sorted (rcons xs x) = sorted xs && all (>=%O x) xs.
Proof. by rewrite sorted_rcons //; apply le_trans. Qed.

Let sorted_cat' (a b : seq T) : sorted (a ++ b) -> sorted a && sorted b.
Proof.
elim: a b => //= h t ih b; rewrite cat_path => /andP[-> /=].
exact: path_sorted.
Qed.

(* TODO: try to reuse sorted lemmas from MathComp *)
Lemma sorted_cat_cons (x : T) (ys zs : seq T) :
  sorted (ys ++ x :: zs) = [&& sorted ys, sorted zs, all (<= x) ys & all (>= x) zs].
Proof.
apply/idP/idP => [|].
  move=> h; apply/and4P; split.
  - by apply: (subseq_le_sorted _ h) => //; apply: prefix_subseq.
  - apply: (subseq_le_sorted _ h) => //; rewrite -cat_rcons.
    exact: suffix_subseq.
  - by move: h; rewrite -cat_rcons => /sorted_cat'/andP[]; rewrite sorted_rcons' => /andP[].
  - by move: h; move/sorted_cat' => /andP[_]; rewrite sorted_cons' => /andP[].
case/and4P => ss ss' ps ps'; apply sorted_cat => //.
  by rewrite sorted_cons' ss' ps'.
move => a ain b bin; apply (@le_trans _ _ x).
- by move: ps => /allP; apply.
- by move: bin ps'; rewrite inE => /orP[/eqP ->//|] => /allP; apply.
Qed.

End sorted.

Local Open Scope monae_scope.
Local Open Scope tuple_ext_scope.
Local Open Scope mprog.

Section qperm.
Variables (M : plusMonad) (A : UU0).
Variables (d : unit) (T : porderType d).

Require Import Recdef.
Fail Function qperm (s : seq A) {measure size s} : M (seq A) :=
  if s isn't x :: xs then Ret [::] else
    splits xs >>= (fun '(ys, zs) => liftM2 (fun a b => a ++ x :: b) (qperm ys) (qperm zs)).

Local Obligation Tactic := idtac.
Program Definition qperm' (s : seq A)
    (f : forall s', size s' < size s -> M (seq A)) : M (seq A) :=
  if s isn't x :: xs then Ret [::] else
    tsplits xs >>= (fun '(ys, zs) => liftM2 (fun a b => a ++ x :: b) (f ys _) (f zs _)).
Next Obligation.
move=> [|h t] // ht x xs [xh xst] [a b] ys _ _ .
by apply: (leq_ltn_trans (size_bseq ys)); rewrite xst.
Qed.
Next Obligation.
move=> [|h t] // ht x xs [xh xst] [a b] _ zs _.
by apply: (leq_ltn_trans (size_bseq zs)); rewrite xst.
Qed.
Next Obligation. by []. Qed.

Definition qperm : seq A -> M (seq A) :=
  Fix (@well_founded_size _) (fun _ => M _) qperm'.

Lemma qperm'_Fix (s : seq A) (f g : forall y, (size y < size s)%N -> M (seq A)) :
  (forall y (p : (size y < size s)%N), f y p = g y p) -> qperm' f = qperm' g.
Proof.
move=> H; rewrite /qperm'; case: s f g H => // h t f g H.
bind_ext => -[a b] /=.
rewrite (_ : f = g) //; apply fun_ext_dep => s.
by rewrite boolp.funeqE => sht; exact: H.
Qed.

Lemma qperm_nil : qperm [::] = Ret [::].
Proof. by rewrite /qperm (Fix_eq _ _ _ qperm'_Fix). Qed.

Lemma qperm_cons x xs :
  qperm (x :: xs) = splits xs >>= (fun '(ys, zs) =>
                    liftM2 (fun a b => a ++ x :: b) (qperm ys) (qperm zs)).
Proof.
rewrite {1}/qperm {1}(Fix_eq _ _ _ qperm'_Fix) /=.
rewrite splitsE /= fmapE bindA; bind_ext => -[s1 s2] /=.
by rewrite bindretf.
Qed.

Definition qpermE := (qperm_nil, qperm_cons).

End qperm.
Arguments qperm {M} {A}.

(* TODO: move *)
Section guard_commute.
Variable M : plusMonad.
Variables (d : unit) (T : porderType d).

(* NB: on the model of nondetState_sub in state_lib.v *)
Definition nondetPlus_sub (M : plusMonad) A (n : M A) :=
  {m | ndDenote m = n}.

Lemma commute_plus
  A (m : M A) B (n : M B) C (f : A -> B -> M C) :
  nondetPlus_sub m -> commute m n f.
Proof.
case => x.
elim: x m n f => [{}A a m n f <-| B0 {}A n0 H0 n1 H1 m n2 f <- |
  A0 m n f <- | A0 n0 H0 n1 H1 m n2 f <-].
- rewrite /commute bindretf.
  by under [RHS] eq_bind do rewrite bindretf.
- rewrite /commute /= !bindA.
  transitivity (do x <- ndDenote n0; do y <- n2; ndDenote (n1 x) >>= f^~ y)%Do.
    bind_ext => s.
    by rewrite (H1 s).
  rewrite H0 //.
  bind_ext => b.
  by rewrite bindA.
- rewrite /commute /= bindfailf.
  transitivity (n >> fail : M C).
    by rewrite (@bindmfail M).
  bind_ext => b.
  by rewrite (@bindfailf M).
- rewrite /commute /= alt_bindDl.
  transitivity (do y <- n2; ndDenote n0 >>= f^~ y [~]
                          ndDenote n1 >>= f^~ y)%Do; last first.
    bind_ext => a.
    by rewrite alt_bindDl.
  by rewrite alt_bindDr H0 // H1.
Qed.

Lemma commute_guard_n (b : bool) B (n : M B) C (f : unit -> B -> M C) :
  commute (guard b) n f.
Proof.
apply commute_plus; exists (if b then ndRet tt else @ndFail _).
by case: ifP; rewrite (guardT, guardF).
Qed.

Lemma guard_splits A (p : pred T) (t : seq T) (f : seq T * seq T -> M A) :
  guard (all p t) >> (splits t >>= f) =
  splits t >>= (fun x => guard (all p x.1) >> guard (all p x.2) >> f x).
Proof.
elim: t p A f => [p A f|h t ih p A f].
  by rewrite /= 2!bindretf /= guardT bindmskip.
rewrite /= guard_and !bindA ih -bindA.
rewrite [in RHS]bindA -[in LHS]bindA. (* TODO : not robust *)
rewrite (@guardsC M (@bindmfail M) _).
rewrite bindA.
bind_ext => -[a b] /=.
rewrite assertE bindA bindretf bindA /=.
rewrite [in RHS]alt_bindDl /=.
do 2 rewrite bindretf /= guard_and !bindA.
rewrite -!bindA.
rewrite [in RHS](@guardsC M (@bindmfail M) (all p a)).
rewrite !bindA -alt_bindDr.
bind_ext; case; rewrite assertE bindmskip -[in RHS]alt_bindDr.
by bind_ext; case; rewrite alt_bindDl /= 2!bindretf -alt_bindDr.
Qed.

Lemma guard_splits' A (p : pred T) (t : seq T) (f : seq T * seq T -> M A) :
  splits t >>= (fun x => guard (all p t) >> f x) =
  splits t >>= (fun x => (guard (all p x.1) >> guard (all p x.2)) >> f x).
Proof.
rewrite -guard_splits (@guardsC M (@bindmfail M) _) bindA.
by bind_ext => -[a b]; rewrite guardsC; last exact : (@bindmfail M).
Abort.

Lemma guard_splits_cons A h (p : pred T) (t : seq T) (f : seq T * seq T -> M A) :
  guard (all p (h :: t)) >> (splits t >>= f)
  =
  splits t >>= (fun x => guard (all p x.1) >>
                         guard (all p x.2) >>
                         guard (p h) >> f x).
Proof.
rewrite /= guard_and bindA guard_splits commute_guard_n.
bind_ext => -[a b] /=.
by rewrite -bindA -!guard_and andbC.
Qed.

(* NB: corresponds to perm-preserves-all? *)
Lemma guard_all_qperm B (p : pred T) s (f : seq T -> M B) :
  guard (all p s) >>= (fun _ => qperm s >>= f) =
  qperm s >>= (fun x => guard (all p x) >> f x).
Proof.
have [n leMn] := ubnP (size s); elim: n => // n ih in s f leMn *.
case: s leMn => [|h t]; first by move=> _; rewrite /= qperm_nil 2!bindretf.
rewrite ltnS /= => tn.
rewrite qperm_cons bindA guard_splits_cons bindA.
rewrite splitsE /= fmapE 2!bindA; bind_ext => -[a b] /=.
rewrite 2!bindretf /=.
rewrite -2!guard_and -andbA andbC guard_and 2!bindA.
rewrite ih; last by rewrite (leq_trans _ tn) //= ltnS size_bseq.
rewrite commute_guard_n [in RHS]bindA; bind_ext => a'.
rewrite -bindA -guard_and -andbA andbC guard_and !bindA.
rewrite ih; last by rewrite (leq_trans _ tn) //= ltnS size_bseq.
rewrite commute_guard_n; bind_ext => b'.
by rewrite -bindA -!guard_and 2!bindretf -all_rcons -cat_rcons all_cat.
Qed.

End guard_commute.

Section partition.
Variable M : plusMonad.
Variables (d : unit) (T : porderType d).

Definition is_partition p (yz : seq T * seq T) :=
  all (<= p) yz.1 && all (>= p) yz.2.

Lemma is_partition_consL p x (ys zs : seq T) :
  is_partition p (x :: ys, zs) = (x <= p) && is_partition p (ys, zs).
Proof. by rewrite /is_partition /= andbA. Qed.

Lemma is_partition_consR p x (ys zs : seq T) :
  is_partition p (ys, x :: zs) = (x >= p) && is_partition p (ys, zs).
Proof. by rewrite /is_partition /= andbCA. Qed.

Definition is_partition_consE := (is_partition_consL, is_partition_consR).

Fixpoint partition p (s : seq T) : seq T * seq T :=
  if s isn't x :: xs then ([::], [::]) else
  let: yz := partition p xs in
  if x <= p then (x :: yz.1, yz.2) else (yz.1, x :: yz.2).

Lemma size_partition p (s : seq T) :
  size (partition p s).1 + size (partition p s).2 = size s.
Proof.
elim: s p => //= x xs ih p; have {ih} := ih p.
move H : (partition p xs) => h; case: h H => a b ab /= abxs.
by case: ifPn => xp /=; rewrite ?(addSn,addnS) abxs.
Qed.

End partition.

Section partition.
Variable M : plusMonad.
Variables (d : unit) (T : porderType d).

Lemma refin_partition (p : T) (xs : seq T) :
  total (<=%O : rel T) ->
  (Ret (partition p xs) : M (seq T * seq T)%type (*TODO: :> notation for `<=`?*))
  `<=`
  splits xs >>= assert (is_partition p).
Proof.
move => t.
elim: xs p => [p /=|x xs ih p].
  by rewrite /is_partition bindretf /refin /= !assertE !all_nil /= guardT bindskipf altmm.
rewrite /=.
rewrite bindA.
under eq_bind do rewrite alt_bindDl 2!bindretf 2!assertE.
under eq_bind do rewrite 2!is_partition_consE 2!guard_and 2!bindA.
apply: (@refin_trans _ _ _); last first.
  apply: refin_bindl => x0.
  apply: (refin_alt (refin_refl _)).
  apply: refin_bindr.
  exact: (refin_guard_le _ _ _ t).
apply: (@refin_trans _ _ _); last first.
  apply: refin_bindl => x1.
  exact: refin_if_guard.
under eq_bind do rewrite -bind_if.
apply: (@refin_trans _ _ (
  (do a <- splits xs;
  guard (is_partition p a) >> (Ret a >>= (fun a =>
  (if x <= p then Ret (x :: a.1, a.2) else Ret (a.1, x :: a.2)))))%Do)); last first.
  rewrite /refin -alt_bindDr.
  bind_ext => -[? ?] /=.
  by rewrite bindretf /= (altmm (_ : M _)).
under eq_bind do rewrite -bindA -assertE.
rewrite -bindA.
apply: (@refin_trans _ _ _); last exact/refin_bindr/ih.
rewrite bindretf.
by case: ifPn => xp; exact: refin_refl.
Qed.

End partition.

Section slowsort.
Variable M : plusMonad.
Variables (d : unit) (T : porderType d).

Local Notation sorted := (sorted <=%O).

Definition slowsort : seq T -> M (seq T) := (qperm >=> assert sorted).

Lemma slowsort_nil : slowsort [::] = Ret [::].
Proof.
rewrite /slowsort.
by rewrite kleisliE qpermE bindretf assertE guardT bindskipf.
Qed.

Lemma slowsort_cons p xs : slowsort (p :: xs) =
  splits xs >>= (fun '(ys, zs) => qperm ys >>=
    (fun ys' => qperm zs >>= (fun zs' => assert sorted (ys' ++ p :: zs')))).
Proof.
rewrite /slowsort kleisliE qperm_cons bindA.
by bind_ext => -[a b] /=; rewrite liftM2E.
Qed.
Print slowsort.

Lemma slowsort_splits p s : slowsort (p :: s) =
  splits s >>= (fun x => guard (is_partition p x) >>
  slowsort x.1 >>= (fun a => slowsort x.2 >>= (fun b => Ret (a ++ p :: b)))).
Proof.
rewrite slowsort_cons; bind_ext=> {s} -[a b].
rewrite /is_partition /slowsort !kleisliE /=.
rewrite guard_and !bindA (commute_guard_n (all (>= p) b)) guard_all_qperm.
bind_ext=> a'.
rewrite assertE bindA (@guardsC M (@bindmfail M) (sorted a')) bindretf !bindA.
rewrite guard_all_qperm commute_guard_n; bind_ext => b'.
rewrite assertE sorted_cat_cons /=.
rewrite andbA andbCA guard_and !bindA; bind_ext => -[].
rewrite andbC guard_and bindA; bind_ext => -[].
rewrite assertE andbC guard_and 2!bindA; bind_ext => -[].
by rewrite 2!bindretf assertE.
Qed.

Lemma refin_slowsort p s : total (<=%O : rel T) ->
  Ret (partition p s) >>= (fun '(a, b) =>
  slowsort a >>= (fun a' => slowsort b >>= (fun b' => Ret (a' ++ p :: b'))))
  `<=`
  slowsort (p :: s).
Proof.
move=> htot; rewrite slowsort_splits.
apply: refin_trans; first exact/refin_bindr/(refin_partition M p s htot).
rewrite bindA; apply: refin_bindl => -[a b].
rewrite assertE (bindA _ (fun _ => Ret (a, b))) bindretf /= bindA.
exact: refin_refl.
Qed.

End slowsort.
Arguments slowsort {M} {_} {_}.

Section qsort.
Variable M : plusMonad.
Variables (d : unit) (T : porderType d).

Program Fixpoint qsort' (s : seq T)
    (f : forall s', (size s' < size s)%N -> seq T) : seq T :=
  if s isn't p :: xs then [::] else
  let: (ys, zs) := partition p xs in
  f ys _ ++ p :: f zs _.
Next Obligation.
have := size_partition p xs.
by rewrite -Heq_anonymous /= => <-; rewrite ltnS leq_addr.
Qed.
Next Obligation.
have := size_partition p xs.
by rewrite -Heq_anonymous /= => <-; rewrite ltnS leq_addl.
Qed.

Definition qsort : seq T -> seq T :=
  Fix (@well_founded_size _) (fun _ => _) qsort'.

Lemma qsort'_Fix (x : seq T)
  (f g : forall y : seq T, (size y < size x)%N -> seq T) :
  (forall (y : seq T) (p : (size y < size x)%N), f y p = g y p) ->
  qsort' f = qsort' g.
Proof.
by move=> ?; congr qsort'; apply fun_ext_dep => ?; rewrite boolp.funeqE.
Qed.

Lemma qsort_nil : qsort [::] = [::].
Proof. by rewrite /qsort Fix_eq //; exact: qsort'_Fix. Qed.

Lemma qsort_cons p (xs : seq T) :
  qsort (p :: xs) = let: (ys, zs) := partition p xs in
                   qsort ys ++ p :: qsort zs.
Proof.
rewrite [in LHS]/qsort Fix_eq /=; last exact: qsort'_Fix.
by move s12 : (partition p xs) => h; case: h s12.
Qed.

Definition qsortE := (qsort_nil, qsort_cons).

Lemma quicksort_slowsort : total (<=%O : rel T) ->
  Ret \o qsort `<.=` (slowsort : _ -> M _).
Proof.
move=> htot s.
have [n sn] := ubnP (size s); elim: n => // n ih in s sn *.
case: s sn => [sn|h t].
  by rewrite /= qsort_nil slowsort_nil; exact: refin_refl.
rewrite ltnS /= => sn.
rewrite qsort_cons.
move htab : (partition h t) => ht; case: ht => a b in htab *.
apply: (refin_trans _ (refin_slowsort M h t htot)).
rewrite bindretf htab.
rewrite -(ih a); last first.
  by rewrite (leq_trans _ sn)// ltnS -(size_partition h t) htab leq_addr.
rewrite -(ih b); last first.
  by rewrite (leq_trans _ sn)// ltnS -(size_partition h t) htab leq_addl.
do 2 rewrite alt_bindDl bindretf.
by rewrite -altA; exact: refinR.
Qed.

End qsort.

Example qsort_nat :
  qsort [:: 3; 42; 230; 1; 67; 2]%N = [:: 1; 2; 3; 42; 67; 230]%N.
Proof. by repeat rewrite qsortE //=. Abort.

Example qsort_sort :
  let s := [:: 3; 42; 230; 1; 67; 2]%N in qsort s = sort ltn s.
Proof.
move=> s; rewrite /s sortE /=.
by repeat rewrite qsortE /=.
Abort.

(* NB: experiment with a version of qsort written with Function *)
Module functional_qsort.
Require Import Recdef.
From mathcomp Require Import ssrnat.
Section qsort_def.
Variables (M : plusMonad).
Variables (d : unit) (T : porderType d).
Function fqsort (s : seq T) {measure size s} : seq T :=
  (* if s isn't h :: t then [::]
  else let: (ys, zs) := partition h t in
       fqsort ys ++ h :: fqsort zs. *)
  (* NB: not using match causes problems when applying fqsort_ind
     which is automatically generated *)
  match s with
  | [::] => [::]
  | h :: t => let: (ys, zs) := partition h t in
              fqsort ys ++ h :: fqsort zs
  end.
Proof.
move=> s h t sht ys zs H.
have := size_partition h t.
by rewrite H /= => <-; apply/ltP; rewrite ltnS leq_addl.
move=> s h t sht ys zs H.
have := size_partition h t.
by rewrite H /= => <-; apply/ltP; rewrite ltnS leq_addr.
Defined.

Definition partition_slowsort (xs : seq T) : M (seq T) :=
  if xs isn't h :: t then Ret [::] else
  let: (ys, zs) := partition h t in
  liftM2 (fun a b => a ++ h :: b) (slowsort ys) (slowsort zs).

Lemma refin_partition_slowsort : total (<=%O : rel T) ->
  partition_slowsort `<.=` slowsort.
Proof.
move => hyp [|p xs]; first by rewrite slowsort_nil; exact: refin_refl.
rewrite [X in _ `<=` X]slowsort_splits.
rewrite [X in _ `<=` X](_ : _ = splits xs >>=
    (fun yz => assert (is_partition p) yz) >>=
    fun '(ys, zs) => slowsort ys >>=
    (fun ys' => slowsort zs >>= (fun zs'=> Ret (ys' ++ p :: zs')))); last first.
  rewrite bindA; bind_ext => -[s1 s2];rewrite !bindA assertE bindA.
  bind_ext => -[] /=.
  by rewrite bindretf /slowsort 2!kleisliE bindA.
rewrite /=.
apply: refin_trans; last exact/refin_bindr/refin_partition.
by rewrite bindretf; exact: refin_refl.
Qed.

Lemma refin_fqsort : (total (<=%O : rel T)) ->
  Ret \o fqsort `<.=` (slowsort : seq T -> M _).
Proof.
move=> hyp s => /=.
apply fqsort_ind => [s0 _|s0 h t sht ys zs pht ihys ihzs].
(* apply fqsort_ind => [s0 h t sht ys zs pht ihys ihzs|s0 x sx H]; last first. *)
  by rewrite slowsort_nil; exact: refin_refl.
apply: (refin_trans _ (refin_partition_slowsort hyp _)).
rewrite /= pht.
apply: (refin_trans _ (refin_liftM2 ihys ihzs)).
by rewrite liftM2_ret; exact: refin_refl.
Qed.

End qsort_def.

Example qsort_nat :
  fqsort [:: 3; 42; 230; 1; 67; 2]%N = [:: 1; 2; 3; 42; 67; 230]%N.
Proof.
do 4 rewrite fqsort_equation /=.
reflexivity.
Qed.

Eval compute in qsort [:: 3; 42; 230; 1; 67; 2]%N.
Eval compute in fqsort [:: 3; 42; 230; 1; 67; 2]%N.

End functional_qsort.
