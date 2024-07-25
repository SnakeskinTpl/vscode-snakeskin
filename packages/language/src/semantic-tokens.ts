import type { AstNode } from 'langium';
import { AbstractSemanticTokenProvider, type SemanticTokenAcceptor } from 'langium/lsp';
import { SemanticTokenTypes, SemanticTokenModifiers } from 'vscode-languageserver-protocol';
import { isAttribute, isClass, isTag } from './generated/ast.js';

export class SemanticTokenProvider extends AbstractSemanticTokenProvider {
	protected override highlightElement(node: AstNode, acceptor: SemanticTokenAcceptor): void | 'prune' | undefined {
		if (isTag(node)) {
			acceptor({
				node,
				property: 'tagName',
				type: SemanticTokenTypes.function,
			});
		} else if (isAttribute(node)) {
			acceptor({
				node,
				property: 'key',
				type: SemanticTokenTypes.property,
			});
			acceptor({
				node,
				property: 'value',
				type: SemanticTokenTypes.string,
			});
		} else if (isClass(node)) {
			acceptor({
				node,
				property: 'name',
				type: SemanticTokenTypes.modifier,
				modifier: node.nonSticky ? SemanticTokenModifiers.static : [],
			});
		}
	}
}
