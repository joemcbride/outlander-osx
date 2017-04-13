//
//  Script.swift
//  Outlander
//
//  Created by Joseph McBride on 3/24/17.
//  Copyright © 2017 Joe McBride. All rights reserved.
//

import Foundation

func delay(_ delay: Double, _ closure: @escaping () -> ()) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        closure()
    }
}

enum CheckStreamResult {
    case None
    case Match(result:String)
}

protocol IWantStreamInfo {

    var id:String { get }

    func stream(_ text:String, _ nodes:[Node], _ context:ScriptContext) -> CheckStreamResult
    func execute(_ script:IScript, _ context:ScriptContext)
}

protocol IAction : IWantStreamInfo {
    var enabled:Bool {get set}
//    var token:ActionToken {get}
    func vars(context:ScriptContext, vars:Dictionary<String, String>) -> CheckStreamResult
}

class GosubContext {
    var label:Label
    var line:ScriptLine
    var params:[String]
    var isGosub:Bool
    var returnToLine:ScriptLine?
    var returnToIndex:Int?

    init(_ label:Label, _ line:ScriptLine, _ params:[String], _ isGosub:Bool = false) {
        self.label = label
        self.line = line
        self.params = params
        self.isGosub = isGosub
    }
}

protocol IScript {
    var fileName:String { get }
    func stop()
    func resume()
    func pause()
    func setLogLevel(_ level:ScriptLogLevel)
    func next()
    func nextAfterRoundtime()
    func stream(_ text:String, _ nodes:[Node])
    func vars()
    func showStackTrace()
}

class ScriptLine {
    var originalText: String
    var fileName: String
    var lineNumber: Int
    var token:TokenValue?
    var endOfBlock:Int?
    var ifResult:Bool?

    init(originalText:String, fileName:String, lineNumber:Int) {
        self.originalText = originalText
        self.fileName = fileName
        self.lineNumber = lineNumber
    }
}

enum ScriptExecuteResult {
    case next
    case wait
    case exit
    case advanceToNextBlock
    case advanceToEndOfBlock
}

class Script : IScript {
    let labelRegex: Regex
    let includeRegex: Regex

    let fileName: String
    let notifier:INotifyMessage
    let loader: (String) -> [String]
    let gameContext: GameContext
    let context: ScriptContext
    let notifyExit: () -> ()

    var started:Date?
    var debugLevel:ScriptLogLevel = ScriptLogLevel.none
    var stopped = false
    var paused = false
    var nextAfterUnpause = false

    private var tokenHandlers:[TokenValue:(ScriptLine,TokenValue)->ScriptExecuteResult]
    private var reactToStream:[IWantStreamInfo]

    private var stackTrace:Stack<ScriptLine>
    private var matchStack:[IMatch]
    private var matchwait:Matchwait?

    private var gosub:GosubContext?
    private var gosubStack:Stack<GosubContext>

    private var evaluator:ExpressionEvaluator

    private var lastLine:ScriptLine? {
        return stackTrace.last2
    }

    private var lastTokenWasIf:Bool {
        guard let lastToken = self.lastLine?.token else {
            return false
        }

        return lastToken.isIfToken
    }

    init(_ notifier:INotifyMessage,
         _ loader: @escaping ((String) -> [String]),
         _ fileName: String,
         _ gameContext: GameContext,
         _ notifyExit: @escaping ()->()) throws {

        self.notifier = notifier
        self.loader = loader
        self.fileName = fileName
        self.gameContext = gameContext
        self.context = ScriptContext({
            return gameContext.globalVars.copyValues() as! [String:String]
        })

        self.notifyExit = notifyExit

        labelRegex = try Regex("^\\s*(\\w+((\\.|-|\\w)+)?):")
        includeRegex = try Regex("^\\s*include (.+)$")

        self.reactToStream = []
        self.stackTrace = Stack<ScriptLine>(30)
        self.matchStack = []
        self.evaluator = ExpressionEvaluator()
        self.gosubStack = Stack<GosubContext>(100)
        
        self.tokenHandlers = [:]
        self.tokenHandlers[.comment("")] = self.handleComment
        self.tokenHandlers[.debug(0)] = self.handleDebug
        self.tokenHandlers[.elseSingle(.comment(""))] = self.handleElseSingle
        self.tokenHandlers[.Else] = self.handleElse
        self.tokenHandlers[.elseNeedsBrace] = self.handleElseNeedsBrace
        self.tokenHandlers[.echo("")] = self.handleEcho
        self.tokenHandlers[.elseIfSingle("", .comment(""))] = self.handleElseIfSingle
        self.tokenHandlers[.elseIf("")] = self.handleElseIf
        self.tokenHandlers[.elseIfNeedsBrace("")] = self.handleElseIfNeedsBrace
        self.tokenHandlers[.exit] = self.handleExit
        self.tokenHandlers[.goto("")] = self.handleGoto
        self.tokenHandlers[.gosub("", "")] = self.handleGosub
        self.tokenHandlers[.ifArgSingle(0, .comment(""))] = self.handleIfArgSingle
        self.tokenHandlers[.ifArg(0)] = self.handleIfArg
        self.tokenHandlers[.ifArgNeedsBrace(0)] = self.handleIfArgNeedsBrace
        self.tokenHandlers[.ifSingle("", .comment(""))] = self.handleIfSingle
        self.tokenHandlers[.If("")] = self.handleIf
        self.tokenHandlers[.ifNeedsBrace("")] = self.handleIfNeedsBrace
        self.tokenHandlers[.label("")] = self.handleLabel
        self.tokenHandlers[.match("", "")] = self.handleMatch
        self.tokenHandlers[.matchre("", "")] = self.handleMatchre
        self.tokenHandlers[.matchwait(0)] = self.handleMatchwait
        self.tokenHandlers[.move("")] = self.handleMove
        self.tokenHandlers[.nextroom] = self.handleNextroom
        self.tokenHandlers[.pause(0)] = self.handlePause
        self.tokenHandlers[.put("")] = self.handlePut
        self.tokenHandlers[.Return] = self.handleReturn
        self.tokenHandlers[.save("")] = self.handleSave
        self.tokenHandlers[.send("")] = self.handleSend
        self.tokenHandlers[.shift] = self.handleShift
        self.tokenHandlers[.token("")] = self.handleToken
        self.tokenHandlers[.unvar("")] = self.handleUnvar
        self.tokenHandlers[.wait] = self.handleWait
        self.tokenHandlers[.waitfor("")] = self.handleWaitfor
        self.tokenHandlers[.waitforre("")] = self.handleWaitforre
        self.tokenHandlers[.variable("", "")] = self.handleVariable
    }

    func run(_ args:[String]) {

        self.context.args = args
        self.context.updateArgumentVars()

        self.started = Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        let formattedDate = dateFormatter.string(from: self.started!)

        self.sendText(String(format:"[Starting '\(self.fileName)' at \(formattedDate)]\n"))
        self.sendText(String(format:"[\(Date()) - started]\n"))
        
        initialize(self.fileName, context: self.context)

        self.sendText(String(format:"[\(Date()) - initialized]\n"))

        self.context.variables["scriptname"] = self.fileName

        next()
    }

    fileprivate func initialize(_ fileName: String, context: ScriptContext) {
        let lines = self.loader(fileName)

//        print("line count: \(lines.count)")

        if lines.count == 0 {
            sendText("Script '\(fileName)' is empty or does not exist\n", preset: "scripterror")
            return
        }

        var index = 0

        for line in lines {
            index += 1

            if line == "" {
                continue
            }

            if let include = includeRegex.firstMatch(line as NSString) {
                let includeName = include.trimmingCharacters(in: CharacterSet.whitespaces).trimSuffix(".cmd")
                guard includeName != fileName else {
                    sendText("script '\(fileName)' cannot include itself!\n", preset: "scripterror", fileName: fileName, scriptLine: index)
                    continue
                }
                print("\(includeName)(\(index))")
                self.notify("including '\(includeName)'\n", debug: ScriptLogLevel.gosubs, scriptLine: index)
                initialize(includeName, context: context)
            } else {
                let scriptLine = ScriptLine(
                    originalText: line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
                    fileName: fileName,
                    lineNumber: index)
                context.lines.append(scriptLine)
            }

            if let label = labelRegex.firstMatch(line as NSString) {
                if let existing  = context.labels[label] {
                    sendText("replacing label '\(existing.name)' from '\(existing.fileName)'\n", preset: "scripterror", fileName: fileName, scriptLine: index)
                }
                context.labels[label.lowercased()] = Label(name: label.lowercased(), line: context.lines.count - 1, fileName: fileName)
            }
        }
    }

    public func sendCommand(_ command: String) {

        let ctx = CommandContext()
        ctx.command = command
        ctx.scriptName = self.fileName

        self.notifier.sendCommand(ctx)
    }

    func sendText(_ text:String, mono:Bool = true, preset:String = "scriptinput", fileName:String = "", scriptLine:Int = -1) {
        let tag = TextTag()
        tag.text = text
        tag.mono = mono
        tag.preset = preset
        tag.scriptName = fileName
        tag.scriptLine = Int32(scriptLine)
        self.notifier.notify(tag)
    }

    public func notify(_ text: String, mono:Bool = true, preset:String = "scriptinfo", debug:ScriptLogLevel = ScriptLogLevel.none, scriptLine:Int = -1) {

        if self.debugLevel.rawValue < debug.rawValue {
            return
        }

        let message = TextTag()
        message.text = text
        message.mono = mono
        message.scriptName = self.fileName
        message.preset = preset
        message.scriptLine = Int32(scriptLine)

        if debug != ScriptLogLevel.none && scriptLine < 0 {
            if let line = self.context.currentLine {
                message.scriptLine = Int32(line.lineNumber)
            }
        }

        self.notifier.notify(message)
    }

    func printInfo() {
        let diff = Date().timeIntervalSince(self.started!)
        self.sendText(String(format: "[Script '\(self.fileName)' running for %.02f seconds]\n", diff), preset: "scriptinput")
    }

    func varsForDisplay() -> [String] {
        var vars:[String] = []

        for (key, value) in self.context.argVars {
            vars.append("\(key): \(value)")
        }

        for (key, value) in self.context.variables {
            vars.append("\(key): \(value)")
        }

        return vars.sorted { $0 < $1 }
    }

    func vars() {
        let display = self.varsForDisplay()

        let diff = Date().timeIntervalSince(self.started!)
        self.sendText(
            String(format:"+----- '\(self.fileName)' variables (running for %.02f seconds) -----+\n", diff),
                mono: true,
                preset: "scriptinfo")

        for v in display {
            self.sendText("|  \(v)\n", mono: true, preset: "scriptinfo")
        }

        self.sendText("+---------------------------------------------------------+\n", mono: true, preset: "scriptinfo")
    }

    func showStackTrace() {
        self.sendText("+----- Tracing '\(self.fileName)' -----------------------------------+\n", mono: true, preset: "scriptinfo")

        for line in self.stackTrace.items {
            self.sendText("[\(line.fileName)(\(line.lineNumber))]: \(line.originalText)\n", mono: true, preset: "scriptinfo")
        }

        self.sendText("+---------------------------------------------------------+\n", mono: true, preset: "scriptinfo")
    }

    func stop() {

        if self.stopped { return }
        
        self.stopped = true
        self.context.currentLineNumber = -1
        let diff = Date().timeIntervalSince(self.started!)
        self.sendText(String(format: "[Script '\(self.fileName)' completed after %.02f seconds total run time]\n", diff), preset: "scriptinput")
    }

    func cancel() {
        self.stop()
        self.notifyExit()
    }

    func pause() {
        self.paused = true
        self.sendText("[Pausing '\(self.fileName)']\n")
    }

    func resume() {
        if !self.paused {
            return
        }

        self.sendText("[Resuming '\(self.fileName)']\n")

        self.paused = false

        if self.nextAfterUnpause {
            self.next()
        }
    }

    func setLogLevel(_ level:ScriptLogLevel) {
        self.debugLevel = level
        self.sendText("[Script '\(self.fileName)' - setting debug level to \(level.rawValue)]\n")
    }

    func stream(_ text:String, _ nodes:[Node]) {
        if (text.characters.count == 0 && nodes.count == 0) || self.paused || self.stopped {
            return
        }

        let handlers = self.reactToStream.filter { x in
            let res = x.stream(text, nodes, self.context)
            switch res {
            case .Match:
                return true
            default:
                return false
            }
        }

        handlers.forEach { handler in
            let idx = self.reactToStream.find { $0.id == handler.id  }
            self.reactToStream.remove(at: idx!)
            handler.execute(self, self.context)
        }

        self.checkMatches(text)
    }

    func checkMatches(_ text:String) {
        guard let _ = self.matchwait else {
            return
        }

        var foundMatch:IMatch? = nil

        for match in self.matchStack {
            if match.isMatch(text, self.context.simplify) {
                foundMatch = match
                break
            }
        }

        guard let match = foundMatch else {
            return
        }
        
        self.matchwait = nil
        self.matchStack.removeAll()

        let label = self.context.simplify(match.label)
        self.notify("match \(label)\n", debug:ScriptLogLevel.wait)

        let result = self.gotoLabel(label, match.groups)

        switch result {
        case .exit: self.cancel()
        case .next: self.nextAfterRoundtime()
        default: return
        }
    }

    func next() {

        if self.stopped { return }

        if self.paused {
            self.nextAfterUnpause = true
            return
        }
        
        self.context.advance()

        guard let line = self.context.currentLine else {
            self.cancel()
            return
        }

        if line.token == nil {
            line.token = ScriptParser().parse(line.originalText)
        }

        self.stackTrace.push(line)

        let result = handleLine(line)

        switch (result) {
            case .next: next()
            case .wait: return
            case .exit: self.cancel()
            case .advanceToNextBlock:
                if self.context.advanceToNextBlock() {
                    self.next()
                } else {
                    if let line = self.context.currentLine {
                        self.sendText("Unable to match next block\n", preset: "scripterror", fileName: line.fileName, scriptLine: line.lineNumber)
                    }
                    self.cancel()
                }
            case .advanceToEndOfBlock:
                if self.context.advanceToEndOfBlock() {
                    self.next()
                } else {
                    if let line = self.context.currentLine {
                        self.sendText("Unable to match end of block\n", preset: "scripterror", fileName: line.fileName, scriptLine: line.lineNumber)
                    }
                    self.cancel()
                }
        }
    }

    func nextAfterRoundtime() {
        if let roundtime = self.context.roundtime {
            if roundtime > 0 {
                delay(roundtime) {
                    self.nextAfterRoundtime()
                }
                return
            }
        }

        self.next()
    }

    func handleLine(_ line:ScriptLine) -> ScriptExecuteResult {
        guard let token = line.token else {
            self.sendText("Unknown command: '\(line.originalText)'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
            return .next
        }

        return executeToken(line, token)
    }

    func executeToken(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        if let handler = self.tokenHandlers[token] {
            return handler(line, token)
        }

        self.sendText("No handler for script token: '\(line.originalText)'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
        return .exit
    }

    func handleComment(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .comment(_) = token else {
            return .next
        }

        return .next
    }
    
    func handleDebug(_line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .debug(level) = token else {
            return .next
        }

        self.debugLevel = ScriptLogLevel(rawValue: level) ?? ScriptLogLevel.none
        self.notify("debug \(self.debugLevel.rawValue)\n", debug:ScriptLogLevel.gosubs)

        return .next
    }

    func handleEcho(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .echo(text) = token else {
            return .next
        }

        let result = self.context.simplify(text)

        self.notify("echo \(result)\n", debug:ScriptLogLevel.vars)

        self.notifier.sendEcho("\(result)\n")
        return .next
    }

    func handleExit(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .exit = token else {
            return .next
        }

        self.notify("exit\n", debug:ScriptLogLevel.gosubs)

        return .exit
    }

    func gotoLabel(_ label:String, _ params:[String], _ isGosub:Bool = false) -> ScriptExecuteResult {
        let result = self.context.simplify(label)

        guard let target = self.context.labels[result.lowercased()] else {
            self.notify("label '\(result)' not found", preset: "scripterror", debug:ScriptLogLevel.gosubs)
            return .exit
        }

        self.context.ifStack.clear()

        let command = isGosub ? "gosub" : "goto"

        self.notify("\(command) '\(result)'\n", debug:ScriptLogLevel.gosubs)

        let currentLine = self.context.currentLine!
        let currentLineNumber = self.context.currentLineNumber
        self.context.currentLineNumber = target.line - 1

        let line = self.context.lines[target.line]
        let gosubContext = GosubContext(target, line, params, isGosub)
        self.gosub = gosubContext

        if isGosub {
            gosubContext.returnToLine = currentLine
            gosubContext.returnToIndex = currentLineNumber
            self.context.setLabelVars(params)
            self.gosubStack.push(gosubContext)
        }

        return .next
    }

    func handleGoto(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .goto(label) = token else {
            return .next
        }

        return gotoLabel(label, [])
    }

    func handleGosub(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .gosub(label, args) = token else {
            return .next
        }

        let result = self.context.simplify(args)

        var split = [result]
        split.append(contentsOf: result.components(separatedBy: " "))

        return gotoLabel(label, split, true)
    }

    func handleIfArgSingle(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .ifArgSingle(count, lineToken) = token else {
            return .next
        }

        let hasArgs = self.context.args.count >= count
        line.ifResult = hasArgs

        self.notify("if_\(count) \(self.context.args.count) >= \(count) = \(hasArgs)\n", debug:ScriptLogLevel.if)

        if hasArgs {
            return executeToken(line, lineToken)
        }

        return .next
    }

    func handleIfArgNeedsBrace(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .ifArgNeedsBrace(count) = token else {
            return .next
        }

        let hasArgs = self.context.args.count >= count

        self.notify("if_\(count) \(self.context.args.count) >= \(count) = \(hasArgs)\n", debug:ScriptLogLevel.if)

        let ifLine = self.context.currentLine!

        if !self.context.consumeToken("{") {
            self.sendText("Expecting opening bracket\n", preset: "scripterror", fileName: self.fileName, scriptLine: ifLine.lineNumber + 1)
            return .exit
        }

        _ = self.context.pushLineToIfStack(ifLine)
        line.ifResult = hasArgs

        if hasArgs {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleIfArg(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .ifArg(count) = token else {
            return .next
        }

        let hasArgs = self.context.args.count >= count
        self.notify("if_\(count) \(self.context.args.count) >= \(count) = \(hasArgs)\n", debug:ScriptLogLevel.if)

        _ = self.context.pushCurrentLineToIfStack()
        line.ifResult = hasArgs

        if hasArgs {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleIfSingle(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .ifSingle(exp, lineToken) = token else {
            return .next
        }

        let simplified = self.context.simplify(exp)
        let result = self.evaluator.evaluateLogic(simplified)
        line.ifResult = result

        self.notify("if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if)

        if result {
            return executeToken(line, lineToken)
        }

        return .next
    }

    func handleIf(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .If(exp) = token else {
            return .next
        }

        _ = self.context.pushCurrentLineToIfStack()

        let simplified = self.context.simplify(exp)
        let result = self.evaluator.evaluateLogic(simplified)
        line.ifResult = result

        self.notify("if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if)

        if result {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleIfNeedsBrace(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .ifNeedsBrace(exp) = token else {
            return .next
        }

        if !self.context.consumeToken("{") {
            self.sendText("Expecting opening bracket\n", preset: "scripterror", fileName: line.fileName, scriptLine: line.lineNumber + 1)
            return .exit
        }

        _ = self.context.pushLineToIfStack(line)

        let simplified = self.context.simplify(exp)
        let result = self.evaluator.evaluateLogic(simplified)
        line.ifResult = result

        self.notify("if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if, scriptLine: line.lineNumber)

        if result {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleElseIfSingle(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .elseIfSingle(exp, lineToken) = token else {
            return .next
        }

        guard self.lastTokenWasIf else {
            self.sendText("Expected previous command to be an 'if' or 'else if'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
            return .exit
        }

        var execute = false
        var result = false

        if self.lastLine!.ifResult == false {
            execute = true
        } else {
            result = true
        }

        if execute {
            let simplified = self.context.simplify(exp)
            result = self.evaluator.evaluateLogic(simplified)
            self.notify("else if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if)
        } else {
            self.notify("else if: skipping\n", debug:ScriptLogLevel.if)
        }

        line.ifResult = result

        if execute && result {
            return executeToken(line, lineToken)
        }

        return .next
    }

    func handleElseIf(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .elseIf(exp) = token else {
            return .next
        }

        _ = self.context.pushCurrentLineToIfStack()

        var execute = false
        var result = false

        if self.lastLine!.ifResult == false {
            execute = true
        } else {
            result = true
        }

        if execute {
            let simplified = self.context.simplify(exp)
            result = self.evaluator.evaluateLogic(simplified)
            self.notify("else if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if)
        } else {
            self.notify("else if: skipping\n", debug:ScriptLogLevel.if)
        }

        line.ifResult = result

        if execute && result {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleElseIfNeedsBrace(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .elseIfNeedsBrace(exp) = token else {
            return .next
        }

        if !self.context.consumeToken("{") {
            self.sendText("Expecting opening bracket\n", preset: "scripterror", fileName: line.fileName, scriptLine: line.lineNumber + 1)
            return .exit
        }

        _ = self.context.pushLineToIfStack(line)

        var execute = false
        var result = false

        if self.lastLine!.ifResult == false {
            execute = true
        } else {
            result = true
        }

        if execute {
            let simplified = self.context.simplify(exp)
            result = self.evaluator.evaluateLogic(simplified)
            self.notify("else if: \(simplified) = \(result)\n", debug:ScriptLogLevel.if, scriptLine: line.lineNumber)
        } else {
            self.notify("else if: skipping\n", debug:ScriptLogLevel.if, scriptLine: line.lineNumber)
        }

        line.ifResult = result

        if execute && result {
            return .next
        }

        return .advanceToNextBlock
    }

    func handleElseSingle(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .elseSingle(lineToken) = token else {
            return .next
        }

        guard self.lastTokenWasIf else {
            self.sendText("Expected previous command to be an 'if' or 'else if'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
            return .exit
        }

        var execute = false

        if self.lastLine!.ifResult == false {
            execute = true
        }

        self.notify("else: \(execute)\n", debug:ScriptLogLevel.if)

        if execute {
            return executeToken(line, lineToken)
        }
        
        return .next
    }

    func handleElse(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .Else = token else {
            return .next
        }

        guard self.lastTokenWasIf else {
            self.sendText("Expected previous command to be an 'if' or 'else if'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
            return .exit
        }

        var execute = false

        if self.lastLine!.ifResult == false {
            execute = true
        }

        _ = self.context.pushLineToIfStack(line)

        self.notify("else: \(execute)\n", debug:ScriptLogLevel.if, scriptLine: line.lineNumber)

        if execute { return .next }
        return .advanceToNextBlock
    }

    func handleElseNeedsBrace(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .elseNeedsBrace = token else {
            return .next
        }

        guard self.lastTokenWasIf else {
            self.sendText("Expected previous command to be an 'if' or 'else if'\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber)
            return .exit
        }

        if !self.context.consumeToken("{") {
            self.sendText("Expecting opening bracket\n", preset: "scripterror", fileName: self.fileName, scriptLine: line.lineNumber + 1)
            return .exit
        }

        var execute = false

        if self.lastLine!.ifResult == false {
            execute = true
        }

        _ = self.context.pushLineToIfStack(line)

        self.notify("else: \(execute)\n", debug:ScriptLogLevel.if, scriptLine: line.lineNumber)

        if execute { return .next }
        return .advanceToNextBlock
    }

    func handleToken(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .token(t) = token else {
            return .next
        }

        if t == "}" {

            let (popped, ifLine) = self.context.popIfStack()
            if !popped {
                let line = self.context.currentLine!
                self.sendText("End brace encountered without matching beginning block\n", preset:"scripterror", fileName: self.fileName, scriptLine: line.lineNumber)

                return .exit
            }

            if ifLine?.ifResult == true {
                return .advanceToEndOfBlock
            }
        }

        return .next
    }

    func handleLabel(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .label(label) = token else {
            return .next
        }

        self.notify("passing label '\(label)'\n", debug:ScriptLogLevel.gosubs)
        return .next
    }

    func handleMatch(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .match(label, value) = token else {
            return .next
        }

        self.matchStack.append(MatchMessage(label, value))
        return .next
    }
    
    func handleMatchre(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .matchre(label, value) = token else {
            return .next
        }

        self.matchStack.append(MatchreMessage(label, value))
        return .next
    }

    func handleMatchwait(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .matchwait(timeout) = token else {
            return .next
        }

        let time = timeout > 0 ? "\(timeout)" : ""
        self.notify("matchwait \(time)\n", debug:ScriptLogLevel.wait)

        let token = Matchwait()
        self.matchwait = token

        if timeout > 0 {
            delay(timeout) {
                if let match = self.matchwait, match.id == token.id {
                    self.matchwait = nil
                    self.matchStack.removeAll()
                    self.notify("matchwait timeout\n", debug: ScriptLogLevel.wait)
                    self.nextAfterRoundtime()
                }
            }
        }

        return .wait
    }

    func handleMove(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .move(dir) = token else {
            return .next
        }

        let result = self.context.simplify(dir)

        self.notify("move \(result)\n", debug:ScriptLogLevel.wait)
        self.reactToStream.append(MoveOp())
        self.sendCommand("\(result)")

        return .wait
    }

    func handleNextroom(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .nextroom = token else {
            return .next
        }

        self.notify("nextroom\n", debug:ScriptLogLevel.wait)
        self.reactToStream.append(NextRoomOp())

        return .wait
    }

    func handlePause(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .pause(duration) = token else {
            return .next
        }

        self.notify("pausing for \(duration) seconds\n", debug:ScriptLogLevel.wait)
        delay(duration) {
            self.next()
        }

        return .wait
    }

    func handlePut(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {

        guard case let .put(text) = token else {
            return .next
        }

        let result = self.context.simplify(text)

        let cmds = result.splitToCommands()
        for cmd in cmds {
            self.sendCommand(cmd)
        }

        return .next
    }

    func handleReturn(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .Return = token else {
            return .next
        }

        guard let ctx = self.gosubStack.pop(), let returnToLine = ctx.returnToLine, let returnToIndex = ctx.returnToIndex else {
            self.sendText("no gosub to return to!\n", preset: "scripterror")
            return .exit
        }

        if let prev = self.gosubStack.last {
            self.gosub = prev
            self.context.setLabelVars(prev.params)
        }

        self.notify("returning to line \(returnToLine.lineNumber)\n", debug:ScriptLogLevel.gosubs)

        self.context.currentLineNumber = returnToIndex
        return .next
    }

    func handleSave(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .save(text) = token else {
            return .next
        }
        let result = self.context.simplify(text)
        self.notify("save \(result) to %s\n", debug:ScriptLogLevel.wait)
        self.context.variables["s"] = result
        return .next
    }

    func handleSend(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .send(text) = token else {
            return .next
        }
        let result = self.context.simplify(text)
        self.sendCommand("#send \(result)")
        return .next
    }

    func handleShift(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .shift = token else {
            return .next
        }

        self.notify("shift\n", debug:ScriptLogLevel.vars)

        if !self.context.shiftArgumentVars() {
            self.sendText("No more script arguments to shift!\n", preset: "scripterror")
            return .exit
        }
        
        return .next
    }

    func handleUnvar(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .unvar(key) = token else {
            return .next
        }

        let result = self.context.simplify(key)

        self.notify("deleting variable \(result)\n", debug:ScriptLogLevel.wait)
        self.context.variables.removeValue(forKey: result)

        return .next
    }

    func handleWait(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case .wait = token else {
            return .next
        }

        self.notify("wait for prompt\n", debug:ScriptLogLevel.wait)
        self.reactToStream.append(WaitforPromptOp())
        return .wait
    }

    func handleWaitfor(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .waitfor(text) = token else {
            return .next
        }

        let result = self.context.simplify(text)

        self.notify("waitfor \(result)\n", debug:ScriptLogLevel.wait)
        self.reactToStream.append(WaitforOp(result))
        return .wait
    }

    func handleWaitforre(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .waitforre(pattern) = token else {
            return .next
        }

        let result = self.context.simplify(pattern)

        self.notify("waitforre \(result)\n", debug:ScriptLogLevel.wait)
        self.reactToStream.append(WaitforReOp(result))
        return .wait
    }

    func handleVariable(_ line:ScriptLine, _ token:TokenValue) -> ScriptExecuteResult {
        guard case let .variable(key, value) = token else {
            return .next
        }

        let result = self.context.simplify(key)

        self.notify("setvariable \(result) \(value)\n", debug:ScriptLogLevel.vars)
        self.context.variables[result] = value

        return .next
    }
}
