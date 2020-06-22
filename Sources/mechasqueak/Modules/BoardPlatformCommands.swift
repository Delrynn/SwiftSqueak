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

extension BoardCommands {
    func platformChangeCommand (platform: GamePlatform, command: IRCBotCommand, message: IRCPrivateMessage) {
        guard let rescue = self.assertGetRescueId(command: command, fromMessage: message) else {
            return
        }

        rescue.platform = platform
        message.reply(key: "board.platformset", fromCommand: command, map: [
            "platform": rescue.platform!.ircRepresentable,
            "caseId": rescue.commandIdentifier!,
            "client": rescue.client!
        ])
        rescue.syncUpstream(fromBoard: mecha.rescueBoard)
    }

    func didReceiveXboxPlatformCommand (command: IRCBotCommand, fromMessage message: IRCPrivateMessage) {
        self.platformChangeCommand(platform: .Xbox, command: command, message: message)
    }

    func didReceivePCPlatformCommand (command: IRCBotCommand, fromMessage message: IRCPrivateMessage) {
        self.platformChangeCommand(platform: .PC, command: command, message: message)
    }

    func didReceivePS4PlatformCommand (command: IRCBotCommand, fromMessage message: IRCPrivateMessage) {
        self.platformChangeCommand(platform: .PS4, command: command, message: message)
    }
}
