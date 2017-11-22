open preamble ml_translatorLib ml_translatorTheory ml_progLib
     mlvectorTheory IntProgTheory basisFunctionsLib
     ratLib gcdTheory ratTheory

val _ = new_theory"RatProg"

val _ = translation_extends "IntProg";

val _ = ml_prog_update (open_module "Rat");

val RAT_TYPE_def = Define `
  RAT_TYPE (r:rat) =
    \v. ?(n:int) (d:num). (r = (rat_of_int n) / &d) /\
                          gcd (Num (ABS n)) d = 1 /\ d <> 0 /\
                          PAIR_TYPE INT NUM (n,d) v`;

val _ = add_type_inv ``RAT_TYPE`` ``:(int # num)``;

val pair_of_num_def = Define `
  pair_of_num n = ((& (n:num)):int, 1:num)`;

val _ = next_ml_names := ["fromInt"];
val pair_of_num_v_thm = translate pair_of_num_def;

val Eval_RAT_NUM = Q.prove(
  `!v. (NUM --> PAIR_TYPE INT NUM) pair_of_num v ==>
       (NUM --> RAT_TYPE) ($&) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,RAT_TYPE_def,PULL_EXISTS,
                       FORALL_PROD] \\ rw [] \\ res_tac >>
  rename [‘empty_state with refs := R’] >>
  pop_assum (qspec_then ‘R’ strip_assume_tac) >>
  fs [] >> asm_exists_tac >> fs [] >>
  qexists_tac `& x` >> qexists_tac `1` >>
  fs [pair_of_num_def])
  |> (fn th => MATCH_MP th pair_of_num_v_thm)
  |> add_user_proved_v_thm;

val pair_le_def = Define `
  pair_le (n1,d1) (n2,d2) = (n1 * & d2 <= n2 * (& d1):int)`;

val _ = next_ml_names := ["<="];
val pair_le_v_thm = translate pair_le_def;

val _ = augment_srw_ss [intLib.INT_ARITH_ss]

val Eval_RAT_LE = Q.prove(
  `!v. (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM --> BOOL) pair_le v ==>
       (RAT_TYPE --> RAT_TYPE --> BOOL) ($<=) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,RAT_TYPE_def,PULL_EXISTS,
                       pair_le_def,FORALL_PROD] >> rw [] >>
  rename [‘empty_state with refs := R’] >>
  first_x_assum (first_assum o
                 mp_then.mp_then (mp_then.Pos hd)
                                 (qspec_then ‘R’ strip_assume_tac)) >>
  fs [] >> asm_exists_tac >> fs []
  >> rw [] >> first_x_assum drule
  >> qmatch_goalsub_rename_tac `(empty_state with refs := refs2)`
  >> disch_then (qspec_then `refs2` mp_tac)
  >> strip_tac >> rpt (asm_exists_tac >> fs []) >>
  rename [‘BOOL (n1 * &d1 ≤ n2 * &d2) bv’] >>
  `0q < &d1 ∧ 0q < &d2` by simp[] >>
  simp[RAT_LDIV_LEQ_POS, RDIV_MUL_OUT, RAT_RDIV_LEQ_POS] >>
  simp_tac bool_ss [GSYM rat_of_int_of_num, rat_of_int_MUL, rat_of_int_11,
                    rat_of_int_LE] >>
  fs[integerTheory.INT_MUL_COMM])
  |> (fn th => MATCH_MP th pair_le_v_thm)
  |> add_user_proved_v_thm;

val _ = next_ml_names := [">="];
val v = translate rat_geq_def;

val pair_lt_def = Define `
  pair_lt (n1,d1) (n2,d2) = (n1 * & d2 < n2 * (& d1):int)`;

val _ = next_ml_names := ["<"];
val pair_lt_v_thm = translate pair_lt_def;

val Eval_RAT_LT = Q.prove(
  `!v. (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM --> BOOL) pair_lt v ==>
       (RAT_TYPE --> RAT_TYPE --> BOOL) ($<) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,RAT_TYPE_def,PULL_EXISTS,
                       pair_lt_def,FORALL_PROD] \\ rw [] \\ res_tac
  \\ pop_assum (strip_assume_tac o SPEC_ALL)
  \\ fs [] \\ asm_exists_tac \\ fs []
  \\ rw [] \\ first_x_assum drule
  \\ qmatch_goalsub_rename_tac `(empty_state with refs := refs2)`
  \\ disch_then (qspec_then `refs2` mp_tac)
  \\ strip_tac \\ rpt (asm_exists_tac \\ fs [])
  \\ pop_assum mp_tac
  \\ ntac 2 (qpat_x_assum `~_` mp_tac)
  \\ rpt (pop_assum kall_tac)
  \\ fs [BOOL_def] \\ rw [] \\ rveq
  \\ EQ_TAC \\ rw [] >>
  rfs[RAT_LDIV_LES_POS, RDIV_MUL_OUT, RAT_RDIV_LES_POS] >>
  full_simp_tac bool_ss [GSYM rat_of_int_of_num, rat_of_int_MUL, rat_of_int_11,
                         rat_of_int_LT] >>
  fs[integerTheory.INT_MUL_COMM])
  |> (fn th => MATCH_MP th pair_lt_v_thm)
  |> add_user_proved_v_thm;

val _ = next_ml_names := [">"];
val v = translate rat_gre_def;

val _ = next_ml_names := ["min"];
val v = translate rat_min_def;

val _ = next_ml_names := ["max"];
val v = translate rat_max_def;

val div_gcd_def = Define `
  div_gcd a b =
    let d = gcd (num_of_int a) b in
      if d = 0 \/ d = 1 then (a,b) else (a / &d, b DIV d)`;

val res = translate div_gcd_def;

val gcd_LESS_EQ = prove(
  ``!m n. n <> 0 ==> gcd$gcd m n <= n``,
  recInduct gcd_ind \\ rw []
  \\ once_rewrite_tac [gcdTheory.gcd_def]
  \\ rw [] \\ fs []);

val DIV_EQ_0 = Q.store_thm(
  "DIV_EQ_0",
  ‘0 < n ==> ((m DIV n = 0) <=> m < n)’,
  strip_tac >> IMP_RES_THEN mp_tac DIVISION >>
  rpt (disch_then (qspec_then `m` assume_tac)) >>
  qabbrev_tac `q = m DIV n` >> qabbrev_tac `r = m MOD n` >>
  RM_ALL_ABBREVS_TAC >> rw[] >> eq_tac >> simp[] >>
  Cases_on ‘q’ >> simp[MULT_CLAUSES]);

val DIV_GCD_NONZERO = Q.store_thm(
  "DIV_GCD_NONZERO",
  ‘(0 < m ==> 0 < m DIV gcd m n) /\ (0 < n ==> 0 < n DIV gcd m n)’,
  rw[] >> ‘gcd m n <> 0’ by simp[GCD_EQ_0]
  >- (‘~(m < gcd m n)’
        by metis_tac[dividesTheory.NOT_LT_DIVIDES,
                     GCD_IS_GREATEST_COMMON_DIVISOR] >>
      spose_not_then assume_tac >>
      rev_full_simp_tac bool_ss
        [DIV_EQ_0, arithmeticTheory.NOT_LT_ZERO_EQ_ZERO,
         arithmeticTheory.NOT_ZERO_LT_ZERO])
  >- (‘~(n < gcd m n)’
        by metis_tac[dividesTheory.NOT_LT_DIVIDES,
                     GCD_IS_GREATEST_COMMON_DIVISOR] >>
      spose_not_then assume_tac >>
      rev_full_simp_tac bool_ss
        [DIV_EQ_0, arithmeticTheory.NOT_LT_ZERO_EQ_ZERO,
         arithmeticTheory.NOT_ZERO_LT_ZERO]));

val INT_NEG_DIV_FACTOR = Q.prove(
  ‘0 < (x:num) ==> (-&(x * y):int / &x = -&y)’,
  strip_tac >> qspec_then ‘&x’ mp_tac integerTheory.INT_DIVISION >>
  simp[] >> disch_then (qspec_then ‘-&(x * y)’ strip_assume_tac) >>
  map_every qabbrev_tac [`D:int = -&(x * y)`, `q = D / &x`, `r = D % &x`] >>
  Q.UNABBREV_TAC `D` >>
  qpat_x_assum `_ = _` mp_tac >>
  disch_then (mp_tac o Q.AP_TERM `int_add &(x:num * y)` ) >>
  simp_tac bool_ss [integerTheory.INT_ADD_RINV] >>
  qmatch_abbrev_tac `0i = RHS ==> q:int = -&y` >>
  ‘RHS = (q + &y) * &x + r’ by simp[Abbr‘RHS’] >>
  Q.UNABBREV_TAC ‘RHS’ >> pop_assum SUBST_ALL_TAC >>
  ‘∃rn. r = &rn’ by (Cases_on ‘r’ >> simp[] >> fs[]) >>
  pop_assum SUBST_ALL_TAC >> fs[] >>
  Cases_on ‘q + &y’
  >- (rename [‘q + &y = &n’] >> simp[integerTheory.INT_ADD])
  >- (rename [‘q + &y = -&n’] >>
      disch_then (mp_tac o Q.AP_TERM ‘int_add (&n * &x)’) >>
      simp_tac bool_ss [integerTheory.INT_ADD_ASSOC,
                        integerTheory.INT_ADD_RID,
                        GSYM integerTheory.INT_NEG_LMUL,
                        integerTheory.INT_ADD_RINV] >> simp[] >>
      Cases_on ‘n’ >> simp[MULT_CLAUSES] >> fs[])
  >- (rename [‘q + &y = 0’] >> disch_then kall_tac >>
      ‘q + &y + -&y = -&y’ by metis_tac [integerTheory.INT_ADD_LID] >>
      metis_tac[integerTheory.INT_ADD_ASSOC, integerTheory.INT_ADD_RID,
                integerTheory.INT_ADD_RINV]))

val PAIR_TYPE_IMP_RAT_TYPE = prove(
  ``r = rat_of_int m / & n /\ n <> 0 ==>
    PAIR_TYPE INT NUM (div_gcd m n) v ==> RAT_TYPE r v``,
  fs [RAT_TYPE_def,div_gcd_def] \\ rw [] >>
  goal_assum (first_assum o mp_then (Pos last) mp_tac)
  >- fs[num_of_int_def] >>
  `gcd$gcd (num_of_int m) n <> 0` by fs [] >>
  `0 < gcd$gcd (num_of_int m) n` by simp [] >>
  Cases_on `m` \\ simp [ZERO_DIV, integerTheory.INT_DIV] >>
  fs [DIV_EQ_X,NOT_LESS,gcd_LESS_EQ] >> rename1 `gcd$gcd m n <> 1` >>
  ‘0 < n DIV gcd m n ∧ 0 < m DIV gcd m n’ by simp[DIV_GCD_NONZERO] >>
  simp[RAT_LDIV_EQ, RDIV_MUL_OUT, RAT_RDIV_EQ, integerTheory.INT_ABS_NUM]
  >- (simp[RAT_MUL_NUM_CALCULATE] >>
      qspecl_then [‘m’, ‘n’] mp_tac FACTOR_OUT_GCD >> simp[] >>
      disch_then (qx_choosel_then [‘p’, ‘q’] strip_assume_tac) >>
      qabbrev_tac ‘G = gcd$gcd m n’ >> simp[] >>
      ‘G * q DIV G = q ∧ G * p DIV G = p’ by metis_tac [MULT_COMM, MULT_DIV] >>
      simp[]) >>
  qspecl_then [‘m’, ‘n’] mp_tac FACTOR_OUT_GCD >> simp[] >>
  disch_then (qx_choosel_then [‘p’, ‘q’] strip_assume_tac) >>
  qabbrev_tac ‘G = gcd$gcd m n’ >> simp[] >>
  ‘G * q DIV G = q ∧ G * p DIV G = p’ by metis_tac [MULT_COMM, MULT_DIV] >>
  simp[INT_NEG_DIV_FACTOR, integerTheory.INT_ABS_NEG,
       integerTheory.INT_ABS_NUM, rat_of_int_ainv] >>
  simp[RAT_MUL_NUM_CALCULATE]);

val pair_add_def = Define `
  pair_add (n1:int, d1:num) (n2, d2) =
    div_gcd ((n1 * &d2) + (n2 * &d1)) (d1 * d2)`;

val _ = next_ml_names := ["+"];
val pair_add_v_thm = translate pair_add_def;

val abs_rat_ONTO = Q.prove(
  ‘!r. ?f. abs_rat f = r’,
  gen_tac >> qexists_tac ‘rep_rat r’ >> simp[rat_type_thm]);

val Eval_RAT_ADD = Q.prove(
  `!v.
     (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM) pair_add v
       ==>
     (RAT_TYPE --> RAT_TYPE --> RAT_TYPE) ($+) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,PULL_EXISTS,
                       pair_add_def,FORALL_PROD] >> rw [] >> res_tac >>
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,PULL_EXISTS,
                       pair_add_def,FORALL_PROD] \\ rw [] \\ res_tac >>
  pop_assum (strip_assume_tac o SPEC_ALL) >>
  fs [] \\ asm_exists_tac \\ fs [] >>
  rw [] \\ first_x_assum drule >>
  qmatch_goalsub_rename_tac `(empty_state with refs := refs2)` >>
  disch_then (qspec_then `refs2` mp_tac) >>
  strip_tac \\ rpt (asm_exists_tac \\ fs []) >>
  pop_assum mp_tac >>
  ntac 2 (qpat_x_assum `~_` mp_tac) >>
  rpt (pop_assum kall_tac) \\ rw [] \\ pop_assum mp_tac >>
  match_mp_tac PAIR_TYPE_IMP_RAT_TYPE >>
  simp[GSYM RAT_NO_ZERODIV] >>
  simp[RAT_DIVDIV_ADD] >>
  simp_tac bool_ss[GSYM rat_of_int_of_num, rat_of_int_MUL, rat_of_int_ADD,
                   integerTheory.INT_MUL])
  |> (fn th => MATCH_MP th pair_add_v_thm)
  |> add_user_proved_v_thm;

val pair_sub_def = Define `
  pair_sub (n1:int, d1:num) (n2, d2) =
    div_gcd ((n1 * &d2) - (n2 * &d1)) (d1 * d2)`;

val _ = next_ml_names := ["-"];
val pair_sub_v_thm = translate pair_sub_def;

val Eval_RAT_SUB = Q.prove(
  `!v. (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM) pair_sub v ==>
       (RAT_TYPE --> RAT_TYPE --> RAT_TYPE) ($-) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,PULL_EXISTS,
                       pair_sub_def,FORALL_PROD] \\ rw [] \\ res_tac
  \\ SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,
                          PULL_EXISTS, pair_add_def,FORALL_PROD] >> rw [] >>
  res_tac >> pop_assum (strip_assume_tac o SPEC_ALL)
  \\ fs [] \\ asm_exists_tac \\ fs []
  \\ rw [] \\ first_x_assum drule
  \\ qmatch_goalsub_rename_tac `(empty_state with refs := refs2)`
  \\ disch_then (qspec_then `refs2` mp_tac)
  \\ strip_tac \\ rpt (asm_exists_tac \\ fs [])
  \\ pop_assum mp_tac
  \\ ntac 2 (qpat_x_assum `~_` mp_tac)
  \\ rpt (pop_assum kall_tac) \\ rw [] \\ pop_assum mp_tac
  \\ match_mp_tac PAIR_TYPE_IMP_RAT_TYPE >>
  simp[GSYM RAT_NO_ZERODIV, RAT_SUB_ADDAINV, RAT_DIV_AINV,
       GSYM rat_of_int_ainv, RAT_DIVDIV_ADD,
       integerTheory.INT_SUB_CALCULATE, integerTheory.INT_NEG_LMUL] >>
  simp_tac bool_ss[GSYM rat_of_int_of_num, rat_of_int_MUL, rat_of_int_ADD,
                   integerTheory.INT_MUL])
  |> (fn th => MATCH_MP th pair_sub_v_thm)
  |> add_user_proved_v_thm;

val rat_neg_lem = prove(
  ``!(x:rat). - x = 0 - x``,
  fs[]);

val _ = next_ml_names := ["~"];
val pair_neg_v_thm = translate rat_neg_lem;

val pair_mul_def = Define `
  pair_mul (n1,d1) (n2,d2) = div_gcd (n1 * n2:int) (d1 * d2:num)`;

val _ = next_ml_names := ["*"];
val pair_mul_v_thm = translate pair_mul_def;

val Eval_RAT_MUL = Q.prove(
  `!v.
    (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM) pair_mul v
      ==>
    (RAT_TYPE --> RAT_TYPE --> RAT_TYPE) ($*) v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,PULL_EXISTS,
                       pair_mul_def,FORALL_PROD] \\ rw [] \\ res_tac
  \\ SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,Once RAT_TYPE_def,
                          PULL_EXISTS, pair_add_def,FORALL_PROD] \\ rw []
  \\ res_tac
  \\ pop_assum (strip_assume_tac o SPEC_ALL)
  \\ fs [] \\ asm_exists_tac \\ fs []
  \\ rw [] \\ first_x_assum drule
  \\ qmatch_goalsub_rename_tac `(empty_state with refs := refs2)`
  \\ disch_then (qspec_then `refs2` mp_tac)
  \\ strip_tac \\ rpt (asm_exists_tac \\ fs [])
  \\ pop_assum mp_tac
  \\ ntac 2 (qpat_x_assum `~_` mp_tac)
  \\ rpt (pop_assum kall_tac) \\ rw [] \\ pop_assum mp_tac
  \\ match_mp_tac PAIR_TYPE_IMP_RAT_TYPE
  \\ simp [RAT_DIVDIV_MUL, rat_of_int_MUL, RAT_MUL_NUM_CALCULATE])
  |> (fn th => MATCH_MP th pair_mul_v_thm)
  |> add_user_proved_v_thm;

val pair_inv_def = Define `
  pair_inv (n1,d1) =
    (if n1 < 0 then - & d1 else (& d1):int,num_of_int n1)`;

val _ = next_ml_names := ["inv"];
val pair_inv_v_thm = translate pair_inv_def;

val Eval_RAT_INV = Q.prove(
  `PRECONDITION (r <> 0) ==>
   !v. (PAIR_TYPE INT NUM --> PAIR_TYPE INT NUM) pair_inv v ==>
       (Eq RAT_TYPE r --> RAT_TYPE) rat_minv v`,
  SIMP_TAC (srw_ss()) [Arrow_def,AppReturns_def,RAT_TYPE_def,PULL_EXISTS,
                       pair_mul_def,FORALL_PROD,Eq_def,PRECONDITION_def]
  \\ rw [] \\ res_tac
  \\ pop_assum (strip_assume_tac o SPEC_ALL)
  \\ fs [] \\ asm_exists_tac \\ fs []
  \\ rw [] \\ first_x_assum drule
  \\ disch_then (qspec_then `refs` mp_tac)
  \\ strip_tac \\ rpt (asm_exists_tac \\ fs [])
  \\ rename [‘pair_inv (n,d)’]
  \\ ‘rat_of_int n ≠ 0’ by (strip_tac >> fs[])
  \\ simp [RAT_DIV_MINV] >>
  Cases_on ‘n’ >> fs[]
  >- (rename [‘&d / &m = _’, ‘m ≠ 0’] >>
      map_every qexists_tac [‘&d’, ‘m’] >>
      fs[integerTheory.INT_ABS_NUM, pair_inv_def, GCD_SYM])
  >- (rename [‘rat_of_int (-&m) ≠ 0’, ‘pair_inv (-&m, d)’] >>
      map_every qexists_tac [‘-&d’, ‘m’] >>
      fs[integerTheory.INT_ABS_NEG, integerTheory.INT_ABS_NUM,
         rat_of_int_ainv, pair_inv_def, GCD_SYM] >>
      simp[RAT_DIV_MULMINV, GSYM RAT_AINV_MINV, GSYM RAT_AINV_LMUL,
           GSYM RAT_AINV_RMUL]))
  |> UNDISCH
  |> (fn th => MATCH_MP th pair_inv_v_thm)
  |> add_user_proved_v_thm;

val _ = (next_ml_names := ["/"])
val pair_div_v_thm = translate ratTheory.RAT_DIV_MULMINV;

val pair_div_side_def = pair_div_v_thm
  |> hyp |> hd |> rand |> repeat rator |> DB.match [] |> hd |> snd |> fst;

val pair_div_v_thm =
  pair_div_v_thm
  |> DISCH_ALL |> REWRITE_RULE [pair_div_side_def] |> UNDISCH_ALL
  |> add_user_proved_v_thm;

val toString_def = Define `
  toString (i:int,n:num) =
    if n = 1 then mlint$toString i else
      concat [mlint$toString i ; implode"/" ; mlint$toString (& n)]`

val _ = (next_ml_names := ["toString"]);
val v = translate toString_def;

val EqualityType_RAT_TYPE = store_thm("EqualityType_RAT_TYPE",
  ``EqualityType RAT_TYPE``,
  rw [EqualityType_def]
  \\ fs [RAT_TYPE_def,PAIR_TYPE_def,INT_def,NUM_def] \\ EVAL_TAC
  \\ rveq \\ fs []
  \\ EQ_TAC \\ strip_tac \\ fs []
  \\ fs [GSYM rat_of_int_def] >>
  rename [‘rat_of_int n1 / &d1 = rat_of_int n2 / &d2’] >>
  Cases_on `d1 = d2` >> rveq
  >- rfs[RAT_MINV_EQ_0, RAT_DIV_MULMINV, RAT_EQ_RMUL] >>
  fs[] >>
  `(rat_of_int n1 / &d1) * (&d1 * &d2) = (rat_of_int n2 / &d2) * (&d1 * &d2)`
    by fs [RAT_EQ_RMUL] >>
  `rat_of_int n1 / &d1 * &d1 = rat_of_int n1`
     by (simp_tac bool_ss [RAT_DIV_MULMINV] >>
         metis_tac[RAT_MUL_LINV, RAT_MUL_ASSOC, RAT_MUL_RID,
                   RAT_EQ_NUM_CALCULATE]) >>
  `rat_of_int n2 / &d2 * &d2 = rat_of_int n2`
     by (simp_tac bool_ss [RAT_DIV_MULMINV] >>
         metis_tac[RAT_MUL_LINV, RAT_MUL_ASSOC, RAT_MUL_RID,
                   RAT_EQ_NUM_CALCULATE]) >>
  `rat_of_int n1 * & d2 = rat_of_int n2 * & d1`
     by metis_tac [RAT_MUL_ASSOC,RAT_MUL_COMM] >>
  pop_assum mp_tac >>
  ntac 3 (pop_assum kall_tac) >> fs [] >>
  Cases_on `n1` >> Cases_on `n2` >>
  fs [integerTheory.INT_ABS_NUM, integerTheory.INT_ABS_NEG,
      rat_of_int_ainv, RAT_MUL_NUM_CALCULATE] >>
  rfs [RAT_DIV_EQ0] >> strip_tac >>
  rename [`d1 * n1 = d2 * n2:num`]
  \\ `divides d2 (d1 * n1) /\
      divides n2 (d1 * n1) /\
      divides d1 (d2 * n2) /\
      divides n1 (d2 * n2)` by
     (fs [dividesTheory.divides_def] \\ metis_tac [MULT_COMM])
  \\ `gcd d1 n2 = 1 /\ gcd d2 n1 = 1` by metis_tac [GCD_SYM]
  \\ fs []
  \\ imp_res_tac L_EUCLIDES
  \\ imp_res_tac dividesTheory.DIVIDES_ANTISYM
  \\ rveq \\ rfs [arithmeticTheory.EQ_MULT_RCANCEL])
  |> store_eq_thm;

val _ = ml_prog_update (close_module NONE);

val _ = export_theory ()
