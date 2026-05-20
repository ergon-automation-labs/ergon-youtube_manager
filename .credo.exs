%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/"],
        excluded: []
      },
      min_priority: :normal,
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Design.TagFIXME, false},
        {Credo.Check.Readability.MaxLineLength, [max_length: 120]},
        {Credo.Check.Readability.FunctionNames},
        {Credo.Check.Readability.LargeNumbers},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs},
        {Credo.Check.Readability.ParenthesesInCondition},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.RedundantBlankLines},
        {Credo.Check.Readability.Semicolons},
        {Credo.Check.Readability.SpaceAfterCommas},
        {Credo.Check.Readability.StringSigils},
        {Credo.Check.Readability.TrailingBlankLine},
        {Credo.Check.Readability.TrailingWhiteSpace},
        {Credo.Check.Readability.UnnecessaryAliasExpansion},
        {Credo.Check.Readability.VariableNames, exit_status: 0},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Refactor.FunctionArity, false},
        {Credo.Check.Refactor.LongQuoteBlocks, false},
        {Credo.Check.Refactor.MapInto, [exit_status: 0]},
        {Credo.Check.Refactor.MatchInCondition},
        {Credo.Check.Refactor.NegatedConditionsInUnless},
        {Credo.Check.Refactor.NegatedConditionsWithElse},
        {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
        {Credo.Check.Refactor.PipeChainStart, false},
        {Credo.Check.Refactor.UnlessWithElse},
        {Credo.Check.Warning.BoolOperationOnSameValues},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck},
        {Credo.Check.Warning.IoInspect},
        {Credo.Check.Warning.OperationOnSameValues},
        {Credo.Check.Warning.OperationWithConstantResult},
        {Credo.Check.Warning.RaiseInsideRescue},
        {Credo.Check.Warning.UnusedEnumOperation},
        {Credo.Check.Warning.UnusedFileOperation},
        {Credo.Check.Warning.UnusedKeywordOperation},
        {Credo.Check.Warning.UnusedListOperation},
        {Credo.Check.Warning.UnusedPathOperation},
        {Credo.Check.Warning.UnusedStringOperation},
        {Credo.Check.Warning.UnusedTupleOperation},
        {Credo.Check.Warning.UnsafeExec}
      ]
    }
  ]
}
