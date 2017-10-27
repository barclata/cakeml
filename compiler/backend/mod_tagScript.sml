open preamble modLangTheory;
open backend_commonTheory;

(* The translator to conLang keeps a mapping (tag_env) of each constructor to
 * its arity, tag, and type. Tags need only be unique for each arity-type pair,
 * and are reused as much as possible otherwise.
 *
 * The expressions include the unary operation for initialising the global
 * store, even though it can't be used until decLang. However, including it here
 * means that the conLang->decLang translation can just be (\x.x). Also
 * includes the expression for extending the global store.
 *)

val _ = new_theory "mod_tag";
val _ = set_grammar_ancestry ["misc", "backend_common", "modLang"];

(*
(* for each constructor, its arity and tag *)
val _ = type_abbrev( "tag_env" , ``:(modN, conN, num # num) namespace``);

val lookup_tag_env_def = Define`
  lookup_tag_env cn (tagenv:(tvarN,tvarN,'a#num) namespace) =
  OPTION_MAP SND (OPTION_JOIN (OPTION_MAP (nsLookup tagenv) cn))`

val compile_pat_def = tDefine"compile_pat"`
  (compile_pat tagenv (Pvar x) = (Pvar x))
  ∧
  (compile_pat tagenv Pany = Pany)
  ∧
  (compile_pat tagenv (Plit l) = (Plit l))
  ∧
  (compile_pat tagenv (Pcon con_id ps) =
    (Pcon (lookup_tag_env con_id tagenv) (MAP (compile_pat tagenv) ps)))
  ∧
  (compile_pat tagenv (Pref p) = (Pref (compile_pat tagenv p)))
  ∧
  (compile_pat tagenv (Ptannot p t) = compile_pat tagenv p)`
  (WF_REL_TAC `inv_image $< (\(x,p). pat_size p)` >>
   srw_tac [ARITH_ss] [astTheory.pat_size_def] >>
   Induct_on `ps` >>
   srw_tac [ARITH_ss] [astTheory.pat_size_def] >>
   srw_tac [ARITH_ss] [astTheory.pat_size_def] >>
   res_tac >>
   decide_tac);

val compile_exp_def = tDefine"compile_exp"`
  (compile_exp tagenv (Raise t e) = Raise t (compile_exp tagenv e))
  ∧
  (compile_exp tagenv (Handle t e pes) =
   Handle t (compile_exp tagenv e) (compile_pes tagenv pes))
  ∧
  (compile_exp tagenv ((Lit t l):modLang$exp) = (Lit t l:conLang$exp))
  ∧
  (compile_exp tagenv (Con t cn es) =
   Con t (lookup_tag_env cn tagenv) (compile_exps tagenv es))
  ∧
  (compile_exp tagenv (Var_local t x) = Var_local t x)
  ∧
  (compile_exp tagenv (Var_global t n) = Var_global t n)
  ∧
  (compile_exp tagenv (Fun t x e) =
   Fun t x (compile_exp tagenv e))
  ∧
  (compile_exp tagenv (App t op es) =
   App t (Op op) (compile_exps tagenv es))
  ∧
  (compile_exp tagenv (If t e1 e2 e3) =
   Mat t (compile_exp tagenv e1)
     [(Pcon (SOME true_tag) [],compile_exp tagenv e2);
      (Pcon (SOME false_tag) [],compile_exp tagenv e3)])
  ∧
  (compile_exp tagenv (Mat t e pes) =
   Mat t (compile_exp tagenv e) (compile_pes tagenv pes))
  ∧
  (compile_exp tagenv (Let t a e1 e2) =
   Let t a (compile_exp tagenv e1) (compile_exp tagenv e2))
  ∧
  (compile_exp tagenv (Letrec t funs e) =
   Letrec t (compile_funs tagenv funs) (compile_exp tagenv e))
  ∧
  (compile_exps tagenv [] = [])
  ∧
  (compile_exps tagenv (e::es) =
   compile_exp tagenv e :: compile_exps tagenv es)
  ∧
  (compile_pes tagenv [] = [])
  ∧
  (compile_pes tagenv ((p,e)::pes) =
   (compile_pat tagenv p, compile_exp tagenv e) :: compile_pes tagenv pes)
  ∧
  (compile_funs tagenv [] = [])
  ∧
  (compile_funs tagenv ((f,x,e)::funs) =
   (f,x,compile_exp tagenv e) :: compile_funs tagenv funs)`
  (WF_REL_TAC `inv_image $< (\x. case x of INL (x,e) => exp_size e
                                         | INR (INL (x,es)) => exp6_size es
                                         | INR (INR (INL (x,pes))) => exp3_size pes
                                         | INR (INR (INR (x,funs))) => exp1_size funs)`);

val compile_exps_map = Q.store_thm("compile_exps_map",
  `!tagenv es.
    compile_exps tagenv es = MAP (compile_exp tagenv) es`,
  Induct_on `es` >>
  rw [compile_exp_def]);

val compile_funs_map = Q.store_thm("compile_funs_map",
  `!funs.
    compile_funs cenv funs = MAP (\(f,x,e). (f,x,compile_exp cenv e)) funs`,
   induct_on `funs` >>
   rw [compile_exp_def] >>
   PairCases_on `h` >>
   rw [compile_exp_def]);

val _ = type_abbrev( "exh_ctors_env" , ``:(modN,typeN) id |-> num spt``);

(* next exception tag (arity-indexed),
 * current tag env,
 * current exh_ctors_env,
 * accumulator (for use on module exit) *)
val _ = type_abbrev( "tagenv_state", ``:num spt # tag_env # exh_ctors_env``);
val _ = type_abbrev( "tagenv_state_acc", ``:tagenv_state # tag_env``);

val _ = Define `
  get_tagenv (((next,tagenv,exh),acc):tagenv_state_acc) = tagenv`;

val _ = Define `
  get_exh ((next,tagenv,exh):tagenv_state) = exh`;

val _ = Define `
  insert_tag_env cn tag (tagenv:tag_env) =
    nsBind cn tag tagenv`;

val _ = Define `
  alloc_tag tn cn arity (((next,tagenv,exh),acc):tagenv_state_acc) =
  (case tn of
   | TypeExn _ =>
     let tag = (case lookup arity next of
                | NONE => 0
                | SOME n => n)
     in
       ((insert arity (tag+1) next,
         insert_tag_env cn (arity,tag,tn) tagenv,
         exh),
        nsBind cn (arity,tag,tn) acc)
   | TypeId tid =>
     let (tag,exh) =
       (case FLOOKUP exh tid of
        | NONE => (0, exh |+ (tid, insert arity 1 LN))
        | SOME m => (case lookup arity m of
                     | NONE => (0, exh |+ (tid, insert arity 1 m))
                     | SOME t => (t, exh |+ (tid, insert arity (t+1) m))))
     in
       ((next,
         insert_tag_env cn (arity,tag,tn) tagenv,
         exh),
        nsBind cn (arity,tag,tn) acc))`;

val _ = Define `
  (alloc_tags mn st [] = st)
  ∧
  (alloc_tags mn st ((tvs,tn,constrs)::types) =
   let st' =
     FOLDL (λst' (cn,ts). alloc_tag (TypeId (mk_id mn tn)) cn (LENGTH ts) st') st constrs
   in
     alloc_tags mn st' types)`;

val _ = Define `
  (compile_decs st [] = (st,[])) ∧
  (compile_decs st (Dlet n e :: ds) =
    let (st', ds') = compile_decs st ds in
      (st', Dlet n (compile_exp (get_tagenv st) e)::ds')) ∧
  (compile_decs st (Dletrec funs :: ds) =
    let (st', ds') = compile_decs st ds in
      (st', Dletrec (compile_funs (get_tagenv st) funs)::ds')) ∧
  (compile_decs st (Dtype type_def :: ds) =
    let st'' = alloc_tags mn st type_def in
    let (st',ds') = compile_decs st'' ds in
      (st', ds')) ∧
  (compile_decs st (Dexn cn arity :: ds) =
    let (st', ds') = compile_decs (alloc_tag (TypeExn (mk_id mn cn)) cn arity st) ds in
      (st', ds'))`;

val _ = Datatype`
  config = <| next_exception : num spt
            ; tag_env : tag_env
            ; exh_ctors_env : exh_ctors_env
            |>`;

val empty_config_def = Define`
  empty_config = <| next_exception := LN
                  ; tag_env := nsEmpty
                  ; exh_ctors_env := FEMPTY |>`;

val compile_def = Define`
  compile c p =
  let ((n,t,e),p) =
    compile_prog (c.next_exception, c.tag_env, c.exh_ctors_env) p in
  (<| next_exception := n; tag_env := t; exh_ctors_env := e|>, p)`;
  *)

val _ = export_theory ();