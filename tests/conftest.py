"""Shared pytest fixtures."""

import pytest

from ais_demo.integrations import crm, event_grid, service_bus


@pytest.fixture(autouse=True)
def _reset_simulated_state():
    """Ensure each test starts with clean in-memory backends."""
    service_bus.reset_simulated_queues()
    event_grid.reset_simulated_events()
    crm.reset_simulated_records()
    yield
    service_bus.reset_simulated_queues()
    event_grid.reset_simulated_events()
    crm.reset_simulated_records()
