import libgit2
import Foundation

internal class StrArray {
    var strarray: git_strarray

    init(_ strings: [String]) {
        let count = strings.count
        self.strarray = git_strarray.init()
        if count == 0 { return }
        
        let cStrings = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count)
        for (index, string) in strings.enumerated() {
            cStrings.advanced(by: index).pointee = strdup(string.cString(using: .utf8)!)
        }
        
        self.strarray.strings = cStrings
        self.strarray.count = count
    }

    deinit {
        git_strarray_free(&self.strarray)
    }
}
