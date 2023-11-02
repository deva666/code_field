// ignore_for_file: depend_on_referenced_packages

import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/armasm.dart';
import 'package:highlighting/languages/bash.dart';
import 'package:highlighting/languages/basic.dart';
import 'package:highlighting/languages/clojure.dart';
import 'package:highlighting/languages/cpp.dart';
import 'package:highlighting/languages/csharp.dart';
import 'package:highlighting/languages/d.dart';
import 'package:highlighting/languages/dockerfile.dart';
import 'package:highlighting/languages/elixir.dart';
import 'package:highlighting/languages/erlang.dart';
import 'package:highlighting/languages/fortran.dart';
import 'package:highlighting/languages/go.dart';
import 'package:highlighting/languages/groovy.dart';
import 'package:highlighting/languages/haskell.dart';
import 'package:highlighting/languages/java.dart';
import 'package:highlighting/languages/javascript.dart';
import 'package:highlighting/languages/lisp.dart';
import 'package:highlighting/languages/lua.dart';
import 'package:highlighting/languages/objectivec.dart';
import 'package:highlighting/languages/ocaml.dart';
import 'package:highlighting/languages/perl.dart';
import 'package:highlighting/languages/php.dart';
import 'package:highlighting/languages/prolog.dart';
import 'package:highlighting/languages/python.dart';
import 'package:highlighting/languages/r.dart';
import 'package:highlighting/languages/ruby.dart';
import 'package:highlighting/languages/rust.dart';
import 'package:highlighting/languages/scala.dart';
import 'package:highlighting/languages/sql.dart';
import 'package:highlighting/languages/swift.dart';
import 'package:highlighting/languages/typescript.dart';
import 'package:highlighting/src/language.dart';
import 'package:highlighting/languages/all.dart';

final _kLangToModeMap = <Language, String>{
  armasm: ';',
  bash: '#',
  basic: 'REM',
  // 48: cpp,
  // 49: cpp,
  cpp: '//',
  csharp: '//',
  // 52: cpp,
  // 53: cpp,
  cpp: '//',
  lisp: ';',
  d: '//',
  elixir: '#',
  erlang: '%',
  fortran: '!',
  go: '//',
  haskell: '--',
  java: '//',
  javascript: '//',
  lua: '--',
  ocaml: '',
  dockerfile: '#',
  // 67: _kPascal,
  php: '//',
  prolog: '%',
  python: '#',
  python: '#',
  ruby: '#',
  rust: '//',
  typescript: '//',
  cpp: '//',
  cpp: '//',
  dockerfile: '#',
  // 78: kotlin,
  objectivec: '//',
  r: '#',
  scala: '//',
  sql: '--',
  swift: '//',
  perl: '#',
  clojure: ';',
  // 87: fsharp,
  groovy: '//'
};

extension Comments on Language {
  String? getComment() => _kLangToModeMap[this];
}
