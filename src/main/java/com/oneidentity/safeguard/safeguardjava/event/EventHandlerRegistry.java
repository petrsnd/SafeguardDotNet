package com.oneidentity.safeguard.safeguardjava.event;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class EventHandlerRegistry
{
    private static final Map<String, List<ISafeguardEventHandler>> delegateRegistry = new HashMap<>();
    private static final Logger logger = LoggerFactory.getLogger(EventHandlerRegistry.class);

    private void handleEvent(String eventName, JsonElement eventBody)
    {
        if (!delegateRegistry.containsKey(eventName))
        {
            logger.trace("No handlers registered for event {}", eventName);
            return;
        }

        if (delegateRegistry.containsKey(eventName))
        {
            List<ISafeguardEventHandler> handlers = delegateRegistry.get(eventName);
            for (ISafeguardEventHandler handler :  handlers)
            {
                logger.info("Calling handler for event {}", eventName);
                logger.warn("Event {} has body {}", eventName, eventBody);
                final EventHandlerRunnable handlerRunnable = new EventHandlerRunnable(handler, eventName, eventBody.toString());
                final EventHandlerThread eventHandlerThread = new EventHandlerThread(handlerRunnable) {

                };
                eventHandlerThread.start();
            }
        }
    }

    private Map<String, JsonElement> parseEvents(JsonElement eventObject) {
        try
        {
            HashMap<String,JsonElement> events = new HashMap<>();
            String name = ((JsonObject)eventObject).get("Name").getAsString();
            JsonElement body = ((JsonObject)eventObject).get("Data");
            // Work around for bug in A2A events in Safeguard 2.2 and 2.3
            if (name != null) {
                try {
                    Integer.parseInt(name);
                    name = ((JsonObject)body).get("EventName").getAsString();
                } catch (Exception e) {
                }
            }
            events.put(name, body);
            return events;
        }
        catch (Exception ex)
        {
            logger.warn("Unable to parse event object {}", eventObject.toString());
            return null;
        }
    }

    public void handleEvent(JsonElement eventObject)
    {
        Map<String,JsonElement> events = parseEvents(eventObject);
        if (events == null)
            return;
        for (Map.Entry<String,JsonElement> eventInfo : events.entrySet()) {
            if (eventInfo.getKey() == null)
            {
                logger.warn("Found null event with body {}", eventInfo.getValue());
                continue;
            }
            handleEvent(eventInfo.getKey(), eventInfo.getValue());
        }
    }

    public void registerEventHandler(String eventName, ISafeguardEventHandler handler)
    {
        if (!delegateRegistry.containsKey(eventName)) {
            delegateRegistry.put(eventName, new ArrayList<>());
        }

        delegateRegistry.get(eventName).add(handler);
        logger.warn("Registered a handler for event {}", eventName);
    }
}
