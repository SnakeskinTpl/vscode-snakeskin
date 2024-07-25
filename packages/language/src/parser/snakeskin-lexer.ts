import type { IMultiModeLexerDefinition, TokenType, CustomPatternMatcherFunc } from 'chevrotain';
import { createTokenInstance } from 'chevrotain';
import type { Grammar, GrammarAST, LexerResult, TokenBuilderOptions } from 'langium';
import { IndentationAwareTokenBuilder, REGULAR_MODE, IGNORE_INDENTATION_MODE, IndentationAwareLexer } from './indentation-aware';
import { SnakeskinTerminals } from '../generated/ast';

type Terminals = keyof typeof SnakeskinTerminals;

export class SnakeskinTokenBuilder extends IndentationAwareTokenBuilder<Terminals> {
	constructor() {
		super({
			ignoreIndentationDelimeters: [
				['AMPERSAND_NL', 'DOT_NL'],
			],
		});
	}

	override buildTokens(grammar: Grammar, options?: TokenBuilderOptions | undefined): IMultiModeLexerDefinition {
		const {modes, defaultMode} = super.buildTokens(grammar, options);

		return {
			modes: {
				[REGULAR_MODE]: modes[REGULAR_MODE].filter(token => token.name !== 'ATTR_VAL_ML'),
				[IGNORE_INDENTATION_MODE]: modes[IGNORE_INDENTATION_MODE].filter(token => !['ATTR_VAL_SL', 'TEXT'].includes(token.name)),
			},
			defaultMode,
		}
	}

	protected override buildTerminalToken(terminal: GrammarAST.TerminalRule): TokenType {
		const tokenType = super.buildTerminalToken(terminal);
		if (tokenType.name === 'TEXT') {
			const originalPattern = tokenType.PATTERN as CustomPatternMatcherFunc;
			tokenType.PATTERN = (text, offset, tokens, groups) => {
				const originalMatch = originalPattern(text, offset, tokens, groups);
				if (originalMatch === null) {
					return null;
				}
				const match = originalMatch[0];
				if (!match.endsWith(' .')) {
					return originalMatch;
				}

				// find the previous token that ends with " &"
				for (let i = tokens.length - 1; i >= 0; i--) {
					const prevToken = tokens[i];
					if (['TEXT', 'ATTR_VAL_SL', 'JS_EXPR'].includes(prevToken.tokenType.name)) {
						if (prevToken.image.endsWith(' &')) {
							const image = tokens.slice(i).map(tk => tk.image).join('') + match;
							const endLine = text.substring(0, offset).split(/\r\n|\r|\n/).length;
							const tok = createTokenInstance(prevToken.tokenType, image, prevToken.startOffset, offset, prevToken.startLine!, endLine, prevToken.startColumn!, match.length);
							tokens[i] = tok;
							tokens.length = i + 1; // truncate the rest
							// TODO: remove the & and .
							return originalMatch; // TODO: how to skip?
						}
					}
				}

				return originalMatch;
			};
		} else if (tokenType.name === 'INTERPOLATION') {
			const startRegex = /\$\{/y;
			tokenType.PATTERN = (text, offset, tokens, groups) => {
				startRegex.lastIndex = offset;
				const match = startRegex.exec(text);
				if (match === null) {
					return null;
				}
				// balance braces until reaching the closing one
				// technically, this is also not enough since we can have braces inside strings, but 🤷‍♂️
				let depth = 1;
				let i = startRegex.lastIndex;
				while (depth > 0 && i < text.length) {
					if (text[i] === '{') {
						depth++;
					} else if (text[i] === '}') {
						depth--;
					}
					i++;
				}
				return [text.substring(offset, i)];
			}
		} else if (tokenType.name === 'ATTR_VAL_SL') {
			const originalPattern = tokenType.PATTERN as CustomPatternMatcherFunc;
			tokenType.PATTERN = (text, offset, tokens, groups) => {
				if (tokens.length < 3) return null;
				const [before, prevToken, eq] = tokens.slice(-3);
				// Before the key, there must be an HtmlTag or '|' (if it is attr key, not '+=')
				// Another way to look at it is to not allow a ',' or '(' before the key to not collide with "default value"
				if (eq.tokenType.name !== '+=' && eq.tokenType.name !== 'EQ' && !['+=', 'ATTR_KEY', 'ID', 'DASHED_ID'].includes(prevToken.tokenType.name) || ['(', ','].includes(before.tokenType.name)) {
					return null;
				}

				return originalPattern(text, offset, tokens, groups);
			}
		}
		return tokenType;
	}
}

export class SnakeskinLexer extends IndentationAwareLexer {
	override tokenize(text: string): LexerResult {
		const result = super.tokenize(text);
		let {errors, hidden, tokens} = result;

		// if (errors.length > 0) {
		// 	return result;
		// }

		// This is basically monkey patching. Very big workaround to support existing code
		// Go through the tokens. If there is any JS_EXPR that ends in ' &\n', merge it with the next tokens until 'DOT_NL'
		// 'DOT_NL' is in the hidden tokens
		for (let i = 0; i < tokens.length - 1; i++) {
			const token = tokens[i];
			const nextToken = tokens[i + 1];
			if (['TEXT', 'ATTR_VAL_SL', 'JS_EXPR'].some(name => token.tokenType.name === name) && nextToken.tokenType.name === 'TEXT') {
				// A repeated token. Remove the text one
				if (token.image.endsWith(nextToken.image)) {
					tokens.splice(i + 1, 1);

					// clear any error inside this range
					const end = nextToken.endOffset ?? text.length;
					errors = errors.filter((err) => {
						return err.offset < token.startOffset || err.offset >= end;
					});
				}
			}
			// if (token.tokenType.name === 'JS_EXPR' && token.image.endsWith(' &\n')) {
			// 	const end = token.endOffset ?? text.length;
			// 	// first ' .\n' token after this JS_EXPR
			// 	const dot = hidden.find(tok => tok.tokenType.name === 'DOT_NL' && tok.startOffset >= end);
			// 	if (!dot) {
			// 		console.error('Expected DOT_NL token after JS_EXPR ending in " &\\n"');
			// 		continue;
			// 	}
			// 	// find the first normal token starting after the dot
			// 	// const j = tokens.findIndex(tok => tok.startOffset >= dot.startOffset ?? text.length);

			// 	// merge all tokens starting with until the one with end offset before start offset of dot

			// }
		}

		// remove any indent/dedent tokens sandwiched between 2 TEXT tokens
		for (let i = 0; i < tokens.length - 2; i++) {
			const [prev, current, next] = tokens.slice(i, i + 3);
			if (prev.tokenType.name === 'TEXT' && next.tokenType.name === 'TEXT' && ['INDENT', 'DEDENT'].includes(current.tokenType.name)) {
				tokens.splice(i + 1, 1);
			}
		}

		return {
			errors, hidden, tokens,
		};
	}
}
