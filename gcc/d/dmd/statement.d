/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/statement.d, _statement.d)
 * Documentation:  https://dlang.org/phobos/dmd_statement.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/statement.d
 */

module dmd.statement;

import core.stdc.stdarg;
import core.stdc.stdio;

import dmd.aggregate;
import dmd.arraytypes;
import dmd.attrib;
import dmd.astcodegen;
import dmd.gluelayer;
import dmd.canthrow;
import dmd.cond;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.dtemplate;
import dmd.errors;
import dmd.expression;
import dmd.expressionsem;
import dmd.func;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.parse;
import dmd.root.outbuffer;
import dmd.root.rootobject;
import dmd.sapply;
import dmd.sideeffect;
import dmd.staticassert;
import dmd.tokens;
import dmd.visitor;

/**
 * Returns:
 *     `TypeIdentifier` corresponding to `object.Throwable`
 */
TypeIdentifier getThrowable()
{
    auto tid = new TypeIdentifier(Loc.initial, Id.empty);
    tid.addIdent(Id.object);
    tid.addIdent(Id.Throwable);
    return tid;
}


/***********************************************************
 * Specification: http://dlang.org/spec/statement.html
 */
extern (C++) abstract class Statement : RootObject
{
    Loc loc;

    override final DYNCAST dyncast() const
    {
        return DYNCAST.statement;
    }

    final extern (D) this(const ref Loc loc)
    {
        this.loc = loc;
        // If this is an in{} contract scope statement (skip for determining
        //  inlineStatus of a function body for header content)
    }

    Statement syntaxCopy()
    {
        assert(0);
    }

    /*************************************
     * Do syntax copy of an array of Statement's.
     */
    static Statements* arraySyntaxCopy(Statements* a)
    {
        Statements* b = null;
        if (a)
        {
            b = a.copy();
            foreach (i, s; *a)
            {
                (*b)[i] = s ? s.syntaxCopy() : null;
            }
        }
        return b;
    }

    override final void print()
    {
        fprintf(stderr, "%s\n", toChars());
        fflush(stderr);
    }

    override final const(char)* toChars()
    {
        HdrGenState hgs;
        OutBuffer buf;
        .toCBuffer(this, &buf, &hgs);
        return buf.extractString();
    }

    final void error(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .verror(loc, format, ap);
        va_end(ap);
    }

    final void warning(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .vwarning(loc, format, ap);
        va_end(ap);
    }

    final void deprecation(const(char)* format, ...)
    {
        va_list ap;
        va_start(ap, format);
        .vdeprecation(loc, format, ap);
        va_end(ap);
    }

    Statement getRelatedLabeled()
    {
        return this;
    }

    /****************************
     * Determine if an enclosed `break` would apply to this
     * statement, such as if it is a loop or switch statement.
     * Returns:
     *     `true` if it does
     */
    bool hasBreak()
    {
        //printf("Statement::hasBreak()\n");
        return false;
    }

    /****************************
     * Determine if an enclosed `continue` would apply to this
     * statement, such as if it is a loop statement.
     * Returns:
     *     `true` if it does
     */
    bool hasContinue()
    {
        return false;
    }

    /**********************************
     * Returns:
     *     `true` if statement uses exception handling
     */
    final bool usesEH()
    {
        extern (C++) final class UsesEH : StoppableVisitor
        {
            alias visit = typeof(super).visit;
        public:
            override void visit(Statement s)
            {
            }

            override void visit(TryCatchStatement s)
            {
                stop = true;
            }

            override void visit(TryFinallyStatement s)
            {
                stop = true;
            }

            override void visit(OnScopeStatement s)
            {
                stop = true;
            }

            override void visit(SynchronizedStatement s)
            {
                stop = true;
            }
        }

        scope UsesEH ueh = new UsesEH();
        return walkPostorder(this, ueh);
    }

    /**********************************
     * Returns:
     *   `true` if statement 'comes from' somewhere else, like a goto
     */
    final bool comeFrom()
    {
        extern (C++) final class ComeFrom : StoppableVisitor
        {
            alias visit = typeof(super).visit;
        public:
            override void visit(Statement s)
            {
            }

            override void visit(CaseStatement s)
            {
                stop = true;
            }

            override void visit(DefaultStatement s)
            {
                stop = true;
            }

            override void visit(LabelStatement s)
            {
                stop = true;
            }

            override void visit(AsmStatement s)
            {
                stop = true;
            }

            version (IN_GCC)
            {
                override void visit(ExtAsmStatement s)
                {
                    stop = true;
                }
            }
        }

        scope ComeFrom cf = new ComeFrom();
        return walkPostorder(this, cf);
    }

    /**********************************
     * Returns:
     *   `true` if statement has executable code.
     */
    final bool hasCode()
    {
        extern (C++) final class HasCode : StoppableVisitor
        {
            alias visit = typeof(super).visit;
        public:
            override void visit(Statement s)
            {
                stop = true;
            }

            override void visit(ExpStatement s)
            {
                if (s.exp !is null)
                {
                    stop = s.exp.hasCode();
                }
            }

            override void visit(CompoundStatement s)
            {
            }

            override void visit(ScopeStatement s)
            {
            }

            override void visit(ImportStatement s)
            {
            }
        }

        scope HasCode hc = new HasCode();
        return walkPostorder(this, hc);
    }

    /****************************************
     * If this statement has code that needs to run in a finally clause
     * at the end of the current scope, return that code in the form of
     * a Statement.
     * Params:
     *     sc = context
     *     sentry     = set to code executed upon entry to the scope
     *     sexception = set to code executed upon exit from the scope via exception
     *     sfinally   = set to code executed in finally block
     * Returns:
     *    code to be run in the finally clause
     */
    Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("Statement::scopeCode()\n");
        //print();
        *sentry = null;
        *sexception = null;
        *sfinally = null;
        return this;
    }

    /*********************************
     * Flatten out the scope by presenting the statement
     * as an array of statements.
     * Params:
     *     sc = context
     * Returns:
     *     The array of `Statements`, or `null` if no flattening necessary
     */
    Statements* flatten(Scope* sc)
    {
        return null;
    }

    /*******************************
     * Find last statement in a sequence of statements.
     * Returns:
     *  the last statement, or `null` if there isn't one
     */
    inout(Statement) last() inout nothrow pure
    {
        return this;
    }

    /********************
     * A cheaper method of doing downcasting of Statements.
     * Returns:
     *    the downcast statement if it can be downcasted, otherwise `null`
     */
    ErrorStatement isErrorStatement()
    {
        return null;
    }

    /// ditto
    inout(ScopeStatement) isScopeStatement() inout nothrow pure
    {
        return null;
    }

    /// ditto
    ExpStatement isExpStatement()
    {
        return null;
    }

    /// ditto
    inout(CompoundStatement) isCompoundStatement() inout nothrow pure
    {
        return null;
    }

    /// ditto
    inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        return null;
    }

    /// ditto
    IfStatement isIfStatement()
    {
        return null;
    }

    /// ditto
    CaseStatement isCaseStatement()
    {
        return null;
    }

    /// ditto
    DefaultStatement isDefaultStatement()
    {
        return null;
    }

    /// ditto
    LabelStatement isLabelStatement()
    {
        return null;
    }

    /// ditto
    GotoDefaultStatement isGotoDefaultStatement() pure
    {
        return null;
    }

    /// ditto
    GotoCaseStatement isGotoCaseStatement() pure
    {
        return null;
    }

    /// ditto
    inout(BreakStatement) isBreakStatement() inout nothrow pure
    {
        return null;
    }

    /// ditto
    DtorExpStatement isDtorExpStatement()
    {
        return null;
    }

    /// ditto
    ForwardingStatement isForwardingStatement()
    {
        return null;
    }

    /**************************
     * Support Visitor Pattern
     * Params:
     *  v = visitor
     */
    void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Any Statement that fails semantic() or has a component that is an ErrorExp or
 * a TypeError should return an ErrorStatement from semantic().
 */
extern (C++) final class ErrorStatement : Statement
{
    extern (D) this()
    {
        super(Loc.initial);
        assert(global.gaggedErrors || global.errors);
    }

    override Statement syntaxCopy()
    {
        return this;
    }

    override ErrorStatement isErrorStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class PeelStatement : Statement
{
    Statement s;

    extern (D) this(Statement s)
    {
        super(s.loc);
        this.s = s;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Convert TemplateMixin members (== Dsymbols) to Statements.
 */
extern (C++) Statement toStatement(Dsymbol s)
{
    extern (C++) final class ToStmt : Visitor
    {
        alias visit = Visitor.visit;
    public:
        Statement result;

        Statement visitMembers(Loc loc, Dsymbols* a)
        {
            if (!a)
                return null;

            auto statements = new Statements();
            foreach (s; *a)
            {
                statements.push(toStatement(s));
            }
            return new CompoundStatement(loc, statements);
        }

        override void visit(Dsymbol s)
        {
            .error(Loc.initial, "Internal Compiler Error: cannot mixin %s `%s`\n", s.kind(), s.toChars());
            result = new ErrorStatement();
        }

        override void visit(TemplateMixin tm)
        {
            auto a = new Statements();
            foreach (m; *tm.members)
            {
                Statement s = toStatement(m);
                if (s)
                    a.push(s);
            }
            result = new CompoundStatement(tm.loc, a);
        }

        /* An actual declaration symbol will be converted to DeclarationExp
         * with ExpStatement.
         */
        Statement declStmt(Dsymbol s)
        {
            auto de = new DeclarationExp(s.loc, s);
            de.type = Type.tvoid; // avoid repeated semantic
            return new ExpStatement(s.loc, de);
        }

        override void visit(VarDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(AggregateDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(FuncDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(EnumDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(AliasDeclaration d)
        {
            result = declStmt(d);
        }

        override void visit(TemplateDeclaration d)
        {
            result = declStmt(d);
        }

        /* All attributes have been already picked by the semantic analysis of
         * 'bottom' declarations (function, struct, class, etc).
         * So we don't have to copy them.
         */
        override void visit(StorageClassDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(DeprecatedDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(LinkDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(ProtDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(AlignDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(UserAttributeDeclaration d)
        {
            result = visitMembers(d.loc, d.decl);
        }

        override void visit(StaticAssert s)
        {
        }

        override void visit(Import s)
        {
        }

        override void visit(PragmaDeclaration d)
        {
        }

        override void visit(ConditionalDeclaration d)
        {
            result = visitMembers(d.loc, d.include(null));
        }

        override void visit(StaticForeachDeclaration d)
        {
            assert(d.sfe && !!d.sfe.aggrfe ^ !!d.sfe.rangefe);
            (d.sfe.aggrfe ? d.sfe.aggrfe._body : d.sfe.rangefe._body) = visitMembers(d.loc, d.decl);
            result = new StaticForeachStatement(d.loc, d.sfe);
        }

        override void visit(CompileDeclaration d)
        {
            result = visitMembers(d.loc, d.include(null));
        }
    }

    if (!s)
        return null;

    scope ToStmt v = new ToStmt();
    s.accept(v);
    return v.result;
}

/***********************************************************
 */
extern (C++) class ExpStatement : Statement
{
    Expression exp;

    final extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    final extern (D) this(const ref Loc loc, Dsymbol declaration)
    {
        super(loc);
        this.exp = new DeclarationExp(loc, declaration);
    }

    static ExpStatement create(Loc loc, Expression exp)
    {
        return new ExpStatement(loc, exp);
    }

    override Statement syntaxCopy()
    {
        return new ExpStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override final Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ExpStatement::scopeCode()\n");
        //print();

        *sentry = null;
        *sexception = null;
        *sfinally = null;

        if (exp && exp.op == TOK.declaration)
        {
            auto de = cast(DeclarationExp)exp;
            auto v = de.declaration.isVarDeclaration();
            if (v && !v.isDataseg())
            {
                if (v.needsScopeDtor())
                {
                    //printf("dtor is: "); v.edtor.print();
                    *sfinally = new DtorExpStatement(loc, v.edtor, v);
                    v.storage_class |= STC.nodtor; // don't add in dtor again
                }
            }
        }
        return this;
    }

    override final Statements* flatten(Scope* sc)
    {
        /* https://issues.dlang.org/show_bug.cgi?id=14243
         * expand template mixin in statement scope
         * to handle variable destructors.
         */
        if (exp && exp.op == TOK.declaration)
        {
            Dsymbol d = (cast(DeclarationExp)exp).declaration;
            if (TemplateMixin tm = d.isTemplateMixin())
            {
                Expression e = exp.expressionSemantic(sc);
                if (e.op == TOK.error || tm.errors)
                {
                    auto a = new Statements();
                    a.push(new ErrorStatement());
                    return a;
                }
                assert(tm.members);

                Statement s = toStatement(tm);
                version (none)
                {
                    OutBuffer buf;
                    buf.doindent = 1;
                    HdrGenState hgs;
                    hgs.hdrgen = true;
                    toCBuffer(s, &buf, &hgs);
                    printf("tm ==> s = %s\n", buf.peekString());
                }
                auto a = new Statements();
                a.push(s);
                return a;
            }
        }
        return null;
    }

    override final ExpStatement isExpStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DtorExpStatement : ExpStatement
{
    // Wraps an expression that is the destruction of 'var'
    VarDeclaration var;

    extern (D) this(const ref Loc loc, Expression exp, VarDeclaration v)
    {
        super(loc, exp);
        this.var = v;
    }

    override Statement syntaxCopy()
    {
        return new DtorExpStatement(loc, exp ? exp.syntaxCopy() : null, var);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }

    override DtorExpStatement isDtorExpStatement()
    {
        return this;
    }
}

/***********************************************************
 * https://dlang.org/spec/statement.html#mixin-statement
 */
extern (C++) final class CompileStatement : Statement
{
    Expression exp;

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new CompileStatement(loc, exp.syntaxCopy());
    }

    private Statements* compileIt(Scope* sc)
    {
        //printf("CompileStatement::compileIt() %s\n", exp.toChars());

        auto errorStatements()
        {
            auto a = new Statements();
            a.push(new ErrorStatement());
            return a;
        }

        auto se = semanticString(sc, exp, "argument to mixin");
        if (!se)
            return errorStatements();
        se = se.toUTF8(sc);

        uint errors = global.errors;
        scope p = new Parser!ASTCodegen(loc, sc._module, se.toStringz(), false);
        p.nextToken();

        auto a = new Statements();
        while (p.token.value != TOK.endOfFile)
        {
            Statement s = p.parseStatement(ParseStatementFlags.semi | ParseStatementFlags.curlyScope);
            if (!s || p.errors)
            {
                assert(!p.errors || global.errors != errors); // make sure we caught all the cases
                return errorStatements();
            }
            a.push(s);
        }
        return a;
    }

    override Statements* flatten(Scope* sc)
    {
        //printf("CompileStatement::flatten() %s\n", exp.toChars());
        return compileIt(sc);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) class CompoundStatement : Statement
{
    Statements* statements;

    /**
     * Construct a `CompoundStatement` using an already existing
     * array of `Statement`s
     *
     * Params:
     *   loc = Instantiation information
     *   s   = An array of `Statement`s, that will referenced by this class
     */
    final extern (D) this(const ref Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    /**
     * Construct a `CompoundStatement` from an array of `Statement`s
     *
     * Params:
     *   loc = Instantiation information
     *   sts   = A variadic array of `Statement`s, that will copied in this class
     *         The entries themselves will not be copied.
     */
    final extern (D) this(const ref Loc loc, Statement[] sts...)
    {
        super(loc);
        statements = new Statements();
        statements.reserve(sts.length);
        foreach (s; sts)
            statements.push(s);
    }

    static CompoundStatement create(Loc loc, Statement s1, Statement s2)
    {
        return new CompoundStatement(loc, s1, s2);
    }

    override Statement syntaxCopy()
    {
        return new CompoundStatement(loc, Statement.arraySyntaxCopy(statements));
    }

    override Statements* flatten(Scope* sc)
    {
        return statements;
    }

    override final inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        ReturnStatement rs = null;
        foreach (s; *statements)
        {
            if (s)
            {
                rs = cast(ReturnStatement)s.isReturnStatement();
                if (rs)
                    break;
            }
        }
        return cast(inout)rs;
    }

    override final inout(Statement) last() inout nothrow pure
    {
        Statement s = null;
        for (size_t i = statements.dim; i; --i)
        {
            s = cast(Statement)(*statements)[i - 1];
            if (s)
            {
                s = cast(Statement)s.last();
                if (s)
                    break;
            }
        }
        return cast(inout)s;
    }

    override final inout(CompoundStatement) isCompoundStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CompoundDeclarationStatement : CompoundStatement
{
    extern (D) this(const ref Loc loc, Statements* s)
    {
        super(loc, s);
        statements = s;
    }

    override Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundDeclarationStatement(loc, a);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * The purpose of this is so that continue will go to the next
 * of the statements, and break will go to the end of the statements.
 */
extern (C++) final class UnrolledLoopStatement : Statement
{
    Statements* statements;

    extern (D) this(const ref Loc loc, Statements* s)
    {
        super(loc);
        statements = s;
    }

    override Statement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new UnrolledLoopStatement(loc, a);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) class ScopeStatement : Statement
{
    Statement statement;
    Loc endloc;                 // location of closing curly bracket

    extern (D) this(const ref Loc loc, Statement s, Loc endloc)
    {
        super(loc);
        this.statement = s;
        this.endloc = endloc;
    }
    override Statement syntaxCopy()
    {
        return new ScopeStatement(loc, statement ? statement.syntaxCopy() : null, endloc);
    }

    override inout(ScopeStatement) isScopeStatement() inout nothrow pure
    {
        return this;
    }

    override inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        if (statement)
            return statement.isReturnStatement();
        return null;
    }

    override bool hasBreak()
    {
        //printf("ScopeStatement::hasBreak() %s\n", toChars());
        return statement ? statement.hasBreak() : false;
    }

    override bool hasContinue()
    {
        return statement ? statement.hasContinue() : false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Statement whose symbol table contains foreach index variables in a
 * local scope and forwards other members to the parent scope.  This
 * wraps a statement.
 *
 * Also see: `dmd.attrib.ForwardingAttribDeclaration`
 */
extern (C++) final class ForwardingStatement : Statement
{
    /// The symbol containing the `static foreach` variables.
    ForwardingScopeDsymbol sym = null;
    /// The wrapped statement.
    Statement statement;

    extern (D) this(const ref Loc loc, ForwardingScopeDsymbol sym, Statement s)
    {
        super(loc);
        this.sym = sym;
        assert(s);
        statement = s;
    }

    extern (D) this(const ref Loc loc, Statement s)
    {
        auto sym = new ForwardingScopeDsymbol(null);
        sym.symtab = new DsymbolTable();
        this(loc, sym, s);
    }

    override Statement syntaxCopy()
    {
        return new ForwardingStatement(loc, statement.syntaxCopy());
    }

    /***********************
     * ForwardingStatements are distributed over the flattened
     * sequence of statements. This prevents flattening to be
     * "blocked" by a ForwardingStatement and is necessary, for
     * example, to support generating scope guards with `static
     * foreach`:
     *
     *     static foreach(i; 0 .. 10) scope(exit) writeln(i);
     *     writeln("this is printed first");
     *     // then, it prints 10, 9, 8, 7, ...
     */

    override Statements* flatten(Scope* sc)
    {
        if (!statement)
        {
            return null;
        }
        sc = sc.push(sym);
        auto a = statement.flatten(sc);
        sc = sc.pop();
        if (!a)
        {
            return a;
        }
        auto b = new Statements();
        b.setDim(a.dim);
        foreach (i, s; *a)
        {
            (*b)[i] = s ? new ForwardingStatement(s.loc, sym, s) : null;
        }
        return b;
    }

    override ForwardingStatement isForwardingStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}


/***********************************************************
 */
extern (C++) final class WhileStatement : Statement
{
    Expression condition;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    extern (D) this(const ref Loc loc, Expression c, Statement b, Loc endloc)
    {
        super(loc);
        condition = c;
        _body = b;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new WhileStatement(loc,
            condition.syntaxCopy(),
            _body ? _body.syntaxCopy() : null,
            endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DoStatement : Statement
{
    Statement _body;
    Expression condition;
    Loc endloc;                 // location of ';' after while

    extern (D) this(const ref Loc loc, Statement b, Expression c, Loc endloc)
    {
        super(loc);
        _body = b;
        condition = c;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new DoStatement(loc,
            _body ? _body.syntaxCopy() : null,
            condition.syntaxCopy(),
            endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ForStatement : Statement
{
    Statement _init;
    Expression condition;
    Expression increment;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    // When wrapped in try/finally clauses, this points to the outermost one,
    // which may have an associated label. Internal break/continue statements
    // treat that label as referring to this loop.
    Statement relatedLabeled;

    extern (D) this(const ref Loc loc, Statement _init, Expression condition, Expression increment, Statement _body, Loc endloc)
    {
        super(loc);
        this._init = _init;
        this.condition = condition;
        this.increment = increment;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForStatement(loc,
            _init ? _init.syntaxCopy() : null,
            condition ? condition.syntaxCopy() : null,
            increment ? increment.syntaxCopy() : null,
            _body.syntaxCopy(),
            endloc);
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("ForStatement::scopeCode()\n");
        Statement.scopeCode(sc, sentry, sexception, sfinally);
        return this;
    }

    override Statement getRelatedLabeled()
    {
        return relatedLabeled ? relatedLabeled : this;
    }

    override bool hasBreak()
    {
        //printf("ForStatement::hasBreak()\n");
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/statement.html#foreach-statement
 */
extern (C++) final class ForeachStatement : Statement
{
    TOK op;                     // TOK.foreach_ or TOK.foreach_reverse_
    Parameters* parameters;     // array of Parameters, one for each ForeachType
    Expression aggr;            // ForeachAggregate
    Statement _body;            // NoScopeNonEmptyStatement
    Loc endloc;                 // location of closing curly bracket

    VarDeclaration key;
    VarDeclaration value;

    FuncDeclaration func;       // function we're lexically in

    Statements* cases;          // put breaks, continues, gotos and returns here
    ScopeStatements* gotos;     // forward referenced goto's go here

    extern (D) this(const ref Loc loc, TOK op, Parameters* parameters, Expression aggr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.parameters = parameters;
        this.aggr = aggr;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForeachStatement(loc, op,
            Parameter.arraySyntaxCopy(parameters),
            aggr.syntaxCopy(),
            _body ? _body.syntaxCopy() : null,
            endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ForeachRangeStatement : Statement
{
    TOK op;                 // TOK.foreach_ or TOK.foreach_reverse_
    Parameter prm;          // loop index variable
    Expression lwr;
    Expression upr;
    Statement _body;
    Loc endloc;             // location of closing curly bracket

    VarDeclaration key;

    extern (D) this(const ref Loc loc, TOK op, Parameter prm, Expression lwr, Expression upr, Statement _body, Loc endloc)
    {
        super(loc);
        this.op = op;
        this.prm = prm;
        this.lwr = lwr;
        this.upr = upr;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new ForeachRangeStatement(loc, op, prm.syntaxCopy(), lwr.syntaxCopy(), upr.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    override bool hasBreak()
    {
        return true;
    }

    override bool hasContinue()
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class IfStatement : Statement
{
    Parameter prm;
    Expression condition;
    Statement ifbody;
    Statement elsebody;
    VarDeclaration match;   // for MatchExpression results
    Loc endloc;                 // location of closing curly bracket

    extern (D) this(const ref Loc loc, Parameter prm, Expression condition, Statement ifbody, Statement elsebody, Loc endloc)
    {
        super(loc);
        this.prm = prm;
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new IfStatement(loc,
            prm ? prm.syntaxCopy() : null,
            condition.syntaxCopy(),
            ifbody ? ifbody.syntaxCopy() : null,
            elsebody ? elsebody.syntaxCopy() : null,
            endloc);
    }

    override IfStatement isIfStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ConditionalStatement : Statement
{
    Condition condition;
    Statement ifbody;
    Statement elsebody;

    extern (D) this(const ref Loc loc, Condition condition, Statement ifbody, Statement elsebody)
    {
        super(loc);
        this.condition = condition;
        this.ifbody = ifbody;
        this.elsebody = elsebody;
    }

    override Statement syntaxCopy()
    {
        return new ConditionalStatement(loc, condition.syntaxCopy(), ifbody.syntaxCopy(), elsebody ? elsebody.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statement s;

        //printf("ConditionalStatement::flatten()\n");
        if (condition.include(sc))
        {
            DebugCondition dc = condition.isDebugCondition();
            if (dc)
                s = new DebugStatement(loc, ifbody);
            else
                s = ifbody;
        }
        else
            s = elsebody;

        auto a = new Statements();
        a.push(s);
        return a;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Static foreach statements, like:
 *      void main()
 *      {
 *           static foreach(i; 0 .. 10)
 *           {
 *               pragma(msg, i);
 *           }
 *      }
 */
extern (C++) final class StaticForeachStatement : Statement
{
    StaticForeach sfe;

    extern (D) this(const ref Loc loc, StaticForeach sfe)
    {
        super(loc);
        this.sfe = sfe;
    }

    override Statement syntaxCopy()
    {
        return new StaticForeachStatement(loc,sfe.syntaxCopy());
    }

    override Statements* flatten(Scope* sc)
    {
        sfe.prepare(sc);
        if (sfe.ready())
        {
            import dmd.statementsem;
            auto s = makeTupleForeach!(true,false)(sc, sfe.aggrfe,sfe.needExpansion);
            auto result = s.flatten(sc);
            if (result)
            {
                return result;
            }
            result = new Statements();
            result.push(s);
            return result;
        }
        else
        {
            auto result = new Statements();
            result.push(new ErrorStatement());
            return result;
        }
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class PragmaStatement : Statement
{
    Identifier ident;
    Expressions* args;      // array of Expression's
    Statement _body;

    extern (D) this(const ref Loc loc, Identifier ident, Expressions* args, Statement _body)
    {
        super(loc);
        this.ident = ident;
        this.args = args;
        this._body = _body;
    }

    override Statement syntaxCopy()
    {
        return new PragmaStatement(loc, ident, Expression.arraySyntaxCopy(args), _body ? _body.syntaxCopy() : null);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class StaticAssertStatement : Statement
{
    StaticAssert sa;

    extern (D) this(StaticAssert sa)
    {
        super(sa.loc);
        this.sa = sa;
    }

    override Statement syntaxCopy()
    {
        return new StaticAssertStatement(cast(StaticAssert)sa.syntaxCopy(null));
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SwitchStatement : Statement
{
    Expression condition;           /// switch(condition)
    Statement _body;                ///
    bool isFinal;                   ///

    DefaultStatement sdefault;      /// default:
    TryFinallyStatement tf;         ///
    GotoCaseStatements gotoCases;   /// array of unresolved GotoCaseStatement's
    CaseStatements* cases;          /// array of CaseStatement's
    int hasNoDefault;               /// !=0 if no default statement
    int hasVars;                    /// !=0 if has variable case values
    VarDeclaration lastVar;         /// last observed variable declaration in this statement

    extern (D) this(const ref Loc loc, Expression c, Statement b, bool isFinal)
    {
        super(loc);
        this.condition = c;
        this._body = b;
        this.isFinal = isFinal;
    }

    override Statement syntaxCopy()
    {
        return new SwitchStatement(loc, condition.syntaxCopy(), _body.syntaxCopy(), isFinal);
    }

    override bool hasBreak()
    {
        return true;
    }

    /************************************
     * Returns:
     *  true if error
     */
    final bool checkLabel()
    {
        /*
         * Checks the scope of a label for existing variable declaration.
         * Params:
         *   vd = last variable declared before this case/default label
         * Returns: `true` if the variables declared in this label would be skipped.
         */
        bool checkVar(VarDeclaration vd)
        {
            for (auto v = vd; v && v != lastVar; v = v.lastVar)
            {
                if (v.isDataseg() || (v.storage_class & (STC.manifest | STC.temp)) || v._init.isVoidInitializer())
                    continue;
                if (vd.ident == Id.withSym)
                    error("`switch` skips declaration of `with` temporary at %s", v.loc.toChars());
                else
                    error("`switch` skips declaration of variable `%s` at %s", v.toPrettyChars(), v.loc.toChars());
                return true;
            }
            return false;
        }

        enum error = true;

        if (sdefault && checkVar(sdefault.lastVar))
            return !error; // return error once fully deprecated

        foreach (scase; *cases)
        {
            if (scase && checkVar(scase.lastVar))
                return !error; // return error once fully deprecated
        }
        return !error;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CaseStatement : Statement
{
    Expression exp;
    Statement statement;
    int index;              // which case it is (since we sort this)
    VarDeclaration lastVar;

    extern (D) this(const ref Loc loc, Expression exp, Statement s)
    {
        super(loc);
        this.exp = exp;
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new CaseStatement(loc, exp.syntaxCopy(), statement.syntaxCopy());
    }

    override int compare(RootObject obj)
    {
        // Sort cases so we can do an efficient lookup
        CaseStatement cs2 = cast(CaseStatement)obj;
        return exp.compare(cs2.exp);
    }

    override CaseStatement isCaseStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class CaseRangeStatement : Statement
{
    Expression first;
    Expression last;
    Statement statement;

    extern (D) this(const ref Loc loc, Expression first, Expression last, Statement s)
    {
        super(loc);
        this.first = first;
        this.last = last;
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new CaseRangeStatement(loc, first.syntaxCopy(), last.syntaxCopy(), statement.syntaxCopy());
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DefaultStatement : Statement
{
    Statement statement;
    VarDeclaration lastVar;

    extern (D) this(const ref Loc loc, Statement s)
    {
        super(loc);
        this.statement = s;
    }

    override Statement syntaxCopy()
    {
        return new DefaultStatement(loc, statement.syntaxCopy());
    }

    override DefaultStatement isDefaultStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoDefaultStatement : Statement
{
    SwitchStatement sw;

    extern (D) this(const ref Loc loc)
    {
        super(loc);
    }

    override Statement syntaxCopy()
    {
        return new GotoDefaultStatement(loc);
    }

    override GotoDefaultStatement isGotoDefaultStatement() pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoCaseStatement : Statement
{
    Expression exp;     // null, or which case to goto
    CaseStatement cs;   // case statement it resolves to

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new GotoCaseStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override GotoCaseStatement isGotoCaseStatement() pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SwitchErrorStatement : Statement
{
    Expression exp;

    extern (D) this(const ref Loc loc)
    {
        super(loc);
    }

    final extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ReturnStatement : Statement
{
    Expression exp;
    size_t caseDim;

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        return new ReturnStatement(loc, exp ? exp.syntaxCopy() : null);
    }

    override inout(ReturnStatement) isReturnStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class BreakStatement : Statement
{
    Identifier ident;

    extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new BreakStatement(loc, ident);
    }

    override inout(BreakStatement) isBreakStatement() inout nothrow pure
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ContinueStatement : Statement
{
    Identifier ident;

    extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new ContinueStatement(loc, ident);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class SynchronizedStatement : Statement
{
    Expression exp;
    Statement _body;

    extern (D) this(const ref Loc loc, Expression exp, Statement _body)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
    }

    override Statement syntaxCopy()
    {
        return new SynchronizedStatement(loc, exp ? exp.syntaxCopy() : null, _body ? _body.syntaxCopy() : null);
    }

    override bool hasBreak()
    {
        return false; //true;
    }

    override bool hasContinue()
    {
        return false; //true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class WithStatement : Statement
{
    Expression exp;
    Statement _body;
    VarDeclaration wthis;
    Loc endloc;

    extern (D) this(const ref Loc loc, Expression exp, Statement _body, Loc endloc)
    {
        super(loc);
        this.exp = exp;
        this._body = _body;
        this.endloc = endloc;
    }

    override Statement syntaxCopy()
    {
        return new WithStatement(loc, exp.syntaxCopy(), _body ? _body.syntaxCopy() : null, endloc);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TryCatchStatement : Statement
{
    Statement _body;
    Catches* catches;

    extern (D) this(const ref Loc loc, Statement _body, Catches* catches)
    {
        super(loc);
        this._body = _body;
        this.catches = catches;
    }

    override Statement syntaxCopy()
    {
        auto a = new Catches();
        a.setDim(catches.dim);
        foreach (i, c; *catches)
        {
            (*a)[i] = c.syntaxCopy();
        }
        return new TryCatchStatement(loc, _body.syntaxCopy(), a);
    }

    override bool hasBreak()
    {
        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class Catch : RootObject
{
    Loc loc;
    Type type;
    Identifier ident;
    VarDeclaration var;
    Statement handler;

    bool errors;                // set if semantic processing errors

    // was generated by the compiler, wasn't present in source code
    bool internalCatch;

    extern (D) this(const ref Loc loc, Type t, Identifier id, Statement handler)
    {
        //printf("Catch(%s, loc = %s)\n", id.toChars(), loc.toChars());
        this.loc = loc;
        this.type = t;
        this.ident = id;
        this.handler = handler;
    }

    Catch syntaxCopy()
    {
        auto c = new Catch(loc, type ? type.syntaxCopy() : getThrowable(), ident, (handler ? handler.syntaxCopy() : null));
        c.internalCatch = internalCatch;
        return c;
    }
}

/***********************************************************
 */
extern (C++) final class TryFinallyStatement : Statement
{
    Statement _body;
    Statement finalbody;

    bool bodyFallsThru;         // true if _body falls through to finally

    extern (D) this(const ref Loc loc, Statement _body, Statement finalbody)
    {
        super(loc);
        this._body = _body;
        this.finalbody = finalbody;
        this.bodyFallsThru = true;      // assume true until statementSemantic()
    }

    static TryFinallyStatement create(Loc loc, Statement _body, Statement finalbody)
    {
        return new TryFinallyStatement(loc, _body, finalbody);
    }

    override Statement syntaxCopy()
    {
        return new TryFinallyStatement(loc, _body.syntaxCopy(), finalbody.syntaxCopy());
    }

    override bool hasBreak()
    {
        return false; //true;
    }

    override bool hasContinue()
    {
        return false; //true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class OnScopeStatement : Statement
{
    TOK tok;
    Statement statement;

    extern (D) this(const ref Loc loc, TOK tok, Statement statement)
    {
        super(loc);
        this.tok = tok;
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new OnScopeStatement(loc, tok, statement.syntaxCopy());
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexception, Statement* sfinally)
    {
        //printf("OnScopeStatement::scopeCode()\n");
        //print();
        *sentry = null;
        *sexception = null;
        *sfinally = null;

        Statement s = new PeelStatement(statement);

        switch (tok)
        {
        case TOK.onScopeExit:
            *sfinally = s;
            break;

        case TOK.onScopeFailure:
            *sexception = s;
            break;

        case TOK.onScopeSuccess:
            {
                /* Create:
                 *  sentry:   bool x = false;
                 *  sexception:    x = true;
                 *  sfinally: if (!x) statement;
                 */
                auto v = copyToTemp(0, "__os", new IntegerExp(Loc.initial, 0, Type.tbool));
                v.dsymbolSemantic(sc);
                *sentry = new ExpStatement(loc, v);

                Expression e = new IntegerExp(Loc.initial, 1, Type.tbool);
                e = new AssignExp(Loc.initial, new VarExp(Loc.initial, v), e);
                *sexception = new ExpStatement(Loc.initial, e);

                e = new VarExp(Loc.initial, v);
                e = new NotExp(Loc.initial, e);
                *sfinally = new IfStatement(Loc.initial, null, e, s, null, Loc.initial);

                break;
            }
        default:
            assert(0);
        }
        return null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ThrowStatement : Statement
{
    Expression exp;

    // was generated by the compiler, wasn't present in source code
    bool internalThrow;

    extern (D) this(const ref Loc loc, Expression exp)
    {
        super(loc);
        this.exp = exp;
    }

    override Statement syntaxCopy()
    {
        auto s = new ThrowStatement(loc, exp.syntaxCopy());
        s.internalThrow = internalThrow;
        return s;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DebugStatement : Statement
{
    Statement statement;

    extern (D) this(const ref Loc loc, Statement statement)
    {
        super(loc);
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new DebugStatement(loc, statement ? statement.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statements* a = statement ? statement.flatten(sc) : null;
        if (a)
        {
            foreach (ref s; *a)
            {
                s = new DebugStatement(loc, s);
            }
        }
        return a;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class GotoStatement : Statement
{
    Identifier ident;
    LabelDsymbol label;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;

    extern (D) this(const ref Loc loc, Identifier ident)
    {
        super(loc);
        this.ident = ident;
    }

    override Statement syntaxCopy()
    {
        return new GotoStatement(loc, ident);
    }

    final bool checkLabel()
    {
        if (!label.statement)
        {
            error("label `%s` is undefined", label.toChars());
            return true;
        }

        if (label.statement.os != os)
        {
            if (os && os.tok == TOK.onScopeFailure && !label.statement.os)
            {
                // Jump out from scope(failure) block is allowed.
            }
            else
            {
                if (label.statement.os)
                    error("cannot `goto` in to `%s` block", Token.toChars(label.statement.os.tok));
                else
                    error("cannot `goto` out of `%s` block", Token.toChars(os.tok));
                return true;
            }
        }

        if (label.statement.tf != tf)
        {
            error("cannot `goto` in or out of `finally` block");
            return true;
        }

        VarDeclaration vd = label.statement.lastVar;
        if (!vd || vd.isDataseg() || (vd.storage_class & STC.manifest))
            return false;

        VarDeclaration last = lastVar;
        while (last && last != vd)
            last = last.lastVar;
        if (last == vd)
        {
            // All good, the label's scope has no variables
        }
        else if (vd.storage_class & STC.exptemp)
        {
            // Lifetime ends at end of expression, so no issue with skipping the statement
        }
        else if (vd.ident == Id.withSym)
        {
            error("`goto` skips declaration of `with` temporary at %s", vd.loc.toChars());
            return true;
        }
        else
        {
            error("`goto` skips declaration of variable `%s` at %s", vd.toPrettyChars(), vd.loc.toChars());
            return true;
        }

        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class LabelStatement : Statement
{
    Identifier ident;
    Statement statement;
    TryFinallyStatement tf;
    OnScopeStatement os;
    VarDeclaration lastVar;
    Statement gotoTarget;       // interpret
    bool breaks;                // someone did a 'break ident'

    extern (D) this(const ref Loc loc, Identifier ident, Statement statement)
    {
        super(loc);
        this.ident = ident;
        this.statement = statement;
    }

    override Statement syntaxCopy()
    {
        return new LabelStatement(loc, ident, statement ? statement.syntaxCopy() : null);
    }

    override Statements* flatten(Scope* sc)
    {
        Statements* a = null;
        if (statement)
        {
            a = statement.flatten(sc);
            if (a)
            {
                if (!a.dim)
                {
                    a.push(new ExpStatement(loc, cast(Expression)null));
                }

                // reuse 'this' LabelStatement
                this.statement = (*a)[0];
                (*a)[0] = this;
            }
        }
        return a;
    }

    override Statement scopeCode(Scope* sc, Statement* sentry, Statement* sexit, Statement* sfinally)
    {
        //printf("LabelStatement::scopeCode()\n");
        if (statement)
            statement = statement.scopeCode(sc, sentry, sexit, sfinally);
        else
        {
            *sentry = null;
            *sexit = null;
            *sfinally = null;
        }
        return this;
    }

    override LabelStatement isLabelStatement()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class LabelDsymbol : Dsymbol
{
    LabelStatement statement;

    extern (D) this(Identifier ident)
    {
        super(ident);
    }

    static LabelDsymbol create(Identifier ident)
    {
        return new LabelDsymbol(ident);
    }

    // is this a LabelDsymbol()?
    override LabelDsymbol isLabel()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class AsmStatement : Statement
{
    Token* tokens;
    code* asmcode;
    uint asmalign;  // alignment of this statement
    uint regs;      // mask of registers modified (must match regm_t in back end)
    bool refparam;  // true if function parameter is referenced
    bool naked;     // true if function is to be naked

    extern (D) this(const ref Loc loc, Token* tokens)
    {
        super(loc);
        this.tokens = tokens;
    }

    override Statement syntaxCopy()
    {
        return new AsmStatement(loc, tokens);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
version (IN_GCC)
{
    extern (C++) final class ExtAsmStatement : Statement
    {
        StorageClass stc;
        Expression insn;
        Expressions *args;
        Identifiers *names;
        Expressions *constraints;   // Array of StringExp's
        uint outputargs;
        Expressions *clobbers;      // Array of StringExp's
        Identifiers *labels;
        GotoStatements *gotos;

        extern (D) this(Loc loc, StorageClass stc, Expression insn,
                        Expressions *args, Identifiers *names,
                        Expressions *constraints, int outputargs,
                        Expressions *clobbers, Identifiers *labels)
        {
            super(loc);
            this.insn = insn;
            this.args = args;
            this.names = names;
            this.constraints = constraints;
            this.outputargs = outputargs;
            this.clobbers = clobbers;
            this.labels = labels;
            this.gotos = null;
        }

        override Statement syntaxCopy()
        {
            Expressions *c_args = Expression.arraySyntaxCopy(args);
            Expressions *c_constraints = Expression.arraySyntaxCopy(constraints);
            Expressions *c_clobbers = Expression.arraySyntaxCopy(clobbers);

            return new ExtAsmStatement(loc, stc, insn.syntaxCopy(), c_args, names,
                                       c_constraints, outputargs, c_clobbers, labels);
        }

        override void accept(Visitor v)
        {
            v.visit(this);
        }
    }
}

/***********************************************************
 * a complete asm {} block
 */
extern (C++) final class CompoundAsmStatement : CompoundStatement
{
    StorageClass stc; // postfix attributes like nothrow/pure/@trusted

    extern (D) this(const ref Loc loc, Statements* s, StorageClass stc)
    {
        super(loc, s);
        this.stc = stc;
    }

    override CompoundAsmStatement syntaxCopy()
    {
        auto a = new Statements();
        a.setDim(statements.dim);
        foreach (i, s; *statements)
        {
            (*a)[i] = s ? s.syntaxCopy() : null;
        }
        return new CompoundAsmStatement(loc, a, stc);
    }

    override Statements* flatten(Scope* sc)
    {
        return null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ImportStatement : Statement
{
    Dsymbols* imports;      // Array of Import's

    extern (D) this(const ref Loc loc, Dsymbols* imports)
    {
        super(loc);
        this.imports = imports;
    }

    override Statement syntaxCopy()
    {
        auto m = new Dsymbols();
        m.setDim(imports.dim);
        foreach (i, s; *imports)
        {
            (*m)[i] = s.syntaxCopy(null);
        }
        return new ImportStatement(loc, m);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
