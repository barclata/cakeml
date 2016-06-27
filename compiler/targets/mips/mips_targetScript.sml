open HolKernel Parse boolLib bossLib
open asmLib mipsTheory;

val () = new_theory "mips_target"

val () = wordsLib.guess_lengths()

(* --- Configuration for MIPS --- *)

val eval = rhs o concl o EVAL
val min16 = eval ``sw2sw (INT_MINw: word16) : word64``
val max16 = eval ``sw2sw (INT_MAXw: word16) : word64``
val umax16 = eval ``w2w (UINT_MAXw: word16) : word64``

val mips_config_def = Define`
   mips_config =
   <| ISA_name := "MIPS"
    ; reg_count := 32
    ; avoid_regs := [0; 1]
    ; link_reg := SOME 31
    ; has_mem_32 := T
    ; two_reg_arith := F
    ; big_endian := T
    ; valid_imm :=
       (\b i. if b IN {INL And; INL Or; INL Xor; INR Test; INR NotTest} then
                0w <= i /\ i <= ^umax16
              else
                b <> INL Sub /\ ^min16 <= i /\ i <= ^max16)
    ; addr_offset_min := ^min16
    ; addr_offset_max := ^max16
    ; jump_offset_min := ^min16
    ; jump_offset_max := ^max16
    ; cjump_offset_min := ^min16
    ; cjump_offset_max := ^max16
    ; loc_offset_min := ^min16 + 12w
    ; loc_offset_max := ^max16 + 8w
    ; code_alignment := 2
    |>`

(* --- The next-state function --- *)

(* --------------------------------------------------------------------------
   Simplifying Assumption for MIPS Branch-Delay Slot
   -------------------------------------------------
   NOTE: The next-state function defined below merges branches with their
   following instruction. This temporal abstraction artificially prevents us
   from considering side-effect events (exceptions) occurring between these two
   instructions. As such, we are assuming that this case is handled correctly
   and we don't attempt to model or verify this behaviour.
   -------------------------------------------------------------------------- *)

val mips_next_def = Define`
   mips_next s =
   let s' = THE (NextStateMIPS s) in
     if IS_SOME s'.BranchDelay then THE (NextStateMIPS s') else s'`

(* --- Relate ASM and MIPS states --- *)

val mips_ok_def = Define`
   mips_ok ms =
   ms.CP0.Config.BE /\ ~ms.CP0.Status.RE /\ ~ms.exceptionSignalled /\
   (ms.BranchDelay = NONE) /\ (ms.BranchTo = NONE) /\
   (ms.exception = NoException) /\ aligned 2 ms.PC`

val mips_asm_state_def = Define`
   mips_asm_state s ms =
   mips_ok ms /\
   (!i. 1 < i /\ i < 32 ==> (s.regs i = ms.gpr (n2w i))) /\
   (fun2set (s.mem, s.mem_domain) = fun2set (ms.MEM, s.mem_domain)) /\
   (s.pc = ms.PC)`

(* --- Encode ASM instructions to MIPS bytes. --- *)

val mips_encode_def = Define`
   mips_encode i =
   let w = mips$Encode i in
      [(31 >< 24) w; (23 >< 16) w; (15 >< 8) w; (7 >< 0) w] : word8 list`

val encs_def = Define `encs l = FLAT (MAP mips_encode l)`

val mips_bop_r_def = Define`
   (mips_bop_r Add = DADDU) /\
   (mips_bop_r Sub = DSUBU) /\
   (mips_bop_r And = AND) /\
   (mips_bop_r Or  = OR) /\
   (mips_bop_r Xor = XOR)`

val mips_bop_i_def = Define`
   (mips_bop_i Add = DADDIU) /\
   (mips_bop_i And = ANDI) /\
   (mips_bop_i Or  = ORI) /\
   (mips_bop_i Xor = XORI)`

val mips_sh_def = Define`
   (mips_sh Lsl = DSLL) /\
   (mips_sh Lsr = DSRL) /\
   (mips_sh Asr = DSRA)`

val mips_sh32_def = Define`
   (mips_sh32 Lsl = DSLL32) /\
   (mips_sh32 Lsr = DSRL32) /\
   (mips_sh32 Asr = DSRA32)`

val mips_memop_def = Define`
   (mips_memop Load    = INL LD) /\
   (mips_memop Load32  = INL LWU) /\
   (mips_memop Load8   = INL LBU) /\
   (mips_memop Store   = INR SD) /\
   (mips_memop Store32 = INR SW) /\
   (mips_memop Store8  = INR SB)`

val mips_cmp_def = Define`
   (mips_cmp Equal    = (NONE, BEQ)) /\
   (mips_cmp Less     = (SOME (SLT, SLTI), BNE)) /\
   (mips_cmp Lower    = (SOME (SLTU, SLTIU), BNE)) /\
   (mips_cmp Test     = (SOME (AND, ANDI), BEQ)) /\
   (mips_cmp NotEqual = (NONE, BNE)) /\
   (mips_cmp NotLess  = (SOME (SLT, SLTI), BEQ)) /\
   (mips_cmp NotLower = (SOME (SLTU, SLTIU), BEQ)) /\
   (mips_cmp NotTest  = (SOME (AND, ANDI), BNE))`

val nop = ``Shift (SLL (0w, 0w, 0w))``

val mips_enc_def = Define`
   (mips_enc (Inst Skip) = mips_encode ^nop) /\
   (mips_enc (Inst (Const r (i: word64))) =
      let top    = (63 >< 32) i : word32
      and middle = (31 >< 16) i : word16
      and bottom = (15 ><  0) i : word16
      in
         if (top = 0w) /\ (middle = 0w) then
            mips_encode (ArithI (ORI (0w, n2w r, bottom)))
         else if (top = -1w) /\ (middle = -1w) /\ bottom ' 15 then
            mips_encode (ArithI (ADDIU (0w, n2w r, bottom)))
         else if (top = 0w) /\ ~middle ' 15 \/ (top = -1w) /\ middle ' 15 then
            encs [ArithI (LUI (n2w r, middle));
                  ArithI (XORI (n2w r, n2w r, bottom))]
         else
            encs [ArithI (LUI (n2w r, (31 >< 16) top));
                  ArithI (ORI (n2w r, n2w r, (15 >< 0) top));
                  Shift (DSLL (n2w r, n2w r, 16w));
                  ArithI (ORI (n2w r, n2w r, middle));
                  Shift (DSLL (n2w r, n2w r, 16w));
                  ArithI (ORI (n2w r, n2w r, bottom))]) /\
   (mips_enc (Inst (Arith (Binop bop r1 r2 (Reg r3)))) =
       mips_encode (ArithR (mips_bop_r bop (n2w r2, n2w r3, n2w r1)))) /\
   (mips_enc (Inst (Arith (Binop Sub r1 r2 (Imm i)))) = []) /\
   (mips_enc (Inst (Arith (Binop bop r1 r2 (Imm i)))) =
       mips_encode (ArithI (mips_bop_i bop (n2w r2, n2w r1, w2w i)))) /\
   (mips_enc (Inst (Arith (Shift sh r1 r2 n))) =
       let (f, n) = if n < 32 then (mips_sh, n) else (mips_sh32, n - 32) in
         mips_encode (Shift (f sh (n2w r2, n2w r1, n2w n)))) /\
   (mips_enc (Inst (Arith (AddCarry r1 r2 r3 r4))) =
       encs [ArithR (SLTU (0w, n2w r4, 1w));
             ArithR (DADDU (n2w r2, n2w r3, n2w r1));
             ArithR (SLTU (n2w r1, n2w r3, n2w r4));
             ArithR (DADDU (n2w r1, 1w, n2w r1));
             ArithR (SLTU (n2w r1, 1w, 1w));
             ArithR (OR (n2w r4, 1w, n2w r4))]) /\
   (mips_enc (Inst (Mem mop r1 (Addr r2 a))) =
       case mips_memop mop of
          INL f => mips_encode (Load (f (n2w r2, n2w r1, w2w a)))
        | INR f => mips_encode (Store (f (n2w r2, n2w r1, w2w a)))) /\
   (mips_enc (Jump a) =
       encs [Branch (BEQ (0w, 0w, w2w (a >>> 2) - 1w)); ^nop]) /\
   (mips_enc (JumpCmp c r1 (Reg r2) a) =
       let (f1, f2) = mips_cmp c and b = w2w (a >>> 2) - 2w in
       let l = case f1 of
                  SOME (f, _) =>
                   [ArithR (f (n2w r1, n2w r2, 1w)); Branch (f2 (1w, 0w, b))]
                | NONE =>
                   [Branch (f2 (n2w r1, n2w r2, b + 1w))]
       in
         encs (l ++ [^nop])) /\
   (mips_enc (JumpCmp c r (Imm i) a) =
       let (f1, f2) = mips_cmp c and b = w2w (a >>> 2) - 2w in
       let l = case f1 of
                  SOME (_, f) =>
                   [ArithI (f (n2w r, 1w, w2w i)); Branch (f2 (1w, 0w, b))]
                | NONE =>
                   [ArithI (DADDIU (0w, 1w, w2w i)); Branch (f2 (n2w r, 1w, b))]
       in
         encs (l ++ [^nop])) /\
   (mips_enc (Call a) =
       encs [Branch (BGEZAL (0w, w2w (a >>> 2) - 1w)); ^nop]) /\
   (mips_enc (JumpReg r) = encs [Branch (JR (n2w r)); ^nop]) /\
   (mips_enc (Loc r i) =
       encs
       (if r = 31 then
           [Branch (BLTZAL (0w, 0w));                    (* LR := pc + 8     *)
            ArithI (DADDIU (31w, n2w r, w2w (i - 8w)))]  (* r := LR - 8 + i  *)
        else
           [ArithI (ORI (31w, 1w, 0w));                  (* $1 := LR         *)
            Branch (BLTZAL (0w, 0w));                    (* LR := pc + 12    *)
            ArithI (DADDIU (31w, n2w r, w2w (i - 12w))); (* r := LR - 12 + i *)
            ArithI (ORI (1w, 31w, 0w))]))`               (* LR := $1         *)

val fetch_decode_def = Define`
   fetch_decode (b0 :: b1 :: b2 :: b3 :: (rest: word8 list)) =
   (Decode (b0 @@ b1 @@ b2 @@ b3), rest)`

val all_same_def = Define`
   (all_same (h::t) = EVERY ((=) h) t)`

val when_nop_def = Define`
   when_nop l (r: 64 asm) = case fetch_decode l of (^nop, _) => r`

val mips_dec_def = Lib.with_flag (Globals.priming, SOME "_") Define`
   mips_dec l =
   case fetch_decode l of
      (ArithR (SLT (r1, r2, 1w)), rest) =>
        (case fetch_decode rest of
            (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Less (w2n r1) (Reg (w2n r2)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotLess (w2n r1) (Reg (w2n r2))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithR (SLTU (r1, r2, 1w)), rest) =>
        (case fetch_decode rest of
            (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Lower (w2n r1) (Reg (w2n r2)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotLower (w2n r1) (Reg (w2n r2))
                          (sw2sw ((a + 2w) << 2)))
          | (ArithR (DADDU (r3, r4, r5)), rest1) =>
               (case fetch_decode rest1 of
                   (ArithR (SLTU (r6, r7, r8)), rest2) =>
                      (case fetch_decode rest2 of
                          (ArithR (DADDU (r9, 1w, r10)), rest3) =>
                             (case fetch_decode rest3 of
                                 (ArithR (SLTU (r11, 1w, 1w)), rest4) =>
                                    (case fetch_decode rest4 of
                                        (ArithR (OR (r12, 1w, r13)), _) =>
                                           if (r1 = 0w) /\
                                              (r2 = r8) /\ (r8 = r12) /\
                                              (r12 = r13) /\
                                              (r4 = r7) /\
                                              (r5 = r6) /\ (r6 = r9) /\
                                              (r9 = r10) /\ (r10 = r11) then
                                              Inst (Arith
                                                (AddCarry (w2n r5) (w2n r3)
                                                   (w2n r4) (w2n r2)))
                                           else ARB
                                      | _ => ARB)
                               | _ => ARB)
                        | _ => ARB)
                 | _ => ARB)
          | _ => ARB)
    | (ArithR (AND (r1, r2, 1w)), rest) =>
        (case fetch_decode rest of
            (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Test (w2n r1) (Reg (w2n r2)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotTest (w2n r1) (Reg (w2n r2))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithI (DADDIU (0w, 1w, i)), rest) =>
        (case fetch_decode rest of
            (Branch (BEQ (r, 1w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Equal (w2n r) (Imm (sw2sw i)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BNE (r, 1w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotEqual (w2n r) (Imm (sw2sw i))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithI (ORI (0w, r, i)), _) =>
        Inst (Const (w2n r) (w2w i : word64))
    | (ArithI (ADDIU (0w, r, i)), _) =>
        Inst (Const (w2n r) (sw2sw i : word64))
    | (ArithI (SLTI (r, 1w, i)), rest) =>
        (case fetch_decode rest of
            (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Less (w2n r) (Imm (sw2sw i)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotLess (w2n r) (Imm (sw2sw i))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithI (SLTIU (r, 1w, i)), rest) =>
        (case fetch_decode rest of
            (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Lower (w2n r) (Imm (sw2sw i)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotLower (w2n r) (Imm (sw2sw i))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithI (ANDI (r1, 1w, i)), rest) =>
        (case fetch_decode rest of
            (Branch (BEQ (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp Test (w2n r1) (Imm (w2w i)) (sw2sw ((a + 2w) << 2)))
          | (Branch (BNE (1w, 0w, a)), rest1) =>
               when_nop rest1
                 (JumpCmp NotTest (w2n r1) (Imm (w2w i))
                          (sw2sw ((a + 2w) << 2)))
          | _ => ARB)
    | (ArithI (ORI (31w, 1w, 0w)), rest0) =>
        (case fetch_decode rest0 of
            (Branch (BLTZAL (0w, 0w)), rest1) =>
              (case fetch_decode rest1 of
                  (ArithI (DADDIU (31w, rr, i)), rest2) =>
                    (case fetch_decode rest2 of
                        (ArithI (ORI (1w, 31w, 0w)), _) =>
                           Loc (w2n rr) (sw2sw i + 12w)
                      | _ => ARB)
                | _ => ARB)
          | _ => ARB)
    | (ArithI (LUI (r0, i0)), rest0) =>
        (case fetch_decode rest0 of
            (ArithI (XORI (r1, r2, i1)), _) =>
                if all_same [r0; r1; r2] then
                   Inst (Const (w2n r0) (sw2sw ((i0 @@ i1) : word32)))
                else
                   ARB
          | (ArithI (ORI (r1, r2, i1)), rest1) =>
              (case fetch_decode rest1 of
                  (Shift (DSLL (r3, r4, 16w)), rest2) =>
                    (case fetch_decode rest2 of
                        (ArithI (ORI (r5, r6, i2)), rest3) =>
                             (case fetch_decode rest3 of
                                 (Shift (DSLL (r7, r8, 16w)), rest4) =>
                                   (case fetch_decode rest4 of
                                       (ArithI (ORI (r9, r10, i3)), _) =>
                                          if all_same [r0; r1; r2; r3; r4; r5;
                                                       r6; r7; r8; r9; r10]
                                             then Inst (Const (w2n r0)
                                                         (i0 @@ i1 @@ i2 @@ i3))
                                          else ARB
                                     | _ => ARB)
                               | _ => ARB)
                      | _ => ARB)
                | _ => ARB)
          | _ => ARB)
    | (ArithR (DADDU (r1, r2, r3)), _) =>
        Inst (Arith (Binop Add (w2n r3) (w2n r1) (Reg (w2n r2))))
    | (ArithR (DSUBU (r1, r2, r3)), _) =>
        Inst (Arith (Binop Sub (w2n r3) (w2n r1) (Reg (w2n r2))))
    | (ArithR (AND (r1, r2, r3)), _) =>
        Inst (Arith (Binop And (w2n r3) (w2n r1) (Reg (w2n r2))))
    | (ArithR (OR (r1, r2, r3)), _) =>
        Inst (Arith (Binop Or (w2n r3) (w2n r1) (Reg (w2n r2))))
    | (ArithR (XOR (r1, r2, r3)), _) =>
        Inst (Arith (Binop Xor (w2n r3) (w2n r1) (Reg (w2n r2))))
    | (ArithI (DADDIU (r1, r2, i)), _) =>
        Inst (Arith (Binop Add (w2n r2) (w2n r1) (Imm (sw2sw i))))
    | (ArithI (ANDI (r1, r2, i)), _) =>
        Inst (Arith (Binop And (w2n r2) (w2n r1) (Imm (w2w i))))
    | (ArithI (ORI (r1, r2, i)), _) =>
        Inst (Arith (Binop Or (w2n r2) (w2n r1) (Imm (w2w i))))
    | (ArithI (XORI (r1, r2, i)), _) =>
        Inst (Arith (Binop Xor (w2n r2) (w2n r1) (Imm (w2w i))))
    | (Shift (SLL (0w, 0w, 0w)), _) =>
        Inst Skip
    | (Shift (DSLL (r1, r2, n)), _) =>
        Inst (Arith (Shift Lsl (w2n r2) (w2n r1) (w2n n)))
    | (Shift (DSRL (r1, r2, n)), _) =>
        Inst (Arith (Shift Lsr (w2n r2) (w2n r1) (w2n n)))
    | (Shift (DSRA (r1, r2, n)), _) =>
        Inst (Arith (Shift Asr (w2n r2) (w2n r1) (w2n n)))
    | (Shift (DSLL32 (r1, r2, n)), _) =>
        Inst (Arith (Shift Lsl (w2n r2) (w2n r1) (w2n n + 32)))
    | (Shift (DSRL32 (r1, r2, n)), _) =>
        Inst (Arith (Shift Lsr (w2n r2) (w2n r1) (w2n n + 32)))
    | (Shift (DSRA32 (r1, r2, n)), _) =>
        Inst (Arith (Shift Asr (w2n r2) (w2n r1) (w2n n + 32)))
    | (Load (LD (r2, r1, a)), _) =>
        Inst (Mem Load (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Load (LWU (r2, r1, a)), _) =>
        Inst (Mem Load32 (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Load (LBU (r2, r1, a)), _) =>
        Inst (Mem Load8 (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Store (SD (r2, r1, a)), _) =>
        Inst (Mem Store (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Store (SW (r2, r1, a)), _) =>
        Inst (Mem Store32 (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Store (SB (r2, r1, a)), _) =>
        Inst (Mem Store8 (w2n r1) (Addr (w2n r2) (sw2sw a)))
    | (Branch (BEQ (r1, r2, a)), rest) =>
        when_nop rest
           (let aa = sw2sw ((a + 1w) << 2) in
               if (r1 = 0w) /\ (r1 = r2) then
                  Jump aa
               else
                  JumpCmp Equal (w2n r1) (Reg (w2n r2)) aa)
    | (Branch (BNE (r1, r2, a)), rest) =>
        when_nop rest
           (JumpCmp NotEqual (w2n r1) (Reg (w2n r2)) (sw2sw ((a + 1w) << 2)))
    | (Branch (BGEZAL (0w, a)), rest) =>
        when_nop rest (Call (sw2sw ((a + 1w) << 2)))
    | (Branch (BLTZAL (0w, 0w)), rest) =>
        (case fetch_decode rest of
             (ArithI (DADDIU (31w, 31w, i)), rest2) =>
            Loc 31 (sw2sw i + 8w)
          | _ => ARB)
    | (Branch (JR r), rest) =>
        when_nop rest (JumpReg (w2n r))
    | _ => ARB`

val mips_proj_def = Define`
   mips_proj d s =
   (s.CP0.Config, s.CP0.Status.RE, s.exceptionSignalled,
    s.BranchDelay, s.BranchTo, s.exception, s.gpr, fun2set (s.MEM,d), s.PC)`

val mips_target_def = Define`
   mips_target =
   <| encode := mips_enc
    ; get_pc := mips_state_PC
    ; get_reg := (\s. mips_state_gpr s o n2w)
    ; get_byte := mips_state_MEM
    ; state_ok := mips_ok
    ; state_rel := mips_asm_state
    ; proj := mips_proj
    ; next := mips_next
    ; config := mips_config
    |>`

val () = export_theory ()
