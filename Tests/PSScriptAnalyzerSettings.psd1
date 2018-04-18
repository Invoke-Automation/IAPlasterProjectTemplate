@{
    ExcludeRules=@(
			'PSUseDeclaredVarsMoreThanAssignments' # This rule sometimes has false positives when nesting
		)
}