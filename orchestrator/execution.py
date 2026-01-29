from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Optional
import uuid

def _utcnow() -> datetime:
    return datetime.now(timezone.utc)

class ExecutionState(Enum):
    PENDING = "pending"
    RUNNING = "running"
    WAITING_FOR_INPUT = "waiting_for_input"
    COMPLETED = "completed"
    FAILED = "failed"

@dataclass
class ExecutionContext:
    session_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    state: ExecutionState = ExecutionState.PENDING
    transcript: list[str] = field(default_factory=list)
    commands: list[str] = field(default_factory=list)
    results: list[dict] = field(default_factory=list)
    current_question: Optional[str] = None
    question_context: Optional[str] = None
    answers: list[dict] = field(default_factory=list)
    topics: list[str] = field(default_factory=list)
    error_message: Optional[str] = None
    created_at: datetime = field(default_factory=_utcnow)
    updated_at: datetime = field(default_factory=_utcnow)
