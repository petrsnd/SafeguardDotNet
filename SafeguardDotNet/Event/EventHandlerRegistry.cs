// Copyright (c) One Identity LLC. All rights reserved.

namespace OneIdentity.SafeguardDotNet.Event;

using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;

using OneIdentity.SafeguardDotNet.Serialization;

using Serilog;

using DelegateRegistry = System.Collections.Generic.Dictionary<string, System.Collections.Generic.List<OneIdentity.SafeguardDotNet.Event.SafeguardEventHandler>>;

internal class EventHandlerRegistry
{
    private readonly DelegateRegistry _delegateRegistry =
        new DelegateRegistry(StringComparer.InvariantCultureIgnoreCase);

    private void HandleEvent(string eventName, string eventBody)
    {
        if (!_delegateRegistry.ContainsKey(eventName))
        {
            Log.Debug("No handlers registered for event {Event}", eventName);
            return;
        }

        if (_delegateRegistry.ContainsKey(eventName))
        {
            foreach (var handler in _delegateRegistry[eventName])
            {
                Log.Information("Calling {Delegate} for event {Event}", handler.Method.Name, eventName);
                Log.Debug("Event {Event} has body {EventBody}", eventName, eventBody);
                Task.Run(() =>
                {
                    try
                    {
                        handler(eventName, eventBody);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(ex, "An error occured while calling {Delegate}", handler.Method.Name);
                    }
                });
            }
        }
    }

    private static (string Name, string Body)[] ParseEvents(string eventObject)
    {
        try
        {
            using var doc = SafeguardJson.Parse(eventObject);
            var root = doc.RootElement;

            var name = root.TryGetProperty("Name", out var nameEl) ? nameEl.GetString() : null;
            var body = root.TryGetProperty("Data", out var dataEl) ? dataEl : default;

            // Work around for bug in A2A events in Safeguard 2.2 and 2.3
            if (name != null && int.TryParse(name, out _)
                && body.ValueKind == JsonValueKind.Object
                && body.TryGetProperty("EventName", out var eventNameEl))
            {
                name = eventNameEl.GetString();
            }

            var bodyJson = body.ValueKind == JsonValueKind.Undefined ? null : body.GetRawText();
            return new[] { (name, bodyJson) };
        }
        catch (Exception ex)
        {
            Log.Warning(ex, "Unable to parse event object {EventObject}", eventObject);
            return Array.Empty<(string, string)>();
        }
    }

    public void HandleEvent(string eventObject)
    {
        var events = ParseEvents(eventObject);
        if (events.Length == 0)
        {
            return;
        }

        foreach (var eventInfo in events)
        {
            if (eventInfo.Name == null)
            {
                Log.Warning("Found null event with body {EventBody}", eventInfo.Body);
                continue;
            }

            HandleEvent(eventInfo.Name, eventInfo.Body);
        }
    }

    public void RegisterEventHandler(string eventName, SafeguardEventHandler handler)
    {
        if (!_delegateRegistry.ContainsKey(eventName))
        {
            _delegateRegistry[eventName] = new List<SafeguardEventHandler>();
        }

        _delegateRegistry[eventName].Add(handler);
        Log.Debug("Registered event {Event} with delegate {Delegate}", eventName, handler.Method.Name);
    }
}
