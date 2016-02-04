(*Generated by Lem from toBytecode.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_stringTheory libTheory astTheory intLangTheory toIntLangTheory bytecodeTheory patLangTheory conLangTheory;

val _ = numLib.prefer_num();



val _ = new_theory "toBytecode"

(* Intermediate Language to Bytecode *)

(*open import Pervasives*)
(*import String*)

(*open import Lib*)
(*open import Ast*)
(*open import IntLang*)
(*open import ToIntLang*)
(*open import Bytecode*)
(*open import PatLang*)
(*import ConLang*)

(* pull closure bodies into code environment *)

 val _ = Define `
 (bind_fv (az,e) nz ix =  
(let fvs = (free_vars e) in
  let recs = (FILTER (\ v .  MEM (az+v) fvs /\ ~ (v=ix)) (GENLIST (\ n .  n) nz)) in
  let envs = (FILTER (\ v .  (az+nz) <= v) fvs) in
  let envs = (MAP (\ v .  v -(az+nz)) envs) in
  let rz = (LENGTH recs+ 1) in
  let e = (mkshift (\ v .  if v < nz then the( 0) (misc$find_index v (ix::recs)( 0))
                            else the( 0) (misc$find_index (v - nz) envs rz))
                  az e) in
  let rz = (rz -  1) in
  (((GENLIST (\ i .  CCArg ( 2+i)) (az+ 1))
   ++((GENLIST CCRef rz)
   ++(GENLIST (\ i .  CCEnv (rz+i)) (LENGTH envs))))
  ,(recs,envs)
  ,e
  )))`;


 val label_closures_defn = Hol_defn "label_closures" `

(label_closures ez j (CRaise e) =  
(let (e,j) = (label_closures ez j e) in
  (CRaise e, j)))
/\
(label_closures ez j (CHandle e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures (ez+ 1) j e2) in
  (CHandle e1 e2, j)))
/\
(label_closures _ j (CVar x) = (CVar x, j))
/\
(label_closures _ j (CGvar x) = (CGvar x, j))
/\
(label_closures _ j (CLit l) = (CLit l, j))
/\
(label_closures ez j (CCon cn es) =  
(let (es,j) = (label_closures_list ez j es) in
  (CCon cn es,j)))
/\
(label_closures ez j (CLet bd e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures (if bd then ez+ 1 else ez) j e2) in
  (CLet bd e1 e2, j)))
/\
(label_closures ez j (CLetrec defs e) =  
(let defs = (MAP SND (FILTER (IS_NONE o FST) defs)) in
  let nz = (LENGTH defs) in
  let (defs,j) = (label_closures_defs ez j nz( 0) defs) in
  let (e,j) = (label_closures (ez+nz) j e) in
  (CLetrec defs e, j)))
/\
(label_closures ez j (CCall ck e es) =  
(let (e,j) = (label_closures ez j e) in
  let (es,j) = (label_closures_list ez j es) in
  (CCall ck e es,j)))
/\
(label_closures ez j (CPrim1 p1 e) =  
(let (e,j) = (label_closures ez j e) in
  (CPrim1 p1 e, j)))
/\
(label_closures ez j (CPrim2 p2 e1 e2) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  (CPrim2 p2 e1 e2, j)))
/\
(label_closures ez j (CUpd b e1 e2 e3) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  let (e3,j) = (label_closures ez j e3) in
  (CUpd b e1 e2 e3, j)))
/\
(label_closures ez j (CIf e1 e2 e3) =  
(let (e1,j) = (label_closures ez j e1) in
  let (e2,j) = (label_closures ez j e2) in
  let (e3,j) = (label_closures ez j e3) in
  (CIf e1 e2 e3, j)))
/\
(label_closures _ j (CExtG n) = (CExtG n, j))
/\
(label_closures_list _ j [] = ([],j))
/\
(label_closures_list ez j (e::es) =  
(let (e,j) = (label_closures ez j e) in
  let (es,j) = (label_closures_list ez j es) in
  ((e::es),j)))
/\
(label_closures_defs _ j _ _ [] = ([], j))
/\
(label_closures_defs ez ld nz k ((az,b)::defs) =  
(let (ccenv,ceenv,b) = (bind_fv (az,b) nz k) in
  let cz = (((az + LENGTH (FST ceenv)) + LENGTH (SND ceenv)) + 1) in
  let (b,j) = (label_closures cz (ld+ 1) b) in
  let (defs,j) = (label_closures_defs ez j nz (k+ 1) defs) in
  (((SOME (ld,(ccenv,ceenv)),(az,b))::defs), j)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn label_closures_defn;

val _ = Hol_datatype `
 call_context = TCNonTail | TCTail of num => num`;

(* TCTail j k = in tail position,
   * the called function has j arguments, and
   * k let variables have been bound *)
(* TCNonTail = in tail position, or called from top-level *)

val _ = Hol_datatype `
 compiler_result =
  <| out: bc_inst list (* reversed code *)
   ; next_label: num
   |>`;


(*val maxPushInt : integer*)
val _ = Define `
 (maxPushInt =(( 200000000 : int)))`;

(*val PushAnyInt : integer -> list bc_inst*)
 val PushAnyInt_defn = Hol_defn "PushAnyInt" `
 (PushAnyInt i =  
(if i <( 0 : int) then    
([Stack(PushInt(( 0 : int)))] ++ PushAnyInt (~ i)) ++ [Stack(Sub)]
  else if i <= maxPushInt then
    [Stack(PushInt i)]
  else
    let q = (i/maxPushInt) in let r = (i % maxPushInt) in    
(PushAnyInt q ++ [Stack(PushInt maxPushInt); Stack(Mult)]) ++    
(if r =( 0 : int) then [] else [Stack(PushInt r); Stack(Add)])))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn PushAnyInt_defn;

(*val VfromListLab : nat*)
val _ = Define `
 (VfromListLab =( 0))`;

(*val VfromListCode : list bc_inst*)
val _ = Define `
 (VfromListCode = ([
  Label VfromListLab;
  Stack (PushInt(( 0 : int)));
  Label (VfromListLab+ 1);
  Stack (Load( 1));
  Stack (TagEq (block_tag+conLang$nil_tag));
  JumpIf (Lab (VfromListLab+ 2));
  Stack (PushInt(( 1 : int)));
  Stack Add;
  Stack (Load( 1));
  Stack (PushInt(( 1 : int)));
  Stack El;
  Stack (Load( 2));
  Stack (PushInt(( 0 : int)));
  Stack El;
  Stack (Store( 2));
  Stack (Load( 0));
  Stack (Load( 2));
  Stack (Store( 1));
  Stack (Store( 1));
  Jump (Lab (VfromListLab+ 1));
  Label (VfromListLab+ 2);
  Stack (Pops( 1));
  Stack (Cons vector_tag);
  Return]))`;

(*val VfromListLabs : nat*)
val _ = Define `
 (VfromListLabs =( 3))`;

(*val ImplodeLab : nat*)
val _ = Define `
 (ImplodeLab = (VfromListLab + VfromListLabs))`;

(*val ImplodeCode : list bc_inst*)
val _ = Define `
 (ImplodeCode = ([
  Label ImplodeLab;
  Stack (PushInt(( 0 : int)));
  Label (ImplodeLab+ 1);
  Stack (Load( 1));
  Stack (TagEq (block_tag+conLang$nil_tag));
  JumpIf (Lab (ImplodeLab+ 2));
  Stack (PushInt(( 1 : int)));
  Stack Add;
  Stack (Load( 1));
  Stack (PushInt(( 1 : int)));
  Stack El;
  Stack (Load( 2));
  Stack (PushInt(( 0 : int)));
  Stack El;
  Stack (Store( 2));
  Stack (Load( 0));
  Stack (Load( 2));
  Stack (Store( 1));
  Stack (Store( 1));
  Jump (Lab (ImplodeLab+ 1));
  Label (ImplodeLab+ 2);
  Stack (Pops( 1));
  Stack (Cons string_tag);
  Return]))`;

(*val ImplodeLabs : nat*)
val _ = Define `
 (ImplodeLabs =( 3))`;

(*val ExplodeLab : nat*)
val _ = Define `
 (ExplodeLab = (ImplodeLab + ImplodeLabs))`;

(*val ExplodeCode : list bc_inst*)
val _ = Define `
 (ExplodeCode = ([
  Label ExplodeLab;
  Stack (Load( 0));
  Stack LengthBlock;
  Stack (PushInt(( 0 : int)));
  Stack (Cons (block_tag+conLang$nil_tag));
  Label (ExplodeLab+ 1);
  Stack (Load( 2));
  Stack (Load( 2));
  Stack (PushInt(( 0 : int)));
  Stack Equal;
  JumpIf (Lab (ExplodeLab+ 2));
  Stack (Load( 2));
  Stack (PushInt(( 1 : int)));
  Stack Sub;
  Stack (Load( 0));
  Stack (Store( 3));
  Stack El;
  Stack (Load( 1));
  Stack (PushInt(( 2 : int)));
  Stack (Cons (block_tag+conLang$cons_tag));
  Stack (Store( 0));
  Jump (Lab (ExplodeLab+ 1));
  Label (ExplodeLab+ 2);
  Stack Pop;
  Stack (Pops( 2));
  Return]))`;

(*val ExplodeLabs : nat*)
val _ = Define `
 (ExplodeLabs =( 3))`;


 val _ = Define `

(prim1_to_bc CRef = ([Stack (PushInt(( 1 : int))); Ref]))
/\
(prim1_to_bc CDer = ([Stack (PushInt(( 0 : int))); Deref]))
/\
(prim1_to_bc CIsBlock = ([Stack IsBlock]))
/\
(prim1_to_bc CLen = ([Length]))
/\
(prim1_to_bc CLenB = ([LengthByte]))
/\
(prim1_to_bc CLenV = ([Stack LengthBlock]))
/\
(prim1_to_bc CLenS = ([Stack LengthBlock]))
/\
(prim1_to_bc (CTagEq n) = ([Stack (TagEq (n+block_tag))]))
/\
(prim1_to_bc (CProj n) = (PushAnyInt (int_of_num n) ++ [Stack El]))
/\
(prim1_to_bc (CInitG n) = ([Gupdate n; Stack (PushInt(( 0 : int))); Stack (Cons unit_tag)]))
/\
(prim1_to_bc CChr = ([]))
/\
(prim1_to_bc COrd = ([]))
/\
(prim1_to_bc CExplode = ([Call (Lab ExplodeLab)]))
/\
(prim1_to_bc CImplode = ([Call (Lab ImplodeLab)]))
/\
(prim1_to_bc CVfromList = ([Call (Lab VfromListLab)]))`;


 val _ = Define `

(prim2_to_bc (P2p CAdd) = (Stack Add))
/\
(prim2_to_bc (P2p CSub) = (Stack Sub))
/\
(prim2_to_bc (P2p CMul) = (Stack Mult))
/\
(prim2_to_bc (P2p CDiv) = (Stack Div))
/\
(prim2_to_bc (P2p CMod) = (Stack Mod))
/\
(prim2_to_bc (P2p CLt) = (Stack Less))
/\
(prim2_to_bc (P2p CEq) = (Stack Equal))
/\
(prim2_to_bc (P2p CDerV) = (Stack El))
/\
(prim2_to_bc (P2s CRefB) = RefByte)
/\
(prim2_to_bc (P2s CDerB) = DerefByte)
/\
(prim2_to_bc (P2s CRefA) = Ref)
/\
(prim2_to_bc (P2s CDerA) = Deref)`;


val _ = Define `
 (emit = (FOLDL (\ s i .  ( s with<| out := i :: s.out |>))))`;


 val _ = Define `

(get_label s = (( s with<| next_label := s.next_label + 1 |>), s.next_label))`;


 val compile_envref_defn = Hol_defn "compile_envref" `

(compile_envref sz s (CCArg n) = (emit s [Stack (Load (sz + n))]))
/\
(compile_envref sz s (CCEnv n) = (emit s (([Stack (Load sz)] ++ (PushAnyInt (int_of_num n))) ++ [Stack El])))
/\
(compile_envref sz s (CCRef n) = (emit (compile_envref sz s (CCEnv n)) [Stack (PushInt(( 0 : int))); Deref]))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn compile_envref_defn;

 val _ = Define `

(compile_varref sz s (CTLet n) = (emit s [Stack (Load (sz - n))]))
/\
(compile_varref _  s (CTDec n) = (emit s [Gread n]))
/\
(compile_varref sz s (CTEnv x) = (compile_envref sz s x))`;


(* calling convention:
 * before: env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
 * thus, since env = stack[sz], argk should be CTArg (2 + n - k)
 * after:  retval,
 *)

(* closure representation:
 * Block 3 [CodePtr f; Env]
 * where Env = Number 0 for empty, or else
 * Block 3 [v1,...,vk]
 * with a value for each free variable
 * (some values may be RefPtrs to other (mutrec) closures)
 *)

(* closure construction, for a bundle of nz names, nk defs:
 * - push nz refptrs
 * - push nk CodePtrs, each pointing to the appropriate body
 * - for each def, load its CodePtr, load its environment, cons them up, and
     store them where its CodePtr was
   - for each name, load the refptr and update it with the closure
   - for each name, store the refptr back where it was
 *)

 val _ = Define `

(emit_ceenv env (sz,s) fv = ((sz+ 1),
  compile_varref sz s
  ((case el_check fv env of SOME x => x
   | NONE => CTLet( 0) (* should not happen *) ))))`;


 val _ = Define `

(* sz                                                           z                             *)
(* e, ..., e, CodePtr_k, cl_1, ..., CodePtr k, ..., CodePtr nz, RefPtr_1 0, ..., RefPtr_nz 0, *)
(emit_ceref z (sz,s) j = ((sz+ 1),emit s [Stack (Load ((sz - z)+j))]))`;


 val _ = Define `

(push_lab (s,ecs) (NONE,_) = (s,(([],[])::ecs))) (* should not happen *)
/\
(push_lab (s,ecs) (SOME (l,(_,ceenv)),_) =
  (emit s [PushPtr (Lab l)],(ceenv::ecs)))`;


 val _ = Define `

(cons_closure env0 sz nk (s,k) (refs,envs) =  
(
  (*                                                                      sz *)
  (* cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0,    *)let s = (emit s [Stack (Load k)]) in
  (* CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (z,s) = (FOLDL (emit_ceref (sz+nk)) ((((sz+nk)+nk)+ 1),s) refs) in  
  (case FOLDL (emit_ceenv env0) (z,s) envs of
      (_,s) =>
  (* e_kj, ..., e_k1, CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = (emit s (PushAnyInt (int_of_num (LENGTH refs + LENGTH envs)))) in
  let s = (emit s [Stack (Cons ( 0))]) in
  (* env_k, CodePtr_k, cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = (emit s [Stack (PushInt (( 2 : int))); Stack (Cons closure_tag)]) in
  (* cl_k,  cl_1, ..., CodePtr_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let s = (emit s [Stack (Store k)]) in
  (* cl_1, ..., cl_k, ..., CodePtr_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  (s,(k +  1))
  )))`;


 val _ = Define `

(update_refptr nk (s,k) =  
(
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)let s = (emit s [Stack (Load (nk + k))]) in
  (* RefPtr_k 0, cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)
  let s = (emit s [Stack (PushInt(( 0 : int))); Stack (Load ( 2 + k))]) in
  (* cl_k, RefPtr_k 0, cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k 0, ..., RefPtr_nk 0, *)
  let s = (emit s [Update]) in
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_k cl_k, ..., RefPtr_nk 0, *)
  (s,(k+ 1))))`;


 val _ = Define `

(compile_closures env sz s defs =  
(let nk = (LENGTH defs) in
  let s = (num_fold (\ s .  emit s [Stack (PushInt(( 0 : int))); Stack (PushInt(( 1 : int))); Ref]) s nk) in
  (* RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,ecs) = (FOLDL push_lab (s,[]) (REVERSE defs)) in
  (* CodePtr 1, ..., CodePtr nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,_k) = (FOLDL (cons_closure env sz nk) (s, 0) ecs) in
  (* cl_1, ..., cl_nk, RefPtr_1 0, ..., RefPtr_nk 0, *)
  let (s,_k) = (num_fold (update_refptr nk) (s, 0) nk) in
  (* cl_1, ..., cl_nk, RefPtr_1 cl_1, ..., RefPtr_nk cl_nk, *)
  let k = (nk -  1) in
  num_fold (\ s .  emit s [Stack (Store k)]) s nk))`;

  (* cl_1, ..., cl_nk, *)

 val _ = Define `

(pushret TCNonTail s = s)
/\
(pushret (TCTail j k) s =  
(
 (* val, vk, ..., v1, env, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)emit s [Stack (Pops (k+ 1));
 (* val, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)
          Stack (Load( 1));
 (* CodePtr ret, val, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c; env], *)
          Stack (Store (j+ 2));
 (* val, CodePtr ret, argj, ..., arg1, CodePtr ret, *)
          Stack (Pops (j+ 1));
 (* val, CodePtr ret, *)
          Return]))`;


(* stackshiftaux n i j
   xs@ys@zs@st, where n = |ys| = |zs|, i = |xs|, j = |xs|+|ys|
   to
   xs@ys@ys@st *)
(*
let rec
stackshiftaux 0 i j = []
and
stackshiftaux n i j =
  (Load i)::(Store j)::(stackshiftaux (n-1) (i+1) (j+1))
*)
 val _ = Define `
 (stackshiftaux n i j =  
(if n = ( 0:num) then []
  else (Load i)::((Store j)::(stackshiftaux (n -  1) (i+ 1) (j+ 1)))))`;

(*
  xs@(y::ys)@(z::zs)@st
  y::xs@(y::ys)@(z::zs)@st
  xs@(y::ys)@(y::zs)@st
*)

(* stackshift j k
   xs@ys@st, where j=|xs|, k=|ys|
   to
   xs@st *)
(*
let rec
stackshift j 0 = []
and
stackshift 0 k = [Pops (k-1); Pop]
and
stackshift 1 k = [Pops k]
and
stackshift j k =
  if j <= k
  then
    (genlist (fun i -> Store (k-1)) j)@(stackshift 0 (k-j))
  else
    (stackshiftaux k (j-k) j)@(stackshift (j-k) k)
*)
 val _ = Define `
 (stackshift j k =  
(if k = 0 then []
  else if j = 0 then [Pops (k -  1); Pop]
  else if j = 1 then [Pops k]
  else if j <= k then (GENLIST (\n .  
  (case (n ) of ( _ ) => Store (k -  1) )) j)++(stackshift( 0) (k - j))
  else (stackshiftaux k (j - k) j)++(stackshift (j - k) k)))`;

(*
  a b c d e x y z
c a b c d e x y z
  a b c d e c y z
d a b c d e c y z
  a b c d e c d z
e a b c d e c d z
  a b c d e c d e
        a b c d e

a b c v w x y z
  b c v w a y z
    c v w a b z
      v w a b c
          a b c

a b c x y z
  b c a y z
    c a b z
      a b c
*)


 val compile_defn = Hol_defn "compile" `

(compile env _ sz s (CRaise e) =  
(let s = (compile env TCNonTail sz s e) in
  emit s [PopExc; Return]))
/\
(compile env t sz s (CHandle e1 e2) =  
(let (s,n0) = (get_label s) in
  let (s,n1) = (get_label s) in
  let s = (emit s [PushPtr (Lab n0); PushExc]) in
  let s = (compile env TCNonTail (sz+ 2) s e1) in
  let s = (pushret t (emit s [PopExc; Stack (Pops( 1))])) in
  let s = (emit s [Jump (Lab n1); Label n0]) in
  let s = (compile_bindings env t sz e2( 0) s( 1)) in
  emit s [Label n1]))
/\
(compile _ t _ s (CLit (IntLit i)) =  
(pushret t (emit s (PushAnyInt i))))
/\
(compile _ t _ s (CLit (Char c)) =  
(pushret t (emit s [Stack (PushInt (int_of_num (ORD c)))])))
/\
(compile _ t _ s (CLit (StrLit r)) =  
(let r = (EXPLODE r) in
  let s = (emit s (MAP (Stack o (PushInt o (int_of_num o ORD))) r)) in
  let s = (emit s (PushAnyInt (int_of_num (LENGTH r)))) in
  pushret t (emit s [Stack (Cons string_tag)])))
/\
(compile _ t _ s (CLit (Word8 w)) =  
(pushret t (emit s [Stack (PushInt (int_of_num (w2n w)))])))
/\
(compile env t sz s (CVar vn) = (pushret t
  (compile_varref sz s
    ((case el_check vn env of
       SOME x => x
     | NONE => CTLet( 0) (* should not happen *)
     )))))
/\
(compile _ t sz s (CGvar n) = (pushret t (compile_varref sz s (CTDec n))))
/\
(compile env t sz s (CCon n es) =  
(let s = (emit (compile_nts env sz s es) (PushAnyInt (int_of_num (LENGTH es)))) in
  pushret t (emit s [Stack (Cons (n+block_tag))])))
/\
(compile env t sz s (CLet F e1 e2) =  
(let s = (compile env TCNonTail sz s e1) in
  let s = (emit s [Stack Pop]) in
  compile env t sz s e2))
/\
(compile env t sz s (CLet T e eb) =  
(compile_bindings env t sz eb( 0) (compile env TCNonTail sz s e)( 1)))
/\
(compile env t sz s (CLetrec defs eb) =  
(let s = (compile_closures env sz s defs) in
  compile_bindings env t sz eb( 0) s (LENGTH defs)))
/\
(compile env t sz s (CCall ck e es) =  
(let n = (LENGTH es) in
  let s = (compile_nts env sz s (e::es)) in
  (case t of
    TCNonTail =>
    (* argn, ..., arg2, arg1, Block 0 [CodePtr c; env], *)
    let s = (emit s [Stack (Load n); Stack (PushInt(( 1 : int))); Stack El]) in
    (* env, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    let s = (emit s [Stack (Load (n+ 1)); Stack (PushInt(( 0 : int))); Stack El]) in
    (* CodePtr c, env, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    emit s ((if ck then [Tick] else [])++[CallPtr])
    (* before: env, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env], *)
    (* after:  retval, *)
  | TCTail j k =>
    (* argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = (emit s [Stack (Load (((n+ 1)+k)+ 1))]) in
    (* CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = (emit s [Stack (Load (n+ 1)); Stack (PushInt(( 0 : int))); Stack El]) in
    (* CodePtr c, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = (emit s [Stack (Load (n+ 2)); Stack (PushInt(( 1 : int))); Stack El]) in
    (* env, CodePtr c, CodePtr ret, argn, ..., arg1, Block 0 [CodePtr c; env],
     * vk, ..., v1, env1, CodePtr ret, argj, ..., arg1, Block 0 [CodePtr c1; env1], *)
    let s = (emit s (MAP Stack (stackshift (((( 1+ 1)+ 1)+n)+ 1) ((((k+ 1)+ 1)+j)+ 1)))) in
    emit s ((if ck then [Tick] else [])++[Return])
  )))
/\
(compile env t sz s (CPrim1 uop e) =  
(pushret t (emit (compile env TCNonTail sz s e) (prim1_to_bc uop))))
/\
(compile env t sz s (CPrim2 op e1 e2) =  
(pushret t (emit (compile_nts env sz s [e1;e2]) [prim2_to_bc op])))
/\
(compile env t sz s (CUpd b e1 e2 e3) =  
(pushret t (emit (compile_nts env sz s [e1;e2;e3]) [(case b of UpB => UpdateByte | _ => Update );
                                                     Stack (PushInt(( 0 : int))); Stack (Cons unit_tag)])))
/\
(compile env t sz s (CIf e1 e2 e3) =  
(let s = (compile env TCNonTail sz s e1) in
  let (s,n0) = (get_label s) in
  let (s,n1) = (get_label s) in
  let (s,n2) = (get_label s) in
  let s = (emit s [(JumpIf (Lab n0)); (Jump (Lab n1)); Label n0]) in
  let s = (compile env t sz s e2) in
  let s = (emit s [Jump (Lab n2); Label n1]) in
  let s = (compile env t sz s e3) in
  emit s [Label n2]))
/\
(compile _ t _ s (CExtG n) = (pushret t (emit s [Galloc n; Stack (PushInt(( 0 : int))); Stack (Cons unit_tag)])))
/\
(compile_bindings env t sz e n s 0 =  
((case t of
    TCTail j k => compile env (TCTail j (k+n)) (sz+n) s e
  | TCNonTail =>
    emit (compile env t (sz+n) s e) [Stack (Pops n)]
  )))
/\
(compile_bindings env t sz e n s m =  
(compile_bindings ((CTLet (sz+(n+ 1)))::env) t sz e (n+ 1) s (m -  1)))
/\
(compile_nts _ _ s [] = s)
/\
(compile_nts env sz s (e::es) =  
(compile_nts env (sz+ 1) (compile env TCNonTail sz s e) es))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn compile_defn;

(* code env to bytecode *)

 val free_labs_defn = Hol_defn "free_labs" `

(free_labs ez (CRaise e) = (free_labs ez e))
/\
(free_labs ez (CHandle e1 e2) = (free_labs ez e1 ++ free_labs (ez+ 1) e2))
/\
(free_labs _ (CVar _) = ([]))
/\
(free_labs _ (CGvar _) = ([]))
/\
(free_labs _ (CLit _) = ([]))
/\
(free_labs ez (CCon _ es) = (free_labs_list ez es))
/\
(free_labs ez (CLet bd e b) = (free_labs ez e ++ free_labs (if bd then (ez+ 1) else ez) b))
/\
(free_labs ez (CLetrec defs e) =  
(free_labs_defs ez (LENGTH defs) ( 0:num) defs ++
  free_labs (ez+LENGTH defs) e))
/\
(free_labs ez (CCall _ e es) = (free_labs ez e ++ free_labs_list ez es))
/\
(free_labs ez (CPrim2 _ e1 e2) = (free_labs ez e1 ++ free_labs ez e2))
/\
(free_labs ez (CUpd _ e1 e2 e3) = ((free_labs ez e1 ++ free_labs ez e2) ++ free_labs ez e3))
/\
(free_labs ez (CPrim1 _ e) = (free_labs ez e))
/\
(free_labs ez (CIf e1 e2 e3) = (free_labs ez e1 ++ (free_labs ez e2 ++ free_labs ez e3)))
/\
(free_labs _ (CExtG _) = ([]))
/\
(free_labs_list _ [] = ([]))
/\
(free_labs_list ez (e::es) = (free_labs ez e ++ free_labs_list ez es))
/\
(free_labs_defs _ _ _ [] = ([]))
/\
(free_labs_defs ez nz ix (d::ds) = (free_labs_def ez nz ix d ++ free_labs_defs ez nz (ix+ 1) ds))
/\
(free_labs_def ez nz ix (SOME (l,(cc,(re,ev))),(az,b)) =
  (((ez,nz,ix),((l,(cc,(re,ev))),(az,b)))::(free_labs ((( 1 + LENGTH re) + LENGTH ev) + az) b)))
/\
(free_labs_def ez nz _ (NONE,(az,b)) = (free_labs ((ez+nz)+az) b))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn free_labs_defn;

 val _ = Define `
 (cce_aux s ((l,(ccenv,_)),(az,b)) =  
(compile (MAP CTEnv ccenv) (TCTail az( 0))( 0) (emit s [Label l]) b))`;


 val _ = Define `

(compile_code_env s e =  
(let (s,l) = (get_label s) in
  let s = (emit s [Jump (Lab l)]) in
  let s = (FOLDL cce_aux s (MAP SND (free_labs( 0) e))) in
  emit s [Label l]))`;

val _ = export_theory()
