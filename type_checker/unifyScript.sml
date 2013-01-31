open preamble finite_mapTheory optionTheory MiniMLTheory; 
open unifPropsTheory unifDefTheory walkTheory walkstarTheory collapseTheory;

val FLOOKUP_FMAP2 = Q.prove (
`!m f k. FLOOKUP (FMAP_MAP2 (\(k,v). f v) m) k = option_map f (FLOOKUP m k)`,
rw [FLOOKUP_DEF, option_map_def, FMAP_MAP2_THM]);

val FMAP2_id = Q.prove (
`!m. FMAP_MAP2 (\(k,v). v) m = m`,
ho_match_mp_tac fmap_INDUCT >>
rw [FMAP_MAP2_FEMPTY, FMAP_MAP2_FUPDATE]);

val FMAP2_FMAP2 = Q.prove (
`!m f g. FMAP_MAP2 (\(k,v). f v) (FMAP_MAP2 (\(k,v). g v) m) = FMAP_MAP2 (\(k,v). f (g v)) m`,
ho_match_mp_tac fmap_INDUCT >>
rw [FMAP_MAP2_FEMPTY, FMAP_MAP2_FUPDATE]);

val option_bind_thm = Q.prove (
`!x f. OPTION_BIND x f =
  case x of
    | NONE => NONE
    | SOME y => f y`,
cases_on `x` >>
rw [OPTION_BIND_def]);

val _ = new_theory "unify";

val _ = Hol_datatype `
infer_t = 
    Infer_Tvar_db of num
  | Infer_Tapp of infer_t list => tc0
  | Infer_Tfn of infer_t => infer_t
  | Infer_Tuvar of num`;

val infer_t_size_def = fetch "-" "infer_t_size_def";
val infer_t_induction = fetch "-" "infer_t_induction";

val _ = Hol_datatype `
atom = 
    TC_tag of tc0
  | DB_tag of num
  | Tfn_tag
  | Tapp_tag
  | Null_tag`;

val encode_infer_t_def = Define `
(encode_infer_t (Infer_Tvar_db n) =
  Const (DB_tag n)) ∧
(encode_infer_t (Infer_Tfn t1 t2) =
  Pair (Const Tfn_tag) (Pair (encode_infer_t t1) (encode_infer_t t2))) ∧
(encode_infer_t (Infer_Tapp ts tc) =
  Pair (Const Tapp_tag) (Pair (Const (TC_tag tc)) (encode_infer_ts ts))) ∧
(encode_infer_t (Infer_Tuvar n) =
  Var n) ∧
(encode_infer_ts [] =
  Const Null_tag) ∧
(encode_infer_ts (t::ts) =
  Pair (encode_infer_t t) (encode_infer_ts ts))`;

val decode_infer_t_def = Define `
(decode_infer_t (Var n) =
  Infer_Tuvar n) ∧
(decode_infer_t (Const (DB_tag n)) =
  Infer_Tvar_db n) ∧
(decode_infer_t (Pair (Const Tfn_tag) (Pair s1 s2)) =
  Infer_Tfn (decode_infer_t s1) (decode_infer_t s2)) ∧
(decode_infer_t (Pair (Const Tapp_tag) (Pair (Const (TC_tag tc)) s)) =
  Infer_Tapp (decode_infer_ts s) tc) ∧
(decode_infer_ts (Const Null_tag) =
  []) ∧ 
(decode_infer_ts (Pair s1 s2) =
  decode_infer_t s1 :: decode_infer_ts s2)`;

val decode_left_inverse = Q.prove (
`(!t. decode_infer_t (encode_infer_t t) = t) ∧
 (!ts. decode_infer_ts (encode_infer_ts ts) = ts)`,
Induct >>
rw [encode_infer_t_def, decode_infer_t_def]);

val t_wfs_def = Define `
t_wfs s = wfs (FMAP_MAP2 (\(n,t). encode_infer_t t) s)`;

val t_vwalk_def = Define `
t_vwalk s v = decode_infer_t (vwalk (FMAP_MAP2 (\(n,t). encode_infer_t t) s) v)`;

val t_vwalk_ind' = Q.prove (
`!s'. t_wfs s' ⇒
   ∀P. 
     (∀v. (∀v1 u. (FLOOKUP s' v = SOME v1) ∧ (v1 = Infer_Tuvar u) ⇒ P u) ⇒ P v) ⇒
     ∀v. P v`,
ntac 4 STRIP_TAC >>
fs [t_wfs_def] >>
imp_res_tac (DISCH_ALL vwalk_ind) >>
pop_assum ho_match_mp_tac >>
rw [] >>
qpat_assum `∀v. (∀u. (FLOOKUP s' v = SOME (Infer_Tuvar u)) ⇒ P u) ⇒ P v` ho_match_mp_tac >>
rw [] >>
qpat_assum `∀u.  (FLOOKUP (FMAP_MAP2 (λ(n,t). encode_infer_t t) s') v = SOME (Var u)) ⇒ P u` ho_match_mp_tac >>
rw [FLOOKUP_FMAP2, option_map_def, encode_infer_t_def]);

val t_vwalk_ind = save_thm("t_vwalk_ind", (UNDISCH o Q.SPEC `s`) t_vwalk_ind')

val t_vwalk_eqn = Q.store_thm ("t_vwalk_eqn",
`!s. 
  t_wfs s ⇒
  (!v. 
    t_vwalk s v =
    case FLOOKUP s v of
      | NONE => Infer_Tuvar v
      | SOME (Infer_Tuvar u) => t_vwalk s u
      | SOME (Infer_Tfn t1 t2) => Infer_Tfn t1 t2
      | SOME (Infer_Tapp ts tc') => Infer_Tapp ts tc'
      | SOME (Infer_Tvar_db n) => Infer_Tvar_db n)`,
rw [t_vwalk_def] >>
full_case_tac >>
rw [] >>
fs [t_wfs_def] >|
[rw [Once vwalk_def] >>
     full_case_tac >>
     rw [decode_infer_t_def] >>
     fs [FLOOKUP_FMAP2, option_map_def] >>
     cases_on `FLOOKUP s v` >>
     fs [],
 rw [Once vwalk_def, FLOOKUP_FMAP2, option_map_def] >>
     cases_on `x` >>
     rw [encode_infer_t_def, decode_infer_t_def, decode_left_inverse]]);

val t_walk_def = Define `
t_walk s t = decode_infer_t (walk (FMAP_MAP2 (\(n,t). encode_infer_t t) s) (encode_infer_t t))`;

val t_walk_eqn = Q.store_thm ("t_walk_eqn",
`(!s v. t_walk s (Infer_Tuvar v) = t_vwalk s v) ∧
 (!s t1 t2. t_walk s (Infer_Tfn t1 t2) = Infer_Tfn t1 t2) ∧
 (!s ts tc. t_walk s (Infer_Tapp ts tc) = Infer_Tapp ts tc) ∧
 (!s n. t_walk s (Infer_Tvar_db n) = Infer_Tvar_db n)`,
rw [t_walk_def, walk_def, t_vwalk_def, encode_infer_t_def,
    decode_infer_t_def, decode_left_inverse]);

val t_oc_def = Define `
t_oc s t v = oc (FMAP_MAP2 (\(n,t). encode_infer_t t) s) (encode_infer_t t) v`;

(*
val t_vars_def = Define `
t_vars t = vars (encode_infer_t t)`;

val t_oc_ind' = Q.prove (
`∀s oc'.
  t_wfs s ∧
  (∀t v. v ∈ t_vars t ∧ v ∉ FDOM s ⇒ oc' t v) ∧
  (∀t v u t'. u ∈ t_vars t ∧ (t_vwalk s u = t') ∧ oc' t' v ⇒ oc' t v) ⇒
  (∀a0 a1. oc (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) a0 a1 ⇒ !a0'. (a0 = encode_infer_t a0') ⇒ oc' a0' a1)`,
NTAC 3 STRIP_TAC >>
ho_match_mp_tac oc_ind >>
rw [] >|
[qpat_assum `∀t v. v ∈ t_vars t ∧ v ∉ FDOM s ⇒ oc' t v` ho_match_mp_tac >>
     fs [t_vars_def, FMAP_MAP2_THM],
 qpat_assum `∀t v u t'. u ∈ t_vars t ∧ (t_vwalk s u = t') ∧ oc' t' v ⇒ oc' t v` ho_match_mp_tac >>
     rw [t_vars_def] >>
     qexists_tac `u` >>
     rw [] >>
     pop_assum ho_match_mp_tac >>
     rw [encode_vwalk]]);

val t_oc_ind = Q.store_thm ("t_oc_ind",
`∀s oc'.
  t_wfs s ∧
  (∀t v. v ∈ t_vars t ∧ v ∉ FDOM s ⇒ oc' t v) ∧
  (∀t v u t'. u ∈ t_vars t ∧ (t_vwalk s u = t') ∧ oc' t' v ⇒ oc' t v) ⇒
  (∀a0 a1. t_oc s a0 a1 ⇒ oc' a0 a1)`,
rw [t_oc_def] >>
metis_tac [t_oc_ind', FMAP2_FMAP2, FMAP2_id, decode_left_inverse]);
*)

val encode_vwalk = Q.prove (
`!s. t_wfs s ⇒ !u. vwalk (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) u = encode_infer_t (t_vwalk s u)`,
NTAC 2 STRIP_TAC >>
ho_match_mp_tac t_vwalk_ind >>
rw [] >>
`wfs (FMAP_MAP2 (\(n,t). encode_infer_t t) s)` by metis_tac [t_wfs_def] >>
rw [Once vwalk_def] >>
rw [Once t_vwalk_eqn, FLOOKUP_FMAP2] >>
cases_on `FLOOKUP s u` >>
rw [option_map_def, encode_infer_t_def] >>
cases_on `x` >>
rw [encode_infer_t_def]);

val t_oc_eqn_help = Q.prove (
`!l v s.
  oc (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) (encode_infer_ts l) v ⇔
  EXISTS (λt. oc (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) (encode_infer_t t) v) l`,
induct_on `l` >>
rw [encode_infer_t_def]);

val t_oc_eqn = Q.store_thm ("t_oc_eqn",
`!s. t_wfs s ⇒
  !t v. t_oc s t v =
    case t_walk s t of
      | Infer_Tuvar u => v = u
      | Infer_Tfn t1 t2 => t_oc s t1 v ∨ t_oc s t2 v
      | Infer_Tapp ts tc' => EXISTS (\t. t_oc s t v) ts
      | Infer_Tvar_db n => F`,
rw [t_oc_def] >>
`wfs (FMAP_MAP2 (λ(n,t). encode_infer_t t) s)` by fs [t_wfs_def] >>
rw [Once oc_walking, t_walk_def] >>
cases_on `t` >>
rw [walk_def, encode_infer_t_def, decode_infer_t_def, decode_left_inverse,
    encode_vwalk, t_oc_eqn_help] >>
cases_on `t_vwalk s n` >>
rw [encode_infer_t_def, t_oc_eqn_help]);

val t_ext_s_check_def = Define `
t_ext_s_check s v t =
  option_map 
    (FMAP_MAP2 (\(n,t). decode_infer_t t))
    (ext_s_check (FMAP_MAP2 (\(n,t). encode_infer_t t) s) v (encode_infer_t t))`;

val t_ext_s_check_eqn = Q.store_thm ("t_ext_s_check_eqn",
`!s v t.
  t_ext_s_check s v t = if t_oc s t v then NONE else SOME (s |+ (v,t))`,
rw [t_ext_s_check_def, t_oc_def, option_map_def, FMAP_MAP2_FUPDATE, 
    FMAP2_FMAP2, FMAP2_id, decode_left_inverse]);

val t_unify_def = Define `
t_unify s t1 t2 = 
  option_map 
    (FMAP_MAP2 (\(n,t). decode_infer_t t))
    (unify (FMAP_MAP2 (\(n,t). encode_infer_t t) s) (encode_infer_t t1) (encode_infer_t t2))`;

val ts_unify_def = Define `
(ts_unify s [] [] = SOME s) ∧
(ts_unify s (t1::ts1) (t2::ts2) =
  case t_unify s t1 t2 of
   | NONE => NONE
   | SOME s' => ts_unify s' ts1 ts2) ∧
(ts_unify s _ _ = NONE)`;


val encode_unify = Q.prove (
`!s t1 t2 s' t1' t2'.
  (s = (FMAP_MAP2 (λ(n,t). encode_infer_t t) s')) ∧
  (t1 = encode_infer_t t1') ∧ 
  (t2 = encode_infer_t t2') ∧ 
  t_wfs s' ⇒
  (unify s t1 t2
   =
   option_map (FMAP_MAP2 (λ(n,t). encode_infer_t t)) (t_unify s' t1' t2'))`,
ho_match_mp_tac unify_ind >>
rw [t_unify_def] >>
cases_on `unify (FMAP_MAP2 (λ(n,t). encode_infer_t t) s') (encode_infer_t t1') (encode_infer_t t2')` >>
rw [option_map_def, FMAP2_FMAP2, decode_left_inverse, FMAP2_id] >>
cases_on `t1'` >>
cases_on `t2'` >>
fs [walk_def, encode_infer_t_def] >>
`wfs (FMAP_MAP2 (λ(n,t). encode_infer_t t) s')` by metis_tac [t_wfs_def] >>
fs [Once unify_def] >>
rw [option_map_def, FMAP2_FMAP2, decode_left_inverse, FMAP2_id, encode_vwalk] >>
cheat);

val wfs_unify = Q.prove (
`!s t1 t2 s'. wfs s ∧ (unify s t1 t2 = SOME s') ⇒ wfs s'`,
cheat);

val ts_unify_thm = Q.prove (
`!s l1 l2.
  t_wfs s ⇒
  (ts_unify s l1 l2 =
   option_map (FMAP_MAP2 (λ(n,t). decode_infer_t t))
     (unify (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) (encode_infer_ts l1) (encode_infer_ts l2)))`,
induct_on `l1` >>
cases_on `l2` >>
rw [ts_unify_def, encode_infer_t_def] >>
`wfs (FMAP_MAP2 (\(n,t). encode_infer_t t) s)` by metis_tac [t_wfs_def] >|
[rw [Once unify_def, option_map_def, decode_left_inverse, FMAP2_FMAP2, FMAP2_id],
 rw [Once unify_def, option_map_def, ts_unify_def],
 rw [Once unify_def, option_map_def, ts_unify_def],
 rw [Once unify_def] >>
     cases_on `t_unify s h' h` >>
     rw [] >|
     [fs [t_unify_def, option_bind_thm] >>
          every_case_tac >>
          fs [option_map_def],
      fs [t_unify_def, option_bind_thm] >>
          every_case_tac >>
          fs [option_map_def] >>
          rw [FMAP2_FMAP2, FMAP2_id] >>
          `?x. x' = FMAP_MAP2 (λ(n,t). encode_infer_t t) x`
                by (imp_res_tac encode_unify >>
                    fs [option_map_def] >>
                    cases_on `t_unify s h' h` >>
                    fs [] >>
                    metis_tac []) >>
          `t_wfs x` by
                 (rw [t_wfs_def] >>
                  metis_tac [wfs_unify]) >>
          rw [FMAP2_FMAP2, FMAP2_id, decode_left_inverse]]]);
(*
val t_unify_eqn = Q.store_thm ("t_unify_eqn",
`(!t1 t2 s.
  t_wfs s ⇒
  (t_unify s t1 t2 =
   case (t_walk s t1, t_walk s t2) of
      (Infer_Tuvar v1, Infer_Tuvar v2) =>
        SOME (if v1 = v2 then s else s |+ (v1,Infer_Tuvar v2))
    | (Infer_Tuvar v1, t2) => t_ext_s_check s v1 t2
    | (t1, Infer_Tuvar v2) => t_ext_s_check s v2 t1
    | (Infer_Tfn t1a t1b, Infer_Tfn t2a t2b) =>
        (case t_unify s t1a t2a of
          | NONE => NONE
          | SOME sx => t_unify sx t1b t2b)
    | (Infer_Tapp ts1 tc1, Infer_Tapp ts2 tc2) =>
        if tc1 = tc2 then
          ts_unify s ts1 ts2
        else
          NONE
    | (Infer_Tvar_db n1, Infer_Tvar_db n2) =>
        if n1 = n2 then 
          SOME s 
        else
          NONE
    | _ => NONE))`,

rw [t_unify_def] >>
`wfs (FMAP_MAP2 (\(n,t). encode_infer_t t) s)` by metis_tac [t_wfs_def] >>
rw [Once unify_def, t_walk_def] >>
cases_on `t1` >>
cases_on `t2` >>
rw [encode_infer_t_def, decode_infer_t_def, option_map_def, decode_left_inverse,
    FMAP2_FMAP2, FMAP2_id, encode_vwalk, option_bind_thm] >|
[cases_on `t_vwalk s n'` >>
     rw [encode_infer_t_def, option_map_def, FMAP2_FMAP2, decode_left_inverse,
         FMAP2_id, FMAP_MAP2_FUPDATE, decode_infer_t_def] >>
     rw [t_ext_s_check_eqn] >>
     imp_res_tac t_oc_eqn >>
     pop_assum (fn x => ALL_TAC) >>
     pop_assum (fn x => ALL_TAC) >>
     pop_assum (ASSUME_TAC o Q.SPECL [`n''`, `Infer_Tvar_db n`]) >>
     fs [] >>
     rw [t_walk_def, encode_infer_t_def, decode_infer_t_def],
 rw [Once unify_def] >>
     rw [Once unify_def] >>
     rw [Once unify_def] >>
     rw [ts_unify_thm, option_map_def],
 rw [Once unify_def] >>
     rw [Once unify_def] >>
     rw [Once unify_def],
 rw [Once unify_def],
 cases_on `t_vwalk s n` >>
     rw [encode_infer_t_def] >>
     rw [Once unify_def] >>
     rw [Once unify_def] >>
     rw [Once unify_def] >>
     rw [ts_unify_thm, option_map_def, FMAP2_FMAP2, decode_left_inverse,
         FMAP2_id, FMAP_MAP2_FUPDATE, decode_infer_t_def, t_ext_s_check_eqn, option_map_def] >>
     rw [Once oc_walking, encode_infer_t_def, t_oc_def],
 rw [Once unify_def],
 rw [Once unify_def] >>
     rw [Once unify_def] >>
     cases_on `unify (FMAP_MAP2 (λ(n,t). encode_infer_t t) s) (encode_infer_t i) (encode_infer_t i')` >>
     fs [] >>
     cases_on `unify x (encode_infer_t i0) (encode_infer_t i0')` >>
     fs [] >>
     `?x'. x = FMAP_MAP2 (λ(n,t). encode_infer_t t) x'`
           by (imp_res_tac encode_unify >>
               fs [option_map_def] >>
               cases_on `t_unify s i i'` >>
               fs [] >>
               metis_tac []) >>
    rw [FMAP2_FMAP2, FMAP2_id, decode_left_inverse],
 all_tac,
 all_tac,
 all_tac,
 all_tac,
 all_tac]

 *) 

val apply_subst_t = Define `
apply_subst_t s t = decode_infer_t (subst_APPLY (FMAP_MAP2 (\(n,t). encode_infer_t t) s) (encode_infer_t t))`;

val t_collapse_def = Define `
t_collapse s = 
  FMAP_MAP2 (\(n,t). decode_infer_t t)
    (collapse ((FMAP_MAP2 (\(n,t). encode_infer_t t)) s))`;

val _ = export_theory ();
