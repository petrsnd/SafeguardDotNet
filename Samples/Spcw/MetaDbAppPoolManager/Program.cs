using System.Reflection;
using Spcw.Utils;
using Topshelf;

namespace Spcw.MetaDbAppPoolManager
{
    class Program
    {
        static void Main()
        {
            var assemblyName = Assembly.GetExecutingAssembly().FullName;
            Logging.SetupLogging(assemblyName);

            HostFactory.Run(hostConfig =>
            {
                hostConfig.Service<ManagerService>(service =>
                {
                    service.ConstructUsing(c => new ManagerService());
                    service.WhenStarted(s => s.Start());
                    service.WhenStopped(s => s.Stop());
                });
                hostConfig.UseSerilog();
                hostConfig.StartAutomaticallyDelayed();
                hostConfig.SetDisplayName(assemblyName);
                hostConfig.SetServiceName("SpcwMdbAp");
                hostConfig.SetDescription("MetaDB and IIS App Pool credential synchronization agent.");
            });
        }
    }
}
