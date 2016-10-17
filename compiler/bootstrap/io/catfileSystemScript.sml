open preamble

open monadsyntax

val _ = new_theory "catfileSystem";

val _ = overload_on ("return", ``SOME``)
val _ = overload_on ("fail", ``NONE``)
val _ = overload_on ("SOME", ``SOME``)
val _ = overload_on ("NONE", ``NONE``)
val _ = overload_on ("monad_bind", ``OPTION_BIND``)
val _ = overload_on ("monad_unit_bind", ``OPTION_IGNORE_BIND``)

val ALOOKUP_EXISTS_IFF = Q.store_thm(
  "ALOOKUP_EXISTS_IFF",
  `(∃v. ALOOKUP alist k = SOME v) ⇔ (∃v. MEM (k,v) alist)`,
  Induct_on `alist` >> simp[FORALL_PROD] >> rw[] >> metis_tac[]);

val _ = Datatype`
  RO_fs = <| files : (string # string) list ;
             infds : (num # (string # num)) list ;
             stdout : string
  |>
`

val wfFS_def = Define`
  wfFS fs =
    ∀fd. fd ∈ FDOM (alist_to_fmap fs.infds) ⇒
         ∃fnm off. ALOOKUP fs.infds fd = SOME (fnm,off) ∧
                   fnm ∈ FDOM (alist_to_fmap fs.files)
`;

val nextFD_def = Define`
  nextFD fsys = LEAST n. ~ MEM n (MAP FST fsys.infds)
`;

val writeStdOut_def = Define`
  writeStdOut c fsys =
    SOME (fsys with stdout := fsys.stdout ++ [c])
`;

val openFile_def = Define`
  openFile fnm fsys =
     let fd = nextFD fsys
     in
       do
          ALOOKUP fsys.files fnm ;
          return (fd, fsys with infds := (nextFD fsys, (fnm, 0)) :: fsys.infds)
       od
`;

val openFileFS_def = Define`
  openFileFS fnm fs =
    case openFile fnm fs of
      NONE => fs
    | SOME (_, fs') => fs'
`;

val wfFS_openFile = Q.store_thm(
  "wfFS_openFile",
  `wfFS fs ⇒ wfFS (openFileFS fnm fs)`,
  simp[openFileFS_def, openFile_def] >>
  Cases_on `ALOOKUP fs.files fnm` >> simp[] >>
  dsimp[wfFS_def, MEM_MAP, EXISTS_PROD, FORALL_PROD] >> rw[] >>
  metis_tac[ALOOKUP_EXISTS_IFF]);

val eof_def = Define`
  eof fd fsys =
    do
      (fnm,pos) <- ALOOKUP fsys.infds fd ;
      contents <- ALOOKUP fsys.files fnm ;
      return (LENGTH contents <= pos)
    od
`;

val wfFS_eof_EQ_SOME = Q.store_thm(
  "wfFS_eof_EQ_SOME",
  `wfFS fs ∧ fd ∈ FDOM (alist_to_fmap fs.infds) ⇒
   ∃b. eof fd fs = SOME b`,
  simp[eof_def, EXISTS_PROD, PULL_EXISTS, MEM_MAP, wfFS_def] >>
  rpt strip_tac >> res_tac >> metis_tac[ALOOKUP_EXISTS_IFF]);

val A_DELKEY_def = Define`
  A_DELKEY k alist = FILTER (λp. FST p <> k) alist
`;

val fgetc_def = Define`
  fgetc fd fsys =
    do
       (fnm, off) <- ALOOKUP fsys.infds fd ;
       content <- ALOOKUP fsys.files fnm ;
       if off < LENGTH content then
         return
           (SOME (EL off content),
            fsys with infds := (fd,(fnm,off+1)) :: A_DELKEY fd fsys.infds)
       else
         return (NONE, fsys)
    od
`;

val closeFD_def = Define`
  closeFD fd fsys =
    do
       ALOOKUP fsys.infds fd ;
       return ((), fsys with infds := A_DELKEY fd fsys.infds)
    od
`;

(* ----------------------------------------------------------------------
    Coding RO_fs values as ffi values
   ---------------------------------------------------------------------- *)

val destStr_def = Define`
  (destStr (Str s) = SOME s) ∧
  (destStr _ = NONE)
`
val _ = export_rewrites ["destStr_def"]

val destNum_def = Define`
  (destNum (Num n) = SOME n) ∧
  (destNum _ = NONE)
`;
val _ = export_rewrites ["destNum_def"]

val encode_pair_def = Define`
  encode_pair e1 e2 (x,y) = Cons (e1 x) (e2 y)
`;

val decode_pair_def = Define`
  (decode_pair d1 d2 (Cons f1 f2) =
      do
        x <- d1 f1;
        y <- d2 f2;
        return (x,y)
      od) ∧
  (decode_pair _ _ _ = fail)
`;

val decode_encode_pair = Q.store_thm(
  "decode_encode_pair",
  `(∀x. d1 (e1 x) = return x) ∧ (∀y. d2 (e2 y) = return y) ⇒
   ∀p. decode_pair d1 d2 (encode_pair e1 e2 p) = return p`,
  strip_tac >> Cases >> simp[encode_pair_def, decode_pair_def])

val encode_list_def = Define`
  encode_list e l = List (MAP e l)
`;

val OPT_MMAP_def = Define`
  (OPT_MMAP f [] = return []) ∧
  (OPT_MMAP f (h0::t0) = do h <- f h0 ; t <- OPT_MMAP f t0 ; return (h::t) od)
`;

val decode_list_def = Define`
  (decode_list d (List fs) = OPT_MMAP d fs) ∧
  (decode_list d _ = fail)
`;

val decode_encode_list = Q.store_thm(
  "decode_encode_list[simp]",
  `(∀x. d (e x) = return x) ⇒
   ∀l. decode_list d (encode_list e l) = return l`,
  strip_tac >> simp[decode_list_def, encode_list_def] >> Induct >>
  simp[OPT_MMAP_def]);

val encode_files_def = Define`
  encode_files fs = encode_list (encode_pair Str Str) fs
`;

val encode_fds_def = Define`
  encode_fds fds =
     encode_list (encode_pair Num (encode_pair Str Num)) fds
`;

val encode_def = Define`
  encode fs = cfHeapsBase$Cons
                         (encode_files fs.files)
                         (Cons (encode_fds fs.infds) (Str fs.stdout))
`


val decode_files_def = Define`
  decode_files f = decode_list (decode_pair destStr destStr) f
`

val decode_encode_files = store_thm(
  "decode_encode_files",
  “∀l. decode_files (encode_files l) = return l”,
  simp[encode_files_def, decode_files_def] >>
  simp[decode_encode_list, decode_encode_pair]);

val decode_fds_def = Define`
  decode_fds = decode_list (decode_pair destNum (decode_pair destStr destNum))
`;

val decode_encode_fds = Q.store_thm(
  "decode_encode_fds",
  `decode_fds (encode_fds fds) = return fds`,
  simp[decode_fds_def, encode_fds_def] >>
  simp[decode_encode_list, decode_encode_pair]);

val decode_def = Define`
  (decode (Cons files0 (Cons fds0 stdout0)) =
     do
        files <- decode_files files0 ;
        fds <- decode_fds fds0 ;
        stdout <- destStr stdout0 ;
        return <| files := files ; infds := fds ; stdout := stdout |>
     od) ∧
  (decode _ = fail)
`;

val decode_encode_FS = Q.store_thm(
  "decode_encode_FS[simp]",
  `decode (encode fs) = return fs`,
  simp[decode_def, encode_def, decode_encode_files, decode_encode_fds] >>
  simp[theorem "RO_fs_component_equality"]);

val encode_11 = Q.store_thm(
  "encode_11[simp]",
  `encode fs1 = encode fs2 ⇔ fs1 = fs2`,
  metis_tac[decode_encode_FS, SOME_11]);

(* ----------------------------------------------------------------------
    Making the above available in the ffi_next view of the world
   ----------------------------------------------------------------------

    There are four operations to be used in the example:

    1. write char to stdout
    2. open file
    3. read char from file descriptor
    4. close file

    The existing example that handles stdout and the write operation
    labels that operation with 0; we might as well keep that, and then
    number the others above 1, 2 and 3. There should probably be a
    better way of developing this numbering methodically (and
    compositionally?).

   ---------------------------------------------------------------------- *)

val getNullTermStr_def = Define`
  getNullTermStr (bytes : word8 list) =
     let sz = findi 0w bytes
     in
       if sz = LENGTH bytes then NONE
       else SOME(MAP (CHR o w2n) (TAKE sz bytes))
`


val fs_ffi_next_def = Define`
  fs_ffi_next (n:num) bytes fs_ffi =
    do
      fs <- decode fs_ffi ;
      case n of
        0 => do (* write *)
               assert(LENGTH bytes = 1);
               fs' <- writeStdOut (CHR (w2n (HD bytes))) fs;
               return (bytes, encode fs')
             od
      | 1 => do (* open file *)
               fname <- getNullTermStr bytes;
               (fd, fs') <- openFile fname fs;
               assert(fd < 256);
               return (LUPDATE (n2w fd) 0 bytes, encode fs')
             od
      | 2 => do
               assert(LENGTH bytes = 1);
               (copt, fs') <- fgetc (w2n (HD bytes)) fs;
               case copt of
                   NONE => return ([255w], encode fs')
                 | SOME c => return ([n2w (ORD c)], encode fs')
             od
      | 3 => do
               assert(LENGTH bytes = 1);
               (_, fs') <- closeFD (w2n (HD bytes)) fs;
               return (bytes, encode fs')
             od
      | 4 => do (* eof check *)
               assert(LENGTH bytes = 1);
               b <- eof (w2n (HD bytes)) fs ;
               return (LUPDATE (if b then 1w else 0w) 0 bytes, encode fs)
             od
      | _ => fail
    od
`;

val closeFD_lemma = Q.store_thm(
  "closeFD_lemma",
  `fd ∈ FDOM (alist_to_fmap fs.infds) ∧ fd < 256
     ⇒
   fs_ffi_next 3 [n2w fd] (encode fs) =
     SOME ([n2w fd], encode (fs with infds updated_by A_DELKEY fd))`,
  simp[fs_ffi_next_def, decode_encode_FS, closeFD_def, PULL_EXISTS,
       theorem "RO_fs_component_equality", MEM_MAP, FORALL_PROD,
       ALOOKUP_EXISTS_IFF] >> metis_tac[]);

val write_lemma = Q.store_thm(
  "write_lemma",
  `fs_ffi_next 0 [c] (encode fs) =
     SOME ([c], encode (fs with stdout := fs.stdout ++ [CHR (w2n c)]))`,
  simp[fs_ffi_next_def, decode_encode_FS, writeStdOut_def]);

(* insert null-terminated-string (l1) at specified index (n) in a list (l2) *)
val insertNTS_atI_def = Define`
  insertNTS_atI (l1:word8 list) n l2 =
    TAKE n l2 ++ l1 ++ [0w] ++ DROP (n + LENGTH l1 + 1) l2
`;

val insertNTS_atI_NIL = Q.store_thm(
  "insertNTS_atI_NIL",
  `∀n l. n < LENGTH l ==> insertNTS_atI [] n l = LUPDATE 0w n l`,
  simp[insertNTS_atI_def] >> Induct_on `n`
  >- (Cases_on `l` >> simp[LUPDATE_def]) >>
  Cases_on `l` >> simp[LUPDATE_def, ADD1]);

val insertNTS_atI_CONS = Q.store_thm(
  "insertNTS_atI_CONS",
  `∀n l h t.
     n + LENGTH t + 1 < LENGTH l ==>
     insertNTS_atI (h::t) n l = LUPDATE h n (insertNTS_atI t (n + 1) l)`,
  simp[insertNTS_atI_def] >> Induct_on `n`
  >- (Cases_on `l` >> simp[ADD1, LUPDATE_def]) >>
  Cases_on `l` >> simp[ADD1] >> fs[ADD1] >>
  simp[GSYM ADD1, LUPDATE_def]);

val LUPDATE_commutes = Q.store_thm(
  "LUPDATE_commutes",
  `∀m n e1 e2 l.
    m ≠ n ⇒
    LUPDATE e1 m (LUPDATE e2 n l) = LUPDATE e2 n (LUPDATE e1 m l)`,
  Induct_on `l` >> simp[LUPDATE_def] >>
  Cases_on `m` >> simp[LUPDATE_def] >> rpt strip_tac >>
  rename[`LUPDATE _ nn (_ :: _)`] >>
  Cases_on `nn` >> fs[LUPDATE_def]);

val LUPDATE_insertNTS_commute = Q.store_thm(
  "LUPDATE_insertNTS_commute",
  `∀ws pos1 pos2 a w.
     pos2 < pos1 ∧ pos1 + LENGTH ws < LENGTH a
       ⇒
     insertNTS_atI ws pos1 (LUPDATE w pos2 a) =
       LUPDATE w pos2 (insertNTS_atI ws pos1 a)`,
  Induct >> simp[insertNTS_atI_NIL, insertNTS_atI_CONS, LUPDATE_commutes]);

val findi_APPEND = Q.store_thm(
  "findi_APPEND",
  `∀l1 l2 x.
      findi x (l1 ++ l2) =
        let n0 = findi x l1
        in
          if n0 = LENGTH l1 then n0 + findi x l2
          else n0`,
  Induct >> simp[findi_def] >> rw[] >> fs[]);

val EVERY_neq_findi = Q.store_thm(
  "EVERY_neq_findi",
  `EVERY (λx. x ≠ e) l ⇒ findi e l = LENGTH l`,
  Induct_on `l` >> simp[findi_def]);

val getNullTermStr_insertNTS_atI = Q.store_thm(
  "getNullTermStr_insertNTS_atI",
  `∀cs l. LENGTH cs < LENGTH l ∧ EVERY (λc. c ≠ 0w) cs ⇒
          getNullTermStr (insertNTS_atI cs 0 l) = SOME (MAP (CHR o w2n) cs)`,
  simp[getNullTermStr_def, insertNTS_atI_def, findi_APPEND, EVERY_neq_findi,
       findi_def, TAKE_APPEND])

val LENGTH_insertNTS_atI = Q.store_thm(
  "LENGTH_insertNTS_atI",
  `p + LENGTH l1 < LENGTH l2 ⇒ LENGTH (insertNTS_atI l1 p l2) = LENGTH l2`,
  simp[insertNTS_atI_def]);

val _ = export_theory()