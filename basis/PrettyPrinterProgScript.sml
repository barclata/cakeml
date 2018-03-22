open
  preamble
  ml_translatorLib
  ml_progLib
  TextIOProgTheory
  mlprettyprinterTheory

val _ = (
  new_theory "PrettyPrinterProg";
  translation_extends "TextIOProg";
  generate_sigs := true;
  ml_prog_update (open_module "PrettyPrinter")
)

val _ = register_type``:'a app_list``;
val _ = theorem "MISC_APP_LIST_TYPE_def";

fun tr name def = (
  next_ml_names := [name];
  translate def
)

val _ = tr "fromString" fromString_def
val _ = tr "fromChar" fromChar_def
val _ = tr "fromBool" fromBool_def
val _ = tr "fromInt" fromInt_def
val _ = tr "fromNum" fromNum_def
val _ = tr "fromWord8" fromWord8_def
val _ = tr "fromWord64" fromWord64_def
val _ = tr "fromRat" fromRat_def
val _ = tr "fromOption" fromOption_def
val _ = tr "fromList" fromList_def
val _ = tr "fromArray" fromArray_def
val _ = tr "fromVector" fromVector_def

val sigs = module_signatures [
  "fromString",
  "fromChar",
  "fromBool",
  "fromInt",
  "fromNum",
  "fromWord8",
  "fromWord64",
  "fromRat",
  "fromOption",
  "fromList",
  "fromArray",
  "fromVector"
]

val _ = ml_prog_update (close_module (SOME sigs))
val _ = export_theory ()
