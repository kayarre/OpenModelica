/*
 * This file is part of OpenModelica.
 *
 * Copyright (c) 1998-2014, Open Source Modelica Consortium (OSMC),
 * c/o Linköpings universitet, Department of Computer and Information Science,
 * SE-58183 Linköping, Sweden.
 *
 * All rights reserved.
 *
 * THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
 * THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
 * ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
 * RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
 * ACCORDING TO RECIPIENTS CHOICE.
 *
 * The OpenModelica software and the Open Source Modelica
 * Consortium (OSMC) Public License (OSMC-PL) are obtained
 * from OSMC, either from the above address,
 * from the URLs: http://www.ida.liu.se/projects/OpenModelica or
 * http://www.openmodelica.org, and in the OpenModelica distribution.
 * GNU version 3 is obtained from: http://www.gnu.org/copyleft/gpl.html.
 *
 * This program is distributed WITHOUT ANY WARRANTY; without
 * even the implied warranty of  MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
 * IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
 *
 * See the full OSMC Public License conditions for more details.
 *
 */

encapsulated uniontype NFStatement
  import Type = NFType;
  import Expression = NFExpression;
  import NFInstNode.InstNode;
  import DAE;
  import ComponentRef = NFComponentRef;

protected
  import Statement = NFStatement;
  import ElementSource;
  import FlatModelicaUtil = NFFlatModelicaUtil;
  import Util;
  import IOStream;

public
  uniontype ForType
    record NORMAL end NORMAL;

    record PARALLEL
      list<tuple<ComponentRef, SourceInfo>> vars;
    end PARALLEL;
  end ForType;

public
  record ASSIGNMENT
    Expression lhs "The asignee";
    Expression rhs "The expression";
    Type ty;
    DAE.ElementSource source;
  end ASSIGNMENT;

  record FUNCTION_ARRAY_INIT "Used to mark in which order local array variables in functions should be initialized"
    String name;
    Type ty;
    DAE.ElementSource source;
  end FUNCTION_ARRAY_INIT;

  record FOR
    InstNode iterator;
    Option<Expression> range;
    list<Statement> body "The body of the for loop.";
    ForType forType;
    DAE.ElementSource source;
  end FOR;

  record IF
    list<tuple<Expression, list<Statement>>> branches
      "List of branches, where each branch is a tuple of a condition and a body.";
    DAE.ElementSource source;
  end IF;

  record WHEN
    list<tuple<Expression, list<Statement>>> branches
      "List of branches, where each branch is a tuple of a condition and a body.";
    DAE.ElementSource source;
  end WHEN;

  record ASSERT
    Expression condition "The assert condition.";
    Expression message "The message to display if the assert fails.";
    Expression level;
    DAE.ElementSource source;
  end ASSERT;

  record TERMINATE
    Expression message "The message to display if the terminate triggers.";
    DAE.ElementSource source;
  end TERMINATE;

  record REINIT
    Expression cref;
    Expression reinitExp;
    DAE.ElementSource source;
  end REINIT;

  record NORETCALL
    Expression exp;
    DAE.ElementSource source;
  end NORETCALL;

  record WHILE
    Expression condition;
    list<Statement> body;
    DAE.ElementSource source;
  end WHILE;

  record RETURN
    DAE.ElementSource source;
  end RETURN;

  record BREAK
    DAE.ElementSource source;
  end BREAK;

  record FAILURE
    list<Statement> body;
    DAE.ElementSource source;
  end FAILURE;

  function isDiscrete
    input Statement stmt;
    output Boolean b;
  algorithm
    b := match stmt
      case ASSIGNMENT()           then Type.isDiscrete(stmt.ty);
      case FUNCTION_ARRAY_INIT()  then Type.isDiscrete(stmt.ty);
      case WHEN()                 then true;
      case ASSERT()               then true;
      case TERMINATE()            then true;
      case REINIT()               then true;
                                  else false;
    end match;
  end isDiscrete;

  function filterDiscrete
    input list<Statement> stmts;
    input output list<Statement> out_stmts = {};
  protected
    Statement stmt;
    list<Statement> rest;
  algorithm
    out_stmts := match stmts
      case (stmt as FOR()) :: rest algorithm
        stmt.body := filterDiscrete(stmt.body);
        out_stmts := if listLength(stmt.body) == 0 then out_stmts else stmt :: out_stmts;
      then filterDiscrete(rest, out_stmts);
      case (stmt as IF()) :: rest algorithm
        // ToDo: remove empty branches after removal
        // Note: need to be careful to carry inverted conditions of removed branches
        stmt.branches := list((Util.tuple21(tpl), filterDiscrete(Util.tuple22(tpl))) for tpl in stmt.branches);
      then filterDiscrete(rest, stmt :: out_stmts);
      case stmt :: rest guard(isDiscrete(stmt)) then filterDiscrete(rest, out_stmts);
      case stmt :: rest then filterDiscrete(rest, stmt :: out_stmts);
      else listReverse(out_stmts);
    end match;
  end filterDiscrete;

  function isEqual
    input Statement stmt1;
    input Statement stmt2;
    output Boolean b;
  protected
    function branchEqual
      input tuple<Expression, list<Statement>> branch1;
      input tuple<Expression, list<Statement>> branch2;
      output Boolean b;
    protected
      Expression e1, e2;
      list<Statement> b1, b2;
    algorithm
      (e1, b1) := branch1;
      (e2, b2) := branch2;
      b := Expression.isEqual(e1,e2) and List.isEqualOnTrue(b1, b2, isEqual);
    end branchEqual;
  algorithm
    b := match (stmt1, stmt2)
      case (ASSIGNMENT(), ASSIGNMENT()) then Expression.isEqual(stmt1.lhs, stmt2.lhs)
        and Expression.isEqual(stmt1.rhs, stmt2.rhs);
      case (FUNCTION_ARRAY_INIT(), FUNCTION_ARRAY_INIT()) then stringEqual(stmt1.name, stmt2.name);
      case (FOR(), FOR()) then InstNode.nameEqual(stmt1.iterator, stmt2.iterator)
        and Util.optionEqual(stmt1.range, stmt2.range, Expression.isEqual)
        and List.isEqualOnTrue(stmt1.body, stmt2.body, isEqual);
      case (IF(), IF()) then List.isEqualOnTrue(stmt1.branches, stmt2.branches, branchEqual);
      case (WHEN(), WHEN()) then List.isEqualOnTrue(stmt1.branches, stmt2.branches, branchEqual);
      case (ASSERT(), ASSERT()) then Expression.isEqual(stmt1.condition, stmt2.condition)
        and Expression.isEqual(stmt1.message, stmt2.message)
        and Expression.isEqual(stmt1.level, stmt2.level);
      case (TERMINATE(), TERMINATE()) then Expression.isEqual(stmt1.message, stmt2.message);
      case (REINIT(), REINIT()) then Expression.isEqual(stmt1.cref, stmt2.cref)
        and Expression.isEqual(stmt1.reinitExp, stmt2.reinitExp);
      case (NORETCALL(), NORETCALL()) then Expression.isEqual(stmt1.exp, stmt2.exp);
      case (WHILE(), WHILE()) then Expression.isEqual(stmt1.condition, stmt2.condition)
        and List.isEqualOnTrue(stmt1.body, stmt2.body, isEqual);
      case (RETURN(), RETURN()) then true;
      case (BREAK(), BREAK()) then true;
      case (FAILURE(), FAILURE()) then List.isEqualOnTrue(stmt1.body, stmt2.body, isEqual);
      else false;
    end match;
  end isEqual;

  function makeAssignment
    input Expression lhs;
    input Expression rhs;
    input Type ty;
    input DAE.ElementSource src;
    output Statement stmt;
  algorithm
    stmt := ASSIGNMENT(lhs, rhs, ty, src);
    annotation(__OpenModelica_EarlyInline=true);
  end makeAssignment;

  function isAssignment
    input Statement stmt;
    output Boolean res;
  algorithm
    res := match stmt
      case ASSIGNMENT() then true;
      else false;
    end match;
  end isAssignment;

  function isWhen
    input Statement stmt;
    output Boolean res;
  algorithm
    res := match stmt
      case WHEN() then true;
      else false;
    end match;
  end isWhen;

  function makeIf
    input list<tuple<Expression, list<Statement>>> branches;
    input DAE.ElementSource src;
    output Statement stmt;
  algorithm
    stmt := IF(branches, src);
    annotation(__OpenModelica_EarlyInline=true);
  end makeIf;

  function source
    input Statement stmt;
    output DAE.ElementSource source;
  algorithm
    source := match stmt
      case ASSIGNMENT() then stmt.source;
      case FUNCTION_ARRAY_INIT() then stmt.source;
      case FOR() then stmt.source;
      case IF() then stmt.source;
      case WHEN() then stmt.source;
      case ASSERT() then stmt.source;
      case TERMINATE() then stmt.source;
      case REINIT() then stmt.source;
      case NORETCALL() then stmt.source;
      case WHILE() then stmt.source;
      case RETURN() then stmt.source;
      case BREAK() then stmt.source;
      case FAILURE() then stmt.source;
    end match;
  end source;

  function setSource
    input DAE.ElementSource source;
    input output Statement stmt;
  algorithm
    () := match stmt
      case ASSIGNMENT()          algorithm stmt.source := source; then ();
      case FUNCTION_ARRAY_INIT() algorithm stmt.source := source; then ();
      case FOR()                 algorithm stmt.source := source; then ();
      case IF()                  algorithm stmt.source := source; then ();
      case WHEN()                algorithm stmt.source := source; then ();
      case ASSERT()              algorithm stmt.source := source; then ();
      case TERMINATE()           algorithm stmt.source := source; then ();
      case NORETCALL()           algorithm stmt.source := source; then ();
      case WHILE()               algorithm stmt.source := source; then ();
      case RETURN()              algorithm stmt.source := source; then ();
      case BREAK()               algorithm stmt.source := source; then ();
      case FAILURE()             algorithm stmt.source := source; then ();
    end match;
  end setSource;

  function info
    input Statement stmt;
    output SourceInfo info = ElementSource.getInfo(source(stmt));
  end info;

  partial function ApplyFn
    input Statement stmt;
  end ApplyFn;

  function apply
    input Statement stmt;
    input ApplyFn func;
  algorithm
    () := match stmt
      case FOR()
        algorithm
          for e in stmt.body loop
            apply(e, func);
          end for;
        then
          ();

      case IF()
        algorithm
          for b in stmt.branches loop
            for e in Util.tuple22(b) loop
              apply(e, func);
            end for;
          end for;
        then
          ();

      case WHEN()
        algorithm
          for b in stmt.branches loop
            for e in Util.tuple22(b) loop
              apply(e, func);
            end for;
          end for;
        then
          ();

      case WHILE()
        algorithm
          for e in stmt.body loop
            apply(e, func);
          end for;
        then
          ();

      case FAILURE()
        algorithm
          for e in stmt.body loop
            apply(e, func);
          end for;
        then
          ();

      else ();
    end match;

    func(stmt);
  end apply;

  function map
    input output Statement stmt;
    input MapFn func;

    partial function MapFn
      input output Statement stmt;
    end MapFn;
  algorithm
    () := match stmt
      case FOR()
        algorithm
          stmt.body := list(map(s, func) for s in stmt.body);
        then
          ();

      case IF()
        algorithm
          stmt.branches := list(
            (Util.tuple21(b),
             list(map(s, func) for s in Util.tuple22(b))) for b in stmt.branches);
        then
          ();

      case WHEN()
        algorithm
          stmt.branches := list(
            (Util.tuple21(b),
             list(map(s, func) for s in Util.tuple22(b))) for b in stmt.branches);
        then
          ();

      case WHILE()
        algorithm
          stmt.body := list(map(s, func) for s in stmt.body);
        then
          ();

      else ();
    end match;

    stmt := func(stmt);
  end map;

  function fold<ArgT>
    input Statement stmt;
    input MapFn func;
    input output ArgT arg;

    partial function MapFn
      input Statement stmt;
      input output ArgT arg;
    end MapFn;
  algorithm
    () := match stmt
      case FOR()
        algorithm
          for s in stmt.body loop
            arg := fold(s, func, arg);
          end for;
        then
          ();

      case IF()
        algorithm
          for b in stmt.branches loop
            for s in Util.tuple22(b) loop
              arg := fold(s, func, arg);
            end for;
          end for;
        then
          ();

      case WHEN()
        algorithm
          for b in stmt.branches loop
            for s in Util.tuple22(b) loop
              arg := fold(s, func, arg);
            end for;
          end for;
        then
          ();

      case WHILE()
        algorithm
          for s in stmt.body loop
            arg := fold(s, func, arg);
          end for;
        then
          ();

      else ();
    end match;

    arg := func(stmt, arg);
  end fold;

  function applyExpList
    input list<Statement> stmt;
    input FoldFunc func;

    partial function FoldFunc
      input Expression exp;
    end FoldFunc;
  algorithm
    for s in stmt loop
      applyExp(s, func);
    end for;
  end applyExpList;

  function applyExp
    input Statement stmt;
    input ApplyFunc func;

    partial function ApplyFunc
      input Expression exp;
    end ApplyFunc;
  algorithm
    () := match stmt
      case Statement.ASSIGNMENT()
        algorithm
          func(stmt.lhs);
          func(stmt.rhs);
        then
          ();

      case Statement.FOR()
        algorithm
          applyExpList(stmt.body, func);

          if isSome(stmt.range) then
            func(Util.getOption(stmt.range));
          end if;
        then
          ();

      case Statement.IF()
        algorithm
          for b in stmt.branches loop
            func(Util.tuple21(b));
            applyExpList(Util.tuple22(b), func);
          end for;
        then
          ();

      case Statement.WHEN()
        algorithm
          for b in stmt.branches loop
            func(Util.tuple21(b));
            applyExpList(Util.tuple22(b), func);
          end for;
        then
          ();

      case Statement.ASSERT()
        algorithm
          func(stmt.condition);
          func(stmt.message);
          func(stmt.level);
        then
          ();

      case Statement.TERMINATE()
        algorithm
          func(stmt.message);
        then
          ();

      case Statement.REINIT()
        algorithm
          func(stmt.cref);
          func(stmt.reinitExp);
        then
          ();

      case Statement.NORETCALL()
        algorithm
          func(stmt.exp);
        then
          ();

      case Statement.WHILE()
        algorithm
          func(stmt.condition);
          applyExpList(stmt.body, func);
        then
          ();

      else ();
    end match;
  end applyExp;

  function mapExpList
    input output list<Statement> stmtl;
    input MapFunc func;

    partial function MapFunc
      input output Expression exp;
    end MapFunc;
  algorithm
    stmtl := list(mapExp(s, func) for s in stmtl);
  end mapExpList;

  function mapExp
    input output Statement stmt;
    input MapFunc func;

    partial function MapFunc
      input output Expression exp;
    end MapFunc;
  algorithm
    stmt := match stmt
      local
        Expression e1, e2, e3;

      case ASSIGNMENT()
        algorithm
          e1 := func(stmt.lhs);
          e2 := func(stmt.rhs);
        then
          if referenceEq(e1, stmt.lhs) and referenceEq(e2, stmt.rhs) then
            stmt else ASSIGNMENT(e1, e2, stmt.ty, stmt.source);

      case FOR()
        algorithm
          stmt.body := mapExpList(stmt.body, func);
          stmt.range := Util.applyOption(stmt.range, func);
        then
          stmt;

      case IF()
        algorithm
          stmt.branches := list(
            (func(Util.tuple21(b)), mapExpList(Util.tuple22(b), func)) for b in stmt.branches);
        then
          stmt;

      case WHEN()
        algorithm
          stmt.branches := list(
            (func(Util.tuple21(b)), mapExpList(Util.tuple22(b), func)) for b in stmt.branches);
        then
          stmt;

      case ASSERT()
        algorithm
          e1 := func(stmt.condition);
          e2 := func(stmt.message);
          e3 := func(stmt.level);
        then
          if referenceEq(e1, stmt.condition) and referenceEq(e2, stmt.message) and
            referenceEq(e3, stmt.level) then stmt else ASSERT(e1, e2, e3, stmt.source);

      case TERMINATE()
        algorithm
          e1 := func(stmt.message);
        then
          if referenceEq(e1, stmt.message) then stmt else TERMINATE(e1, stmt.source);

      case REINIT()
        algorithm
          e1 := func(stmt.cref);
          e2 := func(stmt.reinitExp);
        then
          if referenceEq(e1, stmt.cref) and referenceEq(e2, stmt.reinitExp)
            then stmt else REINIT(e1, e2, stmt.source);

      case NORETCALL()
        algorithm
          e1 := func(stmt.exp);
        then
          if referenceEq(e1, stmt.exp) then stmt else NORETCALL(e1, stmt.source);

      case WHILE()
        then WHILE(func(stmt.condition), mapExpList(stmt.body, func), stmt.source);

      else stmt;
    end match;
  end mapExp;

  function mapExpShallow
    input output Statement stmt;
    input MapFunc func;

    partial function MapFunc
      input output Expression exp;
    end MapFunc;
  algorithm
    stmt := match stmt
      local
        Expression e1, e2, e3;

      case ASSIGNMENT()
        algorithm
          e1 := func(stmt.lhs);
          e2 := func(stmt.rhs);
        then
          if referenceEq(e1, stmt.lhs) and referenceEq(e2, stmt.rhs) then
            stmt else ASSIGNMENT(e1, e2, stmt.ty, stmt.source);

      case FOR()
        algorithm
          stmt.range := Util.applyOption(stmt.range, func);
        then
          stmt;

      case IF()
        algorithm
          stmt.branches := list(
            (func(Util.tuple21(b)), Util.tuple22(b)) for b in stmt.branches);
        then
          stmt;

      case WHEN()
        algorithm
          stmt.branches := list(
            (func(Util.tuple21(b)), Util.tuple22(b)) for b in stmt.branches);
        then
          stmt;

      case ASSERT()
        algorithm
          e1 := func(stmt.condition);
          e2 := func(stmt.message);
          e3 := func(stmt.level);
        then
          if referenceEq(e1, stmt.condition) and referenceEq(e2, stmt.message) and
            referenceEq(e3, stmt.level) then stmt else ASSERT(e1, e2, e3, stmt.source);

      case TERMINATE()
        algorithm
          e1 := func(stmt.message);
        then
          if referenceEq(e1, stmt.message) then stmt else TERMINATE(e1, stmt.source);

      case REINIT()
        algorithm
          e1 := func(stmt.cref);
          e2 := func(stmt.reinitExp);
        then
          if referenceEq(e1, stmt.cref) and referenceEq(e2, stmt.reinitExp) then
            stmt else REINIT(e1, e2, stmt.source);

      case NORETCALL()
        algorithm
          e1 := func(stmt.exp);
        then
          if referenceEq(e1, stmt.exp) then stmt else NORETCALL(e1, stmt.source);

      case WHILE()
        then WHILE(func(stmt.condition), stmt.body, stmt.source);

      else stmt;
    end match;
  end mapExpShallow;

  function foldExpList<ArgT>
    input list<Statement> stmt;
    input FoldFunc func;
    input output ArgT arg;

    partial function FoldFunc
      input Expression exp;
      input output ArgT arg;
    end FoldFunc;
  algorithm
    for s in stmt loop
      arg := foldExp(s, func, arg);
    end for;
  end foldExpList;

  function foldExp<ArgT>
    input Statement stmt;
    input FoldFunc func;
    input output ArgT arg;

    partial function FoldFunc
      input Expression exp;
      input output ArgT arg;
    end FoldFunc;
  algorithm
    () := match stmt
      case Statement.ASSIGNMENT()
        algorithm
          arg := func(stmt.lhs, arg);
          arg := func(stmt.rhs, arg);
        then
          ();

      case Statement.FOR()
        algorithm
          arg := foldExpList(stmt.body, func, arg);

          if isSome(stmt.range) then
            arg := func(Util.getOption(stmt.range), arg);
          end if;
        then
          ();

      case Statement.IF()
        algorithm
          for b in stmt.branches loop
            arg := func(Util.tuple21(b), arg);
            arg := foldExpList(Util.tuple22(b), func, arg);
          end for;
        then
          ();

      case Statement.WHEN()
        algorithm
          for b in stmt.branches loop
            arg := func(Util.tuple21(b), arg);
            arg := foldExpList(Util.tuple22(b), func, arg);
          end for;
        then
          ();

      case Statement.ASSERT()
        algorithm
          arg := func(stmt.condition, arg);
          arg := func(stmt.message, arg);
          arg := func(stmt.level, arg);
        then
          ();

      case Statement.TERMINATE()
        algorithm
          arg := func(stmt.message, arg);
        then
          ();

      case Statement.REINIT()
        algorithm
          arg := func(stmt.cref, arg);
          arg := func(stmt.reinitExp, arg);
        then
          ();

      case Statement.NORETCALL()
        algorithm
          arg := func(stmt.exp, arg);
        then
          ();

      case Statement.WHILE()
        algorithm
          arg := func(stmt.condition, arg);
          arg := foldExpList(stmt.body, func, arg);
        then
          ();

      else ();
    end match;
  end foldExp;

  function replaceIteratorList
    input output list<Statement> stmtl;
    input InstNode iterator;
    input Expression value;
  algorithm
    stmtl := mapExpList(stmtl,
      function Expression.replaceIterator(iterator = iterator, iteratorValue = value));
  end replaceIteratorList;

  function toString
    input Statement stmt;
    input String indent = "";
    output String str;
  protected
    IOStream.IOStream s;
  algorithm
    s := IOStream.create(getInstanceName(), IOStream.IOStreamType.LIST());
    s := toStream(stmt, indent, s);
    str := IOStream.string(s);
    IOStream.delete(s);
  end toString;

  function toStringList
    input list<Statement> stmtl;
    input String indent = "";
    output String str;
  protected
    IOStream.IOStream s;
  algorithm
    s := IOStream.create(getInstanceName(), IOStream.IOStreamType.LIST());
    s := toStreamList(stmtl, indent, s);
    str := IOStream.string(s);
    IOStream.delete(s);
  end toStringList;

  function toStream
    input Statement stmt;
    input String indent;
    input output IOStream.IOStream s;
  protected
    String str;
  algorithm
    s := IOStream.append(s, indent);

    s := match stmt
      case ASSIGNMENT()
        algorithm
          s := IOStream.append(s, Expression.toString(stmt.lhs));
          s := IOStream.append(s, " := ");
          s := IOStream.append(s, Expression.toString(stmt.rhs));
        then
          s;

      case FUNCTION_ARRAY_INIT()
        algorithm
          s := IOStream.append(s, "array init");
          s := IOStream.append(s, stmt.name);
        then
          s;

      case FOR()
        algorithm
          s := IOStream.append(s, "for ");
          s := IOStream.append(s, InstNode.name(stmt.iterator));

          if isSome(stmt.range) then
            s := IOStream.append(s, " in ");
            s := IOStream.append(s, Expression.toString(Util.getOption(stmt.range)));
          end if;

          s := IOStream.append(s, " loop\n");
          s := toStreamList(stmt.body, indent + "  ", s);
          s := IOStream.append(s, indent);
          s := IOStream.append(s, "end for");
        then
          s;

      case IF()
        algorithm
          str := "if ";

          for b in stmt.branches loop
            s := IOStream.append(s, str);
            s := IOStream.append(s, Expression.toString(Util.tuple21(b)));
            s := IOStream.append(s, " then\n");
            s := toStreamList(Util.tuple22(b), indent + "  ", s);
            s := IOStream.append(s, indent);
            str := "elseif ";
          end for;

          s := IOStream.append(s, "end if");
        then
          s;

      case WHEN()
        algorithm
          str := "when ";

          for b in stmt.branches loop
            s := IOStream.append(s, str);
            s := IOStream.append(s, Expression.toString(Util.tuple21(b)));
            s := IOStream.append(s, " then\n");
            s := toStreamList(Util.tuple22(b), indent + "  ", s);
            s := IOStream.append(s, indent);
            str := "elsewhen ";
          end for;

          s := IOStream.append(s, "end when");
        then
          s;

      case ASSERT()
        algorithm
          s := IOStream.append(s, "assert(");
          s := IOStream.append(s, Expression.toString(stmt.condition));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toString(stmt.message));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toString(stmt.level));
          s := IOStream.append(s, ")");
        then
          s;

      case TERMINATE()
        algorithm
          s := IOStream.append(s, "terminate(");
          s := IOStream.append(s, Expression.toString(stmt.message));
          s := IOStream.append(s, ")");
        then
          s;

      case REINIT()
        algorithm
          s := IOStream.append(s, "reinit(");
          s := IOStream.append(s, Expression.toString(stmt.cref));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toString(stmt.reinitExp));
          s := IOStream.append(s, ")");
        then
          s;

      case NORETCALL()
        then IOStream.append(s, Expression.toString(stmt.exp));

      case WHILE()
        algorithm
          s := IOStream.append(s, "while ");
          s := IOStream.append(s, Expression.toString(stmt.condition));
          s := IOStream.append(s, " then\n");
          s := toStreamList(stmt.body, indent + "  ", s);
          s := IOStream.append(s, indent);
          s := IOStream.append(s, "end while");
        then
          s;

      case RETURN() then IOStream.append(s, "return");
      case RETURN() then IOStream.append(s, "break");
      else IOStream.append(s, "#UNKNOWN STATEMENT#");
    end match;

  end toStream;

  function toStreamList
    input list<Statement> stmtl;
    input String indent;
    input output IOStream.IOStream s;
  protected
    Boolean prev_multi_line = false, multi_line;
    Boolean first = true;
  algorithm
    for stmt in stmtl loop
      multi_line := isMultiLine(stmt);

      // Improve human parsability by separating statements that spans multiple
      // lines (like if-statements) with newlines.
      if first then
        first := false;
      elseif prev_multi_line or multi_line then
        s := IOStream.append(s, "\n");
      end if;

      prev_multi_line := multi_line;

      s := toStream(stmt, indent, s);
      s := IOStream.append(s, ";\n");
    end for;
  end toStreamList;

  function toFlatStream
    input Statement stmt;
    input BaseModelica.OutputFormat format;
    input String indent;
    input output IOStream.IOStream s;
  protected
    String str;
  algorithm
    s := IOStream.append(s, indent);

    s := match stmt
      case ASSIGNMENT()
        algorithm
          s := IOStream.append(s, Expression.toFlatString(stmt.lhs, format));
          s := IOStream.append(s, " := ");
          s := IOStream.append(s, Expression.toFlatString(stmt.rhs, format));
        then
          s;

      case FUNCTION_ARRAY_INIT()
        algorithm
          s := IOStream.append(s, "array init");
          s := IOStream.append(s, stmt.name);
        then
          s;

      case FOR()
        algorithm
          s := IOStream.append(s, "for ");
          s := IOStream.append(s, Util.makeQuotedIdentifier(InstNode.name(stmt.iterator)));

          if isSome(stmt.range) then
            s := IOStream.append(s, " in ");
            s := IOStream.append(s, Expression.toFlatString(Util.getOption(stmt.range), format));
          end if;

          s := IOStream.append(s, " loop\n");
          s := toFlatStreamList(stmt.body, format, indent + "  ", s);
          s := IOStream.append(s, indent);
          s := IOStream.append(s, "end for");
        then
          s;

      case IF()
        algorithm
          str := "if ";

          for b in stmt.branches loop
            s := IOStream.append(s, str);
            s := IOStream.append(s, Expression.toFlatString(Util.tuple21(b), format));
            s := IOStream.append(s, " then\n");
            s := toFlatStreamList(Util.tuple22(b), format, indent + "  ", s);
            s := IOStream.append(s, indent);
            str := "elseif ";
          end for;

          s := IOStream.append(s, "end if");
        then
          s;

      case WHEN()
        algorithm
          str := "when ";

          for b in stmt.branches loop
            s := IOStream.append(s, str);
            s := IOStream.append(s, Expression.toFlatString(Util.tuple21(b), format));
            s := IOStream.append(s, " then\n");
            s := toFlatStreamList(Util.tuple22(b), format, indent + "  ", s);
            s := IOStream.append(s, indent);
            str := "elsewhen ";
          end for;

          s := IOStream.append(s, "end when");
        then
          s;

      case ASSERT()
        algorithm
          s := IOStream.append(s, "assert(");
          s := IOStream.append(s, Expression.toFlatString(stmt.condition, format));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toFlatString(stmt.message, format));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toFlatString(stmt.level, format));
          s := IOStream.append(s, ")");
        then
          s;

      case TERMINATE()
        algorithm
          s := IOStream.append(s, "terminate(");
          s := IOStream.append(s, Expression.toFlatString(stmt.message, format));
          s := IOStream.append(s, ")");
        then
          s;

      case REINIT()
        algorithm
          s := IOStream.append(s, "reinit(");
          s := IOStream.append(s, Expression.toFlatString(stmt.cref, format));
          s := IOStream.append(s, ", ");
          s := IOStream.append(s, Expression.toFlatString(stmt.reinitExp, format));
          s := IOStream.append(s, ")");
        then
          s;

      case NORETCALL()
        then IOStream.append(s, Expression.toFlatString(stmt.exp, format));

      case WHILE()
        algorithm
          s := IOStream.append(s, "while ");
          s := IOStream.append(s, Expression.toFlatString(stmt.condition, format));
          s := IOStream.append(s, " loop\n");
          s := toFlatStreamList(stmt.body, format, indent + "  ", s);
          s := IOStream.append(s, indent);
          s := IOStream.append(s, "end while");
        then
          s;

      case RETURN() then IOStream.append(s, "return");
      case RETURN() then IOStream.append(s, "break");
      else IOStream.append(s, "#UNKNOWN STATEMENT#");
    end match;

    s := FlatModelicaUtil.appendElementSourceComment(source(stmt), NFFlatModelicaUtil.ElementType.ALGORITHM, s);
  end toFlatStream;

  function toFlatStreamList
    input list<Statement> stmtl;
    input BaseModelica.OutputFormat format;
    input String indent;
    input output IOStream.IOStream s;
  protected
    Boolean prev_multi_line = false, multi_line;
    Boolean first = true;
  algorithm
    for stmt in stmtl loop
      multi_line := isMultiLine(stmt);

      // Improve human parsability by separating statements that spans multiple
      // lines (like if-statements) with newlines.
      if first then
        first := false;
      elseif prev_multi_line or multi_line then
        s := IOStream.append(s, "\n");
      end if;

      prev_multi_line := multi_line;

      s := toFlatStream(stmt, format, indent, s);
      s := IOStream.append(s, ";\n");
    end for;
  end toFlatStreamList;

  function isMultiLine
    input Statement stmt;
    output Boolean multiLine;
  algorithm
    multiLine := match stmt
      case FOR() then true;
      case IF() then true;
      case WHEN() then true;
      case WHILE() then true;
      else false;
    end match;
  end isMultiLine;

annotation(__OpenModelica_Interface="frontend");
end NFStatement;
