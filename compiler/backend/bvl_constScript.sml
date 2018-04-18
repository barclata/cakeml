open preamble bvlTheory

val _ = new_theory "bvl_const";

val _ = patternMatchesLib.ENABLE_PMATCH_CASES();
(*

   This is a BVL transformation that propagates simple and
   cheap-to-compute context-free expression from Let bindings. It also
   performs some simple constant folding with SmartOp (below).

   The most significant impact of this optimisation is that it removes
   each Var in a Let, i.e. Let [...; Var ...; ...] ..., and replaces
   them with constants Let [...; Op (Const _) []; ...] .... and
   replaces all occurrences of the bound var with a lookup to the
   original variable.

   bvi_let is a simpler version of this optimisation.

*)

val dest_simple_def = Define `
  (dest_simple (bvl$Op (Const i) xs) = if NULL xs then SOME i else NONE) /\
  (dest_simple _ = NONE)`;
val _ = export_rewrites["dest_simple_def"];

val dest_simple_pmatch = Q.store_thm("dest_simple_pmatch",`
  ∀op. dest_simple op =
    case op of
      bvl$Op (Const i) [] => SOME i
    | _ => NONE`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[dest_simple_def]);

val case_op_const_def = Define `
    case_op_const exp =
        dtcase exp of
        | (Op op [x1; Op (Const n2) l]) => if NULL l then SOME (op, x1, n2) else NONE
        | _ => NONE
`

val case_op_const_pmatch = Q.store_thm("case_op_const_pmatch",`
  ∀exp. case_op_const exp =
    case exp of
      | (Op op [x1; Op (Const n2) []]) => SOME (op, x1, n2)
      | _ => NONE`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[case_op_const_def]);

val SmartOp_flip_def = Define `
    SmartOp_flip op x1 x2 =
      dtcase (dest_simple x1) of
      | (SOME i) =>
          if MEM op [Add; Mult] then (op, x2, x1)
          else if op = Sub then (Add, x2, Op (Const (-i)) [])
          else (op, x1, x2)
      | _ => (op, x1, x2)
`

val SmartOp_flip_pmatch = Q.store_thm("SmartOp_flip_pmatch",`
    !op x1 x2. SmartOp_flip op x1 x2 =
    case (dest_simple x1) of
    | (SOME i) =>
        if MEM op [Add; Mult] then (op, x2, x1)
        else if op = Sub then (Add, x2, Op (Const (-i)) [])
        else (op, x1, x2)
    | _ => (op, x1, x2)
`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[SmartOp_flip_def]
);

local val SmartOp2_quotation = `
  SmartOp2 (op, x1:bvl$exp, x2:bvl$exp) =
    let mk_add_const x1 c2 =
      if c2 = 0 then x1
      else Op Add [x1; Op (Const c2) []]
    in
    let mk_add x1 x2 =
      let default = Op Add [x1; x2] in
        dtcase (dest_simple x2) of
        | (SOME n2) => (
            dtcase (case_op_const x1) of
            | SOME (op, x11, n12) =>
                if op = Add then mk_add_const x11 (n2+n12)
                else if op = Sub then Op Sub [x11; Op (Const (n2+n12)) []]
                else default
            | _ =>
                dtcase (dest_simple x1) of
                | SOME n1 => Op (Const (n2+n1)) []
                | _ => mk_add_const x1 n2
        )
        | _ => default
    in
    let mk_sub x1 x2 =
      let default = Op Sub [x1; x2] in
        dtcase (dest_simple x2) of
        | (SOME n2) => (
            dtcase (case_op_const x1) of
            | SOME (op, x11, n12) =>
                if op = Add then Op Sub [x11; Op (Const (n2-n12)) []]
                else if op = Sub then mk_add_const x11 (n2-n12)
                else default
            | _ =>
                dtcase (dest_simple x1) of
                | SOME n1 => Op (Const (n2-n1)) []
                | _ => default
        )
        | _ => default
    in
    let mk_mul x1 x2 =
      let default = Op Mult [x1; x2] in
        dtcase (dest_simple x2) of
        | (SOME n2) => (
            dtcase (case_op_const x1) of
            | SOME (op, x11, n12) =>
                if op = Mult then Op Mult [x11; Op (Const (n2*n12)) []]
                else default
            | _ =>
                dtcase (dest_simple x1) of
                | SOME n1 => Op (Const (n2*n1)) []
                | _ =>
                    if n2 = 1 then x1
                    else if n2 = -1 then mk_sub x1 (Op (Const 0) [])
                    else default
        )
        | _ => default
    in
    let default = Op op [x1;x2] in
    if op = Add then
      mk_add x1 x2
    else if op = Sub then
      mk_sub x1 x2
    else if op = Mult then
      mk_mul x1 x2
    else if MEM op [Div; Mod; Less; LessEq; Greater; GreaterEq] then
      dtcase (dest_simple x1, dest_simple x2) of
      | (SOME x1, SOME (x2:int)) =>
          (dtcase op of
           | Div => if x1 = 0 then default else Op (Const (x2 / x1)) []
           | Mod => if x1 = 0 then default else Op (Const (x2 % x1)) []
           | Less => Bool (x2 < x1)
           | LessEq => Bool (x2 <= x1)
           | Greater => Bool (x2 > x1)
           | GreaterEq => Bool (x2 >= x1)
           | _ => default)
      | _ => default
    else if op = Equal then
      dtcase (dest_simple x1, dest_simple x2) of
      | (SOME i, SOME j) => Bool (j = i)
      | (SOME i, _) => Op (EqualInt i) [x2]
      | (_, SOME i) => Op (EqualInt i) [x1]
      | _ => default
    else default`
in
val SmartOp2_def = Define SmartOp2_quotation

val SmartOp2_pmatch = Q.store_thm("SmartOp2_pmatch",
  SmartOp2_quotation |>
   map (fn QUOTE s => Portable.replace_string {from="dtcase",to="case"} s |> QUOTE
       | aq => aq),
  CONV_TAC (DEPTH_CONV patternMatchesLib.PMATCH_ELIM_CONV) >>
  simp [SmartOp2_def]);
end

val SmartOp_def = Define `
  (SmartOp op [x1; x2] = SmartOp2 (SmartOp_flip op x1 x2)) /\
  (SmartOp op xs = Op op xs)
`

val SmartOp_pmatch = Q.store_thm("SmartOp_pmatch",`
    !op xs. SmartOp op xs =
      case xs of
      | [x1;x2] => SmartOp2 (SmartOp_flip op x1 x2)
      | _ => Op op xs`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[SmartOp_def]
)

val extract_def = Define `
  (extract ((Var n):bvl$exp) ys = SOME ((Var (n + LENGTH ys + 1)):bvl$exp)) /\
  (extract (Op (Const i) xs) ys = SOME (Op (Const i) [])) /\
  (extract (Op (Cons t) xs) ys =
    if NULL xs then SOME (Op (Cons t) []) else NONE) /\
  (extract _ _ = NONE)`

val extract_pmatch = Q.store_thm("extract_pmatch",`
  ∀op ys. extract op ys =
    case op of
      (Var n):bvl$exp => SOME ((Var (n + LENGTH ys + 1)):bvl$exp)
    | Op (Const i) xs => SOME (Op (Const i) [])
    | Op (Cons t) [] => SOME (Op (Cons t) [])
    | _ => NONE`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[extract_def]);

val extract_list_def = Define `
  (extract_list [] = []) /\
  (extract_list (x::xs) = extract x xs :: extract_list xs)`

val delete_var_def = Define `
  (delete_var ((Var n):bvl$exp) = Op (Const 0) []) /\
  (delete_var x = x)`;

val delete_var_pmatch = Q.store_thm("delete_var_pmatch",`!op.
  delete_var op =
    case op of
      Var n => Op (Const 0) []
    | x => x`,
  rpt strip_tac
  >> rpt(CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac)
  >> fs[delete_var_def])

val compile_def = tDefine "compile" `
  (compile env [] = []) /\
  (compile env (x::y::xs) = compile env [x] ++ compile env (y::xs)) /\
  (compile env [Var v] =
     dtcase LLOOKUP env v of
     | NONE => [Var v]
     | SOME NONE => [Var v]
     | SOME (SOME (Var i)) => [Var (v + i)]
     | SOME (SOME x) => [x]) /\
  (compile env [If x1 x2 x3] =
     let y1 = HD (compile env [x1]) in
     let y2 = HD (compile env [x2]) in
     let y3 = HD (compile env [x3]) in
       if y1 = Bool T then [y2] else
       if y1 = Bool F then [y3] else
         [If y1 y2 y3]) /\
  (compile env [Let xs x2] =
     let ys = compile env xs in
       [Let (MAP delete_var ys)
            (HD (compile (extract_list ys ++ env) [x2]))]) /\
  (compile env [Handle x1 x2] =
     [Handle (HD (compile env [x1])) (HD (compile (NONE::env) [x2]))]) /\
  (compile env [Raise x1] =
     [Raise (HD (compile env [x1]))]) /\
  (compile env [Op op xs] = [SmartOp op (compile env xs)]) /\
  (compile env [Tick x] = [Tick (HD (compile env [x]))]) /\
  (compile env [Call t dest xs] = [Call t dest (compile env xs)])`
  (WF_REL_TAC `measure (exp1_size o SND)`);

val compile_ind = theorem"compile_ind";

val compile_length = Q.store_thm("compile_length[simp]",
  `!n xs. LENGTH (compile n xs) = LENGTH xs`,
  HO_MATCH_MP_TAC compile_ind \\ REPEAT STRIP_TAC
  \\ FULL_SIMP_TAC (srw_ss()) [compile_def,ADD1,LET_DEF]
  \\ every_case_tac \\ SRW_TAC [] [] \\ DECIDE_TAC);

val compile_HD_SING = Q.store_thm("compile_HD_SING",
  `[HD (compile n [x])] = compile n [x]`,
  MP_TAC (Q.SPECL [`n`,`[x]`] compile_length)
  \\ Cases_on `compile n [x]` \\ fs [LENGTH_NIL]);

val compile_exp_def = Define `
  compile_exp x = dtcase compile [] [x] of (y::_) => y | _ => Var 0 (* impossible *)`;

val _ = export_theory();
