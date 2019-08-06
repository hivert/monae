Ltac typeof X := type of X.

Require Import ssreflect ssrmatching ssrfun ssrbool.
From mathcomp Require Import eqtype ssrnat seq path div choice fintype tuple.
From mathcomp Require Import finfun bigop.
From mathcomp Require boolp.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

(* Contents:
- generic Haskell-like functions and notations
- Module FunctorLaws/Module Functor
- Section fcomp
- Section natural_transformation.
- Section adjoint_functors.
- Module BindLaws.
    definition of algebraic laws to be used with monads
- Section monad_of_adjoint.
- Module JoinLaws.
- Module Monad.
    with ret and join
- Module Monad_of_ret_bind.
    with bind and ret
- Section kleisli
- Section fmap_and_join
- Section rep.
    simple effect of counting
*)

Reserved Notation "A `2" (format "A `2", at level 3).
Reserved Notation "f ^`2" (format "f ^`2", at level 3).
Reserved Notation "l \\ p" (at level 50).
Reserved Notation "m >>= f" (at level 49).
Reserved Notation "m >> f" (at level 49).
(*Reserved Notation "f =<< m" (at level 49).*)
Reserved Notation "'do' x <- m ; e"
  (at level 60, x ident, m at level 200, e at level 60).
Reserved Notation "'do' x : T <- m ; e"
  (at level 60, x ident, m at level 200, e at level 60).
Reserved Notation "m >=> n" (at level 50).
Reserved Notation "n <=< m" (at level 50).
Reserved Notation "x '[~]' y" (at level 50).
Reserved Notation "'[~p]'".
Reserved Notation "f (o) g" (at level 11).
Reserved Notation "f ~> g" (at level 51).
Reserved Notation "F # g" (at level 11).
Reserved Notation "'fmap' f" (at level 4).
Reserved Notation "f \O g" (at level 50, format "f  \O  g").
Reserved Notation "f -| g :: n , e" (at level 51, g, n, e at next level).

Notation "l \\ p" := ([seq x <- l | x \notin p]).
Notation "f ~~> g" := (forall A, f A -> g A) (at level 51).

(* some Haskell-like functions *)
Definition foldr1 (A : Type) (def : A) (f : A -> A -> A) (s : seq A) :=
  match s with
    | [::] => def
    | [:: h] => h
    | h :: h' :: t => foldr f h [:: h' & t]
  end.

Definition cp {A B} (x : seq A) (y : seq B) := [seq (x', y') | x' <- x, y' <- y].

Lemma cp1 A B (a : A) (s : seq B) : cp [:: a] s = map (fun b => (a, b)) s.
Proof. by  elim: s => // h t /= <-. Qed.

Definition zipWith {A B C} (op : A -> B -> C) a b : seq C :=
  map (fun x => op x.1 x.2) (zip a b).

Section fold.
Variables (T R : Type) (f : T -> R -> R) (r : R).

Section universal.
Variable (g : seq T -> R).
Hypothesis H1 : g nil = r.
Hypothesis H2 : forall h t, g (h :: t) = f h (g t).
Lemma foldr_universal : g = foldr f r.
Proof. rewrite boolp.funeqE; elim => // h t ih /=; by rewrite H2 ih. Qed.
Lemma foldr_universal_ext x : g x = foldr f r x.
Proof. by rewrite -(foldr_universal). Qed.
End universal.

Section fusion_law.
Variables (U : Type) (h : U -> R) (w : U) (g : T -> U -> U).
Hypothesis H1 : h w = r.
Hypothesis H2 : forall x y, h (g x y) = f x (h y).
Lemma foldr_fusion : h \o foldr g w = foldr f r.
Proof. rewrite boolp.funeqE; elim => // a b /= ih; by rewrite H2 ih. Qed.
Lemma foldr_fusion_ext x : (h \o foldr g w) x = foldr f r x.
Proof. by rewrite -foldr_fusion. Qed.
End fusion_law.

End fold.

Section curry.
Variables A B C : Type.
Implicit Types f : A -> B -> C.

Definition uncurry f := prod_curry f.

Lemma uncurryE f a b : (uncurry f) (a, b) = f a b. Proof. by []. Qed.

Definition curry (g : A * B -> C) : A -> B -> C := fun a b => g (a, b).

Lemma curryK : cancel curry uncurry.
Proof. by move=> f; rewrite boolp.funeqE; case. Qed.

Lemma uncurryK f : cancel uncurry curry.
Proof. by []. Qed.
End curry.

Definition ucat {A} := uncurry (@cat A).

Definition uaddn := uncurry addn.

Lemma uaddnE n m : uaddn (n, m) = n + m. Proof. by rewrite /uaddn uncurryE. Qed.

Definition const A B (b : B) := fun _ : A => b.

Definition wrap {A} (a : A) := [:: a].

Fixpoint scanl A B (op : B -> A -> B) (b : B) (s : seq A) : seq B :=
  if s isn't x :: xs then [::] else (op b x) :: scanl op (op b x) xs.

Lemma compA {A B C D} (f : C -> D) (g : B -> C) (h : A -> B) : f \o (g \o h) = (f \o g) \o h.
Proof. by []. Qed.

Lemma compfid A B (f : A -> B) : f \o id = f. Proof. by []. Qed.

Lemma compidf A B (f : A -> B) : id \o f = f. Proof. by []. Qed.

Lemma compE A B C (g : B -> C) (f : A -> B) a : (g \o f) a = g (f a).
Proof. by []. Qed.

(* map laws of a functor *)
Module FunctorLaws.
Section def.
Variable (M : Type -> Type) (f : forall A B, (A -> B) -> M A -> M B).
Definition id := forall A, f id = id :> (M A -> M A).
Definition comp := forall A B C (g : B -> C) (h : A -> B),
  f (g \o h) = f g \o f h :> (M A -> M C).
End def.
End FunctorLaws.

Module Functor.
Record class_of (m : Type -> Type) : Type := Class {
  f : forall A B, (A -> B) -> m A -> m B ;
  _ : FunctorLaws.id f ;
  _ : FunctorLaws.comp f }.
Structure t : Type := Pack { m : Type -> Type ; class : class_of m }.
Module Exports.
Definition Fun (F : t) : forall A B, (A -> B) -> m F A -> m F B :=
  let: Pack _ (Class f _ _) := F return forall A B, (A -> B) -> m F A -> m F B in f.
Arguments Fun _ [A] [B] : simpl never.
Notation functor := t.
Coercion m : functor >-> Funclass.
End Exports.
End Functor.
Export Functor.Exports.
Notation "F # g" := (Fun F g).
Notation "'fmap' f" := (_ # f) : mprog.

Section functor_lemmas.
Variable F : functor.
Lemma functor_id : FunctorLaws.id (Fun F). Proof. by case: F => [? []]. Qed.
Lemma functor_o : FunctorLaws.comp (Fun F). Proof. by case: F => [? []]. Qed.
End functor_lemmas.

Definition Squaring (A : Type) := (A * A)%type.
Notation "A `2" := (Squaring A).
Definition squaring_f A B (f : A -> B) : A`2 -> B`2 := fun x => (f x.1, f x.2).
Lemma squaring_f_id : FunctorLaws.id squaring_f.
Proof. by move=> A /=; rewrite boolp.funeqE => -[x1 x2]. Qed.
Lemma squaring_f_comp : FunctorLaws.comp squaring_f.
Proof. by move=> A B C g h /=; rewrite boolp.funeqE => -[x1 x2]. Qed.
Definition squaring : functor :=
  Functor.Pack (Functor.Class squaring_f_id squaring_f_comp).
Notation "f ^`2" := (squaring # f).
Lemma squaringE A B (f : A -> B) x : (f ^`2) x = (f x.1, f x.2).
Proof. by []. Qed.

Section functorid.
Definition id_f A B (f : A -> B) := f.
Lemma id_id : FunctorLaws.id id_f. Proof. by []. Qed.
Lemma id_comp : FunctorLaws.comp id_f. Proof. by []. Qed.
Definition FId : functor := Functor.Pack (Functor.Class id_id id_comp).
End functorid.

Section functorcomposition.
Variables f g : functor.
Definition functorcomposition A B := fun h : A -> B => f # (g # h).
Lemma functorcomposition_id : FunctorLaws.id functorcomposition.
Proof.
by rewrite /FunctorLaws.id => A; rewrite /functorcomposition 2!functor_id.
Qed.
Lemma functorcomposition_comp : FunctorLaws.comp functorcomposition.
Proof.
rewrite /FunctorLaws.comp => A B C g' h; rewrite /functorcomposition.
rewrite boolp.funeqE => m; by rewrite [in RHS]compE 2!functor_o.
Qed.
Definition FComp : functor :=
  Functor.Pack (Functor.Class functorcomposition_id functorcomposition_comp).
End functorcomposition.

Notation "f \O g" := (FComp f g).

Section functorcomposition_lemmas.
Lemma FCompId f : f \O FId = f.
Proof.
case: f => [? [???]]; congr (Functor.Pack (Functor.Class _ _));
  exact/boolp.Prop_irrelevance.
Qed.
Lemma FIdComp f : FId \O f = f.
Proof.
case: f => [? [???]]; congr (Functor.Pack (Functor.Class _ _));
  exact/boolp.Prop_irrelevance.
Qed.
Lemma FIdf A B (f : A -> B) : FId # f = f. Proof. by []. Qed.
Lemma FCompA (f g h : functor) : (f \O g) \O h = f \O (g \O h).
Proof.
move: f g h => [f [???]] [g [???]] [h [???]].
congr (Functor.Pack (Functor.Class  _ _)); exact/boolp.Prop_irrelevance.
Qed.
Lemma FCompE (f g : functor) A B (k : A -> B) : (f \O g) # k = f # (g # k).
Proof. by []. Qed.
End functorcomposition_lemmas.

Section curry_functor.
Definition curry_M X : Type -> Type := fun B => (X * B)%type.
Definition curry_f X A B (f : A -> B) : curry_M X A -> curry_M X B :=
  fun x : X * A => (x.1, f x.2).
Lemma curry_f_id X : FunctorLaws.id (@curry_f X).
Proof.
by rewrite /FunctorLaws.id => A; rewrite /curry_f boolp.funeqE; case.
Qed.
Lemma curry_f_comp X : FunctorLaws.comp (@curry_f X).
Proof.
by rewrite /FunctorLaws.comp => A B C g h; rewrite /curry_f boolp.funeqE; case.
Qed.
Definition curry_F X : functor :=
  Functor.Pack (Functor.Class (curry_f_id X) (curry_f_comp X)).
End curry_functor.

Section uncurry_functor.
Definition uncurry_M X : Type -> Type := fun B => X -> B.
Definition uncurry_f X A B (f : A -> B) : uncurry_M X A -> uncurry_M X B :=
  fun g : X -> A => f \o g.
Lemma uncurry_f_id X : FunctorLaws.id (@uncurry_f X).
Proof.
rewrite /FunctorLaws.id => A; rewrite /uncurry_f boolp.funeqE => ?.
by rewrite compidf.
Qed.
Lemma uncurry_f_comp X : FunctorLaws.comp (@uncurry_f X).
Proof.
rewrite /FunctorLaws.comp => A B C g h; rewrite /uncurry_f boolp.funeqE => ?.
by rewrite compE compA.
Qed.
Definition uncurry_F X : functor :=
  Functor.Pack (Functor.Class (uncurry_f_id X) (uncurry_f_comp X)).
End uncurry_functor.

Lemma fmap_oE (M : functor) A B C (f : A -> B) (g : C -> A) (m : M C) :
  (M # (f \o g)) m = (M # f) ((M # g) m).
Proof. by rewrite functor_o. Qed.

(* monadic counterpart of function composition:
   composes a pure function after a monadic function *)
Section fcomp.
Variable M : functor.

Definition fcomp A B C (f : A -> B) (g : C -> M A) := locked ((M # f) \o g).
Arguments fcomp : simpl never.
Local Notation "f (o) g" := (fcomp f g).

Lemma fcomp_def A B C (f : A -> B) (g : C -> M A) : f (o) g = ((M # f)) \o g.
Proof. by rewrite /fcomp; unlock. Qed.

Lemma fcompE A B C (f : A -> B) (g : C -> M A) c : (f (o) g) c = (M # f) (g c).
Proof. by rewrite fcomp_def. Qed.

Lemma fcomp_comp A B C D (f : A -> B) (g : C -> A) (m : D -> M C) :
  (f \o g) (o) m = f (o) (g (o) m).
Proof. by rewrite 3!fcomp_def functor_o compA. Qed.

End fcomp.
Notation "f (o) g" := (fcomp f g) : mprog.
Arguments fcomp : simpl never.

(* natural transformation *)
Module Natural.
Section natural.
Variables (M N : functor).
Definition P (m : M ~~> N) :=
  forall A B (h : A -> B), (N # h) \o m A = m B \o (M # h).
Record class_of (m : M ~~> N) := Class { _ : P m }.
Structure t := Pack { m : M ~~> N ; class : class_of m }.
End natural.
Module Exports.
Coercion m : t >-> Funclass.
Arguments P : clear implicits.
Notation naturality := P.
Notation "f ~> g" := (t f g).
End Exports.
End Natural.
Export Natural.Exports.

Section natrans_lemmas.
Variables (M N : functor) (phi : M ~> N).
Lemma natural A B (h : A -> B) : (N # h) \o phi A = phi B \o (M # h).
Proof. by case: phi => ? []. Qed.
End natrans_lemmas.

Section id_natural_transformation.
Variables C : functor.
Definition natural_id : naturality _ _ (fun A => @id (C A)). Proof. by []. Qed.
Definition NId : C ~> C := Natural.Pack (Natural.Class natural_id).
End id_natural_transformation.

Section vertical_composition.
Variables C D E : functor.
Variables (g : D ~> E) (f : C ~> D).
Definition ntcomp := fun A => g A \o f A.
Definition natural_vcomp : naturality _ _ ntcomp.
Proof. by move=> A B h; rewrite compA (natural g) -compA (natural f). Qed.
Definition VComp : C ~> E := Natural.Pack (Natural.Class natural_vcomp).
End vertical_composition.

Section horizontal_composition.
Variables (F G F' G' : functor) (s : F ~> G) (t : F' ~> G').
Lemma natural_hcomp :
  naturality (F' \O F) (G' \O G) (fun A => @t (G A) \o F' # (@s A)).
Proof.
move=> A B h; rewrite compA (natural t) -compA -[in RHS]compA.
by congr (_ \o _); rewrite FCompE -2!functor_o (natural s).
Qed.
Definition HComp : (F' \O F) ~> (G' \O G) :=
  Natural.Pack (Natural.Class natural_hcomp).
End horizontal_composition.

Section natural_transformation_example.
Definition fork' : FId ~~> squaring := fun A (a : A) => (a, a).
Lemma fork_natural : naturality _ _ fork'. Proof. by []. Qed.
Definition fork : FId ~> squaring := Natural.Pack (Natural.Class fork_natural).
End natural_transformation_example.

Section adjoint_functors.
Variables f g : functor.
Definition eta_type := FId ~~> g \O f.
Definition eps_type := f \O g ~~> FId.
Definition triangular_law1 (eps : eps_type) (eta : eta_type) :=
  forall A, eps (f A) \o (f # eta A) = @id (f A).
Definition triangular_law2 (eps : eps_type) (eta : eta_type) :=
  forall A, (g # eps A) \o eta (g A) = @id (g A).
Definition adjunction eta eps :=
  (naturality _ _ eps /\ naturality _ _ eta) /\
  (triangular_law1 eps eta /\ triangular_law2 eps eta).
Definition phi A B eta (h : f A -> B) : A -> g B := (g # h) \o eta A.
Definition psi A B eps (h : A -> g B) : f A -> B := eps B \o (f # h).
End adjoint_functors.
Arguments adjunction : clear implicits.

Notation "f -| g :: n , e" := (adjunction f g n e).

Section adjoint_example.
Variable (X : Type).
Definition curry_eps : eps_type (curry_F X) (uncurry_F X) :=
  fun A (af : X * (X -> A)) => af.2 af.1.
Definition curry_eta : eta_type (curry_F X) (uncurry_F X) :=
  fun A (a : A) => fun x : X => (x, a).
Lemma adjoint_currry : curry_F X -| uncurry_F X :: curry_eta, curry_eps.
Proof.
split.
  split => A B h /=.
  - by rewrite /id_f /curry_eps /curry_f /= /uncurry_M /uncurry_f /= boolp.funeqE; case.
  - rewrite /uncurry_f /curry_f /curry_eta /id_f /= boolp.funeqE => a /=.
    by rewrite boolp.funeqE.
split.
  by move=> A; rewrite /triangular_law1 boolp.funeqE; case.
move=> A; rewrite /triangular_law2 /uncurry_F /curry_eps /curry_eta /uncurry_M.
by rewrite /= /uncurry_f /= /comp /= boolp.funeqE => f; rewrite boolp.funeqE.
Qed.
End adjoint_example.

Module BindLaws.
Section bindlaws.
Variable M : Type -> Type.

Variable b : forall A B, M A -> (A -> M B) -> M B.

Local Notation "m >>= f" := (b m f).

Definition associative := forall A B C (m : M A) (f : A -> M B) (g : B -> M C),
  (m >>= f) >>= g = m >>= (fun x => (f x >>= g)).

Definition right_distributive (add : forall B, M B -> M B -> M B) :=
  forall A B (m : M A) (k1 k2 : A -> M B),
    m >>= (fun x => add _ (k1 x) (k2 x)) = add _ (m >>= k1) (m >>= k2).

Definition left_distributive (add : forall B, M B -> M B -> M B) :=
  forall A B (m1 m2 : M A) (k : A -> M B),
    (add _ m1 m2) >>= k = add _ (m1 >>= k) (m2 >>= k).

Definition left_zero (f : forall A, M A) :=
  forall A B (g : A -> M B), f A >>= g = f B.

Definition right_zero (f : forall A, M A) :=
  forall A B (g : M B), g >>= (fun _ => f A) = f A.

Definition left_neutral (r : forall A, A -> M A) :=
  forall A B (a : A) (f : A -> M B), r _ a >>= f = f a.

Definition right_neutral (r : forall A, A -> M A) :=
  forall A (m : M A), m >>= r _ = m.

Definition left_id (r : forall A, M A) (op : forall B, M B -> M B -> M B) :=
  forall A (m : M A), op _ (r _) m = m.

Definition right_id (r : forall A, M A) (op : forall B, M B -> M B -> M B) :=
  forall A (m : M A), op _ m (r _) = m.

End bindlaws.
End BindLaws.

Module monad_of_adjoint.
Section def.
Variables (F G : functor) (eps : eps_type F G) (eta : eta_type F G).
Definition M := G \O F.
Definition mu : M \O M ~~> M := fun A => G # (@eps (F A)).
Definition bind A B (m : M A) (f : A -> M B) : M B := mu ((M # f) m).
End def.
Section prop.
Variables (f g : functor) (eps : eps_type f g) (eta : eta_type f g).
Hypothesis Had : f -| g :: eta, eps.
Section mu_eps_natural.
Notation M := (M f g).
Notation mu := (mu eps).
Lemma muM_natural : naturality _ _ mu.
Proof.
move: Had => [[Heps _] _]; move: Heps; rewrite /natural => Heps.
move => A B h.
rewrite (_ : (M \O M) # h = g # ((f \O g) # (f # h))) //.
rewrite (_ : _ \o g # ((f \O g) # (f # h)) =
  g # (@eps (f B) \o ((f \O g) # (f # h)))); last by rewrite -functor_o.
rewrite -Heps.
rewrite FIdf.
rewrite FCompE.
by rewrite functor_o.
Qed.
Lemma epsC A :
  @eps _ \o @eps _ = @eps _ \o f # (g # (@eps _)) :> ((f \o g) ((f \o g) A) -> A).
Proof. by move : Had => [[Heps _] _]; rewrite -(Heps _ _ (@eps A)). Qed.
Lemma muMA A : @mu A \o @mu (M A) = @mu A \o (M # @mu A).
Proof.
have -> : g # @eps (f A) \o g # @eps (f (M A)) =
         g # (@eps (f A) \o @eps (f (M A))) by rewrite functor_o.
by rewrite epsC functor_o.
Qed.
End mu_eps_natural.
Lemma bindetaf : BindLaws.left_neutral (bind eps) eta.
Proof.
rewrite /BindLaws.left_neutral => A B a h.
case: Had => [[_ Had2] [_ Ht2]]; move: Had2 => /(_ _ _ h) Had2.
rewrite /bind /mu.
rewrite -(compE ((g \O f) # h)).
rewrite Had2.
move: Ht2; rewrite /triangular_law2 => Ht2'.
rewrite -(compE (g # _)) compA.
by rewrite Ht2'.
Qed.
Lemma bindmeta : BindLaws.right_neutral (bind eps) eta.
Proof.
rewrite /BindLaws.right_neutral => A m.
rewrite /bind /mu.
rewrite -(compE (g # _)).
rewrite -functor_o.
case: Had => [_ [Ht1 _]].
by rewrite Ht1 functor_id.
Qed.
Lemma law3 : BindLaws.associative (bind eps).
Proof.
rewrite /BindLaws.associative => A B C x ab bc.
rewrite /bind.
set N := M f g.
set j := mu eps.
rewrite [X in _ = j C X](_ : _ =
  (N # (j C)) ((N # (N # bc)) ((N # ab) x))); last first.
  rewrite functor_o /funcomp.
  congr (N # j C).
  by rewrite functor_o /funcomp.
move: muMA (muM_natural bc).
rewrite -/N -/j.
move=> muMA.
rewrite FCompE.
have -> : (N # bc) (j B ((N # ab) x)) = (N # bc \o j B) ((N # ab) x) by [].
move=> ->.
rewrite compE.
rewrite [LHS](_ : _ = (j C \o j (N C)) ((N # (N # bc)) ((N # ab) x))) //.
by rewrite muMA.
Qed.
End prop.
End monad_of_adjoint.

Section composite_adjoint.
Variables (F0 U0 : functor) (eta0 : eta_type F0 U0) (eps0 : eps_type F0 U0).
Hypothesis H0 : F0 -| U0 :: eta0, eps0.
Variables (F U : functor) (eta : eta_type F U) (eps : eps_type F U).
Hypothesis H : F -| U :: eta, eps.

Let uni : @eta_type (F \O F0) (U0 \O U) := fun A => U0 # (@eta (F0 A)) \o (@eta0 A).
Let couni : @eps_type (F \O F0) (U0 \O U) := fun A => (@eps _) \o F # (@eps0 (U A)).

Lemma composite_adjoint : F \O F0 -| U0 \O U :: uni, couni.
Proof.
case: H0; rewrite /natural => [[H01 H02] [Ht01 Ht02]].
case: H; rewrite /natural => [[H1 H2] [Ht1 Ht2]].
split.
  split => A B h; rewrite FIdf.
  - rewrite {1}/couni [in LHS]compA {}H1 -compA.
    rewrite {1}/couni -[in RHS]compA; congr (_ \o _).
    rewrite [in LHS]FCompE -[in LHS](functor_o F) [in LHS]H01.
    by rewrite -[in RHS](functor_o F).
  - rewrite /uni -[in RHS]compA -[in RHS]H02 compA [in RHS]compA.
    congr (_ \o _).
    rewrite (FCompE U0 F0).
    rewrite -[in RHS](functor_o U0).
    rewrite -[in LHS](functor_o U0).
    congr (_ # _).
    by rewrite -H2.
split.
- rewrite /triangular_law1 => A.
  rewrite /couni /uni /=.
  rewrite FCompE -compA -functor_o.
  rewrite (_ : @eps0 _ \o F0 # _ = @eta (F0 A)); first exact: Ht1.
  rewrite functor_o compA -FCompE.
  by rewrite -H01 /= FIdf -compA Ht01 compfid.
- rewrite /triangular_law2 => A.
  rewrite /couni /uni /=.
  rewrite compA -[RHS](Ht02 (U A)); congr (_ \o _).
  rewrite FCompE -functor_o; congr (_ # _).
  rewrite functor_o -compA -FCompE.
  by rewrite H2 FIdf compA Ht2 compidf.
Qed.

End composite_adjoint.

Module JoinLaws.
Section join_laws.
Context {M : functor}.
Variables (ret : FId ~~> M) (join : M \O M ~~> M).

Definition ret_naturality := naturality FId M ret.

Definition join_naturality := naturality (M \O M) M join.

Definition left_unit := forall A, @join _ \o @ret _ = id :> (M A -> M A).

Definition right_unit := forall A, @join _ \o M # @ret _ = id :> (M A -> M A).

Definition associativity :=
  forall A, @join _ \o M # @join _ = @join _ \o @join _ :> (M (M (M A)) -> M A).

End join_laws.
End JoinLaws.

Section from_join_laws_to_bind_laws.
Variable F : functor.
Variable (ret : FId ~~> F) (join : F \O F ~~> F).

Hypothesis ret_naturality : JoinLaws.ret_naturality ret.
Hypothesis join_naturality : JoinLaws.join_naturality join.
Hypothesis joinretM : JoinLaws.left_unit ret join.
Hypothesis joinMret : JoinLaws.right_unit ret join.
Hypothesis joinA : JoinLaws.associativity join.

Let bind (A B : Type) (m : F A) (f : A -> F B) : F B := join ((F # f) m).

Lemma bindretf_derived : BindLaws.left_neutral bind ret.
Proof.
move=> A B a f; rewrite /bind -(compE (@join _)) -(compE _ (@ret _)) -compA.
by rewrite ret_naturality compA joinretM compidf.
Qed.

Lemma bindmret_derived : BindLaws.right_neutral bind ret.
Proof. by move=> A m; rewrite /bind -(compE (@join _)) joinMret. Qed.

Lemma bindA_derived : BindLaws.associative bind.
Proof.
move=> A B C m f g; rewrite /bind.
rewrite [LHS](_ : _ = ((@join _ \o (F # g \o @join _) \o F # f) m)) //.
rewrite join_naturality (compA (@join C)) -joinA -(compE (@join _)).
transitivity ((@join _ \o F # (@join _ \o (F # g \o f))) m) => //.
by rewrite -2!compA functor_o FCompE -[in LHS](functor_o F).
Qed.

End from_join_laws_to_bind_laws.

Module Monad.
Record mixin_of (M : functor) : Type := Mixin {
  ret : FId ~~> M ;
  join : M \O M ~~> M ;
  _ : JoinLaws.ret_naturality ret ;
  _ : JoinLaws.join_naturality join ;
  _ : JoinLaws.left_unit ret join ;
  _ : JoinLaws.right_unit ret join ;
  _ : JoinLaws.associativity join
  }.
Record class_of (M : Type -> Type) := Class {
  base : Functor.class_of M ; mixin : mixin_of (Functor.Pack base) }.
Structure t : Type := Pack { m : Type -> Type ; class : class_of m }.
Definition baseType (M : t) := Functor.Pack (base (class M)).
Module Exports.
Definition Ret (M : t) : forall A, A -> m M A :=
  let: Pack _ (Class _ (Mixin ret _ _ _ _ _ _) ) := M return forall A, A -> m M A in ret.
Arguments Ret {M A} : simpl never.
Definition Join (M : t) A : m M (m M A) -> m M A :=
  let: Pack _ (Class _ (Mixin _ join _ _ _ _ _)) := M in join A.
Arguments Join {M A} : simpl never.
Notation monad := t.
Coercion baseType : monad >-> functor.
Canonical baseType.
End Exports.
End Monad.
Export Monad.Exports.

Section monad_interface.
Variable M : monad.
Lemma ret_naturality : JoinLaws.ret_naturality (@Ret M).
Proof. by case: M => ? [? []]. Qed.
Lemma join_naturality : JoinLaws.join_naturality (@Join M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinretM : JoinLaws.left_unit (@Ret M) (@Join M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinMret : JoinLaws.right_unit (@Ret M) (@Join M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinA : JoinLaws.associativity (@Join M).
Proof. by case: M => ? [? []]. Qed.
End monad_interface.

Section monad_lemmas.
Variable M : monad.

Definition Bind A B (x : M A) (f : A -> M B) : M B := Join ((M # f) x).
Arguments Bind {A B} : simpl never.
Local Notation "m >>= f" := (Bind m f).
Lemma bindE A B : forall x (f : A -> M B), x >>= f = Join ((M # f) x).
Proof. by []. Qed.
Lemma bindretf : BindLaws.left_neutral (@Bind) (@Ret _).
Proof. apply: bindretf_derived; [exact: ret_naturality | exact: joinretM]. Qed.
Lemma bindmret : BindLaws.right_neutral (@Bind) (@Ret _).
Proof. apply: bindmret_derived; exact: joinMret. Qed.
Lemma bindA : BindLaws.associative (@Bind).
Proof. apply bindA_derived; [exact: join_naturality | exact: joinA]. Qed.

(*Lemma bindE' (A B : Type) : Bind = fun x (f : A -> M B) => Join ((M # f) x).
Proof. by []. Qed.*)
(*Lemma joinretM' A C (f:C->_) : @Join M A \o (@Ret M (M A) \o f) = f.
Proof. by rewrite compA joinretM. Qed.*)
(*Lemma joinMret' A C (f:C->_) : @Join M A \o (M # @Ret M A \o f) = f.
Proof. by rewrite compA joinMret. Qed.*)
(*Lemma joinA' A C (f:C->_) : @Join M A \o (M # @Join M A \o f) = @Join M A \o (@Join M (M A) \o f).
Proof. by rewrite compA joinA. Qed.*)
End monad_lemmas.
Arguments Bind {M A B} : simpl never.

(* sigma operation, jaskelioff ESOP 2009 *)
Definition operation (E : functor) (M : monad) := (E \O M) ~> M.

Notation "'do' x <- m ; e" := (Bind m (fun x => e)) : do_notation.
Notation "'do' x : T <- m ; e" := (Bind m (fun x : T => e)) (only parsing) : do_notation.
Delimit Scope do_notation with Do.
Notation "m >>= f" := (Bind m f) : monae_scope.
Notation "m >> f" := (Bind m (fun _ => f)) : monae_scope.
Delimit Scope monae_scope with monae.
Local Open Scope monae_scope.

Definition skip M := @Ret M _ tt.
Arguments skip {M} : simpl never.

Ltac bind_ext :=
  let congr_ext m := ltac:(congr (Bind m); rewrite boolp.funeqE) in
  match goal with
    | |- @Bind _ _ _ ?m ?f1 = @Bind _ _ _ ?m ?f2 =>
      congr_ext m
    | |- @Bind _ _ _ ?m1 ?f1 = @Bind _ _ _ ?m2 ?f2 =>
      first[ simpl m1; congr_ext m1 | simpl m2; congr_ext m2 ]
  end.

(* experimental *)
Tactic Notation "With" tactic(tac) "Open" ssrpatternarg(pat) :=
  ssrpattern pat;
  let f := fresh "f" in
  intro f;
  let g := fresh "g" in
  let typ := typeof f in
  let x := fresh "x" in
  evar (g : typ);
  rewrite (_ : f = g);
  [rewrite {}/f {}/g|
   rewrite boolp.funeqE => x; rewrite {}/g {}/f; tac]; last first.

Tactic Notation "Open" ssrpatternarg(pat) :=
  With (idtac) Open pat.

Tactic Notation "Inf" tactic(tac) :=
  (With (tac; reflexivity) Open (X in @Bind _ _ _ _ X = _ )) ||
  (With (tac; reflexivity) Open (X in _ = @Bind _ _ _ _ X)).

Tactic Notation "rewrite_" constr(lem) :=
  (With (rewrite lem; reflexivity) Open (X in @Bind _ _ _ _ X = _ )) ||
  (With (rewrite lem; reflexivity) Open (X in _ = @Bind _ _ _ _ X)).

Lemma bindmskip (M : monad) (m : M unit) : m >> skip = m.
Proof. rewrite -[RHS]bindmret; bind_ext; by case. Qed.

Lemma bindskipf (M : monad) A (m : M A) : skip >> m = m.
Proof. exact: bindretf. Qed.

Fixpoint sequence (M : monad) A (s : seq (M A)) : M (seq A) :=
  (if s isn't h :: t then Ret [::] else
  do v <- h; do vs <- sequence t; Ret (v :: vs))%Do.

Lemma sequence_nil (M : monad) A : sequence [::] = Ret [::] :> M (seq A).
Proof. by []. Qed.

Lemma sequence_cons (M : monad) A h (t : seq (M A)) :
  (sequence (h :: t) = do x <- h ; do vs <- sequence t ; Ret (x :: vs))%Do.
Proof. by []. Qed.

Module Monad_of_ret_bind.
Section monad_of_ret_bind.
Variable M : Type -> Type.
Variable ret : forall A, A -> M A.
Variable bind : forall (A B : Type), M A -> (A -> M B) -> M B.
Hypothesis bindretf : BindLaws.left_neutral bind ret.
Hypothesis bindmret : BindLaws.right_neutral bind ret.
Hypothesis bindA : BindLaws.associative bind.

Definition Map A B (f : A -> B) (m : M A) := bind m (@ret B \o f).
Lemma Map_id : FunctorLaws.id Map.
Proof. by move=> A; rewrite boolp.funeqE => m; rewrite /Map bindmret. Qed.
Lemma Map_o : FunctorLaws.comp Map.
Proof.
move=> A B C g h; rewrite boolp.funeqE => m.
rewrite /Map compE bindA; congr bind.
by rewrite boolp.funeqE => a; rewrite bindretf.
Qed.
Definition functor_mixin := Functor.Class Map_id Map_o.
Let M' := Functor.Pack functor_mixin.

Lemma MapE A B (f : A -> B) m : (M' # f) m = bind m (ret (A:=B) \o f).
Proof. by []. Qed.

Let ret' : FId ~~> M' := ret.
Definition join A (pp : M' (M' A)) := bind pp id.

Let bind_Map A B C (f : A -> B) (m : M A) (g : B -> M C) :
  bind (Map f m) g = bind m (g \o f).
Proof.
rewrite /Map bindA; congr bind; by rewrite boolp.funeqE => ?; rewrite bindretf.
Qed.

Lemma ret_naturality : naturality FId M' ret.
Proof.
move=> A B h; rewrite FIdf boolp.funeqE => ?.
by rewrite compE /= /Map MapE /= bindretf.
Qed.

Let bindE A B m (f : A -> M' B) : bind m f = join ((M' # f) m).
Proof. by rewrite /join bind_Map. Qed.

Let Map_bind A B C (f : A -> B) m (g : C -> M A) :
  (Map f) (bind m g) = bind m (Map f \o g).
Proof. by rewrite /Map bindA bindE. Qed.

Lemma join_naturality : naturality (M' \O M') M' join.
Proof.
move=> A B h; rewrite boolp.funeqE => mma.
by rewrite /Fun 2!compE /Map [in RHS]/join bind_Map [in LHS]/join bindA.
Qed.

Lemma joinretM : JoinLaws.left_unit ret' join.
Proof. by rewrite /join => A; rewrite boolp.funeqE => ma; rewrite compE bindretf. Qed.

Lemma joinMret : JoinLaws.right_unit ret' join.
Proof.
rewrite /join => A; rewrite boolp.funeqE => ma;
by rewrite compE bind_Map compidf bindmret.
Qed.

Lemma joinA : JoinLaws.associativity join.
Proof.
move=> A; rewrite boolp.funeqE => mmma.
by rewrite /join !compE bind_Map compidf bindA.
Qed.

Definition monad_mixin := Monad.Mixin
  ret_naturality join_naturality joinretM joinMret joinA.
End monad_of_ret_bind.
Module Exports.
Definition Monad_of_ret_bind M ret bind a b c :=
  Monad.Pack (Monad.Class (@monad_mixin M ret bind a b c)).
End Exports.
End Monad_of_ret_bind.
Export Monad_of_ret_bind.Exports.

Section kleisli.
Variable M : monad.

Definition kleisli A B C (m : B -> M C) (n : A -> M B) : A -> M C :=
  Join \o (M # m) \o n.
Local Notation "m <=< n" := (kleisli m n).
Local Notation "m >=> n" := (kleisli n m).

Lemma bind_kleisli A B C m (f : A -> M B) (g : B -> M C) :
  m >>= (f >=> g) = (m >>= f) >>= g.
Close Scope monae_scope.

Proof. by rewrite bindA; bind_ext => a; rewrite /kleisli !compE join_fmap. Qed.

Lemma ret_kleisli A B (k : A -> M B) : Ret >=> k = k.
Proof. by rewrite /kleisli -compA ret_naturality FIdf compA joinretM. Qed.

Local Open Scope mprog.
Lemma fcomp_kleisli A B C D (f : A -> B) (g : C -> M A) (h : D -> M C) :
  f (o) (g <=< h) = (f (o) g) <=< h.
Proof.
rewrite /kleisli 2!fcomp_def 2!(compA (fmap f)).
by rewrite join_naturality functor_o compA.
Qed.

Lemma kleisli_fcomp A B C (f : A -> M B) (g : B -> A) (h : C -> M B) :
  ((f \o g) <=< h) = f <=< (g (o) h).
Proof. by rewrite /kleisli fcomp_def functor_o 2!compA. Qed.
Local Close Scope mprog.

End kleisli.
Notation "m <=< n" := (kleisli m n) : monae_scope.
Notation "m >=> n" := (kleisli n m) : monae_scope.

Section fmap_and_join.
Variable M : monad.
Local Open Scope mprog.

Lemma fmapE A B (f : A -> B) (m : M _) : fmap f m = m >>= (Ret \o f).
Proof.
by rewrite bindE [in RHS]functor_o [in RHS]compE -[in RHS](compE Join) joinMret.
Qed.

Lemma bind_fmap A B C (f : A -> B) (m : M A) (g : B -> M C) :
  fmap f m >>= g = m >>= (g \o f).
Proof. by rewrite fmapE bindA; rewrite_ bindretf. Qed.

Lemma fmap_if A B (f : A -> B) b (m : M A) a :
  fmap f (if b then m else Ret a) = if b then fmap f m else Ret (f a).
Proof. case: ifPn => Hb //; by rewrite fmapE bindretf. Qed.

Lemma fmap_bind A B C (f : A -> B) m (g : C -> M A) :
  fmap f (m >>= g) = m >>= (f (o) g).
Proof.
rewrite fcomp_def fmapE bindA; bind_ext => c; by rewrite compE -/(fmap _ _) fmapE.
Qed.

Lemma skip_fmap A B (f : A -> B) (mb : M B) ma :
  mb >> (fmap f ma) = fmap f (mb >> ma).
Proof. by rewrite fmap_bind fcomp_def. Qed.

(*Lemma rev_map A B (f : A -> B) : rev \o map f = map f \o rev.
Proof.
apply functional_extensionality.
by elim=> // h t /= IH; rewrite !rev_cons IH map_rcons.
Qed.*)

Lemma foldl_revE (T R : Type) (f : R -> T -> R) (z : R) :
  foldl f z \o rev = foldr (fun x : T => f^~ x) z.
Proof. by rewrite boolp.funeqE => s; rewrite -foldl_rev. Qed.

Lemma mfoldl_rev (T R : Type) (f : R -> T -> R) (z : R) (s : seq T -> M (seq T)) :
  foldl f z (o) (rev (o) s) = foldr (fun x => f^~ x) z (o) s.
Proof.
rewrite boolp.funeqE => x; rewrite !fcompE 3!fmapE !bindA.
bind_ext => ?; by rewrite bindretf /= -foldl_rev.
Qed.

Lemma joinE A (pp : M (M A)) : Join pp = pp >>= id.
Proof. rewrite bindE; congr Join; by rewrite functor_id. Qed.

Lemma join_fmap A B (f : A -> M B) m : Join (fmap f m) = m >>= f.
Proof. by rewrite bindE. Qed.

End fmap_and_join.

(*
(* monads on Type are strong monads *)
Section strength.
Variable M : monad.
Definition strength A B (xy : (A * M B)%type) : M (A * B)%type :=
  let (x,my) := xy in my >>= (fun y => Ret (x,y)).
Lemma strengthE A B (x:A) (my:M B) : strength (x,my) = my >>= (fun y => Ret (x,y)).
Proof. done. Qed.
Lemma strength_unit A : snd = M # snd \o strength (A:=unit) (B:=A).
Proof.
apply functional_extensionality => x.
case: x => i ma.
rewrite compE strengthE.
rewrite -fmapE fmap_bind fcomp_def.
rewrite bindE.
have ->: Join ((M # (M # snd \o (fun y : A => Ret (i, y)))) ma) =
((M # snd \o Join) \o M # (fun y : A => Ret (i, y))) ma
  by rewrite functor_o join_naturality.
rewrite functor_o.
have ->: ((M # snd \o Join) \o (M # Ret \o M # pair i)) ma =
(M # snd \o (Join \o M # Ret) \o M # pair i) ma by done.
rewrite joinMret compfid.
rewrite -functor_o.
have ->: snd \o pair i = id by done.
by rewrite functor_id.
Qed.
End strength.
*)

Definition mpair {M : monad} {A} (xy : (M A * M A)%type) : M (A * A)%type :=
  let (mx, my) := xy in
  mx >>= (fun x => my >>= fun y => Ret (x, y)).

Lemma mpairE (M : monad) A (mx my : M A) :
  mpair (mx, my) = mx >>= (fun x => my >>= fun y => Ret (x, y)).
Proof. by []. Qed.

Lemma naturality_mpair (M : monad) A B (f : A -> B) (g : A -> M A):
  (M # f^`2) \o (mpair \o g^`2) = mpair \o ((M # f) \o g)^`2.
Proof.
rewrite boolp.funeqE => -[a0 a1].
rewrite compE fmap_bind.
rewrite compE mpairE compE bind_fmap; bind_ext => a2.
rewrite fcompE fmap_bind 2!compE bind_fmap; bind_ext => a3.
by rewrite fcompE -(compE (M # f^`2)) ret_naturality FIdf.
Qed.

(*Local Notation "[ \o f , .. , g , h ]" := (f \o .. (g \o h) ..)
  (at level 0) (*, format "[ \o '['  f , '/' .. , '/' g , '/' h ']' ]"
  ).*) : test_scope.

Local Open Scope test_scope.

Lemma naturality_mpair' (M : monad) A B (f : A -> B) (g : A -> M A):
  (M # f^`2) \o (mpair \o g^`2) = mpair \o ((M # f) \o g)^`2.
Proof.
rewrite funeqE => -[a0 a1].
change ((M # f^`2 \o (mpair \o g^`2)) (a0, a1)) with
    ((M # f^`2) (mpair (g a0, g a1))).
change ((mpair \o (M # f \o g)^`2) (a0, a1)) with
    (mpair ((M # f \o g) a0,(M # f \o g) a1)).
rewrite !mpairE.
rewrite !bindE.
evar (T : Type);evar (RHS : A -> T).
have ->: (fun x : A => do y <- g a1; Ret (x, y)) = RHS.
  rewrite funeqE => x; rewrite bindE.
  rewrite functor_o.
  change (Join ([\o M # Ret,M # pair x] (g a1))) with
        ([\o Join,M # Ret,M # pair x] (g a1)).
    rewrite joinMret'.
  exact: erefl.
rewrite /RHS {RHS}; rewrite {T}.
change ((M # f^`2) (Join ((M # (fun x : A => (M # pair x) (g a1))) (g a0)))) with
    ((M # f^`2 \o Join) ((M # (fun x : A => (M # pair x) (g a1))) (g a0))).
rewrite join_naturality.
evar (T : Type);evar (RHS : T).
have->:(M # (fun x : B => do y <- (M # f \o g) a1; Ret (x, y))) = RHS.
- rewrite functor_o.
  rewrite bindE'.
  rewrite functor_o.
  exact: erefl.
rewrite/RHS{RHS};rewrite{T}.
change
  (
    Join
    (((M # Join \o M # (Fun M (B:=M (B * B)%type))^~ ((M # f \o g) a1)) \o
        M # (fun x y : B => Ret (x, y))) ((M # f \o g) a0))
  ) with
    (
      (
        [ \o Join ,
          (M # Join) ,
          (M # (Fun M (B:=M (B * B)%type))^~ ((M # f \o g) a1)) ,
          (M # (fun x y : B => Ret (x, y))) ,
          (M # f \o g) ]
      ) a0)
    .
rewrite joinA'.
(*
rewrite fmap_bind. compE [in RHS]/= bind_fmap; bind_ext => a2.
rewrite fcompE fmap_bind compE bind_fmap; bind_ext => a3.
by rewrite fcompE -(compE (fmap M # f^`2)) fmap_ret.
Qed.
*)
Abort.

Local Close Scope test_scope.
*)

Section rep.

Variable M : monad.

Fixpoint rep (n : nat) (mx : M unit) : M unit :=
  if n is n.+1 then mx >> rep n mx else skip.

Lemma repS mx n : rep n.+1 mx = rep n mx >> mx.
Proof.
elim: n => /= [|n IH]; first by rewrite bindmskip bindskipf.
by rewrite bindA IH.
Qed.

Lemma rep1 mx : rep 1 mx = mx. Proof. by rewrite repS bindskipf. Qed.

Lemma rep_addn m n mx : rep (m + n) mx = rep m mx >> rep n mx.
Proof.
elim: m n => [|m IH /=] n; by
  [rewrite bindskipf add0n | rewrite -addnE IH bindA].
Qed.

End rep.

Section MonadCount.

Variable M : monad.
Variable tick : M unit.

Fixpoint hanoi n : M unit :=
  if n is n.+1 then hanoi n >> tick >> hanoi n else skip.

Lemma hanoi_rep n : hanoi n = rep (2 ^ n).-1 tick.
Proof.
elim: n => // n IH /=.
rewrite IH -repS prednK ?expn_gt0 // -rep_addn.
by rewrite -subn1 addnBA ?expn_gt0 // addnn -muln2 -expnSr subn1.
Qed.

End MonadCount.
