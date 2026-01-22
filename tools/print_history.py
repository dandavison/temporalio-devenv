async def print_history(handle: WorkflowHandle):
    history = await handle.fetch_history()
    for event in history.events:
        try:
            event_type_name = temporalio.api.enums.v1.EventType.Name(
                event.event_type
            ).replace("EVENT_TYPE_", "")
        except ValueError:
            # Handle unknown event types
            event_type_name = f"Unknown({event.event_type})"
        print(f"{event.event_id}. {event_type_name}")
