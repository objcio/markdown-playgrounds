//
//  Helpers.swift
//  CommonMark
//
//  Created by Chris Eidhof on 22.03.19.
//

import Foundation

extension Collection where Element: Equatable {
    func indexOfFirstDifference(in other: Self) -> Index? {
        var i1 = startIndex
        var i2 = other.startIndex
        while i1 < endIndex, i2 < other.endIndex, self[i1] == other[i2] {
            formIndex(after: &i1)
            other.formIndex(after: &i2)
        }
        return (i1 == i2) ? nil : i2
    }
}

final class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic serial queue")
    private var _value: A
    init(_ value: A) {
        self._value = value
    }
    
    var value: A {
        return queue.sync { self._value }
    }
    
    func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
        }
    }
}
