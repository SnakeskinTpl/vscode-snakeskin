import type { ValidationAcceptor, ValidationChecks } from 'langium';
import type { SnakeskinAstType, Module } from './generated/ast.js';
import type { SnakeskinServices } from './snakeskin-module.js';

/**
 * Register custom validation checks.
 */
export function registerValidationChecks(services: SnakeskinServices) {
    const registry = services.validation.ValidationRegistry;
    const validator = services.validation.SnakeskinValidator;
    const checks: ValidationChecks<SnakeskinAstType> = {
        Module: validator.validateModule,
    };
    registry.register(checks, validator);
}

/**
 * Implementation of custom validations.
 */
export class SnakeskinValidator {

    validateModule(module: Module, accept: ValidationAcceptor): void {
    }

}
