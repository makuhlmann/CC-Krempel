local completion = require "cc.shell.completion"

shell.setPath(shell.path() .. ":/lib")
shell.setPath(shell.path() .. ":/bin")

shell.setCompletionFunction("bin/cat.lua", completion.build(completion.file))
shell.setCompletionFunction("bin/touch.lua", completion.build(completion.file))
shell.setCompletionFunction("bin/cosu.lua", completion.build(completion.file))
shell.setCompletionFunction("bin/svcman.lua", completion.build({ completion.choice, { "start ", "stop ", "restart ", "kill ", "list", "enable ", "disable " } }, completion.command))

shell.setAlias("del", "delete")
shell.setAlias("rm", "delete")
