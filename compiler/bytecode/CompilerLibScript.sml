(*Generated by Lem from compilerLib.lem.*)
open bossLib Theory Parse res_quanTheory
open fixedPointTheory finite_mapTheory listTheory pairTheory pred_setTheory
open integerTheory set_relationTheory sortingTheory stringTheory wordsTheory

val _ = numLib.prefer_num();



val _ = new_theory "CompilerLib"

(* TODO: these should be in the lem library *)

(*val genlist : forall 'a. (num -> 'a) -> num -> list 'a*)

(*val pre : num -> num*)

(*val drop : forall 'a. num -> list 'a -> list 'a*)

(*val least : (num -> bool) -> num*)

(*val int_of_num : num -> int*)

(*val num_of_int : int -> num*)

(*val string_of_num : num -> string*)

(*val neg : int -> int*)

val _ = Define `
 i0 = ( int_of_num 0)`;

val _ = Define `
 i1 = ( int_of_num 1)`;

val _ = Define `
 i2 = ( int_of_num 2)`;


 val find_index_defn = Hol_defn "find_index" `

(find_index _ [] _ = NONE)
/\
(find_index y (x::xs) n = (if x = y then SOME n else find_index y xs (n +1)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn find_index_defn;

 val el_check_def = Define `
 (el_check n ls = (if n < LENGTH ls then SOME ( EL  n  ls) else NONE))`;


 val num_fold_defn = Hol_defn "num_fold" `
 (num_fold f a n = (if n = 0 then a else num_fold f (f a) (n - 1)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn num_fold_defn;

 val intersperse_defn = Hol_defn "intersperse" `

(intersperse _ [] = ([]))
/\
(intersperse _ [x] = ([x]))
/\
(intersperse a (x::xs) = (x ::a ::intersperse a xs))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn intersperse_defn;

 val lunion_defn = Hol_defn "lunion" `

(lunion [] s = s)
/\
(lunion (x::xs) s =  
(if MEM x s
  then lunion xs s
  else x ::(lunion xs s)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn lunion_defn;

 val lshift_def = Define `

(lshift n ls = ( MAP (\ v . v - n) ( FILTER (\ v . n <= v) ls)))`;


 val the_def = Define `
 (the _ (SOME x) = x) /\ (the x NONE = x)`;

val _ = export_theory()

