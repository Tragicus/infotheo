From mathcomp Require Import all_ssreflect.
From mathcomp Require Import finfun bigop.
From mathcomp Require Import boolp.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Reserved Notation "m >>= f" (at level 50).
Reserved Notation "f =<< m" (at level 50).
Reserved Notation "'do' x <- m ; e"
  (at level 60, x ident, m at level 200, e at level 60).
Reserved Notation "'do' x : T <- m ; e"
  (at level 60, x ident, m at level 200, e at level 60).
Reserved Notation "m >=> n" (at level 50).
Reserved Notation "n <=< m" (at level 50).
Reserved Notation "f ~> g" (at level 51).
Reserved Notation "f \O g" (at level 50, format "f  \O  g").
Reserved Notation "f \v g" (at level 50, format "'[v' f '/' \v  g ']'", left associativity).
Reserved Notation "f \h g" (at level 50, format "f  \h  g").
Reserved Notation "f \\h g" (at level 50, format "f  \\h  g").
Reserved Notation "F -| G" (at level 51, G at next level).


Section funcomp_lemmas.
Lemma funcompA {A B C D} (f : C -> D) (g : B -> C) (h : A -> B) : f \o (g \o h) = (f \o g) \o h.
Proof. by []. Qed.

Lemma funcompfid A B (f : A -> B) : f \o id = f. Proof. by []. Qed.

Lemma funcompidf A B (f : A -> B) : id \o f = f. Proof. by []. Qed.

Lemma funcompE A B C (g : B -> C) (f : A -> B) a : (g \o f) a = g (f a).
Proof. by []. Qed.
End funcomp_lemmas.

(*** category ***)
(* Our `category' is always concrete; morphisms are just functions. *)
Module Category.
Record class_of (T : Type) : Type := Class {
  obj : T -> Type ; (* T and obj is like a ``universe a la Tarski'' *)
  hom : forall A B, (obj A -> obj B) -> Prop ; (* subset of morphisms *)
(*  _ : injective obj ; (* NB: do we need this? *)*)
  _ : forall (A : T), hom (A:=A) (B:=A) id ; (* id is in hom *)
  _ : forall (A B C : T) (f : obj A -> obj B) (g : obj B -> obj C),
      hom f -> hom g -> hom (g \o f) ; (* hom is closed under composition *)
}.
Structure t : Type := Pack { car : Type ; class : class_of car }.
Module Exports.
Notation category := t.
Coercion car : category >-> Sortclass.
Definition El (C : t) : C -> Type :=
  let: Pack _ (Class x _ _ _) := C in x.
End Exports.
End Category.
Export Category.Exports.

Module Hom.
Section ClassDef.
Variables (C : category) (U V : C).
Local Notation U' := (El U).
Local Notation V' := (El V).
Let hom (X : category) : forall (A B : X), (El A -> El B) -> Prop :=
  let: Category.Pack _ (Category.Class _ x _ _) := X in x.
Definition axiom (f : U' -> V') := hom f.
Structure map (phUV : phant (U' -> V')) := Pack {apply; _ : axiom apply}.
Local Coercion apply : map >-> Funclass.
Variables (phUV : phant (U' -> V')) (f g : U' -> V') (cF : map phUV).
Definition class := let: Pack _ c as cF' := cF return axiom cF' in c.
Definition clone fA of phant_id g (apply cF) & phant_id fA class :=
  @Pack phUV f fA.
End ClassDef.
Definition map' := map.
Module Exports.
Notation hom f := (axiom f).
Coercion apply : map >-> Funclass.
Add Printing Coercion apply.
Notation "[ 'fun' 'of' f ]" := (apply f)
  (at level 0, format "[ 'fun'  'of'  f ]") : category_scope.
Notation Hom fA := (Pack (Phant _) fA).
Notation "{ 'hom' U , V }" := (map (Phant (El U -> El V)))
  (at level 0, format "{ 'hom'  U ,  V }") : category_scope.
Arguments map' : simpl never.
Notation "{ 'hom' C ; U , V }" := (@map' C U V (Phant (El U -> El V)))
  (at level 0, format "{ 'hom'  C ;  U ,  V }") : category_scope.
Notation "[ 'hom' 'of' f 'as' g ]" := (@clone _ _ _ _ f g _ _ idfun id)
  (at level 0, format "[ 'hom'  'of'  f  'as'  g ]") : category_scope.
Notation "[ 'hom' 'of' f ]" := (@clone _ _ _ _ f f _ _ id id)
  (at level 0, format "[ 'hom'  'of'  f ]") : category_scope.
End Exports.
End Hom.
Export Hom.Exports.

Open Scope category_scope.

Section category_interface.
Variable C : category.

Lemma category_idfun_proof : forall (a : C), hom (idfun : El a -> El a).
Proof. by case: C => [? []]. Qed.
Canonical idfun_hom a := Hom (locked (category_idfun_proof a)).
Lemma idfun_homE a : idfun_hom a = Hom (category_idfun_proof a).
Proof. by rewrite /idfun_hom; unlock. Qed.
Lemma category_funcomp_proof : forall (a b c : C) (f : {hom b,c}) (g : {hom a,b}),
    hom (f \o g).
Proof.
case: C => [car [el hom ? hom_comp]] a b c f g.
by apply/hom_comp;case:f;case:g.
Qed.
Canonical funcomp_hom (a b c : C) (f : {hom b, c}) (g : {hom a, b}) := Hom (locked (category_funcomp_proof f g)).
Lemma funcomp_homE' a b c f g : @funcomp_hom a b c f g = Hom (@category_funcomp_proof a b c f g).
Proof. by rewrite /funcomp_hom; unlock. Qed.
End category_interface.

Section category_lemmas.
Variable C : category.

Lemma homfunK (a b : C) (f : {hom a,b}) : [hom of [fun of f]] = f.
Proof. by case:f. Qed.

Lemma funcomp_homE (a b c:C) (g:{hom b,c}) (f:{hom a,b}) : funcomp_hom g f = [hom of g \o f].
Proof. reflexivity. Qed.


Lemma hom_ext (a b : C) (f g : {hom a,b}) : f = g <-> [fun of f] = [fun of g].
Proof.
split => [ -> // |]; move: f g => [f Hf] [g Hg]; rewrite /Hom.apply => fg.
by rewrite fg in Hf *; rewrite (Prop_irrelevance Hf Hg).
Qed.

Lemma unlock_hom (a b : C) (f : {hom a, b}) :
  locked f = f :> (El a -> El b).
Proof. by unlock. Qed.

Lemma hom_funcompA (a b c d : C) (h : {hom c, d}) (g : {hom b, c}) (f : {hom a, b})
  : [hom of [hom of h \o g] \o f] = [hom of h \o [hom of g \o f]].
Proof. by case:f=>f Hf;case:g=>g Hg;case:h=>h Hh; apply hom_ext. Qed.
Lemma hom_idfunE (a : C) : [hom of idfun] = idfun :> (El a -> El a).
Proof. reflexivity. Qed.

(* Experimental notation [homcomp f , .. , g , h]:
   The purpose is to pretty print the sequence of hom compositions
   that frequently appear in category theory textbooks.
   Also, restricting the components of a composition to homs and using the lemma
   homcompA, we can avoid the infinite sequence of redundunt compositions
   "_ \o id" or "id \o _" that pops out when we "rewrite !funcompA".*)
(* Tactic support is desirable for the following two cases :
   1. rewriting at the head of the sequence; 
      compare for example the lemmas natural and natural_head below
   2. rewriting under [hom of _];
      dependent type errors and explicit application of hom_ext is tedious.
*)
Local Notation "[ 'homcomp' f , .. , g , h ]" := ([fun of f] \o .. ([fun of g] \o [fun of h]) ..)
  (at level 0, format "[ '[' 'homcomp'  f ,  '/' .. ,  '/' g ,  '/' h ']' ]") : category_scope.
Lemma homcompA (a b c d : C) (h : {hom c, d}) (g : {hom b, c}) (f : {hom a, b})
  : (h \o g) \o f = [homcomp h, g, f].
Proof. reflexivity. Qed.
Lemma homcompE (a b c : C) (g : {hom b,c}) (f : {hom a,b}) x : g (f x) = (g \o f) x.
Proof. reflexivity. Qed.
Lemma homcomp_idfun (a b : C) (f : {hom a,b}) : f = [homcomp f, [hom of idfun]] :> (El a -> El b).
Proof. reflexivity. Qed.
Lemma homcomp_hom (a b c : C) (g : {hom b,c}) (f : {hom a,b})
  : [fun of [hom of g \o f]] = g \o f :> (El a -> El c).
Proof. reflexivity. Qed.
Lemma homcomp_hom_head (a b c x: C) (g : {hom b,c}) (f : {hom a,b}) (e : {hom x,a})
  : [homcomp [hom of g \o f], e] = [homcomp g, f, e] :> (El x -> El c).
Proof. reflexivity. Qed.

(* example *)
Example homcompA' (a b c d : C) (h : {hom c, d}) (g : {hom b, c}) (f : {hom a, b})
  : (h \o g) \o f = [homcomp h, g, f].
Proof.
(*
If we issue
 rewrite !funcompA.
here, the result is :
  C : category
  a, b, c, d : C
  h : {hom c,d}
  g : {hom b,c}
  f : {hom a,b}
  ============================
  ((((((((((((((((((((((((((((((((((((((((((((... \o id) \o id) \o id) \o id) \o
                                            id) \o id) \o id) \o id) \o id) \o
                                       id) \o id) \o id) \o id) \o id) \o id) \o
                                 id) \o id) \o id) \o id) \o id) \o id) \o id) \o
                          id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o
                  id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o
         id) \o id) \o id) \o id) \o id) \o id =
  ((((((((((((((((((((((((((((((((((((((((((((... \o id) \o id) \o id) \o id) \o
                                            id) \o id) \o id) \o id) \o id) \o
                                       id) \o id) \o id) \o id) \o id) \o id) \o
                                 id) \o id) \o id) \o id) \o id) \o id) \o id) \o
                          id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o
                  id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o id) \o
         id) \o id) \o id) \o id) \o id) \o id
*)
by rewrite !homcompA.
(* rewrite !homcompA blocks id's from coming in, thanks to {hom _,_} conditions on arguments. *)
Abort.
End category_lemmas.

Module homcomp_notation.
Notation "[ 'homcomp' f , .. , g , h ]" := ([fun of f] \o .. ([fun of g] \o [fun of h]) ..)
  (at level 0, format "[ '[' 'homcomp'  f ,  '/' .. ,  '/' g ,  '/' h ']' ]") : category_scope.
End homcomp_notation.

(* transportation of hom along equality *)
Section transport_lemmas.
Variable C : category.
Definition transport_dom
           (a a' b : C) (p : a = a') (f : {hom a , b}) : {hom a' , b} :=
  eq_rect a (fun x => {hom x, b}) f a' p.
Definition transport_codom
           (a b b' : C) (p : b = b') (f : {hom a , b}) : {hom a , b'} :=
  eq_rect b (fun x => {hom a, x}) f b' p.
Definition transport_hom 
           (a a' b b' : C) (pa : a = a') (pb : b = b') (f : {hom a , b}) :
  {hom a' , b'} :=
  eq_rect b (fun y => {hom a', y})
          (eq_rect a (fun x => {hom x, b}) f a' pa)
          b' pb.
Definition eq_hom (a b : C) (p : a = b) : {hom a, b} :=
  transport_codom p (idfun_hom a).

Lemma transport_dom_eq_hom (a a' b : C) (p : a = a') (f : {hom a, b}) :
  transport_dom p f = [hom of f \o eq_hom (esym p)].
Proof.
apply hom_ext.
by refine (match p with erefl => _ end).
Qed.
Lemma transport_codom_eq_hom (a b b' : C) (p : b = b') (f : {hom a, b}) :
  transport_codom p f = [hom of eq_hom p \o f].
Proof.
apply hom_ext.
by refine (match p with erefl => _ end).
Qed.
End transport_lemmas.

(* Type as a category *)
Section Type_category.
Definition Type_category_class : Category.class_of Type :=
@Category.Class Type id (fun _ _ _ => True) (fun _ => I) (fun _ _ _ _ _ _ _ => I).
Canonical Type_category := Category.Pack Type_category_class.
Definition hom_Type (a b : Type) (f : a -> b) : {hom a,b} := Hom (I : hom (f : El a -> El b)).
End Type_category.

(*** functor ***)
Module FunctorLaws.
Section def.
Variable (C D : category).
Variable (M : C -> D) (f : forall A B, {hom A,B} -> {hom M A, M B}).
Definition id := forall A, f [hom of idfun] = [hom of idfun] :> {hom M A,M A}.
Definition comp := forall A B C (g : {hom B,C}) (h : {hom A,B}),
  f [hom of g \o h] = [hom of f g \o f h] :> {hom M A,M C}.
End def.
End FunctorLaws.

Module Functor.
Record class_of (C D : category) (m : C -> D) : Type := Class {
  f : forall A B, {hom A,B} -> {hom m A, m B} ;
  _ : FunctorLaws.id f ;
  _ : FunctorLaws.comp f
}.
Structure t (C D : category) : Type := Pack { m : C -> D ; class : class_of m }.
Module Exports.
Section exports.
Variables (C D : category).
Definition Fun (F : t C D) : forall A B, {hom A, B} -> {hom m F A, m F B} :=
  let: Pack _ (Class f _ _) := F return forall A B, {hom A, B} -> {hom m F A, m F B} in f.
Arguments Fun _ [A] [B] : simpl never.
End exports.
Notation functor := t.
Coercion m : functor >-> Funclass.
End Exports.
End Functor.
Export Functor.Exports.
Notation "F # f" := (Fun F f) (at level 11).

Section functor_lemmas.
Variable C D : category.
Variable F : functor C D.
Lemma functor_id : FunctorLaws.id (Fun F).
Proof. by case: F => [? []]. Qed.
Lemma functor_o : FunctorLaws.comp (Fun F).
Proof. by case: F => [? []]. Qed.

Lemma functor_id_fun a : F # [hom of idfun] = idfun :> (El (F a) -> El (F a)).
Proof. by rewrite functor_id. Qed.
Lemma functor_o_fun a b c (g : {hom b,c}) (h : {hom a,b}) :
  F # [hom of g \o h] = F # g \o F # h :> (El (F a) -> El (F c)).
Proof. by rewrite functor_o. Qed.

Lemma functor_ext (G : functor C D) (pm : Functor.m F =1 Functor.m G) :
  (forall (A B : C) (f : {hom A, B}),
      transport_hom (pm A) (pm B) (Functor.f (Functor.class F) f) =
      Functor.f (Functor.class G) f)   ->   F = G.
Proof.
move: pm.
case: F => mf cf; case: G => mg cg /= pm.
move: cf cg.
rewrite /transport_hom.
move: (funext pm) => ppm.
destruct ppm => -[] ff idf cf -[] fg idg cg p.
have pp : ff = fg.
- apply functional_extensionality_dep=> A.
  apply functional_extensionality_dep=> B.
  apply functional_extensionality_dep=> f.
  move: (p A B f).
  have -> //: pm = (fun _ => erefl).
  apply Prop_irrelevance.
rewrite {p}.
move: idf cf idg cg; rewrite pp => *.
congr Functor.Pack; congr Functor.Class; apply Prop_irrelevance.
Qed.
End functor_lemmas.

Section functorid.
Variables C : category.
Definition id_f (A B : C) (f : {hom A,B}) := f.
Lemma id_id : FunctorLaws.id id_f. Proof. by move=>A. Qed.
Lemma id_comp : FunctorLaws.comp id_f. Proof. by move=>*. Qed.
Definition FId : functor _ _ := Functor.Pack (Functor.Class id_id id_comp).
Lemma FIdf (A B : C) (f : {hom A,B}) : FId # f = f.
Proof. by []. Qed.
End functorid.
Arguments FId [C].

Section functorcomposition.
Variables (C0 C1 C2 : category) (F : functor C1 C2) (G : functor C0 C1).
Definition functorcomposition a b := fun h : {hom a,b} => F # (G # h).
Lemma functorcomposition_id : FunctorLaws.id functorcomposition.
Proof.
by rewrite /FunctorLaws.id => A; rewrite /functorcomposition 2!functor_id.
Qed.
Lemma functorcomposition_comp : FunctorLaws.comp functorcomposition.
Proof.
rewrite /FunctorLaws.comp => a b c g h; rewrite /functorcomposition.
by rewrite 2!functor_o.
Qed.
Definition FComp : functor C0 C2:=
  Functor.Pack (Functor.Class functorcomposition_id functorcomposition_comp).
End functorcomposition.
Arguments FComp : simpl never.

Notation "f \O g" := (FComp f g).

Section functorcomposition_lemmas.
Variables (C0 C1 C2 C3 : category).
Lemma FCompId (F : functor C0 C1) : F \O FId = F.
Proof.
destruct F as [m [f0 f1 f2]]; congr Functor.Pack; congr Functor.Class => //;
  exact/Prop_irrelevance.
Qed.
Lemma FIdComp (F : functor C0 C1) : FId \O F = F.
Proof.
destruct F as [m [f0 f1 f2]]; congr Functor.Pack; congr Functor.Class => //;
  exact/Prop_irrelevance.
Qed.
Lemma FCompA (F : functor C2 C3) (G : functor C1 C2) (H : functor C0 C1)
  : (F \O G) \O H = F \O (G \O H).
Proof.
destruct F as [m [f0 f1 f2]].
destruct G as [n [g0 g1 g2]].
destruct H as [o [h0 h1 h2]].
congr Functor.Pack; congr Functor.Class => //; exact/Prop_irrelevance.
Qed.
Lemma FCompE (F : functor C1 C2) (G : functor C0 C1) a b (k : {hom a, b}) : (F \O G) # k = F # (G # k).
Proof. by []. Qed.
End functorcomposition_lemmas.

Notation "F ~~> G" := (forall a, {hom F a ,G a}) (at level 51).

(*** natural transformation ***)
Module Natural.
Section natural.
Variables (C D : category) (F G : functor C D).
Definition P (apply : F ~~> G) :=
  forall a b (h : {hom a,b}),
    (G # h) \o (apply a) = (apply b) \o (F # h).
Record class_of (apply : F ~~> G) := Class { _ : P apply }.
Structure t := Pack { apply : F ~~> G ; class : class_of apply }.
End natural.
Module Exports.
Coercion apply : t >-> Funclass.
Arguments P [C D].
Notation naturality := P.
Notation "f ~> g" := (t f g).
Notation Natural p := (Pack (Class p)).
End Exports.
End Natural.
Export Natural.Exports.

Section natural_transformation_lemmas.
Variables (C D : category) (F G : functor C D).
Lemma natural (phi : F ~> G) a b (h : {hom a, b}) :
  (G # h) \o (phi a) = (phi b) \o (F # h).
Proof. by case: phi => ? []. Qed.

Import homcomp_notation.

Lemma natural_head (phi : F ~> G) a b c
  (h : {hom a, b}) (f : {hom c, F a}) :
    [homcomp (G # h), (phi a), f] = [homcomp (phi b), (F # h), f].
Proof. by rewrite -!homcompA natural. Qed.

Lemma nattrans_ext (f g : F ~> G) :
  f = g <-> forall a, Natural.apply f a = Natural.apply g a.
Proof.
split => [ -> // |]; move: f g => [f Hf] [g Hg] /= fg'.
move: (functional_extensionality_dep fg') => fg.
by rewrite fg in Hf *; rewrite (Prop_irrelevance Hf Hg).
Qed.

End natural_transformation_lemmas.
Arguments natural [C D F G].
Arguments natural_head [C D F G].

(* constructions on natural transformations :
   identity, and compositions in two ways *)
Section id_natural_transformation.
Variables (C D : category) (F : functor C D).
Definition natural_id : naturality _ _ (fun a => idfun_hom (F a)).
Proof. by []. Qed.
Definition NId : F ~> F := Natural.Pack (Natural.Class natural_id).
(*
Check Natural.Pack
      (Natural.Class
         ((fun _ _ _ => erefl) :
            (naturality F (F \O FId) (fun a : C => idfun_hom (F a))))).
*)
Lemma NIdE : NId  = (fun a => idfun_hom (F a)) :> (_ ~~> _).
Proof. by []. Qed.
End id_natural_transformation.

Module NIdEq.
Section def.
Import homcomp_notation.
Variables (C D : category) (F G : functor C D).
Variable (Iobj : forall a, F a = G a).
Local Notation tc := (transport_codom (Iobj _)).
Local Notation td := (transport_dom (esym (Iobj _))).
Variable (Imor : forall a b (f : {hom a, b}), tc (F # f) = td (G # f)).
Definition f : F ~~> G := fun (a : C) => tc (idfun_hom (F a)).
Definition n : F ~> G.
apply (Natural.Pack (apply:= f)).
apply Natural.Class=> a b h.
rewrite /f !transport_codom_eq_hom 2!homcomp_hom !funcompfid.
have/hom_ext-> : [hom of [homcomp eq_hom (Iobj b), F # h]] = [hom of tc (F # h)]
  by rewrite transport_codom_eq_hom.
by rewrite homfunK Imor transport_dom_eq_hom homfunK /= esymK.
Defined.
End def.
Module Exports.
Arguments n [C D] : simpl never.
Notation NIdEq := n.
Lemma NIdEqE C D F G Iobj Imor :
  @NIdEq C D F G Iobj Imor =
  (fun a => transport_codom (Iobj _) (idfun_hom (F a))) :> (_ ~~> _).
Proof. reflexivity. Qed.
End Exports.
End NIdEq.
Export NIdEq.Exports.

(*
Notation "[ 'NId' F , G ]" :=
  (Natural.Pack
      (Natural.Class
         ((fun _ _ _ => erefl) :
            (naturality F G (fun a => idfun_hom (F a))))))
    (at level 0, format "[ 'NId'  F ,  G ]") : category_scope.
*)

Notation "[ 'NId' F , G ]" :=
  (NIdEq F G (fun a => erefl) (fun a b f => erefl))
    (at level 0, format "[ 'NId'  F ,  G ]") : category_scope.

Section vertical_composition.
Variables (C D : category) (F G H : functor C D).
Variables (g : G ~> H) (f : F ~> G).
Definition ntcomp := fun a => [hom of g a \o f a].
Definition natural_vcomp : naturality _ _ ntcomp.
Proof. by move=> A B h; rewrite funcompA (natural g) -funcompA (natural f). Qed.
Definition VComp : F ~> H := Natural.Pack (Natural.Class natural_vcomp).
End vertical_composition.
Notation "f \v g" := (VComp f g).

Section vcomp_lemmas.
Variables (C D : category) (F G H I : functor C D).
Variables (h : H ~> I) (g : G ~> H) (f : F ~> G).
Lemma VCompId : f \v NId F = f.
Proof.
by apply nattrans_ext=> a; apply/hom_ext.
Qed.
Lemma VIdComp : NId G \v f = f.
Proof.
by apply nattrans_ext=> a; apply/hom_ext.
Qed.
Lemma VCompA : (h \v g) \v f = h \v (g \v f).
by apply nattrans_ext=> a; apply/hom_ext.
Qed.
Lemma VCompE : g \v f = (fun a => [hom of g a \o f a]) :> (_ ~~> _).
Proof. reflexivity. Qed.
End vcomp_lemmas.

(* horizontal composition, or Godement product *)
Section horizontal_composition.
Variables (C D E : category).
Variables (F G : functor C D) (F' G' : functor D E).
Variables (s : F ~> G) (t : F' ~> G').
Lemma natural_hcomp :
  naturality (F' \O F) (G' \O G) (fun a => [hom of @t (G a) \o F' # (@s a)]).
Proof.
move=> a b h; rewrite funcompA (natural t) -funcompA -[in RHS]funcompA.
congr (_ \o _).
rewrite FCompE -2!functor_o_fun.
congr [fun of F' # _]; apply hom_ext.
by rewrite !homcomp_hom (natural s).
Qed.
Import homcomp_notation.
Lemma natural_hcomp_aux :
  naturality (F' \O F) (G' \O G) (fun a => [hom of G' # (@s a) \o @t (F a)]).
Proof.
move=> a b h.
rewrite [in LHS]homcomp_hom [in RHS]homcomp_hom homcompA.
rewrite (natural_head t).
rewrite !FCompE.
rewrite -(functor_o_fun F').
rewrite -homcompA.
rewrite -(functor_o_fun G').
rewrite (natural t).
by congr (_ \o _); congr [fun of F' # _]; rewrite hom_ext /= (natural s).
Qed.
Definition HComp : (F' \O F) ~> (G' \O G) :=
  Natural.Pack (Natural.Class natural_hcomp).
Definition HComp_aux : (F' \O F) ~> (G' \O G) :=
  Natural.Pack (Natural.Class natural_hcomp_aux).
End horizontal_composition.
Notation "f \h g" := (locked (HComp g f)).
Notation "f \\h g" := (locked (HComp_aux g f)).

Section hcomp_lemmas.
Variables (C D E Z: category).
Variables (F G : functor C D) (F' G' : functor D E) (F'' G'' : functor E Z).
Variables (s : F ~> G) (t : F' ~> G') (u : F'' ~> G'').
Lemma HCompE' : t \h s = HComp s t.
Proof. by unlock. Qed.
Lemma HCompE : t \h s = (fun a => [hom of @t (G a) \o F' # (@s a)]) :> (_ ~~> _).
Proof. by unlock. Qed.
Lemma HComp_auxE' : t \\h s = HComp_aux s t.
Proof. by unlock. Qed.
Lemma HComp_auxE :
  t \\h s = (fun a => [hom of G' # (@s a) \o @t (F a)]) :> (_ ~~> _).
Proof. by unlock. Qed.

Import homcomp_notation.

Lemma HComp_aux_HComp : t \\h s = t \h s.
Proof.
by unlock; apply nattrans_ext=> a /=; rewrite hom_ext /= (natural t).
Qed.

Lemma HCompIdId : s \h NId FId = [NId G , G \O FId] \v s \v [NId F \O FId , F].
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext /=.
by rewrite functor_id hom_idfunE !funcompidf !funcompfid.
Qed.
Lemma HIdIdComp : NId FId \h s = [NId G , FId \O G] \v s \v [NId FId \O F , F].
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext /=.
by rewrite !funcompidf !funcompfid.
Qed.
Lemma HCompA : (u \h t) \h s =
               [NId G'' \O (G' \O G) , (G'' \O G') \O G]
                 \v (u \h (t \h s))
                 \v [NId (F'' \O F') \O F , F'' \O (F' \O F)].
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext; cbn.
rewrite !funcompidf !funcompfid homcompA.
by rewrite functor_o homcomp_hom.
Qed.

(* higher level horizontal composition is a vertical composition of
   horizontal compositions *)
Lemma HComp_VH : t \h s = (t \h NId G) \v (NId F' \h s).
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext /=.
by rewrite homcompA functor_id hom_idfunE !funcompidf.
Qed.
Lemma HComp_VH_aux : t \h s = (NId G' \h s) \v (t \h NId F).
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext; cbn; rewrite funcompidf.
by rewrite functor_id hom_idfunE funcompfid (natural t).
Qed.

Lemma NIdO_HComp : NId (F' \O F) = (NId F') \h (NId F).
Proof.
unlock; apply nattrans_ext=> a; rewrite hom_ext; cbn.
by rewrite functor_id.
Qed.

(* horizontal and vertical compositions interchange *)
Variables (H : functor C D) (H' : functor D E).
Variables (s' : G ~> H) (t' : G' ~> H').
Lemma HCompACA : (t' \h s') \v (t \h s) = (t' \v t) \h (s' \v s).
unlock; apply nattrans_ext=> a; rewrite hom_ext; cbn.
rewrite funcompA [in X in X \o _ = _]homcompA  !homcompA.
rewrite functor_o homcomp_hom.
by rewrite (natural_head t).
Qed.
End hcomp_lemmas.
  
(*** adjoint functor ***)
(* We define adjointness F -| G in terms of its unit and counit. *)
Module AdjointFunctor.
Section def.
Variables (C D : category) (F : functor C D) (G : functor D C).
Record adjunction := mk {
  eta : FId ~> G \O F ;
  eps : F \O G ~> FId ;
  triangular_left : forall c, (eps (F c)) \o (F # eta c) = idfun ;
  triangular_right : forall d, (G # eps d) \o (eta (G d)) = idfun ;
}.
End def.
Section lemmas.
Variables (C D : category) (F : functor C D) (G : functor D C).
Variable A : adjunction F G.
Definition hom_iso c d : {hom F c, d} -> {hom c, G d} :=
  fun h => [hom of (G # h) \o (eta A c)].
Definition hom_inv c d : {hom c, G d} -> {hom F c, d} :=
  fun h => [hom of (eps A d) \o (F # h)].

Import homcomp_notation.

Lemma hom_isoK (c : C) (d : D) (f : {hom F c, d}) : hom_inv (hom_iso f) = f.
Proof.
rewrite /hom_inv /hom_iso.
case: A=> /= [] eps eta triL triR.
apply hom_ext => /=.
by rewrite functor_o homcomp_hom -(natural_head eta) triL.
Qed.
Lemma hom_invK (c : C) (d : D) (g : {hom c, G d}) : hom_iso (hom_inv g) = g.
Proof.
rewrite /hom_inv /hom_iso.
case: A=> /= [] eps eta triL triR.
apply hom_ext => /=.
by rewrite functor_o homcomp_hom_head (natural eps) -homcompA triR.
Qed.

Lemma hom_iso_inj (c : C) (d : D) : injective (@hom_iso c d).
Proof. by apply (can_inj (@hom_isoK c d)). Qed.
Lemma hom_inv_inj (c : C) (d : D) : injective (@hom_inv c d).
Proof. by apply (can_inj (@hom_invK c d)). Qed.

Lemma eta_hom_iso (c : C) : eta A c = hom_iso (idfun_hom (F c)).
Proof.
apply hom_ext.
by rewrite /hom_iso homfunK /= functor_id funcompidf.
Qed.
Lemma eps_hom_inv (d : D) : eps A d = hom_inv (idfun_hom (G d)).
apply hom_ext.
by rewrite /hom_inv homfunK /= functor_id funcompfid.
Qed.

Lemma ext (B : adjunction F G) :
  eta A = eta B -> eps A = eps B -> A = B.
Proof.
case: A => /= etaA epsA triLA triRA.
case: B => /= etaB epsB triLB triRB.
move=> etaAB epsAB.
rewrite etaAB in triLA triRA *.
rewrite epsAB in triLA triRA *.
by congr mk; apply Prop_irrelevance.
Qed.

(*
Lemma left_unique (F' : functor C D) (B : adjunction F' G) :
  exists phi, phi : natural_isomorphism F F'.
Lemma right_unique (G' : functor D C) (B : adjunction F G') :
  exists phi, phi : natural_isomorphism G G'.
*)

End lemmas.
Arguments hom_isoK [C D F G].
Arguments hom_invK [C D F G].
Arguments hom_iso_inj [C D F G].
Arguments hom_inv_inj [C D F G].
End AdjointFunctor.
Module Adj := AdjointFunctor.
Notation "F -| G" := (Adj.adjunction F G).


(*
(* adjunctions compose into an adjunction *)
Module AdjComp.
Section composition_of_adjoint_functors.
Variables (C0 C1 C2 : category).
Variables (F0 : functor C0 C1) (G0 : functor C1 C0) (A0 : F0 -| G0).
Variables (F1 : functor C1 C2) (G1 : functor C2 C1) (A1 : F1 -| G1).

Import homcomp_notation.
Import Adj.

Definition F := F1 \O F0.
Definition G := G0 \O G1.

Definition Eta : FId ~> G \O F :=
  [NId G0 \O (G1 \O F1) \O F0 , G \O F]
    \v ((NId G0) \h (eta A1) \h (NId F0))
    \v [NId G0 \O F0 , G0 \O FId \O F0]
    \v (eta A0).
Lemma EtaE : forall a, Eta a = G0 # (eta A1 (F0 a)) \o (eta A0 a) :> (_ -> _).
Proof. by move=> a; cbn; rewrite functor_id 2!funcompidf 2!funcompfid. Qed.

Definition Eps : F \O G ~> FId :=
  (eps A1)
    \v [NId F1 \O FId \O G1 , F1 \O G1]
    \v ((NId F1) \h (eps A0) \h (NId G1))
    \v [NId F \O G , (F1 \O (F0 \O G0)) \O G1].
Lemma EpsE : forall a, Eps a = (eps A1 _) \o F1 # (eps A0 (G1 a)) :> (_ -> _).
Proof. by move=> a; cbn; rewrite functor_id 3!funcompfid funcompidf. Qed.

Lemma triL c : [homcomp Eps (F c), F # Eta c] = idfun.
Proof.
rewrite /Eps /Eta.
rewrite VCompE homcomp_hom.
rewrite VCompE homcomp_hom.
rewrite VCompE homcomp_hom.
rewrite !funcompfid.

rewrite functor_o homcomp_hom.
rewrite functor_o homcomp_hom.
rewrite functor_o homcomp_hom.
rewrite functor_o homcomp_hom.
rewrite functor_o homcomp_hom.
rewrite !functor_id !funcompidf !funcompfid.
rewrite (triangular_left A1).

         triangular_left : forall c : C,
                           [homcomp eps (F c), F # eta c] = idfun;
         triangular_right : forall d : D,
                            [homcomp G # eps d, eta (G d)] = idfun }


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
End composition_of_adjoint_functors.
End AdjComp.
*)


(* monad *)
Module JoinLaws.
Section join_laws.
Variables (C : category) (M : functor C C) .
Variables (ret : FId ~~> M)
          (join : M \O M ~~> M).

Definition ret_naturality := naturality FId M ret.

Definition join_naturality := naturality (M \O M) M join.

Definition join_left_unit :=
  forall a, @join a \o @ret (M a) = idfun :> (El (M a) -> El (M a)).

Definition join_right_unit :=
  forall a, @join _ \o M # @ret _ = idfun :> (El (M a) -> El (M a)).

Definition join_associativity :=
  forall a, @join _ \o M # @join _ = @join _ \o @join _ :> (El (M (M (M a))) -> El (M a)).
End join_laws.
End JoinLaws.

Module BindLaws.
Section bindlaws.
Variables (C : category) (M : C -> C).

Variable b : forall A B, {hom A, M B} -> {hom M A, M B}.
Local Notation "m >>= f" := (b f m).
(*
NB(saikawa)
I am not convinced if the above typing of `bind' makes sense from the
category-theoretical point of view.  It is rather an ad hoc change needed for
stating the associavitity below.  I am not sure either if it works well in
further formalizations.  Both should be checked with careful thoughts and
examples.

Original and usual definition is :
Variable b : forall A B, M A -> (A -> M B) -> M B.
Local Notation "m >>= f" := (b m f).

This original definition seems to be valid only in closed categories, which
would be a mix-in structure over categories.
*)

Fact associative_aux x y z (f : {hom x, M y}) (g : {hom y, M z})
  : (fun w => (f w >>= g)) = (b g \o f).
Proof. reflexivity. Qed.

Definition associative := forall A B C (m : El (M A)) (f : {hom A, M B}) (g : {hom B, M C}),
  (m >>= f) >>= g = m >>= [hom of b g \o f].

Definition left_neutral (r : forall A, {hom A, M A}) :=
  forall A B (f : {hom A, M B}), [hom of (b f \o r A)] = f.

Definition right_neutral (r : forall A, {hom A, M A}) :=
  forall A (m : El (M A)), m >>= r _ = m.
End bindlaws.

Section bindlaws_on_Type.
Variable M : functor Type_category Type_category.

Variable b : forall A B, (A -> M B) -> M A -> M B.
Local Notation "m >>= f" := (b f m).

Definition bind_right_distributive (add : forall B, M B -> M B -> M B) :=
  forall A B (m : M A) (k1 k2 : A -> M B),
    m >>= (fun x => add _ (k1 x) (k2 x)) = add _ (m >>= k1) (m >>= k2).

Definition bind_left_distributive (add : forall B, M B -> M B -> M B) :=
  forall A B (m1 m2 : M A) (k : A -> M B),
    (add _ m1 m2) >>= k = add _ (m1 >>= k) (m2 >>= k).

Definition right_zero (f : forall A, M A) :=
  forall A B (g : M B), g >>= (fun _ => f A) = f A.

Definition left_zero (f : forall A, M A) := forall A B g, f A >>= g = f B.

Definition left_id (r : forall A, M A) (add : forall B, M B -> M B -> M B) :=
  forall A (m : M A), add _ (r _) m = m.

Definition right_id (r : forall A, M A) (add : forall B, M B -> M B -> M B) :=
  forall A (m : M A), add _ m (r _) = m.
End bindlaws_on_Type.
End BindLaws.

Section bind_lemmas.
Variables (C : category) (M : C -> C).
Variable b : forall A B, {hom A, M B} -> {hom M A, M B}.
Local Notation "m >>= f" := (b f m).
Lemma bind_left_neutral_hom_fun (r : forall A, {hom A, M A})
  : BindLaws.left_neutral b r
    <-> forall A B (f : {hom A, M B}), b f \o r A = [fun of f].
Proof. by split; move=>H A B f; move: (H A B f); move/hom_ext. Qed.
End bind_lemmas.

Module Monad.
Section monad.
Variable (C : category).
Record mixin_of (M : functor C C) : Type := Mixin {
  ret : forall A, {hom A, M A} ;
  join : forall A, {hom M (M A), M A} ;
  _ : JoinLaws.ret_naturality ret ;
  _ : JoinLaws.join_naturality join ;
  _ : JoinLaws.join_left_unit ret join ;
  _ : JoinLaws.join_right_unit ret join ;
  _ : JoinLaws.join_associativity join;
  }.
Record class_of (M : C -> C) := Class {
  base : Functor.class_of M ; mixin : mixin_of (Functor.Pack base) }.
Structure t : Type := Pack { m : C -> C ; class : class_of m }.
Definition baseType (M : t) := Functor.Pack (base (class M)).
End monad.
Module Exports.
Definition Ret (C : category ) (M : t C) : forall A, {hom A, m M A} :=
  let: Pack _ (Class _ (Mixin ret _ _ _ _ _ _) ) := M return forall A, {hom A, m M A} in ret.
Arguments Ret {C M A} : simpl never.
Definition Join (C : category) (M : t C) : forall A ,{hom m M (m M A), m M A} :=
  let: Pack _ (Class _ (Mixin _ join _ _ _ _ _)) := M in join.
Arguments Join {C M A} : simpl never.
Notation monad := t.
Coercion baseType : monad >-> functor.
Canonical baseType.
End Exports.
End Monad.
Export Monad.Exports.

Section monad_interface.
Variable (C : category) (M : monad C).
Lemma ret_naturality : JoinLaws.ret_naturality (@Ret C M).
Proof. by case: M => ? [? []]. Qed.
Lemma join_naturality : JoinLaws.join_naturality (@Join C M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinretM : JoinLaws.join_left_unit (@Ret C M) (@Join C M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinMret : JoinLaws.join_right_unit (@Ret C M) (@Join C M).
Proof. by case: M => ? [? []]. Qed.
Lemma joinA : JoinLaws.join_associativity (@Join C M).
Proof. by case: M => ? [? []]. Qed.

(* *_head lemmas are for [fun of f] \o ([fun of g] \o ([fun of h] \o ..))*)
Import homcomp_notation.
Definition ret_naturality_head :=
  natural_head (Natural ret_naturality). 
Definition join_naturality_head :=
  natural_head (Natural join_naturality).
Lemma joinretM_head a (c:C) (f:{hom c,M a}) : [homcomp Join, Ret, f] = f.
Proof. by rewrite funcompA joinretM. Qed.
Lemma joinMret_head a (c:C) (f:{hom c,M a}) : [homcomp Join, M # Ret, f] = f.
Proof. by rewrite funcompA joinMret. Qed.
Lemma joinA_head a (c:C) (f:{hom c,M (M (M a))})
  :[homcomp Join, M # Join, f] = [homcomp Join, Join, f].
Proof. by rewrite funcompA joinA. Qed.
End monad_interface.

Section from_join_laws_to_bind_laws.
Variable (C : category) (F : functor C C).
Variable (ret : forall A, {hom A, F A}) (join : forall A, {hom F (F A), F A}).

Hypothesis ret_naturality : JoinLaws.ret_naturality ret.
Hypothesis join_naturality : JoinLaws.join_naturality join.
Hypothesis joinretM : JoinLaws.join_left_unit ret join.
Hypothesis joinMret : JoinLaws.join_right_unit ret join.
Hypothesis joinA : JoinLaws.join_associativity join.

Import homcomp_notation.

Let ret_naturality_head := natural_head (Natural ret_naturality).
Let join_naturality_head := natural_head (Natural join_naturality).
Let joinretM_head a (c:C) (f:{hom c,F a}) : [homcomp @join _, @ret _, f] = f.
Proof. by rewrite funcompA joinretM. Qed.
Let joinMret_head a (c:C) (f:{hom c,F a}) : [homcomp @join _, F # @ret _, f] = f.
Proof. by rewrite funcompA joinMret. Qed.
Let joinA_head a (c:C) (f:{hom c,F (F (F a))})
  :[homcomp @join _, F # @join _, f] = [homcomp @join _, @join _, f].
Proof. by rewrite funcompA joinA. Qed.

Let bind (A B : C) (f : {hom A, F B}) : {hom F A, F B} := [hom of (@join B) \o (F # f)].

Lemma bindretf_derived : BindLaws.left_neutral bind ret.
Proof.
move=> A B f.
apply hom_ext=>/=.
by rewrite homcompA ret_naturality joinretM_head.
Qed.

Lemma bindmret_derived : BindLaws.right_neutral bind ret.
Proof.
by move=>A m;rewrite /bind/= !homcompE joinMret.
Qed.

Lemma bindA_derived : BindLaws.associative bind.
Proof.
move=>a b c m f g; rewrite /bind.
(* LHS *)
rewrite homcompE.
(*time(rewrite homcompE).*)
(* ca. 0.55 sec on Mobile Ryzen 3, operating in ca. 1.5GHz *)
(* after "lock"ing the implicit identity and composition proofs,
   this time reduces to 0.38 sec *)
rewrite homcomp_hom_head.
rewrite homcomp_hom.
(* RHS *)
rewrite 2!functor_o.
rewrite !hom_funcompA.
rewrite 3!homcomp_hom.
(* NB : Changing the order of lemmas above easily leads to a dependency error.
   Can we fix this fragility? *)
by rewrite join_naturality_head joinA_head.
Qed.
End from_join_laws_to_bind_laws.

Section monad_lemmas.
Variable (C : category) (M : monad C).

Definition Bind A B (f : {hom A, M B}) : {hom M A, M B} := [hom of Join \o (M # f)].
Arguments Bind {A B} : simpl never.
Local Notation "m >>= f" := (Bind f m).
Lemma bindE (A B:C) : Bind = fun (f : {hom A,M B}) => [hom of Join \o M # f].
Proof. by []. Qed.
Lemma bindretf : BindLaws.left_neutral (@Bind) (@Ret C M).
Proof. apply: bindretf_derived; [exact: ret_naturality | exact: joinretM]. Qed.
Lemma bindretf_fun : 
  (forall (A B : C) (f : {hom A,M B}),
      [fun of (@Bind) A B f] \o [fun of (@Ret C M) A] = [fun of f]).
Proof. by apply/bind_left_neutral_hom_fun/bindretf. Qed.
Lemma bindmret : BindLaws.right_neutral (@Bind) (@Ret C M).
Proof. apply: bindmret_derived; exact: joinMret. Qed.
Lemma bindA : BindLaws.associative (@Bind).
Proof. apply bindA_derived; [exact: join_naturality | exact: joinA]. Qed.

Lemma bindE_ext A B : forall x (f : {hom A, M B}), x >>= f = Join ((M # f) x).
Proof. by []. Qed.
End monad_lemmas.
Arguments Bind {C M A B} : simpl never.
Notation "m >>= f" := (Bind f m).

(*** monad defined by adjointness ***)
Module MonadOfAdjoint.
Section monad_of_adjoint.
Import homcomp_notation.
Variables C D : category.
Variables (F : functor C D) (G : functor D C).
Variable A : F -| G.
Definition eps := Adj.eps A.
Definition eta := Adj.eta A.
Definition M := G \O F.
Definition join a : {hom M (M a), M a} := G # (@eps (F a)).
Definition ret a : {hom a, M a} := @eta a.
Let triL := Adj.triangular_left A.
Let triR := Adj.triangular_right A.
Let joinE : join = fun a => G # (@eps (F a)).
Proof. reflexivity. Qed.
Lemma join_natural : JoinLaws.join_naturality join.
Proof.
rewrite !joinE => a b h.
rewrite/M.
rewrite !FCompE.
have -> : G # (F # (G # (F # h))) = G # ((F \O G) # (F # h))=> //.
rewrite /= -2!functor_o_fun.
congr (Fun G).
by rewrite hom_ext /= -(natural eps).
Qed.
Let join_associativity' a : join a \o join (M a) = join a \o (M # join a).
Proof.
rewrite joinE.
rewrite -2!(functor_o_fun G).
by congr (Fun G); rewrite hom_ext /= (natural eps).
Qed.
Lemma join_associativity : JoinLaws.join_associativity join.
Proof. by move=>a; rewrite join_associativity'. Qed.
Lemma ret_natural : JoinLaws.ret_naturality ret.
Proof. by move=>*; rewrite (natural eta). Qed.
Lemma join_left_unit : JoinLaws.join_left_unit ret join.
Proof. by move=>a;rewrite joinE triR. Qed.
Lemma join_right_unit : JoinLaws.join_right_unit ret join.
Proof.
move=> a; rewrite joinE. rewrite /M FCompE.
rewrite /= -functor_o_fun  -[in RHS]functor_id_fun.
congr (Fun G).
by rewrite hom_ext/= triL.
Qed.
Definition monad_of_adjoint_mixin : Monad.mixin_of M
  := Monad.Mixin ret_natural
                 join_natural
                 join_left_unit
                 join_right_unit
                 join_associativity.
End monad_of_adjoint.
Module Exports.
Definition Monad_of_adjoint C D
           (F : functor C D) (G : functor D C)
           (A : Adj.adjunction F G) :=
  Monad.Pack (Monad.Class (monad_of_adjoint_mixin A)).
End Exports.
End MonadOfAdjoint.
Export MonadOfAdjoint.Exports.

(*** monad defined by bind and ret ***)
Module Monad_of_bind_ret.
Section monad_of_bind_ret.
Import homcomp_notation.
Variables C : category.
Variable M : C -> C.
Variable bind : forall A B, {hom A,M B} -> {hom M A,M B}.
Variable ret : forall A, {hom A, M A}.
Hypothesis bindretf : BindLaws.left_neutral bind ret.
Hypothesis bindmret : BindLaws.right_neutral bind ret.
Hypothesis bindA : BindLaws.associative bind.

Lemma bindretf_fun : 
  (forall (A B : C) (f : {hom A,M B}),
      [fun of bind f] \o [fun of ret A] = [fun of f]).
Proof. by apply bind_left_neutral_hom_fun. Qed.

Definition fmap A B (f : {hom A,B}) := bind [hom of ret B \o f].
Lemma fmap_id : FunctorLaws.id fmap.
Proof.
move=> A; apply/hom_ext/funext=>m. rewrite /fmap.
rewrite/idfun/=.
rewrite /funcomp.
rewrite -[in RHS](bindmret m).
congr (fun f => bind f m).
by rewrite hom_ext.
Qed.
Lemma fmap_o : FunctorLaws.comp fmap.
Proof.
move=> a b c g h; apply/hom_ext/funext=>m; rewrite /fmap/=.
rewrite bindA/=.
congr (fun f => bind f m); rewrite hom_ext/=.
by rewrite -[in RHS]homcompA bindretf_fun.
Qed.
Definition functor_mixin := Functor.Class fmap_id fmap_o.
Let M' := Functor.Pack functor_mixin.

Let ret' : forall A, {hom A, M' A} := ret.
Definition join A : {hom M' (M' A), M' A} := bind [hom of idfun].

Let bind_fmap a b c (f : {hom a,b}) (m : El (M a)) (g : {hom b, M c}) :
  bind g (fmap f m) = bind [hom of g \o f] m .
Proof.
rewrite /fmap bindA. congr (fun f => bind f m).
rewrite homfunK funcomp_homE /= hom_ext/=.
rewrite -homcompA. congr (fun x => x \o [fun of f]).
by rewrite bindretf_fun.
Qed.

Lemma bind_fmap_fun a b c (f : {hom a,b}) (g : {hom b, M c}) :
  bind g \o fmap f = bind [hom of g \o f].
Proof. rewrite funeqE => ?; exact: bind_fmap. Qed.

Lemma ret_naturality : naturality FId M' ret.
Proof. by move=> A B h; rewrite FIdf bindretf_fun. Qed.

Let bindE A B (f : {hom A, M' B}) : bind f = [hom of (join B) \o (M' # f)].
Proof.
rewrite /join.
apply/hom_ext/funext => m.
rewrite /=bind_fmap/idfun/=.
congr (fun f => bind f m).
by rewrite hom_ext.
Qed.

Let fmap_bind a b c (f : {hom a,b}) m (g : {hom c,M a}) :
  (fmap f) (bind g m) = bind [hom of fmap f \o g] m.
Proof. by rewrite /fmap bindA bindE. Qed.

Lemma join_naturality : naturality (FComp M' M') M' join.
Proof.
move => A B h.
rewrite /join /= funeqE => m /=.
rewrite fmap_bind bindA/=.
congr (fun f => bind f m).
rewrite hom_ext/=.
rewrite -[in RHS]homcompA.
by rewrite bindretf_fun.
Qed.

Lemma joinretM : JoinLaws.join_left_unit ret' join.
Proof.
rewrite /join => A.
by rewrite bindretf_fun.
Qed.

Lemma joinMret : JoinLaws.join_right_unit ret' join.
Proof.
rewrite /join => A; rewrite funeqE => ma.
rewrite bind_fmap_fun/= -[in RHS](bindmret ma).
congr (fun f => bind f ma).
by rewrite hom_ext.
Qed.

Lemma joinA : JoinLaws.join_associativity join.
Proof.
move => A; rewrite funeqE => mmma.
rewrite /join.
rewrite bind_fmap_fun/= bindA/=.
congr (fun f => bind f mmma).
by rewrite hom_ext.
Qed.

Definition monad_mixin := Monad.Mixin
  ret_naturality join_naturality joinretM joinMret joinA.
End monad_of_bind_ret.
Module Exports.
Definition Monad_of_bind_ret C M bind ret a b c :=
  Monad.Pack (Monad.Class (@monad_mixin C M bind ret a b c)).
End Exports.
End Monad_of_bind_ret.
Export Monad_of_bind_ret.Exports.


(* interface to monad.v *)
From monae Require monad.
Module Monad_of_category_monad.
Section def.
Variable (M : monad Type_category).
Definition m'' : Type -> Type := M.
Definition f (A B : Type) (h : A -> B) (x : m'' A) : m'' B :=
  (M # hom_Type h) x.
Lemma fid : forall A, f id = id :> (m'' A -> m'' A).
Proof.
move=> A; apply funext=> x /=; rewrite /f.
have-> : hom_Type id = [hom of idfun] by move=> T; apply hom_ext.
by rewrite functor_id.
Qed.
Lemma fcomp : forall A B C (g : B -> C) (h : A -> B),
    f (g \o h) = f g \o f h :> (m'' A -> m'' C).
Proof.
move=> A B C g h; apply funext=> x /=; rewrite /f.
have-> : hom_Type (g \o h) = [hom of hom_Type g \o hom_Type h] by apply hom_ext.
by rewrite functor_o.
Qed.
Definition m' := monad.Functor.Pack (monad.Functor.Class fid fcomp).

Import monad.Functor.Exports.

Definition ret (A : Type) (x : A) : m' A := (@Ret _ M A x).
Definition join (A : Type) (x : m' (m' A)) := (@Join _ M A x).
Lemma ret_nat : monad.Natural.P monad.FId m' ret.
Proof.
move=> A B h; apply funext=> x; rewrite /ret /Fun /= /f.
by rewrite -[in LHS]funcompE (ret_naturality).
Qed.
Lemma join_nat : monad.Natural.P (monad.FComp m' m') m' join.
Proof.
move=> A B h; apply funext=> x; rewrite /ret /Fun /= /f.
rewrite -[in LHS]funcompE join_naturality.
rewrite funcompE FCompE.
suff-> : [fun of M # (M # hom_Type h)] x = [fun of M # hom_Type (Fun m' h)] x
  by done.
congr [fun of M # _].
by apply/hom_ext/funext.
Qed.
Lemma joinretM (A : Type) : @join _ \o @ret _ = id :> (m' A -> m' A).
Proof.
by apply funext=> x; rewrite /join /ret /= -[in LHS]funcompE joinretM.
Qed.
Lemma joinMret (A : Type) : @join _ \o (Fun m' (@ret _)) = id :> (m' A -> m' A).
Proof.
apply funext=> x; rewrite /join /ret /Fun /=.
suff-> : @f A (m'' A) [eta [fun of @Ret Type_category M A]] x =
         [fun of M # Ret] x
  by rewrite -[in LHS]funcompE joinMret.
rewrite /f /m'' /=.
suff-> : @hom_Type A (@Monad.m Type_category M A)
                   [eta [fun of @Ret Type_category M A]] = Ret by done.
by apply hom_ext.
Qed.
Lemma joinA (A : Type) :
  @join _ \o Fun m' (@join _) = @join _ \o @join _ :> (m' (m' (m' A)) -> m' A).
Proof.
apply funext=> x; rewrite /join /ret /Fun /=.
rewrite -[in RHS]funcompE -joinA funcompE.
congr (_ _).
rewrite /f /m'' /=.
suff-> : (@hom_Type (@Monad.m Type_category M (@Monad.m Type_category M A))
                    (@Monad.m Type_category M A)
                    [eta [fun of @Join Type_category M A]]) = Join by done.
by apply hom_ext.
Qed.

Definition m : monad.Monad.t :=
  monad.Monad.Pack
    (monad.Monad.Class
       (monad.Monad.Mixin ret_nat join_nat joinretM joinMret joinA)).
End def.
Module Exports.
Notation Monad_of_category_monad := m.
End Exports.
End Monad_of_category_monad.
Export Monad_of_category_monad.Exports.
