import libgit2
import Foundation

internal extension Date {
    
    func gitTime(withTimeZone timeZone: TimeZone = .current) -> git_time {
        return git_time.init(time: git_time_t(self.timeIntervalSince1970), offset: Int32(timeZone.secondsFromGMT() * 60), sign: 0)
    }
}
