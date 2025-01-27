(* infotheo: information theory and error-correcting codes in Coq             *)
(* Copyright (C) 2020 infotheo authors, license: LGPL-2.1-or-later            *)
From mathcomp Require Import all_ssreflect ssralg fingroup perm finalg matrix.
From mathcomp Require boolp.
From mathcomp Require Import Rstruct.
Require Import Reals Lra Nsatz.
Require Import ssrR Reals_ext logb ssr_ext ssralg_ext bigop_ext Rbigop.

(******************************************************************************)
(*                         Finite distributions                               *)
(*                                                                            *)
(* This file provides a formalization of finite probability distributions.    *)
(*                                                                            *)
(*  f @^-1 y        == preimage of the point y via the function f where the   *)
(*                     type of x is an eqType                                 *)
(*  {fdist A}       == the type of distributions over a finType A             *)
(*  FDist1.d        == point-supported distribution                           *)
(*  FDistMap.d      == map of the "probability monad"                         *)
(*  Uniform.d       == uniform distribution other a finite type               *)
(*  `U H            == the uniform distribution with support C, where H is a  *)
(*                     proof that the set C is not empty                      *)
(*  Binary.d H p    == where H is a proof of #|A| = 2%N and p is a            *)
(*                     probability: binary distribution over A with bias p    *)
(*  D1FDist.d X P   == distribution built from X where the entry b has been   *)
(*                     removed (where P is a proof that X b != 1)             *)
(*  ConvFDist.d     == convex combination of distributions                    *)
(*                     (convex analogue of vector addition)                   *)
(*  AddFDist.d      == concatenation of two distributions according to a      *)
(*                     given probability p                                    *)
(*                     (convex analogue of the canonical presentation of      *)
(*                      an element of the direct sum of two {fdist _}s)       *)
(*  DelFDist.d      == restriction of the domain of a distribution            *)
(*                     (convex analogue of the projection of a vector         *)
(*                      to a subspace)                                        *)
(*                                                                            *)
(* About bivariate (joint) distributions:                                     *)
(*  Bivar.fst       == marginal left                                          *)
(*  Bivar.snd       == marginal right                                         *)
(* About multivariate (joint) distributions                                   *)
(*  head_of         == head marginal                                          *)
(*  tail_of         == tail marginal                                          *)
(*                                                                            *)
(*  P1 `x P2        == product distribution                                   *)
(*                     (convex analogue of the simple tensor of two vectors)  *)
(*  P `^ n          == product distribution over a row vector                 *)
(*  P1 <| p |> P1   == convex combination of distributions P1 and P2 with     *)
(*                     probability p                                          *)
(*  wolfowitz       == Wolfowitz's counting principle                         *)
(*                                                                            *)
(******************************************************************************)

Reserved Notation "{ 'fdist' T }" (at level 0, format "{ 'fdist'  T }").
Reserved Notation "'`U' HC " (at level 10, HC at next level).
Reserved Notation "P `^ n" (at level 5).
Reserved Notation "P1 `x P2" (at level 6).
Reserved Notation "x <| p |> y" (format "x  <| p |>  y", at level 49).
Reserved Notation "f @^-1 y" (at level 10).

Declare Scope proba_scope.

Set Implicit Arguments.
Unset Strict Implicit.
Import Prenex Implicits.

Local Open Scope R_scope.
Local Open Scope reals_ext_scope.

Notation "f @^-1 y" := (preim f (pred1 y)) : proba_scope.

Module FDist.
Section fdist.
Variable A : finType.
Record t := mk {
  f :> A ->R+ ;
  _ : \sum_(a in A) f a == 1 :> R }.
Lemma ge0 (d : t) a : 0 <= d a.
Proof. by case: d => /= f _; exact/nneg_finfun_ge0. Qed.
Lemma f1 (d : t) : \sum_(a in A) d a = 1 :> R.
Proof. by case: d => f /= /eqP. Qed.
Lemma le1 (d : t) a : d a <= 1.
Proof.
rewrite -(f1 d) (_ : d a = \sum_(a' in A | a' == a) d a').
  apply (@leR_sumRl_support _ _ _ xpredT) => // ?; exact/ge0.
by rewrite big_pred1_eq.
Qed.
Definition make (f : {ffun A -> R}) (H0 : forall a, 0 <= f a)
  (H1 : \sum_(a in A) f a = 1) := @mk (@mkNNFinfun _ f
  (proj1 (@reflect_iff _ _ (forallP_leRP _)) H0)) (introT eqP H1).
End fdist.
Module Exports.
Notation fdist := t.
End Exports.
End FDist.
Export FDist.Exports.
Coercion FDist.f : fdist >-> nneg_finfun.
Canonical fdist_subType A := Eval hnf in [subType for @FDist.f A].
Definition fdist_eqMixin A := [eqMixin of fdist A by <:].
Canonical dist_eqType A := Eval hnf in EqType _ (fdist_eqMixin A).

Global Hint Resolve FDist.ge0 : core.
Global Hint Resolve FDist.le1 : core.

Definition fdist_of (A : finType) := fun phT : phant (Finite.sort A) => fdist A.

Notation "{ 'fdist' T }" := (fdist_of (Phant T)) : proba_scope.

Lemma fdist_ge0_le1 (A : finType) (d : fdist A) a : 0 <= d a <= 1.
Proof. by []. Qed.

Definition probfdist (A : finType) (d : fdist A) a :=
  Eval hnf in Prob.mk_ (fdist_ge0_le1 d a).

Section FDist_lemmas.

Variable A : finType.
Implicit Types d : fdist A.

Definition is_fdist (f : A -> R) : Prop :=
  (forall a, 0 <= f a) /\ (\sum_(a in A) f a = 1).

Lemma fdist_is_fdist d : is_fdist d.
Proof. by case: d; case => f /= /forallP_leRP H0 /eqP H1. Qed.

Lemma fdist_card_neq0 d : (0 < #| A |)%nat.
Proof.
apply/negPn/negP => abs; apply R1_neq_R0.
rewrite -(FDist.f1 d) (eq_bigl xpred0) ?big_pred0_eq // => a.
apply/negP => aA.
move/card_gt0P : abs; apply; by exists a.
Qed.

Definition fdist_supp d := [set a | d a != 0].

Lemma rsum_fdist_supp (f : A -> R) d (P : pred A):
  \sum_(a in A | P a) d a * f a = \sum_(a | P a && (a \in fdist_supp d)) d a * f a.
Proof.
rewrite (bigID (mem (fdist_supp d))) /= addRC (eq_bigr (fun=> 0)); last first.
  move=> i; rewrite inE negbK => /andP[_ /eqP] ->; by rewrite mul0R.
rewrite big_const iter_addR mulR0 add0R [in RHS]big_seq_cond.
apply eq_bigl => a; by rewrite !inE andbC /index_enum -enumT mem_enum inE.
Qed.

Lemma fdist_supp_neq0 (d : fdist A) : fdist_supp d != set0.
Proof.
apply/eqP => H; move: (FDist.f1 d).
rewrite -[LHS]mulR1 big_distrl rsum_fdist_supp H big1 //=.
  move/esym; exact: R1_neq_R0.
by move=> i; rewrite inE.
Qed.

Lemma fdist_supp_mem (d : fdist A) : {i | i \in fdist_supp d}.
Proof.
case: (set_0Vmem (fdist_supp d)) (fdist_supp_neq0 d) => // ->; by rewrite eqxx.
Qed.

Lemma fdist_ind (P : fdist A -> Type) :
  (forall n : nat, (forall X, #|fdist_supp X| = n -> P X) ->
    forall X b, #|fdist_supp X| = n.+1 -> X b != 0 -> P X) ->
  forall X, P X.
Proof.
move=> H1 d.
move: {-2}(#|fdist_supp d|) (erefl (#|fdist_supp d|)) => n; move: n d.
elim=> [d /esym /card0_eq Hd0|n IH d n13].
  move: (FDist.f1 d).
  rewrite -[X in X = _]mulR1 big_distrl rsum_fdist_supp big1 => [H01|a].
  by exfalso; move: H01; apply/eqP; rewrite ltR_eqF.
  by rewrite Hd0.
have [b Hb] : {b : A | d b != 0}.
  suff : {x | x \in fdist_supp d} by case => a; rewrite inE => ?; exists a.
  apply/sigW/set0Pn; by rewrite -cards_eq0 -n13.
by refine (H1 n _ _ _ _ Hb) => // d' A2; apply IH.
Qed.

Lemma fdist_gt0 d a : (d a != 0) <-> (0 < d a).
Proof.
split => H; [|by move/gtR_eqF : H].
by rewrite ltR_neqAle; split => //; exact/nesym/eqP.
Qed.

Lemma fdist_lt1 d a : (d a != 1) <-> (d a < 1).
Proof.
split=> H; first by rewrite ltR_neqAle; split => //; exact/eqP.
exact/ltR_eqF.
Qed.

Lemma fdist_ext d d' : (forall x, d x = d' x) -> d = d'.
Proof. by move=> ?; exact/val_inj/val_inj/ffunP. Qed.

End FDist_lemmas.

Local Open Scope proba_scope.

Module FDist1.
Section fdist1.
Variables (A : finType) (a : A).
Definition f := [ffun b => INR (b == a)%bool].
Lemma f0 b : 0 <= f b. Proof. by rewrite ffunE; exact: leR0n. Qed.
Lemma f1 : \sum_(b in A) f b = 1.
Proof.
rewrite (bigD1 a) //= {1}/f ffunE eqxx /= (eq_bigr (fun=> 0)); last first.
  by move=> b ba; rewrite /f ffunE (negbTE ba).
by rewrite big1_eq // addR0.
Qed.
Definition d : fdist A := locked (FDist.make f0 f1).
Lemma dE a0 : d a0 = INR (a0 == a)%bool.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End fdist1.
Section prop.
Variable A : finType.
Lemma P (d : {fdist A}) a : reflect (forall i, i != a -> d i = 0) (d a == 1).
Proof.
apply: (iffP idP) => [/eqP H b ?|H].
- move : (FDist.f1 d); rewrite (bigD1 a) //= H => /esym/eqP.
  rewrite addRC -subR_eq' subRR.
  move/eqP/esym/psumR_eq0P => -> // c ca; exact/fdist_ge0.
- move: (FDist.f1 d); rewrite (bigD1 a) //= => /esym.
  by rewrite -subR_eq => <-; rewrite big1 // subR0.
Qed.
Lemma dE1 (d' : fdist A) a : (d' a == 1 :> R) = (d' == d a :> {fdist A}).
Proof.
apply/idP/idP => [Pa1|/eqP ->]; last by rewrite dE eqxx.
apply/eqP/fdist_ext => a0; rewrite dE.
case/boolP : (a0 == a :> A) => Ha.
by rewrite (eqP Ha); exact/eqP.
by move/P : Pa1 => ->.
Qed.
Lemma supp a : fdist_supp (d a) = [set a] :> {set A}.
Proof.
apply/setP => a0; rewrite !inE; case/boolP : (_ == _ :> A) => [/eqP ->|a0a].
by rewrite dE eqxx; apply/negbT => /=; apply/eqP; rewrite INR_eq0.
by apply/negbTE; rewrite negbK dE (negbTE a0a).
Qed.
Lemma I1 (d : {fdist 'I_1}) : d = FDist1.d ord0.
Proof.
apply/fdist_ext => /= i; rewrite dE (ord1 i) eqxx.
by move: (FDist.f1 d); rewrite big_ord_recl big_ord0 addR0.
Qed.
End prop.
End FDist1.

Module FDistBind.
Section def.
Variables (A B : finType) (p : fdist A) (g : A -> fdist B).
Definition f := [ffun b => \sum_(a in A) p a * (g a) b].
Lemma f0 b : 0 <= f b.
Proof. rewrite /f ffunE; apply sumR_ge0 => a _; exact: mulR_ge0. Qed.
Lemma f1 : \sum_(b in B) f b = 1.
Proof.
rewrite /f; evar (h : B -> R); rewrite (eq_bigr h); last first.
  move=> b _; rewrite ffunE /h; reflexivity.
rewrite {}/h exchange_big /= -[RHS](FDist.f1 p); apply eq_bigr => a _.
by rewrite -big_distrr /= FDist.f1 mulR1.
Qed.
Definition d : fdist B := locked (FDist.make f0 f1).
Lemma dE x : d x = \sum_(a in A) p a * (g a) x.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End def.
End FDistBind.

Lemma FDistBind1f (A B : finType) (a : A) (f : A -> fdist B) :
  FDistBind.d (FDist1.d a) f = f a.
Proof.
apply/fdist_ext => b; rewrite FDistBind.dE /= (bigD1 a) //= FDist1.dE eqxx mul1R.
rewrite (eq_bigr (fun=> 0)) ?big_const ?iter_addR ?mulR0 ?addR0 // => c ca.
by rewrite FDist1.dE (negbTE ca) mul0R.
Qed.

Lemma FDistBindp1 A (p : fdist A) : FDistBind.d p (@FDist1.d A) = p.
Proof.
apply/fdist_ext => /= a; rewrite FDistBind.dE /= (bigD1 a) // FDist1.dE eqxx mulR1.
rewrite (eq_bigr (fun=> 0)) ?big_const ?iter_addR ?mulR0 /= ?addR0 //.
by move=> b ba; rewrite FDist1.dE eq_sym (negbTE ba) mulR0.
Qed.

Lemma FDistBindA A B C (m : fdist A) (f : A -> fdist B) (g : B -> fdist C) :
  FDistBind.d (FDistBind.d m f) g = FDistBind.d m (fun x => FDistBind.d (f x) g).
Proof.
apply/fdist_ext => c; rewrite !FDistBind.dE /=.
rewrite (eq_bigr (fun a => \sum_(a0 in A) m a0 * f a0 a * g a c)); last first.
  move=> b _; by rewrite FDistBind.dE big_distrl.
rewrite exchange_big /=; apply eq_bigr => a _.
rewrite FDistBind.dE big_distrr /=; apply eq_bigr => b _; by rewrite mulRA.
Qed.

Module FDistMap.
Section def.
Variables (A B : finType) (g : A -> B) (p : fdist A).
Definition d : {fdist B} := FDistBind.d p (fun a => FDist1.d (g a)).
Lemma dE (b : B) : d b = \sum_(a in A | a \in g @^-1 b) p a.
Proof.
rewrite /d FDistBind.dE [in RHS]big_mkcond /=; apply eq_bigr => a _.
case: ifPn => [|]; first by rewrite inE => /eqP->; rewrite FDist1.dE eqxx mulR1.
by rewrite !inE => gab; rewrite FDist1.dE eq_sym (negbTE gab) mulR0.
Qed.
End def.
Section prop.
Variables (A B C : finType).
Lemma id P : d (@id A) P = P. Proof. by rewrite /d FDistBindp1. Qed.
Lemma comp (g : A -> B) (h : C -> A) P : d g (d h P) = d (g \o h) P.
Proof.
rewrite /d FDistBindA; congr (FDistBind.d _ _).
by rewrite boolp.funeqE => x; rewrite FDistBind1f.
Qed.
End prop.
End FDistMap.

Module Uniform.
Section def.
Variables (A : finType) (n : nat).
Hypothesis domain_not_empty : #|A| = n.+1.
Definition f := [ffun a : A => INR 1 / INR #|A|].
Lemma f0 a : 0 <= f a.
Proof. rewrite ffunE; apply/divR_ge0 => //; apply/ltR0n; by rewrite domain_not_empty. Qed.
Lemma f1 : \sum_(a in A) f a = 1.
Proof.
rewrite /f; evar (h : A -> R); rewrite (eq_bigr h); last first.
  move=> b _; rewrite ffunE /h; reflexivity.
rewrite {}/h -big_distrr /= mul1R big_const iter_addR mulRV //.
by rewrite INR_eq0' domain_not_empty.
Qed.
Definition d : fdist A := locked (FDist.make f0 f1).
Lemma dE a : d a = / INR #|A|.
Proof. by rewrite /d; unlock => /=; rewrite /f div1R ffunE. Qed.
End def.
Lemma d_neq0 (C : finType) (domain_non_empty : { m : nat | #| C | = m.+1 }) :
  forall x, d (projT2 domain_non_empty) x != 0.
Proof.
move=> c; rewrite dE invR_neq0' //; apply/eqP.
case: domain_non_empty => x' ->; by rewrite INR_eq0.
Qed.
End Uniform.

Lemma dom_by_uniform A (P : fdist A) n (HA : #|A| = n.+1) : P `<< Uniform.d HA.
Proof.
apply/dominatesP => a; rewrite Uniform.dE => /esym abs; exfalso.
by move: abs; rewrite HA; apply/eqP; rewrite ltR_eqF //; apply/invR_gt0/ltR0n.
Qed.

Module UniformSupport.
Section def.
Variables (A : finType) (C : {set A}).
Hypothesis support_not_empty : (0 < #|C|)%nat.
Definition f := [ffun a : A => if a \in C then 1 / INR #|C| else 0].
Lemma f0 a : 0 <= f a.
Proof.
rewrite /f ffunE.
case e : (a \in C); last exact/leRR.
apply divR_ge0; [lra|exact/ltR0n].
Qed.
Lemma f1 : \sum_(a in A) f a = 1.
Proof.
rewrite /f.
have HC' : #|C|%:R != 0 by rewrite INR_eq0' -lt0n.
transitivity (\sum_(a in A) (if a \in C then 1 else 0) / INR #|C|).
apply eq_bigr => a _.
  rewrite ffunE; case aC : (a \in C); by [ | move/eqP in HC'; field].
have HC'' : \sum_(a in A) (if a \in C then 1 else 0) = #|C|%:R.
  by rewrite -big_mkcondr /= big_const iter_addR mulR1.
by rewrite /Rdiv -big_distrl HC'' /= mulRV.
Qed.
Definition d : fdist A := locked (FDist.make f0 f1).
End def.
Local Notation "'`U' HC " := (d HC).
Section prop.
Variables (A : finType) (C : {set A}) (HC : (0 < #| C |)%nat).

Lemma dET z : z \in C -> (`U HC) z = 1 / INR #|C|.
Proof. by rewrite /d; unlock; rewrite /= /f ffunE => ->. Qed.

Lemma dEN z : z \notin C -> (`U HC) z = 0.
Proof. by rewrite /d; unlock; move/negbTE; rewrite /= /f ffunE => ->. Qed.

Lemma restrict g : \sum_(t in A) ((`U HC) t * g t) = \sum_(t in C) ((`U HC) t * g t).
Proof.
rewrite (bigID (fun x => x \in C)) /= addRC (eq_bigr (fun=> 0)).
by rewrite big_const // iter_addR mulR0 add0R.
move=> a aC; by rewrite dEN // mul0R.
Qed.

Lemma big_distrr g : \sum_(t in C) ((`U HC) t * g t) = (/ INR #|C| * \sum_(t in C) g t).
Proof.
rewrite /= big_distrr /=; apply eq_bigr => /= i Hi; by rewrite dET // div1R.
Qed.

Lemma neq0 z : ((`U HC) z != 0) = (z \in C).
Proof.
case/boolP : (z \in C) => [/dET ->|/dEN ->//]; last by rewrite eqxx.
rewrite div1R; by apply/invR_neq0'; rewrite INR_eq0' -lt0n.
Qed.
End prop.
End UniformSupport.

Notation "'`U' HC " := (UniformSupport.d HC) : proba_scope.

Module Binary.
Section def.
Variable A : finType.
Hypothesis HA : #|A| = 2%nat.
Variable p : prob.
Definition f (a : A) := [ffun a' => if a' == a then p.~ else p].
Lemma f0 (a a' : A) : 0 <= f a a'.
Proof. by rewrite /f ffunE; case: ifP. Qed.
Lemma f1 (a : A) : \sum_(a' in A) f a a' = 1.
Proof.
rewrite Set2sumE /= /f !ffunE; case: ifPn => [/eqP <-|].
  by rewrite eq_sym (negbTE (Set2.a_neq_b HA)) subRK.
by rewrite eq_sym; move/Set2.neq_a_b/eqP => <-; rewrite eqxx subRKC.
Qed.
Definition d : A -> fdist A := fun a => locked (FDist.make (f0 a) (f1 a)).
Lemma dE a a' : d a a' = if a' == a then 1 - p else p.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
Lemma d_sum_swap a : \sum_(a' in A) d a a' = \sum_(a' in A) d a' a.
Proof. by rewrite 2!Set2sumE /= !dE !(eq_sym a). Qed.
Lemma dxx a : d a a = 1 - p.
Proof. by rewrite dE eqxx. Qed.
End def.
End Binary.

Section binary_distribution_prop.

Variables (A : finType) (P Q : fdist A).
Hypothesis card_A : #|A| = 2%nat.

Lemma charac_bdist : {r : prob | P = Binary.d card_A r (Set2.a card_A)}.
Proof.
destruct P as [[pf pf0] pf1].
have /leR2P r01 : 0 <= 1 - pf (Set2.a card_A) <= 1.
  move: (FDist.le1 (FDist.mk pf1) (Set2.a card_A)) => /= H1.
  have {}pf1 : \sum_(a in A) pf a = 1 by rewrite -(eqP pf1); apply eq_bigr.
  move/forallP_leRP : pf0 => /(_ (Set2.a card_A)) => H0.
  split; first lra.
  suff : forall a, a <= 1 -> 0 <= a -> 1 - a <= 1 by apply.
  move=> *; lra.
exists (Prob.mk r01).
apply/fdist_ext => a /=.
rewrite Binary.dE; case: ifPn => [/eqP -> /=|Ha/=]; first by rewrite subRB subRR add0R.
by rewrite -(eqP pf1) /= Set2sumE /= addRC addRK; move/Set2.neq_a_b/eqP : Ha => ->.
Qed.

End binary_distribution_prop.

(* TODO: document *)
Module BinarySupport.
Section prop.
Variables (A : finType) (d : fdist A).
Hypothesis Hd : #|fdist_supp d| = 2%nat.
Definition a := enum_val (cast_ord (esym Hd) ord0).
Definition b := enum_val (cast_ord (esym Hd) (lift ord0 ord0)).
Lemma enumE : enum (fdist_supp d) = a :: b :: [::].
Proof.
apply (@eq_from_nth _ a); first by rewrite -cardE Hd.
case=> [_ |]; first by rewrite [X in _ = X]/= {2}/a (enum_val_nth a).
case=> [_ |i]; last by rewrite -cardE Hd.
by rewrite [X in _ = X]/= {1}/b (enum_val_nth a).
Qed.
Lemma rsumE (f : A -> R) : \sum_(i in fdist_supp d) f i = f a + f b.
Proof.
transitivity (\sum_(i <- enum (fdist_supp d)) f i); last first.
  by rewrite enumE 2!big_cons big_nil addR0.
rewrite big_filter; apply eq_bigl => ?; by rewrite !inE.
Qed.
End prop.
End BinarySupport.

Module D1FDist.
Section def.
Variables (B : finType) (X : fdist B) (b : B).
Definition f : B -> R := [ffun a => if a == b then 0 else X a / (1 - X b)].
Hypothesis Xb1 : X b != 1.
Lemma f0 : forall a, 0 <= f a.
Proof.
move=> a; rewrite /f ffunE.
case: ifPn => [_ |ab]; first exact/leRR.
apply mulR_ge0 => //; exact/invR_ge0/subR_gt0/fdist_lt1.
Qed.
Lemma f1 : \sum_(a in B) f a = 1.
Proof.
rewrite (bigD1 b) //= {1}/f ffunE eqxx add0R.
rewrite (eq_bigr (fun c => X c / (1 - X b))); last first.
  by move=> ? cb; rewrite /f ffunE (negbTE cb).
rewrite -big_distrl /=.
move: (FDist.f1 X); rewrite (bigD1 b) //=.
move=> /esym; rewrite addRC -subR_eq => H.
have ?: 1 - X b != 0 by rewrite subR_eq0' eq_sym.
rewrite -(@eqR_mul2r (1 - X b)); last exact/eqP.
by rewrite mul1R -mulRA mulVR ?mulR1 // H.
Qed.
Definition d := locked (FDist.make f0 f1).
Lemma dE a : d a = if a == b then 0 else X a / (1 - X b).
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End def.
Section prop.
Variables (B : finType) (X : fdist B) (b : B).
Hypothesis Xb1 : X b != 1.
Lemma card_fdist_supp (Xb0 : X b != 0) : #|fdist_supp (d Xb1)| = #|fdist_supp X|.-1.
Proof.
rewrite /fdist_supp (cardsD1 b [set a | X a != 0]) !inE Xb0 add1n /=.
apply eq_card => i; rewrite !inE dE.
case: ifPn => //= ib; first by rewrite eqxx.
apply/idP/idP; first by apply: contra => /eqP ->; rewrite div0R.
apply: contra; rewrite /Rdiv mulR_eq0' => /orP[//|H].
exfalso.
move/negPn/negP : H; apply.
by apply/invR_neq0'; rewrite subR_eq0' eq_sym.
Qed.

Lemma d_eq0 a (Xa0 : X a != 0) : ((d Xb1 a == 0) = (b == a))%bool.
Proof.
rewrite dE; case: ifPn => [/eqP ->|ab]; first by rewrite !eqxx.
apply/idP/idP => [|]; last by rewrite eq_sym (negbTE ab).
rewrite mulR_eq0' => /orP[]; first by rewrite (negbTE Xa0).
by move/invR_eq0'; rewrite subR_eq0' eq_sym (negbTE Xb1).
Qed.

Lemma d_0 a : X a = 0 -> d Xb1 a = 0.
Proof. move=> Xa0; rewrite dE Xa0 div0R; by case: ifP. Qed.

End prop.
End D1FDist.

(* TODO: move? *)
(* about_distributions_of_ordinals.*)

Lemma fdistI0_False (d : {fdist 'I_O}) : False.
Proof. move: (fdist_card_neq0 d); by rewrite card_ord. Qed.

Module I2FDist.
Section def.
Variable (p : prob).
Definition d : {fdist 'I_2} := Binary.d (card_ord 2) p (lift ord0 ord0).
Lemma dE a : d a = if a == ord0 then Prob.p p else p.~.
Proof.
rewrite /d Binary.dE; case: ifPn => [/eqP ->|].
by rewrite eq_sym (negbTE (neq_lift _ _)).
by case: ifPn => //; move: a => -[[//|[|]//]].
Qed.
End def.
Section prop.
Lemma p1 : d 1%:pr = FDist1.d ord0.
Proof.
apply/fdist_ext => /= i; rewrite dE FDist1.dE; case: ifPn => //= _; exact: onem1.
Qed.
Lemma p0 : d 0%:pr = FDist1.d (Ordinal (erefl (1 < 2)%nat)).
Proof.
apply/fdist_ext => /= i; rewrite dE FDist1.dE; case: ifPn => [/eqP ->//|].
case: i => -[//|] [|//] i12 _ /=; by rewrite onem0.
Qed.
End prop.
End I2FDist.

Module AddFDist.
Section def.
Variables (n m : nat) (d1 : {fdist 'I_n}) (d2 : {fdist 'I_m}) (p : prob).
Definition f := [ffun i : 'I_(n + m) =>
  let si := fintype.split i in
  match si with inl a => (p * d1 a) | inr a => p.~ * d2 a end].
Lemma f0 i : 0 <= f i.
Proof. rewrite /f ffunE; case: splitP => a _; exact: mulR_ge0. Qed.
Lemma f1 : \sum_(i < n + m) f i = 1.
Proof.
rewrite -(onemKC p) -{1}(mulR1 p) -(mulR1 p.~).
rewrite -{1}(FDist.f1 d1) -(FDist.f1 d2) big_split_ord /=; congr (_ + _).
- rewrite big_distrr /f /=; apply eq_bigr => i _; rewrite ffunE; case: splitP => [j Hj|k /= Hi].
  + congr (_ * d1 _); apply/val_inj => /=; by rewrite -Hj.
  + move: (ltn_ord i); by rewrite Hi -ltn_subRL subnn ltn0.
- rewrite big_distrr /f /=; apply eq_bigr => i _; rewrite ffunE; case: splitP => [j /= Hi|k /= /eqP].
  + move: (ltn_ord j); by rewrite -Hi -ltn_subRL subnn ltn0.
  + rewrite eqn_add2l => /eqP ik; congr (_ * d2 _); exact/val_inj.
Qed.
Definition d : {fdist 'I_(n + m)} := locked (FDist.make f0 f1).
Lemma dE i : d i =
  match fintype.split i with inl a => p * d1 a | inr a => p.~ * d2 a end.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End def.
End AddFDist.

Module DelFDist.
Section def.
Variables (n : nat) (P : {fdist 'I_n.+1}) (j : 'I_n.+1) (Pj_neq1 : P j != 1).
Let D : {fdist 'I_n.+1} := D1FDist.d Pj_neq1.
Let h (i : 'I_n) := if (i < j)%nat then widen_ord (leqnSn _) i else lift ord0 i.
Lemma f0 i : 0 <= [ffun x => (D \o h) x] i.
Proof. by rewrite /h ffunE /=; case: ifPn. Qed.
Lemma f1 : \sum_(i < n) [ffun x => (D \o h) x] i = 1.
Proof.
rewrite -(FDist.f1 D) /= (bigID (fun i : 'I_n.+1 => (i < j)%nat)) /=.
rewrite (bigID (fun i : 'I_n => (i < j)%nat)) /=; congr (_ + _).
  rewrite (@big_ord_narrow_cond _ _ _ j n.+1 xpredT); first by rewrite ltnW.
  move=> jn; rewrite (@big_ord_narrow_cond _ _ _ j n xpredT); first by rewrite -ltnS.
  move=> jn'; apply eq_bigr => i _; rewrite ffunE; congr (D _).
  rewrite /h /= ltn_ord; exact/val_inj.
rewrite (bigID (pred1 j)) /= [X in _ = X + _](_ : _ = 0) ?add0R; last first.
  rewrite (big_pred1 j).
  by rewrite /D D1FDist.dE eqxx.
  by move=> /= i; rewrite -leqNgt andbC andb_idr // => /eqP ->.
rewrite [in RHS]big_mkcond big_ord_recl.
set X := (X in _ = addR_monoid _ X).
rewrite /= -leqNgt leqn0 eq_sym andbN add0R.
rewrite big_mkcond; apply eq_bigr => i _.
rewrite -2!leqNgt andbC eq_sym -ltn_neqAle ltnS.
case: ifPn => // ji; by rewrite /h ffunE ltnNge ji.
Qed.
Definition d : {fdist 'I_n} := locked (FDist.make f0 f1).
Lemma dE i : d i = D (h i). Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
Definition f (i : 'I_n) := h i.
End def.
End DelFDist.

Module BelastFDist.
Local Open Scope proba_scope.
Section def.
Variables (n : nat) (P : {fdist 'I_n.+1}) (Pmax_neq1 : P ord_max != 1).
Let D : {fdist 'I_n.+1} := D1FDist.d Pmax_neq1.
Definition d : {fdist 'I_n} := locked (DelFDist.d Pmax_neq1).
Lemma dE i : d i = D (widen_ord (leqnSn _) i).
Proof. by rewrite /d; unlock; rewrite DelFDist.dE ltn_ord. Qed.
End def.
End BelastFDist.

Module ConvnFDist.
Section def.
Variables (A : finType) (n : nat) (e : {fdist 'I_n}) (g : 'I_n -> fdist A).
Definition f := [ffun a => \sum_(i < n) e i * g i a].
Lemma f0 a : 0 <= f a.
Proof. by rewrite ffunE; apply: sumR_ge0 => /= i _; apply mulR_ge0. Qed.
Lemma f1 : \sum_(a in A) f a = 1.
Proof.
rewrite /f; evar (h : A -> R); rewrite (eq_bigr h); last first.
  move=> b _; rewrite ffunE /h; reflexivity.
rewrite {}/h exchange_big /= -(FDist.f1 e) /=; apply eq_bigr => i _.
by rewrite -big_distrr /= FDist.f1 mulR1.
Qed.
Definition d : fdist A := locked (FDist.make f0 f1).
Lemma dE a : d a = \sum_(i < n) e i * g i a.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End def.
Section prop.
Variables (A : finType) (n : nat).
Lemma fdist1 (g : 'I_n -> fdist A) a : d (FDist1.d a) g = g a.
Proof.
apply/fdist_ext => a0; rewrite dE (bigD1 a) //= FDist1.dE eqxx mul1R.
by rewrite big1 ?addR0 // => i ia; rewrite FDist1.dE (negbTE ia) mul0R.
Qed.
Lemma cst (e : {fdist 'I_n}) (a : {fdist A}) : d e (fun=> a) = a.
Proof. by apply/fdist_ext => ?; rewrite dE -big_distrl /= FDist.f1 mul1R. Qed.
End prop.
End ConvnFDist.

Definition s_of_pq (p q : prob) : prob := locked (p.~ * q.~).~%:pr.

Notation "[ 's_of' p , q ]" := (s_of_pq p q) (format "[ 's_of'  p ,  q ]") : proba_scope.

Lemma s_of_pqE (p q : prob) : [s_of p, q] = (p.~ * q.~).~ :> R.
Proof. by rewrite /s_of_pq; unlock. Qed.

Lemma s_of_pq_oprob (p q : oprob) : 0 <b [s_of p, q] <b 1.
Proof. rewrite s_of_pqE (_ : (p.~ * q.~).~ = (p.~ * q.~).~%:opr) //=; exact: OProb.O1. Qed.
Canonical oprob_of_s_of_pq (p q : oprob) := Eval hnf in OProb.mk (s_of_pq_oprob p q).

Lemma s_of_p0 (p : prob) : [s_of p, 0%:pr] = p.
Proof. by apply/val_inj; rewrite /= s_of_pqE onem0 mulR1 onemK. Qed.

Lemma s_of_0q (q : prob) : [s_of 0%:pr, q] = q.
Proof. by apply/val_inj; rewrite /= s_of_pqE onem0 mul1R onemK. Qed.

Lemma s_of_p1 (p : prob) : [s_of p, 1%:pr] = 1%:pr.
Proof. by apply/val_inj; rewrite /= s_of_pqE onem1 mulR0 onem0. Qed.

Lemma s_of_1q (q : prob) : [s_of 1%:pr, q] = 1%:pr.
Proof. by apply/val_inj; rewrite /= s_of_pqE onem1 mul0R onem0. Qed.

Lemma s_of_pqE' (p q : prob) : [s_of p, q] = p + p.~ * q :> R.
Proof. rewrite s_of_pqE /= /onem; field. Qed.

Lemma s_of_gt0 p q : p != 0%:pr -> 0 < [s_of p, q].
Proof.
move=> ?; rewrite s_of_pqE';
  apply addR_gt0wl; [exact/prob_gt0 | exact: mulR_ge0].
Qed.

Lemma s_of_gt0_oprob (p : oprob) (q : prob) : 0 < [s_of p, q].
Proof. by apply/s_of_gt0/oprob_neq0. Qed.

Lemma ge_s_of (p q : prob) : p <= [s_of p, q].
Proof. rewrite s_of_pqE' addRC -leR_subl_addr subRR; exact/mulR_ge0. Qed.

Lemma r_of_pq_prob (p q : prob) : 0 <b= p / [s_of p, q] <b= 1.
Proof.
case/boolP : (p == 0%:pr :> prob) => p0.
  rewrite (eqP p0) div0R; apply/andP; split; apply/leRP => //; exact/leRR.
case/boolP : (q == 0%:pr :> prob) => q0.
  rewrite (eqP q0) (s_of_p0 p) divRR //; apply/andP; split; apply/leRP=> //; exact/leRR.
apply/andP; split; apply/leRP.
- apply divR_ge0 => //; exact/s_of_gt0.
- rewrite leR_pdivr_mulr ?mul1R; [exact: ge_s_of | exact: s_of_gt0].
Qed.

Definition r_of_pq (p q : prob) : prob := locked (Prob.mk (r_of_pq_prob p q)).

(* TODO: move up? *)
Notation "[ 'r_of' p , q ]" := (r_of_pq p q)
  (format "[ 'r_of'  p ,  q ]") : proba_scope.

Lemma r_of_pqE (p q : prob) : [r_of p, q] = p / [s_of p, q] :> R.
Proof. by rewrite /r_of_pq; unlock. Qed.

Lemma r_of_pq_oprob (p q : oprob) : 0 <b [r_of p, q] <b 1.
Proof.
rewrite r_of_pqE.
apply/andP; split; apply/ltRP; first by apply divR_gt0.
rewrite ltR_pdivr_mulr ?mul1R; last by apply/(oprob_gt0).
rewrite ltR_neqAle; split; last by apply/ge_s_of.
rewrite s_of_pqE'; apply/eqP/ltR_eqF/ltR_addl.
by apply/oprob_gt0.
Qed.
Canonical oprob_of_r_of_pq (p q : oprob) := Eval hnf in OProb.mk (r_of_pq_oprob p q).

Lemma r_of_p0 (p : prob) : p != 0%:pr -> [r_of p, 0%:pr] = 1%:pr.
Proof. by move=> p0; apply val_inj; rewrite /= r_of_pqE s_of_p0 divRR. Qed.

Lemma r_of_p0_oprob (p : oprob) : [r_of p, 0%:pr] = 1%:pr.
Proof. by apply/r_of_p0/oprob_neq0. Qed.

Lemma r_of_0q (q : prob) : [r_of 0%:pr, q] = 0%:pr.
Proof. by apply/val_inj; rewrite /= r_of_pqE div0R. Qed.

Lemma r_of_p1 (p : prob) : [r_of p, 1%:pr] = p.
Proof. by apply/val_inj; rewrite /= r_of_pqE s_of_p1 divR1. Qed.

Lemma r_of_1q (q : prob) : [r_of 1%:pr, q] = 1%:pr.
Proof. by apply/val_inj; rewrite /= r_of_pqE s_of_1q divR1. Qed.

Lemma p_is_rs (p q : prob) : p = [r_of p, q] * [s_of p, q] :> R.
Proof.
case/boolP : (p == 0%:pr :> prob) => p0; first by rewrite (eqP p0) r_of_0q mul0R.
case/boolP : (q == 0%:pr :> prob) => q0.
  by rewrite (eqP q0) s_of_p0 r_of_p0 // mul1R.
rewrite r_of_pqE /Rdiv -mulRA mulVR ?mulR1 //.
suff : [s_of p, q] != 0 :> R by [].
by rewrite prob_gt0; apply s_of_gt0.
Qed.

Lemma r_of_pq_is_r (p q r s : prob) : r != 0%:pr -> s != 0%:pr ->
  p = r * s :> R -> s.~ = p.~ * q.~ -> [r_of p, q] = r.
Proof.
move=> r0 s0 H1 H2; apply val_inj => /=.
rewrite r_of_pqE eqR_divr_mulr; last by rewrite s_of_pqE -H2 onemK.
rewrite (p_is_rs _ q) /= {1}s_of_pqE -H2 onemK r_of_pqE s_of_pqE.
by rewrite -H2 onemK /Rdiv -mulRA mulVR ?mulR1.
Qed.

Lemma r_of_pq_is_r_oprob (p q : prob) (r s : oprob) :
  p = r * s :> R -> s.~ = p.~ * q.~ -> [r_of p, q] = r.
Proof. apply/r_of_pq_is_r/oprob_neq0/oprob_neq0. Qed.

Lemma p_of_rs_prob (r s : prob) : 0 <b= r * s <b= 1.
Proof.
move: r s => -[] r /andP [] /leRP r0 /leRP r1 -[] s /= /andP [] /leRP s0 /leRP s1.
apply/andP; split; apply/leRP; [exact/mulR_ge0 | rewrite -(mulR1 1); exact: leR_pmul].
Qed.

Definition p_of_rs (r s : prob) : prob := locked (Prob.mk (p_of_rs_prob r s)).

(* TODO: move up? *)
Notation "[ 'p_of' r , s ]" := (p_of_rs r s)
  (format "[ 'p_of'  r ,  s ]") : proba_scope.

Lemma p_of_rsE (r s : prob) : [p_of r, s] = r * s :> R.
Proof. by rewrite /p_of_rs; unlock. Qed.

Lemma p_of_rs_oprob (r s : oprob) : 0 <b [p_of r, s] <b 1.
Proof. by rewrite p_of_rsE; apply/OProb.O1. Qed.
Canonical oprob_of_p_of_rs (r s : oprob) := Eval hnf in OProb.mk (p_of_rs_oprob r s).

Lemma p_of_r1 (r : prob) : [p_of r, 1%:pr] = r.
Proof. by apply val_inj; rewrite /= p_of_rsE mulR1. Qed.

Lemma p_of_1s (s : prob) : [p_of 1%:pr, s] = s.
Proof. by apply val_inj; rewrite /= p_of_rsE mul1R. Qed.

Lemma p_of_r0 (r : prob) : [p_of r, 0%:pr] = 0%:pr.
Proof. by apply/val_inj; rewrite /= p_of_rsE mulR0. Qed.

Lemma p_of_0s (s : prob) : [p_of 0%:pr, s] = 0%:pr.
Proof. by apply/val_inj; rewrite /= p_of_rsE mul0R. Qed.

Lemma p_of_rsC (r s : prob) : [p_of r, s] = [p_of s, r].
Proof. by apply/val_inj; rewrite /= !p_of_rsE mulRC. Qed.

Lemma p_of_neq1 (p q : prob) : 0 < p < 1 -> [p_of q, p] != 1%:pr.
Proof.
case=> p0 p1; apply/eqP => pq1; move: (p1).
rewrite [X in _ < X -> _](_ : _ = Prob.p 1%:pr) //.
rewrite -pq1 p_of_rsE -ltR_pdivr_mulr // divRR ?prob_gt0 //.
by rewrite ltRNge; exact.
Qed.

Lemma p_of_rs1 (r s : prob) :
  ([p_of r, s] == 1%:pr :> prob) = ((r == 1%:pr) && (s == 1%:pr)).
Proof.
apply/idP/idP; last by case/andP => /eqP -> /eqP ->; rewrite p_of_r1.
move/eqP/(congr1 Prob.p); rewrite /= p_of_rsE => /eqP.
apply contraLR => /nandP.
wlog : r s / r != 1%:pr by move=> H [|] ?; [|rewrite mulRC]; rewrite H //; left.
move=> r1 _.
have [/eqP->|/prob_gt0/ltR_neqAle[/nesym r0 _]] := boolP (r == 0%:pr :> prob).
  by rewrite mul0R eq_sym; apply/eqP.
apply/eqP => /(@eqR_mul2r (/ r)).
move/(_ (invR_neq0 _ r0)).
rewrite mulRAC mulRV ?mul1R; last exact/eqP.
move/eqP/prob_gt0 in r0.
move=> srV; move: (prob_le1 s); rewrite {}srV.
rewrite invR_le1 // => r_le1.
move: (prob_le1 r) => le_r1.
by move/eqP : r1; apply; apply/val_inj; apply eqR_le.
Qed.

Lemma p_of_rs1P r s : reflect (r = 1%:pr /\ s = 1%:pr) ([p_of r, s] == 1%:pr).
Proof.
move: (p_of_rs1 r s) ->.
apply: (iffP idP);
  [by case/andP => /eqP -> /eqP -> | by case => -> ->; rewrite eqxx].
Qed.

Lemma q_of_rs_prob (r s : prob) : 0 <b= (r.~ * s) / [p_of r, s].~ <b= 1.
Proof.
case/boolP : (r == 1%:pr :> prob) => r1.
  rewrite (eqP r1) onem1 mul0R div0R; apply/andP; split; apply/leRP => //; exact/leRR.
case/boolP : (s == 1%:pr :> prob) => s1.
  rewrite (eqP s1) mulR1 p_of_r1 divRR ?onem_neq0 //; apply/andP; split; apply/leRP => //; exact/leRR.
apply/andP; split; apply/leRP.
  apply/divR_ge0; first exact/mulR_ge0.
    apply/onem_gt0; rewrite p_of_rsE -(mulR1 1); apply/ltR_pmul => //;
      by [rewrite -prob_lt1 | rewrite -prob_lt1].
rewrite leR_pdivr_mulr ?mul1R.
  by rewrite p_of_rsE {2}/onem leR_subr_addr -mulRDl addRC onemKC mul1R.
apply onem_gt0; rewrite p_of_rsE -(mulR1 1); apply/ltR_pmul => //;
  by [rewrite -prob_lt1 | rewrite -prob_lt1].
Qed.

Definition q_of_rs (r s : prob) : prob := locked (Prob.mk (q_of_rs_prob r s)).

(* TODO: move up? *)
Notation "[ 'q_of' r , s ]" := (q_of_rs r s)
  (format "[ 'q_of'  r ,  s ]") : proba_scope.

Lemma q_of_rsE (r s : prob) : [q_of r, s] = (r.~ * s) / [p_of r, s].~ :> R.
Proof. by rewrite /q_of_rs; unlock. Qed.

Lemma q_of_rs_oprob (r s : oprob) : 0 <b [q_of r, s] <b 1.
Proof.
rewrite q_of_rsE p_of_rsE.
have->: r.~ * s / (r * s).~ = (s.~ / (r * s).~).~
  by rewrite /onem; field; move/eqP: (oprob_neq0 ((r * s).~)%:opr).
apply onem_oprob.
apply/andP; split; apply/ltRP.
- by apply/divR_gt0/oprob_gt0/oprob_gt0.
- apply/(@ltR_pmul2r (r * s).~); first by apply/oprob_gt0.
  rewrite divRE mulRAC -mulRA mulRV ?oprob_neq0 // mulR1 mul1R.
  rewrite -onem_lt.
  by rewrite -{2}(mul1R s) ltR_pmul2r; [apply/oprob_lt1 | apply/oprob_gt0].
Qed.
Canonical oprob_of_q_of_rs (r s : oprob) := Eval hnf in OProb.mk (q_of_rs_oprob r s).

Lemma q_of_r0 (r : prob) : [q_of r, 0%:pr] = 0%:pr.
Proof. by apply/val_inj => /=; rewrite q_of_rsE mulR0 div0R. Qed.

Lemma q_of_r1 (r : prob) : r != 1%:pr -> [q_of r, 1%:pr] = 1%:pr.
Proof.
move=> r1.
by apply/val_inj => /=; rewrite q_of_rsE /= mulR1 p_of_r1 divRR // onem_neq0.
Qed.

Lemma q_of_1s (s : prob) : [q_of 1%:pr, s] = 0%:pr.
Proof. by apply/val_inj => /=; rewrite q_of_rsE onem1 mul0R div0R. Qed.

Lemma pq_is_rs (p q : prob) : p.~ * q = [r_of p, q].~ * [s_of p, q].
Proof.
case/boolP : (p == 0%:pr :> prob) => p0.
  by rewrite (eqP p0) onem0 mul1R r_of_0q onem0 mul1R s_of_0q.
rewrite r_of_pqE [in RHS]mulRBl mul1R.
rewrite /Rdiv -mulRA mulVR ?mulR1; last first.
  rewrite prob_gt0; exact/s_of_gt0.
by rewrite s_of_pqE' addRC addRK.
Qed.

Lemma s_of_pqK r s : [p_of r, s] != 1%:pr ->
  [s_of [p_of r, s], [q_of r, s]] = s.
Proof.
move=> H.
apply/val_inj; rewrite /= s_of_pqE p_of_rsE q_of_rsE p_of_rsE /=.
rewrite /onem; field.
rewrite subR_eq0; apply/eqP; apply: contra H => /eqP rs1.
by apply/eqP/val_inj; rewrite /= p_of_rsE.
Qed.

Lemma s_of_pqK_oprob (r s : oprob) : [s_of [p_of r, s], [q_of r, s]] = s.
Proof. apply/s_of_pqK/oprob_neq1. Qed.

Lemma r_of_pqK (r s : prob) : [p_of r, s] != 1%:pr -> s != 0%:pr ->
  [r_of [p_of r, s], [q_of r, s]] = r.
Proof.
move=> H1 s0; apply/val_inj => /=.
rewrite !(r_of_pqE,s_of_pqE,q_of_rsE,p_of_rsE) /onem; field.
split; last first.
  by rewrite 2!subRB subRR add0R mulRBl mul1R addRC subRK; exact/eqP.
rewrite subR_eq0 => /esym.
apply/eqP; apply: contra H1 => /eqP H1.
by apply/eqP/val_inj; rewrite /= p_of_rsE.
Qed.

Lemma r_of_pqK_oprob (r s : oprob) : [r_of [p_of r, s], [q_of r, s]] = r.
Proof. apply/r_of_pqK/oprob_neq0/oprob_neq1. Qed.

Module ConvFDist.
Section def.
Variables (A : finType) (p : prob) (d1 d2 : fdist A).
Definition d : {fdist A} := locked
  (ConvnFDist.d (I2FDist.d p) (fun i => if i == ord0 then d1 else d2)).
Lemma dE a : d a = p * d1 a + p.~ * d2 a.
Proof.
rewrite /d; unlock => /=.
by rewrite ConvnFDist.dE !big_ord_recl big_ord0 /= addR0 !I2FDist.dE.
Qed.
End def.
Section prop.
Variables (A : finType).
Implicit Types a b c : fdist A.

Local Notation "x <| p |> y" := (d p x y).

Lemma d1 a b : a <| 1%:pr |> b = a.
Proof. apply/fdist_ext => a0; by rewrite dE /= onem1 mul1R mul0R addR0. Qed.

Lemma skewed_commute p a b : a <| p |> b = b <| p.~%:pr |> a.
Proof. apply/fdist_ext => a0 /=; by rewrite 2!dE onemK addRC. Qed.

Lemma idempotent p a : a <| p |> a = a.
Proof. apply/fdist_ext => a0; by rewrite dE mulRBl mul1R addRCA addRN addR0. Qed.

Lemma quasi_assoc p q a b c :
  a <| p |> (b <| q |> c) = (a <| [r_of p, q] |> b) <| [s_of p, q] |> c.
Proof.
apply/fdist_ext => a0 /=; rewrite 4!dE /=.
set r := r_of_pq p q.  set s := s_of_pq p q.
transitivity (p * a a0 + p.~ * q * b a0 + p.~ * q.~ * c a0); first lra.
transitivity (r * s * a a0 + r.~ * s * b a0 + s.~ * c a0); last first.
  by rewrite 2!(mulRC _ s) -2!mulRA -mulRDr.
rewrite s_of_pqE onemK; congr (_ + _).
rewrite (_ : (p.~ * q.~).~ = [s_of p, q]); last by rewrite s_of_pqE.
by rewrite -pq_is_rs -p_is_rs.
Qed.

Lemma bind_left_distr (B : finType) p a b (f : A -> fdist B) :
  FDistBind.d (a <| p |> b) f = FDistBind.d a f <| p |> FDistBind.d b f.
Proof.
apply/fdist_ext => a0 /=; rewrite !(FDistBind.dE,dE) /=.
rewrite 2!big_distrr /= -big_split /=; apply/eq_bigr => a1 _.
by rewrite dE mulRDl !mulRA.
Qed.

End prop.
End ConvFDist.

Module PermFDist.
Section def.
Variables (n : nat) (P : {fdist 'I_n}) (s : 'S_n).
Definition f := [ffun i : 'I_n => P (s i)].
Lemma f0 (i : 'I_n) : 0 <= f i. Proof. by rewrite ffunE. Qed.
Lemma f1 : \sum_(i < n) f i = 1.
Proof.
transitivity (\sum_(i <- [tuple (s^-1)%g i | i < n]) f i).
  apply/perm_big/tuple_permP; exists s.
  destruct n; first by move: (fdistI0_False P).
  rewrite /index_enum -enumT; apply/(@eq_from_nth _ ord0).
    by rewrite size_map size_tuple -enumT size_enum_ord.
  move=> i; rewrite size_enum_ord => ni /=.
  rewrite (nth_map ord0) ?size_enum_ord //= tnth_map /=.
  apply (@perm_inj _ s); by rewrite permKV /= tnth_ord_tuple.
rewrite -(FDist.f1 P) /= big_map; apply congr_big => //.
  by rewrite /index_enum -enumT.
move=> i _; by rewrite /f ffunE permKV.
Qed.
Definition d : {fdist 'I_n} := locked (FDist.make f0 f1).
Lemma dE i : d i = P (s i).
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
End def.
Section prop.
Lemma dE1 (n : nat) (P : {fdist 'I_n}) : d P 1%g = P.
Proof. apply/fdist_ext => /= i; by rewrite dE perm1. Qed.
Lemma mul (n : nat) (P : {fdist 'I_n}) (s s' : 'S_n) : d (d P s) s' = d P (s' * s).
Proof. by apply/fdist_ext => /= i; rewrite !dE permM. Qed.
Lemma tperm (n : nat) (a b : 'I_n) : d (FDist1.d a) (tperm a b) = FDist1.d b.
Proof.
apply/fdist_ext => /= x; rewrite dE !FDist1.dE permE /=.
case: ifPn => [/eqP ->|xa]; first by rewrite eq_sym.
case: ifPn; by [rewrite eqxx | move=> _; rewrite (negbTE xa)].
Qed.
Lemma d1 (n : nat) (a : 'I_n) (s : 'S_n) : d (FDist1.d a) s = FDist1.d (s^-1 a)%g.
Proof.
apply/fdist_ext => /= i; rewrite dE !FDist1.dE; congr (INR (nat_of_bool _)).
by apply/eqP/eqP => [<-|->]; rewrite ?permK // ?permKV.
Qed.
End prop.
End PermFDist.

Module Bivar.
Section def.
Variables (A B : finType) (P : {fdist A * B}).

Definition fst : fdist A := FDistMap.d fst P.

Lemma fstE a : fst a = \sum_(i in B) P (a, i).
Proof.
by rewrite /fst FDistMap.dE /= -(pair_big_fst _ _ (pred1 a)) //= ?big_pred1_eq.
Qed.

Lemma dom_by_fst a b : fst a = 0 -> P (a, b) = 0.
Proof. rewrite fstE => /psumR_eq0P -> // ? _; exact: fdist_ge0. Qed.

Lemma dom_by_fstN a b : P (a, b) != 0 -> fst a != 0.
Proof. by apply: contra => /eqP /dom_by_fst ->. Qed.

Definition snd : fdist B := FDistMap.d snd P.

Lemma sndE b : snd b = \sum_(i in A) P (i, b).
Proof.
rewrite /snd FDistMap.dE -(pair_big_snd _ _ (pred1 b)) //=.
apply eq_bigr => a ?; by rewrite big_pred1_eq.
Qed.

Lemma dom_by_snd a b : snd b = 0 -> P (a, b) = 0.
Proof. rewrite sndE => /psumR_eq0P -> // ? _; exact: fdist_ge0. Qed.

Lemma dom_by_sndN a b : P (a, b) != 0 -> snd b != 0.
Proof. by apply: contra => /eqP /dom_by_snd ->. Qed.

End def.
End Bivar.

(* multivariate (joint) distribution *)
Module Multivar.
Section prod_of_rV.
Variables (A : finType) (n : nat) (P : {fdist 'rV[A]_n.+1}).

Let f (v : 'rV[A]_n.+1) : A * 'rV[A]_n := (v ord0 ord0, rbehead v).
Let inj_f : injective f.
Proof.
move=> a b -[H1 H2]; rewrite -(row_mx_rbehead a) -(row_mx_rbehead b).
by rewrite {}H2; congr (@row_mx _ 1 1 n _ _); apply/rowP => i; rewrite !mxE.
Qed.
Definition to_bivar : {fdist A * 'rV[A]_n} := FDistMap.d f P.
Lemma to_bivarE a : to_bivar a = P (row_mx (\row_(i < 1) a.1) a.2).
Proof.
case: a => x y; rewrite /to_bivar FDistMap.dE /=.
rewrite (_ : (x, y) = f (row_mx (\row_(i < 1) x) y)); last first.
  by rewrite /f row_mx_row_ord0 rbehead_row_mx.
by rewrite (big_pred1_inj inj_f).
Qed.

Definition head_of := Bivar.fst to_bivar.
Definition tail_of := Bivar.snd to_bivar.

Let g (v : 'rV[A]_n.+1) : 'rV[A]_n * A := (rbelast v, rlast v).
Let inj_g : injective g.
Proof.
by move=> a b -[H1 H2]; rewrite -(row_mx_rbelast a) -(row_mx_rbelast b) H1 H2.
Qed.
Definition belast_last : {fdist 'rV[A]_n * A} := FDistMap.d g P.
Lemma belast_lastE a : belast_last a =
  P (castmx (erefl, addn1 n) (row_mx a.1 (\row_(i < 1) a.2))).
Proof.
case: a => x y; rewrite /belast_last FDistMap.dE /=.
rewrite (_ : (x, y) = g (castmx (erefl 1%nat, addn1 n) (row_mx x (\row__ y)))); last first.
  by rewrite /g rbelast_row_mx row_mx_row_ord_max.
by rewrite (big_pred1_inj inj_g).
Qed.

End prod_of_rV.

Section rV_of_prod.

Local Open Scope vec_ext_scope.

Variables (A : finType) (n : nat) (P : {fdist A * 'rV[A]_n}).

Let f (x : A * 'rV[A]_n) : 'rV[A]_n.+1 := row_mx (\row_(_ < 1) x.1) x.2.
Lemma inj_f : injective f.
Proof.
move=> -[x1 x2] -[y1 y2]; rewrite /f /= => H.
move: (H) => /(congr1 (@lsubmx A 1 1 n)); rewrite 2!row_mxKl => /rowP/(_ ord0).
rewrite !mxE => ->; congr (_, _).
by move: H => /(congr1 (@rsubmx A 1 1 n)); rewrite 2!row_mxKr.
Qed.
Definition from_bivar : {fdist 'rV[A]_n.+1} := FDistMap.d f P.

Lemma from_bivarE a : from_bivar a = P (a ``_ ord0, rbehead a).
Proof.
rewrite /from_bivar FDistMap.dE /=.
rewrite {1}(_ : a = f (a ``_ ord0, rbehead a)); last first.
  by rewrite /f /= row_mx_rbehead.
by rewrite (big_pred1_inj inj_f).
Qed.

End rV_of_prod.

Lemma from_bivarK (A : finType) n : cancel (@from_bivar A n) (@to_bivar A n).
Proof.
move=> P; apply/fdist_ext => /= -[a b].
by rewrite to_bivarE /= from_bivarE /= row_mx_row_ord0 rbehead_row_mx.
Qed.

Lemma to_bivarK (A : finType) n : cancel (@to_bivar A n) (@from_bivar A n).
Proof.
move=> P; by apply/fdist_ext => v; rewrite from_bivarE to_bivarE row_mx_rbehead.
Qed.

End Multivar.

Module ProdFDist.
Section def.
Variables (A B : finType) (P : fdist A) (Q : A -> fdist B) (*TODO: sto mat?*).
Definition f := [ffun ab => P ab.1 * Q ab.1 ab.2].
Lemma f0 ab : 0 <= f ab. Proof. by rewrite ffunE; apply/mulR_ge0. Qed.
Lemma f1 : \sum_(ab in {: A * B}) f ab = 1.
Proof.
rewrite /f; evar (h : A * B -> R); rewrite (eq_bigr h); last first.
  move=> b _; rewrite ffunE /h; reflexivity.
rewrite {}/h -(pair_bigA _ (fun i j => P i * Q i j)) /= -(FDist.f1 P).
apply eq_bigr => a _; by rewrite -big_distrr FDist.f1 /= mulR1.
Qed.
Definition d := locked (FDist.make f0 f1).
Lemma dE ab : d ab = P ab.1 * Q ab.1 ab.2.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.
Lemma fst : Bivar.fst d = P.
Proof.
apply/fdist_ext=> a; rewrite Bivar.fstE (eq_bigr _ (fun b _ => dE (a,b))) /=.
by rewrite -big_distrr FDist.f1 /= mulR1.
Qed.
End def.
Section prop.
Variables (A B : finType) (Q : A -> fdist B).
Lemma fst_convex p (a b : fdist A) : Bivar.fst (d (ConvFDist.d p a b) Q) =
  ConvFDist.d p (Bivar.fst (d a Q)) (Bivar.fst (d b Q)).
Proof. by rewrite !fst. Qed.
Lemma snd_convex p (a b : fdist A) : Bivar.snd (d (ConvFDist.d p a b) Q) =
  ConvFDist.d p (Bivar.snd (d a Q)) (Bivar.snd (d b Q)).
Proof.
apply/fdist_ext => b0.
rewrite Bivar.sndE ConvFDist.dE !Bivar.sndE 2!big_distrr /=.
rewrite -big_split; apply eq_bigr => a0 _; rewrite !dE ConvFDist.dE /=; field.
Qed.
End prop.
End ProdFDist.

Notation "P1 `x P2" := (ProdFDist.d P1 (fun _ => P2)) : proba_scope.

Section prod_dominates_joint.
Variables (A B : finType) (P : {fdist A * B}).
Let P1 := Bivar.fst P. Let P2 := Bivar.snd P.

Local Open Scope reals_ext_scope.
Lemma Prod_dominates_Joint : P `<< P1 `x P2.
Proof.
apply/dominatesP => -[a b].
rewrite ProdFDist.dE /= mulR_eq0 => -[P1a|P2b];
  by [rewrite Bivar.dom_by_fst | rewrite Bivar.dom_by_snd].
Qed.
End prod_dominates_joint.

Lemma ProdFDistfst A B (P1 : fdist A) (P2 : fdist B) : Bivar.fst (P1 `x P2) = P1.
Proof.
apply/fdist_ext => b; rewrite Bivar.fstE.
under eq_bigr do rewrite ProdFDist.dE.
by rewrite /= -big_distrr /= FDist.f1 mulR1.
Qed.

Lemma ProdFDistsnd A B (P1 : fdist A) (P2 : fdist B) : Bivar.snd (P1 `x P2) = P2.
Proof.
apply/fdist_ext => b; rewrite Bivar.sndE.
under eq_bigr do rewrite ProdFDist.dE.
by rewrite /= -big_distrl /= FDist.f1 mul1R.
Qed.

Module TupleFDist.
Local Open Scope vec_ext_scope.
Section def.
Variables (A : finType) (P : fdist A) (n : nat).

Definition f := [ffun t : 'rV[A]_n => \prod_(i < n) P t ``_ i].

Lemma f0 t : 0 <= f t.
Proof. by rewrite ffunE; apply prodR_ge0. Qed.

Lemma f1 : \sum_(t in 'rV_n) f t = 1.
Proof.
pose P' := fun (a : 'I_n) b => P b.
suff : \sum_(g : {ffun 'I_n -> A }) \prod_(i < n) P' i (g i) = 1.
Local Open Scope ring_scope.
  rewrite (reindex_onto (fun j : 'rV[A]_n => finfun (fun x => j ``_ x))
                        (fun i => \row_(j < n) i j)) /=.
Local Close Scope ring_scope.
  - move=> H; rewrite /f -H {H}.
    apply eq_big => t /=.
    + by apply/esym/eqP/rowP => i; rewrite mxE ffunE.
    + move=> _; rewrite ffunE; apply eq_bigr => i _ /=; by rewrite ffunE.
  move=> g _; apply/ffunP => i; by rewrite ffunE mxE.
rewrite -bigA_distr_bigA /= /P'.
rewrite [RHS](_ : _ = \prod_(i < n) 1); last by rewrite big1.
apply eq_bigr => i _; exact: FDist.f1.
Qed.

Definition d : {fdist 'rV[A]_n} := locked (FDist.make f0 f1).

Lemma dE t : d t = \prod_(i < n) P t ``_ i.
Proof. by rewrite /d; unlock; rewrite ffunE. Qed.

End def.
Local Notation "P `^ n" := (d P n).
Section prop.
Variable A : finType.

Lemma zero (x : 'rV[A]_0) P : P `^ 0 x = 1.
Proof. by rewrite dE big_ord0. Qed.

Lemma S n (x : 'rV[A]_n.+1) P : P `^ n.+1 x = P (x ``_ ord0) * P `^ n (rbehead x).
Proof.
rewrite 2!TupleFDist.dE big_ord_recl; congr (_ * _).
apply eq_bigr => i _; by rewrite /rbehead mxE.
Qed.

Lemma one (a : 'rV[A]_1) P : (P `^ 1) a = P (a ``_ ord0).
Proof. by rewrite S zero mulR1. Qed.

Lemma to_bivar n (P : fdist A) : Multivar.to_bivar P `^ n.+1 = P `x P `^ n.
Proof.
apply/fdist_ext => /= -[a b].
rewrite Multivar.to_bivarE /= S ProdFDist.dE; congr (P _ * P `^ n _) => /=.
by rewrite row_mx_row_ord0.
by rewrite rbehead_row_mx.
Qed.

End prop.

(* The tuple distribution as a joint distribution *)
Section joint_tuple_fdist.

Variables (A : finType) (P : fdist A) (n : nat).

Lemma head_of : Multivar.head_of (P `^ n.+1) = P.
Proof.
apply/fdist_ext => a; rewrite /Multivar.head_of Bivar.fstE /=.
evar (f : 'rV[A]_n -> R); rewrite (eq_bigr f); last first.
  move=> v _; rewrite Multivar.to_bivarE /= TupleFDist.S.
  rewrite row_mx_row_ord0 rbehead_row_mx /f; reflexivity.
by rewrite {}/f -big_distrr /= FDist.f1 mulR1.
Qed.

Lemma tail_of : Multivar.tail_of (P `^ n.+1) = P `^ n.
Proof.
apply/fdist_ext => a; rewrite /Multivar.tail_of Bivar.sndE /=.
evar (f : A -> R); rewrite (eq_bigr f); last first.
  move=> v _; rewrite Multivar.to_bivarE /= TupleFDist.S.
  rewrite row_mx_row_ord0 rbehead_row_mx /f; reflexivity.
by rewrite {}/f -big_distrl /= FDist.f1 mul1R.
Qed.

End joint_tuple_fdist.
End TupleFDist.

Notation "P `^ n" := (TupleFDist.d P n) : proba_scope.

Local Open Scope ring_scope.
Local Open Scope vec_ext_scope.

Lemma rsum_rmul_rV_pmf_tnth A n k (P : fdist A) :
  (\sum_(t : 'rV[ 'rV[A]_n]_k) \prod_(m < k) (P `^ n) t ``_ m = 1)%R.
Proof.
transitivity (\sum_(j : {ffun 'I_k -> 'rV[A]_n}) \prod_(m : 'I_k) P `^ _ (j m))%R.
  rewrite (reindex_onto (fun p : 'rV_k => [ffun i => p ``_ i])
    (fun x : {ffun 'I_k -> 'rV_n} => \row_(i < k) x i)) //=; last first.
    move=> f _; apply/ffunP => /= k0; by rewrite ffunE mxE.
  apply eq_big => //.
  - move=> v /=; by apply/esym/eqP/rowP => i; rewrite mxE ffunE.
  - move=> i _; apply eq_bigr => j _; by rewrite ffunE.
rewrite -(bigA_distr_bigA (fun m => P `^ _)) /= big_const.
by rewrite iter_mulR FDist.f1 exp1R.
Qed.

(*Section tuple_prod_cast.

Variables A B : finType.
Variable n : nat.
Variable P : {dist 'rV[A * B]_n}.

(*
Definition dist_tuple_prod_cast : dist [finType of n.-tuple A * n.-tuple B].
apply makeDist with (fun xy => P (prod_tuple xy)).
move=> a; by apply Rle0f.
rewrite -(pmf1 P).
rewrite (reindex_onto (fun x => tuple_prod x) (fun y => prod_tuple y)); last first.
  move=> i _; by rewrite prod_tupleK.
rewrite /=.
apply eq_big => /= i.
- by rewrite inE tuple_prodK eqxx.
- move=> _; by rewrite tuple_prodK.
Defined.
*)

End tuple_prod_cast.*)

Section wolfowitz_counting.

Variables (C : finType) (P : fdist C) (k : nat) (s : {set 'rV[C]_k}).

Lemma wolfowitz a b A B : 0 < A -> 0 < B ->
  a <= \sum_(x in s) P `^ k x <= b ->
  (forall x : 'rV_k, x \in s -> A <= P `^ k x <= B) ->
  a / B <= INR #| s | <= b / A.
Proof.
move=> A0 B0 [Ha Hb] H.
have HB : \sum_(x in s) P `^ _ x <= INR #|s| * B.
  have HB : \sum_(x in s | predT s ) P `^ _ x <= INR #|s| * B.
    apply (@leR_trans (\sum_(x in s | predT s) [fun _ => B] x)).
      apply leR_sumR_support => /= i iA _; by apply H.
    rewrite -big_filter /= big_const_seq /= iter_addR /=.
    apply leR_wpmul2r; first lra.
    apply Req_le.
    have [/= l el [ul ls] [pl sl]] := big_enumP _.
    rewrite count_predT sl; congr (_%:R)%R.
    by apply: eq_card => /= v; rewrite inE andbT.
  apply/(leR_trans _ HB)/Req_le/eq_bigl => i; by rewrite andbC.
have HA : INR #|s| * A <= \sum_(x in s) P `^ _ x.
  have HA : INR #|s| * A <= \sum_(x in s | predT s) P `^ _ x.
    apply (@leR_trans (\sum_(x in s | predT s) [fun _ => A] x)); last first.
      apply leR_sumR_support => i Hi _; by case: (H i Hi).
    rewrite -big_filter /= big_const_seq /= iter_addR /=.
    apply leR_wpmul2r; first lra.
    apply Req_le.
    have [/= l el [ul ls] [pl sl]] := big_enumP _.
    rewrite count_predT sl; congr (_%:R)%R.
    by apply: eq_card => /= v; rewrite inE andbT.
  by apply/(leR_trans HA)/Req_le/eq_bigl => i; rewrite andbC.
split.
- by rewrite leR_pdivr_mulr //; move/leR_trans : Ha; exact.
- by rewrite leR_pdivl_mulr //; exact: (leR_trans HA).
Qed.

End wolfowitz_counting.

Local Close Scope ring_scope.
