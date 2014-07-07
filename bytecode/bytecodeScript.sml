(*Generated by Lem from bytecode.lem.*)
open HolKernel Parse boolLib bossLib;
open lem_pervasivesTheory lem_map_extraTheory lem_string_extraTheory libTheory astTheory semanticPrimitivesTheory;

val _ = numLib.prefer_num();



val _ = new_theory "bytecode"

(*open import Pervasives*)
(*import Map_extra*)
(*import String_extra*)

(*open import Lib*)
(*open import Ast*)
(*open import SemanticPrimitives*)

(* TODO: should be in lem library? *)
(*val snoc_char : char -> string -> string*)
(*val least : (nat -> bool) -> nat*)

(* --- Syntax --- *)

val _ = Hol_datatype `

  bc_stack_op =
    Pop                     (* pop top of stack *)
  | Pops of num             (* pop n elements under stack top *)
  | PushInt of int      (* push int onto stack *)
  | Cons of num => num       (* push new cons with tag m and n elements *)
  | Load of num             (* push stack[n] *)
  | Store of num            (* pop and store in stack[n] *)
  | El of num               (* read field n of cons block *)
  | TagEq of num            (* test tag of block *)
  | IsBlock                 (* test for a block *)
  | Equal                   (* test equality *)
  | Add | Sub | Mult | Div | Mod | Less`;
  (* arithmetic *)

val _ = Hol_datatype `

  loc =
    Lab of num              (* label *)
  | Addr of num`;
             (* address *)

val _ = Hol_datatype `

  bc_inst =
    Stack of bc_stack_op
  | Label of num            (* label location *)
  | Jump of loc             (* jump to location *)
  | JumpIf of loc           (* jump to location iff true *)
  | Call of loc             (* call location *)
  | CallPtr                 (* call based on code pointer *)
  | PushPtr of loc          (* push a CodePtr onto stack *)
  | Return                  (* pop return address, jump *)
  | PushExc                 (* push exception handler *)
  | PopExc                  (* pop exception handler *)
  | Ref                     (* create a new ref cell *)
  | RefByte                 (* create new byte array *)
  | Deref                   (* dereference a ref cell *)
  | DerefByte               (* index a byte array *)
  | Update                  (* update a ref cell *)
  | UpdateByte              (* update a byte array *)
  | Length                  (* get length of ref *)
  | LengthByte              (* get length of byte array *)
  | Galloc of num           (* allocate global variables *)
  | Gupdate of num          (* update a global variable *)
  | Gread of num            (* read a global variable *)
  | Stop of bool            (* halt execution with success/failure *)
  | Tick                    (* use fuel *)
  | Print                   (* print non-word value at top of stack *)
  | PrintWord8              (* print word8 at top of stack *)
  | PrintC of char`;
          (* print a character *)

(* --- Semantics --- *)

(* the stack is a list of elements of bc_value *)

val _ = Hol_datatype `

  bc_value =
    Number of int              (* integer *)
  | Block of num => bc_value list   (* cons block: tag and payload *)
  | CodePtr of num                 (* code pointer *)
  | RefPtr of num                  (* pointer to ref cell *)
  | StackPtr of num`;
                (* pointer into stack *)

val _ = Hol_datatype `

  ref_value =
    ValueArray of bc_value list
  | ByteArray of word8 list`;


val _ = Hol_datatype `

  bc_state =
   <| (* main state components *)
      stack : bc_value list;
      code : bc_inst list;
      pc : num;
      refs : (num, ref_value) fmap;
      globals : ( bc_value option) list;
      handler : num;
      output : string;
      (* artificial state components *)
      inst_length : bc_inst -> num;
      clock :  num option
   |>`;


(*val bool_to_tag : bool -> nat*)
 val _ = Define `

(bool_to_tag F =( 0))
/\
(bool_to_tag T =( 1))`;


val _ = Define `
 (unit_tag : num =( 2))`;

val _ = Define `
 (closure_tag : num =( 3))`;

val _ = Define `
 (string_tag : num =( 4))`;

val _ = Define `
 (block_tag : num =( 5))`;


val _ = Define `
 (bool_to_val b = (Block (bool_to_tag b) []))`;

val _ = Define `
 (unit_val = (Block unit_tag []))`;


val _ = Define `
 (word8_to_val w = (Number (int_of_num (w2n w))))`;


 val _ = Define `

(is_Block (Block _ _) = T)
/\
(is_Block _ = F)`;


 val _ = Define `

(is_Number (Number _) = T)
/\
(is_Number _ = F)`;


 val _ = Define `
 (dest_Number (Number i) = i)`;


 val _ = Define `

(is_char (Number n) = ((( 0 : int) <= n) /\ (n <( 256 : int))))
/\
(is_char _ = F)`;


(* comparing bc_values for equality *)

 val bc_equal_defn = Hol_defn "bc_equal" `

(bc_equal (CodePtr _) _ = Eq_type_error)
/\
(bc_equal _ (CodePtr _) = Eq_type_error)
/\
(bc_equal (StackPtr _) _ = Eq_type_error)
/\
(bc_equal _ (StackPtr _) = Eq_type_error)
/\
(bc_equal (Number n1) (Number n2) = (Eq_val (n1 = n2)))
/\
(bc_equal (Number _) _ = (Eq_val F))
/\
(bc_equal _ (Number _) = (Eq_val F))
/\
(bc_equal (RefPtr n1) (RefPtr n2) = (Eq_val (n1 = n2)))
/\
(bc_equal (RefPtr _) _ = (Eq_val F))
/\
(bc_equal _ (RefPtr _) = (Eq_val F))
/\
(bc_equal (Block t1 l1) (Block t2 l2) =  
(if (t1 = closure_tag) \/ (t2 = closure_tag)
  then Eq_closure else
    if (t1 = t2) /\ (LENGTH l1 = LENGTH l2)
    then bc_equal_list l1 l2 else Eq_val F))
/\
(bc_equal_list [] [] = (Eq_val T))
/\
(bc_equal_list (v1::vs1) (v2::vs2) =  
((case bc_equal v1 v2 of
    Eq_val T => bc_equal_list vs1 vs2
  | Eq_val F => Eq_val F
  | bad => bad
  )))
/\
(bc_equal_list _ _ = (Eq_val F))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_equal_defn;

 val _ = Define `

(bc_equality_result_to_val (Eq_val b) = (bool_to_val b))
/\
(bc_equality_result_to_val Eq_closure = (Number(( 0 : int))))
/\
(bc_equality_result_to_val Eq_type_error = (Number(( 1 : int))))`;


(* fetching the next instruction from the code *)

 val _ = Define `

(is_Label (Label _) = T)
/\
(is_Label _ = F)`;


 val bc_fetch_aux_defn = Hol_defn "bc_fetch_aux" `

(bc_fetch_aux [] _ _ = NONE)
/\
(bc_fetch_aux (x::xs) len (n:num) =  
(if is_Label x then bc_fetch_aux xs len n else
    if n = 0 then SOME x else
      if n < (len x + 1) then NONE else
        bc_fetch_aux xs len (n - (len x + 1))))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_fetch_aux_defn;

val _ = Define `
 (bc_fetch s = (bc_fetch_aux s.code s.inst_length s.pc))`;


(* most instructions just bump the pc along, for this we use bump_pc *)

val _ = Define `
 (bump_pc s = ((case bc_fetch s of
  NONE => s
| SOME x => ( s with<| pc := (s.pc + s.inst_length x) + 1 |>)
)))`;


(* finding the address of a location *)
 val bc_find_loc_aux_defn = Hol_defn "bc_find_loc_aux" `

(bc_find_loc_aux [] _ _ _ = NONE)
/\
(bc_find_loc_aux (x::xs) len l (n:num) =  
(if x = Label l then SOME n else
    bc_find_loc_aux xs len l (n + (if is_Label x then  0 else len x + 1))))`;

val _ = Lib.with_flag (computeLib.auto_import_definitions, false) Defn.save_defn bc_find_loc_aux_defn;

 val _ = Define `

(bc_find_loc _ (Addr n) = (SOME n))
/\
(bc_find_loc s (Lab l) = (bc_find_loc_aux s.code s.inst_length l( 0)))`;


(* conversion to observable values *)

(*val bvs_to_chars : list bc_value -> list char -> maybe (list char)*)
 val _ = Define `

(bvs_to_chars [] ac = (SOME (REVERSE ac)))
/\
(bvs_to_chars (Number i::vs) ac =  
(bvs_to_chars vs ((CHR (Num (ABS ( i))))::ac)))
/\
(bvs_to_chars _ _ = NONE)`;


(*val bv_to_string :  bc_value -> maybe string*)
 val _ = Define `

(bv_to_string (Number i) = (SOME (int_to_string i)))
/\
(bv_to_string (Block n vs) =  
(if n = (bool_to_tag F) then SOME "false" else
  if n = (bool_to_tag T) then SOME "true" else
  if n = unit_tag then SOME "()" else
  if n = closure_tag then SOME "<fn>" else
  if n = string_tag then
    (case bvs_to_chars vs [] of
      NONE => NONE
    | SOME cs => SOME (string_to_string (IMPLODE cs))
    )
  else SOME "<constructor>"))
/\
(bv_to_string (RefPtr _) = (SOME "<ref>"))
/\
(bv_to_string _ = NONE)`;


(* next state relation *)

val _ = Hol_reln ` (! x xs. T ==>
bc_stack_op Pop (x::xs) (xs))
/\ (! x ys xs. T ==>
bc_stack_op (Pops (LENGTH ys)) ((x::ys)++xs) (x::xs))
/\ (! n xs. T ==>
bc_stack_op (PushInt n) (xs) (Number n::xs))
/\ (! tag ys xs. T ==>
bc_stack_op (Cons tag (LENGTH ys)) (ys++xs) (Block tag (REVERSE ys)::xs))
/\ (! k xs. (k < LENGTH xs) ==>
bc_stack_op (Load k) xs (EL k xs::xs))
/\ (! y ys x xs. T ==>
bc_stack_op (Store (LENGTH ys)) ((y::ys)++(x::xs)) (ys++(y::xs)))
/\ (! k tag ys xs. (k < LENGTH ys) ==>
bc_stack_op (El k) ((Block tag ys)::xs) (EL k ys::xs))
/\ (! t tag ys xs. T ==>
bc_stack_op (TagEq t) ((Block tag ys)::xs) (bool_to_val (tag = t)::xs))
/\ (! x xs. (! n. ~ (x = CodePtr n) /\ ~ (x = StackPtr n)) ==>
bc_stack_op IsBlock (x::xs) ((bool_to_val (is_Block x))::xs))
/\ (! x2 x1 xs. (~ (bc_equal x1 x2 = Eq_type_error)) ==>
bc_stack_op Equal (x2::(x1::xs)) (bc_equality_result_to_val (bc_equal x1 x2)::xs))
/\ (! n m xs. T ==>
bc_stack_op Less (Number n::(Number m::xs)) (bool_to_val (m < n)::xs))
/\ (! n m xs. T ==>
bc_stack_op Add  (Number n::(Number m::xs)) (Number (m + n)::xs))
/\ (! n m xs. T ==>
bc_stack_op Sub  (Number n::(Number m::xs)) (Number (m - n)::xs))
/\ (! n m xs. T ==>
bc_stack_op Mult (Number n::(Number m::xs)) (Number (m * n)::xs))
/\ (! n m xs. (~ (n =( 0 : int))) ==>
bc_stack_op Div  (Number n::(Number m::xs)) (Number (m / n)::xs))
/\ (! n m xs. (~ (n =( 0 : int))) ==>
bc_stack_op Mod  (Number n::(Number m::xs)) (Number (m % n)::xs))`;

val _ = Hol_reln ` (! s b ys.
((bc_fetch s = SOME (Stack b))
/\ bc_stack_op b (s.stack) ys)
==>
bc_next s ((bump_pc s with<| stack := ys|>))) (* parens throughout: lem sucks *)
/\ (! s l n.
((bc_fetch s = SOME (Jump l)) (* parens: ugh...*)
/\ (bc_find_loc s l = SOME n))
==>
bc_next s ((s with<| pc := n|>)))
/\ (! s l n b xs s'.
((bc_fetch s = SOME (JumpIf l))
/\ (bc_find_loc s l = SOME n)
/\ (s.stack = ((bool_to_val b)::xs))
/\ (s' = ((s with<| stack := xs|>))))
==>
bc_next s (if b then (s' with<| pc := n|>) else bump_pc s'))
/\ (! s l n x xs.
((bc_fetch s = SOME (Call l))
/\ (bc_find_loc s l = SOME n)
/\ (s.stack = (x::xs)))
==>
bc_next s ((s with<| pc := n; stack := x::(CodePtr ((bump_pc s).pc)::xs)|>)))
/\ (! s ptr x xs.
((bc_fetch s = SOME CallPtr)
/\ (s.stack = (CodePtr ptr::(x::xs))))
==>
bc_next s ((s with<| pc := ptr; stack := x::(CodePtr ((bump_pc s).pc)::xs)|>)))
/\ (! s l n.
((bc_fetch s = SOME (PushPtr l))
/\ (bc_find_loc s l = SOME n))
==>
bc_next s ((bump_pc s with<| stack := (CodePtr n)::s.stack |>)))
/\ (! s x n xs.
((bc_fetch s = SOME Return)
/\ (s.stack = (x::(CodePtr n::xs))))
==>
bc_next s ((s with<| pc := n; stack := x::xs|>)))
/\ (! s.
(bc_fetch s = SOME PushExc) (* parens: Lem sucks *)
==>
bc_next s ((bump_pc s with<|
               handler := LENGTH s.stack ;
               stack := (StackPtr s.handler)::s.stack|>)))
/\ (! s sp x l1 l2.
((bc_fetch s = SOME PopExc) /\
(s.stack = ((x::l1) ++ (StackPtr sp::l2))) /\
(LENGTH l2 = s.handler))
==>
bc_next s ((bump_pc s with<| handler := sp; stack := x::l2|>)))
/\ (! s n v xs ptr.
((bc_fetch s = SOME Ref)
/\ (s.stack = ((Number (int_of_num n))::(v::xs)))
/\ (ptr = $LEAST (\ ptr .  ~ (ptr IN FDOM s.refs))))
==>
bc_next s ((bump_pc s with<| stack := (RefPtr ptr)::xs;
             refs :=s.refs |+ (ptr, (ValueArray (REPLICATE n v)))|>)))
/\ (! s n w xs ptr.
((bc_fetch s = SOME RefByte)
/\ (s.stack = ((Number (int_of_num n))::((word8_to_val w)::xs)))
/\ (ptr = $LEAST (\ ptr .  ~ (ptr IN FDOM s.refs))))
==>
bc_next s ((bump_pc s with<| stack := (RefPtr ptr)::xs;
             refs :=s.refs |+ (ptr, (ByteArray (REPLICATE n w)))|>)))
/\ (! s n ptr xs vs.
((bc_fetch s = SOME Deref)
/\ (s.stack = ((Number (int_of_num n))::((RefPtr ptr)::xs)))
/\ (FLOOKUP s.refs ptr = SOME (ValueArray vs))
/\ (n < LENGTH vs))
==>
bc_next s ((bump_pc s with<| stack := (EL n vs)::xs|>)))
/\ (! s n ptr xs vs.
((bc_fetch s = SOME DerefByte)
/\ (s.stack = ((Number (int_of_num n))::((RefPtr ptr)::xs)))
/\ (FLOOKUP s.refs ptr = SOME (ByteArray vs))
/\ (n < LENGTH vs))
==>
bc_next s ((bump_pc s with<| stack := (word8_to_val (EL n vs))::xs|>)))
/\ (! s x n ptr xs vs.
((bc_fetch s = SOME Update)
/\ (s.stack = (x::((Number (int_of_num n))::((RefPtr ptr)::xs))))
/\ (FLOOKUP s.refs ptr = SOME (ValueArray vs))
/\ (n < LENGTH vs))
==>
bc_next s ((bump_pc s with<| stack := xs;
             refs :=s.refs |+ (ptr, (ValueArray (LUPDATE x n vs)))|>)))
/\ (! s w n ptr xs vs.
((bc_fetch s = SOME UpdateByte)
/\ (s.stack = ((Number (int_of_num (w2n w)))::             
((Number (int_of_num n))::((RefPtr ptr)::xs))))
/\ (FLOOKUP s.refs ptr = SOME (ByteArray vs))
/\ (n < LENGTH vs))
==>
bc_next s ((bump_pc s with<| stack := xs;
             refs :=s.refs |+ (ptr, (ByteArray (LUPDATE w n vs)))|>)))
/\ (! s ptr xs vs.
((bc_fetch s = SOME Length)
/\ (s.stack = ((RefPtr ptr)::xs))
/\ (FLOOKUP s.refs ptr = SOME (ValueArray vs)))
==>
bc_next s ((bump_pc s with<| stack := (Number (int_of_num (LENGTH vs)))::xs|>)))
/\ (! s ptr xs vs.
((bc_fetch s = SOME LengthByte)
/\ (s.stack = ((RefPtr ptr)::xs))
/\ (FLOOKUP s.refs ptr = SOME (ByteArray vs)))
==>
bc_next s ((bump_pc s with<| stack := (Number (int_of_num (LENGTH vs)))::xs|>)))
/\ (! s n.
(bc_fetch s = SOME (Galloc n))
==>
bc_next s ((bump_pc s with<| globals := s.globals ++ (REPLICATE n NONE)|>)))
/\ (! s n x xs.
((bc_fetch s = SOME (Gupdate n))
/\ (s.stack = (x::xs))
/\ (n < LENGTH s.globals)
/\ (EL n s.globals = NONE))
==>
bc_next s ((bump_pc s with<| stack := xs;
                            globals := LUPDATE (SOME x) n s.globals|>)))
/\ (! s n v.
((bc_fetch s = SOME (Gread n))
/\ (n < LENGTH s.globals)
/\ (EL n s.globals = SOME v))
==>
bc_next s ((bump_pc s with<| stack := v::s.stack|>)))
/\ (! s.
((bc_fetch s = SOME Tick)
/\ (! n. (s.clock = SOME n) ==> (n > 0)))
==>
bc_next s ((bump_pc s with<| clock := OPTION_MAP PRE s.clock|>)))
/\ (! s x xs str.
((bc_fetch s = SOME Print)
/\ (s.stack = (x::xs))
/\ (bv_to_string x = SOME str))
==>
bc_next s ((bump_pc s with<| stack := xs;
  output := CONCAT [s.output;str]|>)))
/\ (! s x xs.
((bc_fetch s = SOME PrintWord8)
/\ (s.stack = ((Number (int_of_num (w2n (x:word8))))::xs)))
==>
bc_next s ((bump_pc s with<| stack := xs;
  output := CONCAT [s.output;word_to_hex_string x]|>)))
/\ (! s c.
(bc_fetch s = SOME (PrintC c))
==>
bc_next s ((bump_pc s with<| output := SNOC c s.output|>)))`;
val _ = export_theory()

