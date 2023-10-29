// ignore_for_file: depend_on_referenced_packages

import 'package:highlight/highlight.dart';
import 'package:highlight/languages/armasm.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/basic.dart';
import 'package:highlight/languages/clojure.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/cs.dart';
import 'package:highlight/languages/d.dart';
import 'package:highlight/languages/dockerfile.dart';
import 'package:highlight/languages/elixir.dart';
import 'package:highlight/languages/erlang.dart';
import 'package:highlight/languages/fortran.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/groovy.dart';
import 'package:highlight/languages/haskell.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/lisp.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/objectivec.dart';
import 'package:highlight/languages/ocaml.dart';
import 'package:highlight/languages/perl.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/prolog.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/r.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/scala.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/typescript.dart';

final _kLangToModeMap = <Mode, String>{
  armasm: ';',
  bash: '#',
  basic: 'REM',
  // 48: cpp,
  // 49: cpp,
  cpp: '//',
  cs: '//',
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

extension Comments on Mode {
  String? getComment() => _kLangToModeMap[this];
}
