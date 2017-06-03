//
//  ParserTests.swift
//  Outlander
//
//  Created by Joseph McBride on 4/4/17.
//  Copyright © 2017 Joe McBride. All rights reserved.
//

import Foundation
import Nimble
import Quick

class RecordingNotifier : INotifyMessage {

    var messages:[String] = []

    func notify(_ message:TextTag) {

        if message.text.containsAny(["Starting", "started", "completed after", "initialized"]) {
            return
        }

        self.messages.append(message.text)
    }

    func sendCommand(_ command:CommandContext) {
        self.messages.append(command.command)
    }

    func sendEcho(_ echo:String) {
        self.messages.append(echo)
    }

    func clear() {
        messages.removeAll()
    }
}

class StubScriptLoader {
    var script:[String] = []

    func load() -> [String] {
        return script
    }

    func set(_ text:String) {
        script = text.components(separatedBy: "\n")
    }

    func set(_ lines:[String]) {
        script = lines
    }
}

class ScriptTester : QuickSpec {

    override func spec() {

        describe("the script") {

            let context = GameContext()
            let loader = StubScriptLoader()
            let notifier = RecordingNotifier()
            var script = try! Script(
                notifier,
                {_ in loader.load()},
                "Script",
                context,
                { print("done") })

            beforeEach() {
                notifier.clear()
                script = try! Script(
                    notifier,
                    {_ in loader.load()},
                    "Script",
                    context,
                    { print("done") })
            }

            describe("debug") {
                it("basic debug") {
                    loader.set("debug 5")
                    script.run([])
                    expect(notifier.messages).to(equal(["debug 5\n"]))
                }
            }

            describe("echo") {
                it("basic text") {
                    loader.set("echo hi")
                    script.run([])
                    expect(notifier.messages).to(equal(["hi\n"]))
                }
            }

            describe("variables") {
                it("label vars") {
                    loader.set([
                        "var one &0",
                        "echo %one"
                    ])
                    script.context.labelVars["0"] = "hi"
                    script.run([])
                    expect(notifier.messages).to(equal(["hi\n"]))
                }
            }

            describe("if") {
                it("nested ifs") {
                    loader.set([
                        "if_1 {",
                            "echo one",
                            "if 1 == 1 {",
                                "echo two",
                            "}",
                            "echo after",
                        "}",
                        "echo after two"
                    ])
                    script.run(["abcd"])
                    expect(notifier.messages).to(equal([
                        "one\n",
                        "two\n",
                        "after\n",
                        "after two\n"
                    ]))
                }

                it("consecutive") {
                    loader.set([
                        "if_1 {",
                            "echo one",
                        "}",
                        "if_1 then echo two",
                        "else echo three",
                        "echo four"
                    ])
                    script.run(["abcd"])
                    expect(notifier.messages).to(equal([
                        "one\n",
                        "two\n",
                        "four\n",
                    ]))
                }

                it("command between") {
                    loader.set([
                        "if_1 {",
                            "echo one",
                        "}",
                        "echo two",
                        "if_1 then echo three",
                        "else echo four",
                        "echo five"
                    ])
                    script.run(["abcd"])
                    expect(notifier.messages).to(equal([
                        "one\n",
                        "two\n",
                        "three\n",
                        "five\n"
                    ]))
                }
            }

            describe("if else") {
                it("single line if else") {
                    loader.set([
                        "if 1 == 2 then echo one",
                        "else echo two"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["two\n"]))
                }

                it("single line if else") {
                    loader.set([
                        "if 1 == 1 then echo one",
                        "else echo two"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["one\n"]))
                }

                it("multi line else") {
                    loader.set([
                        "if 1 > 1 {",
                            "echo one",
                            "echo five",
                        "}",
                        "else",
                        "{",
                            "echo two",
                            "echo three",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["two\n", "three\n"]))
                }

                it("multi line else") {
                    loader.set([
                        "if 1 > 1 then echo one",
                        "else",
                        "{",
                        "echo two",
                        "echo three",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["two\n", "three\n"]))
                }

                it("multi line else") {
                    loader.set([
                        "if 1 > 1",
                        "{",
                            "echo one",
                            "echo five",
                        "}",
                        "else {",
                            "echo two",
                            "echo three",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["two\n", "three\n"]))
                }
            }

            describe("else if") {
                it("single line") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 then echo three",
                        "else {",
                            "echo four",
                            "echo five",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

                it("single line") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 then",
                        "{",
                            "echo three",
                        "}",
                        "else echo four",
                        "exit",
                        "}",
                        "echo after",
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

                it("single line") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 then",
                        "{",
                            "echo three",
                        "}",
                        "else echo four",
                        "exit",
                        "}",
                        "echo after",
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

                it("single line") {
                    loader.set([
                        "if 1 < 2 then echo one",
                        "else if 2 == 2  then echo two",
                        "else echo three",
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["one\n"]))
                }

                it("single line") {
                    loader.set([
                        "if 1 > 2 then echo one",
                        "else if 2 == 2  then echo two",
                        "else echo three",
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["two\n"]))
                }

                it("single line") {
                    loader.set([
                        "if 1 > 2 then echo one",
                        "else if 2 > 2  then echo two",
                        "else echo three",
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

//                it("arg single line") {
//                    loader.set([
//                        "if_1 then echo one",
//                        "else if_2 then echo two",
//                        "else echo three",
//                    ])
//                    script.run(["one"])
//                    expect(notifier.messages).to(equal(["one\n"]))
//                }
//
//                it("arg single line") {
//                    loader.set([
//                        "if_1 then echo one",
//                        "else if_2 then echo two",
//                        "else echo three",
//                    ])
//                    script.run(["one", "two"])
//                    expect(notifier.messages).to(equal(["two\n"]))
//                }

                it("multi line if else") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 > 2 {",
                            "echo three",
                        "}",
                        "else if 2 > 2 {",
                            "echo four",
                        "}",
                        "else {",
                            "echo five",
                            "echo six",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["five\n", "six\n"]))
                }

                it("multi line if else") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 {",
                            "echo three",
                        "}",
                        "else {",
                            "echo four",
                            "echo five",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

                it("multi line if else") {
                    loader.set([
                        "if 1 > 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 {",
                            "echo three",
                        "}",
                        "else if 2 == 2 {",
                            "echo six",
                        "}",
                        "else {",
                            "echo four",
                            "echo five",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["three\n"]))
                }

                it("multi line if else") {
                    loader.set([
                        "if 1 < 2",
                        "{",
                            "echo one",
                            "echo two",
                        "}",
                        "else if 2 == 2 {",
                            "echo three",
                        "}",
                        "else if 2 == 2 {",
                            "echo six",
                        "}",
                        "else {",
                            "echo four",
                            "echo five",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["one\n", "two\n"]))
                }

                it("multi line if else - nested") {
                    loader.set([
                        "if 1 < 2",
                        "{",
                            "echo one",
                            "echo two",
                            "if 1 == 2 {",
                                "echo middle",
                            "}",
                            "else if 1 == 1 {",
                                "echo another",
                            "}",
                            "echo after",
                        "}",
                        "else if 2 == 2 {",
                            "echo three",
                        "}",
                        "else if 2 == 2 {",
                            "echo six",
                        "}",
                        "else {",
                            "echo four",
                            "echo five",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["one\n", "two\n", "another\n", "after\n"]))
                }
            }

            describe("evaluated ifs") {
                it("replaces variables in expression") {
                    loader.set([
                        "if %one > $two {",
                            "echo one",
                        "}",
                        "else echo two"
                    ])
                    script.context.variables["one"] = "3"
                    context.variable("two", "2")
                    script.run([])
                    expect(notifier.messages).to(equal(["one\n"]))
                }

                it("replaces variables in expression") {
                    loader.set([
                        "if \"%guild\" = \"Ranger\" || \"%guild\" = \"Thief\" {",
                            "echo Yep",
                        "}",
                        "else echo Other"
                    ])
                    script.context.variables["guild"] = "Thief"
                    script.run([])
                    expect(notifier.messages).to(equal(["Yep\n"]))
                }

                it("replaces variables in expression") {
                    loader.set([
                        "if \"%guild\" = \"Ranger\" || \"%guild\" = \"Thief\" || \"%guild\" == \"Cleric\" {",
                            "echo Yep",
                        "}",
                        "else echo Other"
                    ])
                    script.context.variables["guild"] = "Cleric"
                    script.run([])
                    expect(notifier.messages).to(equal(["Yep\n"]))
                }
            }

            describe("if") {
                it("if matchre sets regex variables") {
                    loader.set([
                        "if matchre(\"swim north\", \"^(search|swim) \") then",
                        "{",
                            "echo $1",
                        "}"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal(["swim\n"]))
                }
            }

            describe("math") {
                it("trunkates .0") {
                    loader.set([
                        "math test add 5",
                    ])
                    script.context.variables["test"] = "10"
                    script.run([])
                    expect(script.context.variables["test"]).to(equal("15"))
                }

                it("add fractions") {
                    loader.set([
                        "math test add 5.5",
                    ])
                    script.context.variables["test"] = "10.2"
                    script.run([])
                    expect(script.context.variables["test"]).to(equal("15.7"))
                }
            }

            describe("gosub") {
                it("restores if stack") {
                    loader.set([
                        "if 3 > 2 {",
                            "gosub one",
                        "}",
                        "goto end",
                        "one:",
                            "echo gosub",
                            "return",
                        "end:"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal([
                        "gosub\n"
                    ]))
                }

                it("restores nested if stack") {
                    loader.set([
                        "if 3 > 2 {",
                            "if 3 > 2 {",
                                "gosub one",
                                "gosub two",
                                "echo one",
                            "}",
                            "gosub three",
                            "echo two",
                        "}",
                        "gosub four",
                        "echo three",
                        "goto end",
                        "one:",
                            "echo gosub 1",
                            "return",
                        "two:",
                            "echo gosub 2",
                            "return",
                        "three:",
                            "echo gosub 3",
                            "return",
                        "four:",
                            "echo gosub 4",
                            "return",
                        "end:"
                    ])
                    script.run([])
                    expect(notifier.messages).to(equal([
                        "gosub 1\n",
                        "gosub 2\n",
                        "one\n",
                        "gosub 3\n",
                        "two\n",
                        "gosub 4\n",
                        "three\n"
                    ]))
                }
            }
        }
    }
}
