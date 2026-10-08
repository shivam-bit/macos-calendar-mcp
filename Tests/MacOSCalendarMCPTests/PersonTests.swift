import Testing
@testable import MacOSCalendarMCP

@Suite("Person")
struct PersonTests {
    let ana = Person(name: "Ana", email: "ana@x.com", isSelf: false, status: "accepted")
    let bo = Person(name: "Bo", email: "bo@x.com", isSelf: true, status: "pending")
    let noEmailA = Person(name: "Zed", email: nil, isSelf: false, status: nil)
    let noEmailB = Person(name: "Amy", email: nil, isSelf: false, status: "declined")
    let anonymous = Person(name: nil, email: nil, isSelf: false, status: nil)

    @Test("different input orders give the same output")
    func orderIndependent() {
        let people = [ana, bo, noEmailA, noEmailB, anonymous]
        let expected = Person.stableOrder(people)
        #expect(Person.stableOrder(people.reversed()) == expected)
        #expect(Person.stableOrder([noEmailA, ana, anonymous, bo, noEmailB]) == expected)
    }

    @Test("emails sort first, people without an email last ordered by name")
    func nilEmailsLast() {
        let ordered = Person.stableOrder([noEmailA, anonymous, bo, noEmailB, ana])
        #expect(ordered == [ana, bo, noEmailB, noEmailA, anonymous])
    }

    @Test("same email falls back to name, self flag, then status")
    func tieBreaks() {
        let a = Person(name: "A", email: "e", isSelf: true, status: "x")
        let b = Person(name: "A", email: "e", isSelf: false, status: "y")
        let c = Person(name: "A", email: "e", isSelf: false, status: "x")
        #expect(Person.stableOrder([a, b, c]) == [c, b, a])
        #expect(Person.stableOrder([c, a, b]) == [c, b, a])
    }
}
