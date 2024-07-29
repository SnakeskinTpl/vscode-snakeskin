/**
 * This is the grammar definition for the [Snakeskin language](https://snakeskintpl.github.io/docs/api.html).
 * Snakeskin is a template engine that allows you to write templates in a language that is similar to JavaScript.
 * Since Snakeskin is more of a macro language on top of JavaScript, it is impossible to define its
 * full grammar in EBNF notation without also parsing JS code (which is beyond the scope of this project).
 * Therefore, only the constructs used in V4Fire and Edadeal are supported, as they are much simpler,
 * with a few exceptions where the full grammar is not too complicated.
 */
grammar Snakeskin

entry Module:
    (directives+=Directive)*;


// TODO: differentiate between top-level and other directives
Directive:
    Namespace |
    Template |
    // Interface |
    Placeholder |
    Block |

    Output |
    Call |
    Void |
    Return |

    Eval |
    Head |

    With |

    Var |
    Const |

    If |
    ElseIf |
    ElseUnless |
    Unless |
    Else |

    For |
    // While |
    // Do |
    Break |
    Continue |

    ForEach |
    ForIn |

    Try |
    Throw |
    Catch |
    Finally |

    DocType |

    Tag |

    Include |
    Import |

    Func |
    Target |
    PutIn |

    Super |

    Ignore |
    IgnoreAllWhitespace
;

/**
 * A fragment for any directive that accepts an indented body of other directives.
 */
fragment Body:
    INDENT
    body+=Directive+
    DEDENT
;


// ---------- I. Creating templates ----------

/**
 * The path of object properties access.
 * e.g.: `exports.demo.helloWorld.index`
 */
ReferencePath:
    ( name=(DASHED_ID|ID)
    | '[' name=(STRING|MACRO) (PIPE filters+=ID)* R_BRAC
    )
    (DOT next=ReferencePath)?
;

/**
 * A directive that specifies the namespace for a file (module).
 * The namespace is used when exporting from a module, as well as when importing.
 */
Namespace:
    '-' 'namespace'
    name=ReferencePath
;

Parameter:
    usesWith?=AT? // Actually this line currently never matches because it would get detected as "ATTR_KEY"
    name=(ID|ATTR_KEY) // hack: ATTR_KEY because it can sometimes start with '@' and have default value, hence matching the wrong token
    ('=' defaultValue=PARAM_DEFAULT_VALUE)?
    // TODO: any JS expression
;

Template:
    '-' 'template'
    name=ID
    '('
        (params+=Parameter (',' params+=Parameter)*)?
    R_PAREN
    ('extends' extendsWith?=AT? extends=ReferencePath)?
    Body?
;

// TODO: Interface

/**
 * A placeholder is just like a template, except that it will not be included in the final JS
 */
Placeholder:
    '-' 'placeholder'
    name=ID
    '('
        (params+=Parameter (',' params+=Parameter)*)?
    R_PAREN
    ('extends' extendsWith?=AT? extends=ReferencePath)?
    Body
;

Block:
    '-' 'block'
    (container=[Template] '->')?
    name=ID
    ('('
        (params+=Parameter (',' params+=Parameter)*)?
    R_PAREN)?
    Body?
;

// TODO: set


// ---------- II. Execution/output ----------

Output:
    text=(TEXT|INTERPOLATION|',') | // special case for comma because it is a token on its own
    '(' text=TEXT2 R_PAREN // special case for '(' because it has a priority as a token since it's a literal
;

/**
 * Allowed only within templates or external blocks
 */
Call:
    '+='
    value=(ATTR_VAL_SL|TEXT) // TODO: any JS expression
    Body?
;

Void:
    '?'
    content=JS_EXPR
;

Return:
    '-' 'return'
    expr=JS_EXPR
;


// ---------- III. Global context ----------

/**
 * This directive creates a block that will not be executed at the translation stage,
 * but will be included in the final JS.
 * It can only be used in the global scope.
 */
Eval:
    '-' 'eval'
    Body
;

Head:
    '-' 'head'
    Body
;


// ---------- IV. Scope ----------

With:
    '-' 'with'
    name=ReferencePath
;


// ---------- V. Vars ----------

Var:
    ':'
    ('putIn' name=ID Body
    | name=ID ('=' initialValue=(AttrVal|JS_EXPR))?
    )
;

Const:
    '-' name=ID
    '=' initialValue=AttrVal  // TODO: any JS expression
;

// TODO: Global


// ---------- VI. Logical directives ----------

If:
    '-' 'if'
    ( '(' EXC? condition=DottedID R_PAREN // to handle (!IS_PROD)
    | condition=(DottedID|JS_EXPR)
    )
    Body
    // alternatives+=(ElseIf | ElseUnless)*
    // else=Else?
    // I have no idea why the 2 lines above are not working
;

ElseIf:
    '-' 'else' 'if'
    condition=JS_EXPR
    Body
;

ElseUnless:
    '-' 'else' 'unless'
    condition=JS_EXPR
    Body
;

Else:
    '-' 'else'
    Body
;

Unless:
    '-' 'unless'
    condition=JS_EXPR
    Body
    // (alternatives+=ElseIf | alternatives+=ElseUnless)*
    // else=Else?
;

// TODO: switch


// ---------- VII. Loops ----------

For:
    '-' 'for'
    loop=JS_EXPR
    // initialization=ID // TODO: any JS expression
    // ';'
    // condition=ID // TODO: any JS expression
    // ';'
    // step=ID // TODO: any JS expression
    Body
;

// TODO: While

// TODO: Do-While

Break: {infer Break} '-' 'break';

Continue: {infer Continue} '-' 'continue';

// ---------- VIII. Iterators ----------

ForEach:
    '-' 'forEach'
    collection=(ID | JS_Array | ATTR_KEY) // TODO: any JS expression
    '=>'
    name=ID
    (',' idx=ID)?
    Body
;

ForIn:
    '-' 'forIn'
    collection=ID // TODO: any JS expression
    '=>'
    name=ID
    (',' idx=ID)?
    Body
;


// ---------- IX. Working with exceptions ----------

Try: '-' 'try' Body;

Throw: '-' 'throw' name=JS_EXPR; // TODO: any JS expression

Catch:
    '-' 'catch'
    name=ID
    Body
;

Finally:
    '-' 'finally'
    Body
;


// ---------- X. Working with whitespace ----------

// ignoreWhitespaces is implemented in the tokenizer

IgnoreAllWhitespace: '&+' Body;

// Removed because unused and conflicts with class names
// UnIgnoreAllWhitespace: '&-' Body;

// TODO: sp

// ---------- XI. Working with HTML/XML ----------

DocType:
    '-' 'doctype'
    name=ID?
;

Attribute:
    ( key=AttrKey
      (DOT modifiers+=ID)*
      ('=' value=AttrVal)?
    )
    | interpolated=INTERPOLATION
;

Class:
    DOT name=ClassName |
    nonSticky?='[' DOT name=ClassName Class? R_BRAC
;

Tag:
    '<'
    ( tagName=DOT
    | tagName=(TagName|'?')? (classes+=Class)*
    )
    (attrs+=Attribute (PIPE? attrs+=Attribute)*)? // If an attribute is inline, it doesn't need a separator
    Body?
;

// TODO: script
// TODO: style
// TODO: link
// TODO: comment


// ---------- XII. Char escaping ----------

// TODO: cdata
// TODO: literal


// ---------- XIII. Modules ----------

/**
 * Includes the file at the specified path
 */
Include:
    '-' 'include'
    path=STRING
    (PIPE filters+=ID)*
    ('as' renderAs=('placeholder' | 'interface'))?
;

Import:
    '-' 'import'
    name=ID
    'from'
    path=STRING
;


// ---------- XIV. Creating literals ----------

Func:
    '(' R_PAREN '=>'
    params+=ID (',' params+=ID)*
    Body
;

Target:
    '-' 'target'
    value=JS_EXPR // TODO: any JS expression
    ('as' name=ID)? // TODO: any JS expression
    Body?
;

PutIn:
    '*'
    name=ID
    Body
;


// ---------- XV. Asynchronous directives ----------

// TODO: series
// TODO: parallel
// TODO: waterfall
// TODO: yield
// TODO: await


// ---------- XVI. Inheritance ----------

Super: {infer Super} '-' 'super';


// ---------- Special cases ----------

Ignore: {infer Ignore} '-' '@@ignore'; // TODO: actually this shouldn't be special. It's a decorator above a template (using a global variable)
// single '@' means 'with' syntax, double '@@' means "super global variable". when used before template, it's a decorator,


// ---------- Terminals ----------

// Note: everything about the terminals is a big mess full of workarounds and hacks
// due to ambiguity everywhere in the syntax.
// In the future, all tokens would have to be rewritten from scratch using Chevrotain
// and custom pattern functions, or perhaps a custom lexer from scratch (not using Chevrotain's lexer)

AttrKey returns string:
    ATTR_KEY | ID | DASHED_ID | INTERPOLATION |
    DASHED_ID ':' '[' ID (DOT ID)* R_BRAC | // for "v-icon:[el.preIcon]"
    '#' ('[' ID (DOT ID)* R_BRAC)?
;

DottedID returns string: ID (DOT ID)*;

ClassName returns string:
    ID | DASHED_ID | INTERPOLATION | CLASS_NAME INTERPOLATION?
;

TagName returns string:
    ID |
    DASHED_ID |
    INTERPOLATION |
    ID INTERPOLATION | // special case for "h{i}"
    ATTR_KEY // Because elements can start with '@', but ATTR_KEY has a higher priority than AT
;

JS_Array returns string: '[' (STRING (',' STRING)*)? R_BRAC;

/**
 * The token builder will be overridden to choose one based on existing inside "& ."
 */
AttrVal returns string:
    ID | DASHED_ID | ATTR_VAL_SL | ATTR_VAL_ML | JS_EXPR | TEXT;


terminal TEXT: /(?<=[\n\r]+\s+)(?!=+=|\/\*)[^\-\s<:?].*?(?=\r?\n)/s;
terminal TEXT2: /(?<=[\n\r]+\s+\()(?!=+=)[^\-\s<:?].*(?=\)\r?\n)/; // special case for "(b: { @@buildVersion })"
// terminal PARAM_DEFAULT_VALUE: /(?<= = )[\p{L}\d'"{} ]+(?=\)|,)/u; // \p{L} instead of \w to match any letter (including Russian)
terminal PARAM_DEFAULT_VALUE: /(?<= = )((\{(\w+:\s*(\{\}|\w+)(,\s*\w+:\s*(\{\}|\w+))*)?\})|[\p{L}\d'" ]+)(?=\)|,)/u; // \p{L} instead of \w to match any letter (including Russian)
// Workaround for JavaScript expressions
terminal JS_EXPR: /(?<=\s(return|=|if|for|throw|unless|- target|\?) ).+?(?=\r?\n)/;
terminal DASHED_ID: /[_a-zA-Z\-][\w\-]*?(?=-\w)[\-\w]+/;
terminal ID: /[_a-zA-Z][\w]*/;

// Attribute values come after an '=' sign, then they match anything until " | " or a new line
// positive lookbehind/ahead to avoid mixing between token types due to overlap.
/**
 * When not inside & . context, attr ends with new line or " | " (or maybe " &\n" ?)
 */
terminal ATTR_VAL_SL: /(?<==\s*).+?(?=\r?\n|\s+\|\s+)/;
// terminal ATTR_VAL_SL: /(?<==\s*).+?(?=\r?\n|\s+\|\s+|\s+&\r?\n)/;
/**
 * When inside & . context, attr ends with " | " or " .\n"
 */
terminal ATTR_VAL_ML: /(?<==\s*).+?(?=\s+\.\s+|\s+\|\s+)/s;

terminal fragment BIND_ATTR_KEY: /\:[\w\-]*/;
terminal fragment SLOT_ATTR_KEY: /\#[\w\-]*/;
terminal fragment EVENT_ATTR_KEY: /\@[\w:\-\[\]]*/;
terminal fragment EVENT_ATTR_KEY2: /\@\[[\w:\-\(\)\.]*?\]/; // special case for "@[getControlEvent(tmp.buttonControl)]"
terminal fragment DATA_ATTR_KEY: /-[\w\-]*/;
terminal fragment ATTR_KEY_END: /(?=\s*=\s*|\.|\s)/; // Attr key ends with an equal sign or a dot for modifiers, or just whitespace (if no value)
terminal ATTR_KEY: (BIND_ATTR_KEY|SLOT_ATTR_KEY|EVENT_ATTR_KEY|EVENT_ATTR_KEY2|DATA_ATTR_KEY|DASHED_ID|ID) INTERPOLATION? ATTR_KEY_END;
terminal AT: /@/; // Again, to have a lower priority than "JS_EXPR"

terminal STRING: /"(\\.|[^"\\])*"|'(\\.|[^'\\])*'/;
terminal MACRO: /%\w+%/;
terminal INTERPOLATION: /\$\{.+?\}/; // This will also be overridden in the token builder to balance braces

// To be overridden in the tokenizer
terminal INDENT: ':synthetic-indent:';
terminal DEDENT: ':synthetic-dedent:';

hidden terminal AMPERSAND_NL: /(?<=\s)&(?=[\r\n]+)/; // For starting multi-line mode
hidden terminal DOT_NL: /(?<=\n\s+)\.(?=[\r\n]+)/; // For ending multi-line mode
terminal CLASS_NAME: /[_a-z\-&][\w\-&]*/;

terminal DOT: /\./; // For class names. Lower priority than DOT_NL

// All of the following is also to give a lower priority
terminal R_PAREN: /\)/;
terminal R_BRAC: /\]/;
terminal PIPE: /\|/;
terminal EXC: /!/;

hidden terminal WS: /[ \t]+/;

hidden terminal ML_COMMENT: /\/\*[\s\S]*?\*\//;
hidden terminal SL_COMMENT: /\/\/\/[^\n\r]*/;

hidden terminal NEW_LINE: /[\r\n]+/;
