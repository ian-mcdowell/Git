import git2
import Foundation

internal typealias git_tree = OpaquePointer

/// Git tree parsing, loading
/// - See: git2/tree.h
public class Tree {
    internal let tree: git_tree

    internal init(tree: git_tree) {
        self.tree = tree
    }
    
    deinit {
        git_tree_free(self.tree)
    }
}
