package com.oneidentity.safeguard.safeguardjava.event;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

class EventHandlerRunnable implements Runnable {

    private static final Logger logger = LoggerFactory.getLogger(EventHandlerRunnable.class);

    private final ISafeguardEventHandler handler;
    private final String eventName;
    private final String eventBody;

    EventHandlerRunnable(ISafeguardEventHandler handler, String eventName, String eventBody) {
        this.handler = handler;
        this.eventName = eventName;
        this.eventBody = eventBody;
    }

    @Override
    public void run() {
        try
        {
            handler.onEventReceived(eventName, eventBody);
        }
        catch (Exception ex)
        {
            logger.warn("An error occured while calling onEventReceived");
        }
    }
}
