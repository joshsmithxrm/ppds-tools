using System;
using Microsoft.Xrm.Sdk;
using PPDS.Plugins;

namespace ContractFixture
{
    [PluginStep(Message = "Update", EntityLogicalName = "account", Stage = PluginStage.PreOperation,
        FilteringAttributes = "name", ExecutionOrder = 7)]
    public sealed class AccountPlugin : IPlugin
    {
        public AccountPlugin() { throw new InvalidOperationException("Fixture must never execute."); }
        public void Execute(IServiceProvider serviceProvider) { throw new InvalidOperationException("Fixture must never execute."); }
    }
}
