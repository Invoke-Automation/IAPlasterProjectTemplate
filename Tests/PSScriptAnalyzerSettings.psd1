@{
    ExcludeRules=@(
			'PSUseDeclaredVarsMoreThanAssignments', # This rule sometimes has false positives when nesting
			'PSAvoidGlobalVars' # We need global variables for our test variables in the module scope
		)
}