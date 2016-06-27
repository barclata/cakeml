structure encodeLib :> encodeLib =
struct

open HolKernel boolLib bossLib
open arm6_targetLib arm8_targetLib x64_targetLib mips_targetLib riscv_targetLib
open armAssemblerLib arm8AssemblerLib x64AssemblerLib mips riscv

(* ------------------------------------------------------------------------- *)

val () =
 ( computeLib.del_consts
     [``arm6_target$arm6_enc``, ``arm8_target$arm8_enc``,
      ``x64_target$x64_enc``, ``mips_target$mips_enc``,
       ``riscv_target$riscv_enc``, ``arm8_target$valid_immediate``]
 ; computeLib.extend_compset
    [computeLib.Extenders
       [arm6_targetLib.add_arm6_encode_compset,
        arm8_targetLib.add_arm8_encode_compset,
        x64_targetLib.add_x64_encode_compset,
        mips_targetLib.add_mips_encode_compset,
        riscv_targetLib.add_riscv_encode_compset,
        arm6_targetLib.add_arm6_decode_compset,
        arm8_targetLib.add_arm8_decode_compset,
        x64_targetLib.add_x64_decode_compset,
        mips_targetLib.add_mips_decode_compset,
        riscv_targetLib.add_riscv_decode_compset
       ]
    ] computeLib.the_compset
 )

val ty32 = fcpSyntax.mk_int_numeric_type 32
val ty64 = fcpSyntax.mk_int_numeric_type 64
val eval = rhs o concl o EVAL
fun string_quotation l = [QUOTE (String.concatWith " " l)] : string quotation

val mk_asm_ok = Lib.curry (#2 (HolKernel.syntax_fns2 "asm" "asm_ok"))
fun ok tm = Lib.equal boolSyntax.T o eval o mk_asm_ok tm

fun mk f s = #2 (HolKernel.syntax_fns1 (s ^ "_target") (s ^ "_" ^ f))
fun mk_enc_dec s = (mk "enc" s, mk "dec" s)

val (mk_arm6_enc, mk_arm6_dec) = mk_enc_dec "arm6"
val (mk_arm8_enc, mk_arm8_dec) = mk_enc_dec "arm8"
val (mk_x64_enc, mk_x64_dec) = mk_enc_dec "x64"
val (mk_mips_enc, mk_mips_dec) = mk_enc_dec "mips"
val (mk_riscv_enc, mk_riscv_dec) = mk_enc_dec "riscv"

fun config_tm s = Term.prim_mk_const {Name = s ^ "_config", Thy = s ^ "_target"}
val arm6_config = config_tm "arm6"
val arm8_config = config_tm "arm8"
val mips_config = config_tm "mips"
val riscv_config = config_tm "riscv"
val x64_config = config_tm "x64"

local
  fun segment4 l =
    let
      fun seg4 a l =
         let
           val (x, y) = Lib.split_after 4 l handle HOL_ERR _ => (l, [])
         in
           if List.null y then List.rev (l :: a) else seg4 (x :: a) y
         end
    in
      seg4 [] l
    end
in
  val hex_list =
    List.map (StringCvt.padLeft #"0" 2 o Arbnum.toHexString o
              wordsSyntax.dest_word_literal) o
    fst o listSyntax.dest_list
  fun split32 bigend t =
    t |> hex_list
      |> segment4
      |> List.map (String.concat o (if bigend then Lib.I else List.rev))
end

local
  val max_size = List.foldl (fn (s, n) => Int.max (n, String.size s)) 0
  fun print_disassemble l =
    let
      val mx = max_size (snd (ListPair.unzip l))
    in
      List.app
        (fn (b, s) => print (StringCvt.padRight #" " mx (utilsLib.lowercase s) ^
                             " ; " ^ utilsLib.lowercase b ^ "\n")) l
    end
  fun mips_to_string s =
     mips.instructionToString
       (mips.Decode (Option.valOf (BitsN.fromHexString (s, 32))))
  fun riscv_to_string s =
     riscv.instructionToString
       (riscv.Decode (Option.valOf (BitsN.fromHexString (s, 32))))
in
  val print_x64_disassemble =
    print_disassemble o x64AssemblerLib.x64_disassemble_term
  fun print_mips_disassemble l =
    print_disassemble (ListPair.zip (l, List.map mips_to_string l))
  fun print_riscv_disassemble l =
    print_disassemble (ListPair.zip (l, List.map riscv_to_string l))
end

local
  fun line i = String.concat (List.tabulate (i, fn _ => UTF8.chr 0x23BA))
in
  fun print_heading s = print ("\n" ^ s ^ "\n" ^ line (String.size s) ^ "\n")
  fun print_not_ok () = print "[not asm_ok]\n"
end

local
  val cnv = Conv.REWR_CONV (GSYM wordsTheory.n2w_mod)
            THENC Conv.RAND_CONV (Conv.RAND_CONV wordsLib.SIZES_CONV)
            THENC numLib.REDUCE_CONV
  fun reduce_literal_conv tm =
    if fst (wordsSyntax.dest_mod_word_literal tm) =
       wordsSyntax.dest_word_literal tm
      then raise ERR "reduce_literal" "already reduced"
    else cnv tm
  val REDUCE_LITERALS_CONV = Conv.DEPTH_CONV reduce_literal_conv
in
  val reduce = boolSyntax.rhs o Thm.concl o Conv.QCONV REDUCE_LITERALS_CONV
end

fun check_dec tm f (l : term) =
  let
    val d = eval (f l)
  in
    if d = tm then ()
    else ( print "[decode mismatch]\n"
         ; Parse.print_term d
         ; print "\n"
         )
  end

fun encoding q =
  let
    val tm = Feedback.trace ("notify type variable guesses", 0) Parse.Term q
    val tm32 = reduce (Term.inst [Type.alpha |-> ty32] tm)
    val tm64 = reduce (Term.inst [Type.alpha |-> ty64] tm)
    val ok64 = ok tm64
    val asm32 = Parse.term_to_string tm32
    val asm64 = Parse.term_to_string tm64
  in
    { asm = fn SOME is64 => print (if is64 then asm64 else asm32)
             | NONE =>
                 if asm32 = asm64 then print asm32
                 else print ("32 asm: " ^ asm32 ^ "\n    64 asm: " ^ asm64),
      arm6 = fn () =>
              if ok tm32 arm6_config
                then let
                       val l = eval (mk_arm6_enc tm32)
                     in
                       armAssemblerLib.print_arm_disassemble
                         (string_quotation (split32 false l))
                     ; check_dec tm32 mk_arm6_dec l
                     end
              else print_not_ok (),
      arm8 = fn () =>
              if ok64 arm8_config
                then let
                       val l = eval (mk_arm8_enc tm64)
                     in
                       arm8AssemblerLib.print_arm8_disassemble
                         (string_quotation (split32 false l))
                     ; check_dec tm64 mk_arm8_dec l
                     end
              else print_not_ok (),
      x64 = fn () =>
              if ok64 x64_config
                then let
                       val l = eval (mk_x64_enc tm64)
                     in
                       print_x64_disassemble l
                     ; check_dec tm64 mk_x64_dec l
                     end
              else print_not_ok (),
      mips = fn () =>
              if ok64 mips_config
                then let
                       val l = (eval (mk_mips_enc tm64))
                     in
                       print_mips_disassemble (split32 true l)
                     ; check_dec tm64 mk_mips_dec l
                     end
              else print_not_ok (),
      riscv = fn () =>
              if ok64 riscv_config
                then let
                       val l = eval (mk_riscv_enc tm64)
                     in
                       print_riscv_disassemble (split32 false l)
                     ; check_dec tm64 mk_riscv_dec l
                     end
              else print_not_ok ()
    }
  end

datatype arch = Compare | All | ARMv6 | ARMv8 | x86_64 | MIPS | RISCV

fun encodings arches l =
  let
    val es = List.map encoding l
    fun yes a = Lib.mem All arches orelse Lib.mem a arches
  in
    if Lib.mem Compare arches
       then let
              fun pr h a f = if yes a then (print_heading h; f ()) else ()
            in
              List.app
                (fn {arm6, arm8, asm, mips, riscv, x64} =>
                        ( print_heading "ASM"
                        ; asm NONE
                        ; print "\n"
                        ; pr "ARMv6" ARMv6 arm6
                        ; pr "ARMv8" ARMv8 arm8
                        ; pr "x86-64" x86_64 x64
                        ; pr "MIPS-64" MIPS mips
                        ; pr "RISC-V" RISCV riscv
                        )) es
            end
    else let
           fun pr h a f =
             if yes a
               then ( print_heading h
                    ; General.ignore
                        (List.app (fn p => ( print (UTF8.chr 0x2022 ^ " ")
                                           ; #asm p (SOME (a <> ARMv6))
                                           ; print "\n"
                                           ; f p ()
                                           ; print "\n")) es)
                    )
             else ()
         in
           pr "ARMv6" ARMv6 (#arm6)
         ; pr "ARMv8" ARMv8 (#arm8)
         ; pr "x86-64" x86_64 (#x64)
         ; pr "MIPS-64" MIPS (#mips)
         ; pr "RISC-V" RISCV (#riscv)
         end
  end

(*

val () = encodings [All]
   [
    `Inst Skip`,
    `Inst (Const 8 0w)`,
    `Inst (Const 2 0x100000000w)`,
    `Inst (Const 2 0x100000001w)`,
    `Inst (Const 2 0x100010001w)`,
    `Inst (Arith (Binop Add 2 2 (Imm 1w)))`,
    `Inst (Arith (Binop Add 2 2 (Imm 0x10000w)))`,
    `Inst (Arith (Binop Add 2 2 (Reg 3)))`,
    `Inst (Arith (Binop Or 2 2 (Imm 0xFFw)))`,
    `Inst (Arith (Shift Lsr 2 2 1))`,
    `Inst (Arith (Shift Asr 2 2 1))`,
    `Inst (Arith (AddCarry 2 2 3 6))`,
    `Inst (Mem Load 2 (Addr 3 0w))`,
    `Inst (Mem Load 2 (Addr 3 0x10w))`,
    `Inst (Mem Load8 2 (Addr 3 0x10w))`,
    `Inst (Mem Load32 2 (Addr 3 0x10w))`,
    `Inst (Mem Store 2 (Addr 3 0w))`,
    `Inst (Mem Store 2 (Addr 3 0x10w))`,
    `Inst (Mem Store8 2 (Addr 3 0x10w))`,
    `Inst (Mem Store32 2 (Addr 3 0x10w))`,
    `Jump 12w`,
    `JumpCmp Less 2 (Reg 3) 12w`,
    `JumpCmp NotLess 2 (Imm 1w) 12w`,
    `Call 0x10w`,
    `JumpReg 2`,
    `Loc 2 0xF00w`
   ]

*)

end
