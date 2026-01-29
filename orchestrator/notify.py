import logging
import subprocess

logger = logging.getLogger(__name__)

def send_question_notification(
    phone: str,
    question: str,
    context: str,
    personaplex_url: str,
    session_id: str
) -> bool:
    """Send WhatsApp notification when Moltbot needs input."""
    message = f"I need your input:\n\n{question}\n\nContext: {context}\n\nAnswer here: {personaplex_url}?session={session_id}&mode=answer"
    return _send_whatsapp(phone, message)

def send_completion_notification(
    phone: str,
    summary: str,
    personaplex_url: str,
    session_id: str
) -> bool:
    """Send WhatsApp notification when execution completes."""
    message = f"Task completed:\n\n{summary}\n\nReview here: {personaplex_url}?session={session_id}"
    return _send_whatsapp(phone, message)

def _send_whatsapp(phone: str, message: str) -> bool:
    """Send a WhatsApp message via Moltbot's deliver channel."""
    try:
        result = subprocess.run(
            ["moltbot", "agent", "--message", message, "--deliver", "--channel", "whatsapp", "--to", phone],
            capture_output=True,
            timeout=30,
        )
        if result.returncode != 0:
            logger.warning("WhatsApp send failed: %s", result.stderr.decode(errors="replace"))
            return False
        return True
    except FileNotFoundError:
        logger.warning("Moltbot not available for WhatsApp delivery")
        return False
    except subprocess.TimeoutExpired:
        logger.warning("WhatsApp send timed out")
        return False
