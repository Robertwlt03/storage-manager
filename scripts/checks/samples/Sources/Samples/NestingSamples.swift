// swift-format-ignore-file

func deeplyNested(values: [Int]) -> Int {
    var total = 0
    for value in values {
        if value > 0 {
            if value != 1 {  // expect: 3 blocks inside each other
                total += value
            }
        }
    }
    return total
}

func outerFunction() -> Int {
    func innerFunction() -> Int {
        func innermostFunction() -> Int {  // expect: a function inside a function inside a function
            0
        }
        return innermostFunction()
    }
    return innerFunction()
}
