/*
 Copyright 2020 The Fuel Rats Mischief

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
 products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import IRCKit

protocol IRCBotModule {
    var name: String { get }

    init (_ moduleManager: IRCBotModuleManager)
}

class IRCBotModuleManager {
    private var registeredModules: [IRCBotModule] = []
    static var blacklist = configuration.general.dispatchBlacklist

    func register (module: IRCBotModule) {
        self.registeredModules.append(module)
    }

    func register (command: IRCBotCommandDeclaration) {
        MechaSqueak.commands.append(command)
    }

    @EventListener<IRCChannelMessageNotification>
    var onChannelMessage = { channelMessage in
        guard channelMessage.raw.messageTags["batch"] == nil else {
            // Do not interpret commands from playback of old messages
            return
        }
        guard let ircBotCommand = IRCBotCommand(from: channelMessage) else {
            return
        }

        handleIncomingCommand(ircBotCommand: ircBotCommand)
    }


    @EventListener<IRCPrivateMessageNotification>
    var onPrivateMessage = { privateMessage in
        guard privateMessage.raw.messageTags["batch"] == nil else {
            // Do not interpret commands from playback of old messages
            return
        }
        guard let ircBotCommand = IRCBotCommand(from: privateMessage) else {
            return
        }

        handleIncomingCommand(ircBotCommand: ircBotCommand)
    }

    static func handleIncomingCommand (ircBotCommand: IRCBotCommand) {
        var ircBotCommand = ircBotCommand
        let message = ircBotCommand.message

        guard let command = MechaSqueak.commands.first(where: {
            $0.commands.contains(ircBotCommand.command)
        }) else {
            return
        }

        if ircBotCommand.options.contains("h") {
            var helpCommand = ircBotCommand
            helpCommand.command = "!help"
            helpCommand.parameters = ["!\(ircBotCommand.command)"]
            mecha.helpModule.didReceiveHelpCommand(helpCommand)
            return
        }

        let illegalNamedOptions = ircBotCommand.namedOptions.subtracting(command.namedOptions)
        if illegalNamedOptions.count > 0 {
            message.error(key: "command.illegalnamedoptions", fromCommand: ircBotCommand, map: [
                "options": Array(illegalNamedOptions).englishList,
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        let illegalOptions = ircBotCommand.options.subtracting(command.options)
        if illegalOptions.count > 0 {
            message.error(key: "command.illegaloptions", fromCommand: ircBotCommand, map: [
                "options": String(illegalOptions),
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if message.user.hasPermission(permission: .RescueWrite) == false && message.destination.isPrivateMessage && command.allowedDestinations == .Channel {
            message.error(key: "command.publiconly", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command
            ])
            return
        }

        if message.user.hasPermission(permission: .RescueWrite) == false && message.destination.isPrivateMessage == false && command.allowedDestinations == .PrivateMessage {
            message.error(key: "command.privateonly", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command
            ])
             return
        }

        guard command.minimumParameters <= ircBotCommand.parameters.count else {
            message.error(key: "command.toofewparams", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if
            let maxParameters = command.maximumParameters,
            command.lastParameterIsContinous == true,
            ircBotCommand.parameters.count > 1
        {
            var parameters: [String] = []
            var paramIndex = 0

            while paramIndex < maxParameters && paramIndex < ircBotCommand.parameters.count {
                if paramIndex == maxParameters - 1 {
                    let remainderComponents = ircBotCommand.parameters[paramIndex..<ircBotCommand.parameters.endIndex]
                    let remainder = remainderComponents.joined(separator: " ")
                    parameters.append(remainder)
                    break
                } else {
                    parameters.append(ircBotCommand.parameters[paramIndex])
                }
                paramIndex += 1
            }
            ircBotCommand.parameters = Array(parameters)
        }

        if let maxParameters = command.maximumParameters, ircBotCommand.parameters.count > maxParameters {
            message.error(key: "command.toomanyparams", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if let permission = command.permission {
            guard message.user.hasPermission(permission: permission) else {
                message.error(key: "board.nopermission", fromCommand: ircBotCommand, map: [
                    "nick": message.user.nickname
                ])
                return
            }
        }
        if command.isDispatchingCommand && blacklist.contains(where: {
            message.user.nickname.lowercased().contains($0.lowercased()) || message.user.account?.lowercased() == $0.lowercased()
        }) {
            message.client.sendMessage(toChannelName: "#doersofstuff", withKey: "command.blacklist", mapping: [
                "command": ircBotCommand.command,
                "nick": message.user.nickname
            ])
        }

        command.onCommand?(ircBotCommand)
    }
}
