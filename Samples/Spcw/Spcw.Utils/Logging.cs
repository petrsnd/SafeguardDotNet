using System;
using System.IO;
using System.Reflection;
using Serilog;
using Serilog.Events;

namespace Spcw.Utils
{
    public static class Logging
    {
        public static void SetupLogging(string applicationName)
        {
            if (Environment.UserInteractive)
                Log.Logger = new LoggerConfiguration().MinimumLevel.Debug().WriteTo.ColoredConsole()
                    .CreateLogger();
            else
            {
                var loggingDirectory = Config.ReadRequiredSettingFromAppConfig("LoggingDirectory", "logging directory");
                if (!Path.IsPathRooted(loggingDirectory))
                    loggingDirectory = Path.Combine(Assembly.GetEntryAssembly().Location, loggingDirectory);
                Log.Logger = new LoggerConfiguration().WriteTo.RollingFile(
                        Path.Combine(loggingDirectory, "MetaDbAppPoolManager-{Date}.log"),
                        LogEventLevel.Debug)
                    .CreateLogger();
            }
        }
    }
}
