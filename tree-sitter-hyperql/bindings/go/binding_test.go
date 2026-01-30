package tree_sitter_hyperql_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_hyperql "github.com/jarbear82/hyperql/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_hyperql.Language())
	if language == nil {
		t.Errorf("Error loading HyperQL grammar")
	}
}
