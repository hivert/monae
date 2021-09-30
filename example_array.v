(* monae: Monadic equational reasoning in Coq                                 *)
(* Copyright (C) 2020 monae authors, license: LGPL-2.1-or-later               *)
From mathcomp Require Import all_ssreflect.
From mathcomp Require boolp.
Require Import monae_lib hierarchy monad_lib fail_lib state_lib example_quicksort.
From infotheo Require Import ssr_ext.

(*******************************************************************************)
(*                                   wip                                       *)
(*******************************************************************************)

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope order_scope.
Import Order.Theory.
Local Open Scope monae_scope.
Local Open Scope tuple_ext_scope.

From infotheo Require Import ssrZ.
Require Import ZArith.

Local Open Scope zarith_ext_scope.
Lemma ltZ_addl (a b c : Z) : (0 <= c -> a < b -> a < b + c)%Z.
Proof. Admitted.

Lemma ltZ_addr (a b c : Z) : (0 < c -> a <= b -> a < b + c)%Z.
Proof. Admitted.

(* TODO: move ssrZ *)
Lemma intRD (n m : nat) : (n + m)%:Z = (n%:Z + m%:Z)%Z.
Proof. exact: Nat2Z.inj_add. Qed.

(* TODO: add to ssrZ? *)
Lemma leZ0n (n : nat) : (0 <= n%:Z)%Z.
Proof. exact: Zle_0_nat. Qed.
(* Search _ Z.of_nat Z0. *)
Local Close Scope zarith_ext_scope.

Section marray.

Variable (d : unit) (E : porderType d) (M : plusArrayMonad E Z_eqType).

Fixpoint readList (i : Z) (n : nat) : M (seq E) :=
  if n isn't k.+1 then Ret [::] else liftM2 cons (aget i) (readList (i + 1) k).

Fixpoint writeList (i : Z) (s : seq E) : M unit :=
  if s isn't x :: xs then Ret tt else aput i x >> writeList (i + 1) xs.

Definition writeL (i : Z) (s : seq E) := writeList i s >> Ret (size s).

Definition write2L (i : Z) '(s1, s2) :=
  writeList i (s1 ++ s2) >> Ret (size s1, size s2).

Definition write3L (i : Z) '(xs, ys, zs) :=
  writeList i (xs ++ ys ++ zs) >> Ret (size xs, size ys, size zs).

Definition swap (i j : Z) : M unit := 
  aget i >>= (fun x => aget j >>= (fun y => aput i y >> aput j x)).

Fixpoint partl (p : E) (s : (seq E * seq E)%type) (xs : seq E)
    : (seq E * seq E)%type :=
  match xs with
  | [::] => s
  | x :: xs => if x <= p then partl p (s.1 ++ [:: x], s.2) xs
                         else partl p (s.1, s.2 ++ [:: x]) xs
  end.

Definition second {A B C} (f : B -> M C) (xy : (A * B)%type) := 
  f xy.2 >>= (fun y' => Ret (xy.1, y')).

(* Require Import FunInd.
Function partl' (p : E) (yzxs : (seq E * seq E * seq E)) {struct yzxs}
    : M (seq E * seq E)%type :=
  match yzxs with
  | (ys, zs, [::]) => Ret (ys, zs)
  | (ys, zs, x :: xs) => 
    if x <= p then (@qperm _ _ zs) >>= 
                (fun zs' => 
                  partl' p ((ys ++ [:: x]), zs', xs))
              else (@qperm _ _ (zs ++ [:: x])) >>=
                (fun zs' =>
                  partl' p (ys, zs', xs))
  end. *)

Fixpoint partl' (p : E) (ys zs xs : seq E) 
    : M (seq E * seq E)%type :=
  match xs with
  | [::] => Ret (ys, zs)
  | x :: xs => 
    if x <= p then (@qperm _ _ zs) >>= 
                (fun zs' => 
                  partl' p (ys ++ [:: x]) zs' xs)
              else (@qperm _ _ (zs ++ [:: x])) >>=
                (fun zs' =>
                  partl' p ys zs' xs)
  end.

Definition dispatch (x p : E) '(ys, zs, xs) : M (seq E * seq E * seq E)%type := 
  if x <= p then qperm zs >>= (fun zs' => Ret (ys ++ [:: x], zs', xs))
            else qperm (zs ++ [:: x]) >>= (fun zs' => Ret (ys, zs', xs)).

Definition uncurry3 :=
  (fun (A B C D : UU0) (f : A -> B -> C -> D) (X : A * B * C) =>
  let (p, c) := X in let (a, b) := p in f a b c).

Definition curry3 :=
  (fun (A B C D : UU0) (f : A * B * C -> D) =>
  fun a b c => f (a, b, c)).

Lemma partl'_dispatch (p x : E) (ys zs xs : seq E) :
  partl' p ys zs (x :: xs) = 
  dispatch x p (ys, zs, xs) >>= uncurry3 (partl' p).
Proof.
  rewrite /dispatch {1}/partl'.
  case: ifPn.
  rewrite bindA.
  move=> _.
  bind_ext.
  move=> s.
  by rewrite bindretf.
  rewrite bindA.
  move=> _.
  bind_ext.
  move=> s.
  by rewrite bindretf.
Qed.

(* not used 2021-09-24 :first equation on page10 *)
Lemma ipartl_spec (i : Z) (p : E) (ys zs xs : seq E) 
    (ipartl : E -> Z -> (nat * nat * nat)%type -> M (nat * nat)%type) : 
  writeList i (ys ++ zs ++ xs) >> ipartl p i (size ys, size zs, size xs)
  `<=` second qperm (partl p (ys, zs) xs) >>= write2L i.
Proof. Admitted.

Local Open Scope zarith_ext_scope.

Lemma writeList_cat (i : Z) (xs ys : seq E) :
  writeList i (xs ++ ys) = writeList i xs >> writeList (i + (size xs)%:Z) ys.
Proof.
elim: xs i => [|h t ih] i /=; first by rewrite bindretf addZ0.
by rewrite ih bindA -addZA add1Z natZS.
Qed.

(*
Fixpoint ipartl (p : E) (i : Z) (ny nz : nat) (nx : nat) : M (nat * nat)%type := 
  match nx with
  | 0 => Ret (ny, nz)
  | k.+1 => aget ((* i + *) (ny + nz)%:Z) >>= (fun x => (* TODO *)
         if x <= p then swap (i + ny%:Z) (i + ny%:Z + nz%:Z) >> ipartl p i (ny + 1) nz k
                   else ipartl p i ny (nz.+1) k)
  end.

(* Program Fixpoint iqsort (i : Z) (n : nat) : M unit := 
  match n with
  | 0 => Ret tt
  | n.+1 => aget i >>= (fun p =>
         ipartl p (i) 0 0 n >>= (fun '(ny, nz) =>
         swap i (i + ny%:Z) >>
         iqsort i ny >> iqsort (ny%:Z) nz))
  end. *)

(* Lemma lemma12 {i : Z} {xs : seq E} {p : E} : 
  writeList i xs >> iqsort i (size xs) `<=` _.
Proof. *)

(* Lemma lemma13 {i : Z} {ys : seq E} {p : E} : 
  perm ys >>= (fun ys' => writeList i (ys' ++ [:: p])) `>=` 
  writeList i (p :: ys) >> swap i (i + (size ys)%:Z).
Proof. *)
  
(* Qed. *)

*)
Lemma write_read {i : Z} {p} : aput i p >> aget i = aput i p >> Ret p :> M _.
Proof. by rewrite -[RHS]aputget bindmret. Qed.

Lemma write_readC {i j : Z} {p} : 
  i != j -> aput i p >> aget j = aget j >>= (fun v => aput i p >> Ret v) :> M _.
Proof. by move => ?; rewrite -aputgetC // bindmret. Qed.

Lemma writeList_cons {i : Z} (x : E) (xs : seq E) :
  writeList i (x :: xs) = aput i x >> writeList (i + 1) xs.
Proof. by done. Qed.

Lemma writeList_rcons {i : Z} (x : E) (xs : seq E) :
  writeList i (rcons xs x) = writeList i xs >> aput (i + (size xs)%:Z)%Z x.
Proof. by rewrite -cats1 writeList_cat /= -bindA bindmskip. Qed.

Lemma aput_writeListC (i j : Z) {x : E} {xs : seq E}:
  (i < j)%Z ->
  aput i x >> writeList j xs =
  writeList j xs >> aput i x.
Proof.
  elim: xs i j => [|h t ih] i j hyp.
  by rewrite bindretf bindmskip.
  rewrite /= -bindA aputC.
  rewrite !bindA.
  bind_ext => ?.
  apply: ih _.
  by rewrite ltZadd1; apply ltZW.
  by left; apply/eqP/ltZ_eqF.
Qed.

Lemma write_writeListC (i j : Z) {x : E} {xs : seq E}:
  (i < j)%Z ->
  aput i x >> writeList j xs =
  writeList j xs >> aput i x.
Proof.
  elim: xs i j => [|h t ih] i j hyp.
  by rewrite bindretf bindmskip.
  rewrite /= -bindA aputC.
  rewrite !bindA.
  bind_ext => ?.
  apply: ih _.
  by rewrite ltZadd1; apply ltZW.
  by left; apply/eqP/ltZ_eqF.
Qed.

Lemma writeList_writeListC {i j : Z} {ys zs : seq E}:
  (i + (size ys)%:Z <= j)%Z ->
  writeList i ys >> writeList j zs =
  writeList j zs >> writeList i ys.
Proof.
elim: ys zs i j => [|h t ih] zs i j hyp.
  by rewrite bindretf bindmskip.
rewrite /= write_writeListC; last first.
  by rewrite ltZadd1; exact: leZZ.
rewrite bindA write_writeListC; last first.
  apply: (ltZ_leZ_trans _ hyp).
  by apply: ltZ_addr => //; exact: leZZ.
rewrite -!bindA ih => [//|].
by rewrite /= natZS -add1Z (* -> addZ1 *) addZA in hyp.
Qed.

Lemma aput_writeListCR (i j : Z) {x : E} {xs : seq E}:
  (j + (size xs)%:Z <= i)%Z ->
  aput i x >> writeList j xs =
  writeList j xs >> aput i x.
Proof.
move=> ?.
have->: aput i x = writeList i [:: x].
by rewrite /= bindmskip.
by rewrite writeList_writeListC.
Qed.

Lemma introduce_read {i : Z} (p : E) (xs : seq E) :
  writeList i (p :: xs) >> Ret p =
  writeList i (p :: xs) >> aget i.
Proof.
  rewrite /=.
  elim/last_ind: xs p i => [/= p i|].
  by rewrite bindmskip write_read.
  move => h t ih p i /=.
  transitivity (
    (aput i p >> writeList (i + 1) h >> aput (i + 1 + (size h)%:Z)%Z t) >> aget i
  ); last first.
  by rewrite writeList_rcons !bindA.
  rewrite ![RHS]bindA.
  rewrite write_readC.
  rewrite -2![RHS]bindA -ih [RHS]bindA.
  transitivity (
    (aput i p >> writeList (i + 1) h >> aput (i + 1 + (size h)%:Z)%Z t) >> Ret p
  ).
  by rewrite writeList_rcons !bindA.
  rewrite !bindA.
  bind_ext => ?.
  bind_ext => ?.
  by rewrite bindretf.
  apply/negP =>/eqP/esym.
  apply ltZ_eqF.
  rewrite -{1}(addZ0 i) -addZA ltZ_add2l.
  apply addZ_gt0wl => //.
  apply/leZP.
  rewrite -natZ0 -leZ_nat //. (* TODO: cleanup *)
Qed.

Section dipartl.
Variables (p : E) (i : Z) (nx : nat).

Local Open Scope nat_scope.
Local Obligation Tactic := idtac.

Let nx_pair : Type := {x : nat * nat | x.1 + x.2 <= nx}.

Let rel_nx_pair : rel nx_pair := fun x y =>
  let x1 := (sval x).1 in let x2 := (sval x).2 in
  let y1 := (sval y).1 in let y2 := (sval y).2 in
  nx - x1 - x2 < nx - y1 - y2.

Lemma well_founded_rel_nx_pair : well_founded rel_nx_pair.
Proof.
apply: (@well_founded_lt_compat _ (fun x => nx - (sval x).1 - (sval x).2)).
by move=> x y ?; apply/ssrnat.ltP.
Qed.

Program Fixpoint dipartl' (nynz : nx_pair)
    (f : forall x, rel_nx_pair x nynz -> M nx_pair) : M nx_pair :=
  let ny := (sval nynz).1 in
  let nz := (sval nynz).2 in
  match Bool.bool_dec (ny + nz == nx) true with
  | left H =>  Ret _(*ny,nz*)
  | right H => aget (i + (ny + nz)%:Z)%Z >>= (fun x =>
    if (x <= p)%O then
      swap (i + ny%:Z)%Z (i + ny%:Z + nz%:Z)%Z >> @f _ _ (*ny.+1,nz*)
    else
      @f _ _ (*ny,nz.+1*))
  end.
Next Obligation.
by move=> [nynz ?] /= _ _ _; exists nynz.
Defined.
Next Obligation.
move=> [[ny nz] nynz] /= _ /negP H _ _ _.
exists (ny.+1, nz).
rewrite /= leq_eqVlt (negbTE H) /= in nynz *.
by rewrite addSn.
Defined.
Next Obligation.
move=> [[ny nz] nynz] /= _ /negP H _ _ _ /=; rewrite /rel_nx_pair /=.
have {}nynz : ny + nz < nx by move: nynz; rewrite /= ltn_neqAle H.
destruct nx as [|nx'] => //.
by rewrite subSS -2!subnDA subSn.
Defined.
Next Obligation.
move=> [[ny nz] nynz] /= _ + _ => /negP H.
exists (ny, nz.+1).
rewrite /= leq_eqVlt (negbTE H) /= in nynz *.
by rewrite addnS.
Defined.
Next Obligation.
move=> [[ny nz] nynz] /= _ /negP H _ _ /=; rewrite /rel_nx_pair /=.
have {}nynz : ny + nz < nx by move: nynz; rewrite /= ltn_neqAle H.
destruct nx as [|nx'] => //.
by rewrite subnS prednK // -subnDA subn_gt0.
Qed.

Definition dipartl : nx_pair -> M nx_pair :=
  Fix well_founded_rel_nx_pair (fun _ => M _) dipartl'.

End dipartl.

Print exist.

(*Program Definition ipartl (p : E) (i : Z) (ny nz : nat) (nx : nat) :=
  (@dipartl p i nx (exist (fun x => x.1 + x.2 <= nx) (ny, nz) _)).*)

Fixpoint ipartl (p : E) (i : Z) (ny nz : nat) (nx : nat) : M (nat * nat)%type :=
  match nx with
  | 0 => Ret (ny, nz)
  | k.+1 => aget (i + (ny + nz)%:Z)%Z >>= (fun x => (* TODO *)
           if x <= p then
             swap (i + ny%:Z) (i + ny%:Z + nz%:Z) >> ipartl p i ny.+1 nz k
           else
             ipartl p i ny nz.+1 k)
  end.

Local Obligation Tactic := idtac.
Program Fixpoint iqsort' (ni : (Z * nat))
    (f : forall (n'j : (Z * nat)), (n'j.2 < ni.2)%coq_nat -> M unit) : M unit :=
  match ni.2 with
  | 0 => Ret tt
  | n.+1 => aget ni.1 >>= (fun p =>
            @dipartl p (ni.1 + 1)%Z n
              (exist (fun x => x.1 + x.2 <= n) (0, 0) isT) >>= (fun nynz =>
              let ny := (sval nynz).1 in
              let nz := (sval nynz).2 in
              swap ni.1 (ni.1 + ny%:Z) >>
              f (ni.1, ny) _ >> f ((ni.1 + ny%:Z + 1)%Z, nz) _))
  end.
Next Obligation.
move => [i [//|_]] /= _ n [<-] p [] [ny nz] /= nynz _.
apply/ssrnat.ltP; rewrite ltnS.
rewrite (leq_trans _ nynz) //.
rewrite leq_addr //.
Qed.
Next Obligation.
move => [i [//|_]] /= _ n [<-] p [] [ny nz] /= nynz _.
apply/ssrnat.ltP; rewrite ltnS.
rewrite (leq_trans _ nynz) //.
rewrite leq_addl //.
Qed.

Lemma well_founded_lt2 : well_founded (fun x y : (Z * nat) => (x.2 < y.2)%coq_nat).
Proof. 
  apply: (@well_founded_lt_compat _ _).
  move => [x1 x2] [y1 y2]; exact.
Qed.
  
Definition iqsort : (Z * nat) -> M unit :=
  Fix well_founded_lt2 (fun _ => M unit) iqsort'.

Lemma iqsort'_Fix (ni : (Z * nat))
  (f g : forall (n'j : (Z * nat)), (n'j.2 < ni.2)%coq_nat -> M unit) :
  (forall (n'j : (Z * nat)) (p : (n'j.2 < ni.2)%coq_nat), f n'j p = g n'j p) ->
  iqsort' f = iqsort' g.
Proof.
  by move=> ?; congr iqsort'; apply fun_ext_dep => ?; rewrite boolp.funeqE.
Qed.

Lemma iqsort_nil {i : Z} : iqsort (i, 0) = Ret tt.
Proof. rewrite /iqsort Fix_eq //; exact: iqsort'_Fix. Qed.

Lemma iqsort_cons {i : Z} {n : nat}: iqsort (i, n.+1) = aget i >>= (fun p =>
@dipartl p (i + 1)%Z n
  (exist (fun x => x.1 + x.2 <= n) (0, 0) isT) >>= (fun nynz =>
  let ny := (sval nynz).1 in
  let nz := (sval nynz).2 in
  swap i (i + ny%:Z) >>
  iqsort (i, ny) >> iqsort ((i + ny%:Z + 1)%Z, nz))).
Proof. rewrite [in LHS]/iqsort Fix_eq //=; exact: iqsort'_Fix. Qed.

Lemma write2L_write3L {i : Z} {x p : E} {ys zs xs : seq E} : 
  (forall ys zs : seq E, (do x <- partl' p ys zs xs; write2L i x)%Do
  `>=` writeList i (ys ++ zs ++ xs) >>
      ipartl p i (size ys) (size zs) (size xs)) ->
  uncurry3 (partl' p) (ys, zs, xs) >>= write2L i
  `>=` write3L i (ys, zs, xs) >>= uncurry3 (ipartl p i).
Proof.
  move=> h.
  rewrite /uncurry3 /write3L.
  apply: refin_trans (h ys zs).
  rewrite bindA bindretf.
  apply refin_refl.
Qed.

Lemma dispatch_write2L_write3L {i : Z} {x p : E} {ys zs xs : seq E} : 
  (forall ys zs : seq E, (do x <- partl' p ys zs xs; write2L i x)%Do
  `>=` writeList i (ys ++ zs ++ xs) >>
      ipartl p i (size ys) (size zs) (size xs)) ->
  dispatch x p (ys, zs, xs) >>= uncurry3 (partl' p) >>= write2L i
  `>=` dispatch x p (ys, zs, xs) >>= write3L i >>= uncurry3 (ipartl p i).
Proof.
  move=> h.
  rewrite 2!bindA.
  rewrite /dispatch.
  case: ifPn => xp.
  rewrite 2!bindA /refin.
  rewrite bind_monotonic_lrefin //.
  move=> {}zs.
  rewrite 2!bindretf.
  apply: write2L_write3L h.
  exact x.
  (* same *)
  rewrite 2!bindA /refin.
  rewrite bind_monotonic_lrefin //.
  move=> {}zs.
  rewrite 2!bindretf.
  apply: write2L_write3L h.
  exact x.
Qed.

Lemma dispatch_writeList_cat {i : Z} {x p : E} {ys zs xs : seq E} :
  dispatch x p (ys, zs, xs) >>= write3L i >>= uncurry3 (ipartl p i) =
  dispatch x p (ys, zs, xs) >>= (fun '(ys', zs', xs) => 
    writeList i (ys' ++ zs') >> writeList (i + (size (ys' ++ zs'))%:Z) xs >>
    ipartl p i (size ys') (size zs') (size xs)).
Proof.
  rewrite bindA.
  bind_ext => [[[ys' zs']] xs'].
  by rewrite /write3L bindA catA writeList_cat bindretf.
Qed.

Let split_pair A n : Type := {x : seq A * seq A | size x.1 + size x.2 = n}.

Program Fixpoint ssplits A (s : seq A) : M (split_pair A (size s))%type :=
  match s with
  | [::] => Ret (exist _ ([::], [::]) _)
  | x :: xs => (do yz <- ssplits xs; Ret (exist _ (x :: yz.1, yz.2) _) [~]
                                  Ret (exist _ (yz.1, x :: yz.2) _))%Do
  end.
Next Obligation. by []. Qed.
Next Obligation.
by move=> A [//|x' xs'] x xs [xx' xsxs'] [[a b] /=] <-; rewrite addSn.
Qed.
Next Obligation.
by move=> A [//|x' xs'] x xs [xx' xsxs'] [[a b] /=] <-; rewrite -addnS.
Qed.

Local Open Scope mprog.
Lemma splitsE A (s : seq A) :
  splits s = fmap (fun xy => ((sval xy).1, (sval xy).2)) (ssplits s) :> M _.
Proof.
elim: s => [|h t ih]; first by rewrite fmapE /= bindretf.
rewrite /= fmapE bindA ih /= fmapE !bindA; bind_ext => -[[a b] ab] /=.
by rewrite bindretf /= alt_bindDl /=; congr (_ [~] _); rewrite bindretf.
Qed.
Local Close Scope mprog.

(* NB: can't use the preserves predicate below because the input/output of splits
   are of different sizes *)
Lemma splits_preserves_size A (x : seq A) :
  (splits x >>= fun x' => Ret (x' , size x'.1 + size x'.2)) =
  (splits x >>= fun x' => Ret (x' , size x)) :> M _.
Proof.
move: x => [|x xs]; first by rewrite /= !bindretf.
rewrite /= !bindA splitsE !fmapE !bindA.
bind_ext => -[[a b] /= ab].
by rewrite /= !bindretf !alt_bindDl !bindretf /= addSn addnS ab.
Qed.

Definition preserves A B (f : A -> M A) (g : A -> B) :=
  forall x, (f x >>= fun x' => Ret (x' , g x')) = (f x >>= fun x' => Ret (x' , g x)).

Lemma bind_liftM2 A B C (f : seq A -> seq B -> seq C)
    (m1 : M (seq A)) (m2 : M (seq B)) n :
  (forall a b, size (f a b) = size a + size b + n) ->
  liftM2 f m1 m2 >>= (fun x => Ret (x, size x)) =
  liftM2 (fun a b => (f a.1 b.1, a.2 + b.2 + n))
          (m1 >>= (fun x => Ret (x, size x)))
          (m2 >>= (fun x => Ret (x, size x))).
Proof.
move=> hf.
rewrite /liftM2 !bindA; bind_ext => x1.
rewrite !bindretf !bindA.
bind_ext=> x2.
by rewrite !bindretf /= hf.
Qed.
Arguments bind_liftM2 {A B C} {f} {m1} {m2} _.

Lemma qperm_preserves_size A : preserves (@qperm _ A) size.
Proof.
move=> s.
have [n ns] := ubnP (size s); elim: n s ns => // n ih s ns.
move: s => [|p s] in ns *.
  by rewrite !qperm_nil !bindretf.
rewrite /= ltnS in ns.
rewrite qpermE !bindA.
(*bind_ext => -[a b]. (* we lose the size information *)*)
rewrite !splitsE !fmapE !bindA.
bind_ext => -[[a b] /= ab].
rewrite !bindretf.
rewrite (bind_liftM2 1%N); last first.
  by move=> x y; rewrite size_cat /= addn1 -addnS.
rewrite {1}/liftM2.
rewrite ih; last by rewrite (leq_trans _ ns)// ltnS -ab leq_addr.
rewrite /liftM2 !bindA.
bind_ext => xa.
rewrite bindretf.
rewrite ih; last by rewrite (leq_trans _ ns)// ltnS -ab leq_addl.
rewrite !bindA.
bind_ext => xb.
rewrite !bindretf /=.
by rewrite ab addn1.
Qed.

Lemma nondetPlus_sub_splits (s : seq E) : nondetPlus_sub (@splits M _ s).
Proof.
elim: s => [|h t ih /=]; first by exists (ndRet ([::], [::])).
have [syn syn_splits] := ih.
exists (ndBind syn (fun '(a, b) => ndAlt (ndRet (h :: a, b)) (ndRet (a, h :: b)))).
rewrite /= syn_splits.
by bind_ext => -[].
Qed.

Lemma nondetPlus_sub_tsplits (s : seq E) : nondetPlus_sub (@tsplits M _ s).
Proof.
elim: s => [|h t ih]; first by exists (ndRet (bseq0 0 E, bseq0 0 E)).
have [syn syn_tsplits] := ih.
exists (ndBind syn (fun '(a, b) => ndAlt
   (ndRet
      (Bseq (example_quicksort.tsplits_obligation_1 h (erefl (a, b))),
       Bseq (example_quicksort.tsplits_obligation_2 h (erefl (a, b)))))
   (ndRet
      (Bseq (example_quicksort.tsplits_obligation_3 h (erefl (a, b))),
       Bseq (example_quicksort.tsplits_obligation_4 h (erefl (a, b)))))
   )) (*TODO: name tsplits_obligation_x*).
rewrite /= syn_tsplits.
by bind_ext => -[].
Qed.

Lemma nondetPlus_sub_liftM2 A B C f ma mb :
  nondetPlus_sub ma -> nondetPlus_sub mb ->
  nondetPlus_sub (@liftM2 M A B C f ma mb).
Proof.
move=> [s1 s1_ma] [s2 s2_mb].
exists (ndBind s1 (fun a => ndBind s2 (fun b => ndRet (f a b)))).
by rewrite /= s1_ma s2_mb.
Qed.

Lemma nondetPlus_sub_qperm (s : seq E) : nondetPlus_sub (@qperm M _ s).
Proof.
have [n sn] := ubnP (size s); elim: n s => // n ih s in sn *.
move: s => [|h t] in sn *; first by exists (ndRet [::]); rewrite qperm_nil.
rewrite qperm_cons.
rewrite example_quicksort.splitsE /=. (*TODO: rename, there are two splitsE lemmas*)
rewrite fmapE (*TODO: broken ret notation*).
rewrite bindA.
have [syn syn_tsplits] := nondetPlus_sub_tsplits t.
have nondetPlus_sub_liftM2_qperm : forall a b : (size t).-bseq E,
  nondetPlus_sub (@liftM2 M _ _ _ (fun x y => x ++ h :: y) (qperm a) (qperm b)).
  move=> a b; apply nondetPlus_sub_liftM2 => //; apply: ih.
  - by rewrite (leq_ltn_trans (size_bseq a)).
  - by rewrite (leq_ltn_trans (size_bseq b)).
exists (ndBind syn (fun a => sval (nondetPlus_sub_liftM2_qperm a.1 a.2))).
rewrite /= syn_tsplits.
bind_ext => -[a b] /=.
rewrite bindretf.
by case: (nondetPlus_sub_liftM2_qperm _ _).
Qed.

Lemma commute_writeList_dispatch i p ys zs xs x :
  commute (dispatch x p (ys, zs, xs))
          (writeList (i + (size ys)%:Z + (size zs)%:Z + 1) xs)
          (fun pat _ => let: (ys', zs', xs0) := pat in
            writeList i (ys' ++ zs') >> ipartl p i (size ys') (size zs') (size xs0)).
Proof.
apply commute_plus.
rewrite /dispatch.
case: ifPn => xp.
  have [syn syn_qperm] := nondetPlus_sub_qperm zs.
  exists (ndBind(*NB: is ndBind a good name?*) syn (fun s => ndRet (ys ++ [:: x], s, xs))).
  by rewrite /= syn_qperm.
have [syn syn_qperm] := nondetPlus_sub_qperm (zs ++ [:: x])(*NB: why don't I have rcons?*).
exists (ndBind syn (fun s => ndRet (ys, s, xs))).
by rewrite /= syn_qperm.
Qed.

(* page11 step4 *)
Lemma qperm_preserves_length {i : Z} {x p : E} {ys zs xs : seq E} :
  dispatch x p (ys, zs, xs) >>= (fun '(ys', zs', xs) =>
  writeList i (ys' ++ zs') >> writeList (i + (size (ys' ++ zs'))%:Z) xs >>
  ipartl p i (size ys') (size zs') (size xs)) =
  writeList (i + (size ys)%:Z + (size zs)%:Z + 1) xs >>
    dispatch x p (ys, zs, xs) >>= (fun '(ys', zs', xs) =>
    writeList i (ys' ++ zs') >> ipartl p i (size ys') (size zs') (size xs)).
Proof.
rewrite [in RHS]bindA.
rewrite -commute_writeList_dispatch.
rewrite /dispatch.
case: ifPn => xp.
  rewrite !bindA.
  under eq_bind do rewrite bindretf.
  under [in RHS]eq_bind do rewrite bindretf.
  under eq_bind do rewrite -writeList_cat.
  under [in RHS]eq_bind do rewrite -bindA.
  under [in RHS]eq_bind do rewrite -2!addZA.
  (* TODO: simplify this *)
  transitivity (
    (do zs' <- qperm zs;
    (writeList (i + ((size ys)%:Z + ((size zs')%:Z + 1))) xs >> writeList i ((ys ++ [:: x]) ++ zs')) >>
    ipartl p i (size (ys ++ [:: x])) (size zs') (size xs))%Do); last first.
    transitivity (
      (do zs' <- (do x <- qperm zs; Ret (x, size x));
      (writeList (i + ((size ys)%:Z + ((zs'.2)%:Z + 1))) xs >> writeList i ((ys ++ [:: x]) ++ zs'.1)) >>
      ipartl p i (size (ys ++ [:: x])) (size zs'.1) (size xs))%Do); last first.
      rewrite qperm_preserves_size !bindA.
      bind_ext => zs' /=.
      by rewrite bindretf /=.
    rewrite !bindA.
    by under [in RHS]eq_bind do rewrite bindretf.
  bind_ext => zs' /=.
  rewrite (_ : (_ + (_ + 1))%Z = (size (ys ++ [:: x] ++ zs'))%:Z); last first.
    by rewrite 2!size_cat /= add1n intRD natZS -add1Z (addZC 1%Z).
  rewrite -writeList_writeListC; last first.
    by rewrite -catA; exact: leZZ.
  by rewrite writeList_cat catA.
admit.
Admitted.

(* page11 top derivation *)
Lemma partl'_writeList (p x : E) (ys zs xs : seq E) (i : Z) :
  (forall ys zs : seq E, (do x <- partl' p ys zs xs; write2L i x)%Do
    `>=` writeList i (ys ++ zs ++ xs) >>
        ipartl p i (size ys) (size zs) (size xs)) ->
  partl' p ys zs (x :: xs) >>= write2L i `>=`
  writeList (i + (size ys)%:Z + (size zs)%:Z + 1)%Z xs >>
    if x <= p then qperm zs >>= (fun zs' => writeList i (ys ++ [:: x] ++ zs') >>
      ipartl p i (size ys + 1) (size zs') (size xs))
    else qperm (rcons zs x) >>= (fun zs' => writeList i (ys ++ zs') >>
      ipartl p i (size ys) (size zs') (size xs)).
Proof.
  move=> h.
  rewrite partl'_dispatch.
  apply: refin_trans; last first.
  apply (dispatch_write2L_write3L h).
  rewrite dispatch_writeList_cat.
  rewrite qperm_preserves_length.
  rewrite /dispatch bindA.
  apply bind_monotonic_lrefin => -[].

  case: ifPn => xp. (* TODO:  *)
  rewrite bindA /refin -alt_bindDr.
  bind_ext => s.
  by rewrite bindretf catA cats1 size_rcons addn1 altmm.
  rewrite bindA /refin cats1 -alt_bindDr.
  bind_ext => s.
  by rewrite bindretf altmm.
Qed.

Lemma swapii (i : Z) : 
  swap i i = skip.
Proof.
  rewrite /swap agetget.
  under eq_bind do rewrite aputput.
  by rewrite agetpustskip.
Qed.

  
(* qperm (rcons zs x) >>= (fun zs' => 
  writeList i (ys ++ zs') >> ipartl p i (size ys) (size zs') (size xs))
`>=`
writeList i (ys ++ zs ++ [:: x]) >> ipartl p i (size ys) (size zs + 1) (size xs). *)
(* Lemma qperm_refin (zs : seq E) :
  qperm zs `>=` @ret M _ zs.
Proof.
  elim: zs => [|h t ih].
  rewrite qperm_nil.
  apply: refin_refl.
  rewrite qperm_cons.
  (* rewrite qperm_cons.
  apply: refin_trans; last first. *)
Admitted. *)

Lemma qperm_preserves {A} (h : E) (t : seq E) (f : seq E -> M A) :
  qperm (h :: t) >>= f = qperm (rcons t h) >>= f.
Proof.
Admitted.

Lemma qperm_refin {A} (zs : seq E) (f : seq E -> M A) :
  qperm zs >>= f `>=` Ret zs >>= f.
Proof.
Admitted.

Lemma qperm_refin_rcons {A} (h : E) (t : seq E) (f : seq E -> M A) :
  qperm (h :: t) >>= f `>=` Ret (rcons t h) >>= f.
Proof.
  rewrite qperm_preserves.
  apply /(refin_trans _ (@qperm_refin _ _ _)) /refin_refl.
Qed.

Lemma qperm_refin_cons {A} (h : E) (t : seq E) (f : seq E -> M A) :
  qperm (rcons t h) >>= f `>=` Ret (h :: t) >>= f.
Proof.
  rewrite -qperm_preserves.
  apply /(refin_trans _ (@qperm_refin _ _ _)) /refin_refl.
Qed.

(* TODO *)
Lemma aput_writeList_cons {i : Z} {x h : E} {t : seq E} :
  writeList i (rcons (h :: t) x) =
  writeList i (rcons (x :: t) h) >> swap i (i + (size (rcons t h))%:Z).
  (* aput i x >> writeList (i + 1) (rcons t h) >> swap i (i + (size (rcons t h))%:Z). *)
  (* aput i h >> writeList (i + 1) (rcons t x) =
  aput i x >>
      ((aput (i + 1)%Z h >> writeList (i + 1 + 1) t) >>
        swap i (i + (size t).+1%:Z)). *)
Proof.
  rewrite /swap -!bindA.
  rewrite writeList_rcons.
  rewrite /=.
  rewrite aput_writeListC.
  rewrite bindA.
  rewrite aput_writeListC.
  rewrite writeList_rcons.
  rewrite !bindA.
  bind_ext => ?.
  under [RHS] eq_bind do rewrite -bindA.
  rewrite aputget.
  rewrite -bindA.
  rewrite size_rcons.
  rewrite -addZA natZS -add1Z.
  under [RHS] eq_bind do rewrite -!bindA.
  rewrite aputgetC.
  rewrite -!bindA.
  rewrite aputget.
  rewrite aputput aputC.
  rewrite bindA.
  by rewrite aputput.
  - by right.
  - apply /eqP/ltZ_eqF.
    apply /ltZ_addr; last by apply leZZ.
    by rewrite add1Z -natZS.
  - by rewrite ltZadd1; exact: leZZ.
  - by rewrite ltZadd1; exact: leZZ.
Qed.

Lemma aput_writeList_rcons {i : Z} {x h : E} {t : seq E}:
  aput i x >> writeList (i + 1) (rcons t h) =
  aput i h >>
      ((writeList (i + 1) t >> aput (i + 1 + (size t)%:Z)%Z x) >>
        swap i (i + (size t).+1%:Z)).
Proof.
rewrite /swap -!bindA.
rewrite writeList_rcons -bindA.
rewrite aput_writeListC; last by rewrite ltZadd1; exact: leZZ.
rewrite aput_writeListC; last by rewrite ltZadd1; exact: leZZ.
rewrite !bindA.
bind_ext => ?.
under [RHS] eq_bind do rewrite -bindA.
rewrite aputgetC; last first.
- apply /eqP/gtZ_eqF.
  rewrite -addZA.
  apply /ltZ_addr; last by apply leZZ.
  by rewrite add1Z -natZS.
rewrite -bindA.
rewrite -addZA natZS -add1Z aputget.
under [RHS] eq_bind do rewrite -!bindA.
rewrite aputget aputC; last first.
- by right.
by rewrite -!bindA aputput bindA aputput.
Qed.

(* equation11 *)
Lemma introduce_swap_cons {i : Z} {x : E} (zs : seq E) :
  qperm zs >>= (fun zs' => writeList i (x :: zs')) `>=`
  writeList i (rcons zs x) >> swap i (i + (size zs)%:Z).
Proof.
case: zs i => [/= i|].
rewrite qperm_nil bindmskip bindretf addZ0 swapii bindmskip.
by apply: refin_refl.
move=> h t /= i.
rewrite bindA writeList_rcons.
apply: (refin_trans _ (@qperm_refin_rcons _ _ _ _)).
rewrite bindretf.
rewrite -aput_writeList_rcons.
apply: refin_refl.
Qed.

(* See postulate introduce-swap equation13 *)
Lemma introduce_swap_rcons {i : Z} {x : E} (ys : seq E) :
  qperm ys >>= (fun ys' => writeList i (rcons ys' x)) `>=`
  writeList i (x :: ys) >> swap i (i + (size ys)%:Z).
Proof.
elim/last_ind: ys i => [/= i|].
rewrite qperm_nil bindmskip bindretf addZ0 swapii /= bindmskip.
by apply: refin_refl.
move=> t h ih i.
rewrite /= bindA.
apply: (refin_trans _ (@qperm_refin_cons _ _ _ _)).
rewrite bindretf -bindA.
rewrite -aput_writeList_cons.
by apply: refin_refl.
Qed.

(* bottom of the page11 *)
Lemma first_branch (i : Z) (x : E) (ys zs : seq E) :
  qperm zs >>= (fun zs' => writeList i (ys ++ [:: x] ++ zs')) `>=`
  writeList i (ys ++ zs ++ [:: x]) >> swap (i + (size ys)%:Z) (i + (size ys)%:Z + (size zs)%:Z).
Proof.
apply: refin_trans; last first.
- apply: bind_monotonic_lrefin => x0.
  rewrite writeList_cat.
  apply: refin_refl.
  (* have: commute *)
  have: commute (qperm zs) (writeList i ys) (fun x0 _ => writeList (i + (size ys)%:Z) ([:: x] ++ x0)).
  admit.
  move->.
apply: (@refin_trans _ _
  (writeList i ys >> writeList (i + (size ys)%:Z) (rcons zs x) >>
    swap (i + (size ys)%:Z) (i + (size ys)%:Z + (size zs)%:Z))
); last first.
- rewrite !bindA.
  rewrite /refin -alt_bindDr.
  bind_ext => ?.
  by rewrite introduce_swap_cons.
- rewrite writeList_cat -cat_rcons cats0.
  apply refin_refl.
Admitted.


Lemma introduce_read_sub {i : Z} (p : E) (xs : seq E) (f : E -> M (nat * nat)%type):
  writeList i (p :: xs) >> Ret p >> f p =
  writeList i (p :: xs) >> aget i >>= f.
Proof.
  rewrite introduce_read 2!bindA /=.
  rewrite aput_writeListC; last first.
  rewrite ltZadd1 leZ_eqVlt; exact: or_introl.
  rewrite 2!bindA.
  under [LHS] eq_bind do rewrite -bindA aputget.
  by under [RHS] eq_bind do rewrite -bindA aputget.
Qed.


(* page12 *)
Lemma writeList_ipartl (p x : E) (i : Z) (ys zs xs : seq E) :
  writeList (i + (size ys + size zs)%:Z + 1) xs >>
  (if x <= p 
    then writeList i (ys ++ zs ++ [:: x]) >>
      swap (i + (size ys)%:Z) (i + (size ys + size zs)%:Z) >>
      ipartl p i (size ys + 1) (size zs) (size xs)
    else writeList i (ys ++ zs ++ [:: x]) >>
      ipartl p i (size ys) (size zs + 1) (size xs)) =
  writeList i (ys ++ zs ++ (x :: xs)) >>
    aget (i + (size ys + size zs)%:Z)%Z >>= (fun x =>
    (if x <= p
      then swap (i + (size ys)%:Z) (i + (size ys + size zs)%:Z) >>
        ipartl p i (size ys + 1) (size zs) (size xs)
      else ipartl p i (size ys) (size zs + 1) (size xs))).
Proof.
  (* step1 *)
  transitivity (
    writeList i (ys ++ zs ++ (x :: xs)) >>
      if x <= p 
        then swap (i + (size ys)%:Z) (i + (size ys + size zs)%:Z) >>
          ipartl p i (size ys + 1) (size zs) (size xs)
        else ipartl p i (size ys) (size zs + 1) (size xs)
  ).
  case: ifPn => xp.
  rewrite !writeList_cat -![in LHS]bindA.
  rewrite -writeList_writeListC; last first.
    rewrite intRD -2!addZA addZA; apply: (leZ_addr _ _ _ _ (leZZ _)).
    by apply addZ_ge0 => //; apply leZ0n.
  rewrite ![LHS]bindA ![RHS]bindA.
  bind_ext => ?.
  rewrite -![in LHS]bindA.
  rewrite -writeList_writeListC; last first.
    by rewrite intRD !addZA; apply: leZ_addr => //; exact: leZZ.
  rewrite ![LHS]bindA ![RHS]bindA.
  bind_ext => ?.
  rewrite /= -[in LHS]bindA aput_writeListC; last first.
    by rewrite ltZadd1; exact: leZZ.
  rewrite intRD addZA.
  bind_ext => ?.
  by rewrite bindretf bindA.
  (* almost same *)
  rewrite !writeList_cat -![in LHS]bindA.
  rewrite -writeList_writeListC; last first.
    rewrite intRD -2!addZA addZA.
    by apply: (leZ_addr _ _ _ _ (leZZ _)); apply: addZ_ge0 => //; apply leZ0n.
  rewrite ![LHS]bindA ![RHS]bindA.
  bind_ext => ?.
  rewrite -![in LHS]bindA.
  rewrite -writeList_writeListC; last first.
    by rewrite intRD !addZA; apply: leZ_addr => //; exact: leZZ.
  rewrite ![LHS]bindA ![RHS]bindA.
  bind_ext => ?.
  rewrite /= -[in LHS]bindA aput_writeListC; last first.
    by rewrite ltZadd1; exact: leZZ.
  rewrite intRD addZA.
  bind_ext => ?.
  by rewrite bindretf. (* TODO: cleanup (distributivity of if) *)
  (* step 2 *)
  rewrite bindA catA writeList_cat 2!bindA.
  rewrite size_cat intRD addZA.
  bind_ext => ?.
  transitivity (
    writeList (i + (size ys)%:Z + (size zs)%:Z)%Z (x :: xs) >> Ret x >>
    (if x <= p
     then
      swap (i + (size ys)%:Z) (i + (size ys)%:Z + (size zs)%:Z) >>
      ipartl p i (size ys + 1) (size zs) (size xs)
     else ipartl p i (size ys) (size zs + 1) (size xs))
  ). by rewrite bindA bindretf.
  rewrite (introduce_read_sub x xs (fun x0 => (
    if x0 <= p
      then swap (i + (size ys)%:Z) (i + (size ys)%:Z + (size zs)%:Z) >>
        ipartl p i (size ys + 1) (size zs) (size xs)
      else ipartl p i (size ys) (size zs + 1) (size xs)))
  ).
  by rewrite bindA.
Qed.
  
(* page10 *)
Lemma lemma10 (p : E) (i : Z) (ys zs xs : seq E) :
  writeList i (ys ++ zs ++ xs) >> ipartl p i (size ys) (size zs) (size xs) `<=`
  partl' p ys zs xs >>= write2L i.
Proof.
  elim: xs ys zs => [|h t ih] ys zs.
  rewrite /= catA cats0 bindretf /=; exact: refin_refl.
  apply: refin_trans; last first.
  apply: (partl'_writeList _ _ _ ih).
Admitted.

Lemma qperm_involutive : qperm >=> qperm = qperm :> (seq E -> M (seq E)).
Proof.
Admitted.

Lemma qperm_slowsort : qperm >=> (@slowsort M _ _) = (@slowsort M _ _) :> (seq E -> M (seq E)).
Proof.
Admitted.

Lemma lemma12 {i : Z} {xs : seq E} :
 writeList i xs >> iqsort (i, size xs) `<=` slowsort xs >> writeList i xs.
Proof.
have [n nxs] := ubnP (size xs); elim: n xs => // n ih xs in nxs *.
move: xs => [|p xs] in nxs *.
 rewrite /= iqsort_nil slowsort_nil.
 (* NB: lemma? *)
 by rewrite /refin 2!bindretf altmm.
set lhs := (X in X `>=` _).
have : lhs `>=` writeList i (p :: xs) >>
 (ipartl p (i + 1) 0 0 (size xs) >>= (fun '(ny, nz) => swap i (i + ny%:Z) >>
   iqsort (i, (*(size ys)?*)ny) >> iqsort ((i + (*(size ys)?*)nz%:Z + 1)%Z,(*(size zs?*) nz))).
 rewrite {}/lhs.
 apply: (@refin_trans _ _
   (partl' p [::] [::] xs >>= (fun '(ys, zs) =>
     qperm ys >>= (fun ys' => writeList i (ys' ++ [:: p] ++ zs) >>
       iqsort (i, size ys) >> iqsort ((i + (size ys)%:Z + 1)%Z, size zs))))); last first.
   admit. (* NB: use qperm_involutive, qperm_slowsort, writeList_cat + inductive hypothesis *)
 admit. (* NB: use lemma10 and lemma 13 *)
 (*
move=> -> {lhs}.
apply: bind_monotonic_lrefin.
case.
admit. (* use iqsort_cons? *) *)
Admitted.

Lemma qperm_preserves_guard B (p : pred E) (a : seq E) (f : seq E -> M B) :
  (* guard (all p a) >>= (fun _ => qperm a >>= f) = *)
  qperm a >>= (fun x => guard (all p a) >> f x) =
  qperm a >>= (fun x => guard (all p x) >> f x).
Proof.
  rewrite -guard_qperm_eq -bindA.
  rewrite (@guardsC M (@bindmfail M) _) bindA.
  bind_ext => ?.
  rewrite /assert; unlock.
  by rewrite bindA bindretf.
Qed.

(* Lemma __ : preserves (@qperm _ E) size.
rewrite /preserves. *)

Lemma qperm_preserves_guard2 A (p : pred E) (a : seq E) (f : (seq E * M unit)%type -> M A):
qperm a >>= (fun x => Ret (x, guard (all p x)) >>= f) =
qperm a >>= (fun x => Ret (x, guard (all p a)) >>= f).
Proof.
Admitted.

End marray.
