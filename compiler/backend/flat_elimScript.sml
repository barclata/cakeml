open preamble sptreeTheory flatLangTheory reachabilityTheory

val _ = new_theory "flat_elim";

(******************************************************** HELPER FUNCTIONS *********************************************************)

(**************************** ISHIDDEN/ISPURE *****************************)

(* from source_to_flat$compile_decs:
    env_with_closure : alist_to_ns (alloc_defs n next_vidx fun_names)
        (where we call compile_decs n next env decs_list)
        =>  alloc_defs : num -> num -> tvarN list -> (tvarN, exp) alist     (where tvarN = string)
            alist_to_ns : (tvarN, exp) alist -> (tvarN, tvarN, exp) namespace

    Dlet locs p e => env_with_closure, Dlet (Mat _ (compile_exp _ env e) [(compile_pat env p, make_varls ...)])
    Dletrec locs [(f,x,e)] => env_with_closure, Dlet (App _ (GlobalVarInit _) [compile_exp _ env (Letrec [(f,x,e)] (Var _))]
    Dletrec locs [] => emptyish_env, []
    Dletrec locs (a::b::c) => env_with_closure,
                    MAP (λ (f,x,e) . Dlet (App _ (GlobalVarInit _ [Fun _ x e]))) (compile_funs _ new_env (a::b::c))
    Dtype locs type_def => emptyish_env, MAP (λ (ns,cids) . Dtype _ cids) new_env
    Dtabbrev locs tvs tn t => empty_env, []
    Dexn locs cn ts => emptyish_env, Dexn _ (LENGTH ts)
    Dmod mn ds => let (n1, next1, new_env, decs1) = compile_decs n next env ds in
                    (n1, next1, , decs1
*)

(* isHidden exp = T means there is no direct execution of GlobalVarLookup *)
val isHidden_def = tDefine "isHidden" `
    (isHidden (Raise t e) = isHidden e) ∧                                       (* raise exception *)
    (isHidden (Handle t e pes) = F) ∧                                           (* exception handler *)
    (isHidden (Lit t l) = T) ∧                                                  (* literal *)
    (isHidden (Con t id_option es) = EVERY isHidden es) ∧                       (* constructor *)
    (isHidden (Var_local t str) = T) ∧                                          (* local var *)
    (isHidden (Fun t name body) = T) ∧                                          (* function abstraction *)
    (isHidden (App t Opapp l) = F) ∧                                            (* function application *)
    (isHidden (App t (GlobalVarInit g) [e]) = isHidden e) ∧                     (* GlobalVarInit *)
    (isHidden (App t (GlobalVarLookup g) [e]) = F) ∧                            (* GlobalVarLookup *)
    (isHidden (If t e1 e2 e3) = (isHidden e1 ∧ isHidden e2 ∧ isHidden e3)) ∧    (* if expression *)
    (isHidden (Mat t e1 [p,e2]) = (isHidden e1 ∧ isHidden e2)) ∧                (* SINGLE pattern match *)
    (isHidden (Let t opt e1 e2) = (isHidden e1 ∧ isHidden e2)) ∧                (* let-expression *)
    (isHidden (Letrec t funs e) = isHidden e) ∧                                 (* local def of mutually recursive funs *)
    (isHidden _ = F)
`
    (
        WF_REL_TAC `measure (λ e . exp_size e)` >> rw[exp_size_def] >>
        Induct_on `es` >> rw[exp_size_def] >> fs[]
    );

val isHidden_ind = theorem "isHidden_ind";

(* check if expression is pure in that it does not make any visible changes (other than writing to globals) *)
val isPure_def = tDefine "isPure" `
    (isPure (Handle t e pes) = isPure e) ∧
    (isPure (Lit t l) = T) ∧
    (isPure (Con t id_option es) = EVERY isPure es) ∧
    (isPure (Var_local t str) = T) ∧
    (isPure (Fun t name body) = T) ∧
    (isPure (App t (GlobalVarInit g) es) = EVERY isPure es) ∧
(*    (isPure (App t (GlobalVarLookup g) es) = EVERY isPure es) ∧ *)
    (isPure (If t e1 e2 e3) = (isPure e1 ∧ isPure e2 ∧ isPure e3)) ∧
    (isPure (Mat t e1 pes) = (isPure e1 ∧ EVERY isPure (MAP SND pes))) ∧
    (isPure (Let t opt e1 e2) = (isPure e1 ∧ isPure e2)) ∧
    (isPure (Letrec t funs e) = isPure e) ∧
    (isPure _ = F)
`
    (
        WF_REL_TAC `measure (λ e . exp_size e)` >> rw[exp_size_def] >> fs[] >>
        TRY (Induct_on `es` >> rw[exp_size_def] >> fs[])
        >- (Induct_on `pes` >> rw[exp_size_def] >> fs[] >>
            Cases_on `h` >> fs[exp_size_def])
 );

val isPure_ind = theorem "isPure_ind";

val isPure_EVERY_aconv = Q.store_thm ("isPure_EVERY_aconv",
    `∀ es . EVERY (λ a . isPure a) es = EVERY isPure es`,
    Induct >> fs[]
);


(**************************** DEST_GLOBALVARINIT/DEST_GLOBALVARLOOOKUP *****************************)

val dest_GlobalVarInit_def = Define `
    dest_GlobalVarInit (GlobalVarInit n) = SOME n ∧
    dest_GlobalVarInit _ = NONE
`

val dest_GlobalVarLookup_def = Define `
    dest_GlobalVarLookup (GlobalVarLookup n) = SOME n ∧
    dest_GlobalVarLookup _ = NONE
`

(**************************** FIND GLOBALVARINIT/GLOBALVARLOOKUP *****************************)

(******** LEMMAS ********)

val exp_size_map_snd = Q.store_thm("exp_size_map_snd",
    `∀ p_es . exp6_size (MAP SND p_es) ≤ exp3_size p_es`,
    Induct >> rw[exp_size_def] >>
    Cases_on `exp6_size (MAP SND p_es) = exp3_size p_es` >>
    `exp_size (SND h) ≤ exp5_size h` by (Cases_on `h` >> rw[exp_size_def]) >> rw[]
);

val exp_size_map_snd_snd = Q.store_thm("exp_size_map_snd_snd",
    `∀ vv_es . exp6_size (MAP (λ x . SND (SND x)) vv_es) ≤ exp1_size vv_es`,
    Induct >> rw[exp_size_def] >>
    Cases_on `exp6_size (MAP (λ x . SND (SND x)) vv_es) = exp1_size vv_es` >>
    `exp_size (SND (SND h)) ≤ exp2_size h` by
        (Cases_on `h` >> Cases_on `r` >> rw[exp_size_def]) >> rw[]
);

(******** FINDLOC ********)

val findLoc_def = tDefine "findLoc" `
    (findLoc ((Raise _ er):flatLang$exp) = findLoc er) ∧
    (findLoc (Handle _ eh p_es) = union (findLoc eh) (findLocL (MAP SND p_es))) ∧
    (findLoc (Lit _ _) = LN:num_set) ∧
    (findLoc (Con _ _ es) = findLocL es) ∧
    (findLoc (Var_local _ _) = LN) ∧
    (findLoc (Fun _ _ ef) = findLoc ef) ∧
    (findLoc (App _ op es) = (case (dest_GlobalVarInit op) of
        | SOME n => (insert n () (findLocL es))
        | NONE => findLocL es)) ∧
    (findLoc (If _ ei1 ei2 ei3) = union (findLoc ei1) (union (findLoc ei2) (findLoc ei3))) ∧
    (findLoc (Mat _ em p_es) = union (findLoc em) (findLocL (MAP SND p_es))) ∧
    (findLoc (Let _ _ el1 el2) = union (findLoc el1) (findLoc el2)) ∧
    (findLoc (Letrec _ vv_es elr1) = union (findLocL (MAP (SND o SND) vv_es)) (findLoc elr1)) ∧
    (findLocL [] = LN) ∧
    (findLocL (e::es) = union (findLoc e) (findLocL es))`
    (
        WF_REL_TAC `measure (λ e . case e of
            | INL x => exp_size x
            | INR y => exp6_size y)` >>
        rw[exp_size_def]
        >- (qspec_then `vv_es` mp_tac exp_size_map_snd_snd >>
            Cases_on `exp6_size(MAP (λ x . SND (SND x)) vv_es) = exp1_size vv_es` >>
            rw[])
        >- (qspec_then `p_es` mp_tac exp_size_map_snd >>
            Cases_on `flatLang$exp6_size(MAP SND p_es) = exp3_size p_es` >>
            rw[])
        >- (qspec_then `p_es` mp_tac exp_size_map_snd >>
            Cases_on `exp6_size(MAP SND p_es') = exp3_size p_es` >>
            rw[])
    );


val findLoc_ind = theorem "findLoc_ind";

val wf_findLoc_wf_findLocL = Q.store_thm ("wf_findLoc_wf_findLocL",
    `(∀ e locs . findLoc  e = locs ⇒ wf locs) ∧
    (∀ l locs . findLocL l = locs ⇒ wf locs)`,
    ho_match_mp_tac findLoc_ind >> rw[findLoc_def, wf_union] >> rw[wf_def] >>
    Cases_on `dest_GlobalVarInit op` >> fs[wf_insert]
);

val wf_findLocL = Q.store_thm("wf_findLocL",
    `∀ l . wf(findLocL l)`,
    metis_tac[wf_findLoc_wf_findLocL]
);

val wf_findLoc = Q.store_thm("wf_findLoc",
    `∀ e . wf(findLoc e)`,
    metis_tac[wf_findLoc_wf_findLocL]
);


(******** FINDLOOKUPS ********)

val findLookups_def = tDefine "findLookups" `
    (findLookups (Raise _ er) = findLookups er) ∧
    (findLookups (Handle _ eh p_es) = union (findLookups eh) (findLookupsL (MAP SND p_es))) ∧
    (findLookups (Lit _ _) = LN) ∧
    (findLookups (Con _ _ es) = findLookupsL es) ∧
    (findLookups (Var_local _ _) = LN) ∧
    (findLookups (Fun _ _ ef) = findLookups ef) ∧
    (findLookups (App _ op es) = (case (dest_GlobalVarLookup op) of
        | SOME n => (insert n () (findLookupsL es))
        | NONE => findLookupsL es)) ∧
    (findLookups (If _ ei1 ei2 ei3) = union (findLookups ei1) (union (findLookups ei2) (findLookups ei3))) ∧
    (findLookups (Mat _ em p_es) = union (findLookups em) (findLookupsL (MAP SND p_es))) ∧
    (findLookups (Let _ _ el1 el2) = union (findLookups el1) (findLookups el2)) ∧
    (findLookups (Letrec _ vv_es elr1) =  union (findLookupsL (MAP (SND o SND) vv_es)) (findLookups elr1)) ∧
    (findLookupsL [] = LN) ∧
    (findLookupsL (e::es) = union (findLookups e) (findLookupsL es))
`
    (
        WF_REL_TAC `measure (λ e . case e of
                | INL x => exp_size x
                | INR (y:flatLang$exp list) => flatLang$exp6_size y)` >> rw[exp_size_def]
        >- (qspec_then `vv_es` mp_tac exp_size_map_snd_snd >>
            Cases_on `exp6_size(MAP (λ x . SND (SND x)) vv_es) = exp1_size vv_es` >>
            rw[])
        >- (qspec_then `p_es` mp_tac exp_size_map_snd >>
            Cases_on `exp6_size(MAP SND p_es) = exp3_size p_es` >>
            rw[])
        >- (qspec_then `p_es` mp_tac exp_size_map_snd >>
            Cases_on `exp6_size(MAP SND p_es) = exp3_size p_es` >>
            rw[])
    );

val findLookups_ind = theorem "findLookups_ind";

(*** THEOREMS ***)

val wf_findLookups_wf_findLookupsL = Q.store_thm ("wf_findLookups_wf_findLookupsL",
    `(∀ e lookups . findLookups e = lookups ⇒ wf lookups) ∧
    (∀ l lookups . findLookupsL l = lookups ⇒ wf lookups)`,
    ho_match_mp_tac findLookups_ind >> rw[findLookups_def, wf_union] >> rw[wf_def] >>
    Cases_on `dest_GlobalVarLookup op` >> fs[wf_insert]
);

val wf_findLookupsL = Q.store_thm("wf_findLookupsL",
    `∀ l . wf(findLookupsL l)`,
    metis_tac[wf_findLookups_wf_findLookupsL]
);

val wf_findLookups = Q.store_thm("wf_findLookups",
    `∀ e . wf(findLookups e)`,
    metis_tac[wf_findLookups_wf_findLookupsL]
);

val findLookupsL_MEM = Q.store_thm("findLookupsL_MEM",
    `∀ e es . MEM e es ⇒ domain (findLookups e) ⊆ domain (findLookupsL es)`,
    Induct_on `es` >> rw[] >> fs[findLookups_def, domain_union] >> res_tac >> fs[SUBSET_DEF]
);

val findLookupsL_APPEND = Q.store_thm("findLookupsL_APPEND",
    `∀ l1 l2 . findLookupsL (l1 ++ l2) = union (findLookupsL l1) (findLookupsL l2)`,
    Induct >> fs[findLookups_def] >> fs[union_assoc]
);

val findLookupsL_REVERSE = Q.store_thm("findLookupsL_REVERSE",
    `∀ l . findLookupsL l = findLookupsL (REVERSE l)`,
    Induct >> fs[findLookups_def] >>
    fs[findLookupsL_APPEND, findLookups_def, union_num_set_sym]
);

val findLoc_EVERY_isEmpty = Q.store_thm("findLoc_EVERY_isEmpty",
    `∀ l reachable:num_set . EVERY (λ e . isEmpty (inter (findLoc e) reachable)) l ⇔ isEmpty (inter (findLocL l) reachable)`,
    Induct >- fs[Once findLoc_def, inter_def] >> fs[EVERY_DEF] >> rw[] >> EQ_TAC >> rw[] >>
        qpat_x_assum `isEmpty _` mp_tac >> simp[Once findLoc_def] >> fs[inter_union_empty]
);

(******************************************************** CODE ANALYSIS *********************************************************)

val analyseExp_def = Define `
    analyseExp e = let locs = (findLoc e) in let lookups = (findLookups e) in
        if isPure e then (
            if (isHidden e) then (LN, map (K lookups) locs)
            else (locs, map (K lookups) locs)
        ) else (
            (union locs lookups, (map (K LN) (union locs lookups)))
        )
`

val wf_analyseExp = Q.store_thm("wf_analyseExp",
    `∀ e roots tree . analyseExp e = (roots, tree) ⇒ (wf roots) ∧ (wf tree)`,
    simp[analyseExp_def] >> rw[] >>
    metis_tac[wf_def, wf_map, wf_union, wf_findLoc, wf_findLookups_wf_findLookupsL]
);

val analyseExp_domain = Q.store_thm("analyseExp_domain",
   `∀ e roots tree . analyseExp e = (roots, tree) ⇒ (domain roots ⊆ domain tree)`,
    simp[analyseExp_def] >> rw[] >> rw[domain_def, domain_map]
);

val analyseCode_def = Define `
    analyseCode [] = (LN, LN) ∧
    analyseCode ((Dlet e)::cs) = codeAnalysis_union (analyseExp e) (analyseCode cs) ∧
    analyseCode (_::cs) = analyseCode cs
`

val analyseCode_thm = Q.store_thm("analyseCode_thm",
    `∀ code root tree . analyseCode code = (root, tree)
    ⇒ (wf root) ∧ (domain root ⊆ domain tree)`,
    Induct
    >-(rw[analyseCode_def] >> rw[wf_def])
    >> Cases_on `h` >> simp[analyseCode_def] >> Cases_on `analyseExp e` >>
       Cases_on `analyseCode code` >>
       first_x_assum (qspecl_then [`q'`, `r'`] mp_tac) >> simp[] >>
       qspecl_then [`e`, `q`, `r`] mp_tac wf_analyseExp >> simp[] >> rw[]
       >- imp_res_tac wf_codeAnalysis_union
       >> qspecl_then [`e`, `q`, `r`] mp_tac analyseExp_domain >> rw[] >>
          imp_res_tac domain_codeAnalysis_union
);


(******************************************************** CODE REMOVAL *********************************************************)

val keep_def = Define `
    (keep reachable (Dlet e) =
        (* if none of the global variables that e may assign to are in
           the reachable set, then e is candidate for removal - if any are in, then keep e
            -> however if e is not pure (can have side-effects), then it must be kept *)
        if isEmpty (inter (findLoc e) reachable) then (¬ (isPure e)) else T) ∧
    (keep reachable _ = T) (* not a Dlet, will be Dtype/Dexn so keep *)
`

val keep_ind = theorem "keep_ind";

val keep_Dlet = Q.store_thm("keep_Dlet",
    `∀ (reachable:num_set) h . ¬ keep reachable h ⇒ ∃ x . h = Dlet x`,
   Cases_on `h` >> rw[keep_def]
);

val removeUnreachable_def = Define `
    removeUnreachable reachable l = FILTER (keep reachable) l
`

val removeFlatProg_def = Define `
    removeFlatProg code =
        let (r, t) = analyseCode code in
        let reachable = closure_spt r (mk_wf_set_tree t) in
        removeUnreachable reachable code
`


(******************************************************** REACHABILITY *********************************************************)

val analysis_reachable_thm = Q.store_thm("analysis_reachable_thm",
   `∀ (compiled : dec list) start tree t . ((start, t) = analyseCode compiled) ∧
        (tree = mk_wf_set_tree t)
    ⇒ domain (closure_spt start tree) = {a | ∃ n . isReachable tree n a ∧ n ∈ domain start}`
    ,
    rw[] >> qspecl_then [`mk_wf_set_tree t`, `start`] mp_tac closure_spt_thm >> rw[] >>
    `wf_set_tree(mk_wf_set_tree t)` by metis_tac[mk_wf_set_tree_thm] >>
    qspecl_then [`compiled`, `start`, `t`] mp_tac analyseCode_thm >>
    qspec_then `t` mp_tac mk_wf_set_tree_domain >> rw[] >> metis_tac[SUBSET_TRANS]
);


(******************************************************** TESTING *********************************************************)
(*
val flat_compile_def = Define `
    flat_compile c p =
        let (c',p) = source_to_flat$compile c p in p
`

val compile_to_flat_def = Define `compile_to_flat p = flat_compile empty_config p`;

val l = ``Locs (locn 1 2 3) (locn 1 2 3)``

val input = ``
    [Dlet ^l (* gl0 *) (Pvar "five") (Lit (IntLit 5));
     Dlet ^l (* gl1 *) (Pvar "f") (Fun "x" (Var (Short "five"))); (* f = λ x . five *)
     Dlet ^l (* gl2 *) (Pvar "g") (Fun "y" (Var (Short "y"))); (* g = λ y . y *)
     Dletrec ^l (* gl3 *) [("foo","i",App Opapp [Var (Short "f"); Lit (IntLit 0)])];
        (* foo = λ i . f 0 *)
     Dletrec ^l
       [("bar1","i",App Opapp [Var (Short "bar2"); Lit (IntLit 0)]); (*gl4*)
        ("bar2","i",App Opapp [Var (Short "bar1"); Lit (IntLit 0)])]; (*gl5*)
            (* bar1 = λ i . bar2 0  ∧  bar2 = λ i . bar1 0 *)
     Dlet ^l (* gl6 *) (Pvar "main") (App Opapp [Var (Short "f"); Lit (IntLit 0)]); (* main = f 0 *)
     Dletrec ^l (* gl 7 *) [("foobar", "x", App Opapp [Var (Short "foobar"); Lit (IntLit 0)])] ]
``

val test_compile_def = Define `
    test_compile code = compile_to_flat code
`

val test_analyse_roots_def = Define `
    test_analyse_roots code = domain (FST (analyseCode (test_compile code)))
`

val test_analyse_tree_def = Define `
    test_analyse_tree code = toAList (SND (analyseCode (test_compile code)))
`

val test_analyse_closure_def = Define `
    test_analyse_closure code =
        let (roots, tree) = analyseCode (test_compile code) in
        (closure_spt roots tree)
`

val test_analyse_removal_def = Define `
    test_analyse_removal code =
        let compiled = (test_compile code) in
        let (roots, tree) = analyseCode compiled in
        let reachable = (closure_spt roots tree) in
        removeUnreachable reachable compiled
`

val test_code = EVAL ``test_compile ^input``;
val test_result = EVAL ``test_analyse_removal ^input``;
*)

(*
    Overall:
    gl0 := "five" = 5
    gl1 := "f" = λ x . gl0 = "five"
    gl2 := "g" = λ y . y
    gl3 := "foo" = λ i . (gl1 = "f") 0
    gl4 := _ = λ i . (gl5) 0
    gl5 := _ = λ i . (gl4) 0
    gl6 := "main" = (gl1 = "f") 0
    gl7 := "foobar" = λ x . foobar 0
[
    ***** WHAT DOES THIS DO? *****
    Dlet (Let _ NONE (App _ (GlobalVarAlloc 7) []) (Con _ NONE [])); --> what does this do?

    GL0 ***** Match 5 => "five", stored in gl0 *****
    Dlet (Mat _ (Lit _ (IntLit 5))
        [(Pvar "five", App _ (GlobalVarInit 0) [Var_local _ "five"])]
    );

    GL1 ****** Match (λ x . lookup gl0) => "f", stored in gl1 (gl0 contains "five" = 5) *****
    Dlet (Mat _ (Fun _ "x" (App _ (GlobalVarLookup 0) []))
        [(Pvar "f",  App _ (GlobalVarInit 1) [Var_local _ "f"])]
    );

    GL 2 ***** Match (λ y . y) =>  "g", stored in gl2 *****
    Dlet (Mat _ (Fun _ "y" (Var_local _ "y"))
        [(Pvar "g", App _ (GlobalVarInit 2) [Var_local _ "g"])]
    );

    GL3 ***** gl3 := (letrec "foo" = λ i . (lookup gl1) 0)   --> i.e foo = (fn i => "f" 0) *****
    Dlet (App _ (GlobalVarInit 3)
        [Letrec _
            [( "foo","i", App _ Opapp [App _ (GlobalVarLookup 1) [];  Lit _ (IntLit 0)] )]
            (Var_local _ "foo")
        ]
    );

    GL4 ***** gl4 := (λ i . (lookup gl5) 0)  --> i.e. gl4 := ("bar1" = "bar2" 0) *****
    Dlet (App _ (GlobalVarInit 4) [Fun _ "i"
        (App _ Opapp [App _ (GlobalVarLookup 5) []; Lit _ (IntLit 0)])
    ] );

    GL5 ***** gl5 := (λ i . (lookup gl4) 0)  --> i.e. gl5 := ("bar1" = "bar2" 0) *****
    Dlet (App _ (GlobalVarInit 5) [Fun _ "i"
        (App _ Opapp [App _ (GlobalVarLookup 4) []; Lit _ (IntLit 0)])
    ] );

    GL6 ***** Match ((lookup 1) 0) => "main", stored in gl6  --> i.e. "main" = "f" 0 *****
    Dlet (Mat _ (App _ Opapp [App _ (GlobalVarLookup 1) []; Lit _ (IntLit 0)])
        [( Pvar "main", App _ (GlobalVarInit 6) [Var_local _ "main"] )]
    )

    GL7 ***** gl7 := (letrec "foobar" = λ x . foobar 0)   --> i.e foobar = (fn x => foobar 0) *****
    Dlet (Mat _ (App _ Opapp [App _ (GlobalVarLookup 1) []; Lit _ (IntLit 0)])
        [( Pvar "main", App _ (GlobalVarInit 6) [Var_local _ "main"] )]
    )
]
*)

val _ = export_theory();

