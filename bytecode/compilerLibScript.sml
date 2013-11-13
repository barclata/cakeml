(*Generated by Lem from compilerLib.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_list_extraTheory;

val _ = numLib.prefer_num();



val _ = new_theory "compilerLib"

(*open import Pervasives*)
(*import List_extra*)


(* TODO: these should be in the lem library *)
(*val least : (nat -> bool) -> nat*)

(*val string_concat : list string -> string*)

(*val snoc_char : char -> string -> string*)

(*val all2 : forall 'a 'b. ('a -> 'b -> bool) -> list 'a -> list 'b -> bool*)


 val _ = Define `
 (el_check n ls = (if n < (LENGTH ls) then (SOME ((EL n ls))) else NONE))`;


(*val num_fold : forall 'a. ('a -> 'a) -> 'a -> nat -> 'a*)
 val num_fold_defn = Hol_defn "num_fold" `
 (num_fold f a n = (if n = 0 then a else num_fold f (f a) (n -  1)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn num_fold_defn;

 val intersperse_defn = Hol_defn "intersperse" `

(intersperse _ [] = ([]))
/\
(intersperse _ [x] = ([x]))
/\
(intersperse a (x::xs) = (x::(a::intersperse a xs)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn intersperse_defn;

 val lunion_defn = Hol_defn "lunion" `

(lunion [] s = s)
/\
(lunion (x::xs) s =  
(if (MEM x s)
  then lunion xs s
  else x::(lunion xs s)))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn lunion_defn;

 val _ = Define `

(lshift dict_Basic_classes_Ord_a dict_Num_NumMinus_a n ls =  
((MAP (\ v . dict_Num_NumMinus_a.numMinus_method v n) ((FILTER (\ v . 
  dict_Basic_classes_Ord_a.isLessEqual_method n v) ls)))))`;


 val _ = Define `
 (the _ ((SOME x)) = x) /\ (the x NONE = x)`;


(*val fapply : forall 'a 'b. MapKeyType 'b => 'a -> 'b -> Map.map 'b 'a -> 'a*)
val _ = Define `
 (fapply d x f = ((case (FLOOKUP f x) of (SOME d) => d | NONE => d )))`;

val _ = export_theory()

