-- | Help text for the TorXakis CLI.
{-# LANGUAGE QuasiQuotes #-}
module TorXakis.CLI.Help where

import           Text.RawString.QQ

helpText :: String
helpText = [r|
--------------------------------
TorXakis :: Model-Based Testing
--------------------------------

quit, q                        : stop TorXakis completely
exit, x                        : exit the current command run of TorXakis
help, h, ?                     : show help (this text)
info, i                        : show info on TorXakis
seed <n>                       : set random seed to <n>

delay <n>                      : wait for <n> seconds
echo <text>                    : echo the input <text>
# <text>                       : comment, <text> is ignored
time                           : give the current time
timer <name>                   : set or read timer <name>
run <file path>                : run TorXakis script from <file path>

var [<variable-declarations>]  : show/[declare] variables
val [<value-definitions>]      : show/[define] values
eval <value-expression>        : evaluate the (closed) <value-expression>
solve <value-expression>       : solve the (open, boolean) <value-expression>
ransolve <value-expression>    : solve (randomly) the (open, boolean) <value-expression>
unisolve <value-expression>    : solve (uniquely) the (open, boolean) <value-expression>
                                 'unsat': 0, 'sat': 1, 'unknown': >1 or unknown solution

load <file path>               : load TorXakis model definitions to the session
stepper <model>                : start stepping with model <model> where <model>
                                 is a model in model definitions which has been
                                 loaded with `load` command
step <action>                  : make a step identified by <action>
step [<n>]                     : make <n>/1 random steps
tester <model> [<purpose>]     : start testing with model <model> and connection
       [<mapper>] <cnect>        <cnect> using optional test purpose <purpose>
                                 and/or mapper <mapper>
test <action>                  : make a test step identified by (visible) input <action>
test                           : make a test step by observing output/quiescence
test <n>                       : make <n> random test steps
simulator <model> [<mapper>]   : start simulating with model <model> and
          <cnect>                connection <cnect> using optional mapper <mapper>
sim [<n>]                      : make <n>/[unbounded] random simulation steps
stop                           : stop testing, simulation, or stepping

show <object>                  : show <object>
menu [in|out|map|purp <goal>]  : give the [in|out|map] menu of actions of current state
                                 or purp menu for given goal
|]
