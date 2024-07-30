import { Lexer, CstParser, createToken, type ParserMethod, type CstNode } from 'chevrotain';

const Identifier = createToken({ name: "Identifier", pattern: /[a-zA-Z]\w*/ });
const Integer = createToken({ name: "Integer", pattern: /\d+/ });
const String = createToken({ name: "String", pattern: /"(\\.|[^"\\])*"|'(\\.|[^'\\])*'/ });
const Boolean = createToken({ name: "Boolean", pattern: /true|false/ });
const WhiteSpace = createToken({ name: "WhiteSpace", pattern: /\s+/, group: Lexer.SKIPPED });
const LeftBracket = createToken({ name: "LeftBracket", pattern: /\[/ });
const RightBracket = createToken({ name: "RightBracket", pattern: /]/ });
const LeftBrace = createToken({ name: "LeftBrace", pattern: /{/ });
const RightBrace = createToken({ name: "RightBrace", pattern: /}/ });
const Comma = createToken({ name: "Comma", pattern: /,/ });
const Colon = createToken({ name: "Colon", pattern: /:/ });

const allTokenTypes = [
	Identifier,
	Integer,
	String,
	Boolean,
	WhiteSpace,
	LeftBracket,
	RightBracket,
	LeftBrace,
	RightBrace,
	Comma,
	Colon,
];

const JsLiteralLexer = new Lexer(allTokenTypes);

/**
 * A mini parser for JavaScript literals.
 */
class JsLiteralParser extends CstParser {
	readonly parse: ParserMethod<[], CstNode>;

	constructor() {
		super(allTokenTypes, {
			nodeLocationTracking: 'onlyOffset'
		});

		const $ = this;

		const SimpleLiteral = $.RULE("SimpleLiteral", () => {
			$.OR([
				{ ALT: () => $.CONSUME(Identifier) },
				{ ALT: () => $.CONSUME(Integer) },
				{ ALT: () => $.CONSUME(Boolean) },
				{ ALT: () => $.CONSUME(String) },
			]);
		});

		const ArrayLiteral = $.RULE("ArrayLiteral", () => {
			$.CONSUME(LeftBracket);
			$.MANY_SEP({
				SEP: Comma,
				DEF: () => {
					$.SUBRULE(JsLiteral);
				},
			});
			$.CONSUME(RightBracket);
		});

		const ObjectLiteral = $.RULE("ObjectLiteral", () => {
			$.CONSUME(LeftBrace);
			$.MANY_SEP({
				SEP: Comma,
				DEF: () => {
					$.CONSUME(Identifier);
					$.CONSUME(Colon);
					$.SUBRULE(JsLiteral);
				},
			});
			$.CONSUME(RightBrace);
		});

		const JsLiteral = $.RULE("JSLiteral", () => {
			$.OR([
				{ ALT: () => $.SUBRULE(SimpleLiteral) },
				{ ALT: () => $.SUBRULE(ArrayLiteral) },
				{ ALT: () => $.SUBRULE(ObjectLiteral) },
			]);
		});

		this.parse = JsLiteral;

    this.performSelfAnalysis();
	}
}

const parser = new JsLiteralParser();

/**
 * Given an input string, tries to consume a JavaScript literal (number, boolean, string, array, object)
 * from the beginning of the string, and returns the substring that matches (possibly with whitespace).
 */
export function consumeLiteral(text: string): string {
	const {tokens, errors} = JsLiteralLexer.tokenize(text);
	parser.input = tokens;
	const {startOffset = 0, endOffset = 0} = parser.parse()?.location ?? {};
	const hasErrorBeforeStart = errors.some((error) => error.offset < startOffset);
	if (hasErrorBeforeStart) {
		return '';
	}
	return text.substring(0, endOffset + 1);
}
